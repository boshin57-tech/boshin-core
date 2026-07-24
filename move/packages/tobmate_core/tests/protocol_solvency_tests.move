#[test_only]
module tobmate_core::protocol_solvency_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::bad_debt_settlement;

use tobmate_core::insurance_fund;

use tobmate_core::lending_pool;

use tobmate_core::protocol_solvency;

use tobmate_core::treasury;

use tobmate_core::treasury_backstop;

const ADMIN: address = @0xA;
const BORROWER: address = @0xB;


/* ============================================================
   Test 01 — Zero Debt Is Fully Covered
   ============================================================ */

#[test]
fun test_01_zero_debt_is_fully_covered() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let pool =
        lending_pool::new_for_testing(
            1_000,
            500,
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

    assert!(
        protocol_solvency::is_fully_covered(
            &pool,
            &insurance,
            &protocol_treasury,
        ),
        1,
    );

    assert!(
        protocol_solvency::coverage_bps(
            &pool,
            &insurance,
            &protocol_treasury,
        ) == 10_000,
        2,
    );

    insurance_fund::destroy_for_testing(
        insurance,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Bad Debt Fully Covered
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_02_bad_debt_fully_covered() {
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

    protocol_solvency::
        assert_protocol_accounting_invariant(
            &pool,
            &debt_registry,
            &insurance,
            &protocol_treasury,
        );

    assert!(
        protocol_solvency::loss_absorption_capacity(
            &pool,
            &insurance,
            &protocol_treasury,
        ) == 1_000,
        10,
    );

    assert!(
        protocol_solvency::coverage_bps(
            &pool,
            &insurance,
            &protocol_treasury,
        ) == 10_000,
        11,
    );

    assert!(
        protocol_solvency::is_fully_covered(
            &pool,
            &insurance,
            &protocol_treasury,
        ),
        12,
    );

    abort 0
}


/* ============================================================
   Test 03 — Bad Debt Under-Covered
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_03_bad_debt_undercovered() {
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

    assert!(
        protocol_solvency::loss_absorption_capacity(
            &pool,
            &insurance,
            &protocol_treasury,
        ) == 500,
        20,
    );

    assert!(
        protocol_solvency::coverage_bps(
            &pool,
            &insurance,
            &protocol_treasury,
        ) == 5_000,
        21,
    );

    assert!(
        !protocol_solvency::is_fully_covered(
            &pool,
            &insurance,
            &protocol_treasury,
        ),
        22,
    );

    abort 0
}


/* ============================================================
   Test 04
   Insurance + Treasury Recovery → Solvent Snapshot
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_04_recovery_produces_solvent_snapshot() {
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

    let mut insurance =
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

    /* Fund Insurance = 400 */

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

    /* Fund Treasury = 600 */

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

    /* Create bad debt = 1,000 */

    let record_id =
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

    /* Submit insurance claim */

    let claim_id =
        bad_debt_settlement::
            submit_insurance_claim_for_bad_debt(
                &access,
                &mut debt_registry,
                &debt_cap,
                &mut insurance,
                record_id,
                b"solvency-e2e",
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
        400,
        8001,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::pay_claim(
        &insurance_cap,
        &access,
        &mut insurance,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    /* Receive insurance payment */

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

    /* Remaining bad debt must be 600 */

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) == 600,
        40,
    );

    /* Treasury absorbs remaining 600 */

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

    /* Cross-module accounting must still hold */

    protocol_solvency::
        assert_protocol_accounting_invariant(
            &pool,
            &debt_registry,
            &insurance,
            &protocol_treasury,
        );

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) == 0,
        41,
    );

    assert!(
        lending_pool::total_bad_debt_created(
            &pool,
        ) == 1_000,
        42,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(
            &pool,
        ) == 1_000,
        43,
    );

    /* Create final solvency snapshot */

    let snapshot =
        protocol_solvency::snapshot(
            &pool,
            &debt_registry,
            &insurance,
            &protocol_treasury,
            &backstop,
        );

    assert!(
        protocol_solvency::
            snapshot_outstanding_bad_debt(
                &snapshot,
            ) == 0,
        44,
    );

    assert!(
        protocol_solvency::
            snapshot_total_bad_debt_created(
                &snapshot,
            ) == 1_000,
        45,
    );

    assert!(
        protocol_solvency::
            snapshot_total_bad_debt_recovered(
                &snapshot,
            ) == 1_000,
        46,
    );

    assert!(
        protocol_solvency::
            snapshot_total_treasury_backstop_paid(
                &snapshot,
            ) == 600,
        47,
    );

    assert!(
        protocol_solvency::
            snapshot_coverage_bps(
                &snapshot,
            ) == 10_000,
        48,
    );

    assert!(
        protocol_solvency::is_fully_covered(
            &pool,
            &insurance,
            &protocol_treasury,
        ),
        49,
    );

    /*
       Intentional abort avoids lengthy test-object cleanup.
       All assertions above must execute first.
    */

    abort 0
}


/* ============================================================
   Test 05 — Snapshot Preserves Coverage State
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_05_snapshot_preserves_undercovered_state() {
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

    let backstop =
        treasury_backstop::new_for_testing(
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

    let snapshot =
        protocol_solvency::snapshot(
            &pool,
            &debt_registry,
            &insurance,
            &protocol_treasury,
            &backstop,
        );

    assert!(
        protocol_solvency::
            snapshot_outstanding_bad_debt(
                &snapshot,
            ) == 1_000,
        50,
    );

    assert!(
        protocol_solvency::
            snapshot_loss_absorption_capacity(
                &snapshot,
            ) == 500,
        51,
    );

    assert!(
        protocol_solvency::
            snapshot_coverage_bps(
                &snapshot,
            ) == 5_000,
        52,
    );

    abort 0
}


/* ============================================================
   Test 06 — Cross Module Accounting Holds
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_06_cross_module_accounting_holds() {
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

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        100,
        200,
        BORROWER,
        750,
        test_scenario::ctx(&mut scenario),
    );

    protocol_solvency::
        assert_protocol_accounting_invariant(
            &pool,
            &debt_registry,
            &insurance,
            &protocol_treasury,
        );

    assert!(
        lending_pool::total_bad_debt_created(
            &pool,
        ) ==
        bad_debt_settlement::
            total_bad_debt_recorded(
                &debt_registry,
            ),
        60,
    );

    assert!(
        lending_pool::total_bad_debt_recovered(
            &pool,
        ) ==
        bad_debt_settlement::total_recovered(
            &debt_registry,
        ),
        61,
    );

    assert!(
        lending_pool::outstanding_bad_debt(
            &pool,
        ) == 750,
        62,
    );

    abort 0
}
