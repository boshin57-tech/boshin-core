#[test_only]
module tobmate_core::treasury_backstop_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::bad_debt_settlement;

use tobmate_core::insurance_fund::{
    Self as insurance_fund,
};

use tobmate_core::lending_pool::{
    Self as lending_pool,
};

use tobmate_core::treasury::{
    Self as treasury,
};

use tobmate_core::treasury_backstop;

const ADMIN: address = @0xA;
const BORROWER: address = @0xB;

const BAD_DEBT: u64 = 1_000;
const TREASURY_FUNDS: u64 = 2_000;


/* ============================================================
   Test 01 — Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        treasury_backstop::version(&registry) == 1,
        1,
    );

    assert!(
        !treasury_backstop::is_paused(&registry),
        2,
    );

    assert!(
        treasury_backstop::total_backstop_paid(
            &registry,
        ) == 0,
        3,
    );

    assert!(
        treasury_backstop::settlement_count(
            &registry,
        ) == 0,
        4,
    );

    treasury_backstop::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Pause Lifecycle
   ============================================================ */

#[test]
fun test_02_pause_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        treasury_backstop::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    treasury_backstop::set_paused(
        &mut registry,
        &cap,
        true,
    );

    assert!(
        treasury_backstop::is_paused(&registry),
        10,
    );

    treasury_backstop::set_paused(
        &mut registry,
        &cap,
        false,
    );

    assert!(
        !treasury_backstop::is_paused(&registry),
        11,
    );

    treasury_backstop::
        destroy_admin_cap_for_testing(cap);

    treasury_backstop::
        destroy_for_testing(registry);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Partial Treasury Backstop
   ============================================================ */

