#[test_only]
module tobmate_core::protocol_governance_security_tests;

use sui::object;
use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::protocol_governance::{
    Self as governance,
};

use tobmate_core::governance_policy_executor::{
    Self as executor,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
};


use tobmate_core::treasury_strategy_recovery_mode::{
    Self as recovery_mode,
};

const ADMIN: address = @0xAD;
const OTHER: address = @0xBEEF;


/* ============================================================
   Stage 10 Part 6-D
   Global AccessControl × Governance Security
   ============================================================ */


/* Test 01 — Global Pause Blocks New Proposal Submission */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::access_control,
)]
fun test_01_global_pause_blocks_proposal_submission() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let access_cap =
        access_control::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let target_uid =
        object::new(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        object::uid_to_inner(
            &target_uid,
        );

    access_control::set_paused(
        &access_cap,
        &mut access,
        true,
        test_scenario::ctx(&mut scenario),
    );

    governance::submit_proposal(
        &access,
        &mut registry,
        1,
        b"global_pause",
        target_id,
        b"global-pause-submit-01",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 02 — Global Pause Blocks Authorized Policy Execution
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::access_control,
)]
fun test_02_global_pause_blocks_authorized_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let access_cap =
        access_control::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
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
            &mut registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
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
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
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
     * Authorization already exists.
     * Global protocol pause must still take precedence.
     */
    access_control::set_paused(
        &access_cap,
        &mut access,
        true,
        test_scenario::ctx(&mut scenario),
    );

    executor::execute_set_global_exposure(
        &access,
        &mut registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        7_000,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 03 — Unpause Restores Authorized Execution
   ============================================================ */

#[test]
fun test_03_unpause_restores_authorized_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let access_cap =
        access_control::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
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
            &mut registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
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
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
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

    access_control::set_paused(
        &access_cap,
        &mut access,
        true,
        test_scenario::ctx(&mut scenario),
    );

    access_control::set_paused(
        &access_cap,
        &mut access,
        false,
        test_scenario::ctx(&mut scenario),
    );

    executor::execute_set_global_exposure(
        &access,
        &mut registry,
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
        301,
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_executed(),
        302,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    access_control::destroy_admin_cap_for_testing(
        access_cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Stage 10 Part 6-E
   Cross-Module Governance End-to-End
   ============================================================ */


/* Test 04 — Governance To Yield Policy E2E */

#[test]
fun test_04_governance_to_yield_policy_e2e() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
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
            6_500,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        800,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
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
        &mut registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        6_500,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        yield_engine::global_exposure_limit_bps(
            &engine,
        ) == 6_500,
        400,
    );

    assert!(
        governance::proposal_executed(
            &registry,
            proposal_id,
        ),
        401,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        402,
    );

    assert!(
        governance::total_proposals_executed(
            &registry,
        ) == 1,
        403,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        registry,
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


/* Test 05 — Governance To Recovery Policy E2E */

#[test]
fun test_05_governance_to_recovery_policy_e2e() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut recovery_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        recovery_mode::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        object::id(
            &recovery_registry,
        );

    let payload =
        executor::payload_recovery_threshold_for_testing(
            7_500,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            executor::action_set_recovery_threshold(),
            b"treasury_strategy_recovery_mode",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        800,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
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
        &mut registry,
        &mut authorization,
        &recovery_cap,
        &mut recovery_registry,
        proposal_id,
        7_500,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        recovery_mode::recovery_threshold_bps(
            &recovery_registry,
        ) == 7_500,
        500,
    );

    assert!(
        governance::proposal_executed(
            &registry,
            proposal_id,
        ),
        501,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    recovery_mode::destroy_admin_cap_for_testing(
        recovery_cap,
    );

    recovery_mode::destroy_for_testing(
        recovery_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Stage 10 Part 6-F
   Final Replay / State Invariant Tests
   ============================================================ */


/* Test 06 — Executed Proposal Cannot Execute Again */

#[test]
#[expected_failure(
    abort_code = 22,
    location = tobmate_core::protocol_governance,
)]
fun test_06_executed_proposal_cannot_execute_again() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
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
            6_000,
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            target_id,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        800,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
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
        &mut registry,
        &mut authorization,
        &yield_cap,
        &mut engine,
        proposal_id,
        6_000,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Proposal is now EXECUTED.
     * Re-queue must fail because only APPROVED proposals can queue.
     */
    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 07 — Consumed Authorization Cannot Mutate Another Target */

#[test]
#[expected_failure(
    abort_code = 26,
    location = tobmate_core::protocol_governance,
)]
fun test_07_consumed_authorization_cannot_mutate_another_target() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let authorization_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let target_a_uid =
        object::new(
            test_scenario::ctx(&mut scenario),
        );

    let target_b_uid =
        object::new(
            test_scenario::ctx(&mut scenario),
        );

    let target_a =
        object::uid_to_inner(
            &target_a_uid,
        );

    let target_b =
        object::uid_to_inner(
            &target_b_uid,
        );

    let payload =
        b"consumed-auth-07";

    /*
     * This test focuses on the authorization object itself.
     * Build a normal governance authorization lifecycle first.
     */

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        authorization_registry;

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"authorization_replay",
            target_a,
            payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::open_voting(
        &mut registry,
        &governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        800,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
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

    governance::consume_execution_authorization(
        &mut authorization,
        proposal_id,
        1,
        target_a,
        &payload,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Once consumed, even a different target attempt must stop
     * at E_AUTHORIZATION_CONSUMED before any other comparison.
     */
    governance::assert_execution_authorized(
        &authorization,
        proposal_id,
        1,
        target_b,
        &payload,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Multi-Module Execution Accounting Invariant
   ============================================================ */

#[test]
fun test_08_multi_module_execution_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &registry,
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

    let mut recovery_registry =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery_cap =
        recovery_mode::admin_cap_for_testing(
            &recovery_registry,
            test_scenario::ctx(&mut scenario),
        );

    let yield_target =
        yield_engine::engine_id(
            &engine,
        );

    let recovery_target =
        object::id(
            &recovery_registry,
        );

    let yield_payload =
        executor::payload_global_exposure_for_testing(
            6_000,
        );

    let recovery_payload =
        executor::payload_recovery_threshold_for_testing(
            7_500,
        );

    let yield_proposal =
        governance::submit_proposal(
            &access,
            &mut registry,
            executor::action_set_global_exposure(),
            b"treasury_yield_engine",
            yield_target,
            yield_payload,
            test_scenario::ctx(&mut scenario),
        );

    let recovery_proposal =
        governance::submit_proposal(
            &access,
            &mut registry,
            executor::action_set_recovery_threshold(),
            b"treasury_strategy_recovery_mode",
            recovery_target,
            recovery_payload,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &governance_cap,
        yield_proposal,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::open_voting(
        &mut registry,
        &governance_cap,
        recovery_proposal,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        yield_proposal,
        governance::vote_for(),
        800,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    governance::cast_vote(
        &mut registry,
        recovery_proposal,
        governance::vote_for(),
        800,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    governance::finalize_vote(
        &mut registry,
        yield_proposal,
        test_scenario::ctx(&mut scenario),
    );

    governance::finalize_vote(
        &mut registry,
        recovery_proposal,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        yield_proposal,
        test_scenario::ctx(&mut scenario),
    );

    governance::queue_proposal(
        &mut registry,
        &governance_cap,
        recovery_proposal,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
        &governance_cap,
        yield_proposal,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    governance::authorize_execution(
        &registry,
        &governance_cap,
        recovery_proposal,
        ADMIN,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization_a =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    let mut authorization_b =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    /*
     * The two authorizations may be returned in either order.
     * Bind them by proposal_id before execution.
     */
    let auth_a_is_yield =
        governance::authorization_proposal_id(
            &authorization_a,
        ) == yield_proposal;

    if (auth_a_is_yield) {
        executor::execute_set_global_exposure(
            &access,
            &mut registry,
            &mut authorization_a,
            &yield_cap,
            &mut engine,
            yield_proposal,
            6_000,
            test_scenario::ctx(&mut scenario),
        );

        executor::execute_set_recovery_threshold(
            &access,
            &mut registry,
            &mut authorization_b,
            &recovery_cap,
            &mut recovery_registry,
            recovery_proposal,
            7_500,
            test_scenario::ctx(&mut scenario),
        );
    } else {
        executor::execute_set_global_exposure(
            &access,
            &mut registry,
            &mut authorization_b,
            &yield_cap,
            &mut engine,
            yield_proposal,
            6_000,
            test_scenario::ctx(&mut scenario),
        );

        executor::execute_set_recovery_threshold(
            &access,
            &mut registry,
            &mut authorization_a,
            &recovery_cap,
            &mut recovery_registry,
            recovery_proposal,
            7_500,
            test_scenario::ctx(&mut scenario),
        );
    };

    assert!(
        governance::proposal_count(
            &registry,
        ) == 2,
        800,
    );

    assert!(
        governance::total_proposals_created(
            &registry,
        ) == 2,
        801,
    );

    assert!(
        governance::total_proposals_executed(
            &registry,
        ) == 2,
        802,
    );

    assert!(
        governance::proposal_executed(
            &registry,
            yield_proposal,
        ),
        803,
    );

    assert!(
        governance::proposal_executed(
            &registry,
            recovery_proposal,
        ),
        804,
    );

    assert!(
        yield_engine::global_exposure_limit_bps(
            &engine,
        ) == 6_000,
        805,
    );

    assert!(
        recovery_mode::recovery_threshold_bps(
            &recovery_registry,
        ) == 7_500,
        806,
    );

    assert!(
        governance::authorization_consumed(
            &authorization_a,
        ),
        807,
    );

    assert!(
        governance::authorization_consumed(
            &authorization_b,
        ),
        808,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization_a,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization_b,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    yield_engine::destroy_admin_cap_for_testing(
        yield_cap,
    );

    yield_engine::destroy_empty_for_testing(
        engine,
    );

    recovery_mode::destroy_admin_cap_for_testing(
        recovery_cap,
    );

    recovery_mode::destroy_for_testing(
        recovery_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
