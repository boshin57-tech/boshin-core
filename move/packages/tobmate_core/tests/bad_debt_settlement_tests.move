#[test_only]
module tobmate_core::bad_debt_settlement_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::bad_debt_settlement;

use tobmate_core::lending_pool::{
    Self as lending_pool,
};

use tobmate_core::insurance_fund::{
    Self as insurance_fund,
};

const ADMIN: address = @0xA;
const BORROWER: address = @0xB;

const BAD_DEBT_AMOUNT: u64 = 1_000;

/* ============================================================
   Test 1 — Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        bad_debt_settlement::version(
            &registry,
        ) == 1,
        1,
    );

    assert!(
        !bad_debt_settlement::is_paused(
            &registry,
        ),
        2,
    );

    assert!(
        bad_debt_settlement::record_count(
            &registry,
        ) == 0,
        3,
    );

    assert!(
        bad_debt_settlement::total_bad_debt_recorded(
            &registry,
        ) == 0,
        4,
    );

    assert!(
        bad_debt_settlement::total_recovered(
            &registry,
        ) == 0,
        5,
    );

    bad_debt_settlement::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 2 — Pause Lifecycle
   ============================================================ */

#[test]
fun test_02_pause_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        bad_debt_settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    bad_debt_settlement::set_paused(
        &mut registry,
        &cap,
        true,
    );

    assert!(
        bad_debt_settlement::is_paused(
            &registry,
        ),
        10,
    );

    bad_debt_settlement::set_paused(
        &mut registry,
        &cap,
        false,
    );

    assert!(
        !bad_debt_settlement::is_paused(
            &registry,
        ),
        11,
    );

    bad_debt_settlement::destroy_admin_cap_for_testing(
        cap,
    );

    bad_debt_settlement::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 3 — Record Bad Debt
   ============================================================ */

#[test]
fun test_03_record_bad_debt() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut registry,
            &mut pool,

            1,
            1,
            BORROWER,

            BAD_DEBT_AMOUNT,

            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(record_id == 1, 20);

    assert!(
        bad_debt_settlement::record_original_bad_debt(
            &registry,
            record_id,
        ) == BAD_DEBT_AMOUNT,
        21,
    );

    assert!(
        bad_debt_settlement::record_remaining_bad_debt(
            &registry,
            record_id,
        ) == BAD_DEBT_AMOUNT,
        22,
    );

    assert!(
        bad_debt_settlement::record_status(
            &registry,
            record_id,
        ) == bad_debt_settlement::status_open(),
        23,
    );

    assert!(
        lending_pool::total_bad_debt_created(
            &pool,
        ) == BAD_DEBT_AMOUNT,
        24,
    );

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) == BAD_DEBT_AMOUNT,
        25,
    );

    assert!(
        lending_pool::bad_debt_count(
            &pool,
        ) == 1,
        26,
    );

    lending_pool::assert_bad_debt_accounting_invariant(
        &pool,
    );

    bad_debt_settlement::destroy_for_testing(
        registry,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 4 — Duplicate Bad Debt Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::bad_debt_settlement,
)]
fun test_04_duplicate_bad_debt_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut registry,
        &mut pool,
        1,
        1,
        BORROWER,
        BAD_DEBT_AMOUNT,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut registry,
        &mut pool,
        1,
        1,
        BORROWER,
        BAD_DEBT_AMOUNT,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

const INSURANCE_DEPOSIT: u64 = 2_000;
const PARTIAL_RECOVERY: u64 = 400;

/* ============================================================
   Test 5 — Insurance Claim Auto Linking
   ============================================================ */