#[test]
fun test_03_partial_treasury_backstop() {
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

    let debt_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &debt_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut backstop =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let backstop_cap =
        treasury_backstop::admin_cap_for_testing(
            &backstop,
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUNDS,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut debt_registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::link_insurance_claim(
        &mut debt_registry,
        &debt_cap,
        record_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    treasury_backstop::execute_backstop(
        &access,
        &mut backstop,
        &backstop_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut debt_registry,
        &mut pool,
        record_id,
        400,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bad_debt_settlement::record_remaining_bad_debt(
            &debt_registry,
            record_id,
        ) == 600,
        20,
    );

    assert!(
        bad_debt_settlement::record_recovered_amount(
            &debt_registry,
            record_id,
        ) == 400,
        21,
    );

    assert!(
        lending_pool::outstanding_bad_debt(&pool) == 600,
        22,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(&pool) == 400,
        23,
    );

    assert!(
        treasury::balance(&protocol_treasury) == 1_600,
        24,
    );

    assert!(
        treasury_backstop::total_backstop_paid(
            &backstop,
        ) == 400,
        25,
    );

    assert!(
        treasury_backstop::settlement_count(
            &backstop,
        ) == 1,
        26,
    );

    lending_pool::assert_bad_debt_accounting_invariant(
        &pool,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    let recovered =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(recovered);

    treasury::withdraw(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        1_600,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let remainder =
        test_scenario::take_from_sender<
            sui::coin::Coin<SUI>
        >(&scenario);

    coin::burn_for_testing(remainder);

    treasury_backstop::destroy_admin_cap_for_testing(
        backstop_cap,
    );

    treasury_backstop::destroy_for_testing(
        backstop,
    );

    bad_debt_settlement::destroy_admin_cap_for_testing(
        debt_cap,
    );

    bad_debt_settlement::destroy_for_testing(
        debt_registry,
    );

    treasury::destroy_admin_cap_for_testing(
        treasury_cap,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    lending_pool::destroy_empty_for_testing(pool);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Full Treasury Backstop
   ============================================================ */

#[test]
fun test_04_full_treasury_backstop() {
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

    let debt_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &debt_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut backstop =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let backstop_cap =
        treasury_backstop::admin_cap_for_testing(
            &backstop,
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            BAD_DEBT,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut debt_registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::link_insurance_claim(
        &mut debt_registry,
        &debt_cap,
        record_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    treasury_backstop::execute_backstop(
        &access,
        &mut backstop,
        &backstop_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut debt_registry,
        &mut pool,
        record_id,
        BAD_DEBT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bad_debt_settlement::record_remaining_bad_debt(
            &debt_registry,
            record_id,
        ) == 0,
        30,
    );

    assert!(
        bad_debt_settlement::record_status(
            &debt_registry,
            record_id,
        ) ==
            bad_debt_settlement::status_recovered(),
        31,
    );

    assert!(
        lending_pool::outstanding_bad_debt(&pool) == 0,
        32,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(&pool)
            == BAD_DEBT,
        33,
    );

    assert!(
        treasury::balance(&protocol_treasury) == 0,
        34,
    );

    assert!(
        treasury_backstop::total_backstop_paid(
            &backstop,
        ) == BAD_DEBT,
        35,
    );

    lending_pool::assert_bad_debt_accounting_invariant(
        &pool,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    let recovered =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(recovered);

    treasury_backstop::destroy_admin_cap_for_testing(
        backstop_cap,
    );

    treasury_backstop::destroy_for_testing(backstop);

    bad_debt_settlement::destroy_admin_cap_for_testing(
        debt_cap,
    );

    bad_debt_settlement::destroy_for_testing(
        debt_registry,
    );

    treasury::destroy_admin_cap_for_testing(
        treasury_cap,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    lending_pool::destroy_empty_for_testing(pool);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Above Remaining Debt Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::treasury_backstop,
)]
fun test_05_above_remaining_debt_rejected() {
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

    let debt_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &debt_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut backstop =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let backstop_cap =
        treasury_backstop::admin_cap_for_testing(
            &backstop,
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUNDS,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut debt_registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::link_insurance_claim(
        &mut debt_registry,
        &debt_cap,
        record_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    treasury_backstop::execute_backstop(
        &access,
        &mut backstop,
        &backstop_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut debt_registry,
        &mut pool,
        record_id,
        BAD_DEBT + 1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06 — Second Backstop Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::treasury_backstop,
)]
fun test_06_second_backstop_after_full_recovery_rejected() {
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

    let debt_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &debt_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut backstop =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let backstop_cap =
        treasury_backstop::admin_cap_for_testing(
            &backstop,
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUNDS,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut debt_registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::link_insurance_claim(
        &mut debt_registry,
        &debt_cap,
        record_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    treasury_backstop::execute_backstop(
        &access,
        &mut backstop,
        &backstop_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut debt_registry,
        &mut pool,
        record_id,
        BAD_DEBT,
        test_scenario::ctx(&mut scenario),
    );

    treasury_backstop::execute_backstop(
        &access,
        &mut backstop,
        &backstop_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut debt_registry,
        &mut pool,
        record_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Insurance + Treasury E2E Solvency Settlement
   ============================================================ */

#[test]
fun test_07_insurance_plus_treasury_full_settlement() {
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

    let debt_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &debt_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut backstop =
        treasury_backstop::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let backstop_cap =
        treasury_backstop::admin_cap_for_testing(
            &backstop,
            test_scenario::ctx(&mut scenario),
        );

    let insurance_funding =
        coin::mint_for_testing<SUI>(
            400,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut fund,
        insurance_funding,
        test_scenario::ctx(&mut scenario),
    );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            600,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut debt_registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT,
            test_scenario::ctx(&mut scenario),
        );

    let claim_id =
        bad_debt_settlement::
            submit_insurance_claim_for_bad_debt(
                &access,
                &mut debt_registry,
                &debt_cap,
                &mut fund,
                record_id,
                b"e2e-solvency",
                test_scenario::ctx(&mut scenario),
            );

    insurance_fund::review_claim(
        &insurance_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::approve_claim(
        &insurance_cap,
        &access,
        &mut fund,
        claim_id,
        400,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::pay_claim(
        &insurance_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let insurance_recovery =
        test_scenario::take_from_sender<
            sui::coin::Coin<SUI>
        >(&scenario);

    bad_debt_settlement::apply_recovery(
        &access,
        &mut debt_registry,
        &mut pool,
        record_id,
        insurance_recovery,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bad_debt_settlement::record_remaining_bad_debt(
            &debt_registry,
            record_id,
        ) == 600,
        70,
    );

    treasury_backstop::execute_backstop(
        &access,
        &mut backstop,
        &backstop_cap,
        &treasury_cap,
        &mut protocol_treasury,
        &mut debt_registry,
        &mut pool,
        record_id,
        600,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bad_debt_settlement::record_remaining_bad_debt(
            &debt_registry,
            record_id,
        ) == 0,
        71,
    );

    assert!(
        bad_debt_settlement::record_recovered_amount(
            &debt_registry,
            record_id,
        ) == BAD_DEBT,
        72,
    );

    assert!(
        lending_pool::total_bad_debt_created(
            &pool,
        ) == BAD_DEBT,
        73,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(
            &pool,
        ) == BAD_DEBT,
        74,
    );

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) == 0,
        75,
    );

    assert!(
        treasury_backstop::total_backstop_paid(
            &backstop,
        ) == 600,
        76,
    );

    assert!(
        treasury::balance(
            &protocol_treasury,
        ) == 0,
        77,
    );

    lending_pool::assert_bad_debt_accounting_invariant(
        &pool,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    insurance_fund::assert_accounting_invariant(
        &fund,
    );

    let recovered =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(recovered);

    treasury_backstop::destroy_admin_cap_for_testing(
        backstop_cap,
    );

    treasury_backstop::destroy_for_testing(
        backstop,
    );

    bad_debt_settlement::destroy_admin_cap_for_testing(
        debt_cap,
    );

    bad_debt_settlement::destroy_for_testing(
        debt_registry,
    );

    insurance_fund::destroy_admin_cap_for_testing(
        insurance_cap,
    );

    insurance_fund::destroy_for_testing(
        fund,
    );

    treasury::destroy_admin_cap_for_testing(
        treasury_cap,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
