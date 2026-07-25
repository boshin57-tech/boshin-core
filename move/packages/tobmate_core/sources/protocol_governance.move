module tobmate_core::protocol_governance;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

/* ============================================================
   Stage 10 Part 1
   Protocol Governance Foundation
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;
const BPS_DENOMINATOR: u64 = 10_000;

/* Proposal states */

const STATUS_SUBMITTED: u8 = 1;
const STATUS_VOTING: u8 = 2;
const STATUS_APPROVED: u8 = 3;
const STATUS_REJECTED: u8 = 4;
const STATUS_QUEUED: u8 = 5;
const STATUS_EXECUTED: u8 = 6;
const STATUS_CANCELLED: u8 = 7;

/* Vote choices */

const VOTE_FOR: u8 = 1;
const VOTE_AGAINST: u8 = 2;
const VOTE_ABSTAIN: u8 = 3;

/* Governance errors */

const E_GOVERNANCE_PAUSED: u64 = 1;
const E_ZERO_ACTION_TYPE: u64 = 2;
const E_EMPTY_PAYLOAD_HASH: u64 = 3;
const E_DUPLICATE_OPEN_PROPOSAL: u64 = 4;
const E_PROPOSAL_NOT_FOUND: u64 = 5;
const E_INVALID_VERSION: u64 = 6;
const E_STATE_UNCHANGED: u64 = 7;
const E_INVALID_QUORUM_BPS: u64 = 8;
const E_INVALID_APPROVAL_BPS: u64 = 9;
const E_INVALID_VOTING_PERIOD: u64 = 10;
const E_INVALID_EXECUTION_DELAY: u64 = 11;
const E_INVALID_PROPOSAL_STATUS: u64 = 12;
const E_ZERO_VOTING_POWER: u64 = 13;
const E_VOTING_NOT_STARTED: u64 = 14;
const E_VOTING_ALREADY_STARTED: u64 = 15;
const E_INVALID_VOTE_CHOICE: u64 = 16;
const E_DUPLICATE_VOTE: u64 = 17;
const E_VOTING_ENDED: u64 = 18;
const E_VOTING_POWER_EXCEEDS_SNAPSHOT: u64 = 19;
const E_VOTING_NOT_ENDED: u64 = 20;
const E_PROPOSAL_ALREADY_FINALIZED: u64 = 21;
const E_PROPOSAL_NOT_APPROVED: u64 = 22;
const E_PROPOSAL_ALREADY_QUEUED: u64 = 23;
const E_TIMELOCK_ACTIVE: u64 = 24;
const E_AUTHORIZATION_MISMATCH: u64 = 25;
const E_AUTHORIZATION_CONSUMED: u64 = 26;
const E_EMERGENCY_STATE_UNCHANGED: u64 = 27;
const E_EMERGENCY_MODE_ACTIVE: u64 = 28;
const E_EMERGENCY_MODE_INACTIVE: u64 = 29;
const E_EMERGENCY_CAP_MISMATCH: u64 = 30;
const E_PROPOSAL_NOT_VETOABLE: u64 = 31;
const E_PROPOSAL_CANCELLED: u64 = 32;
const E_AUTHORIZATION_REGISTRY_MISMATCH: u64 = 33;


/* ============================================================
   Governance Registry
   ============================================================ */

public struct GovernanceRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    emergency_mode: bool,
    emergency_activation_count: u64,
    emergency_clear_count: u64,

    next_proposal_id: u64,
    proposals: vector<GovernanceProposal>,
    vote_receipts: vector<VoteReceipt>,

    voting_delay_epochs: u64,
    voting_period_epochs: u64,
    execution_delay_epochs: u64,

    quorum_bps: u64,
    approval_bps: u64,

    total_proposals_created: u64,
    total_proposals_executed: u64,
}


/* ============================================================
   Governance Admin Capability
   ============================================================ */

public struct GovernanceAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


public struct EmergencyGovernanceCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Governance Proposal
   ============================================================ */

public struct GovernanceProposal has store {
    proposal_id: u64,

    proposer: address,

    action_type: u64,
    target_module: vector<u8>,
    target_object_id: ID,
    payload_hash: vector<u8>,

    status: u8,

    for_votes: u64,
    against_votes: u64,
    abstain_votes: u64,

    total_voting_power_snapshot: u64,
    vote_count: u64,
    finalized: bool,

    created_epoch: u64,
    voting_start_epoch: u64,
    voting_end_epoch: u64,
    executable_epoch: u64,

    executed: bool,
}


/* ============================================================
   Vote Receipt
   ============================================================ */

