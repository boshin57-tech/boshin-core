module tobmate_core::gold_marketplace_adapter;


use sui::coin::Coin;
use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer::{Self, Receiving};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::AccessControl;
use tobmate_core::backing_position::{
    Self,
    GoldBackingPosition,
};
use tobmate_core::dual_ownership::{
    Self,
    DualOwnershipRecord,
    DualOwnershipRegistry,
};
use tobmate_core::gold_nft::{Self, GoldNFT};
use tobmate_core::gold_reserve::{Self, GoldReserve};
use tobmate_core::marketplace::{Self, Marketplace};

const E_INVALID_PRICE: u64 = 1;
const E_MARKETPLACE_PAUSED: u64 = 2;
const E_NFT_NOT_ACTIVE: u64 = 3;
const E_NFT_FROZEN: u64 = 4;
const E_POSITION_NOT_ACTIVE: u64 = 5;
const E_RESERVE_NOT_ACTIVE: u64 = 6;
const E_RESERVE_MISMATCH: u64 = 7;
const E_NFT_MISMATCH: u64 = 8;
const E_NOT_COLLECTIBLE_OWNER: u64 = 9;
const E_WRONG_MARKETPLACE: u64 = 10;
const E_WRONG_LISTING_NFT: u64 = 11;
const E_NOT_LISTING_SELLER: u64 = 12;
const E_SELLER_CANNOT_BUY: u64 = 13;
const E_INVALID_BUYER: u64 = 14;
const E_PRINCIPAL_CHANGED: u64 = 15;
const E_ORIGINAL_INVESTOR_CHANGED: u64 = 16;

/// Listing metadata remains separate from the GoldNFT.
///
/// The GoldNFT remains an owned object and is transferred to the
/// listing object's address as an object-owned escrow asset.
public struct GoldFixedPriceListing has key {
    id: UID,

    marketplace_id: ID,
    gold_nft_id: ID,
    backing_position_id: ID,
    reserve_id: ID,
    dual_ownership_record_id: ID,

    seller: address,
    principal_owner_snapshot: address,
    original_investor_snapshot: address,

    price: u64,
    created_at_epoch: u64,
}

public struct GoldListingCreated has copy, drop {
    marketplace_id: ID,
    listing_id: ID,
    gold_nft_id: ID,
    backing_position_id: ID,
    reserve_id: ID,
    seller: address,
    price: u64,
}

public struct GoldListingCancelled has copy, drop {
    marketplace_id: ID,
    listing_id: ID,
    gold_nft_id: ID,
    seller: address,
}

public struct GoldSaleCompleted has copy, drop {
    marketplace_id: ID,
    listing_id: ID,
    gold_nft_id: ID,
    backing_position_id: ID,
    reserve_id: ID,
    dual_ownership_record_id: ID,

    seller: address,
    buyer: address,

    original_investor: address,
    principal_owner: address,

    sale_price: u64,
    marketplace_fee: u64,
    seller_proceeds: u64,

    completed_at_epoch: u64,
}

/// Performs all cross-object checks required before listing.
public fun assert_gold_tradeable(
    marketplace: &Marketplace,
    reserve: &GoldReserve,
    position: &GoldBackingPosition,
    nft: &GoldNFT,
    record: &DualOwnershipRecord,
    expected_seller: address,
) {
    assert!(
        !marketplace::is_paused(marketplace),
        E_MARKETPLACE_PAUSED,
    );

    assert!(
        gold_reserve::is_active(reserve),
        E_RESERVE_NOT_ACTIVE,
    );

    assert!(
        backing_position::is_active(position),
        E_POSITION_NOT_ACTIVE,
    );

    assert!(
        gold_nft::is_active(nft),
        E_NFT_NOT_ACTIVE,
    );

    assert!(
        !gold_nft::is_frozen(nft),
        E_NFT_FROZEN,
    );

    backing_position::assert_reserve(
        position,
        reserve,
    );

    gold_nft::assert_matches_position(
        nft,
        position,
    );

    gold_nft::assert_linked_to_position(
        nft,
        position,
    );

    dual_ownership::assert_active_and_unfrozen(
        record,
    );

    dual_ownership::assert_matches_position_and_nft(
        record,
        position,
        nft,
    );

    assert!(
        gold_nft::reserve_id(nft) ==
            gold_reserve::reserve_id(reserve),
        E_RESERVE_MISMATCH,
    );

    assert!(
        dual_ownership::gold_nft_id(record) ==
            gold_nft::nft_id(nft),
        E_NFT_MISMATCH,
    );

    assert!(
        dual_ownership::collectible_owner(record) ==
            expected_seller,
        E_NOT_COLLECTIBLE_OWNER,
    );
}

