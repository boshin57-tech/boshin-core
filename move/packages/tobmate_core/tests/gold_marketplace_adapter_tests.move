#[test_only]
module tobmate_core::gold_marketplace_adapter_tests;

use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{Self as access_control};
use tobmate_core::backing_position::{Self as backing_position};
use tobmate_core::dual_ownership::{Self as dual_ownership};
use tobmate_core::gold_marketplace_adapter::{
    Self as gold_marketplace_adapter,
    GoldFixedPriceListing,
};
use tobmate_core::gold_nft::{Self as gold_nft};
use tobmate_core::gold_reserve::{Self as gold_reserve};
use tobmate_core::marketplace::{Self as marketplace};
use tobmate_core::test_support;

const OWNER: address = @0xA11CE;
const OTHER: address = @0xB0B;
const FEE_RECIPIENT: address = @0xFEE;

const MARKETPLACE_FEE_BPS: u64 = 250;
const LISTING_PRICE: u64 = 1_000_000;

/// Adapter abort codes.
const E_NFT_FROZEN: u64 = 4;
const E_RESERVE_NOT_ACTIVE: u64 = 6;
const E_NOT_COLLECTIBLE_OWNER: u64 = 9;

fun destroy_non_nft_fixture(
    access: tobmate_core::access_control::AccessControl,
    marketplace_object: tobmate_core::marketplace::Marketplace,
    reserve: tobmate_core::gold_reserve::GoldReserve,
    admin_cap: tobmate_core::gold_nft::GoldNFTAdminCap,
    nft_registry: tobmate_core::gold_nft::GoldNFTRegistry,
    mut dual_registry: tobmate_core::dual_ownership::DualOwnershipRegistry,
    position: tobmate_core::backing_position::GoldBackingPosition,
    record: tobmate_core::dual_ownership::DualOwnershipRecord,
) {
    dual_ownership::destroy_record_for_testing(
        &mut dual_registry,
        record,
    );
    dual_ownership::destroy_registry_for_testing(dual_registry);

    gold_nft::destroy_registry_for_testing(nft_registry);
    gold_nft::destroy_admin_cap_for_testing(admin_cap);

    backing_position::destroy_linked_for_testing(position);
    gold_reserve::destroy_reserve_for_testing(reserve);
    marketplace::destroy_for_testing(marketplace_object);
    access_control::destroy_for_testing(access);
}

fun destroy_complete_fixture(
    access: tobmate_core::access_control::AccessControl,
    marketplace_object: tobmate_core::marketplace::Marketplace,
    reserve: tobmate_core::gold_reserve::GoldReserve,
    admin_cap: tobmate_core::gold_nft::GoldNFTAdminCap,
    nft_registry: tobmate_core::gold_nft::GoldNFTRegistry,
    dual_registry: tobmate_core::dual_ownership::DualOwnershipRegistry,
    position: tobmate_core::backing_position::GoldBackingPosition,
    nft: tobmate_core::gold_nft::GoldNFT,
    record: tobmate_core::dual_ownership::DualOwnershipRecord,
) {
    gold_nft::destroy_nft_for_testing(nft);

    destroy_non_nft_fixture(
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        record,
    );
}

/// Test 63:
/// A completely linked active Gold asset is tradeable.
#[test]
fun assert_gold_tradeable_success() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    gold_marketplace_adapter::assert_gold_tradeable(
        &marketplace_object,
        &reserve,
        &position,
        &nft,
        &record,
        OWNER,
    );

    destroy_complete_fixture(
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        nft,
        record,
    );

    test_scenario::end(scenario);
}

/// Test 64:
/// A valid NFT can be placed into object-owned marketplace escrow.
#[test]
fun create_gold_fixed_price_listing_success() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        access,
        mut marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    gold_marketplace_adapter::create_gold_fixed_price_listing(
        &mut marketplace_object,
        &reserve,
        &position,
        nft,
        &record,
        LISTING_PRICE,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        marketplace::listing_count_for_testing(
            &marketplace_object,
        ) == 1,
        100,
    );

    assert!(
        marketplace::active_listing_count_for_testing(
            &marketplace_object,
        ) == 1,
        101,
    );

    destroy_non_nft_fixture(
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        record,
    );

    test_scenario::end(scenario);
}

