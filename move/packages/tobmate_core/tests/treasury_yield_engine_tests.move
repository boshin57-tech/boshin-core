#[test_only]
module tobmate_core::treasury_yield_engine_tests;

use sui::coin::{Self};
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
};

const ADMIN: address = @0xAD;
const STRATEGY_OPERATOR: address = @0x51;

const STRATEGY_KEY: vector<u8> =
    b"TOBMATE_SUI_LP";

const FUND_AMOUNT: u64 =
    1_000_000_000;

const ALLOCATION_LIMIT: u64 =
    700_000_000;

const ALLOCATION_AMOUNT: u64 =
    400_000_000;

const RETURN_AMOUNT: u64 =
    150_000_000;

const YIELD_AMOUNT: u64 =
    50_000_000;

const LOSS_AMOUNT: u64 =
    25_000_000;

#[test]
fun initial_state_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        yield_engine::version(&engine) == 1,
        100,
    );

    assert!(
        !yield_engine::is_paused(&engine),
        101,
    );

    assert!(
        yield_engine::idle_balance(&engine) == 0,
        102,
    );

    assert!(
        yield_engine::strategy_count(&engine) == 0,
        103,
    );

    assert!(
        yield_engine::total_funded(&engine) == 0,
        104,
    );

    assert!(
        yield_engine::total_allocated(&engine) == 0,
        105,
    );

    assert!(
        yield_engine::outstanding_principal(
            &engine,
        ) == 0,
        106,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    test_scenario::end(scenario);
}

#[test]
fun strategy_registration_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            STRATEGY_KEY,
            ALLOCATION_LIMIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        strategy_id == 1,
        200,
    );

    assert!(
        yield_engine::strategy_count(
            &engine,
        ) == 1,
        201,
    );

    assert!(
        yield_engine::strategy_allocation_limit(
            &engine,
            strategy_id,
        ) == ALLOCATION_LIMIT,
        202,
    );

    assert!(
        !yield_engine::strategy_is_active(
            &engine,
            strategy_id,
        ),
        203,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        cap,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::treasury_yield_engine,
)]
fun duplicate_strategy_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::register_strategy(
        &cap,
        &mut engine,
        STRATEGY_KEY,
        ALLOCATION_LIMIT,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    yield_engine::register_strategy(
        &cap,
        &mut engine,
        STRATEGY_KEY,
        ALLOCATION_LIMIT,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::treasury_yield_engine,
)]
fun inactive_strategy_blocks_allocation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            STRATEGY_KEY,
            ALLOCATION_LIMIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        payment,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        ALLOCATION_AMOUNT,
        STRATEGY_OPERATOR,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::treasury_yield_engine,
)]
fun allocation_above_strategy_limit_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            STRATEGY_KEY,
            ALLOCATION_LIMIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        ALLOCATION_LIMIT + 1,
        STRATEGY_OPERATOR,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
