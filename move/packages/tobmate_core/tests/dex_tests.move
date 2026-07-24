#[test_only]
module tobmate_core::dex_tests;

use std::string;

use sui::clock;
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_core::access_control;
use tobmate_core::dex;
use tobmate_core::liquidity_pool;
use tobmate_core::oracle_price_router;

const ADMIN: address = @0xA11CE;

public struct X_TEST has drop {}
public struct Y_TEST has drop {}

fun setup_access(
    scenario: &mut test_scenario::Scenario,
): access_control::AccessControl {
    scenario.next_tx(ADMIN);
    access_control::new_for_testing(
        scenario.ctx(),
    )
}

fun setup_registry(
    access: &access_control::AccessControl,
    scenario: &mut test_scenario::Scenario,
): (
    dex::DexRegistry,
    dex::DexAdminCap,
) {
    dex::create_registry(
        access,
        500,
        60_000,
        scenario.ctx(),
    )
}

fun setup_pool(
    access: &access_control::AccessControl,
    scenario: &mut test_scenario::Scenario,
): (
    liquidity_pool::LiquidityPool<X_TEST, Y_TEST>,
    liquidity_pool::LiquidityPoolAdminCap,
) {
    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let pool =
        liquidity_pool::create_pool<X_TEST, Y_TEST>(
            &pool_admin,
            access,
            30,
            2_000,
            scenario.ctx(),
        );

    (pool, pool_admin)
}

#[test]
fun registry_initial_state_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    assert!(
        dex::version(&registry) == 1,
        0,
    );

    assert!(
        !dex::is_paused(&registry),
        1,
    );

    assert!(
        dex::next_pool_id(&registry) == 1,
        2,
    );

    assert!(
        dex::registered_pool_count(&registry) == 0,
        3,
    );

    assert!(
        dex::active_pool_count(&registry) == 0,
        4,
    );

    assert!(
        dex::total_swap_count(&registry) == 0,
        5,
    );

    assert!(
        dex::total_input_volume(&registry) == 0,
        6,
    );

    assert!(
        dex::total_output_volume(&registry) == 0,
        7,
    );

    assert!(
        dex::total_fee_collected(&registry) == 0,
        8,
    );

    assert!(
        dex::max_oracle_deviation_bps(&registry) == 500,
        9,
    );

    assert!(
        dex::default_deadline_window_ms(&registry)
            == 60_000,
        10,
    );

    assert!(
        dex::registry_id(&registry)
            == dex::admin_registry_id(&admin_cap),
        11,
    );

    dex::assert_accounting_invariant(&registry);

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun pool_registration_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    let (pool, pool_admin) =
        setup_pool(&access, &mut scenario);

    let underlying_pool_id =
        liquidity_pool::pool_id(&pool);

    let dex_pool_id =
        dex::register_pool<X_TEST, Y_TEST>(
            &admin_cap,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"X_TEST"),
            string::utf8(b"Y_TEST"),
            false,
            scenario.ctx(),
        );

    assert!(dex_pool_id == 1, 0);

    assert!(
        dex::registered_pool_count(&registry) == 1,
        1,
    );

    assert!(
        dex::active_pool_count(&registry) == 1,
        2,
    );

    assert!(
        dex::next_pool_id(&registry) == 2,
        3,
    );

    assert!(
        dex::pool_exists(&registry, dex_pool_id),
        4,
    );

    assert!(
        dex::pool_is_active(&registry, dex_pool_id),
        5,
    );

    assert!(
        !dex::pool_oracle_guard_enabled(
            &registry,
            dex_pool_id,
        ),
        6,
    );

    assert!(
        dex::pool_object_id(
            &registry,
            dex_pool_id,
        ) == underlying_pool_id,
        7,
    );

    dex::assert_accounting_invariant(&registry);

    liquidity_pool::destroy_pool_for_testing(pool);
    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun pool_activation_lifecycle_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    let (pool, pool_admin) =
        setup_pool(&access, &mut scenario);

    let pool_id =
        dex::register_pool<X_TEST, Y_TEST>(
            &admin_cap,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"X_TEST"),
            string::utf8(b"Y_TEST"),
            false,
            scenario.ctx(),
        );

    dex::set_pool_active(
        &admin_cap,
        &access,
        &mut registry,
        pool_id,
        false,
    );

    assert!(
        !dex::pool_is_active(&registry, pool_id),
        0,
    );

    assert!(
        dex::active_pool_count(&registry) == 0,
        1,
    );

    dex::set_pool_active(
        &admin_cap,
        &access,
        &mut registry,
        pool_id,
        true,
    );

    assert!(
        dex::pool_is_active(&registry, pool_id),
        2,
    );

    assert!(
        dex::active_pool_count(&registry) == 1,
        3,
    );

    liquidity_pool::destroy_pool_for_testing(pool);
    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun pause_lifecycle_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    dex::set_paused(
        &admin_cap,
        &access,
        &mut registry,
        true,
    );

    assert!(
        dex::is_paused(&registry),
        0,
    );

    dex::set_paused(
        &admin_cap,
        &access,
        &mut registry,
        false,
    );

    assert!(
        !dex::is_paused(&registry),
        1,
    );

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun version_upgrade_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    dex::set_version(
        &admin_cap,
        &access,
        &mut registry,
        2,
    );

    assert!(
        dex::version(&registry) == 2,
        0,
    );

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun oracle_policy_update_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    dex::set_max_oracle_deviation_bps(
        &admin_cap,
        &access,
        &mut registry,
        750,
    );

    assert!(
        dex::max_oracle_deviation_bps(&registry)
            == 750,
        0,
    );

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun deadline_policy_update_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    dex::set_default_deadline_window_ms(
        &admin_cap,
        &access,
        &mut registry,
        120_000,
    );

    assert!(
        dex::default_deadline_window_ms(&registry)
            == 120_000,
        0,
    );

    dex::destroy_admin_cap_for_testing(admin_cap);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test, expected_failure(abort_code = dex::E_POOL_ALREADY_REGISTERED)]