/// Test 65:
/// Shared listing metadata exactly matches the fixture objects.
#[test]
fun listing_metadata_matches_fixture() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        access,
        mut marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    let expected_marketplace_id =
        marketplace::marketplace_id(&marketplace_object);

    let expected_nft_id =
        gold_nft::nft_id(&nft);

    let expected_position_id =
        backing_position::position_id(&position);

    let expected_reserve_id =
        gold_reserve::reserve_id(&reserve);

    let expected_record_id =
        dual_ownership::record_id(&record);

    gold_marketplace_adapter::create_gold_fixed_price_listing(
        &mut marketplace_object,
        &reserve,
        &position,
        nft,
        &record,
        LISTING_PRICE,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(&mut scenario, OWNER);

    let listing =
        test_scenario::take_shared<GoldFixedPriceListing>(
            &scenario,
        );

    assert!(
        gold_marketplace_adapter::listing_marketplace_id(
            &listing,
        ) == expected_marketplace_id,
        200,
    );

    assert!(
        gold_marketplace_adapter::listing_gold_nft_id(
            &listing,
        ) == expected_nft_id,
        201,
    );

    assert!(
        gold_marketplace_adapter::
            listing_backing_position_id_for_testing(
                &listing,
            ) == expected_position_id,
        202,
    );

    assert!(
        gold_marketplace_adapter::
            listing_reserve_id_for_testing(
                &listing,
            ) == expected_reserve_id,
        203,
    );

    assert!(
        gold_marketplace_adapter::
            listing_record_id_for_testing(
                &listing,
            ) == expected_record_id,
        204,
    );

    assert!(
        gold_marketplace_adapter::listing_seller(
            &listing,
        ) == OWNER,
        205,
    );

    assert!(
        gold_marketplace_adapter::listing_price(
            &listing,
        ) == LISTING_PRICE,
        206,
    );

    test_scenario::return_shared(listing);

    destroy_non_nft_fixture(
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        record,
    );

    test_scenario::end(scenario);
}

/// Test 66:
/// Listing creation updates only listing-related Marketplace counters.
#[test]
fun marketplace_listing_counter_incremented() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        access,
        mut marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    gold_marketplace_adapter::create_gold_fixed_price_listing(
        &mut marketplace_object,
        &reserve,
        &position,
        nft,
        &record,
        LISTING_PRICE,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        marketplace::listing_count_for_testing(
            &marketplace_object,
        ) == 1,
        300,
    );

    assert!(
        marketplace::active_listing_count_for_testing(
            &marketplace_object,
        ) == 1,
        301,
    );

    assert!(
        marketplace::completed_sale_count_for_testing(
            &marketplace_object,
        ) == 0,
        302,
    );

    assert!(
        marketplace::cancelled_listing_count_for_testing(
            &marketplace_object,
        ) == 0,
        303,
    );

    assert!(
        marketplace::total_sales_volume_for_testing(
            &marketplace_object,
        ) == 0,
        304,
    );

    assert!(
        marketplace::total_marketplace_fees_for_testing(
            &marketplace_object,
        ) == 0,
        305,
    );

    destroy_non_nft_fixture(
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        record,
    );

    test_scenario::end(scenario);
}

/// Test 67:
/// A suspended physical reserve cannot support a marketplace trade.
#[test]
#[expected_failure(
    abort_code = E_RESERVE_NOT_ACTIVE,
    location = tobmate_core::gold_marketplace_adapter,
)]
fun reserve_suspended_aborts() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        _access,
        marketplace_object,
        mut reserve,
        _admin_cap,
        _nft_registry,
        _dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    gold_reserve::suspend_for_testing(&mut reserve);

    gold_marketplace_adapter::assert_gold_tradeable(
        &marketplace_object,
        &reserve,
        &position,
        &nft,
        &record,
        OWNER,
    );

    abort 900
}