public struct VoteReceipt has store {
    proposal_id: u64,
    voter: address,
    choice: u8,
    voting_power: u64,
    cast_epoch: u64,
}


/* ============================================================
   Execution Authorization
   ============================================================ */

public struct ExecutionAuthorization has key, store {
    id: UID,

    registry_id: ID,
    proposal_id: u64,
    action_type: u64,
    target_object_id: ID,
    payload_hash: vector<u8>,

    executable_epoch: u64,
    consumed: bool,
}


/* ============================================================
   Events
   ============================================================ */

public struct GovernanceRegistryCreated has copy, drop {
    registry_id: ID,
    administrator: address,
}

public struct GovernanceProposalSubmitted has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    proposer: address,
    action_type: u64,
    target_object_id: ID,
    created_epoch: u64,
}

public struct GovernancePauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct GovernanceVersionChanged has copy, drop {
    registry_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}


public struct GovernanceVotingOpened has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    total_voting_power_snapshot: u64,
    voting_start_epoch: u64,
    voting_end_epoch: u64,
    opened_by: address,
}


public struct GovernanceVoteCast has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    voter: address,
    choice: u8,
    voting_power: u64,
    vote_count_after: u64,
}


public struct GovernanceVoteFinalized has copy, drop {
    registry_id: ID,
    proposal_id: u64,

    for_votes: u64,
    against_votes: u64,
    abstain_votes: u64,

    participation_bps: u64,
    approval_bps: u64,

    approved: bool,
    finalized_by: address,
}


public struct GovernanceProposalQueued has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    executable_epoch: u64,
    queued_by: address,
}


public struct GovernanceExecutionAuthorized has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    authorization_id: ID,
    executable_epoch: u64,
    authorized_by: address,
}


public struct GovernanceProposalExecuted has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    authorization_id: ID,
    executed_by: address,
    executed_epoch: u64,
}


public struct GovernanceEmergencyActivated has copy, drop {
    registry_id: ID,
    activated_by: address,
    activation_count: u64,
}

public struct GovernanceEmergencyCleared has copy, drop {
    registry_id: ID,
    cleared_by: address,
    clear_count: u64,
}


public struct GovernanceProposalVetoed has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    previous_status: u8,
    vetoed_by: address,
    vetoed_epoch: u64,
}


/* ============================================================
   Initialization
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
) {
    let administrator =
        tx_context::sender(ctx);

    let registry =
        GovernanceRegistry {
            id: object::new(ctx),

            version: PROTOCOL_VERSION,
            paused: false,

            emergency_mode: false,
            emergency_activation_count: 0,
            emergency_clear_count: 0,

            next_proposal_id: 1,
            proposals: vector[],
            vote_receipts: vector[],

            voting_delay_epochs: 1,
            voting_period_epochs: 5,
            execution_delay_epochs: 2,

            quorum_bps: 2_000,
            approval_bps: 5_001,

            total_proposals_created: 0,
            total_proposals_executed: 0,
        };

    let registry_id =
        object::id(&registry);

    let admin_cap =
        GovernanceAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    let emergency_cap =
        EmergencyGovernanceCap {
            id: object::new(ctx),
            registry_id,
        };

    event::emit(
        GovernanceRegistryCreated {
            registry_id,
            administrator,
        },
    );

    transfer::share_object(registry);

    transfer::public_transfer(
        admin_cap,
        administrator,
    );

    transfer::public_transfer(
        emergency_cap,
        administrator,
    );
}


/* ============================================================
   Proposal Submission
   ============================================================ */

public fun submit_proposal(
    access: &AccessControl,
    registry: &mut GovernanceRegistry,

    action_type: u64,
    target_module: vector<u8>,
    target_object_id: ID,
    payload_hash: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert!(
        action_type > 0,
        E_ZERO_ACTION_TYPE,
    );

    assert!(
        vector::length(&payload_hash) > 0,
        E_EMPTY_PAYLOAD_HASH,
    );

    assert!(
        !contains_open_payload(
            registry,
            action_type,
            target_object_id,
            &payload_hash,
        ),
        E_DUPLICATE_OPEN_PROPOSAL,
    );

    let proposal_id =
        registry.next_proposal_id;

    registry.next_proposal_id =
        proposal_id + 1;

    let created_epoch =
        tx_context::epoch(ctx);

    let voting_start_epoch =
        created_epoch
            + registry.voting_delay_epochs;

    let voting_end_epoch =
        voting_start_epoch
            + registry.voting_period_epochs;

    let executable_epoch =
        voting_end_epoch
            + registry.execution_delay_epochs;

    vector::push_back(
        &mut registry.proposals,
        GovernanceProposal {
            proposal_id,

            proposer:
                tx_context::sender(ctx),

            action_type,
            target_module,
            target_object_id,
            payload_hash,

            status:
                STATUS_SUBMITTED,

            for_votes: 0,
            against_votes: 0,
            abstain_votes: 0,

            total_voting_power_snapshot: 0,
            vote_count: 0,
            finalized: false,

            created_epoch,
            voting_start_epoch,
            voting_end_epoch,
            executable_epoch,

            executed: false,
        },
    );

    registry.total_proposals_created =
        registry.total_proposals_created + 1;

    event::emit(
        GovernanceProposalSubmitted {
            registry_id:
                object::id(registry),

            proposal_id,

            proposer:
                tx_context::sender(ctx),

            action_type,
            target_object_id,
            created_epoch,
        },
    );

    proposal_id
}