/// Creates a shared fixed-price listing and transfers the GoldNFT
/// to the listing object's address without granting `store` ability.
public fun create_gold_fixed_price_listing(
    marketplace: &mut Marketplace,
    reserve: &GoldReserve,
    position: &GoldBackingPosition,
    nft: GoldNFT,
    record: &DualOwnershipRecord,
    price: u64,
    ctx: &mut TxContext,
) {
    assert!(price > 0, E_INVALID_PRICE);

    let seller = tx_context::sender(ctx);

    assert_gold_tradeable(
        marketplace,
        reserve,
        position,
        &nft,
        record,
        seller,
    );

    let gold_nft_id = gold_nft::nft_id(&nft);

    let listing = GoldFixedPriceListing {
        id: object::new(ctx),

        marketplace_id:
            marketplace::marketplace_id(marketplace),

        gold_nft_id,

        backing_position_id:
            backing_position::position_id(position),

        reserve_id:
            gold_reserve::reserve_id(reserve),

        dual_ownership_record_id:
            dual_ownership::record_id(record),

        seller,

        principal_owner_snapshot:
            dual_ownership::principal_owner(record),

        original_investor_snapshot:
            dual_ownership::original_investor(record),

        price,
        created_at_epoch: tx_context::epoch(ctx),
    };

    let listing_id = object::id(&listing);
    let listing_address = object::uid_to_address(&listing.id);

    marketplace::record_external_listing_created(
        marketplace,
    );

    event::emit(GoldListingCreated {
        marketplace_id:
            marketplace::marketplace_id(marketplace),
        listing_id,
        gold_nft_id,
        backing_position_id:
            backing_position::position_id(position),
        reserve_id:
            gold_reserve::reserve_id(reserve),
        seller,
        price,
    });

    // GoldNFT becomes an address-owned child of the listing.
    gold_nft::transfer_to_marketplace_escrow(
        nft,
        listing_address,
    );

    // Only the newly created listing becomes shared.
    transfer::share_object(listing);
}

/// Cancels the listing and returns the shared GoldNFT to the seller.
public fun cancel_gold_fixed_price_listing(
    access_control: &AccessControl,
    marketplace: &mut Marketplace,
    mut listing: GoldFixedPriceListing,
    nft_receiving: Receiving<GoldNFT>,
    ctx: &mut TxContext,
) {
    assert!(
        listing.marketplace_id ==
            marketplace::marketplace_id(marketplace),
        E_WRONG_MARKETPLACE,
    );

    assert!(
        tx_context::sender(ctx) == listing.seller,
        E_NOT_LISTING_SELLER,
    );

    assert!(
        transfer::receiving_object_id(&nft_receiving) ==
            listing.gold_nft_id,
        E_WRONG_LISTING_NFT,
    );

    let nft =
        gold_nft::receive_from_marketplace_escrow(
            &mut listing.id,
            nft_receiving,
        );

    assert!(
        gold_nft::nft_id(&nft) == listing.gold_nft_id,
        E_WRONG_LISTING_NFT,
    );

    marketplace::record_external_listing_cancelled(
        marketplace,
    );

    event::emit(GoldListingCancelled {
        marketplace_id: listing.marketplace_id,
        listing_id: object::id(&listing),
        gold_nft_id: listing.gold_nft_id,
        seller: listing.seller,
    });

    let GoldFixedPriceListing {
        id,
        marketplace_id: _,
        gold_nft_id: _,
        backing_position_id: _,
        reserve_id: _,
        dual_ownership_record_id: _,
        seller,
        principal_owner_snapshot: _,
        original_investor_snapshot: _,
        price: _,
        created_at_epoch: _,
    } = listing;

    object::delete(id);

    gold_nft::transfer_gold_nft(
        access_control,
        nft,
        seller,
        ctx,
    );
}

