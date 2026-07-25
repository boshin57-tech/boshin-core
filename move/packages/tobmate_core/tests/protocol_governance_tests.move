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


/* ============================================================
   Stage 10 Part 2-E
   Voting Lifecycle Tests
   ============================================================ */


/* Test 09 — Open Voting Succeeds */

#[test]
fun test_09_open_voting_succeeds() {
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
            b"vote-open-09",
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Default voting delay is 1 epoch.
     */
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_voting(),
        900,
    );

    assert!(
        governance::proposal_total_voting_power_snapshot(
            &registry,
            proposal_id,
        ) == 1_000_000,
        901,
    );

    object::delete(target_uid);

    governance::destroy_admin_cap_for_testing(
        cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* Test 10 — Vote Accounting Succeeds */

#[test]
fun test_10_vote_accounting_succeeds() {
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
            b"protocol_governance",
            target_id,
            b"vote-accounting-10",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        400,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_against(),
        300,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        @0xBEEF,
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_abstain(),
        200,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_for_votes(
            &registry,
            proposal_id,
        ) == 400,
        1000,
    );

    assert!(
        governance::proposal_against_votes(
            &registry,
            proposal_id,
        ) == 300,
        1001,
    );

    assert!(
        governance::proposal_abstain_votes(
            &registry,
            proposal_id,
        ) == 200,
        1002,
    );

    assert!(
        governance::proposal_vote_count(
            &registry,
            proposal_id,
        ) == 3,
        1003,
    );

    assert!(
        governance::vote_receipt_count(
            &registry,
        ) == 3,
        1004,
    );

    object::delete(target_uid);

    governance::destroy_admin_cap_for_testing(
        cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 11 — Duplicate Vote Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::protocol_governance,
)]
fun test_11_duplicate_vote_rejected() {
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
            b"protocol_governance",
            target_id,
            b"duplicate-vote-11",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        300,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_against(),
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Invalid Vote Choice Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::protocol_governance,
)]
fun test_12_invalid_vote_choice_rejected() {
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
            b"protocol_governance",
            target_id,
            b"invalid-choice-12",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        99,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Voting Power Above Snapshot Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 19,
    location = tobmate_core::protocol_governance,
)]
fun test_13_voting_power_above_snapshot_rejected() {
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
            b"protocol_governance",
            target_id,
            b"snapshot-overflow-13",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        1_001,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14 — Vote After Voting End Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 18,
    location = tobmate_core::protocol_governance,
)]
fun test_14_vote_after_voting_end_rejected() {
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
            b"protocol_governance",
            target_id,
            b"late-vote-14",
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Move to voting start epoch.
     */
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Default voting period = 5 epochs.
     * Move beyond voting_end_epoch.
     */
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 15 — Approved Vote Finalizes Proposal
   ============================================================ */

#[test]
fun test_15_approved_vote_finalizes_proposal() {
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
            b"protocol_governance",
            target_id,
            b"approved-finalize-15",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
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

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_against(),
        100,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Move beyond voting_end_epoch.
     */
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_approved(),
        1500,
    );

    assert!(
        governance::proposal_finalized(
            &registry,
            proposal_id,
        ),
        1501,
    );

    assert!(
        governance::proposal_participation_bps(
            &registry,
            proposal_id,
        ) == 8_000,
        1502,
    );

    assert!(
        governance::proposal_approval_bps(
            &registry,
            proposal_id,
        ) == 8_750,
        1503,
    );

    object::delete(target_uid);

    governance::destroy_admin_cap_for_testing(
        cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 16 — Failed Approval Finalizes As Rejected
   ============================================================ */

#[test]
fun test_16_failed_approval_finalizes_as_rejected() {
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
            b"protocol_governance",
            target_id,
            b"rejected-finalize-16",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        300,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_against(),
        400,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Move beyond voting_end_epoch.
     */
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_rejected(),
        1600,
    );

    assert!(
        governance::proposal_finalized(
            &registry,
            proposal_id,
        ),
        1601,
    );

    object::delete(target_uid);

    governance::destroy_admin_cap_for_testing(
        cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 17 — Quorum Failure Finalizes As Rejected
   ============================================================ */

#[test]
fun test_17_quorum_failure_finalizes_as_rejected() {
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
            b"protocol_governance",
            target_id,
            b"quorum-failure-17",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Default quorum is 20%.
     * 100 / 1000 = 10% participation.
     */
    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        100,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );
    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::proposal_status(
            &registry,
            proposal_id,
        ) == governance::status_rejected(),
        1700,
    );

    assert!(
        governance::proposal_participation_bps(
            &registry,
            proposal_id,
        ) == 1_000,
        1701,
    );

    object::delete(target_uid);

    governance::destroy_admin_cap_for_testing(
        cap,
    );

    governance::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 18 — Finalize Before Voting End Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 20,
    location = tobmate_core::protocol_governance,
)]
fun test_18_finalize_before_voting_end_rejected() {
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
            b"protocol_governance",
            target_id,
            b"early-finalize-18",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        500,
        test_scenario::ctx(&mut scenario),
    );

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 19 — Duplicate Finalize Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::protocol_governance,
)]
fun test_19_duplicate_finalize_rejected() {
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
            b"protocol_governance",
            target_id,
            b"duplicate-finalize-19",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    governance::cast_vote(
        &mut registry,
        proposal_id,
        governance::vote_for(),
        600,
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

    governance::finalize_vote(
        &mut registry,
        proposal_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 20 — Zero Voting Power Snapshot Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::protocol_governance,
)]
fun test_20_zero_voting_power_snapshot_rejected() {
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
            b"protocol_governance",
            target_id,
            b"zero-snapshot-20",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_epoch(
        &mut scenario,
        ADMIN,
    );

    governance::open_voting(
        &mut registry,
        &cap,
        proposal_id,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
