#[test_only]
module tobmate_core::dex_fee_settlement_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_core::access_control;
use tobmate_core::dex_fee_settlement;
use tobmate_core::fee_vault;
use tobmate_core::insurance_fund;
use tobmate_core::liquidity_pool;
use tobmate_core::lp_reward_distributor;
use tobmate_core::revenue_router;
use tobmate_core::treasury;

const ADMIN: address = @0xA11CE;
const TREASURY_RECIPIENT: address = @0xBEEF;

const INITIAL_X: u64 = 1_000_000_000;
const INITIAL_Y: u64 = 4_000_000_000;

const TRADING_FEE_BPS: u64 = 30;
const PROTOCOL_FEE_SHARE_BPS: u64 = 2_000;

const X_TO_Y_INPUT: u64 = 100_000_000;
const X_TO_Y_OUTPUT: u64 = 362_644_357;
const X_TO_Y_PROTOCOL_FEE: u64 = 60_000;

const Y_TO_X_INPUT: u64 = 400_000_000;
const Y_TO_X_OUTPUT: u64 = 90_661_089;
const Y_TO_X_PROTOCOL_FEE: u64 = 240_000;

const ROUTED_TREASURY: u64 = 18_000;
const ROUTED_INSURANCE: u64 = 12_000;
const ROUTED_LP_REWARD: u64 = 15_000;
const ROUTED_RESERVE_OPERATION: u64 = 9_000;
const ROUTED_DAO: u64 = 6_000;

public struct TEST_ASSET has drop {}

