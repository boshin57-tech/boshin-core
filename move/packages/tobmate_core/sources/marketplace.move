module tobmate_core::marketplace;

use sui::balance;
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

//
// Constants
//

const BPS_DENOMINATOR: u64 = 10_000;
const MAX_MARKETPLACE_FEE_BPS: u64 = 1_000;

//
// Error codes
//

const E_NOT_MARKETPLACE_ADMIN: u64 = 1;
const E_MARKETPLACE_PAUSED: u64 = 2;
const E_INVALID_PRICE: u64 = 3;
const E_INVALID_FEE: u64 = 4;
const E_WRONG_MARKETPLACE: u64 = 5;
const E_NOT_LISTING_SELLER: u64 = 6;
const E_SELLER_CANNOT_BUY: u64 = 7;
const E_INCORRECT_PAYMENT: u64 = 8;
const E_DUPLICATE_PAUSE_STATE: u64 = 9;
const E_INVALID_FEE_RECIPIENT: u64 = 10;

//
// Core objects
//

/// Administrative capability for one Marketplace object.
public struct MarketplaceAdminCap has key, store {
    id: UID,
    marketplace_id: ID,
}

/// Shared marketplace configuration and accounting object.
public struct Marketplace has key {
    id: UID,

    version: u64,
    paused: bool,

    marketplace_fee_bps: u64,
    fee_recipient: address,

    listing_count: u64,
    active_listing_count: u64,
    completed_sale_count: u64,
    cancelled_listing_count: u64,

    total_sales_volume: u64,
    total_marketplace_fees: u64,
}

/// Generic fixed-price escrow listing.
///
/// Asset may be:
///
/// - GoldCoinNFT
/// - DiamondNFT
/// - RubyNFT
/// - JewelryNFT
/// - ArtNFT
/// - another approved `key + store` object.
///
/// Payment is represented by the selected Sui Coin type.
public struct FixedPriceListing<
    Asset: key + store,
    phantom Payment,
> has key {
    id: UID,

    marketplace_id: ID,
    seller: address,

    asset: Asset,
    price: u64,

    created_at_epoch: u64,
}

//
// Events
//

public struct MarketplaceCreated has copy, drop {
    marketplace_id: ID,
    administrator: address,
    fee_recipient: address,
    marketplace_fee_bps: u64,
}

public struct FixedPriceListingCreated has copy, drop {
    marketplace_id: ID,
    listing_id: ID,
    seller: address,
    price: u64,
}

public struct FixedPriceListingCancelled has copy, drop {
    marketplace_id: ID,
    listing_id: ID,
    seller: address,
}

public struct FixedPriceSaleCompleted has copy, drop {
    marketplace_id: ID,
    listing_id: ID,
    seller: address,
    buyer: address,
    sale_price: u64,
    marketplace_fee: u64,
    seller_proceeds: u64,
}

public struct MarketplacePauseChanged has copy, drop {
    marketplace_id: ID,
    paused: bool,
}

public struct MarketplaceFeeChanged has copy, drop {
    marketplace_id: ID,
    old_fee_bps: u64,
    new_fee_bps: u64,
}

public struct MarketplaceFeeRecipientChanged has copy, drop {
    marketplace_id: ID,
    old_recipient: address,
    new_recipient: address,
}

//
// Marketplace creation
//

/// Creates the shared Marketplace object and transfers its AdminCap
/// to the transaction sender.
public fun create_marketplace(
    marketplace_fee_bps: u64,
    fee_recipient: address,
    ctx: &mut TxContext,
) {
    assert!(
        marketplace_fee_bps <= MAX_MARKETPLACE_FEE_BPS,
        E_INVALID_FEE,
    );

    assert!(
        fee_recipient != @0x0,
        E_INVALID_FEE_RECIPIENT,
    );

    let administrator = tx_context::sender(ctx);

    let marketplace = Marketplace {
        id: object::new(ctx),

        version: 1,
        paused: false,

        marketplace_fee_bps,
        fee_recipient,

        listing_count: 0,
        active_listing_count: 0,
        completed_sale_count: 0,
        cancelled_listing_count: 0,

        total_sales_volume: 0,
        total_marketplace_fees: 0,
    };

    let marketplace_id = object::id(&marketplace);

    let admin_cap = MarketplaceAdminCap {
        id: object::new(ctx),
        marketplace_id,
    };

    event::emit(MarketplaceCreated {
        marketplace_id,
        administrator,
        fee_recipient,
        marketplace_fee_bps,
    });

    transfer::public_transfer(admin_cap, administrator);
    transfer::share_object(marketplace);
}