#[test]
fun test_05_insurance_claim_auto_linked() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let registry_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let claim_id =
        bad_debt_settlement::
            submit_insurance_claim_for_bad_debt(
                &access,
                &mut registry,
                &registry_cap,
                &mut fund,
                record_id,
                b"bad-debt-evidence",
                test_scenario::ctx(
                    &mut scenario,
                ),
            );

    assert!(
        claim_id == 1,
        50,
    );

    assert!(
        bad_debt_settlement::
            record_insurance_claim_id(
                &registry,
                record_id,
            ) == claim_id,
        51,
    );

    assert!(
        bad_debt_settlement::record_status(
            &registry,
            record_id,
        ) ==
            bad_debt_settlement::
                status_claim_submitted(),
        52,
    );

    assert!(
        insurance_fund::claim_requested_amount(
            &fund,
            claim_id,
        ) == BAD_DEBT_AMOUNT,
        53,
    );

    assert!(
        insurance_fund::claim_status(
            &fund,
            claim_id,
        ) ==
            insurance_fund::status_submitted(),
        54,
    );

    bad_debt_settlement::
        destroy_admin_cap_for_testing(
            registry_cap,
        );

    bad_debt_settlement::destroy_for_testing(
        registry,
    );

    insurance_fund::destroy_for_testing(
        fund,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 6 — Partial Insurance Recovery
   ============================================================ */

#[test]
fun test_06_partial_insurance_recovery() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let registry_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let insurance_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            INSURANCE_DEPOSIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    insurance_fund::deposit(
        &access,
        &mut fund,
        funding,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let claim_id =
        bad_debt_settlement::
            submit_insurance_claim_for_bad_debt(
                &access,
                &mut registry,
                &registry_cap,
                &mut fund,
                record_id,
                b"partial-recovery",
                test_scenario::ctx(
                    &mut scenario,
                ),
            );

    insurance_fund::review_claim(
        &insurance_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    insurance_fund::approve_claim(
        &insurance_cap,
        &access,
        &mut fund,
        claim_id,
        PARTIAL_RECOVERY,
        6001,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    insurance_fund::pay_claim(
        &insurance_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    bad_debt_settlement::
        assert_insurance_claim_paid(
            &registry,
            &fund,
            record_id,
        );

    /*
       pay_claim() transfers Coin<SUI> to the claimant.
       ADMIN submitted the claim, so ADMIN owns the payout.
    */

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let recovery =
        test_scenario::take_from_sender<
            sui::coin::Coin<SUI>
        >(
            &scenario,
        );

    assert!(
        coin::value(&recovery)
            == PARTIAL_RECOVERY,
        60,
    );

    bad_debt_settlement::apply_recovery(
        &access,
        &mut registry,
        &mut pool,
        record_id,
        recovery,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        bad_debt_settlement::
            record_recovered_amount(
                &registry,
                record_id,
            ) == PARTIAL_RECOVERY,
        61,
    );

    assert!(
        bad_debt_settlement::
            record_remaining_bad_debt(
                &registry,
                record_id,
            ) ==
            BAD_DEBT_AMOUNT
                - PARTIAL_RECOVERY,
        62,
    );

    assert!(
        bad_debt_settlement::record_status(
            &registry,
            record_id,
        ) ==
            bad_debt_settlement::
                status_partially_recovered(),
        63,
    );

    assert!(
        lending_pool::total_bad_debt_created(
            &pool,
        ) == BAD_DEBT_AMOUNT,
        64,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(
            &pool,
        ) == PARTIAL_RECOVERY,
        65,
    );

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) ==
            BAD_DEBT_AMOUNT
                - PARTIAL_RECOVERY,
        66,
    );

    assert!(
        lending_pool::available_liquidity(
            &pool,
        ) == PARTIAL_RECOVERY,
        67,
    );

    lending_pool::
        assert_bad_debt_accounting_invariant(
            &pool,
        );

    insurance_fund::
        assert_accounting_invariant(
            &fund,
        );

    /*
       Cleanup InsuranceFund remaining balance.
    */

    let remaining_insurance =
        insurance_fund::drain_for_testing(
            &mut fund,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(
        remaining_insurance,
    );

    /*
       Cleanup recovered LendingPool liquidity.
    */

    let recovered_liquidity =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(
        recovered_liquidity,
    );

    bad_debt_settlement::
        destroy_admin_cap_for_testing(
            registry_cap,
        );

    bad_debt_settlement::destroy_for_testing(
        registry,
    );

    insurance_fund::
        destroy_admin_cap_for_testing(
            insurance_cap,
        );

    insurance_fund::destroy_for_testing(
        fund,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 7 — Full Insurance Recovery
   ============================================================ */

#[test]
fun test_07_full_insurance_recovery() {
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

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_cap =
        bad_debt_settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let insurance_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            INSURANCE_DEPOSIT,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut fund,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    let claim_id =
        bad_debt_settlement::
            submit_insurance_claim_for_bad_debt(
                &access,
                &mut registry,
                &registry_cap,
                &mut fund,
                record_id,
                b"full-recovery",
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
        BAD_DEBT_AMOUNT,
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

    let recovery =
        test_scenario::take_from_sender<
            sui::coin::Coin<SUI>
        >(
            &scenario,
        );

    bad_debt_settlement::apply_recovery(
        &access,
        &mut registry,
        &mut pool,
        record_id,
        recovery,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bad_debt_settlement::
            record_remaining_bad_debt(
                &registry,
                record_id,
            ) == 0,
        70,
    );

    assert!(
        bad_debt_settlement::record_status(
            &registry,
            record_id,
        ) ==
            bad_debt_settlement::
                status_recovered(),
        71,
    );

    assert!(
        bad_debt_settlement::
            record_recovered_amount(
                &registry,
                record_id,
            ) == BAD_DEBT_AMOUNT,
        72,
    );

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) == 0,
        73,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(
            &pool,
        ) == BAD_DEBT_AMOUNT,
        74,
    );

    assert!(
        lending_pool::available_liquidity(
            &pool,
        ) == BAD_DEBT_AMOUNT,
        75,
    );

    lending_pool::
        assert_bad_debt_accounting_invariant(
            &pool,
        );

    let insurance_remaining =
        insurance_fund::drain_for_testing(
            &mut fund,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(
        insurance_remaining,
    );

    let pool_remaining =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(
        pool_remaining,
    );

    bad_debt_settlement::
        destroy_admin_cap_for_testing(
            registry_cap,
        );

    bad_debt_settlement::destroy_for_testing(
        registry,
    );

    insurance_fund::
        destroy_admin_cap_for_testing(
            insurance_cap,
        );

    insurance_fund::destroy_for_testing(
        fund,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 8 — Recovery Above Remaining Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::bad_debt_settlement,
)]
fun test_08_recovery_above_remaining_rejected() {
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

    let mut registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let record_id =
        bad_debt_settlement::record_bad_debt(
            &access,
            &mut registry,
            &mut pool,
            1,
            1,
            BORROWER,
            BAD_DEBT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        bad_debt_settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::link_insurance_claim(
        &mut registry,
        &cap,
        record_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    let too_much =
        coin::mint_for_testing<SUI>(
            BAD_DEBT_AMOUNT + 1,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::apply_recovery(
        &access,
        &mut registry,
        &mut pool,
        record_id,
        too_much,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
