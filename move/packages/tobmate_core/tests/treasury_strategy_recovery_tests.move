#[test_only]
module tobmate_core::treasury_strategy_recovery_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
};

use tobmate_core::insurance_fund::{
    Self as insurance_fund,
};

use tobmate_core::treasury::{
    Self as treasury,
};

use tobmate_core::treasury_strategy_recovery::{
    Self as strategy_recovery,
};

const ADMIN: address = @0xAD;
const STRATEGY_OPERATOR: address = @0xBEEF;


/* ============================================================
   Test 01 — Initial Recovery Registry State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        strategy_recovery::version(&registry) == 1,
        100,
    );

    assert!(
        !strategy_recovery::is_paused(&registry),
        101,
    );

    assert!(
        strategy_recovery::record_count(&registry) == 0,
        102,
    );

    assert!(
        strategy_recovery::total_loss_recorded(
            &registry,
        ) == 0,
        103,
    );

    assert!(
        strategy_recovery::total_recovered(
            &registry,
        ) == 0,
        104,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    strategy_recovery::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Strategy Loss Recovery Record
   ============================================================ */

#[test]
fun test_02_record_strategy_loss() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_TEST_02",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(record_id == 1, 200);

    assert!(
        strategy_recovery::record_count(
            &registry,
        ) == 1,
        201,
    );

    assert!(
        strategy_recovery::record_original_loss(
            &registry,
            record_id,
        ) == 100_000_000,
        202,
    );

    assert!(
        strategy_recovery::record_remaining_loss(
            &registry,
            record_id,
        ) == 100_000_000,
        203,
    );

    assert!(
        strategy_recovery::record_total_recovered(
            &registry,
            record_id,
        ) == 0,
        204,
    );

    assert!(
        strategy_recovery::record_strategy_id(
            &registry,
            record_id,
        ) == strategy_id,
        205,
    );

    assert!(
        strategy_recovery::record_status(
            &registry,
            record_id,
        ) == strategy_recovery::status_open(),
        206,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    strategy_recovery::destroy_admin_cap_for_testing(
        recovery_cap,
    );

    strategy_recovery::destroy_for_testing(
        registry,
    );

    /*
     * Outstanding principal after 100M loss:
     * 500M - 100M = 400M.
     * Mark the remainder as loss for fixture cleanup.
     */
    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let drained =
        yield_engine::drain_for_testing(
            &mut engine,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(drained);

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Duplicate Open Recovery Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::treasury_strategy_recovery,
)]
fun test_03_duplicate_open_recovery_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_DUPLICATE",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::record_strategy_loss(
        &mut registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04 — Zero Loss Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::treasury_strategy_recovery,
)]
fun test_04_zero_loss_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut registry,
        &recovery_cap,
        &engine,
        1,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05 — Loss Above Recognized Strategy Loss Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::treasury_strategy_recovery,
)]
fun test_05_loss_above_recognized_strategy_loss_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_MISMATCH",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_001,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06 — Multi Strategy Recovery Records Stay Isolated
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_06_multi_strategy_recovery_isolation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_a =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_ISOLATION_A",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let strategy_b =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_ISOLATION_B",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_a,
        300_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_b,
        300_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_a,
        80_000_000,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_b,
        120_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_a =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_a,
            80_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let record_b =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_b,
            120_000_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        record_a != record_b,
        600,
    );

    assert!(
        strategy_recovery::record_strategy_id(
            &registry,
            record_a,
        ) == strategy_a,
        601,
    );

    assert!(
        strategy_recovery::record_strategy_id(
            &registry,
            record_b,
        ) == strategy_b,
        602,
    );

    assert!(
        strategy_recovery::record_original_loss(
            &registry,
            record_a,
        ) == 80_000_000,
        603,
    );

    assert!(
        strategy_recovery::record_original_loss(
            &registry,
            record_b,
        ) == 120_000_000,
        604,
    );

    assert!(
        strategy_recovery::total_loss_recorded(
            &registry,
        ) == 200_000_000,
        605,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    abort 0
}


/* ============================================================
   Stage 9 Part 3-B
   Insurance Recovery Integration Tests
   ============================================================ */


/* Test 07 — Insurance Claim Submission Links Recovery Record */