//
// Fixed-price listing
//

/// Places any transferable `key + store` asset into a shared escrow
/// listing.
///
/// The Marketplace Core does not assume that the asset is gold.
/// Asset-specific validation is performed by a separate adapter.
public fun create_fixed_price_listing<
    Asset: key + store,
    Payment,
>(
    marketplace: &mut Marketplace,
    asset: Asset,
    price: u64,
    ctx: &mut TxContext,
) {
    assert!(!marketplace.paused, E_MARKETPLACE_PAUSED);
    assert!(price > 0, E_INVALID_PRICE);

    let seller = tx_context::sender(ctx);

    let listing = FixedPriceListing<Asset, Payment> {
        id: object::new(ctx),
        marketplace_id: object::id(marketplace),
        seller,
        asset,
        price,
        created_at_epoch: tx_context::epoch(ctx),
    };

    let listing_id = object::id(&listing);

    marketplace.listing_count = marketplace.listing_count + 1;
    marketplace.active_listing_count =
        marketplace.active_listing_count + 1;

    event::emit(FixedPriceListingCreated {
        marketplace_id: object::id(marketplace),
        listing_id,
        seller,
        price,
    });

    transfer::share_object(listing);
}

/// Cancels an active listing and returns the escrowed asset to the
/// original seller.
public fun cancel_fixed_price_listing<
    Asset: key + store,
    Payment,
>(
    marketplace: &mut Marketplace,
    listing: FixedPriceListing<Asset, Payment>,
    ctx: &mut TxContext,
) {
    assert!(!marketplace.paused, E_MARKETPLACE_PAUSED);

    let FixedPriceListing {
        id,
        marketplace_id,
        seller,
        asset,
        price: _,
        created_at_epoch: _,
    } = listing;

    assert!(
        marketplace_id == object::id(marketplace),
        E_WRONG_MARKETPLACE,
    );

    assert!(
        tx_context::sender(ctx) == seller,
        E_NOT_LISTING_SELLER,
    );

    marketplace.active_listing_count =
        marketplace.active_listing_count - 1;

    marketplace.cancelled_listing_count =
        marketplace.cancelled_listing_count + 1;

    let listing_id = object::uid_to_inner(&id);

    event::emit(FixedPriceListingCancelled {
        marketplace_id,
        listing_id,
        seller,
    });

    object::delete(id);
    transfer::public_transfer(asset, seller);
}

/// Purchases an escrowed asset using the exact fixed price.
///
/// Settlement:
///
/// payment
///   ├── marketplace fee → configured fee recipient
///   └── seller proceeds → seller
///
/// asset → buyer
public fun buy_fixed_price<
    Asset: key + store,
    Payment,
>(
    marketplace: &mut Marketplace,
    listing: FixedPriceListing<Asset, Payment>,
    payment: Coin<Payment>,
    ctx: &mut TxContext,
) {
    assert!(!marketplace.paused, E_MARKETPLACE_PAUSED);

    let buyer = tx_context::sender(ctx);

    let FixedPriceListing {
        id,
        marketplace_id,
        seller,
        asset,
        price,
        created_at_epoch: _,
    } = listing;

    assert!(
        marketplace_id == object::id(marketplace),
        E_WRONG_MARKETPLACE,
    );

    assert!(buyer != seller, E_SELLER_CANNOT_BUY);

    assert!(
        coin::value(&payment) == price,
        E_INCORRECT_PAYMENT,
    );

    let marketplace_fee =
        calculate_marketplace_fee(
            price,
            marketplace.marketplace_fee_bps,
        );

    let seller_proceeds = price - marketplace_fee;

    let mut payment_balance = coin::into_balance(payment);

    let marketplace_fee_balance =
        balance::split(
            &mut payment_balance,
            marketplace_fee,
        );

    let seller_payment =
        coin::from_balance(payment_balance, ctx);

    let marketplace_fee_payment =
        coin::from_balance(marketplace_fee_balance, ctx);

    marketplace.active_listing_count =
        marketplace.active_listing_count - 1;

    marketplace.completed_sale_count =
        marketplace.completed_sale_count + 1;

    marketplace.total_sales_volume =
        marketplace.total_sales_volume + price;

    marketplace.total_marketplace_fees =
        marketplace.total_marketplace_fees + marketplace_fee;

    let listing_id = object::uid_to_inner(&id);

    event::emit(FixedPriceSaleCompleted {
        marketplace_id,
        listing_id,
        seller,
        buyer,
        sale_price: price,
        marketplace_fee,
        seller_proceeds,
    });

    object::delete(id);

    transfer::public_transfer(asset, buyer);
    transfer::public_transfer(seller_payment, seller);

    transfer::public_transfer(
        marketplace_fee_payment,
        marketplace.fee_recipient,
    );
}

