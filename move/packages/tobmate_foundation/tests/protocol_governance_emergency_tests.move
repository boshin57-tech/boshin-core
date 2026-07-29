#[test_only]
module tobmate_foundation::protocol_governance_emergency_tests;

use sui::object;
use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::protocol_governance::{
    Self as governance,
};

const ADMIN: address = @0xAD;


/* ============================================================
   Test 01 — Emergency Lifecycle
   ============================================================ */

#[test]
fun test_01_emergency_activate_clear_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        !governance::is_emergency_mode(
            &registry,
        ),
        100,
    );

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::is_emergency_mode(
            &registry,
        ),
        101,
    );

    assert!(
        governance::emergency_activation_count(
            &registry,
        ) == 1,
        102,
    );

    governance::clear_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        !governance::is_emergency_mode(
            &registry,
        ),
        103,
    );

    assert!(
        governance::emergency_clear_count(
            &registry,
        ) == 1,
        104,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Veto Requires Emergency Mode
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 29,
    location = tobmate_foundation::protocol_governance,
)]
fun test_02_veto_requires_emergency_mode() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_test",
            target_id,
            b"emergency-veto-02",
            test_scenario::ctx(&mut scenario),
        );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 03 — Queued Proposal Can Be Vetoed
   ============================================================ */

#[test]
fun test_03_queued_proposal_can_be_vetoed() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_test",
            target_id,
            b"queued-veto-03",
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

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_cancelled(),
        300,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    object::delete(target_uid);

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Issued Authorization Invalid After Veto
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_foundation::protocol_governance,
)]
fun test_04_issued_authorization_invalid_after_veto() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_test",
            target_id,
            b"issued-auth-veto-04",
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

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Even though an ExecutionAuthorization already exists,
     * emergency mode must block execution.
     */
    governance::assert_proposal_execution_allowed(
        &registry,
        proposal_id,
    );

    abort 999
}


/* ============================================================
   Test 05 — Veto Remains Effective After Emergency Clear
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 32,
    location = tobmate_foundation::protocol_governance,
)]
fun test_05_veto_remains_effective_after_emergency_clear() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_test",
            target_id,
            b"persistent-veto-05",
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

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::clear_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::assert_proposal_execution_allowed(
        &registry,
        proposal_id,
    );

    abort 999
}


/* ============================================================
   Test 06 — Executed Proposal Cannot Be Vetoed
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 31,
    location = tobmate_foundation::protocol_governance,
)]
fun test_06_executed_proposal_cannot_be_vetoed() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let payload =
        b"executed-veto-06";

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_test",
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

    governance::mark_executed(
        &mut registry,
        &mut authorization,
        proposal_id,
        1,
        target_id,
        &payload,
        test_scenario::ctx(&mut scenario),
    );

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Emergency Mode Blocks Policy Execution
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_foundation::protocol_governance,
)]
fun test_07_emergency_mode_blocks_policy_execution() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_execution",
            target_id,
            b"emergency-block-07",
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

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::assert_proposal_execution_allowed(
        &registry,
        proposal_id,
    );

    abort 999
}


/* ============================================================
   Test 08 — Emergency Clear Restores Non-Vetoed Execution
   ============================================================ */

#[test]
fun test_08_emergency_clear_restores_non_vetoed_execution() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let payload =
        b"emergency-clear-08";

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_execution",
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

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::clear_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::assert_proposal_execution_allowed(
        &registry,
        proposal_id,
    );

    test_scenario::next_epoch(&mut scenario, ADMIN);
    test_scenario::next_epoch(&mut scenario, ADMIN);

    let mut authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            &scenario,
        );

    governance::mark_executed(
        &mut registry,
        &mut authorization,
        proposal_id,
        1,
        target_id,
        &payload,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_executed(),
        800,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    object::delete(target_uid);

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Stage 10 Part 5-E
   Emergency Governance Replay Protection
   ============================================================ */


/* Test 09 — Duplicate Emergency Activation Rejected */

#[test]
#[expected_failure(
    abort_code = 27,
    location = tobmate_foundation::protocol_governance,
)]
fun test_09_duplicate_emergency_activation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Duplicate Emergency Clear Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 27,
    location = tobmate_foundation::protocol_governance,
)]
fun test_10_duplicate_emergency_clear_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::clear_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::clear_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Emergency Cap From Another Registry Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 30,
    location = tobmate_foundation::protocol_governance,
)]
fun test_11_wrong_emergency_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry_a =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let emergency_cap_b =
        governance::emergency_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    governance::activate_emergency(
        &mut registry_a,
        &emergency_cap_b,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Already Vetoed Proposal Cannot Be Vetoed Again
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 31,
    location = tobmate_foundation::protocol_governance,
)]
fun test_12_duplicate_veto_rejected() {
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

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
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

    let proposal_id =
        governance::submit_proposal(
            &access,
            &mut registry,
            1,
            b"emergency_test",
            target_id,
            b"duplicate-veto-12",
            test_scenario::ctx(&mut scenario),
        );

    governance::activate_emergency(
        &mut registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    governance::emergency_veto_proposal(
        &mut registry,
        &emergency_cap,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
