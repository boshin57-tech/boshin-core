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


/* ============================================================
   Governance Registry
   ============================================================ */

public struct GovernanceRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_proposal_id: u64,
    proposals: vector<GovernanceProposal>,

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

    created_epoch: u64,
    voting_start_epoch: u64,
    voting_end_epoch: u64,
    executable_epoch: u64,

    executed: bool,
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

            next_proposal_id: 1,
            proposals: vector[],

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

        next_proposal_id: 1,
        proposals: vector[],

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

        next_proposal_id: _,
        mut proposals,

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

    object::delete(id);
}