fun allocation_return_yield_and_loss_accounting_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            STRATEGY_KEY,
            ALLOCATION_LIMIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        ALLOCATION_AMOUNT,
        STRATEGY_OPERATOR,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        yield_engine::idle_balance(&engine)
            == FUND_AMOUNT - ALLOCATION_AMOUNT,
        300,
    );

    assert!(
        yield_engine::outstanding_principal(&engine)
            == ALLOCATION_AMOUNT,
        301,
    );

    let returned =
        coin::mint_for_testing<SUI>(
            RETURN_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::return_capital(
        &access,
        &mut engine,
        strategy_id,
        returned,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let realized_yield =
        coin::mint_for_testing<SUI>(
            YIELD_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::record_yield(
        &access,
        &mut engine,
        strategy_id,
        realized_yield,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        LOSS_AMOUNT,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        yield_engine::total_returned(&engine)
            == RETURN_AMOUNT,
        302,
    );

    assert!(
        yield_engine::gross_yield(&engine)
            == YIELD_AMOUNT,
        303,
    );

    assert!(
        yield_engine::recognized_loss(&engine)
            == LOSS_AMOUNT,
        304,
    );

    assert!(
        yield_engine::outstanding_principal(&engine)
            ==
            ALLOCATION_AMOUNT
                - RETURN_AMOUNT
                - LOSS_AMOUNT,
        305,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    let remaining =
        yield_engine::outstanding_principal(
            &engine,
        );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        remaining,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let drained =
        yield_engine::drain_for_testing(
            &mut engine,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::treasury_yield_engine,
)]
fun loss_above_outstanding_principal_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            STRATEGY_KEY,
            ALLOCATION_LIMIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        1,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::treasury_yield_engine,
)]
fun return_above_outstanding_principal_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            STRATEGY_KEY,
            ALLOCATION_LIMIT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let returned =
        coin::mint_for_testing<SUI>(
            1,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::return_capital(
        &access,
        &mut engine,
        strategy_id,
        returned,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::treasury_yield_engine,
)]
fun paused_engine_blocks_funding() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::set_paused(
        &cap,
        &mut engine,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    yield_engine::fund(
        &access,
        &mut engine,
        funding,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
fun version_update_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_version(
        &cap,
        &mut engine,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::version(&engine) == 2,
        400,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        cap,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Stage 9 Part 2-A
   Global Exposure Risk Controls
   ============================================================ */


/* Test 11 — Default Global Exposure Is 100 Percent */

#[test]
fun test_11_default_global_exposure_is_full() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        yield_engine::global_exposure_limit_bps(
            &engine,
        ) == 10_000,
        1100,
    );

    assert!(
        yield_engine::current_global_exposure_bps(
            &engine,
        ) == 0,
        1101,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    test_scenario::end(scenario);
}


/* Test 12 — Global Exposure Limit Update Succeeds */

#[test]
fun test_12_global_exposure_limit_update_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_global_exposure_limit_bps(
        &cap,
        &mut engine,
        7_500,
    );

    assert!(
        yield_engine::global_exposure_limit_bps(
            &engine,
        ) == 7_500,
        1200,
    );

    assert!(
        yield_engine::maximum_global_exposure(
            &engine,
        ) == 0,
        1201,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        cap,
    );

    test_scenario::end(scenario);
}


/* Test 13 — Allocation Above Global Exposure Cap Rejected */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_13_allocation_above_global_exposure_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"GLOBAL_CAP_TEST",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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

    yield_engine::set_global_exposure_limit_bps(
        &cap,
        &mut engine,
        5_000,
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_001,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 14 — Cannot Lower Cap Below Current Exposure */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_14_cannot_lower_cap_below_current_exposure() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOWER_CAP_TEST",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        600_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_global_exposure_limit_bps(
        &cap,
        &mut engine,
        5_000,
    );

    abort 999
}


/* ============================================================
   Stage 9 Part 2-B
   Per-Strategy Concentration Risk Controls
   ============================================================ */


/* Test 15 — Default Strategy Concentration Is 100 Percent */

#[test]
fun test_15_default_strategy_concentration_is_full() {
    let mut scenario = test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"CONCENTRATION_DEFAULT",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        yield_engine::strategy_concentration_limit_bps(
            &engine,
            strategy_id,
        ) == 10_000,
        1500,
    );

    assert!(
        yield_engine::strategy_current_concentration_bps(
            &engine,
            strategy_id,
        ) == 0,
        1501,
    );

    yield_engine::destroy_empty_for_testing(engine);
    yield_engine::destroy_admin_cap_for_testing(cap);

    test_scenario::end(scenario);
}


/* Test 16 — Strategy Concentration Limit Update Succeeds */

#[test]
fun test_16_strategy_concentration_limit_update_succeeds() {
    let mut scenario = test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"CONCENTRATION_UPDATE",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_id,
        4_000,
    );

    assert!(
        yield_engine::strategy_concentration_limit_bps(
            &engine,
            strategy_id,
        ) == 4_000,
        1600,
    );

    yield_engine::destroy_empty_for_testing(engine);
    yield_engine::destroy_admin_cap_for_testing(cap);

    test_scenario::end(scenario);
}


/* Test 17 — Allocation Above Strategy Concentration Rejected */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_17_allocation_above_strategy_concentration_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"CONCENTRATION_BLOCK",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_id,
        4_000,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_001,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 18 — Cannot Lower Concentration Below Current Exposure */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_18_cannot_lower_concentration_below_current_exposure() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"CONCENTRATION_LOWER",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        600_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_id,
        5_000,
    );

    abort 999
}


