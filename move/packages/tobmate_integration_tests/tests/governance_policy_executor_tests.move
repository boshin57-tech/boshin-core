#[test_only]
module tobmate_integration_tests::governance_policy_executor_tests;

use sui::object;
use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::protocol_governance::{
    Self as governance,
};

use tobmate_finance::governance_policy_executor::{
    Self as executor,
};

use tobmate_finance::treasury_yield_engine::{
    Self as yield_engine,
};

const ADMIN: address = @0xAD;


/* ============================================================
   Test 01
   Governance Global Exposure Execution Succeeds
   ============================================================ */

#[test]
fun test_01_global_exposure_execution_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let payload =
        executor::payload_global_exposure_for_testing(
            7_000,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_set_global_exposure(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        7_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::global_exposure_limit_bps(
            &engine,
        ) == 7_000,
        100,
    );

    assert!(
        governance::proposal_status(
            &governance_registry,
            proposal_id,
        ) == governance::status_executed(),
        101,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        102,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Payload / Execution Value Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_foundation::protocol_governance,
)]
fun test_02_global_exposure_payload_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let approved_payload =
        executor::payload_global_exposure_for_testing(
            7_000,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            target_id,
            approved_payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    /*
     * Governance approved 7,000 bps.
     * Executor is intentionally asked to execute 8,000 bps.
     * Canonical payload must not match.
     */
    executor::execute_set_global_exposure(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        8_000,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 03
   Strategy Allocation Limit Governance Execution
   ============================================================ */

#[test]
fun test_03_strategy_allocation_execution_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"GOV_ALLOC_03",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let payload =
        executor::payload_strategy_allocation_for_testing(
            strategy_id,
            700_000_000,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_strategy_allocation(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_set_strategy_allocation(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        strategy_id,
        700_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_allocation_limit(
            &engine,
            strategy_id,
        ) == 700_000_000,
        300,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Strategy Concentration Governance Execution
   ============================================================ */

#[test]
fun test_04_strategy_concentration_execution_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"GOV_CONCENTRATION_04",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let payload =
        executor::payload_strategy_concentration_for_testing(
            strategy_id,
            6_000,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_strategy_concentration(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_set_strategy_concentration(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        strategy_id,
        6_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_concentration_limit_bps(
            &engine,
            strategy_id,
        ) == 6_000,
        400,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05
   Strategy Active Governance Execution
   ============================================================ */

#[test]
fun test_05_strategy_active_execution_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"GOV_ACTIVE_05",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let payload =
        executor::payload_strategy_active_for_testing(
            strategy_id,
            true,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_strategy_active(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_set_strategy_active(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        strategy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_is_active(
            &engine,
            strategy_id,
        ),
        500,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06
   Strategy Retirement Governance Execution
   ============================================================ */

#[test]
fun test_06_strategy_retirement_execution_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let strategy_id =
        yield_engine::register_strategy(
            &yield_cap,
            &mut engine,
            b"GOV_RETIRE_06",
            1_000_000_000,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let payload =
        executor::payload_retire_strategy_for_testing(
            strategy_id,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_retire_strategy(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_retire_strategy(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        strategy_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::strategy_is_retired(
            &engine,
            strategy_id,
        ),
        600,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Recovery Threshold Governance Execution
   ============================================================ */

#[test]
fun test_07_recovery_threshold_execution_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut recovery_registry =
        tobmate_finance::treasury_strategy_recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        tobmate_finance::treasury_strategy_recovery_mode::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        object::id(
            &recovery_registry,
        );

    let payload =
        executor::payload_recovery_threshold_for_testing(
            7_000,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_recovery_threshold(),
            b"treasury_strategy_recovery_mode",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_set_recovery_threshold(
        &access,
        &mut governance_registry,
        &mut authorization,
        &recovery_cap,
        &mut recovery_registry,
        proposal_id,
        7_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        tobmate_finance::treasury_strategy_recovery_mode::recovery_threshold_bps(
            &recovery_registry,
        ) == 7_000,
        700,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    tobmate_finance::treasury_strategy_recovery_mode::destroy_admin_cap_for_testing(
        recovery_cap,
    );

    tobmate_finance::treasury_strategy_recovery_mode::destroy_for_testing(
        recovery_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08
   Wrong Action Binding Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_foundation::protocol_governance,
)]
fun test_08_wrong_action_binding_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_cap =
        yield_engine::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut engine =
        yield_engine::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        yield_engine::engine_id(
            &engine,
        );

    let payload =
        executor::payload_global_exposure_for_testing(
            7_000,
        );

    /*
     * Proposal is deliberately authorized for Action 2,
     * while executor later attempts Action 1.
     */
    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut governance_registry,
            executor::action_set_strategy_allocation(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut governance_registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut governance_registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &governance_registry,
        &governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    executor::execute_set_global_exposure(
        &access,
        &mut governance_registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        7_000,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
