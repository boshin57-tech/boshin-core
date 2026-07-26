module tobmate_core::gsos_agent_authority;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::gsos_identity_binding::{
    Self as identity_binding,
    GSOSIdentityRegistry,
};

use tobmate_core::gsos_protocol_registry::{
    Self as protocol_registry,
    GSOSProtocolRegistry,
};

use tobmate_core::gsos_world_space_registry::{
    Self as world_space,
    GSOSWorldSpaceRegistry,
};


/* ============================================================
   Stage 11 Part 7
   GSOS AI Agent Authority / Delegation
   Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Authority Types

   Part 7 defines delegation level only.
   Concrete capabilities are assigned in Part 8.
   ============================================================ */

const AUTHORITY_OBSERVE: u8 = 1;
const AUTHORITY_INTERACT: u8 = 2;
const AUTHORITY_EXECUTE: u8 = 3;
const AUTHORITY_DELEGATE: u8 = 4;


/* ============================================================
   Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_REVOKED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_AGENT_IDENTITY: u64 = 2;
const E_INVALID_PRINCIPAL_IDENTITY: u64 = 3;
const E_INVALID_WORLD_ID: u64 = 4;
const E_INVALID_SPACE_BINDING_ID: u64 = 5;
const E_WORLD_SPACE_MISMATCH: u64 = 6;
const E_INVALID_AGENT_PROTOCOL: u64 = 7;
const E_INVALID_AUTHORITY_TYPE: u64 = 8;
const E_INVALID_VALIDITY_RANGE: u64 = 9;
const E_DUPLICATE_ACTIVE_AUTHORITY: u64 = 10;
const E_AUTHORITY_NOT_FOUND: u64 = 11;
const E_AUTHORITY_INACTIVE: u64 = 12;
const E_INVALID_DELEGATE_AGENT: u64 = 13;
const E_DELEGATION_NOT_FOUND: u64 = 14;
const E_DUPLICATE_ACTIVE_DELEGATION: u64 = 15;
const E_DELEGATION_EXCEEDS_AUTHORITY: u64 = 16;
const E_DELEGATION_SCOPE_EXPANSION: u64 = 17;
const E_DELEGATION_VALIDITY_EXPANSION: u64 = 18;
const E_STATE_UNCHANGED: u64 = 19;
const E_ALREADY_REVOKED: u64 = 20;
const E_VERSION_UNCHANGED: u64 = 21;
const E_ADMIN_CAP_MISMATCH: u64 = 22;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSAgentAuthorityRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_authority_id: u64,
    next_delegation_id: u64,

    authorities: vector<AgentAuthority>,
    delegations: vector<AgentDelegation>,

    total_authorities: u64,
    total_delegations: u64,

    active_authority_count: u64,
    active_delegation_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSAgentAuthorityAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Agent Authority

   agent_identity_binding_id:
     canonical AGENT identity.

   principal_identity_binding_id:
     canonical principal represented by the agent.

   space_binding_id == 0:
     authority is World-level.

   space_binding_id > 0:
     authority is scoped to that GSOS Space Binding.

   valid_until_epoch == 0:
     no fixed expiry.
   ============================================================ */

public struct AgentAuthority has store {
    authority_id: u64,

    agent_identity_binding_id: u64,
    principal_identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    agent_protocol_id: u64,
    authority_type: u8,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Agent Delegation

   Delegation must remain within the parent authority's:
   - principal relationship
   - world / space scope
   - authority level
   - validity range
   ============================================================ */

public struct AgentDelegation has store {
    delegation_id: u64,

    parent_authority_id: u64,

    delegator_agent_identity_binding_id: u64,
    delegate_agent_identity_binding_id: u64,

    principal_identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    authority_type: u8,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct AgentAuthorityCreated has copy, drop {
    registry_id: ID,

    authority_id: u64,

    agent_identity_binding_id: u64,
    principal_identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    agent_protocol_id: u64,
    authority_type: u8,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    created_by: address,
    created_epoch: u64,
}

public struct AgentDelegationCreated has copy, drop {
    registry_id: ID,

    delegation_id: u64,
    parent_authority_id: u64,

    delegator_agent_identity_binding_id: u64,
    delegate_agent_identity_binding_id: u64,