/// Test 68:
/// A frozen GoldNFT cannot be listed or traded.
#[test]
#[expected_failure(
    abort_code = E_NFT_FROZEN,
    location = tobmate_core::gold_marketplace_adapter,
)]
fun nft_frozen_aborts() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        _access,
        marketplace_object,
        reserve,
        _admin_cap,
        _nft_registry,
        _dual_registry,
        position,
        mut nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    gold_nft::freeze_for_testing(&mut nft);

    gold_marketplace_adapter::assert_gold_tradeable(
        &marketplace_object,
        &reserve,
        &position,
        &nft,
        &record,
        OWNER,
    );

    abort 901
}

/// Test 69:
/// The expected seller must be the current collectible owner.
#[test]
#[expected_failure(
    abort_code = E_NOT_COLLECTIBLE_OWNER,
    location = tobmate_core::gold_marketplace_adapter,
)]
fun seller_mismatch_aborts() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        _access,
        marketplace_object,
        reserve,
        _admin_cap,
        _nft_registry,
        _dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    gold_marketplace_adapter::assert_gold_tradeable(
        &marketplace_object,
        &reserve,
        &position,
        &nft,
        &record,
        OTHER,
    );

    abort 902
}

/// Test 70:
/// Listing creation snapshots—but never changes—principal ownership.
#[test]
fun principal_owner_unchanged_after_listing() {
    let mut scenario = test_scenario::begin(OWNER);

    let (
        access,
        mut marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        nft,
        record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    let principal_before =
        dual_ownership::principal_owner(&record);

    let original_investor_before =
        dual_ownership::original_investor(&record);

    gold_marketplace_adapter::create_gold_fixed_price_listing(
        &mut marketplace_object,
        &reserve,
        &position,
        nft,
        &record,
        LISTING_PRICE,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        dual_ownership::principal_owner(&record)
            == principal_before,
        400,
    );

    assert!(
        dual_ownership::original_investor(&record)
            == original_investor_before,
        401,
    );

    test_scenario::next_tx(&mut scenario, OWNER);

    let listing =
        test_scenario::take_shared<GoldFixedPriceListing>(
            &scenario,
        );

    assert!(
        gold_marketplace_adapter::
            listing_principal_owner_snapshot(
                &listing,
            ) == principal_before,
        402,
    );

    assert!(
        gold_marketplace_adapter::
            listing_original_investor_for_testing(
                &listing,
            ) == original_investor_before,
        403,
    );

    test_scenario::return_shared(listing);

    destroy_non_nft_fixture(
        access,
        marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        dual_registry,
        position,
        record,
    );

    test_scenario::end(scenario);
}

/// Test 71:
/// A buyer purchases an escrowed GoldNFT with exact SUI payment.
///
/// Verifies:
/// - exact payment settlement;
/// - seller net proceeds;
/// - marketplace fee calculation;
/// - FeeVault accounting;
/// - Marketplace counters;
/// - NFT transfer to buyer;
/// - collectible ownership transfer;
/// - principal ownership invariance;
/// - original-investor invariance.
#[test]
fun gold_purchase_fee_vault_and_ownership_integration_succeeds() {
    use sui::coin::{Self as coin, Coin};
    use sui::sui::SUI;

    use tobmate_core::fee_vault::{Self as fee_vault};

    let mut scenario = test_scenario::begin(OWNER);

    let (
        access,
        mut marketplace_object,
        reserve,
        admin_cap,
        nft_registry,
        mut dual_registry,
        position,
        nft,
        mut record,
    ) = test_support::new_gold_marketplace_fixture(
        MARKETPLACE_FEE_BPS,
        FEE_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let nft_id = gold_nft::nft_id(&nft);

    let principal_before =
        dual_ownership::principal_owner(&record);

    let original_investor_before =
        dual_ownership::original_investor(&record);

    gold_marketplace_adapter::create_gold_fixed_price_listing(
        &mut marketplace_object,
        &reserve,
        &position,
        nft,
        &record,
        LISTING_PRICE,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(&mut scenario, OTHER);

    let listing =
        test_scenario::take_shared<GoldFixedPriceListing>(
            &scenario,
        );

    let receiving =
        test_scenario::receiving_ticket_by_id<
            tobmate_core::gold_nft::GoldNFT,
        >(nft_id);

    let payment =
        coin::mint_for_testing<SUI>(
            LISTING_PRICE,
            test_scenario::ctx(&mut scenario),
        );

    gold_marketplace_adapter::
        buy_gold_fixed_price_with_fee_vault(
            &access,
            &mut marketplace_object,
            &mut vault,
            listing,
            receiving,
            &mut dual_registry,
            &mut record,
            payment,
            test_scenario::ctx(&mut scenario),
        );

    let expected_fee =
        marketplace::calculate_marketplace_fee(
            LISTING_PRICE,
            MARKETPLACE_FEE_BPS,
        );

    let expected_seller_proceeds =
        LISTING_PRICE - expected_fee;

    assert!(expected_fee == 25_000, 7100);
    assert!(expected_seller_proceeds == 975_000, 7101);

    assert!(
        fee_vault::pending_balance(&vault)
            == expected_fee,
        7102,
    );

    assert!(
        fee_vault::marketplace_fees(&vault)
            == expected_fee,
        7103,
    );

    assert!(
        fee_vault::total_collected(&vault)
            == expected_fee,
        7104,
    );

    assert!(
        fee_vault::collection_count(&vault) == 1,
        7105,
    );

    assert!(
        marketplace::active_listing_count_for_testing(
            &marketplace_object,
        ) == 0,
        7106,
    );

    assert!(
        marketplace::completed_sale_count_for_testing(
            &marketplace_object,
        ) == 1,
        7107,
    );

    assert!(
        marketplace::total_sales_volume_for_testing(
            &marketplace_object,
        ) == LISTING_PRICE,
        7108,
    );

    assert!(
        marketplace::total_marketplace_fees_for_testing(
            &marketplace_object,
        ) == expected_fee,
        7109,
    );

    assert!(
        dual_ownership::collectible_owner(&record)
            == OTHER,
        7110,
    );

    assert!(
        dual_ownership::principal_owner(&record)
            == principal_before,
        7111,
    );

    assert!(
        dual_ownership::original_investor(&record)
            == original_investor_before,
        7112,
    );

    fee_vault::assert_accounting_invariant(&vault);

    // Complete the buyer transaction so transferred objects enter
    // the test-scenario inventory.
    test_scenario::next_tx(&mut scenario, OTHER);

    let purchased_nft =
        test_scenario::take_from_sender_by_id<
            tobmate_core::gold_nft::GoldNFT,
        >(
            &scenario,
            nft_id,
        );

    assert!(
        gold_nft::nft_id(&purchased_nft) == nft_id,
        7113,
    );

    gold_nft::destroy_nft_for_testing(purchased_nft);

    // Seller receives only net proceeds.
    test_scenario::next_tx(&mut scenario, OWNER);

    let seller_payment =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    assert!(
        coin::value(&seller_payment)
            == expected_seller_proceeds,
        7114,
    );

    assert!(
        coin::burn_for_testing(seller_payment)
            == expected_seller_proceeds,
        7115,
    );

    // Drain the FeeVault for fixture cleanup.
    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fee_coin =
        fee_vault::release_all(
            &collector_cap,
            &access,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(fee_coin)
            == expected_fee,
        7116,
    );

    fee_vault::destroy_empty_for_testing(vault);
    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    dual_ownership::destroy_record_for_testing(
        &mut dual_registry,
        record,
    );

    dual_ownership::destroy_registry_for_testing(
        dual_registry,
    );

    gold_nft::destroy_registry_for_testing(nft_registry);
    gold_nft::destroy_admin_cap_for_testing(admin_cap);
    backing_position::destroy_linked_for_testing(position);
    gold_reserve::destroy_reserve_for_testing(reserve);
    marketplace::destroy_for_testing(marketplace_object);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}