fun duplicate_pool_registration_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    let (pool, _pool_admin) =
        setup_pool(&access, &mut scenario);

    dex::register_pool<X_TEST, Y_TEST>(
        &admin_cap,
        &access,
        &mut registry,
        &pool,
        string::utf8(b"X_TEST"),
        string::utf8(b"Y_TEST"),
        false,
        scenario.ctx(),
    );

    dex::register_pool<X_TEST, Y_TEST>(
        &admin_cap,
        &access,
        &mut registry,
        &pool,
        string::utf8(b"X_TEST"),
        string::utf8(b"Y_TEST"),
        false,
        scenario.ctx(),
    );

    abort 999
}

#[test, expected_failure(abort_code = dex::E_DEX_STATE_UNCHANGED)]
fun duplicate_pause_state_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    dex::set_paused(
        &admin_cap,
        &access,
        &mut registry,
        false,
    );

    abort 999
}

#[test, expected_failure(abort_code = dex::E_VERSION_NOT_INCREASING)]
fun non_increasing_version_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, admin_cap) =
        setup_registry(&access, &mut scenario);

    dex::set_version(
        &admin_cap,
        &access,
        &mut registry,
        1,
    );

    abort 999
}


/* ============================================================
   Stage 5B — Swap Routing Tests
   ============================================================ */