/// Purchases a GoldNFT while transferring only collectible ownership.
///
/// The principal owner and original investor are checked before and
/// after synchronization and must remain unchanged.
public fun buy_gold_fixed_price<Payment>(
    access_control: &AccessControl,
    marketplace: &mut Marketplace,
    mut listing: GoldFixedPriceListing,
    nft_receiving: Receiving<GoldNFT>,
    registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    payment: Coin<Payment>,
    ctx: &mut TxContext,
) {
    let buyer = tx_context::sender(ctx);

    assert!(buyer != @0x0, E_INVALID_BUYER);

    assert!(
        listing.marketplace_id ==
            marketplace::marketplace_id(marketplace),
        E_WRONG_MARKETPLACE,
    );

    assert!(
        buyer != listing.seller,
        E_SELLER_CANNOT_BUY,
    );

    assert!(
        transfer::receiving_object_id(&nft_receiving) ==
            listing.gold_nft_id,
        E_WRONG_LISTING_NFT,
    );

    assert!(
        listing.dual_ownership_record_id ==
            dual_ownership::record_id(record),
        E_NFT_MISMATCH,
    );

    assert!(
        dual_ownership::gold_nft_id(record) ==
            listing.gold_nft_id,
        E_NFT_MISMATCH,
    );

    assert!(
        dual_ownership::collectible_owner(record) ==
            listing.seller,
        E_NOT_COLLECTIBLE_OWNER,
    );

    assert!(
        dual_ownership::principal_owner(record) ==
            listing.principal_owner_snapshot,
        E_PRINCIPAL_CHANGED,
    );

    assert!(
        dual_ownership::original_investor(record) ==
            listing.original_investor_snapshot,
        E_ORIGINAL_INVESTOR_CHANGED,
    );

    let nft =
        gold_nft::receive_from_marketplace_escrow(
            &mut listing.id,
            nft_receiving,
        );

    assert!(
        gold_nft::nft_id(&nft) ==
            listing.gold_nft_id,
        E_WRONG_LISTING_NFT,
    );

    assert!(
        gold_nft::backing_position_id(&nft) ==
            listing.backing_position_id,
        E_NFT_MISMATCH,
    );

    assert!(
        gold_nft::reserve_id(&nft) ==
            listing.reserve_id,
        E_RESERVE_MISMATCH,
    );

    dual_ownership::record_collectible_transfer(
        registry,
        record,
        listing.gold_nft_id,
        listing.seller,
        buyer,
        ctx,
    );

    // Physical-gold principal rights must remain unchanged.
    assert!(
        dual_ownership::principal_owner(record) ==
            listing.principal_owner_snapshot,
        E_PRINCIPAL_CHANGED,
    );

    assert!(
        dual_ownership::original_investor(record) ==
            listing.original_investor_snapshot,
        E_ORIGINAL_INVESTOR_CHANGED,
    );

    let listing_id = object::id(&listing);

    marketplace::settle_external_fixed_price_sale(
        marketplace,
        listing_id,
        listing.seller,
        buyer,
        listing.price,
        payment,
        ctx,
    );

    event::emit(GoldSaleCompleted {
        marketplace_id:
            listing.marketplace_id,
        listing_id,
        gold_nft_id:
            listing.gold_nft_id,
        backing_position_id:
            listing.backing_position_id,
        reserve_id:
            listing.reserve_id,
        dual_ownership_record_id:
            listing.dual_ownership_record_id,

        seller:
            listing.seller,
        buyer,

        original_investor:
            listing.original_investor_snapshot,
        principal_owner:
            listing.principal_owner_snapshot,

        sale_price:
            listing.price,
        marketplace_fee:
            marketplace::calculate_marketplace_fee(
                listing.price,
                marketplace::marketplace_fee_bps(
                    marketplace,
                ),
            ),
        seller_proceeds:
            listing.price -
                marketplace::calculate_marketplace_fee(
                    listing.price,
                    marketplace::marketplace_fee_bps(
                        marketplace,
                    ),
                ),

        completed_at_epoch:
            tx_context::epoch(ctx),
    });

    let GoldFixedPriceListing {
        id,
        marketplace_id: _,
        gold_nft_id: _,
        backing_position_id: _,
        reserve_id: _,
        dual_ownership_record_id: _,
        seller: _,
        principal_owner_snapshot: _,
        original_investor_snapshot: _,
        price: _,
        created_at_epoch: _,
    } = listing;

    object::delete(id);

    gold_nft::transfer_gold_nft(
        access_control,
        nft,
        buyer,
        ctx,
    );
}