    principal_identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    authority_type: u8,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    created_by: address,
    created_epoch: u64,
}

public struct AgentAuthorityStatusChanged has copy, drop {
    registry_id: ID,
    authority_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct AgentDelegationStatusChanged has copy, drop {
    registry_id: ID,
    delegation_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct AgentAuthorityPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct AgentAuthorityVersionChanged has copy, drop {
    registry_id: ID,

    previous_version: u64,
    new_version: u64,

    changed_by: address,
}


/* ============================================================
   Registry Creation
   ============================================================ */

public fun create(
    access: &AccessControl,
    ctx: &mut TxContext,
): (
    GSOSAgentAuthorityRegistry,
    GSOSAgentAuthorityAdminCap,
) {
    access_control::assert_not_paused(access);

    let registry = GSOSAgentAuthorityRegistry {
        id: object::new(ctx),

        version: REGISTRY_VERSION,
        paused: false,

        next_authority_id: 1,
        next_delegation_id: 1,

        authorities: vector[],
        delegations: vector[],

        total_authorities: 0,
        total_delegations: 0,

        active_authority_count: 0,
        active_delegation_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSAgentAuthorityAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Core Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSAgentAuthorityRegistry,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_authority_type(
    authority_type: u8,
) {
    assert!(
        authority_type >= AUTHORITY_OBSERVE
            && authority_type <= AUTHORITY_DELEGATE,
        E_INVALID_AUTHORITY_TYPE,
    );
}

fun assert_validity_range(
    valid_from_epoch: u64,
    valid_until_epoch: u64,
) {
    assert!(
        valid_until_epoch == 0
            || valid_until_epoch >= valid_from_epoch,
        E_INVALID_VALIDITY_RANGE,
    );
}


/* ============================================================
   Identity Validation
   ============================================================ */

fun assert_agent_identity(
    identities: &GSOSIdentityRegistry,
    identity_binding_id: u64,
) {
    assert!(
        identity_binding_id != 0,
        E_INVALID_AGENT_IDENTITY,
    );

    assert!(
        identity_binding::binding_status(
            identities,
            identity_binding_id,
        ) == identity_binding::status_active(),
        E_INVALID_AGENT_IDENTITY,
    );

    assert!(
        identity_binding::binding_identity_type(
            identities,
            identity_binding_id,
        ) == identity_binding::identity_agent(),
        E_INVALID_AGENT_IDENTITY,
    );
}

fun assert_principal_identity(
    identities: &GSOSIdentityRegistry,
    identity_binding_id: u64,
) {
    assert!(
        identity_binding_id != 0,
        E_INVALID_PRINCIPAL_IDENTITY,
    );

    assert!(
        identity_binding::binding_status(
            identities,
            identity_binding_id,
        ) == identity_binding::status_active(),
        E_INVALID_PRINCIPAL_IDENTITY,
    );
}


/* ============================================================
   World / Space Validation
   ============================================================ */

fun assert_world_scope(
    worlds: &GSOSWorldSpaceRegistry,
    world_id: u64,
    space_binding_id: u64,
) {
    assert!(
        world_id != 0,
        E_INVALID_WORLD_ID,
    );

    assert!(
        world_space::world_status(
            worlds,
            world_id,
        ) == world_space::status_active(),
        E_INVALID_WORLD_ID,
    );

    if (space_binding_id == 0) {
        return
    };

    assert!(
        world_space::binding_status(
            worlds,
            space_binding_id,
        ) == world_space::status_active(),
        E_INVALID_SPACE_BINDING_ID,
    );

    assert!(
        world_space::binding_world_id(
            worlds,
            space_binding_id,
        ) == world_id,
        E_WORLD_SPACE_MISMATCH,
    );
}


/* ============================================================
   AGENT Protocol Validation
   ============================================================ */

fun assert_agent_protocol(
    protocols: &GSOSProtocolRegistry,
    agent_protocol_id: u64,
) {
    assert!(
        agent_protocol_id != 0,
        E_INVALID_AGENT_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_exists(
            protocols,
            agent_protocol_id,
        ),
        E_INVALID_AGENT_PROTOCOL,
    );

    assert!(
        protocol_registry::is_protocol_active(
            protocols,
            agent_protocol_id,
        ),
        E_INVALID_AGENT_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_family(
            protocols,
            agent_protocol_id,
        ) == protocol_registry::family_agent(),
        E_INVALID_AGENT_PROTOCOL,
    );
}


/* ============================================================
   Authority Lookup
   ============================================================ */

fun authority_index(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u64 {
    let length =
        vector::length(&registry.authorities);

    let mut i = 0;

    while (i < length) {
        let authority =
            vector::borrow(
                &registry.authorities,
                i,
            );

        if (authority.authority_id == authority_id) {
            return i
        };

        i = i + 1;
    };

    abort E_AUTHORITY_NOT_FOUND
}

fun borrow_authority_internal(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): &AgentAuthority {
    let index =
        authority_index(
            registry,
            authority_id,
        );

    vector::borrow(
        &registry.authorities,
        index,
    )
}


/* ============================================================
   Delegation Lookup
   ============================================================ */

fun delegation_index(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): u64 {
    let length =
        vector::length(&registry.delegations);

    let mut i = 0;

    while (i < length) {
        let delegation =
            vector::borrow(
                &registry.delegations,
                i,
            );

        if (
            delegation.delegation_id
                == delegation_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_DELEGATION_NOT_FOUND
}


/* ============================================================
   Duplicate Authority Guard
   ============================================================ */

fun assert_no_duplicate_active_authority(
    registry: &GSOSAgentAuthorityRegistry,
    agent_identity_binding_id: u64,
    principal_identity_binding_id: u64,
    world_id: u64,
    space_binding_id: u64,
) {
    let length =
        vector::length(&registry.authorities);

    let mut i = 0;

    while (i < length) {
        let authority =
            vector::borrow(
                &registry.authorities,
                i,
            );

        let duplicate =
            authority.status == STATUS_ACTIVE
                && authority.agent_identity_binding_id
                    == agent_identity_binding_id
                && authority.principal_identity_binding_id
                    == principal_identity_binding_id
                && authority.world_id == world_id
                && authority.space_binding_id
                    == space_binding_id;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_AUTHORITY,
        );

        i = i + 1;
    };
}


/* ============================================================
   Duplicate Delegation Guard
   ============================================================ */

fun assert_no_duplicate_active_delegation(
    registry: &GSOSAgentAuthorityRegistry,
    parent_authority_id: u64,
    delegate_agent_identity_binding_id: u64,
) {
    let length =
        vector::length(&registry.delegations);

    let mut i = 0;

    while (i < length) {
        let delegation =
            vector::borrow(
                &registry.delegations,
                i,
            );

        let duplicate =
            delegation.status == STATUS_ACTIVE
                && delegation.parent_authority_id
                    == parent_authority_id
                && delegation.delegate_agent_identity_binding_id
                    == delegate_agent_identity_binding_id;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_DELEGATION,
        );

        i = i + 1;
    };
}


/* ============================================================
   Create Agent Authority
   ============================================================ */

public fun create_authority(
    access: &AccessControl,
    registry: &mut GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,

    identities: &GSOSIdentityRegistry,
    worlds: &GSOSWorldSpaceRegistry,
    protocols: &GSOSProtocolRegistry,

    agent_identity_binding_id: u64,
    principal_identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    agent_protocol_id: u64,
    authority_type: u8,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_agent_identity(
        identities,
        agent_identity_binding_id,
    );

    assert_principal_identity(
        identities,
        principal_identity_binding_id,
    );

    assert_world_scope(
        worlds,
        world_id,
        space_binding_id,
    );

    assert_agent_protocol(
        protocols,
        agent_protocol_id,
    );

    assert_valid_authority_type(
        authority_type,
    );

    assert_validity_range(
        valid_from_epoch,
        valid_until_epoch,
    );

    assert_no_duplicate_active_authority(
        registry,
        agent_identity_binding_id,
        principal_identity_binding_id,
        world_id,
        space_binding_id,
    );

    let authority_id =
        registry.next_authority_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.authorities,
        AgentAuthority {
            authority_id,

            agent_identity_binding_id,
            principal_identity_binding_id,

            world_id,
            space_binding_id,

            agent_protocol_id,
            authority_type,

            valid_from_epoch,
            valid_until_epoch,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_authority_id =
        authority_id + 1;

    registry.total_authorities =
        registry.total_authorities + 1;

    registry.active_authority_count =
        registry.active_authority_count + 1;

    event::emit(AgentAuthorityCreated {
        registry_id: object::id(registry),

        authority_id,

        agent_identity_binding_id,
        principal_identity_binding_id,

        world_id,
        space_binding_id,

        agent_protocol_id,
        authority_type,

        valid_from_epoch,
        valid_until_epoch,

        created_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    authority_id
}


/* ============================================================
   Create Agent Delegation
   ============================================================ */

public fun create_delegation(
    access: &AccessControl,
    registry: &mut GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,

    identities: &GSOSIdentityRegistry,

    parent_authority_id: u64,
    delegate_agent_identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    authority_type: u8,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_agent_identity(
        identities,
        delegate_agent_identity_binding_id,
    );

    assert_valid_authority_type(
        authority_type,
    );

    assert_validity_range(
        valid_from_epoch,
        valid_until_epoch,
    );

    let (
        delegator_agent_identity_binding_id,
        principal_identity_binding_id,
        parent_world_id,
        parent_space_binding_id,
        parent_authority_type,
        parent_valid_from_epoch,
        parent_valid_until_epoch,
    );

    {
        let parent =
            borrow_authority_internal(
                registry,
                parent_authority_id,
            );

        assert!(
            parent.status == STATUS_ACTIVE,
            E_AUTHORITY_INACTIVE,
        );

        delegator_agent_identity_binding_id =
            parent.agent_identity_binding_id;

        principal_identity_binding_id =
            parent.principal_identity_binding_id;

        parent_world_id =
            parent.world_id;

        parent_space_binding_id =
            parent.space_binding_id;

        parent_authority_type =
            parent.authority_type;

        parent_valid_from_epoch =
            parent.valid_from_epoch;

        parent_valid_until_epoch =
            parent.valid_until_epoch;
    };

    assert!(
        authority_type <= parent_authority_type,
        E_DELEGATION_EXCEEDS_AUTHORITY,
    );

    assert!(
        world_id == parent_world_id,
        E_DELEGATION_SCOPE_EXPANSION,
    );

    if (parent_space_binding_id != 0) {
        assert!(
            space_binding_id
                == parent_space_binding_id,
            E_DELEGATION_SCOPE_EXPANSION,
        );
    };

    assert!(
        valid_from_epoch >= parent_valid_from_epoch,
        E_DELEGATION_VALIDITY_EXPANSION,
    );

    if (parent_valid_until_epoch != 0) {
        assert!(
            valid_until_epoch != 0
                && valid_until_epoch
                    <= parent_valid_until_epoch,
            E_DELEGATION_VALIDITY_EXPANSION,
        );
    };

    assert_no_duplicate_active_delegation(
        registry,
        parent_authority_id,
        delegate_agent_identity_binding_id,
    );

    let delegation_id =
        registry.next_delegation_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.delegations,
        AgentDelegation {
            delegation_id,

            parent_authority_id,

            delegator_agent_identity_binding_id,
            delegate_agent_identity_binding_id,

            principal_identity_binding_id,

            world_id,
            space_binding_id,

            authority_type,

            valid_from_epoch,
            valid_until_epoch,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_delegation_id =
        delegation_id + 1;

    registry.total_delegations =
        registry.total_delegations + 1;

    registry.active_delegation_count =
        registry.active_delegation_count + 1;

    event::emit(AgentDelegationCreated {
        registry_id: object::id(registry),

        delegation_id,
        parent_authority_id,

        delegator_agent_identity_binding_id,
        delegate_agent_identity_binding_id,

        principal_identity_binding_id,

        world_id,
        space_binding_id,

        authority_type,

        valid_from_epoch,
        valid_until_epoch,

        created_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    delegation_id
}


/* ============================================================
   Mutable Lookup
   ============================================================ */

fun borrow_authority_internal_mut(
    registry: &mut GSOSAgentAuthorityRegistry,
    authority_id: u64,
): &mut AgentAuthority {
    let index =
        authority_index(
            registry,
            authority_id,
        );

    vector::borrow_mut(
        &mut registry.authorities,
        index,
    )
}

fun borrow_delegation_internal(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): &AgentDelegation {
    let index =
        delegation_index(
            registry,
            delegation_id,
        );

    vector::borrow(
        &registry.delegations,
        index,
    )
}

fun borrow_delegation_internal_mut(
    registry: &mut GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): &mut AgentDelegation {
    let index =
        delegation_index(
            registry,
            delegation_id,
        );

    vector::borrow_mut(
        &mut registry.delegations,
        index,
    )
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun version(
    registry: &GSOSAgentAuthorityRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSAgentAuthorityRegistry,
): bool {
    registry.paused
}

public fun total_authorities(
    registry: &GSOSAgentAuthorityRegistry,
): u64 {
    registry.total_authorities
}

public fun total_delegations(
    registry: &GSOSAgentAuthorityRegistry,
): u64 {
    registry.total_delegations
}

public fun active_authority_count(
    registry: &GSOSAgentAuthorityRegistry,
): u64 {
    registry.active_authority_count
}

public fun active_delegation_count(
    registry: &GSOSAgentAuthorityRegistry,
): u64 {
    registry.active_delegation_count
}


/* ============================================================
   Authority Read API
   ============================================================ */

public fun authority_agent_identity_binding_id(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u64 {
    borrow_authority_internal(
        registry,
        authority_id,
    ).agent_identity_binding_id
}

public fun authority_principal_identity_binding_id(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u64 {
    borrow_authority_internal(
        registry,
        authority_id,
    ).principal_identity_binding_id
}

public fun authority_world_id(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u64 {
    borrow_authority_internal(
        registry,
        authority_id,
    ).world_id
}

public fun authority_space_binding_id(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u64 {
    borrow_authority_internal(
        registry,
        authority_id,
    ).space_binding_id
}

public fun authority_type(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u8 {
    borrow_authority_internal(
        registry,
        authority_id,
    ).authority_type
}

public fun authority_status(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
): u8 {
    borrow_authority_internal(
        registry,
        authority_id,
    ).status
}


/* ============================================================
   Delegation Read API
   ============================================================ */

public fun delegation_parent_authority_id(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): u64 {
    borrow_delegation_internal(
        registry,
        delegation_id,
    ).parent_authority_id
}

public fun delegation_delegate_agent_identity_binding_id(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): u64 {
    borrow_delegation_internal(
        registry,
        delegation_id,
    ).delegate_agent_identity_binding_id
}

public fun delegation_authority_type(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): u8 {
    borrow_delegation_internal(
        registry,
        delegation_id,
    ).authority_type
}

public fun delegation_status(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
): u8 {
    borrow_delegation_internal(
        registry,
        delegation_id,
    ).status
}


/* ============================================================
   Constant Accessors
   ============================================================ */

public fun authority_observe(): u8 {
    AUTHORITY_OBSERVE
}

public fun authority_interact(): u8 {
    AUTHORITY_INTERACT
}

public fun authority_execute(): u8 {
    AUTHORITY_EXECUTE
}

public fun authority_delegate(): u8 {
    AUTHORITY_DELEGATE
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_suspended(): u8 {
    STATUS_SUSPENDED
}

public fun status_revoked(): u8 {
    STATUS_REVOKED
}


/* ============================================================
   Runtime Validity
   ============================================================ */

public fun is_authority_valid(
    registry: &GSOSAgentAuthorityRegistry,
    authority_id: u64,
    current_epoch: u64,
): bool {
    if (registry.paused) {
        return false
    };

    let authority =
        borrow_authority_internal(
            registry,
            authority_id,
        );

    authority.status == STATUS_ACTIVE
        && current_epoch >= authority.valid_from_epoch
        && (
            authority.valid_until_epoch == 0
                || current_epoch
                    <= authority.valid_until_epoch
        )
}

public fun is_delegation_valid(
    registry: &GSOSAgentAuthorityRegistry,
    delegation_id: u64,
    current_epoch: u64,
): bool {
    if (registry.paused) {
        return false
    };

    let delegation =
        borrow_delegation_internal(
            registry,
            delegation_id,
        );

    if (delegation.status != STATUS_ACTIVE) {
        return false
    };

    let parent =
        borrow_authority_internal(
            registry,
            delegation.parent_authority_id,
        );

    parent.status == STATUS_ACTIVE
        && current_epoch >= delegation.valid_from_epoch
        && (
            delegation.valid_until_epoch == 0
                || current_epoch
                    <= delegation.valid_until_epoch
        )
        && current_epoch >= parent.valid_from_epoch
        && (
            parent.valid_until_epoch == 0
                || current_epoch
                    <= parent.valid_until_epoch
        )
}


/* ============================================================
   Authority Status Lifecycle
   ============================================================ */

public fun set_authority_status(
    access: &AccessControl,
    registry: &mut GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,

    authority_id: u64,
    new_status: u8,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert!(
        new_status == STATUS_ACTIVE
            || new_status == STATUS_SUSPENDED
            || new_status == STATUS_REVOKED,
        E_STATE_UNCHANGED,
    );

    let current_epoch =
        tx_context::epoch(ctx);

    let previous_status;

    {
        let authority =
            borrow_authority_internal_mut(
                registry,
                authority_id,
            );

        previous_status = authority.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        authority.status = new_status;
        authority.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_authority_count =
            registry.active_authority_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_authority_count =
            registry.active_authority_count + 1;
    };

    event::emit(AgentAuthorityStatusChanged {
        registry_id: object::id(registry),
        authority_id,

        previous_status,
        new_status,

        changed_by: tx_context::sender(ctx),
        updated_epoch: current_epoch,
    });
}


/* ============================================================
   Delegation Status Lifecycle
   ============================================================ */

public fun set_delegation_status(
    access: &AccessControl,
    registry: &mut GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,

    delegation_id: u64,
    new_status: u8,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert!(
        new_status == STATUS_ACTIVE
            || new_status == STATUS_SUSPENDED
            || new_status == STATUS_REVOKED,
        E_STATE_UNCHANGED,
    );

    let current_epoch =
        tx_context::epoch(ctx);

    let previous_status;

    {
        let delegation =
            borrow_delegation_internal_mut(
                registry,
                delegation_id,
            );

        previous_status = delegation.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        delegation.status = new_status;
        delegation.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_delegation_count =
            registry.active_delegation_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_delegation_count =
            registry.active_delegation_count + 1;
    };

    event::emit(AgentDelegationStatusChanged {
        registry_id: object::id(registry),
        delegation_id,

        previous_status,
        new_status,

        changed_by: tx_context::sender(ctx),
        updated_epoch: current_epoch,
    });
}


/* ============================================================
   Pause Control
   ============================================================ */

public fun set_paused(
    access: &AccessControl,
    registry: &mut GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,

    paused: bool,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_admin(registry, admin_cap);

    assert!(
        registry.paused != paused,
        E_STATE_UNCHANGED,
    );

    registry.paused = paused;

    event::emit(AgentAuthorityPauseChanged {
        registry_id: object::id(registry),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Version Control
   ============================================================ */

public fun set_version(
    access: &AccessControl,
    registry: &mut GSOSAgentAuthorityRegistry,
    admin_cap: &GSOSAgentAuthorityAdminCap,

    new_version: u64,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_admin(registry, admin_cap);

    assert!(
        registry.version != new_version,
        E_VERSION_UNCHANGED,
    );

    let previous_version =
        registry.version;

    registry.version = new_version;

    event::emit(AgentAuthorityVersionChanged {
        registry_id: object::id(registry),

        previous_version,
        new_version,

        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun destroy_for_testing(
    registry: GSOSAgentAuthorityRegistry,
) {
    let GSOSAgentAuthorityRegistry {
        id,
        version: _,
        paused: _,
        next_authority_id: _,
        next_delegation_id: _,
        authorities,
        delegations,
        total_authorities: _,
        total_delegations: _,
        active_authority_count: _,
        active_delegation_count: _,
    } = registry;

    let mut authorities = authorities;

    while (!vector::is_empty(&authorities)) {
        let authority =
            vector::pop_back(&mut authorities);

        let AgentAuthority {
            authority_id: _,
            agent_identity_binding_id: _,
            principal_identity_binding_id: _,
            world_id: _,
            space_binding_id: _,
            agent_protocol_id: _,
            authority_type: _,
            valid_from_epoch: _,
            valid_until_epoch: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = authority;
    };

    vector::destroy_empty(authorities);

    let mut delegations = delegations;

    while (!vector::is_empty(&delegations)) {
        let delegation =
            vector::pop_back(&mut delegations);

        let AgentDelegation {
            delegation_id: _,
            parent_authority_id: _,
            delegator_agent_identity_binding_id: _,
            delegate_agent_identity_binding_id: _,
            principal_identity_binding_id: _,
            world_id: _,
            space_binding_id: _,
            authority_type: _,
            valid_from_epoch: _,
            valid_until_epoch: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = delegation;
    };

    vector::destroy_empty(delegations);

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSAgentAuthorityAdminCap,
) {
    let GSOSAgentAuthorityAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}
