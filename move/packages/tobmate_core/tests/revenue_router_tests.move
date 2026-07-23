#[test_only]
module tobmate_core::revenue_router_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::fee_vault::{
    Self as fee_vault,
};

use tobmate_core::revenue_router::{
    Self as revenue_router,
};

use tobmate_core::treasury::{
    Self as treasury,
};

const ADMIN: address = @0xAD;
const PAYER: address = @0xFEE;
const RECIPIENT: address = @0xBEEF;

/// Chosen deliberately so integer division leaves three MIST.
///
/// Default allocation:
///
/// Treasury:          300,000,000
/// Insurance:         200,000,000
/// LP rewards:        250,000,000
/// Reserve operation: 150,000,000
/// DAO remainder:     100,000,003
const ROUTING_AMOUNT: u64 = 1_000_000_003;

const EXPECTED_TREASURY: u64 = 300_000_000;
const EXPECTED_INSURANCE: u64 = 200_000_000;
const EXPECTED_LP_REWARDS: u64 = 250_000_000;
const EXPECTED_RESERVE_OPERATIONS: u64 = 150_000_000;
const EXPECTED_DAO: u64 = 100_000_003;

/// Confirms that a new RevenueRouter uses the default 10,000-BPS
/// configuration and begins with no routed revenue.
#[test]
fun revenue_router_initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    let router =
        revenue_router::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(revenue_router::version(&router) == 1, 100);
    assert!(!revenue_router::is_paused(&router), 101);

    assert!(
        revenue_router::basis_point_denominator() == 10_000,
        102,
    );

    assert!(
        revenue_router::treasury_bps(&router) == 3_000,
        103,
    );

    assert!(
        revenue_router::insurance_bps(&router) == 2_000,
        104,
    );

    assert!(
        revenue_router::lp_reward_bps(&router) == 2_500,
        105,
    );

    assert!(
        revenue_router::reserve_operation_bps(&router)
            == 1_500,
        106,
    );

    assert!(
        revenue_router::dao_bps(&router) == 1_000,
        107,
    );

    assert!(
        revenue_router::total_routed(&router) == 0,
        108,
    );

    assert!(
        revenue_router::routing_count(&router) == 0,
        109,
    );

    revenue_router::assert_valid_distribution(
        revenue_router::treasury_bps(&router),
        revenue_router::insurance_bps(&router),
        revenue_router::lp_reward_bps(&router),
        revenue_router::reserve_operation_bps(&router),
        revenue_router::dao_bps(&router),
    );

    revenue_router::assert_accounting_invariant(&router);
    revenue_router::destroy_empty_for_testing(router);

    test_scenario::end(scenario);
}

/// Verifies that an administrator can replace the distribution while
/// preserving the exact 10,000-BPS invariant.
#[test]
fun valid_distribution_update_succeeds() {
    let mut scenario = test_scenario::begin(ADMIN);

    let admin_cap =
        revenue_router::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut router =
        revenue_router::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    revenue_router::set_distribution(
        &admin_cap,
        &mut router,
        4_000,
        1_500,
        2_000,
        1_000,
        1_500,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        revenue_router::treasury_bps(&router) == 4_000,
        200,
    );

    assert!(
        revenue_router::insurance_bps(&router) == 1_500,
        201,
    );

    assert!(
        revenue_router::lp_reward_bps(&router) == 2_000,
        202,
    );

    assert!(
        revenue_router::reserve_operation_bps(&router)
            == 1_000,
        203,
    );

    assert!(
        revenue_router::dao_bps(&router) == 1_500,
        204,
    );

    revenue_router::assert_valid_distribution(
        revenue_router::treasury_bps(&router),
        revenue_router::insurance_bps(&router),
        revenue_router::lp_reward_bps(&router),
        revenue_router::reserve_operation_bps(&router),
        revenue_router::dao_bps(&router),
    );

    revenue_router::destroy_empty_for_testing(router);

    revenue_router::destroy_admin_cap_for_testing(
        admin_cap,
    );

    test_scenario::end(scenario);
}