/// Purchases an escrowed GoldNFT using SUI and deposits the
/// marketplace fee directly into the protocol FeeVault.
///
/// The following state transitions are atomic:
///
/// - SUI payment settlement;
/// - seller proceeds payment;
/// - marketplace fee collection;
/// - collectible ownership synchronization;
/// - GoldNFT transfer to buyer;
/// - marketplace accounting update;
/// - listing destruction.
///
/// The function never changes physical-gold principal ownership or
/// the original-investor identity.
public fun buy_gold_fixed_price_with_fee_vault(
    access_control: &AccessControl,
    marketplace: &mut Marketplace,
    fee_vault_object:
        &mut tobmate_core::fee_vault::FeeVault,
    mut listing: GoldFixedPriceListing,
    nft_receiving: Receiving<GoldNFT>,
    registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    payment: Coin<sui::sui::SUI>,
    ctx: &mut TxContext,
) {
    let buyer =
        tx_context::sender(ctx);

    assert!(
        buyer != @0x0,
        E_INVALID_BUYER,
    );

    assert!(
        listing.marketplace_id ==
            marketplace::marketplace_id(
                marketplace,
            ),
        E_WRONG_MARKETPLACE,
    );

    assert!(
        buyer != listing.seller,
        E_SELLER_CANNOT_BUY,
    );

    assert!(
        transfer::receiving_object_id(
            &nft_receiving,
        ) == listing.gold_nft_id,
        E_WRONG_LISTING_NFT,
    );

    assert!(
        listing.dual_ownership_record_id ==
            dual_ownership::record_id(record),
        E_NFT_MISMATCH,
    );

    assert!(
        dual_ownership::gold_nft_id(record) ==
            listing.gold_nft_id,
        E_NFT_MISMATCH,
    );

    assert!(
        dual_ownership::collectible_owner(record) ==
            listing.seller,
        E_NOT_COLLECTIBLE_OWNER,
    );

    assert!(
        dual_ownership::principal_owner(record) ==
            listing.principal_owner_snapshot,
        E_PRINCIPAL_CHANGED,
    );

    assert!(
        dual_ownership::original_investor(record) ==
            listing.original_investor_snapshot,
        E_ORIGINAL_INVESTOR_CHANGED,
    );

    let nft =
        gold_nft::receive_from_marketplace_escrow(
            &mut listing.id,
            nft_receiving,
        );

    assert!(
        gold_nft::nft_id(&nft) ==
            listing.gold_nft_id,
        E_WRONG_LISTING_NFT,
    );

    assert!(
        gold_nft::backing_position_id(&nft) ==
            listing.backing_position_id,
        E_NFT_MISMATCH,
    );

    assert!(
        gold_nft::reserve_id(&nft) ==
            listing.reserve_id,
        E_RESERVE_MISMATCH,
    );

    let principal_before =
        dual_ownership::principal_owner(record);

    let original_investor_before =
        dual_ownership::original_investor(record);

    dual_ownership::record_collectible_transfer(
        registry,
        record,
        listing.gold_nft_id,
        listing.seller,
        buyer,
        ctx,
    );

    assert!(
        dual_ownership::collectible_owner(record) ==
            buyer,
        E_NOT_COLLECTIBLE_OWNER,
    );

    assert!(
        dual_ownership::principal_owner(record) ==
            principal_before,
        E_PRINCIPAL_CHANGED,
    );

    assert!(
        dual_ownership::original_investor(record) ==
            original_investor_before,
        E_ORIGINAL_INVESTOR_CHANGED,
    );

    let listing_id =
        object::id(&listing);

    let (
        marketplace_fee,
        seller_proceeds,
    ) =
        marketplace::
            settle_external_fixed_price_sale_to_fee_vault(
                access_control,
                marketplace,
                fee_vault_object,
                listing_id,
                listing.seller,
                buyer,
                listing.price,
                payment,
                ctx,
            );

    event::emit(GoldSaleCompleted {
        marketplace_id:
            listing.marketplace_id,
        listing_id,
        gold_nft_id:
            listing.gold_nft_id,
        backing_position_id:
            listing.backing_position_id,
        reserve_id:
            listing.reserve_id,
        dual_ownership_record_id:
            listing.dual_ownership_record_id,

        seller:
            listing.seller,
        buyer,

        original_investor:
            original_investor_before,
        principal_owner:
            principal_before,

        sale_price:
            listing.price,
        marketplace_fee,
        seller_proceeds,

        completed_at_epoch:
            tx_context::epoch(ctx),
    });

    let GoldFixedPriceListing {
        id,
        marketplace_id: _,
        gold_nft_id: _,
        backing_position_id: _,
        reserve_id: _,
        dual_ownership_record_id: _,
        seller: _,
        principal_owner_snapshot: _,
        original_investor_snapshot: _,
        price: _,
        created_at_epoch: _,
    } = listing;

    object::delete(id);

    gold_nft::transfer_gold_nft(
        access_control,
        nft,
        buyer,
        ctx,
    );
}

