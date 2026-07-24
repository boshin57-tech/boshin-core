#[test_only]
module tobmate_core::lending_pool_tests;

use sui::coin::{Self};
use sui::object;
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::collateral_manager::{
    Self as collateral_manager,
};

use tobmate_core::lending_pool::{
    Self as lending_pool,
};

use tobmate_core::oracle_price_router::{
    Self as oracle_price_router,
};

const ADMIN: address = @0xAD;
const OWNER: address = @0xBEEF;

const RESERVE_FACTOR_BPS: u64 = 1_000;
const BASE_BORROW_RATE_BPS: u64 = 500;

const SUPPLY_AMOUNT: u64 = 10_000;
const BORROW_AMOUNT: u64 = 1_000;

const COLLATERAL_TYPE_SUI: u8 = 1;
const ASSET_KEY: vector<u8> = b"SUI";
const ORACLE_SYMBOL: vector<u8> = b"SUI_USD";
const ORACLE_FEED_ID: u64 = 1;
const ASSET_DECIMALS: u8 = 9;

const MAX_LTV_BPS: u64 = 7_000;
const LIQ_THRESHOLD_BPS: u64 = 8_000;
const LIQ_BONUS_BPS: u64 = 500;

const COLLATERAL_AMOUNT: u64 =
    1_000_000_000;

#[test]
fun initial_state_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        lending_pool::version(&pool) == 1,
        100,
    );

    assert!(
        !lending_pool::is_paused(&pool),
        101,
    );

    assert!(
        lending_pool::available_liquidity(
            &pool,
        ) == 0,
        102,
    );

    assert!(
        lending_pool::utilization_bps(
            &pool,
        ) == 0,
        103,
    );

    lending_pool::assert_accounting_invariant(
        &pool,
    );

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    test_scenario::end(scenario);
}