//
// Administration
//

public fun set_paused(
    admin_cap: &MarketplaceAdminCap,
    marketplace: &mut Marketplace,
    paused: bool,
) {
    assert_admin(admin_cap, marketplace);

    assert!(
        marketplace.paused != paused,
        E_DUPLICATE_PAUSE_STATE,
    );

    marketplace.paused = paused;

    event::emit(MarketplacePauseChanged {
        marketplace_id: object::id(marketplace),
        paused,
    });
}

public fun set_marketplace_fee(
    admin_cap: &MarketplaceAdminCap,
    marketplace: &mut Marketplace,
    new_fee_bps: u64,
) {
    assert_admin(admin_cap, marketplace);

    assert!(
        new_fee_bps <= MAX_MARKETPLACE_FEE_BPS,
        E_INVALID_FEE,
    );

    let old_fee_bps = marketplace.marketplace_fee_bps;

    marketplace.marketplace_fee_bps = new_fee_bps;

    event::emit(MarketplaceFeeChanged {
        marketplace_id: object::id(marketplace),
        old_fee_bps,
        new_fee_bps,
    });
}

public fun set_fee_recipient(
    admin_cap: &MarketplaceAdminCap,
    marketplace: &mut Marketplace,
    new_recipient: address,
) {
    assert_admin(admin_cap, marketplace);

    assert!(
        new_recipient != @0x0,
        E_INVALID_FEE_RECIPIENT,
    );

    let old_recipient = marketplace.fee_recipient;
    marketplace.fee_recipient = new_recipient;

    event::emit(MarketplaceFeeRecipientChanged {
        marketplace_id: object::id(marketplace),
        old_recipient,
        new_recipient,
    });
}

public fun update_version(
    admin_cap: &MarketplaceAdminCap,
    marketplace: &mut Marketplace,
    new_version: u64,
) {
    assert_admin(admin_cap, marketplace);
    marketplace.version = new_version;
}

//
// Fee calculation
//

public fun calculate_marketplace_fee(
    sale_price: u64,
    fee_bps: u64,
): u64 {
    (((sale_price as u128) * (fee_bps as u128))
        / (BPS_DENOMINATOR as u128)) as u64
}

//
// Internal validation
//

fun assert_admin(
    admin_cap: &MarketplaceAdminCap,
    marketplace: &Marketplace,
) {
    assert!(
        admin_cap.marketplace_id == object::id(marketplace),
        E_NOT_MARKETPLACE_ADMIN,
    );
}

//
// Marketplace read API
//

public fun marketplace_id(
    marketplace: &Marketplace,
): ID {
    object::id(marketplace)
}

public fun admin_marketplace_id(
    admin_cap: &MarketplaceAdminCap,
): ID {
    admin_cap.marketplace_id
}

public fun version(
    marketplace: &Marketplace,
): u64 {
    marketplace.version
}

public fun is_paused(
    marketplace: &Marketplace,
): bool {
    marketplace.paused
}

public fun marketplace_fee_bps(
    marketplace: &Marketplace,
): u64 {
    marketplace.marketplace_fee_bps
}

public fun fee_recipient(
    marketplace: &Marketplace,
): address {
    marketplace.fee_recipient
}

public fun listing_count(
    marketplace: &Marketplace,
): u64 {
    marketplace.listing_count
}

public fun active_listing_count(
    marketplace: &Marketplace,
): u64 {
    marketplace.active_listing_count
}

public fun completed_sale_count(
    marketplace: &Marketplace,
): u64 {
    marketplace.completed_sale_count
}

public fun cancelled_listing_count(
    marketplace: &Marketplace,
): u64 {
    marketplace.cancelled_listing_count
}

public fun total_sales_volume(
    marketplace: &Marketplace,
): u64 {
    marketplace.total_sales_volume
}

public fun total_marketplace_fees(
    marketplace: &Marketplace,
): u64 {
    marketplace.total_marketplace_fees
}

//
// Listing read API
//

public fun listing_id<
    Asset: key + store,
    Payment,
