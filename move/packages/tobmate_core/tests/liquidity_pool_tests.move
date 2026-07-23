#[test_only]
module tobmate_core::liquidity_pool_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::liquidity_pool::{
    Self as liquidity_pool,
};

const ADMIN: address = @0xAD;
const LP_OWNER: address = @0x1A;

const INITIAL_X: u64 = 1_000_000_000;
const INITIAL_Y: u64 = 4_000_000_000;
const INITIAL_LIQUIDITY: u64 = 2_000_000_000;

const TRADING_FEE_BPS: u64 = 30;
const PROTOCOL_FEE_SHARE_BPS: u64 = 2_000;

#[test]
fun liquidity_pool_initial_state_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &admin_cap,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        liquidity_pool::version(&pool) == 1,
        100,
    );

    assert!(
        !liquidity_pool::is_paused(&pool),
        101,
    );

    assert!(
        liquidity_pool::reserve_x(&pool) == 0,
        102,
    );

    assert!(
        liquidity_pool::reserve_y(&pool) == 0,
        103,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        104,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool) == 0,
        105,
    );

    assert!(
        liquidity_pool::total_liquidity(&pool) == 0,
        106,
    );

    assert!(
        liquidity_pool::position_count(&pool) == 0,
        107,
    );

    assert!(
        liquidity_pool::trading_fee_bps(&pool)
            == TRADING_FEE_BPS,
        108,
    );

    assert!(
        liquidity_pool::protocol_fee_share_bps(&pool)
            == PROTOCOL_FEE_SHARE_BPS,
        109,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun initialize_and_remove_all_liquidity_succeeds() {
    let mut scenario =
        test_scenario::begin(LP_OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &admin_cap,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let coin_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let coin_y =
        coin::mint_for_testing<SUI>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            coin_x,
            coin_y,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        liquidity_pool::reserve_x(&pool)
            == INITIAL_X,
        200,
    );

    assert!(
        liquidity_pool::reserve_y(&pool)
            == INITIAL_Y,
        201,
    );

    assert!(
        liquidity_pool::total_liquidity(&pool)
            == INITIAL_LIQUIDITY,
        202,
    );

    assert!(
        liquidity_pool::position_count(&pool) == 1,
        203,
    );

    assert!(
        liquidity_pool::position_liquidity(&position)
            == INITIAL_LIQUIDITY,
        204,
    );

    assert!(
        liquidity_pool::position_owner(&position)
            == LP_OWNER,
        205,
    );

    assert!(
        liquidity_pool::position_is_active(&position),
        206,
    );

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        INITIAL_LIQUIDITY,
        INITIAL_X,
        INITIAL_Y,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::value(&withdrawn_x) == INITIAL_X,
        207,
    );

    assert!(
        coin::value(&withdrawn_y) == INITIAL_Y,
        208,
    );

    assert!(
        liquidity_pool::reserve_x(&pool) == 0,
        209,
    );

    assert!(
        liquidity_pool::reserve_y(&pool) == 0,
        210,
    );

    assert!(
        liquidity_pool::total_liquidity(&pool) == 0,
        211,
    );

    assert!(
        liquidity_pool::position_liquidity(&position)
            == 0,
        212,
    );

    assert!(
        !liquidity_pool::position_is_active(&position),
        213,
    );

    assert!(
        coin::burn_for_testing(withdrawn_x)
            == INITIAL_X,
        214,
    );

    assert!(
        coin::burn_for_testing(withdrawn_y)
            == INITIAL_Y,
        215,
    );

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun proportional_liquidity_addition_succeeds() {
    let mut scenario =
        test_scenario::begin(LP_OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &admin_cap,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_coin_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_coin_y =
        coin::mint_for_testing<SUI>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_coin_x,
            initial_coin_y,
            test_scenario::ctx(&mut scenario),
        );

    let additional_x: u64 =
        500_000_000;

    let additional_y: u64 =
        2_000_000_000;

    let additional_coin_x =
        coin::mint_for_testing<SUI>(
            additional_x,
            test_scenario::ctx(&mut scenario),
        );

    let additional_coin_y =
        coin::mint_for_testing<SUI>(
            additional_y,
            test_scenario::ctx(&mut scenario),
        );

    let (
        remainder_x,
        remainder_y,
        liquidity_minted,
    ) = liquidity_pool::add_liquidity(
        &access,
        &mut pool,
        &mut position,
        additional_coin_x,
        additional_coin_y,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        liquidity_minted == 1_000_000_000,
        300,
    );

    assert!(
        coin::value(&remainder_x) == 0,
        301,
    );

    assert!(
        coin::value(&remainder_y) == 0,
        302,
    );

    assert!(
        liquidity_pool::reserve_x(&pool)
            == 1_500_000_000,
        303,
    );

    assert!(
        liquidity_pool::reserve_y(&pool)
            == 6_000_000_000,
        304,
    );

    assert!(
        liquidity_pool::total_liquidity(&pool)
            == 3_000_000_000,
        305,
    );

    assert!(
        liquidity_pool::position_liquidity(&position)
            == 3_000_000_000,
        306,
    );

    assert!(
        coin::burn_for_testing(remainder_x) == 0,
        307,
    );

    assert!(
        coin::burn_for_testing(remainder_y) == 0,
        308,
    );

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        3_000_000_000,
        1_500_000_000,
        6_000_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::burn_for_testing(withdrawn_x)
            == 1_500_000_000,
        309,
    );

    assert!(
        coin::burn_for_testing(withdrawn_y)
            == 6_000_000_000,
        310,
    );

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun swap_x_for_y_tracks_protocol_fee() {
    let mut scenario =
        test_scenario::begin(LP_OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &admin_cap,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_coin_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_coin_y =
        coin::mint_for_testing<SUI>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_coin_x,
            initial_coin_y,
            test_scenario::ctx(&mut scenario),
        );

    let swap_input_amount: u64 =
        100_000_000;

    let expected_trading_fee: u64 =
        300_000;

    let expected_protocol_fee: u64 =
        60_000;

    let expected_output: u64 =
        362_644_357;

    let swap_input =
        coin::mint_for_testing<SUI>(
            swap_input_amount,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_x_for_y(
            &access,
            &mut pool,
            swap_input,
            expected_output,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&output) == expected_output,
        400,
    );

    assert!(
        expected_trading_fee == 300_000,
        401,
    );

    assert!(
        liquidity_pool::reserve_x(&pool)
            == 1_099_940_000,
        402,
    );

    assert!(
        liquidity_pool::reserve_y(&pool)
            == 3_637_355_643,
        403,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool)
            == expected_protocol_fee,
        404,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool)
            == 0,
        405,
    );

    assert!(
        liquidity_pool::total_volume_x(&pool)
            == swap_input_amount,
        406,
    );

    assert!(
        liquidity_pool::total_volume_y(&pool)
            == 0,
        407,
    );

    assert!(
        liquidity_pool::swap_count(&pool) == 1,
        408,
    );

    let (
        protocol_fees_x,
        protocol_fees_y,
    ) = liquidity_pool::withdraw_protocol_fees(
        &admin_cap,
        &mut pool,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::value(&protocol_fees_x)
            == expected_protocol_fee,
        409,
    );

    assert!(
        coin::value(&protocol_fees_y) == 0,
        410,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        411,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool) == 0,
        412,
    );

    assert!(
        coin::burn_for_testing(output)
            == expected_output,
        413,
    );

    assert!(
        coin::burn_for_testing(protocol_fees_x)
            == expected_protocol_fee,
        414,
    );

    assert!(
        coin::burn_for_testing(protocol_fees_y) == 0,
        415,
    );

    let remaining_reserve_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_reserve_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        INITIAL_LIQUIDITY,
        remaining_reserve_x,
        remaining_reserve_y,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::burn_for_testing(withdrawn_x)
            == remaining_reserve_x,
        416,
    );

    assert!(
        coin::burn_for_testing(withdrawn_y)
            == remaining_reserve_y,
        417,
    );

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun swap_y_for_x_tracks_protocol_fee() {
    let mut scenario =
        test_scenario::begin(LP_OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        liquidity_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &admin_cap,
            &access,
            TRADING_FEE_BPS,
            PROTOCOL_FEE_SHARE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let initial_coin_x =
        coin::mint_for_testing<SUI>(
            INITIAL_X,
            test_scenario::ctx(&mut scenario),
        );

    let initial_coin_y =
        coin::mint_for_testing<SUI>(
            INITIAL_Y,
            test_scenario::ctx(&mut scenario),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_coin_x,
            initial_coin_y,
            test_scenario::ctx(&mut scenario),
        );

    let swap_input_amount: u64 =
        400_000_000;

    let expected_protocol_fee: u64 =
        240_000;

    let expected_output: u64 =
        90_661_089;

    let swap_input =
        coin::mint_for_testing<SUI>(
            swap_input_amount,
            test_scenario::ctx(&mut scenario),
        );

    let output =
        liquidity_pool::swap_exact_y_for_x(
            &access,
            &mut pool,
            swap_input,
            expected_output,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&output) == expected_output,
        500,
    );

    assert!(
        liquidity_pool::reserve_x(&pool)
            == 909_338_911,
        501,
    );

    assert!(
        liquidity_pool::reserve_y(&pool)
            == 4_399_760_000,
        502,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        503,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool)
            == expected_protocol_fee,
        504,
    );

    assert!(
        liquidity_pool::total_volume_x(&pool) == 0,
        505,
    );

    assert!(
        liquidity_pool::total_volume_y(&pool)
            == swap_input_amount,
        506,
    );

    assert!(
        liquidity_pool::swap_count(&pool) == 1,
        507,
    );

    let (
        protocol_fees_x,
        protocol_fees_y,
    ) = liquidity_pool::withdraw_protocol_fees(
        &admin_cap,
        &mut pool,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::value(&protocol_fees_x) == 0,
        508,
    );

    assert!(
        coin::value(&protocol_fees_y)
            == expected_protocol_fee,
        509,
    );

    assert!(
        liquidity_pool::protocol_fees_x(&pool) == 0,
        510,
    );

    assert!(
        liquidity_pool::protocol_fees_y(&pool) == 0,
        511,
    );

    assert!(
        coin::burn_for_testing(output)
            == expected_output,
        512,
    );

    assert!(
        coin::burn_for_testing(protocol_fees_x) == 0,
        513,
    );

    assert!(
        coin::burn_for_testing(protocol_fees_y)
            == expected_protocol_fee,
        514,
    );

    let remaining_reserve_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_reserve_y =
        liquidity_pool::reserve_y(&pool);

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        INITIAL_LIQUIDITY,
        remaining_reserve_x,
        remaining_reserve_y,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::burn_for_testing(withdrawn_x)
            == remaining_reserve_x,
        515,
    );

    assert!(
        coin::burn_for_testing(withdrawn_y)
            == remaining_reserve_y,
        516,
    );

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}
