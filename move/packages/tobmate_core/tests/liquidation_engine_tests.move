#[test_only]
module tobmate_core::liquidation_engine_tests;

use tobmate_core::liquidation_engine;

/* ============================================================
   Stage 6D-1
   Liquidation Engine Tests
   Part 1 — Tests 1~4
   ============================================================ */

/* ============================================================
   Test 1 — Constants
   ============================================================ */

#[test]
fun test_01_constants() {
    assert!(
        liquidation_engine::basis_point_denominator()
            == 10_000,
        1,
    );

    assert!(
        liquidation_engine::healthy_health_factor_bps()
            == 10_000,
        2,
    );
}

/* ============================================================
   Test 2 — Asset Value
   ============================================================ */

#[test]
fun test_02_asset_value() {
    let value =
        liquidation_engine::asset_value(
            100,
            100_000_000,
            100_000_000,
        );

    assert!(value == 100, 1);
}

/* ============================================================
   Test 3 — Adjusted Collateral
   ============================================================ */

#[test]
fun test_03_adjusted_collateral_value() {
    let adjusted =
        liquidation_engine::adjusted_collateral_value(
            100,
            100_000_000,
            100_000_000,
            8_000,
        );

    assert!(adjusted == 80, 1);
}

/* ============================================================
   Test 4 — Healthy Position
   ============================================================ */

#[test]
fun test_04_healthy_position() {
    let health_factor =
        liquidation_engine::calculate_health_factor_bps(
            100,
            100_000_000,
            70,
            100_000_000,
            100_000_000,
            8_000,
        );

    assert!(health_factor > 10_000, 1);

    assert!(
        !liquidation_engine::position_is_liquidatable(
            100,
            100_000_000,
            70,
            100_000_000,
            100_000_000,
            8_000,
        ),
        2,
    );
}

/* ============================================================
   Test 5 — Liquidatable Position
   ============================================================ */

#[test]
fun test_05_liquidatable_position() {
    let health_factor =
        liquidation_engine::calculate_health_factor_bps(
            100,
            100_000_000,
            85,
            100_000_000,
            100_000_000,
            8_000,
        );

    assert!(health_factor < 10_000, 1);

    assert!(
        liquidation_engine::position_is_liquidatable(
            100,
            100_000_000,
            85,
            100_000_000,
            100_000_000,
            8_000,
        ),
        2,
    );
}

/* ============================================================
   Test 6 — Exact Health Factor Boundary
   ============================================================ */

#[test]
fun test_06_exact_health_factor_boundary() {
    let health_factor =
        liquidation_engine::calculate_health_factor_bps(
            100,
            100_000_000,
            80,
            100_000_000,
            100_000_000,
            8_000,
        );

    assert!(health_factor == 10_000, 1);

    assert!(
        !liquidation_engine::position_is_liquidatable(
            100,
            100_000_000,
            80,
            100_000_000,
            100_000_000,
            8_000,
        ),
        2,
    );
}

/* ============================================================
   Test 7 — Close Factor
   ============================================================ */

#[test]
fun test_07_close_factor() {
    let max_repay =
        liquidation_engine::calculate_max_repay(
            1_000,
            5_000,
        );

    assert!(max_repay == 500, 1);

    let full_repay =
        liquidation_engine::calculate_max_repay(
            1_000,
            10_000,
        );

    assert!(full_repay == 1_000, 2);
}

/* ============================================================
   Test 8 — Liquidation Bonus
   ============================================================ */

#[test]
fun test_08_liquidation_bonus() {
    let seize_amount =
        liquidation_engine::calculate_seize_amount(
            100,
            100_000_000,
            100_000_000,
            500,
        );

    assert!(seize_amount == 105, 1);
}

/* ============================================================
   Test 9 — Full Liquidation Quote
   ============================================================ */

#[test]
fun test_09_full_liquidation_quote() {
    let mut scenario =
        sui::test_scenario::begin(@0xA);

    let ctx = scenario.ctx();

    let mut engine =
        liquidation_engine::new_for_testing(
            8_000,
            5_000,
            500,
            ctx,
        );

    /*
       Collateral:
       100 units × $100 = $10,000
       threshold 80% = $8,000

       Debt:
       85 units × $100 = $8,500

       Health Factor:
       8000 / 8500 = 0.9411

       Close Factor:
       50% of 85 = 42

       Requested repay:
       40

       Bonus:
       5%

       Seize:
       42 collateral units
    */

    let quote =
        liquidation_engine::quote_liquidation(
            &mut engine,

            100,
            100_000_000,

            85,
            100_000_000,

            100_000_000,

            40,
        );

    assert!(
        liquidation_engine::quote_is_liquidatable(
            &quote,
        ),
        1,
    );

    assert!(
        liquidation_engine::quote_health_factor_bps(
            &quote,
        ) < 10_000,
        2,
    );

    assert!(
        liquidation_engine::quote_max_repay_amount(
            &quote,
        ) == 42,
        3,
    );

    assert!(
        liquidation_engine::quote_repay_amount(
            &quote,
        ) == 40,
        4,
    );

    assert!(
        liquidation_engine::quote_seize_amount(
            &quote,
        ) == 42,
        5,
    );

    assert!(
        liquidation_engine::total_liquidation_quotes(
            &engine,
        ) == 1,
        6,
    );

    liquidation_engine::destroy_for_testing(engine);

    scenario.end();
}

/* ============================================================
   Test 10 — Close Factor Protection
   ============================================================ */

#[test]
#[expected_failure(abort_code = 10)]
fun test_10_reject_above_close_factor() {
    let mut scenario =
        sui::test_scenario::begin(@0xA);

    let ctx = scenario.ctx();

    let mut engine =
        liquidation_engine::new_for_testing(
            8_000,
            5_000,
            500,
            ctx,
        );

    /*
       Debt = 100

       Close Factor = 50%

       Maximum repay = 50

       Requested repay = 51

       MUST ABORT
    */

    let _quote =
        liquidation_engine::quote_liquidation(
            &mut engine,

            100,
            100_000_000,

            100,
            100_000_000,

            100_000_000,

            51,
        );

    liquidation_engine::destroy_for_testing(engine);

    scenario.end();
}