/* ============================================================
   Stage 9 Part 2-C
   Multi-Strategy Exposure Invariants
   ============================================================ */


/* Test 19 — Multiple Strategies Preserve Individual Concentration */

#[test]
#[expected_failure(abort_code = 0)]
fun test_19_multiple_strategies_preserve_individual_concentration() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_a =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"MULTI_STRATEGY_A",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let strategy_b =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"MULTI_STRATEGY_B",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_a,
        4_000,
    );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_b,
        5_000,
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
        &cap,
        &access,
        &mut engine,
        strategy_a,
        350_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_b,
        450_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_a,
        ) == 350_000_000,
        1900,
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_b,
        ) == 450_000_000,
        1901,
    );

    assert!(
        yield_engine::outstanding_principal(
            &engine,
        ) == 800_000_000,
        1902,
    );

    assert!(
        yield_engine::strategy_current_concentration_bps(
            &engine,
            strategy_a,
        ) == 3_500,
        1903,
    );

    assert!(
        yield_engine::strategy_current_concentration_bps(
            &engine,
            strategy_b,
        ) == 4_500,
        1904,
    );

    assert!(
        yield_engine::current_global_exposure_bps(
            &engine,
        ) == 8_000,
        1905,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    abort 0
}


/* Test 20 — Global Cap Overrides Individual Strategy Capacity */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_20_global_cap_overrides_individual_strategy_capacity() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_a =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"GLOBAL_OVERRIDE_A",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let strategy_b =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"GLOBAL_OVERRIDE_B",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_a,
        6_000,
    );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_b,
        6_000,
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

    yield_engine::set_global_exposure_limit_bps(
        &cap,
        &mut engine,
        7_000,
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_a,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Strategy B itself could hold up to 60%.
     * But total exposure would become 80%,
     * exceeding the global 70% cap.
     */
    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_b,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 21 — Return Recalculates Global And Strategy Exposure */

#[test]
#[expected_failure(abort_code = 0)]
fun test_21_return_recalculates_exposure() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"RETURN_EXPOSURE",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        600_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    let returned =
        coin::mint_for_testing<SUI>(
            200_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::return_capital(
        &access,
        &mut engine,
        strategy_id,
        returned,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_id,
        ) == 400_000_000,
        2100,
    );

    assert!(
        yield_engine::strategy_current_concentration_bps(
            &engine,
            strategy_id,
        ) == 4_000,
        2101,
    );

    assert!(
        yield_engine::current_global_exposure_bps(
            &engine,
        ) == 4_000,
        2102,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    abort 0
}


/* Test 22 — Strategy Loss Preserves Cross Strategy Isolation */

#[test]
#[expected_failure(abort_code = 0)]
fun test_22_strategy_loss_preserves_cross_strategy_isolation() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_a =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_ISOLATION_A",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let strategy_b =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_ISOLATION_B",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_a,
        300_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_b,
        300_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_a,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_a,
        ) == 200_000_000,
        2200,
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_b,
        ) == 300_000_000,
        2201,
    );

    assert!(
        yield_engine::outstanding_principal(
            &engine,
        ) == 500_000_000,
        2202,
    );

    assert!(
        yield_engine::recognized_loss(
            &engine,
        ) == 100_000_000,
        2203,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    abort 0
}


/* ============================================================
   Stage 9 Part 2-D
   Loss-Triggered Allocation Guard Tests
   ============================================================ */


/* Test 23 — Loss Automatically Activates Guard */

#[test]
#[expected_failure(abort_code = 0)]
fun test_23_loss_automatically_activates_guard() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_GUARD_AUTO",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_is_loss_guarded(
            &engine,
            strategy_id,
        ),
        2300,
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_id,
        ) == 400_000_000,
        2301,
    );

    yield_engine::assert_accounting_invariant(&engine);

    abort 0
}


/* Test 24 — Guarded Strategy Blocks New Allocation */

#[test]
#[expected_failure(
    abort_code = 18,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_24_guarded_strategy_blocks_new_allocation() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_GUARD_BLOCK",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        50_000_000,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        10_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 25 — Admin Clear Allows Allocation Again */

