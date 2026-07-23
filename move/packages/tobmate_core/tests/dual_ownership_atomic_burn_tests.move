#[test_only]
module tobmate_core::dual_ownership_atomic_burn_tests;

use sui::test_scenario;

use tobmate_core::access_control;
use tobmate_core::backing_position;
use tobmate_core::dual_ownership;
use tobmate_core::gold_nft;
use tobmate_core::test_support;

/// ================================================================
/// Test 1
/// Duplicate record creation must abort with E_DUPLICATE_RECORD = 16.
/// ================================================================

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::dual_ownership,
)]
fun duplicate_record_creation_aborts() {
    let mut scenario =
        test_scenario::begin(test_support::owner());

    let ctx = scenario.ctx();

    let (
        _access,
        _gold_nft_admin_cap,
        _gold_nft_registry,
        mut dual_registry,
        position,
        nft,
        _record,
    ) = test_support::new_single_fixture(ctx);

    // The fixture already indexed an active record for this position.
    // A second record for the same position must abort.
    let _duplicate_record =
        dual_ownership::create_record_for_testing(
            &mut dual_registry,
            &position,
            &nft,
            test_support::owner(),
            test_support::owner(),
            test_support::owner(),
            ctx,
        );

    abort 0
}

/// ================================================================
/// Test 2
/// Atomic burn without principal approval must abort with
/// E_PRINCIPAL_APPROVAL_REQUIRED = 11.
/// ================================================================

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::dual_ownership,
)]
fun atomic_burn_without_approval_aborts() {
    let mut scenario =
        test_scenario::begin(test_support::owner());

    let ctx = scenario.ctx();

    let (
        access,
        gold_nft_admin_cap,
        mut gold_nft_registry,
        mut dual_registry,
        mut position,
        nft,
        mut record,
    ) = test_support::new_single_fixture(ctx);

    // No principal or collectible burn approval has been granted.
    dual_ownership::burn_gold_nft_atomic(
        &gold_nft_admin_cap,
        &access,
        &mut gold_nft_registry,
        &mut dual_registry,
        &mut record,
        &mut position,
        nft,
        ctx,
    );

    abort 0
}

/// ================================================================
/// Test 3
/// Supplying an NFT different from the record's NFT must abort with
/// E_NFT_MISMATCH = 9.
/// ================================================================

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::dual_ownership,
)]
fun atomic_burn_with_mismatched_nft_aborts() {
    let mut scenario =
        test_scenario::begin(test_support::owner());

    let ctx = scenario.ctx();

    let (
        access,
        gold_nft_admin_cap,
        mut gold_nft_registry,
        mut dual_registry,
        mut position_one,
        _nft_one,
        _position_two,
        nft_two,
        mut record,
    ) = test_support::new_mismatch_fixture(ctx);

    dual_ownership::set_principal_burn_approval(
        &access,
        &mut record,
        true,
        ctx,
    );

    dual_ownership::set_collectible_burn_approval(
        &access,
        &mut record,
        true,
        ctx,
    );

    // record references nft_one, but nft_two is supplied.
    dual_ownership::burn_gold_nft_atomic(
        &gold_nft_admin_cap,
        &access,
        &mut gold_nft_registry,
        &mut dual_registry,
        &mut record,
        &mut position_one,
        nft_two,
        ctx,
    );

    abort 0
}

/// ================================================================
/// Test 4
/// Successful atomic burn must:
///
/// - consume and delete the GoldNFT;
/// - unlink the NFT from GoldBackingPosition;
/// - decrement GoldNFT active count;
/// - increment GoldNFT burned count;
/// - remove backed NFT weight from GoldNFTRegistry;
/// - close DualOwnershipRecord;
/// - decrement dual active count;
/// - increment dual closed count;
/// - remove the active position index;
/// - preserve both registry invariants.
/// ================================================================

#[test]
fun successful_atomic_burn_closes_all_linked_state() {
    let mut scenario =
        test_scenario::begin(test_support::owner());

    let ctx = scenario.ctx();

    let (
        access,
        gold_nft_admin_cap,
        mut gold_nft_registry,
        mut dual_registry,
        mut position,
        nft,
        mut record,
    ) = test_support::new_single_fixture(ctx);

    let position_id =
        backing_position::position_id(&position);

    assert!(
        backing_position::has_gold_nft(&position),
        100,
    );

    assert!(
        gold_nft::registry_total_minted(
            &gold_nft_registry,
        ) == 1,
        101,
    );

    assert!(
        gold_nft::registry_total_active(
            &gold_nft_registry,
        ) == 1,
        102,
    );

    assert!(
        gold_nft::registry_total_burned(
            &gold_nft_registry,
        ) == 0,
        103,
    );

    assert!(
        gold_nft::registry_total_backed_weight_mg(
            &gold_nft_registry,
        ) == test_support::weight_mg(),
        104,
    );

    assert!(
        dual_ownership::registry_total_active_for_testing(
            &dual_registry,
        ) == 1,
        105,
    );

    assert!(
        dual_ownership::registry_total_closed_for_testing(
            &dual_registry,
        ) == 0,
        106,
    );

    assert!(
        dual_ownership::registry_has_active_position_for_testing(
            &dual_registry,
            position_id,
        ),
        107,
    );

    dual_ownership::set_principal_burn_approval(
        &access,
        &mut record,
        true,
        ctx,
    );

    dual_ownership::set_collectible_burn_approval(
        &access,
        &mut record,
        true,
        ctx,
    );

    dual_ownership::assert_burn_authorized(&record);

    dual_ownership::burn_gold_nft_atomic(
        &gold_nft_admin_cap,
        &access,
        &mut gold_nft_registry,
        &mut dual_registry,
        &mut record,
        &mut position,
        nft,
        ctx,
    );

    // GoldNFT was consumed by burn_gold_nft_atomic().
    // Its deletion is enforced by Move resource semantics.

    assert!(
        !backing_position::has_gold_nft(&position),
        108,
    );

    assert!(
        dual_ownership::record_is_closed_for_testing(
            &record,
        ),
        109,
    );

    assert!(
        gold_nft::registry_total_minted(
            &gold_nft_registry,
        ) == 1,
        110,
    );

    assert!(
        gold_nft::registry_total_active(
            &gold_nft_registry,
        ) == 0,
        111,
    );

    assert!(
        gold_nft::registry_total_burned(
            &gold_nft_registry,
        ) == 1,
        112,
    );

    assert!(
        gold_nft::registry_total_backed_weight_mg(
            &gold_nft_registry,
        ) == 0,
        113,
    );

    assert!(
        dual_ownership::registry_total_active_for_testing(
            &dual_registry,
        ) == 0,
        114,
    );

    assert!(
        dual_ownership::registry_total_closed_for_testing(
            &dual_registry,
        ) == 1,
        115,
    );

    assert!(
        !dual_ownership::registry_has_active_position_for_testing(
            &dual_registry,
            position_id,
        ),
        116,
    );

    gold_nft::assert_registry_invariants(
        &gold_nft_registry,
    );

    dual_ownership::assert_registry_invariants(
        &dual_registry,
    );

    dual_ownership::destroy_record_for_testing(record);
    dual_ownership::destroy_registry_for_testing(
        dual_registry,
    );

    gold_nft::destroy_registry_for_testing(
        gold_nft_registry,
    );

    gold_nft::destroy_admin_cap_for_testing(
        gold_nft_admin_cap,
    );

    backing_position::destroy_for_testing(position);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}