/* ============================================================
   Administration
   ============================================================ */

public fun set_paused(
    registry: &mut GovernanceRegistry,
    admin_cap: &GovernanceAdminCap,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        registry.paused != paused,
        E_STATE_UNCHANGED,
    );

    registry.paused =
        paused;

    event::emit(
        GovernancePauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


public fun set_version(
    registry: &mut GovernanceRegistry,
    admin_cap: &GovernanceAdminCap,
    new_version: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_version > registry.version,
        E_INVALID_VERSION,
    );

    let previous_version =
        registry.version;

    registry.version =
        new_version;

    event::emit(
        GovernanceVersionChanged {
            registry_id:
                object::id(registry),

            previous_version,
            new_version,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Internal Guards
   ============================================================ */

fun assert_admin(
    registry: &GovernanceRegistry,
    admin_cap: &GovernanceAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_STATE_UNCHANGED,
    );
}


public fun assert_operational(
    access: &AccessControl,
    registry: &GovernanceRegistry,
) {
    access_control::assert_not_paused(
        access,
    );

    assert!(
        !registry.paused,
        E_GOVERNANCE_PAUSED,
    );
}


/* ============================================================
   Proposal Search
   ============================================================ */

fun contains_open_payload(
    registry: &GovernanceRegistry,
    action_type: u64,
    target_object_id: ID,
    payload_hash: &vector<u8>,
): bool {
    let mut i = 0;

    let length =
        vector::length(
            &registry.proposals,
        );

    while (i < length) {
        let proposal =
            vector::borrow(
                &registry.proposals,
                i,
            );

        if (
            proposal.action_type
                == action_type

            && proposal.target_object_id
                == target_object_id

            && proposal.payload_hash
                == *payload_hash

            && proposal.status
                != STATUS_EXECUTED

            && proposal.status
                != STATUS_CANCELLED

            && proposal.status
                != STATUS_REJECTED
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


fun find_proposal_index(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let mut i = 0;

    let length =
        vector::length(
            &registry.proposals,
        );

    while (i < length) {
        if (
            vector::borrow(
                &registry.proposals,
                i,
            ).proposal_id
                == proposal_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_PROPOSAL_NOT_FOUND
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun registry_id(
    registry: &GovernanceRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &GovernanceRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GovernanceRegistry,
): bool {
    registry.paused
}

public fun proposal_count(
    registry: &GovernanceRegistry,
): u64 {
    vector::length(
        &registry.proposals,
    )
}

public fun total_proposals_created(
    registry: &GovernanceRegistry,
): u64 {
    registry.total_proposals_created
}

public fun total_proposals_executed(
    registry: &GovernanceRegistry,
): u64 {
    registry.total_proposals_executed
}

public fun voting_delay_epochs(
    registry: &GovernanceRegistry,
): u64 {
    registry.voting_delay_epochs
}

public fun voting_period_epochs(
    registry: &GovernanceRegistry,
): u64 {
    registry.voting_period_epochs
}

public fun execution_delay_epochs(
    registry: &GovernanceRegistry,
): u64 {
    registry.execution_delay_epochs
}

public fun quorum_bps(
    registry: &GovernanceRegistry,
): u64 {
    registry.quorum_bps
}

public fun approval_bps(
    registry: &GovernanceRegistry,
): u64 {
    registry.approval_bps
}


/* ============================================================
   Proposal Read API
   ============================================================ */

public fun proposal_status(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u8 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).status
}

public fun proposal_proposer(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): address {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).proposer
}

public fun proposal_action_type(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).action_type
}

public fun proposal_created_epoch(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).created_epoch
}

public fun proposal_voting_start_epoch(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).voting_start_epoch
}

public fun proposal_voting_end_epoch(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).voting_end_epoch
}

public fun proposal_executable_epoch(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).executable_epoch
}

public fun proposal_executed(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): bool {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).executed
}


