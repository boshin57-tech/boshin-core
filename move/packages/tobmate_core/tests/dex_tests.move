#[test_only]
module tobmate_core::dex_tests;

use std::string;

use sui::test_scenario;

use tobmate_core::access_control;
use tobmate_core::dex;
use tobmate_core::liquidity_pool;

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