#[test]
fun x_to_y_routed_swap_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, X_TEST>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            scenario.ctx(),
        );

    let initial_y =
        coin::mint_for_testing<X_TEST>(
            4_000_000_000,
            scenario.ctx(),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI"),
            string::utf8(b"X_TEST"),
            false,
            scenario.ctx(),
        );

    let clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    let input =
        coin::mint_for_testing<SUI>(
            100_000_000,
            scenario.ctx(),
        );

    let (output, receipt) =
        dex::swap_exact_x_for_y(
            &access,
            &mut registry,
            dex_pool_id,
            &mut pool,
            input,
            362_644_357,
            60_000,
            &clock,
            scenario.ctx(),
        );

    assert!(
        coin::value(&output) == 362_644_357,
        600,
    );

    assert!(
        dex::total_swap_count(&registry) == 1,
        601,
    );

    assert!(
        dex::total_input_volume(&registry)
            == 100_000_000,
        602,
    );

    assert!(
        dex::total_output_volume(&registry)
            == 362_644_357,
        603,
    );

    assert!(
        dex::total_fee_collected(&registry)
            == 300_000,
        604,
    );

    assert!(
        dex::receipt_amount_in(&receipt)
            == 100_000_000,
        605,
    );

    assert!(
        dex::receipt_amount_out(&receipt)
            == 362_644_357,
        606,
    );

    assert!(
        dex::receipt_trading_fee(&receipt)
            == 300_000,
        607,
    );

    assert!(
        dex::receipt_protocol_fee(&receipt)
            == 60_000,
        608,
    );

    assert!(
        dex::receipt_x_to_y(&receipt),
        609,
    );

    coin::burn_for_testing(output);

    let remaining_liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        remaining_liquidity,
        0,
        0,
        scenario.ctx(),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    let (
        protocol_fees_x,
        protocol_fees_y,
    ) = liquidity_pool::withdraw_protocol_fees(
        &pool_admin,
        &mut pool,
        scenario.ctx(),
    );

    coin::burn_for_testing(protocol_fees_x);
    coin::burn_for_testing(protocol_fees_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    clock::destroy_for_testing(clock);

    dex::destroy_admin_cap_for_testing(dex_admin);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test]
fun y_to_x_routed_swap_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<X_TEST, SUI>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let initial_x =
        coin::mint_for_testing<X_TEST>(
            1_000_000_000,
            scenario.ctx(),
        );

    let initial_y =
        coin::mint_for_testing<SUI>(
            4_000_000_000,
            scenario.ctx(),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"X_TEST"),
            string::utf8(b"SUI"),
            false,
            scenario.ctx(),
        );

    let clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    let input =
        coin::mint_for_testing<SUI>(
            400_000_000,
            scenario.ctx(),
        );

    let (output, receipt) =
        dex::swap_exact_y_for_x(
            &access,
            &mut registry,
            dex_pool_id,
            &mut pool,
            input,
            90_661_089,
            60_000,
            &clock,
            scenario.ctx(),
        );

    assert!(
        coin::value(&output) == 90_661_089,
        620,
    );

    assert!(
        dex::total_swap_count(&registry) == 1,
        621,
    );

    assert!(
        dex::total_input_volume(&registry)
            == 400_000_000,
        622,
    );

    assert!(
        dex::total_output_volume(&registry)
            == 90_661_089,
        623,
    );

    assert!(
        dex::total_fee_collected(&registry)
            == 1_200_000,
        624,
    );

    assert!(
        !dex::receipt_x_to_y(&receipt),
        625,
    );

    assert!(
        dex::receipt_protocol_fee(&receipt)
            == 240_000,
        626,
    );

    coin::burn_for_testing(output);

    let remaining_liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let (
        withdrawn_x,
        withdrawn_y,
    ) = liquidity_pool::remove_liquidity(
        &access,
        &mut pool,
        &mut position,
        remaining_liquidity,
        0,
        0,
        scenario.ctx(),
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    let (
        protocol_fees_x,
        protocol_fees_y,
    ) = liquidity_pool::withdraw_protocol_fees(
        &pool_admin,
        &mut pool,
        scenario.ctx(),
    );

    coin::burn_for_testing(protocol_fees_x);
    coin::burn_for_testing(protocol_fees_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    clock::destroy_for_testing(clock);

    dex::destroy_admin_cap_for_testing(dex_admin);
    dex::destroy_registry_for_testing(registry);
    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test, expected_failure(abort_code = 12)]
fun inactive_pool_blocks_routed_swap() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, X_TEST>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI"),
            string::utf8(b"X_TEST"),
            false,
            scenario.ctx(),
        );

    dex::set_pool_active(
        &dex_admin,
        &access,
        &mut registry,
        dex_pool_id,
        false,
    );

    let clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    let input =
        coin::mint_for_testing<SUI>(
            1,
            scenario.ctx(),
        );

    let (output, _receipt) =
        dex::swap_exact_x_for_y(
        &access,
        &mut registry,
        dex_pool_id,
        &mut pool,
        input,
        0,
        60_000,
        &clock,
        scenario.ctx(),
        );

    coin::burn_for_testing(output);

    abort 999
}