/// Read API.

public fun listing_id(
    listing: &GoldFixedPriceListing,
): ID {
    object::id(listing)
}

public fun listing_marketplace_id(
    listing: &GoldFixedPriceListing,
): ID {
    listing.marketplace_id
}

public fun listing_gold_nft_id(
    listing: &GoldFixedPriceListing,
): ID {
    listing.gold_nft_id
}

public fun listing_seller(
    listing: &GoldFixedPriceListing,
): address {
    listing.seller
}

public fun listing_price(
    listing: &GoldFixedPriceListing,
): u64 {
    listing.price
}

public fun listing_principal_owner_snapshot(
    listing: &GoldFixedPriceListing,
): address {
    listing.principal_owner_snapshot
}

/// ================================================================
/// Test-only listing inspection API
/// ================================================================

#[test_only]
public fun listing_backing_position_id_for_testing(
    listing: &GoldFixedPriceListing,
): ID {
    listing.backing_position_id
}

#[test_only]
public fun listing_reserve_id_for_testing(
    listing: &GoldFixedPriceListing,
): ID {
    listing.reserve_id
}

#[test_only]
public fun listing_record_id_for_testing(
    listing: &GoldFixedPriceListing,
): ID {
    listing.dual_ownership_record_id
}

#[test_only]
public fun listing_original_investor_for_testing(
    listing: &GoldFixedPriceListing,
): address {
    listing.original_investor_snapshot
}

#[test_only]
public fun listing_created_epoch_for_testing(
    listing: &GoldFixedPriceListing,
): u64 {
    listing.created_at_epoch
}