#[test]
#[expected_failure(abort_code = 0)]
fun test_07_insurance_claim_submission_links_record() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"INSURANCE_LINK",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let claim_id =
        strategy_recovery::submit_insurance_claim_for_strategy_loss(
            &access,
            &mut registry,
            &recovery_cap,
            &mut insurance,
            record_id,
            b"strategy-loss-evidence",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        claim_id == 1,
        700,
    );

    assert!(
        strategy_recovery::record_insurance_claim_id(
            &registry,
            record_id,
        ) == claim_id,
        701,
    );

    assert!(
        insurance_fund::claim_requested_amount(
            &insurance,
            claim_id,
        ) == 100_000_000,
        702,
    );

    assert!(
        insurance_fund::claim_status(
            &insurance,
            claim_id,
        ) == insurance_fund::status_submitted(),
        703,
    );

    abort 0
}


/* Test 08 — Paid Insurance Claim Applies Recovery */

#[test]
#[expected_failure(abort_code = 0)]
fun test_08_paid_insurance_claim_applies_recovery() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"INSURANCE_PAID",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let insurance_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance_funding =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut insurance,
        insurance_funding,
        test_scenario::ctx(&mut scenario),
    );

    let claim_id =
        strategy_recovery::submit_insurance_claim_for_strategy_loss(
            &access,
            &mut registry,
            &recovery_cap,
            &mut insurance,
            record_id,
            b"strategy-loss-paid",
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::review_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::approve_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        60_000_000,
        1,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::pay_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::apply_paid_insurance_recovery(
        &mut registry,
        &recovery_cap,
        &insurance,
        record_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        strategy_recovery::record_insurance_recovered(
            &registry,
            record_id,
        ) == 60_000_000,
        800,
    );

    assert!(
        strategy_recovery::record_total_recovered(
            &registry,
            record_id,
        ) == 60_000_000,
        801,
    );

    assert!(
        strategy_recovery::record_remaining_loss(
            &registry,
            record_id,
        ) == 40_000_000,
        802,
    );

    assert!(
        strategy_recovery::record_status(
            &registry,
            record_id,
        ) == strategy_recovery::status_partially_recovered(),
        803,
    );

    assert!(
        strategy_recovery::total_insurance_recovered(
            &registry,
        ) == 60_000_000,
        804,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    abort 0
}


/* Test 09 — Insurance Recovery Before Payment Rejected */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::treasury_strategy_recovery,
)]
fun test_09_insurance_recovery_before_payment_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"INSURANCE_NOT_PAID",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::submit_insurance_claim_for_strategy_loss(
        &access,
        &mut registry,
        &recovery_cap,
        &mut insurance,
        record_id,
        b"not-paid",
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::apply_paid_insurance_recovery(
        &mut registry,
        &recovery_cap,
        &insurance,
        record_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 10 — Duplicate Insurance Recovery Application Rejected */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::treasury_strategy_recovery,
)]
fun test_10_duplicate_insurance_recovery_application_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"INSURANCE_DUP_APPLY",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let insurance_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance_funding =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut insurance,
        insurance_funding,
        test_scenario::ctx(&mut scenario),
    );

    let claim_id =
        strategy_recovery::submit_insurance_claim_for_strategy_loss(
            &access,
            &mut registry,
            &recovery_cap,
            &mut insurance,
            record_id,
            b"duplicate-paid",
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::review_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::approve_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        50_000_000,
        1,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::pay_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::apply_paid_insurance_recovery(
        &mut registry,
        &recovery_cap,
        &insurance,
        record_id,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::apply_paid_insurance_recovery(
        &mut registry,
        &recovery_cap,
        &insurance,
        record_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Stage 9 Part 3-C
   Treasury Residual Recovery Tests
   ============================================================ */


/* Test 11 — Treasury Recovery Restores Yield Engine Assets */

#[test]
#[expected_failure(abort_code = 0)]
fun test_11_treasury_recovery_restores_yield_engine_assets() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"TREASURY_RECOVERY_11",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        strategy_recovery::record_treasury_recovered(
            &registry,
            record_id,
        ) == 100_000_000,
        1100,
    );

    assert!(
        strategy_recovery::record_remaining_loss(
            &registry,
            record_id,
        ) == 0,
        1101,
    );

    assert!(
        strategy_recovery::record_status(
            &registry,
            record_id,
        ) == strategy_recovery::status_recovered(),
        1102,
    );

    assert!(
        yield_engine::total_recovery_inflow(
            &engine,
        ) == 100_000_000,
        1103,
    );

    assert!(
        treasury::balance(
            &protocol_treasury,
        ) == 100_000_000,
        1104,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    abort 0
}


/* Test 12 — Insurance Plus Treasury Completes Recovery */

#[test]
#[expected_failure(abort_code = 0)]
fun test_12_insurance_plus_treasury_completes_recovery() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_COMBINED_12",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let insurance_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance_funding =
        coin::mint_for_testing<SUI>(
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut insurance,
        insurance_funding,
        test_scenario::ctx(&mut scenario),
    );

    let claim_id =
        strategy_recovery::submit_insurance_claim_for_strategy_loss(
            &access,
            &mut registry,
            &recovery_cap,
            &mut insurance,
            record_id,
            b"combined-recovery",
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::review_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::approve_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        60_000_000,
        1,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::pay_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::apply_paid_insurance_recovery(
        &mut registry,
        &recovery_cap,
        &insurance,
        record_id,
        test_scenario::ctx(&mut scenario),
    );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        40_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        strategy_recovery::record_insurance_recovered(
            &registry,
            record_id,
        ) == 60_000_000,
        1200,
    );

    assert!(
        strategy_recovery::record_treasury_recovered(
            &registry,
            record_id,
        ) == 40_000_000,
        1201,
    );

    assert!(
        strategy_recovery::record_total_recovered(
            &registry,
            record_id,
        ) == 100_000_000,
        1202,
    );

    assert!(
        strategy_recovery::record_remaining_loss(
            &registry,
            record_id,
        ) == 0,
        1203,
    );

    assert!(
        strategy_recovery::total_insurance_recovered(
            &registry,
        ) == 60_000_000,
        1204,
    );

    assert!(
        strategy_recovery::total_treasury_recovered(
            &registry,
        ) == 40_000_000,
        1205,
    );

    assert!(
        strategy_recovery::total_recovered(
            &registry,
        ) == 100_000_000,
        1206,
    );

    assert!(
        yield_engine::total_recovery_inflow(
            &engine,
        ) == 40_000_000,
        1207,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    abort 0
}


/* Test 13 — Treasury Recovery Above Remaining Loss Rejected */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::treasury_strategy_recovery,
)]
fun test_13_treasury_recovery_above_remaining_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"TREASURY_ABOVE_REMAINING",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        100_000_001,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 14 — Multiple Treasury Recoveries Preserve Accounting */