#[test, expected_failure(abort_code = 14)]
fun expired_deadline_blocks_routed_swap() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, X_TEST>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI"),
            string::utf8(b"X_TEST"),
            false,
            scenario.ctx(),
        );

    let mut clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    clock::increment_for_testing(
        &mut clock,
        1_001,
    );

    let input =
        coin::mint_for_testing<SUI>(
            1,
            scenario.ctx(),
        );

    let (output, _receipt) =
        dex::swap_exact_x_for_y(
        &access,
        &mut registry,
        dex_pool_id,
        &mut pool,
        input,
        0,
        1_000,
        &clock,
        scenario.ctx(),
        );

    coin::burn_for_testing(output);

    abort 999
}

/* ============================================================
   Stage 5D Part 4B — Oracle Guard Tests
   ============================================================ */

#[test]
fun oracle_guarded_x_to_y_swap_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            scenario.ctx(),
        );

    let initial_y =
        coin::mint_for_testing<SUI>(
            4_000_000_000,
            scenario.ctx(),
        );

    let mut position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool<SUI, SUI>(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI_X"),
            string::utf8(b"SUI_Y"),
            true,
            scenario.ctx(),
        );

    let mut test_clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    clock::increment_for_testing(
        &mut test_clock,
        10_000,
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            dex::registry_id(&registry),
            1,
            1,
            4_000_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let input =
        coin::mint_for_testing<SUI>(
            100_000_000,
            scenario.ctx(),
        );

    let (output, receipt) =
        dex::swap_exact_x_for_y_with_oracle(
            &access,
            &mut registry,
            dex_pool_id,
            &mut pool,
            input,
            0,
            60_000,
            &quote,
            1_000_000,
            &test_clock,
            scenario.ctx(),
        );

    assert!(
        coin::value(&output) > 0,
        500,
    );

    assert!(
        dex::receipt_dex_pool_id(&receipt)
            == dex_pool_id,
        501,
    );

    assert!(
        dex::receipt_x_to_y(&receipt),
        502,
    );

    assert!(
        dex::total_swap_count(&registry) == 1,
        503,
    );

    coin::burn_for_testing(output);

    let (
        protocol_fees_x,
        protocol_fees_y,
    ) =
        liquidity_pool::withdraw_protocol_fees(
            &pool_admin,
            &mut pool,
            scenario.ctx(),
        );

    coin::burn_for_testing(protocol_fees_x);
    coin::burn_for_testing(protocol_fees_y);

    let remaining_x =
        liquidity_pool::reserve_x(&pool);

    let remaining_y =
        liquidity_pool::reserve_y(&pool);

    let position_liquidity =
        liquidity_pool::position_liquidity(
            &position,
        );

    let (
        withdrawn_x,
        withdrawn_y,
    ) =
        liquidity_pool::remove_liquidity(
            &access,
            &mut pool,
            &mut position,
            position_liquidity,
            0,
            0,
            scenario.ctx(),
        );

    assert!(
        coin::value(&withdrawn_x)
            == remaining_x,
        504,
    );

    assert!(
        coin::value(&withdrawn_y)
            == remaining_y,
        505,
    );

    coin::burn_for_testing(withdrawn_x);
    coin::burn_for_testing(withdrawn_y);

    liquidity_pool::destroy_position_for_testing(
        position,
    );

    clock::destroy_for_testing(test_clock);

    liquidity_pool::destroy_pool_for_testing(pool);

    liquidity_pool::destroy_admin_cap_for_testing(
        pool_admin,
    );

    dex::destroy_admin_cap_for_testing(dex_admin);
    dex::destroy_registry_for_testing(registry);

    access_control::destroy_for_testing(access);

    scenario.end();
}

