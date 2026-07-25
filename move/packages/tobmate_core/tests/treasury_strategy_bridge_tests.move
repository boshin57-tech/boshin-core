#[test_only]
module tobmate_core::treasury_strategy_bridge_tests;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::treasury::{
    Self as treasury,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
};

use tobmate_core::treasury_strategy_bridge::{
    Self as strategy_bridge,
};

const ADMIN: address = @0xAD;
const STRATEGY_OPERATOR: address = @0xBEEF;

const TREASURY_FUND: u64 = 1_000_000_000;
const DEPLOY_AMOUNT: u64 = 600_000_000;
const ALLOCATE_AMOUNT: u64 = 400_000_000;
const RETURN_AMOUNT: u64 = 400_000_000;
const YIELD_AMOUNT: u64 = 50_000_000;


/* ============================================================
   Test 01
   Treasury → Yield Engine Deployment
   ============================================================ */

#[test]
fun test_01_treasury_to_yield_engine_deployment_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
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

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUND,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_bridge::deploy_to_yield_engine(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        DEPLOY_AMOUNT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == TREASURY_FUND - DEPLOY_AMOUNT,
        100,
    );

    assert!(
        treasury::total_withdrawn(&protocol_treasury)
            == DEPLOY_AMOUNT,
        101,
    );

    assert!(
        yield_engine::idle_balance(&engine)
            == DEPLOY_AMOUNT,
        102,
    );

    assert!(
        yield_engine::total_funded(&engine)
            == DEPLOY_AMOUNT,
        103,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    strategy_bridge::sweep_to_treasury(
        &yield_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        DEPLOY_AMOUNT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::total_swept_to_treasury(&engine)
            == DEPLOY_AMOUNT,
        104,
    );

    // Remove Treasury funds through the normal accounting path.
    treasury::withdraw(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        TREASURY_FUND,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let withdrawn =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    coin::burn_for_testing(withdrawn);

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    treasury::destroy_admin_cap_for_testing(
        treasury_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Full Strategy Round Trip
   ============================================================ */

#[test]
fun test_02_full_strategy_round_trip_preserves_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUND,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        treasury_funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_bridge::deploy_to_yield_engine(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        DEPLOY_AMOUNT,
        test_scenario::ctx(&mut scenario),
    );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"stage9-e2e",
            ALLOCATE_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::set_strategy_active(
        &yield_cap,
        &mut engine,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    yield_engine::allocate_capital(
        &yield_cap,
        &access,
        &mut engine,
        strategy_id,
        ALLOCATE_AMOUNT,
        STRATEGY_OPERATOR,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::outstanding_principal(&engine)
            == ALLOCATE_AMOUNT,
        200,
    );

    /*
     * Strategy operator receives the actually deployed Coin.
     */
    test_scenario::next_tx(
        &mut scenario,
        STRATEGY_OPERATOR,
    );

    let strategy_capital =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    assert!(
        coin::value(&strategy_capital)
            == ALLOCATE_AMOUNT,
        201,
    );

    /*
     * Return the actual deployed principal.
     */
    yield_engine::return_capital(
        &access,
        &mut engine,
        strategy_id,
        strategy_capital,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Simulate externally realized strategy yield.
     */
    let realized_yield =
        coin::mint_for_testing<SUI>(
            YIELD_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    yield_engine::record_yield(
        &access,
        &mut engine,
        strategy_id,
        realized_yield,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::outstanding_principal(&engine)
            == 0,
        202,
    );

    assert!(
        yield_engine::gross_yield(&engine)
            == YIELD_AMOUNT,
        203,
    );

    let sweep_amount =
        DEPLOY_AMOUNT + YIELD_AMOUNT;

    strategy_bridge::sweep_to_treasury(
        &yield_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        sweep_amount,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::idle_balance(&engine) == 0,
        204,
    );

    assert!(
        yield_engine::total_swept_to_treasury(&engine)
            == sweep_amount,
        205,
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == TREASURY_FUND + YIELD_AMOUNT,
        206,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    /*
     * Clean Treasury through its normal withdrawal path.
     */
    treasury::withdraw(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        TREASURY_FUND + YIELD_AMOUNT,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let final_treasury_coin =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    assert!(
        coin::value(&final_treasury_coin)
            == TREASURY_FUND + YIELD_AMOUNT,
        207,
    );

    coin::burn_for_testing(
        final_treasury_coin,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    treasury::destroy_admin_cap_for_testing(
        treasury_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   Partial Sweep Preserves Cross-Module Accounting
   ============================================================ */

#[test]
fun test_03_partial_sweep_preserves_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUND,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_bridge::deploy_to_yield_engine(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        DEPLOY_AMOUNT,
        test_scenario::ctx(&mut scenario),
    );

    strategy_bridge::sweep_to_treasury(
        &yield_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        200_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::idle_balance(&engine)
            == 400_000_000,
        300,
    );

    assert!(
        yield_engine::total_swept_to_treasury(&engine)
            == 200_000_000,
        301,
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == 600_000_000,
        302,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    yield_engine::assert_accounting_invariant(
        &engine,
    );

    strategy_bridge::sweep_to_treasury(
        &yield_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        400_000_000,
        test_scenario::ctx(&mut scenario),
    );

    treasury::withdraw(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        TREASURY_FUND,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(&mut scenario, ADMIN);

    let withdrawn =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    coin::burn_for_testing(withdrawn);

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    treasury::destroy_admin_cap_for_testing(
        treasury_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Sweep Above Idle Balance Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::treasury_yield_engine,
)]
fun test_04_sweep_above_idle_balance_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            TREASURY_FUND,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access,
        &mut protocol_treasury,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    strategy_bridge::deploy_to_yield_engine(
        &treasury_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        DEPLOY_AMOUNT,
        test_scenario::ctx(&mut scenario),
    );

    strategy_bridge::sweep_to_treasury(
        &yield_cap,
        &access,
        &mut protocol_treasury,
        &mut engine,
        DEPLOY_AMOUNT + 1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