/// Rejects a distribution whose components do not total 10,000 BPS.
#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::revenue_router
)]
fun invalid_distribution_total_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let admin_cap =
        revenue_router::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut router =
        revenue_router::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    revenue_router::set_distribution(
        &admin_cap,
        &mut router,
        3_000,
        2_000,
        2_500,
        1_500,
        999,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// A locally paused RevenueRouter must reject routing before reading
/// or releasing FeeVault funds.
#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::revenue_router
)]
fun paused_revenue_router_blocks_routing() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        revenue_router::new_admin_cap_for_testing(
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

    let mut router =
        revenue_router::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    revenue_router::set_paused(
        &admin_cap,
        &mut router,
        true,
        test_scenario::ctx(&mut scenario),
    );

    revenue_router::route_all_pending_fees(
        &collector_cap,
        &access,
        &mut vault,
        &mut protocol_treasury,
        &mut router,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// Routes all pending FeeVault funds through the default distribution,
/// verifies every destination, and confirms that rounding remainder is
/// assigned to the DAO balance without losing any SUI.
#[test]
fun pending_fees_are_routed_without_value_loss() {
    let mut scenario = test_scenario::begin(PAYER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let treasury_admin_cap =
        treasury::new_admin_cap_for_testing(
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

    let mut router =
        revenue_router::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fee_payment =
        coin::mint_for_testing<SUI>(
            ROUTING_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::collect_fee(
        &access,
        &mut vault,
        fee_vault::fee_marketplace(),
        fee_payment,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == ROUTING_AMOUNT,
        300,
    );

    revenue_router::route_all_pending_fees(
        &collector_cap,
        &access,
        &mut vault,
        &mut protocol_treasury,
        &mut router,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        fee_vault::pending_balance(&vault) == 0,
        301,
    );

    assert!(
        fee_vault::total_released(&vault)
            == ROUTING_AMOUNT,
        302,
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == EXPECTED_TREASURY,
        303,
    );

    assert!(
        treasury::total_deposited(&protocol_treasury)
            == EXPECTED_TREASURY,
        304,
    );

    assert!(
        revenue_router::insurance_balance(&router)
            == EXPECTED_INSURANCE,
        305,
    );

    assert!(
        revenue_router::lp_reward_balance(&router)
            == EXPECTED_LP_REWARDS,
        306,
    );

    assert!(
        revenue_router::reserve_operation_balance(&router)
            == EXPECTED_RESERVE_OPERATIONS,
        307,
    );

    assert!(
        revenue_router::dao_balance(&router)
            == EXPECTED_DAO,
        308,
    );

    assert!(
        revenue_router::total_routed(&router)
            == ROUTING_AMOUNT,
        309,
    );

    assert!(
        revenue_router::total_to_treasury(&router)
            == EXPECTED_TREASURY,
        310,
    );

    assert!(
        revenue_router::total_to_insurance(&router)
            == EXPECTED_INSURANCE,
        311,
    );

    assert!(
        revenue_router::total_to_lp_rewards(&router)
            == EXPECTED_LP_REWARDS,
        312,
    );

    assert!(
        revenue_router::total_to_reserve_operations(&router)
            == EXPECTED_RESERVE_OPERATIONS,
        313,
    );

    assert!(
        revenue_router::total_to_dao(&router)
            == EXPECTED_DAO,
        314,
    );

    assert!(
        revenue_router::routing_count(&router) == 1,
        315,
    );

    assert!(
        EXPECTED_TREASURY
            + EXPECTED_INSURANCE
            + EXPECTED_LP_REWARDS
            + EXPECTED_RESERVE_OPERATIONS
            + EXPECTED_DAO
            == ROUTING_AMOUNT,
        316,
    );

    fee_vault::assert_accounting_invariant(&vault);
    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );
    revenue_router::assert_accounting_invariant(&router);

    // Remove and burn the four balances retained by RevenueRouter.
    let (
        insurance_coin,
        lp_reward_coin,
        reserve_operation_coin,
        dao_coin,
    ) = revenue_router::drain_all_for_testing(
        &mut router,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        coin::burn_for_testing(insurance_coin)
            == EXPECTED_INSURANCE,
        317,
    );

    assert!(
        coin::burn_for_testing(lp_reward_coin)
            == EXPECTED_LP_REWARDS,
        318,
    );

    assert!(
        coin::burn_for_testing(reserve_operation_coin)
            == EXPECTED_RESERVE_OPERATIONS,
        319,
    );

    assert!(
        coin::burn_for_testing(dao_coin)
            == EXPECTED_DAO,
        320,
    );

    // Empty the Treasury so its test fixture can be destroyed.
    treasury::withdraw(
        &treasury_admin_cap,
        &access,
        &mut protocol_treasury,
        EXPECTED_TREASURY,
        RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::balance(&protocol_treasury) == 0,
        321,
    );

    revenue_router::destroy_empty_for_testing(router);
    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );
    fee_vault::destroy_empty_for_testing(vault);

    treasury::destroy_admin_cap_for_testing(
        treasury_admin_cap,
    );

    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}