/* ============================================================
   Status Constants
   ============================================================ */

public fun status_submitted(): u8 {
    STATUS_SUBMITTED
}

public fun status_voting(): u8 {
    STATUS_VOTING
}

public fun status_approved(): u8 {
    STATUS_APPROVED
}

public fun status_rejected(): u8 {
    STATUS_REJECTED
}

public fun status_queued(): u8 {
    STATUS_QUEUED
}

public fun status_executed(): u8 {
    STATUS_EXECUTED
}

public fun status_cancelled(): u8 {
    STATUS_CANCELLED
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): GovernanceRegistry {
    GovernanceRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused: false,

        emergency_mode: false,
        emergency_activation_count: 0,
        emergency_clear_count: 0,

        next_proposal_id: 1,
        proposals: vector[],
        vote_receipts: vector[],

        voting_delay_epochs: 1,
        voting_period_epochs: 5,
        execution_delay_epochs: 2,

        quorum_bps: 2_000,
        approval_bps: 5_001,

        total_proposals_created: 0,
        total_proposals_executed: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &GovernanceRegistry,
    ctx: &mut TxContext,
): GovernanceAdminCap {
    GovernanceAdminCap {
        id: object::new(ctx),
        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GovernanceAdminCap,
) {
    let GovernanceAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: GovernanceRegistry,
) {
    let GovernanceRegistry {
        id,

        version: _,
        paused: _,

        emergency_mode: _,
        emergency_activation_count: _,
        emergency_clear_count: _,

        next_proposal_id: _,
        mut proposals,
        mut vote_receipts,

        voting_delay_epochs: _,
        voting_period_epochs: _,
        execution_delay_epochs: _,

        quorum_bps: _,
        approval_bps: _,

        total_proposals_created: _,
        total_proposals_executed: _,
    } = registry;

    while (!vector::is_empty(
        &proposals,
    )) {
        let GovernanceProposal {
            proposal_id: _,
            proposer: _,
            action_type: _,
            target_module: _,
            target_object_id: _,
            payload_hash: _,
            status: _,

            for_votes: _,
            against_votes: _,
            abstain_votes: _,

            total_voting_power_snapshot: _,
            vote_count: _,
            finalized: _,

            created_epoch: _,
            voting_start_epoch: _,
            voting_end_epoch: _,
            executable_epoch: _,
            executed: _,
        } = vector::pop_back(
            &mut proposals,
        );
    };

    vector::destroy_empty(
        proposals,
    );

    while (!vector::is_empty(
        &vote_receipts,
    )) {
        let VoteReceipt {
            proposal_id: _,
            voter: _,
            choice: _,
            voting_power: _,
            cast_epoch: _,
        } = vector::pop_back(
            &mut vote_receipts,
        );
    };

    vector::destroy_empty(
        vote_receipts,
    );

    object::delete(id);
}


/* ============================================================
   Stage 10 Part 2-B
   Voting Lifecycle
   ============================================================ */

public fun open_voting(
    registry: &mut GovernanceRegistry,
    admin_cap: &GovernanceAdminCap,
    proposal_id: u64,
    total_voting_power_snapshot: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        total_voting_power_snapshot > 0,
        E_ZERO_VOTING_POWER,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    {
        let proposal =
            vector::borrow(
                &registry.proposals,
                index,
            );

        assert!(
            proposal.status == STATUS_SUBMITTED,
            E_INVALID_PROPOSAL_STATUS,
        );

        assert!(
            tx_context::epoch(ctx)
                >= proposal.voting_start_epoch,
            E_VOTING_NOT_STARTED,
        );
    };

    {
        let proposal =
            vector::borrow_mut(
                &mut registry.proposals,
                index,
            );

        proposal.status =
            STATUS_VOTING;

        proposal.total_voting_power_snapshot =
            total_voting_power_snapshot;
    };

    let proposal =
        vector::borrow(
            &registry.proposals,
            index,
        );

    event::emit(
        GovernanceVotingOpened {
            registry_id:
                object::id(registry),

            proposal_id,

            total_voting_power_snapshot,

            voting_start_epoch:
                proposal.voting_start_epoch,

            voting_end_epoch:
                proposal.voting_end_epoch,

            opened_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Voting Read API
   ============================================================ */

public fun proposal_for_votes(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).for_votes
}

public fun proposal_against_votes(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).against_votes
}

public fun proposal_abstain_votes(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).abstain_votes
}

public fun proposal_total_voting_power_snapshot(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).total_voting_power_snapshot
}

public fun proposal_vote_count(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).vote_count
}

