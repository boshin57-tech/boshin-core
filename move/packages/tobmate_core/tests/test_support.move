#[test_only]
module tobmate_core::test_support;

use sui::object::{Self, ID};
use sui::tx_context::TxContext;

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::backing_position::{
    Self as backing_position,
    GoldBackingPosition,
};

use tobmate_core::gold_nft::{
    Self as gold_nft,
    GoldNFT,
    GoldNFTAdminCap,
    GoldNFTRegistry,
};

use tobmate_core::dual_ownership::{
    Self as dual_ownership,
    DualOwnershipRecord,
    DualOwnershipRegistry,
};

use tobmate_core::gold_reserve::{
    Self as gold_reserve,
    GoldReserve,
};

use tobmate_core::marketplace::{
    Self as marketplace,
    Marketplace,
};

const OWNER: address = @0xA11CE;
const CUSTODIAN: address = @0xC0570D1A;

const WEIGHT_MG: u64 = 31_103_476;
const PURITY_BPS: u64 = 9_999;

public fun owner(): address {
    OWNER
}

public fun custodian(): address {
    CUSTODIAN
}

public fun weight_mg(): u64 {
    WEIGHT_MG
}

public fun purity_bps(): u64 {
    PURITY_BPS
}

public fun reserve_id_one(): ID {
    object::id_from_address(@0xA001)
}

public fun reserve_id_two(): ID {
    object::id_from_address(@0xA002)
}

/// Creates one complete active dual-ownership fixture:
///
/// AccessControl
/// GoldNFTAdminCap
/// GoldNFTRegistry
/// DualOwnershipRegistry
/// GoldBackingPosition
/// GoldNFT
/// DualOwnershipRecord
public fun new_single_fixture(
    ctx: &mut TxContext,
): (
    AccessControl,
    GoldNFTAdminCap,
    GoldNFTRegistry,
    DualOwnershipRegistry,
    GoldBackingPosition,
    GoldNFT,
    DualOwnershipRecord,
) {
    let access =
        access_control::new_for_testing(ctx);

    let gold_nft_admin_cap =
        gold_nft::new_admin_cap_for_testing(ctx);

    let mut gold_nft_registry =
        gold_nft::new_registry_for_testing(ctx);

    let mut dual_registry =
        dual_ownership::new_registry_for_testing(ctx);

    let mut position =
        backing_position::new_for_testing(
            reserve_id_one(),
            CUSTODIAN,
            WEIGHT_MG,
            PURITY_BPS,
            ctx,
        );

    let nft =
        gold_nft::mint_for_testing(
            &mut gold_nft_registry,
            &mut position,
            OWNER,
            ctx,
        );

    let record =
        dual_ownership::create_record_for_testing(
            &mut dual_registry,
            &position,
            &nft,
            OWNER,
            OWNER,
            OWNER,
            ctx,
        );

    (
        access,
        gold_nft_admin_cap,
        gold_nft_registry,
        dual_registry,
        position,
        nft,
        record,
    )
}

/// Creates two independent positions and NFTs.
///
/// The ownership record references position_one and nft_one.
/// nft_two can therefore be supplied to test NFT mismatch handling.
public fun new_mismatch_fixture(
    ctx: &mut TxContext,
): (
    AccessControl,
    GoldNFTAdminCap,
    GoldNFTRegistry,
    DualOwnershipRegistry,
    GoldBackingPosition,
    GoldNFT,
    GoldBackingPosition,
    GoldNFT,
    DualOwnershipRecord,
) {
    let access =
        access_control::new_for_testing(ctx);

    let gold_nft_admin_cap =
        gold_nft::new_admin_cap_for_testing(ctx);

    let mut gold_nft_registry =
        gold_nft::new_registry_for_testing(ctx);

    let mut dual_registry =
        dual_ownership::new_registry_for_testing(ctx);

    let mut position_one =
        backing_position::new_for_testing(
            reserve_id_one(),
            CUSTODIAN,
            WEIGHT_MG,
            PURITY_BPS,
            ctx,
        );

    let nft_one =
        gold_nft::mint_for_testing(
            &mut gold_nft_registry,
            &mut position_one,
            OWNER,
            ctx,
        );

    let mut position_two =
        backing_position::new_for_testing(
            reserve_id_two(),
            CUSTODIAN,
            WEIGHT_MG,
            PURITY_BPS,
            ctx,
        );

    let nft_two =
        gold_nft::mint_for_testing(
            &mut gold_nft_registry,
            &mut position_two,
            OWNER,
            ctx,
        );

    let record =
        dual_ownership::create_record_for_testing(
            &mut dual_registry,
            &position_one,
            &nft_one,
            OWNER,
            OWNER,
            OWNER,
            ctx,
        );

    (
        access,
        gold_nft_admin_cap,
        gold_nft_registry,
        dual_registry,
        position_one,
        nft_one,
        position_two,
        nft_two,
        record,
    )
}

/// Creates a complete Gold Marketplace fixture using a real
/// GoldReserve object ID.
///
/// The resulting linkage is:
///
/// GoldReserve.id
///     == GoldBackingPosition.reserve_id
///     == GoldNFT.reserve_id
public fun new_gold_marketplace_fixture(
    marketplace_fee_bps: u64,
    fee_recipient: address,
    ctx: &mut TxContext,
): (
    AccessControl,
    Marketplace,
    GoldReserve,
    GoldNFTAdminCap,
    GoldNFTRegistry,
    DualOwnershipRegistry,
    GoldBackingPosition,
    GoldNFT,
    DualOwnershipRecord,
) {
    let access =
        access_control::new_for_testing(ctx);

    let marketplace =
        marketplace::new_for_testing(
            marketplace_fee_bps,
            fee_recipient,
            ctx,
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            WEIGHT_MG,
            PURITY_BPS,
            ctx,
        );

    let reserve_id =
        gold_reserve::reserve_id(&reserve);

    let gold_nft_admin_cap =
        gold_nft::new_admin_cap_for_testing(ctx);

    let mut gold_nft_registry =
        gold_nft::new_registry_for_testing(ctx);

    let mut dual_registry =
        dual_ownership::new_registry_for_testing(ctx);

    let mut position =
        backing_position::new_for_testing(
            reserve_id,
            CUSTODIAN,
            WEIGHT_MG,
            PURITY_BPS,
            ctx,
        );

    let nft =
        gold_nft::mint_for_testing(
            &mut gold_nft_registry,
            &mut position,
            OWNER,
            ctx,
        );

    let record =
        dual_ownership::create_record_for_testing(
            &mut dual_registry,
            &position,
            &nft,
            OWNER,
            OWNER,
            OWNER,
            ctx,
        );

    (
        access,
        marketplace,
        reserve,
        gold_nft_admin_cap,
        gold_nft_registry,
        dual_registry,
        position,
        nft,
        record,
    )
}