>(
    listing: &FixedPriceListing<Asset, Payment>,
): ID {
    object::id(listing)
}

public fun listing_marketplace_id<
    Asset: key + store,
    Payment,
>(
    listing: &FixedPriceListing<Asset, Payment>,
): ID {
    listing.marketplace_id
}

public fun listing_seller<
    Asset: key + store,
    Payment,
>(
    listing: &FixedPriceListing<Asset, Payment>,
): address {
    listing.seller
}

public fun listing_price<
    Asset: key + store,
    Payment,
>(
    listing: &FixedPriceListing<Asset, Payment>,
): u64 {
    listing.price
}

public fun listing_created_at_epoch<
    Asset: key + store,
    Payment,
>(
    listing: &FixedPriceListing<Asset, Payment>,
): u64 {
    listing.created_at_epoch
}

public fun max_marketplace_fee_bps(): u64 {
    MAX_MARKETPLACE_FEE_BPS
}

public fun bps_denominator(): u64 {
    BPS_DENOMINATOR
}

/// ================================================================
/// Package integration API
/// ================================================================

/// Registers a new asset-specific listing.
///
/// The asset-specific adapter remains responsible for creating and
/// sharing its listing object and escrowed asset.
public(package) fun record_external_listing_created(
    marketplace: &mut Marketplace,
) {
    assert!(!marketplace.paused, E_MARKETPLACE_PAUSED);

    marketplace.listing_count =
        marketplace.listing_count + 1;

    marketplace.active_listing_count =
        marketplace.active_listing_count + 1;
}

/// Registers cancellation of an asset-specific listing.
public(package) fun record_external_listing_cancelled(
    marketplace: &mut Marketplace,
) {
    assert!(!marketplace.paused, E_MARKETPLACE_PAUSED);
    assert!(
        marketplace.active_listing_count > 0,
        E_WRONG_MARKETPLACE,
    );

    marketplace.active_listing_count =
        marketplace.active_listing_count - 1;

    marketplace.cancelled_listing_count =
        marketplace.cancelled_listing_count + 1;
}

/// Atomically settles payment and records an asset-specific sale.
public(package) fun settle_external_fixed_price_sale<Payment>(
    marketplace: &mut Marketplace,
    listing_id: ID,
    seller: address,
    buyer: address,
    price: u64,
    payment: Coin<Payment>,
    ctx: &mut TxContext,
) {
    assert!(!marketplace.paused, E_MARKETPLACE_PAUSED);
    assert!(buyer != seller, E_SELLER_CANNOT_BUY);

    assert!(
        coin::value(&payment) == price,
        E_INCORRECT_PAYMENT,
    );

    assert!(
        marketplace.active_listing_count > 0,
        E_WRONG_MARKETPLACE,
    );

    let marketplace_fee =
        calculate_marketplace_fee(
            price,
            marketplace.marketplace_fee_bps,
        );

    let seller_proceeds = price - marketplace_fee;
    let mut payment_balance = coin::into_balance(payment);

    let marketplace_fee_balance =
        balance::split(
            &mut payment_balance,
            marketplace_fee,
        );

    let seller_payment =
        coin::from_balance(payment_balance, ctx);

    let marketplace_fee_payment =
        coin::from_balance(
            marketplace_fee_balance,
            ctx,
        );

    marketplace.active_listing_count =
        marketplace.active_listing_count - 1;

    marketplace.completed_sale_count =
        marketplace.completed_sale_count + 1;

    marketplace.total_sales_volume =
        marketplace.total_sales_volume + price;

    marketplace.total_marketplace_fees =
        marketplace.total_marketplace_fees +
            marketplace_fee;

    event::emit(FixedPriceSaleCompleted {
        marketplace_id: object::id(marketplace),
        listing_id,
        seller,
        buyer,
        sale_price: price,
        marketplace_fee,
        seller_proceeds,
    });

    transfer::public_transfer(
        seller_payment,
        seller,
    );

    transfer::public_transfer(
        marketplace_fee_payment,
        marketplace.fee_recipient,
    );
}