#[test]
#[expected_failure(abort_code = 0)]
fun test_14_multiple_treasury_recoveries_preserve_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"MULTI_TREASURY_RECOVERY",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        120_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut registry,
            &recovery_cap,
            &engine,
            strategy_id,
            120_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        30_000_000,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        40_000_000,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        50_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        strategy_recovery::record_treasury_recovered(
            &registry,
            record_id,
        ) == 120_000_000,
        1400,
    );

    assert!(
        strategy_recovery::record_remaining_loss(
            &registry,
            record_id,
        ) == 0,
        1401,
    );

    assert!(
        yield_engine::total_recovery_inflow(
            &engine,
        ) == 120_000_000,
        1402,
    );

    assert!(
        treasury::balance(
            &protocol_treasury,
        ) == 80_000_000,
        1403,
    );

    strategy_recovery::assert_accounting_invariant(
        &registry,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    abort 0
}


/* ============================================================
   Stage 9 Part 3-D
   Strategy Recovery Mode Tests
   ============================================================ */


/* Test 15 — No Loss Coverage Is 100 Percent */

#[test]
fun test_15_no_loss_coverage_is_full() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        recovery_mode::recovery_coverage_bps(
            &registry,
        ) == 10_000,
        1500,
    );

    strategy_recovery::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* Test 16 — Unresolved Loss Activates Recovery Mode */

#[test]
#[expected_failure(abort_code = 0)]
fun test_16_unresolved_loss_activates_recovery_mode() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_MODE_16",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut recovery_registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut recovery_registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::evaluate_and_activate(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    assert!(
        recovery_mode::is_recovery_mode(
            &mode_registry,
        ),
        1600,
    );

    assert!(
        yield_engine::is_strategy_recovery_mode(
            &engine,
        ),
        1601,
    );

    assert!(
        recovery_mode::last_observed_coverage_bps(
            &mode_registry,
        ) == 0,
        1602,
    );

    abort 0
}