public fun proposal_finalized(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): bool {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    vector::borrow(
        &registry.proposals,
        index,
    ).finalized
}


/* ============================================================
   Stage 10 Part 2-C
   Vote Casting
   ============================================================ */

public fun cast_vote(
    registry: &mut GovernanceRegistry,
    proposal_id: u64,
    choice: u8,
    voting_power: u64,
    ctx: &mut TxContext,
) {
    assert!(
        choice == VOTE_FOR
            || choice == VOTE_AGAINST
            || choice == VOTE_ABSTAIN,
        E_INVALID_VOTE_CHOICE,
    );

    assert!(
        voting_power > 0,
        E_ZERO_VOTING_POWER,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let voter =
        tx_context::sender(ctx);

    assert!(
        !has_voted(
            registry,
            proposal_id,
            voter,
        ),
        E_DUPLICATE_VOTE,
    );

    {
        let proposal =
            vector::borrow(
                &registry.proposals,
                index,
            );

        assert!(
            proposal.status == STATUS_VOTING,
            E_INVALID_PROPOSAL_STATUS,
        );

        assert!(
            tx_context::epoch(ctx)
                <= proposal.voting_end_epoch,
            E_VOTING_ENDED,
        );

        let votes_after =
            proposal.for_votes
                + proposal.against_votes
                + proposal.abstain_votes
                + voting_power;

        assert!(
            votes_after
                <= proposal.total_voting_power_snapshot,
            E_VOTING_POWER_EXCEEDS_SNAPSHOT,
        );
    };

    {
        let proposal =
            vector::borrow_mut(
                &mut registry.proposals,
                index,
            );

        if (choice == VOTE_FOR) {
            proposal.for_votes =
                proposal.for_votes + voting_power;
        } else if (choice == VOTE_AGAINST) {
            proposal.against_votes =
                proposal.against_votes + voting_power;
        } else {
            proposal.abstain_votes =
                proposal.abstain_votes + voting_power;
        };

        proposal.vote_count =
            proposal.vote_count + 1;
    };

    vector::push_back(
        &mut registry.vote_receipts,
        VoteReceipt {
            proposal_id,
            voter,
            choice,
            voting_power,
            cast_epoch:
                tx_context::epoch(ctx),
        },
    );

    let vote_count_after =
        vector::borrow(
            &registry.proposals,
            index,
        ).vote_count;

    event::emit(
        GovernanceVoteCast {
            registry_id:
                object::id(registry),

            proposal_id,
            voter,
            choice,
            voting_power,
            vote_count_after,
        },
    );
}


/* ============================================================
   Vote Receipt Helpers
   ============================================================ */

fun has_voted(
    registry: &GovernanceRegistry,
    proposal_id: u64,
    voter: address,
): bool {
    let mut i = 0;

    let length =
        vector::length(
            &registry.vote_receipts,
        );

    while (i < length) {
        let receipt =
            vector::borrow(
                &registry.vote_receipts,
                i,
            );

        if (
            receipt.proposal_id
                == proposal_id
            && receipt.voter
                == voter
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


public fun vote_receipt_count(
    registry: &GovernanceRegistry,
): u64 {
    vector::length(
        &registry.vote_receipts,
    )
}


public fun vote_for(): u8 {
    VOTE_FOR
}

public fun vote_against(): u8 {
    VOTE_AGAINST
}

public fun vote_abstain(): u8 {
    VOTE_ABSTAIN
}


/* ============================================================
   Stage 10 Part 2-D
   Vote Finalization
   ============================================================ */

public fun finalize_vote(
    registry: &mut GovernanceRegistry,
    proposal_id: u64,
    ctx: &mut TxContext,
) {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let (
        for_votes,
        against_votes,
        abstain_votes,
        total_voting_power_snapshot,
        voting_end_epoch,
        finalized,
        status,
    ) = {
        let proposal =
            vector::borrow(
                &registry.proposals,
                index,
            );

        (
            proposal.for_votes,
            proposal.against_votes,
            proposal.abstain_votes,
            proposal.total_voting_power_snapshot,
            proposal.voting_end_epoch,
            proposal.finalized,
            proposal.status,
        )
    };

    assert!(
        status == STATUS_VOTING,
        E_INVALID_PROPOSAL_STATUS,
    );

    assert!(
        !finalized,
        E_PROPOSAL_ALREADY_FINALIZED,
    );

    assert!(
        tx_context::epoch(ctx)
            > voting_end_epoch,
        E_VOTING_NOT_ENDED,
    );

    let participation =
        for_votes
            + against_votes
            + abstain_votes;

    let participation_bps =
        participation
            * BPS_DENOMINATOR
            / total_voting_power_snapshot;

    let decisive_votes =
        for_votes + against_votes;

    let approval_ratio_bps =
        if (decisive_votes == 0) {
            0
        } else {
            for_votes
                * BPS_DENOMINATOR
                / decisive_votes
        };

    let quorum_met =
        participation_bps
            >= registry.quorum_bps;

    let approval_met =
        approval_ratio_bps
            >= registry.approval_bps;

    let approved =
        quorum_met && approval_met;

    {
        let proposal =
            vector::borrow_mut(
                &mut registry.proposals,
                index,
            );

        proposal.status =
            if (approved) {
                STATUS_APPROVED
            } else {
                STATUS_REJECTED
            };

        proposal.finalized =
            true;
    };

    event::emit(
        GovernanceVoteFinalized {
            registry_id:
                object::id(registry),

            proposal_id,

            for_votes,
            against_votes,
            abstain_votes,

            participation_bps,
            approval_bps:
                approval_ratio_bps,

            approved,

            finalized_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Vote Calculation Read API
   ============================================================ */

public fun proposal_participation_bps(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let proposal =
        vector::borrow(
            &registry.proposals,
            index,
        );

    if (
        proposal.total_voting_power_snapshot == 0
    ) {
        return 0
    };

    (
        proposal.for_votes
            + proposal.against_votes
            + proposal.abstain_votes
    )
        * BPS_DENOMINATOR
        / proposal.total_voting_power_snapshot
}


public fun proposal_approval_bps(
    registry: &GovernanceRegistry,
    proposal_id: u64,
): u64 {
    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let proposal =
        vector::borrow(
            &registry.proposals,
            index,
        );

    let decisive_votes =
        proposal.for_votes
            + proposal.against_votes;

    if (decisive_votes == 0) {
        return 0
    };

    proposal.for_votes
        * BPS_DENOMINATOR
        / decisive_votes
}


/* ============================================================
   Stage 10 Part 3-A
   Timelock Queue
   ============================================================ */

public fun queue_proposal(
    registry: &mut GovernanceRegistry,
    admin_cap: &GovernanceAdminCap,
    proposal_id: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    {
        let proposal =
            vector::borrow(
                &registry.proposals,
                index,
            );

        assert!(
            proposal.status == STATUS_APPROVED,
            E_PROPOSAL_NOT_APPROVED,
        );

        assert!(
            !proposal.executed,
            E_INVALID_PROPOSAL_STATUS,
        );
    };

    {
        let proposal =
            vector::borrow_mut(
                &mut registry.proposals,
                index,
            );

        proposal.status =
            STATUS_QUEUED;
    };

    let executable_epoch =
        vector::borrow(
            &registry.proposals,
            index,
        ).executable_epoch;

    event::emit(
        GovernanceProposalQueued {
            registry_id:
                object::id(registry),

            proposal_id,
            executable_epoch,

            queued_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Stage 10 Part 3-B
   Execution Authorization
   ============================================================ */

public fun authorize_execution(
    registry: &GovernanceRegistry,
    admin_cap: &GovernanceAdminCap,
    proposal_id: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let proposal =
        vector::borrow(
            &registry.proposals,
            index,
        );

    assert!(
        proposal.status == STATUS_QUEUED,
        E_INVALID_PROPOSAL_STATUS,
    );

    let authorization =
        ExecutionAuthorization {
            id: object::new(ctx),

            registry_id:
                object::id(registry),

            proposal_id:
                proposal.proposal_id,

            action_type:
                proposal.action_type,

            target_object_id:
                proposal.target_object_id,

            payload_hash:
                proposal.payload_hash,

            executable_epoch:
                proposal.executable_epoch,

            consumed: false,
        };

    let authorization_id =
        object::id(&authorization);

    event::emit(
        GovernanceExecutionAuthorized {
            registry_id:
                object::id(registry),

            proposal_id,

            authorization_id,

            executable_epoch:
                proposal.executable_epoch,

            authorized_by:
                tx_context::sender(ctx),
        },
    );

    transfer::public_transfer(
        authorization,
        recipient,
    );
}


/* ============================================================
   Stage 10 Part 3-C
   Execution Authorization Validation
   ============================================================ */

public fun assert_execution_authorized(
    authorization: &ExecutionAuthorization,

    proposal_id: u64,
    action_type: u64,
    target_object_id: ID,
    payload_hash: &vector<u8>,

    ctx: &TxContext,
) {
    assert!(
        !authorization.consumed,
        E_AUTHORIZATION_CONSUMED,
    );

    assert!(
        authorization.proposal_id
            == proposal_id,
        E_AUTHORIZATION_MISMATCH,
    );

    assert!(
        authorization.action_type
            == action_type,
        E_AUTHORIZATION_MISMATCH,
    );

    assert!(
        authorization.target_object_id
            == target_object_id,
        E_AUTHORIZATION_MISMATCH,
    );

    assert!(
        authorization.payload_hash
            == *payload_hash,
        E_AUTHORIZATION_MISMATCH,
    );

    assert!(
        tx_context::epoch(ctx)
            >= authorization.executable_epoch,
        E_TIMELOCK_ACTIVE,
    );
}


public fun consume_execution_authorization(
    authorization: &mut ExecutionAuthorization,

    proposal_id: u64,
    action_type: u64,
    target_object_id: ID,
    payload_hash: &vector<u8>,

    ctx: &TxContext,
) {
    assert_execution_authorized(
        authorization,
        proposal_id,
        action_type,
        target_object_id,
        payload_hash,
        ctx,
    );

    authorization.consumed =
        true;
}


/* ============================================================
   Execution Authorization Read API
   ============================================================ */

public fun authorization_proposal_id(
    authorization: &ExecutionAuthorization,
): u64 {
    authorization.proposal_id
}

public fun authorization_action_type(
    authorization: &ExecutionAuthorization,
): u64 {
    authorization.action_type
}

public fun authorization_target_object_id(
    authorization: &ExecutionAuthorization,
): ID {
    authorization.target_object_id
}

public fun authorization_executable_epoch(
    authorization: &ExecutionAuthorization,
): u64 {
    authorization.executable_epoch
}

public fun authorization_consumed(
    authorization: &ExecutionAuthorization,
): bool {
    authorization.consumed
}


/* ============================================================
   Stage 10 Part 3-D
   Proposal Execution Finalization
   ============================================================ */

public fun mark_executed(
    registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    proposal_id: u64,
    action_type: u64,
    target_object_id: ID,
    payload_hash: &vector<u8>,

    ctx: &TxContext,
) {
    assert_authorization_registry(
        registry,
        authorization,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    {
        let proposal =
            vector::borrow(
                &registry.proposals,
                index,
            );

        assert!(
            proposal.status == STATUS_QUEUED,
            E_INVALID_PROPOSAL_STATUS,
        );

        assert!(
            !proposal.executed,
            E_AUTHORIZATION_CONSUMED,
        );
    };

    consume_execution_authorization(
        authorization,
        proposal_id,
        action_type,
        target_object_id,
        payload_hash,
        ctx,
    );

    {
        let proposal =
            vector::borrow_mut(
                &mut registry.proposals,
                index,
            );

        proposal.status =
            STATUS_EXECUTED;

        proposal.executed =
            true;
    };

    registry.total_proposals_executed =
        registry.total_proposals_executed + 1;

    event::emit(
        GovernanceProposalExecuted {
            registry_id:
                object::id(registry),

            proposal_id,

            authorization_id:
                object::id(authorization),

            executed_by:
                tx_context::sender(ctx),

            executed_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Execution Authorization Test Cleanup
   ============================================================ */

#[test_only]
public fun destroy_execution_authorization_for_testing(
    authorization: ExecutionAuthorization,
) {
    let ExecutionAuthorization {
        id,
        registry_id: _,
        proposal_id: _,
        action_type: _,
        target_object_id: _,
        payload_hash: _,
        executable_epoch: _,
        consumed: _,
    } = authorization;

    object::delete(id);
}


/* ============================================================
   Stage 10 Part 5-A
   Emergency Governance Lifecycle
   ============================================================ */

fun assert_emergency_cap(
    registry: &GovernanceRegistry,
    emergency_cap: &EmergencyGovernanceCap,
) {
    assert!(
        emergency_cap.registry_id
            == object::id(registry),
        E_EMERGENCY_CAP_MISMATCH,
    );
}


public fun activate_emergency(
    registry: &mut GovernanceRegistry,
    emergency_cap: &EmergencyGovernanceCap,
    ctx: &mut TxContext,
) {
    assert_emergency_cap(
        registry,
        emergency_cap,
    );

    assert!(
        !registry.emergency_mode,
        E_EMERGENCY_STATE_UNCHANGED,
    );

    registry.emergency_mode =
        true;

    registry.emergency_activation_count =
        registry.emergency_activation_count + 1;

    event::emit(
        GovernanceEmergencyActivated {
            registry_id:
                object::id(registry),

            activated_by:
                tx_context::sender(ctx),

            activation_count:
                registry.emergency_activation_count,
        },
    );
}


public fun clear_emergency(
    registry: &mut GovernanceRegistry,
    emergency_cap: &EmergencyGovernanceCap,
    ctx: &mut TxContext,
) {
    assert_emergency_cap(
        registry,
        emergency_cap,
    );

    assert!(
        registry.emergency_mode,
        E_EMERGENCY_STATE_UNCHANGED,
    );

    registry.emergency_mode =
        false;

    registry.emergency_clear_count =
        registry.emergency_clear_count + 1;

    event::emit(
        GovernanceEmergencyCleared {
            registry_id:
                object::id(registry),

            cleared_by:
                tx_context::sender(ctx),

            clear_count:
                registry.emergency_clear_count,
        },
    );
}


public fun assert_not_emergency(
    registry: &GovernanceRegistry,
) {
    assert!(
        !registry.emergency_mode,
        E_EMERGENCY_MODE_ACTIVE,
    );
}


public fun assert_emergency_active(
    registry: &GovernanceRegistry,
) {
    assert!(
        registry.emergency_mode,
        E_EMERGENCY_MODE_INACTIVE,
    );
}


/* ============================================================
   Emergency Governance Read API
   ============================================================ */

public fun is_emergency_mode(
    registry: &GovernanceRegistry,
): bool {
    registry.emergency_mode
}

public fun emergency_activation_count(
    registry: &GovernanceRegistry,
): u64 {
    registry.emergency_activation_count
}

public fun emergency_clear_count(
    registry: &GovernanceRegistry,
): u64 {
    registry.emergency_clear_count
}


#[test_only]
public fun emergency_cap_for_testing(
    registry: &GovernanceRegistry,
    ctx: &mut TxContext,
): EmergencyGovernanceCap {
    EmergencyGovernanceCap {
        id: object::new(ctx),
        registry_id:
            object::id(registry),
    }
}


#[test_only]
public fun destroy_emergency_cap_for_testing(
    cap: EmergencyGovernanceCap,
) {
    let EmergencyGovernanceCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}


/* ============================================================
   Stage 10 Part 5-B
   Emergency Proposal Veto
   ============================================================ */

public fun emergency_veto_proposal(
    registry: &mut GovernanceRegistry,
    emergency_cap: &EmergencyGovernanceCap,
    proposal_id: u64,
    ctx: &mut TxContext,
) {
    assert_emergency_cap(
        registry,
        emergency_cap,
    );

    assert_emergency_active(
        registry,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let previous_status = {
        let proposal =
            vector::borrow(
                &registry.proposals,
                index,
            );

        assert!(
            proposal.status == STATUS_SUBMITTED
                || proposal.status == STATUS_VOTING
                || proposal.status == STATUS_APPROVED
                || proposal.status == STATUS_QUEUED,
            E_PROPOSAL_NOT_VETOABLE,
        );

        assert!(
            !proposal.executed,
            E_PROPOSAL_NOT_VETOABLE,
        );

        proposal.status
    };

    {
        let proposal =
            vector::borrow_mut(
                &mut registry.proposals,
                index,
            );

        proposal.status =
            STATUS_CANCELLED;

        proposal.finalized =
            true;
    };

    event::emit(
        GovernanceProposalVetoed {
            registry_id:
                object::id(registry),

            proposal_id,
            previous_status,

            vetoed_by:
                tx_context::sender(ctx),

            vetoed_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Proposal Execution State Guard
   ============================================================ */

public fun assert_proposal_execution_allowed(
    registry: &GovernanceRegistry,
    proposal_id: u64,
) {
    assert_not_emergency(
        registry,
    );

    let index =
        find_proposal_index(
            registry,
            proposal_id,
        );

    let proposal =
        vector::borrow(
            &registry.proposals,
            index,
        );

    assert!(
        proposal.status != STATUS_CANCELLED,
        E_PROPOSAL_CANCELLED,
    );

    assert!(
        proposal.status == STATUS_QUEUED,
        E_INVALID_PROPOSAL_STATUS,
    );

    assert!(
        !proposal.executed,
        E_AUTHORIZATION_CONSUMED,
    );
}


/* ============================================================
   Stage 10 Part 6-C
   Cross-Registry Authorization Isolation
   ============================================================ */

public fun assert_authorization_registry(
    registry: &GovernanceRegistry,
    authorization: &ExecutionAuthorization,
) {
    assert!(
        authorization.registry_id
            == object::id(registry),
        E_AUTHORIZATION_REGISTRY_MISMATCH,
    );
}


public fun authorization_registry_id(
    authorization: &ExecutionAuthorization,
): ID {
    authorization.registry_id
}