#[test]
#[expected_failure(abort_code = 0)]
fun test_25_admin_clear_allows_allocation_again() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_GUARD_CLEAR",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        50_000_000,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::clear_strategy_loss_guard(
        &cap,
        &mut engine,
        strategy_id,
    );

    assert!(
        !yield_engine::strategy_is_loss_guarded(
            &engine,
            strategy_id,
        ),
        2500,
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        10_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_id,
        ) == 360_000_000,
        2501,
    );

    abort 0
}


/* Test 26 — Loss Guard Is Isolated Per Strategy */

#[test]
#[expected_failure(abort_code = 0)]
fun test_26_loss_guard_isolated_per_strategy() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_a =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_GUARD_A",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let strategy_b =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"LOSS_GUARD_B",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
        &mut engine,
        strategy_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_a,
        300_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_b,
        300_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_a,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_is_loss_guarded(
            &engine,
            strategy_a,
        ),
        2600,
    );

    assert!(
        !yield_engine::strategy_is_loss_guarded(
            &engine,
            strategy_b,
        ),
        2601,
    );

    yield_engine::allocate_capital(
        &cap,
        &access,
        &mut engine,
        strategy_b,
        50_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_b,
        ) == 350_000_000,
        2602,
    );

    abort 0
}


/* ============================================================
   Stage 9 Part 2-E
   Security / Boundary Tests
   ============================================================ */


/* Test 27 — Zero Global Exposure Limit Rejected */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_27_zero_global_exposure_limit_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_global_exposure_limit_bps(
        &cap,
        &mut engine,
        0,
    );

    abort 999
}


/* Test 28 — Global Exposure Above 100 Percent Rejected */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_28_global_exposure_above_max_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_global_exposure_limit_bps(
        &cap,
        &mut engine,
        10_001,
    );

    abort 999
}


/* Test 29 — Zero Strategy Concentration Rejected */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_29_zero_strategy_concentration_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"BOUNDARY_CONCENTRATION_ZERO",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_id,
        0,
    );

    abort 999
}


/* Test 30 — Strategy Concentration Above 100 Percent Rejected */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_30_strategy_concentration_above_max_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"BOUNDARY_CONCENTRATION_HIGH",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_concentration_limit_bps(
        &cap,
        &mut engine,
        strategy_id,
        10_001,
    );

    abort 999
}


/* Test 31 — Duplicate Loss Guard Clear Rejected */

#[test]
#[expected_failure(
    abort_code = 19,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_31_duplicate_loss_guard_clear_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"DUPLICATE_GUARD_CLEAR",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        400_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        50_000_000,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::clear_strategy_loss_guard(
        &cap,
        &mut engine,
        strategy_id,
    );

    yield_engine::clear_strategy_loss_guard(
        &cap,
        &mut engine,
        strategy_id,
    );

    abort 999
}


/* Test 32 — Principal Return Preserves Loss Guard And Accounting */

#[test]
#[expected_failure(abort_code = 0)]
fun test_32_principal_return_preserves_loss_guard_and_accounting() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &cap,
            &mut engine,
            b"RETURN_AFTER_LOSS",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &cap,
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
        &cap,
        &access,
        &mut engine,
        strategy_id,
        500_000_000,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::record_loss(
        &cap,
        &access,
        &mut engine,
        strategy_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_is_loss_guarded(
            &engine,
            strategy_id,
        ),
        3200,
    );

    /*
     * Returning principal must remain possible even while
     * new allocations are loss-guarded.
     */
    let returned =
        coin::mint_for_testing<SUI>(
            150_000_000,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::return_capital(
        &access,
        &mut engine,
        strategy_id,
        returned,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_is_loss_guarded(
            &engine,
            strategy_id,
        ),
        3201,
    );

    assert!(
        yield_engine::strategy_outstanding_principal(
            &engine,
            strategy_id,
        ) == 250_000_000,
        3202,
    );

    assert!(
        yield_engine::recognized_loss(
            &engine,
        ) == 100_000_000,
        3203,
    );

    assert!(
        yield_engine::total_returned(
            &engine,
        ) == 150_000_000,
        3204,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    abort 0
}
