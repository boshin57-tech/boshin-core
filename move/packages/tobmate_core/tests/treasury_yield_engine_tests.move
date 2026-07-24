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