#[test]
fun supply_succeeds() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let position_id =
        lending_pool::supply(
            &access,
            &mut pool,
            payment,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        position_id == 1,
        200,
    );

    assert!(
        lending_pool::available_liquidity(
            &pool,
        ) == SUPPLY_AMOUNT,
        201,
    );

    assert!(
        lending_pool::supply_position_principal(
            &pool,
            position_id,
        ) == SUPPLY_AMOUNT,
        202,
    );

    lending_pool::assert_accounting_invariant(
        &pool,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

#[test]
fun supply_withdrawal_succeeds() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let position_id =
        lending_pool::supply(
            &access,
            &mut pool,
            payment,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let withdrawn =
        lending_pool::withdraw_supply(
            &access,
            &mut pool,
            position_id,
            4_000,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        coin::value(&withdrawn) == 4_000,
        300,
    );

    assert!(
        lending_pool::available_liquidity(
            &pool,
        ) == 6_000,
        301,
    );

    assert!(
        lending_pool::supply_position_principal(
            &pool,
            position_id,
        ) == 6_000,
        302,
    );

    lending_pool::assert_accounting_invariant(
        &pool,
    );

    coin::burn_for_testing(withdrawn);

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

#[test]
fun borrow_and_repay_succeeds() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let collateral_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let supply_coin =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply_coin,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let borrowed =
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            collateral_position_id,
            BORROW_AMOUNT,
            &quote,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        coin::value(&borrowed)
            == BORROW_AMOUNT,
        400,
    );

    assert!(
        lending_pool::outstanding_borrow_principal(
            &pool,
        ) == BORROW_AMOUNT,
        401,
    );

    assert!(
        collateral_manager::position_debt_value(
            &collateral,
            collateral_position_id,
        ) == BORROW_AMOUNT,
        402,
    );

    coin::burn_for_testing(borrowed);

    let repayment =
        coin::mint_for_testing<SUI>(
            400,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::repay(
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        repayment,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        lending_pool::borrow_position_principal_debt(
            &pool,
            1,
        ) == 600,
        403,
    );

    assert!(
        collateral_manager::position_debt_value(
            &collateral,
            collateral_position_id,
        ) == 600,
        404,
    );

    assert!(
        lending_pool::available_liquidity(
            &pool,
        ) == 9_400,
        405,
    );

    lending_pool::assert_accounting_invariant(
        &pool,
    );

    collateral_manager::assert_accounting_invariant(
        &collateral,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    lending_pool::destroy_admin_cap_for_testing(
        lending_cap,
    );

    collateral_manager::destroy_for_testing(
        collateral,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        collateral_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 18,
    location = tobmate_core::collateral_manager,
)]
fun borrow_above_collateral_capacity_aborts() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let collateral_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let supply_coin =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply_coin,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    // 1 SUI at price 2,000 with 70% LTV
    // => max debt = 1,400.
    let _borrowed =
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            collateral_position_id,
            1_401,
            &quote,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    abort 999
}

#[test]
fun interest_accrual_and_reserve_accounting_succeeds() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let collateral_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let supply_coin =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply_coin,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let borrowed =
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            collateral_position_id,
            BORROW_AMOUNT,
            &quote,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(borrowed);

    lending_pool::accrue_borrow_interest(
        &lending_cap,
        &mut pool,
        1,
        2,
    );

    assert!(
        lending_pool::borrow_position_accrued_interest(
            &pool,
            1,
        ) == 100,
        500,
    );

    assert!(
        lending_pool::total_borrow_interest_accrued(
            &pool,
        ) == 100,
        501,
    );

    let interest_payment =
        coin::mint_for_testing<SUI>(
            100,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::repay_interest(
        &access,
        &mut pool,
        1,
        interest_payment,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        lending_pool::borrow_position_accrued_interest(
            &pool,
            1,
        ) == 0,
        502,
    );

    assert!(
        lending_pool::total_borrow_interest_paid(
            &pool,
        ) == 100,
        503,
    );

    assert!(
        lending_pool::protocol_reserves(
            &pool,
        ) == 10,
        504,
    );

    lending_pool::assert_accounting_invariant(
        &pool,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    lending_pool::destroy_admin_cap_for_testing(
        lending_cap,
    );

    collateral_manager::destroy_for_testing(
        collateral,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        collateral_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::lending_pool,
)]
fun insufficient_liquidity_blocks_borrow() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let collateral_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let _borrowed =
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            collateral_position_id,
            100,
            &quote,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::lending_pool,
)]
fun repay_above_principal_aborts() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let collateral_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let supply_coin =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply_coin,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let borrowed =
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            collateral_position_id,
            BORROW_AMOUNT,
            &quote,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(borrowed);

    let repayment =
        coin::mint_for_testing<SUI>(
            BORROW_AMOUNT + 1,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::repay(
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        repayment,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::lending_pool,
)]
fun paused_pool_blocks_supply() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::set_paused(
        &cap,
        &mut pool,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let payment =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        payment,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
fun full_repay_closes_borrow_position() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let collateral_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let supply_coin =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply_coin,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let borrowed =
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            collateral_position_id,
            BORROW_AMOUNT,
            &quote,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(borrowed);

    let repayment =
        coin::mint_for_testing<SUI>(
            BORROW_AMOUNT,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    lending_pool::repay(
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        repayment,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        lending_pool::borrow_position_principal_debt(
            &pool,
            1,
        ) == 0,
        600,
    );

    assert!(
        !lending_pool::borrow_position_is_active(
            &pool,
            1,
        ),
        601,
    );

    assert!(
        collateral_manager::position_debt_value(
            &collateral,
            collateral_position_id,
        ) == 0,
        602,
    );

    lending_pool::assert_accounting_invariant(
        &pool,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    lending_pool::destroy_admin_cap_for_testing(
        lending_cap,
    );

    collateral_manager::destroy_for_testing(
        collateral,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        collateral_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
