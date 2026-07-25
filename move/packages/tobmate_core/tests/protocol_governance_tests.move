#[test_only]
module tobmate_core::protocol_governance_tests;

use sui::object;
use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::protocol_governance::{
    Self as governance,
};

const ADMIN: address = @0xAD;
const OTHER: address = @0xCAFE;


/* ============================================================
   Test 01 — Initial Governance State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        governance::version(&registry) == 1,
        100,
    );

    assert!(
        !governance::is_paused(&registry),
        101,
    );

    assert!(
        governance::proposal_count(
            &registry,
        ) == 0,
        102,
    );

    assert!(
        governance::total_proposals_created(
            &registry,
        ) == 0,
        103,
    );

    assert!(
        governance::total_proposals_executed(
            &registry,
        ) == 0,
        104,
    );

    assert!(
        governance::voting_delay_epochs(
            &registry,
        ) == 1,
        105,
    );

    assert!(
        governance::voting_period_epochs(
            &registry,
        ) == 5,
        106,
    );

    assert!(
        governance::execution_delay_epochs(
            &registry,
        ) == 2,
        107,
    );

    assert!(
        governance::quorum_bps(
            &registry,
        ) == 2_000,
        108,
    );

    assert!(
        governance::approval_bps(
            &registry,
        ) == 5_001,
        109,
    );

    governance::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Proposal Submission Succeeds
   ============================================================ */

#[test]
fun test_02_proposal_submission_succeeds() {
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
            b"treasury_yield_engine",
            target_id,
            b"proposal-hash-001",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        proposal_id == 1,
        200,
    );

    assert!(
        governance::proposal_count(
            &registry,
        ) == 1,
        201,
    );

    assert!(
        governance::total_proposals_created(
            &registry,
        ) == 1,
        202,
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_submitted(),
        203,
    );

    assert!(
        governance::proposal_proposer(
            &registry,
            proposal_id,
        ) == ADMIN,
        204,
    );

    assert!(
        governance::proposal_action_type(
            &registry,
            proposal_id,
        ) == 1,
        205,
    );

    assert!(
        !governance::proposal_executed(
            &registry,
            proposal_id,
        ),
        206,
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
   Test 03 — Duplicate Open Proposal Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::protocol_governance,
)]
fun test_03_duplicate_open_proposal_rejected() {
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

    let target_uid =
        object::new(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        object::uid_to_inner(
            &target_uid,
        );

    governance::submit_proposal(
        &access,
        &mut registry,
        1,
        b"treasury_yield_engine",
        target_id,
        b"duplicate-proposal-hash",
        test_scenario::ctx(&mut scenario),
    );

    governance::submit_proposal(
        &access,
        &mut registry,
        1,
        b"treasury_yield_engine",
        target_id,
        b"duplicate-proposal-hash",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04 — Proposal Timeline Is Derived Correctly
   ============================================================ */

#[test]
fun test_04_proposal_timeline_is_derived_correctly() {
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
            2,
            b"protocol_governance",
            target_id,
            b"timeline-proposal-hash",
            test_scenario::ctx(&mut scenario),
        );

    let created =
        governance::proposal_created_epoch(
            &registry,
            proposal_id,
        );

    let voting_start =
        governance::proposal_voting_start_epoch(
            &registry,
            proposal_id,
        );

    let voting_end =
        governance::proposal_voting_end_epoch(
            &registry,
            proposal_id,
        );

    let executable =
        governance::proposal_executable_epoch(
            &registry,
            proposal_id,
        );

    assert!(
        voting_start == created + 1,
        400,
    );

    assert!(
        voting_end == voting_start + 5,
        401,
    );

    assert!(
        executable == voting_end + 2,
        402,
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
   Stage 10 Part 1-C
   Proposal Validation Tests
   ============================================================ */


/* Test 05 — Zero Action Type Rejected */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::protocol_governance,
)]
fun test_05_zero_action_type_rejected() {
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

    let target_uid =
        object::new(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        object::uid_to_inner(
            &target_uid,
        );

    governance::submit_proposal(
        &access,
        &mut registry,
        0,
        b"protocol_governance",
        target_id,
        b"zero-action-test",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 06 — Empty Payload Hash Rejected */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::protocol_governance,
)]
fun test_06_empty_payload_hash_rejected() {
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

    let target_uid =
        object::new(
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        object::uid_to_inner(
            &target_uid,
        );

    governance::submit_proposal(
        &access,
        &mut registry,
        1,
        b"protocol_governance",
        target_id,
        vector[],
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Governance Pause Blocks Proposal Submission
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::protocol_governance,
)]
fun test_07_governance_pause_blocks_proposal_submission() {
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

    let cap =
        governance::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    governance::set_paused(
        &mut registry,
        &cap,
        true,
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

    governance::submit_proposal(
        &access,
        &mut registry,
        1,
        b"protocol_governance",
        target_id,
        b"paused-governance-test",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Version And Pause Lifecycle
   ============================================================ */

#[test]
fun test_08_version_and_pause_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        governance::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    governance::set_paused(
        &mut registry,
        &cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::is_paused(
            &registry,
        ),
        800,
    );

    governance::set_paused(
        &mut registry,
        &cap,
        false,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        !governance::is_paused(
            &registry,
        ),
        801,
    );

    governance::set_version(
        &mut registry,
        &cap,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::version(
            &registry,
        ) == 2,
        802,
    );

    governance::destroy_admin_cap_for_testing(
        cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}
