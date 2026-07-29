#[test_only]
module tobmate_finance::recovery_mode_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_finance::bad_debt_settlement;

use tobmate_finance::insurance_fund;

use tobmate_finance::lending_pool;

use tobmate_finance::recovery_mode;

use tobmate_finance::treasury;

const ADMIN: address = @0xA;
const BORROWER: address = @0xB;


/* ============================================================
   Test 01 — Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        recovery_mode::mode(&registry)
            == recovery_mode::normal_mode(),
        1,
    );

    assert!(
        !recovery_mode::is_recovery_mode(
            &registry,
        ),
        2,
    );

    assert!(
        recovery_mode::recovery_threshold_bps(
            &registry,
        ) == 10_000,
        3,
    );

    assert!(
        recovery_mode::activation_count(
            &registry,
        ) == 0,
        4,
    );

    recovery_mode::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Under-Coverage Activates Recovery Mode
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_02_undercoverage_activates_recovery() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(&mut scenario),
        );

    let mut debt_registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance_coin =
        coin::mint_for_testing<SUI>(
            200,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut insurance,
        insurance_coin,
        test_scenario::ctx(&mut scenario),
    );

    let treasury_coin =
        coin::mint_for_testing<SUI>(
            300,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_coin,
        test_scenario::ctx(&mut scenario),
    );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        1,
        1,
        BORROWER,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_activate(
        &mut registry,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    assert!(
        recovery_mode::is_recovery_mode(
            &registry,
        ),
        10,
    );

    assert!(
        recovery_mode::activation_count(
            &registry,
        ) == 1,
        11,
    );

    assert!(
        recovery_mode::last_observed_coverage_bps(
            &registry,
        ) == 5_000,
        12,
    );

    abort 0
}


/* ============================================================
   Test 03 — Risk Increase Blocked In Recovery Mode
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_finance::recovery_mode,
)]
fun test_03_risk_increase_blocked_in_recovery() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(&mut scenario),
        );

    let mut debt_registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        1,
        1,
        BORROWER,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_activate(
        &mut registry,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    recovery_mode::assert_risk_increase_allowed(
        &registry,
    );

    abort 999
}


/* ============================================================
   Test 04 — Recovery Mode Clears After Coverage Restored
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_04_recovery_clears_after_coverage_restored() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(&mut scenario),
        );

    let mut debt_registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        1,
        1,
        BORROWER,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_activate(
        &mut registry,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    assert!(
        recovery_mode::is_recovery_mode(
            &registry,
        ),
        40,
    );

    /*
       Restore coverage to 100%:
       Insurance 400 + Treasury 600
    */

    let insurance_coin =
        coin::mint_for_testing<SUI>(
            400,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut insurance,
        insurance_coin,
        test_scenario::ctx(&mut scenario),
    );

    let treasury_coin =
        coin::mint_for_testing<SUI>(
            600,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_coin,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_clear(
        &mut registry,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    assert!(
        !recovery_mode::is_recovery_mode(
            &registry,
        ),
        41,
    );

    assert!(
        recovery_mode::mode(
            &registry,
        ) == recovery_mode::normal_mode(),
        42,
    );

    assert!(
        recovery_mode::recovery_count(
            &registry,
        ) == 1,
        43,
    );

    assert!(
        recovery_mode::last_observed_coverage_bps(
            &registry,
        ) == 10_000,
        44,
    );

    recovery_mode::assert_risk_increase_allowed(
        &registry,
    );

    abort 0
}


/* ============================================================
   Test 05 — Cannot Clear While Still Under-Covered
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_finance::recovery_mode,
)]
fun test_05_cannot_clear_while_undercovered() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(&mut scenario),
        );

    let mut debt_registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        1,
        1,
        BORROWER,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_activate(
        &mut registry,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    recovery_mode::evaluate_and_clear(
        &mut registry,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    abort 999
}


/* ============================================================
   Test 06 — Recovery Threshold Can Be Updated
   ============================================================ */

#[test]
fun test_06_threshold_update_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        recovery_mode::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::set_recovery_threshold_bps(
        &mut registry,
        &admin_cap,
        12_500,
    );

    assert!(
        recovery_mode::recovery_threshold_bps(
            &registry,
        ) == 12_500,
        60,
    );

    recovery_mode::destroy_admin_cap_for_testing(
        admin_cap,
    );

    recovery_mode::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}