#[test, expected_failure(abort_code = 22)]
fun oracle_price_deviation_blocks_guarded_swap() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            scenario.ctx(),
        );

    let initial_y =
        coin::mint_for_testing<SUI>(
            4_000_000_000,
            scenario.ctx(),
        );

    let _position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool<SUI, SUI>(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI_X"),
            string::utf8(b"SUI_Y"),
            true,
            scenario.ctx(),
        );

    let mut test_clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    clock::increment_for_testing(
        &mut test_clock,
        10_000,
    );

    // Pool price is 4.0 while Oracle price is 2.0.
    // The resulting 10,000 bps deviation exceeds the
    // registry policy of 500 bps.
    let quote =
        oracle_price_router::new_quote_for_testing(
            dex::registry_id(&registry),
            1,
            1,
            2_000_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let input =
        coin::mint_for_testing<SUI>(
            100_000_000,
            scenario.ctx(),
        );

    let (_output, _receipt) =
        dex::swap_exact_x_for_y_with_oracle(
            &access,
            &mut registry,
            dex_pool_id,
            &mut pool,
            input,
            0,
            60_000,
            &quote,
            1_000_000,
            &test_clock,
            scenario.ctx(),
        );

    abort 999
}

#[test, expected_failure(abort_code = 19)]
fun oracle_circuit_breaker_blocks_guarded_swap() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            scenario.ctx(),
        );

    let initial_y =
        coin::mint_for_testing<SUI>(
            4_000_000_000,
            scenario.ctx(),
        );

    let _position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool<SUI, SUI>(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI_X"),
            string::utf8(b"SUI_Y"),
            true,
            scenario.ctx(),
        );

    dex::set_oracle_circuit_breaker(
        &dex_admin,
        &access,
        &mut registry,
        true,
    );

    let mut test_clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    clock::increment_for_testing(
        &mut test_clock,
        10_000,
    );

    let quote =
        oracle_price_router::new_quote_for_testing(
            dex::registry_id(&registry),
            1,
            1,
            4_000_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    let input =
        coin::mint_for_testing<SUI>(
            100_000_000,
            scenario.ctx(),
        );

    let (_output, _receipt) =
        dex::swap_exact_x_for_y_with_oracle(
            &access,
            &mut registry,
            dex_pool_id,
            &mut pool,
            input,
            0,
            60_000,
            &quote,
            1_000_000,
            &test_clock,
            scenario.ctx(),
        );

    abort 999
}

#[test, expected_failure(abort_code = 24)]
fun zero_price_scale_blocks_oracle_guarded_swap() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        setup_access(&mut scenario);

    let (mut registry, dex_admin) =
        setup_registry(&access, &mut scenario);

    let pool_admin =
        liquidity_pool::new_admin_cap_for_testing(
            scenario.ctx(),
        );

    let mut pool =
        liquidity_pool::create_pool<SUI, SUI>(
            &pool_admin,
            &access,
            30,
            2_000,
            scenario.ctx(),
        );

    let initial_x =
        coin::mint_for_testing<SUI>(
            1_000_000_000,
            scenario.ctx(),
        );

    let initial_y =
        coin::mint_for_testing<SUI>(
            4_000_000_000,
            scenario.ctx(),
        );

    let _position =
        liquidity_pool::initialize_liquidity(
            &access,
            &mut pool,
            initial_x,
            initial_y,
            scenario.ctx(),
        );

    let dex_pool_id =
        dex::register_pool<SUI, SUI>(
            &dex_admin,
            &access,
            &mut registry,
            &pool,
            string::utf8(b"SUI_X"),
            string::utf8(b"SUI_Y"),
            true,
            scenario.ctx(),
        );

    let test_clock =
        clock::create_for_testing(
            scenario.ctx(),
        );

    let quote =
        oracle_price_router::new_quote_for_testing(
            dex::registry_id(&registry),
            1,
            1,
            4_000_000,
            40,
            0,
            0,
            60_000,
        );

    let input =
        coin::mint_for_testing<SUI>(
            100_000_000,
            scenario.ctx(),
        );

    let (_output, _receipt) =
        dex::swap_exact_x_for_y_with_oracle(
            &access,
            &mut registry,
            dex_pool_id,
            &mut pool,
            input,
            0,
            60_000,
            &quote,
            0,
            &test_clock,
            scenario.ctx(),
        );

    abort 999
}