/* Test 17 — Recovery Mode Blocks New Allocation */

#[test]
#[expected_failure(
    abort_code = 20,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_17_recovery_mode_blocks_new_allocation() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_MODE_BLOCK_17",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut recovery_registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut recovery_registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::evaluate_and_activate(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        10_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 18 — Recovery Clears Mode And Allocation Resumes */

#[test]
#[expected_failure(abort_code = 0)]
fun test_18_recovery_clears_mode_and_allocation_resumes() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"RECOVERY_CLEAR_18",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut recovery_registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        strategy_recovery::record_strategy_loss(
            &mut recovery_registry,
            &recovery_cap,
            &engine,
            strategy_id,
            100_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::evaluate_and_activate(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_recovery::execute_treasury_recovery(
        &access,
        &mut recovery_registry,
        &recovery_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut engine,
        record_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        recovery_mode::recovery_coverage_bps(
            &recovery_registry,
        ) == 10_000,
        1800,
    );

    recovery_mode::evaluate_and_clear(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    assert!(
        !recovery_mode::is_recovery_mode(
            &mode_registry,
        ),
        1801,
    );

    assert!(
        !yield_engine::is_strategy_recovery_mode(
            &engine,
        ),
        1802,
    );

    yield_engine::clear_strategy_loss_guard(
        &yield_cap,
        &mut engine,
        strategy_id,
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        10_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    abort 0
}


/* ============================================================
   Stage 9 Part 3-E
   Security / Cross-Module Edge Cases
   ============================================================ */


/* Test 19 — Zero Recovery Threshold Rejected */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::treasury_strategy_recovery_mode,
)]
fun test_19_zero_recovery_threshold_rejected() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mode_cap =
        recovery_mode::admin_cap_for_testing(
            &mode_registry,
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::set_recovery_threshold_bps(
        &mut mode_registry,
        &mode_cap,
        0,
    );

    abort 999
}


/* Test 20 — Recovery Threshold Above 100 Percent Rejected */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::treasury_strategy_recovery_mode,
)]
fun test_20_recovery_threshold_above_max_rejected() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mode_cap =
        recovery_mode::admin_cap_for_testing(
            &mode_registry,
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::set_recovery_threshold_bps(
        &mut mode_registry,
        &mode_cap,
        10_001,
    );

    abort 999
}


/* Test 21 — Duplicate Recovery Mode Activation Rejected */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::treasury_strategy_recovery_mode,
)]
fun test_21_duplicate_recovery_mode_activation_rejected() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"DUPLICATE_MODE_21",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut recovery_registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut recovery_registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::evaluate_and_activate(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    recovery_mode::evaluate_and_activate(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    abort 999
}


/* Test 22 — Recovery Mode Cannot Clear Before Threshold */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::treasury_strategy_recovery_mode,
)]
fun test_22_recovery_mode_cannot_clear_before_threshold() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"CLEAR_BEFORE_THRESHOLD_22",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut recovery_registry =
        strategy_recovery::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        strategy_recovery::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    strategy_recovery::record_strategy_loss(
        &mut recovery_registry,
        &recovery_cap,
        &engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    let mut mode_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    recovery_mode::evaluate_and_activate(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    recovery_mode::evaluate_and_clear(
        &mut mode_registry,
        &recovery_registry,
        &mut engine,
    );

    abort 999
}


/* ============================================================
   Stage 9 Part 4-B
   Recovery Governance Replay Protection
   ============================================================ */


/* Test 23 — Duplicate Recovery Threshold Rejected */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::treasury_strategy_recovery_mode,
)]
fun test_23_duplicate_recovery_threshold_rejected() {
    use tobmate_core::treasury_strategy_recovery_mode::{
        Self as recovery_mode,
    };

    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        recovery_mode::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Default threshold is already 8,000 bps.
     */
    recovery_mode::set_recovery_threshold_bps(
        &mut registry,
        &cap,
        8_000,
    );

    abort 999
}