/// Atomically settles a SUI-denominated external sale.
///
/// Unlike the generic settlement path, the marketplace fee is not
/// transferred to a fee-recipient address. It is deposited directly
/// into the protocol FeeVault under the marketplace-fee category.
///
/// Payment conservation:
///
/// payment = seller proceeds + marketplace fee
public(package) fun settle_external_fixed_price_sale_to_fee_vault(
    access_control:
        &tobmate_core::access_control::AccessControl,
    marketplace: &mut Marketplace,
    fee_vault_object:
        &mut tobmate_core::fee_vault::FeeVault,
    listing_id: ID,
    seller: address,
    buyer: address,
    price: u64,
    payment: Coin<sui::sui::SUI>,
    ctx: &mut TxContext,
): (u64, u64) {
    assert!(
        !marketplace.paused,
        E_MARKETPLACE_PAUSED,
    );

    assert!(
        buyer != seller,
        E_SELLER_CANNOT_BUY,
    );

    assert!(
        coin::value(&payment) == price,
        E_INCORRECT_PAYMENT,
    );

    assert!(
        marketplace.active_listing_count > 0,
        E_WRONG_MARKETPLACE,
    );

    let marketplace_fee =
        calculate_marketplace_fee(
            price,
            marketplace.marketplace_fee_bps,
        );

    let seller_proceeds =
        price - marketplace_fee;

    let mut payment_balance =
        coin::into_balance(payment);

    if (marketplace_fee > 0) {
        let fee_balance =
            balance::split(
                &mut payment_balance,
                marketplace_fee,
            );

        let fee_coin =
            coin::from_balance(
                fee_balance,
                ctx,
            );

        tobmate_core::fee_vault::collect_fee(
            access_control,
            fee_vault_object,
            tobmate_core::fee_vault::fee_marketplace(),
            fee_coin,
            ctx,
        );
    };

    let seller_payment =
        coin::from_balance(
            payment_balance,
            ctx,
        );

    marketplace.active_listing_count =
        marketplace.active_listing_count - 1;

    marketplace.completed_sale_count =
        marketplace.completed_sale_count + 1;

    marketplace.total_sales_volume =
        marketplace.total_sales_volume + price;

    marketplace.total_marketplace_fees =
        marketplace.total_marketplace_fees
            + marketplace_fee;

    event::emit(FixedPriceSaleCompleted {
        marketplace_id:
            object::id(marketplace),
        listing_id,
        seller,
        buyer,
        sale_price: price,
        marketplace_fee,
        seller_proceeds,
    });

    transfer::public_transfer(
        seller_payment,
        seller,
    );

    (
        marketplace_fee,
        seller_proceeds,
    )
}

#[test_only]
public fun listing_count_for_testing(
    marketplace: &Marketplace,
): u64 {
    marketplace.listing_count
}

#[test_only]
public fun active_listing_count_for_testing(
    marketplace: &Marketplace,
): u64 {
    marketplace.active_listing_count
}

#[test_only]
public fun completed_sale_count_for_testing(
    marketplace: &Marketplace,
): u64 {
    marketplace.completed_sale_count
}

#[test_only]
public fun cancelled_listing_count_for_testing(
    marketplace: &Marketplace,
): u64 {
    marketplace.cancelled_listing_count
}

#[test_only]
public fun total_sales_volume_for_testing(
    marketplace: &Marketplace,
): u64 {
    marketplace.total_sales_volume
}

#[test_only]
public fun total_marketplace_fees_for_testing(
    marketplace: &Marketplace,
): u64 {
    marketplace.total_marketplace_fees
}

/// ================================================================
/// Test-only object construction and destruction
/// ================================================================

#[test_only]
public fun new_for_testing(
    marketplace_fee_bps: u64,
    fee_recipient: address,
    ctx: &mut TxContext,
): Marketplace {
    assert!(
        marketplace_fee_bps <= MAX_MARKETPLACE_FEE_BPS,
        E_INVALID_FEE,
    );

    assert!(
        fee_recipient != @0x0,
        E_INVALID_FEE_RECIPIENT,
    );

    Marketplace {
        id: object::new(ctx),
        version: 1,
        paused: false,
        marketplace_fee_bps,
        fee_recipient,
        listing_count: 0,
        active_listing_count: 0,
        completed_sale_count: 0,
        cancelled_listing_count: 0,
        total_sales_volume: 0,
        total_marketplace_fees: 0,
    }
}

#[test_only]
public fun destroy_for_testing(
    marketplace: Marketplace,
) {
    let Marketplace {
        id,
        version: _,
        paused: _,
        marketplace_fee_bps: _,
        fee_recipient: _,
        listing_count: _,
        active_listing_count: _,
        completed_sale_count: _,
        cancelled_listing_count: _,
        total_sales_volume: _,
        total_marketplace_fees: _,
    } = marketplace;

    object::delete(id);
}