#[test]
fun sui_x_protocol_fee_settlement_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, TEST_ASSET>(
            &pool_admin,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_y =
        coin::mint_for_testing<TEST_ASSET>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            test_scenario::ctx(&mut scenario),
        );

    let swap_input =
        coin::mint_for_testing<SUI>(
            X_TO_Y_INPUT,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_x_for_y(
            &access,
            &mut pool,
            swap_input,
            X_TO_Y_OUTPUT,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&output) == X_TO_Y_OUTPUT,
        100,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool)
            == X_TO_Y_PROTOCOL_FEE,
        101,
    );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        returned_non_sui_fee,
        receipt,
    ) =
        dex_fee_settlement::settle_sui_x_protocol_fees(
            &access,
            &pool_admin,
            &mut pool,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&returned_non_sui_fee) == 0,
        102,
    );

    assert!(
        dex_fee_settlement::receipt_sui_is_x(
            &receipt,
        ),
        103,
    );

    assert!(
        dex_fee_settlement::receipt_sui_amount(
            &receipt,
        ) == X_TO_Y_PROTOCOL_FEE,
        104,
    );

    assert!(
        dex_fee_settlement::receipt_non_sui_amount(
            &receipt,
        ) == 0,
        105,
    );

    assert!(
        dex_fee_settlement::receipt_pending_before(
            &receipt,
        ) == 0,
        106,
    );

    assert!(
        dex_fee_settlement::receipt_pending_after(
            &receipt,
        ) == X_TO_Y_PROTOCOL_FEE,
        107,
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == X_TO_Y_PROTOCOL_FEE,
        108,
    );

    assert!(
        fee_vault::liquidity_fees(&vault)
            == X_TO_Y_PROTOCOL_FEE,
        109,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        110,
    );

    assert!(
        coin::burn_for_testing(output)
            == X_TO_Y_OUTPUT,
        111,
    );

    assert!(
        coin::burn_for_testing(returned_non_sui_fee)
            == 0,
        112,
    );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let released =
        fee_vault::release_all(
            &collector_cap,
            &access,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(released)
            == X_TO_Y_PROTOCOL_FEE,
        113,
    );

    let liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let remaining_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        liquidity,
        remaining_x,
        remaining_y,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    fee_vault::destroy_empty_for_testing(vault);

    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun x_sui_protocol_fee_settlement_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<TEST_ASSET, SUI>(
            &pool_admin,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_x =
        coin::mint_for_testing<TEST_ASSET>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_y =
        coin::mint_for_testing<SUI>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            test_scenario::ctx(&mut scenario),
        );

    let swap_input =
        coin::mint_for_testing<SUI>(
            Y_TO_X_INPUT,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_y_for_x(
            &access,
            &mut pool,
            swap_input,
            Y_TO_X_OUTPUT,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&output) == Y_TO_X_OUTPUT,
        200,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool)
            == Y_TO_X_PROTOCOL_FEE,
        201,
    );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        returned_non_sui_fee,
        receipt,
    ) =
        dex_fee_settlement::settle_x_sui_protocol_fees(
            &access,
            &pool_admin,
            &mut pool,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        !dex_fee_settlement::receipt_sui_is_x(
            &receipt,
        ),
        202,
    );

    assert!(
        dex_fee_settlement::receipt_sui_amount(
            &receipt,
        ) == Y_TO_X_PROTOCOL_FEE,
        203,
    );

    assert!(
        dex_fee_settlement::receipt_non_sui_amount(
            &receipt,
        ) == 0,
        204,
    );

    assert!(
        dex_fee_settlement::receipt_pending_before(
            &receipt,
        ) == 0,
        205,
    );

    assert!(
        dex_fee_settlement::receipt_pending_after(
            &receipt,
        ) == Y_TO_X_PROTOCOL_FEE,
        206,
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == Y_TO_X_PROTOCOL_FEE,
        207,
    );

    assert!(
        fee_vault::liquidity_fees(&vault)
            == Y_TO_X_PROTOCOL_FEE,
        208,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool) == 0,
        209,
    );

    assert!(
        coin::value(&returned_non_sui_fee) == 0,
        210,
    );

    assert!(
        coin::burn_for_testing(output)
            == Y_TO_X_OUTPUT,
        211,
    );

    assert!(
        coin::burn_for_testing(returned_non_sui_fee)
            == 0,
        212,
    );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let released =
        fee_vault::release_all(
            &collector_cap,
            &access,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(released)
            == Y_TO_X_PROTOCOL_FEE,
        213,
    );

    let liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let remaining_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        liquidity,
        remaining_x,
        remaining_y,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    fee_vault::destroy_empty_for_testing(vault);

    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun settlement_preserves_existing_fee_vault_balance() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, TEST_ASSET>(
            &pool_admin,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_y =
        coin::mint_for_testing<TEST_ASSET>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            test_scenario::ctx(&mut scenario),
        );

    let swap_input =
        coin::mint_for_testing<SUI>(
            X_TO_Y_INPUT,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_x_for_y(
            &access,
            &mut pool,
            swap_input,
            X_TO_Y_OUTPUT,
            test_scenario::ctx(&mut scenario),
        );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let existing_fee: u64 = 10_000;

    let existing_payment =
        coin::mint_for_testing<SUI>(
            existing_fee,
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::collect_fee(
        &access,
        &mut vault,
        fee_vault::fee_marketplace(),
        existing_payment,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == existing_fee,
        300,
    );

    let (
        returned_non_sui_fee,
        receipt,
    ) =
        dex_fee_settlement::settle_sui_x_protocol_fees(
            &access,
            &pool_admin,
            &mut pool,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        dex_fee_settlement::receipt_pending_before(
            &receipt,
        ) == existing_fee,
        301,
    );

    assert!(
        dex_fee_settlement::receipt_pending_after(
            &receipt,
        ) == existing_fee + X_TO_Y_PROTOCOL_FEE,
        302,
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == existing_fee + X_TO_Y_PROTOCOL_FEE,
        303,
    );

    assert!(
        fee_vault::total_collected(&vault)
            == existing_fee + X_TO_Y_PROTOCOL_FEE,
        304,
    );

    assert!(
        fee_vault::marketplace_fees(&vault)
            == existing_fee,
        305,
    );

    assert!(
        fee_vault::liquidity_fees(&vault)
            == X_TO_Y_PROTOCOL_FEE,
        306,
    );

    assert!(
        coin::burn_for_testing(output)
            == X_TO_Y_OUTPUT,
        307,
    );

    assert!(
        coin::burn_for_testing(returned_non_sui_fee)
            == 0,
        308,
    );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let released =
        fee_vault::release_all(
            &collector_cap,
            &access,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(released)
            == existing_fee + X_TO_Y_PROTOCOL_FEE,
        309,
    );

    let liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let remaining_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        liquidity,
        remaining_x,
        remaining_y,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    fee_vault::destroy_empty_for_testing(vault);

    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun non_sui_protocol_fee_is_returned_without_loss() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, TEST_ASSET>(
            &pool_admin,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_y =
        coin::mint_for_testing<TEST_ASSET>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            test_scenario::ctx(&mut scenario),
        );

    let sui_input =
        coin::mint_for_testing<SUI>(
            X_TO_Y_INPUT,
            test_scenario::ctx(&mut scenario),
        );

    let output_y =
        liquidity_pool::swap_exact_x_for_y(
            &access,
            &mut pool,
            sui_input,
            X_TO_Y_OUTPUT,
            test_scenario::ctx(&mut scenario),
        );

    let test_asset_input_amount: u64 =
        100_000_000;

    let test_asset_input =
        coin::mint_for_testing<TEST_ASSET>(
            test_asset_input_amount,
            test_scenario::ctx(&mut scenario),
        );

    let output_x =
        liquidity_pool::swap_exact_y_for_x(
            &access,
            &mut pool,
            test_asset_input,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let expected_non_sui_protocol_fee: u64 =
        60_000;

    assert!(
        liquidity_pool::protocol_fees_x(&pool)
            == X_TO_Y_PROTOCOL_FEE,
        400,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool)
            == expected_non_sui_protocol_fee,
        401,
    );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        returned_non_sui_fee,
        receipt,
    ) =
        dex_fee_settlement::settle_sui_x_protocol_fees(
            &access,
            &pool_admin,
            &mut pool,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&returned_non_sui_fee)
            == expected_non_sui_protocol_fee,
        402,
    );

    assert!(
        dex_fee_settlement::receipt_sui_amount(
            &receipt,
        ) == X_TO_Y_PROTOCOL_FEE,
        403,
    );

    assert!(
        dex_fee_settlement::receipt_non_sui_amount(
            &receipt,
        ) == expected_non_sui_protocol_fee,
        404,
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == X_TO_Y_PROTOCOL_FEE,
        405,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        406,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool) == 0,
        407,
    );

    assert!(
        coin::burn_for_testing(output_y)
            == X_TO_Y_OUTPUT,
        408,
    );

    coin::burn_for_testing(output_x);

    assert!(
        coin::burn_for_testing(
            returned_non_sui_fee,
        ) == expected_non_sui_protocol_fee,
        409,
    );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let released =
        fee_vault::release_all(
            &collector_cap,
            &access,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(released)
            == X_TO_Y_PROTOCOL_FEE,
        410,
    );

    let liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let remaining_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        liquidity,
        remaining_x,
        remaining_y,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    fee_vault::destroy_empty_for_testing(vault);

    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun settle_and_route_sui_x_protocol_fees_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_admin =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, TEST_ASSET>(
            &pool_admin,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_y =
        coin::mint_for_testing<TEST_ASSET>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            test_scenario::ctx(&mut scenario),
        );

    let swap_input =
        coin::mint_for_testing<SUI>(
            X_TO_Y_INPUT,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_x_for_y(
            &access,
            &mut pool,
            swap_input,
            X_TO_Y_OUTPUT,
            test_scenario::ctx(&mut scenario),
        );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut lp_rewards =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut router =
        revenue_router::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        returned_non_sui_fee,
        receipt,
    ) =
        dex_fee_settlement::settle_and_route_sui_x_protocol_fees(
            &access,
            &pool_admin,
            &collector_cap,
            &mut pool,
            &mut vault,
            &mut protocol_treasury,
            &mut insurance,
            &mut lp_rewards,
            &mut router,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        dex_fee_settlement::receipt_sui_amount(
            &receipt,
        ) == X_TO_Y_PROTOCOL_FEE,
        500,
    );

    assert!(
        dex_fee_settlement::receipt_non_sui_amount(
            &receipt,
        ) == 0,
        501,
    );

    assert!(
        fee_vault::pending_balance(&vault) == 0,
        502,
    );

    assert!(
        fee_vault::total_released(&vault)
            == X_TO_Y_PROTOCOL_FEE,
        503,
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == ROUTED_TREASURY,
        504,
    );

    assert!(
        insurance_fund::fund_balance(&insurance)
            == ROUTED_INSURANCE,
        505,
    );

    assert!(
        lp_reward_distributor::reward_balance(
            &lp_rewards,
        ) == ROUTED_LP_REWARD,
        506,
    );

    assert!(
        revenue_router::reserve_operation_balance(
            &router,
        ) == ROUTED_RESERVE_OPERATION,
        507,
    );

    assert!(
        revenue_router::dao_balance(&router)
            == ROUTED_DAO,
        508,
    );

    assert!(
        revenue_router::total_routed(&router)
            == X_TO_Y_PROTOCOL_FEE,
        509,
    );

    assert!(
        ROUTED_TREASURY
            + ROUTED_INSURANCE
            + ROUTED_LP_REWARD
            + ROUTED_RESERVE_OPERATION
            + ROUTED_DAO
            == X_TO_Y_PROTOCOL_FEE,
        510,
    );

    fee_vault::assert_accounting_invariant(&vault);

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    revenue_router::assert_accounting_invariant(
        &router,
    );

    assert!(
        coin::burn_for_testing(output)
            == X_TO_Y_OUTPUT,
        511,
    );

    assert!(
        coin::burn_for_testing(
            returned_non_sui_fee,
        ) == 0,
        512,
    );

    let insurance_coin =
        insurance_fund::drain_for_testing(
            &mut insurance,
            test_scenario::ctx(&mut scenario),
        );

    let lp_reward_coin =
        lp_reward_distributor::drain_for_testing(
            &mut lp_rewards,
            test_scenario::ctx(&mut scenario),
        );

    let (
        reserve_operation_coin,
        dao_coin,
    ) = revenue_router::drain_all_for_testing(
        &mut router,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::burn_for_testing(insurance_coin)
            == ROUTED_INSURANCE,
        513,
    );

    assert!(
        coin::burn_for_testing(lp_reward_coin)
            == ROUTED_LP_REWARD,
        514,
    );

    assert!(
        coin::burn_for_testing(
            reserve_operation_coin,
        ) == ROUTED_RESERVE_OPERATION,
        515,
    );

    assert!(
        coin::burn_for_testing(dao_coin)
            == ROUTED_DAO,
        516,
    );

    treasury::withdraw(
        &treasury_admin,
        &access,
        &mut protocol_treasury,
        ROUTED_TREASURY,
        TREASURY_RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::balance(&protocol_treasury) == 0,
        517,
    );

    let liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let remaining_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        liquidity,
        remaining_x,
        remaining_y,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    insurance_fund::destroy_for_testing(insurance);

    lp_reward_distributor::destroy_for_testing(
        lp_rewards,
    );

    revenue_router::destroy_empty_for_testing(router);

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    fee_vault::destroy_empty_for_testing(vault);

    treasury::destroy_admin_cap_for_testing(
        treasury_admin,
    );

    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::next_tx(
        &mut scenario,
        TREASURY_RECIPIENT,
    );

    let treasury_coin =
        test_scenario::take_from_sender<
            coin::Coin<SUI>
        >(&scenario);

    assert!(
        coin::burn_for_testing(treasury_coin)
            == ROUTED_TREASURY,
        518,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::dex_fee_settlement,
)]
fun settlement_aborts_when_only_non_sui_fee_exists() {

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, TEST_ASSET>(
            &pool_admin,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_y =
        coin::mint_for_testing<TEST_ASSET>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let _position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            test_scenario::ctx(&mut scenario),
        );

    let test_asset_input =
        coin::mint_for_testing<TEST_ASSET>(
            Y_TO_X_INPUT,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_y_for_x(
            &access,
            &mut pool,
            test_asset_input,
            1,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(output);

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        600,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool)
            == Y_TO_X_PROTOCOL_FEE,
        601,
    );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        returned_non_sui_fee,
        _receipt,
    ) =
        dex_fee_settlement::settle_sui_x_protocol_fees(
            &access,
            &pool_admin,
            &mut pool,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(
        returned_non_sui_fee,
    );

    abort 999;
}
