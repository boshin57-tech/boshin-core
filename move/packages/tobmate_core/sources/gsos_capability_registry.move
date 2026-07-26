module tobmate_core::gsos_capability_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::gsos_protocol_registry::{
    Self as protocol_registry,
    GSOSProtocolRegistry,
};

use tobmate_core::gsos_world_space_registry::{
    Self as world_space,
    GSOSWorldSpaceRegistry,
};

use tobmate_core::gsos_agent_authority::{
    Self as agent_authority,
    GSOSAgentAuthorityRegistry,
};





/* ============================================================
   Stage 11 Part 8
   GSOS Capability Registry
   Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Capability Types
   ============================================================ */

const CAPABILITY_READ: u8 = 1;
const CAPABILITY_WRITE: u8 = 2;
const CAPABILITY_EXECUTE: u8 = 3;
const CAPABILITY_ENTER: u8 = 4;
const CAPABILITY_TRADE: u8 = 5;
const CAPABILITY_CONTROL: u8 = 6;


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
const E_INVALID_CAPABILITY_TYPE: u64 = 2;
const E_EMPTY_CAPABILITY_NAME: u64 = 3;
const E_INVALID_CAPABILITY_PROTOCOL: u64 = 4;
const E_DUPLICATE_ACTIVE_CAPABILITY: u64 = 5;
const E_CAPABILITY_NOT_FOUND: u64 = 6;
const E_INVALID_AUTHORITY_ID: u64 = 7;
const E_INVALID_DELEGATION_ID: u64 = 8;
const E_ASSIGNMENT_SCOPE_MISMATCH: u64 = 9;
const E_ASSIGNMENT_EXCEEDS_AUTHORITY: u64 = 10;
const E_INVALID_VALIDITY_RANGE: u64 = 11;
const E_DUPLICATE_ACTIVE_ASSIGNMENT: u64 = 12;
const E_ASSIGNMENT_NOT_FOUND: u64 = 13;
const E_STATE_UNCHANGED: u64 = 14;
const E_ALREADY_REVOKED: u64 = 15;
const E_VERSION_UNCHANGED: u64 = 16;
const E_ADMIN_CAP_MISMATCH: u64 = 17;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSCapabilityRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_capability_id: u64,
    next_assignment_id: u64,

    capabilities: vector<CapabilityDefinition>,
    assignments: vector<CapabilityAssignment>,

    total_capabilities: u64,
    total_assignments: u64,

    active_capability_count: u64,
    active_assignment_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSCapabilityAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Capability Definition

   protocol_id must point to an ACTIVE CAPABILITY-family
   protocol in GSOS Protocol Registry.
   ============================================================ */

public struct CapabilityDefinition has store {
    capability_id: u64,

    capability_type: u8,
    capability_name: vector<u8>,

    protocol_id: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Capability Assignment

   Exactly one source must be used:

   authority_id > 0, delegation_id == 0
       direct authority assignment

   authority_id == 0, delegation_id > 0
       delegated authority assignment

   world_id / space_binding_id must remain inside the
   authority or delegation scope.

   valid_until_epoch == 0 means no fixed expiry.
   ============================================================ */

public struct CapabilityAssignment has store {
    assignment_id: u64,

    capability_id: u64,

    authority_id: u64,
    delegation_id: u64,

    world_id: u64,
    space_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct CapabilityRegistered has copy, drop {
    registry_id: ID,

    capability_id: u64,
    capability_type: u8,

    protocol_id: u64,

    registered_by: address,
    created_epoch: u64,
}

public struct CapabilityAssigned has copy, drop {
    registry_id: ID,

    assignment_id: u64,
    capability_id: u64,

    authority_id: u64,
    delegation_id: u64,

    world_id: u64,
    space_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    assigned_by: address,
    created_epoch: u64,
}

public struct CapabilityStatusChanged has copy, drop {
    registry_id: ID,
    capability_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct CapabilityAssignmentStatusChanged has copy, drop {
    registry_id: ID,
    assignment_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct CapabilityRegistryPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct CapabilityRegistryVersionChanged has copy, drop {
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
    GSOSCapabilityRegistry,
    GSOSCapabilityAdminCap,
) {
    access_control::assert_not_paused(access);

    let registry = GSOSCapabilityRegistry {
        id: object::new(ctx),
        version: REGISTRY_VERSION,
        paused: false,

        next_capability_id: 1,
        next_assignment_id: 1,

        capabilities: vector[],
        assignments: vector[],

        total_capabilities: 0,
        total_assignments: 0,

        active_capability_count: 0,
        active_assignment_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSCapabilityAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Core Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSCapabilityRegistry,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_capability_type(
    capability_type: u8,
) {
    assert!(
        capability_type >= CAPABILITY_READ
            && capability_type <= CAPABILITY_CONTROL,
        E_INVALID_CAPABILITY_TYPE,
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
   Capability Protocol Validation
   ============================================================ */

fun assert_capability_protocol(
    protocols: &GSOSProtocolRegistry,
    protocol_id: u64,
) {
    assert!(
        protocol_id != 0,
        E_INVALID_CAPABILITY_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_exists(
            protocols,
            protocol_id,
        ),
        E_INVALID_CAPABILITY_PROTOCOL,
    );

    assert!(
        protocol_registry::is_protocol_active(
            protocols,
            protocol_id,
        ),
        E_INVALID_CAPABILITY_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_family(
            protocols,
            protocol_id,
        ) == protocol_registry::family_capability(),
        E_INVALID_CAPABILITY_PROTOCOL,
    );
}


/* ============================================================
   World / Space Scope Validation
   ============================================================ */

fun assert_world_space_scope(
    worlds: &GSOSWorldSpaceRegistry,
    world_id: u64,
    space_binding_id: u64,
) {
    assert!(
        world_space::world_status(
            worlds,
            world_id,
        ) == world_space::status_active(),
        E_ASSIGNMENT_SCOPE_MISMATCH,
    );

    if (space_binding_id == 0) {
        return
    };

    assert!(
        world_space::binding_status(
            worlds,
            space_binding_id,
        ) == world_space::status_active(),
        E_ASSIGNMENT_SCOPE_MISMATCH,
    );

    assert!(
        world_space::binding_world_id(
            worlds,
            space_binding_id,
        ) == world_id,
        E_ASSIGNMENT_SCOPE_MISMATCH,
    );
}


/* ============================================================
   Capability Lookup
   ============================================================ */

fun capability_index(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
): u64 {
    let length =
        vector::length(&registry.capabilities);

    let mut i = 0;

    while (i < length) {
        let capability =
            vector::borrow(
                &registry.capabilities,
                i,
            );

        if (
            capability.capability_id
                == capability_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_CAPABILITY_NOT_FOUND
}

fun borrow_capability_internal(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
): &CapabilityDefinition {
    let index =
        capability_index(
            registry,
            capability_id,
        );

    vector::borrow(
        &registry.capabilities,
        index,
    )
}


/* ============================================================
   Assignment Lookup
   ============================================================ */

fun assignment_index(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u64 {
    let length =
        vector::length(&registry.assignments);

    let mut i = 0;

    while (i < length) {
        let assignment =
            vector::borrow(
                &registry.assignments,
                i,
            );

        if (
            assignment.assignment_id
                == assignment_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_ASSIGNMENT_NOT_FOUND
}


/* ============================================================
   Duplicate Capability Guard
   ============================================================ */

fun assert_no_duplicate_active_capability(
    registry: &GSOSCapabilityRegistry,
    capability_type: u8,
) {
    let length =
        vector::length(&registry.capabilities);

    let mut i = 0;

    while (i < length) {
        let capability =
            vector::borrow(
                &registry.capabilities,
                i,
            );

        let duplicate =
            capability.status == STATUS_ACTIVE
                && capability.capability_type
                    == capability_type;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_CAPABILITY,
        );

        i = i + 1;
    };
}


/* ============================================================
   Duplicate Assignment Guard
   ============================================================ */

fun assert_no_duplicate_active_assignment(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
    authority_id: u64,
    delegation_id: u64,
    world_id: u64,
    space_binding_id: u64,
) {
    let length =
        vector::length(&registry.assignments);

    let mut i = 0;

    while (i < length) {
        let assignment =
            vector::borrow(
                &registry.assignments,
                i,
            );

        let duplicate =
            assignment.status == STATUS_ACTIVE
                && assignment.capability_id
                    == capability_id
                && assignment.authority_id
                    == authority_id
                && assignment.delegation_id
                    == delegation_id
                && assignment.world_id
                    == world_id
                && assignment.space_binding_id
                    == space_binding_id;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_ASSIGNMENT,
        );

        i = i + 1;
    };
}


/* ============================================================
   Capability → Authority Level Mapping
   ============================================================ */

fun required_authority_type(
    capability_type: u8,
): u8 {
    if (capability_type == CAPABILITY_READ) {
        return agent_authority::authority_observe()
    };

    if (
        capability_type == CAPABILITY_WRITE
            || capability_type == CAPABILITY_ENTER
    ) {
        return agent_authority::authority_interact()
    };

    if (
        capability_type == CAPABILITY_EXECUTE
            || capability_type == CAPABILITY_TRADE
    ) {
        return agent_authority::authority_execute()
    };

    agent_authority::authority_delegate()
}


/* ============================================================
   Register Capability
   ============================================================ */

public fun register_capability(
    access: &AccessControl,
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

    protocols: &GSOSProtocolRegistry,

    capability_type: u8,
    capability_name: vector<u8>,
    protocol_id: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_valid_capability_type(
        capability_type,
    );

    assert!(
        !vector::is_empty(&capability_name),
        E_EMPTY_CAPABILITY_NAME,
    );

    assert_capability_protocol(
        protocols,
        protocol_id,
    );

    assert_no_duplicate_active_capability(
        registry,
        capability_type,
    );

    let capability_id =
        registry.next_capability_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.capabilities,
        CapabilityDefinition {
            capability_id,
            capability_type,
            capability_name,
            protocol_id,
            status: STATUS_ACTIVE,
            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_capability_id =
        capability_id + 1;

    registry.total_capabilities =
        registry.total_capabilities + 1;

    registry.active_capability_count =
        registry.active_capability_count + 1;

    event::emit(CapabilityRegistered {
        registry_id: object::id(registry),
        capability_id,
        capability_type,
        protocol_id,
        registered_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    capability_id
}


/* ============================================================
   Assign Capability To Authority
   ============================================================ */

public fun assign_to_authority(
    access: &AccessControl,
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

    authorities: &GSOSAgentAuthorityRegistry,
    worlds: &GSOSWorldSpaceRegistry,

    capability_id: u64,
    authority_id: u64,

    world_id: u64,
    space_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    current_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    let capability =
        borrow_capability_internal(
            registry,
            capability_id,
        );

    assert!(
        capability.status == STATUS_ACTIVE,
        E_CAPABILITY_NOT_FOUND,
    );

    assert!(
        agent_authority::authority_status(
            authorities,
            authority_id,
        ) == agent_authority::status_active(),
        E_INVALID_AUTHORITY_ID,
    );

    assert!(
        agent_authority::is_authority_valid(
            authorities,
            authority_id,
            current_epoch,
        ),
        E_INVALID_AUTHORITY_ID,
    );

    assert!(
        agent_authority::authority_world_id(
            authorities,
            authority_id,
        ) == world_id,
        E_ASSIGNMENT_SCOPE_MISMATCH,
    );

    let authority_space =
        agent_authority::authority_space_binding_id(
            authorities,
            authority_id,
        );

    if (authority_space != 0) {
        assert!(
            space_binding_id == authority_space,
            E_ASSIGNMENT_SCOPE_MISMATCH,
        );
    };

    assert_world_space_scope(
        worlds,
        world_id,
        space_binding_id,
    );

    assert!(
        agent_authority::authority_type(
            authorities,
            authority_id,
        ) >= required_authority_type(
            capability.capability_type,
        ),
        E_ASSIGNMENT_EXCEEDS_AUTHORITY,
    );

    assert_validity_range(
        valid_from_epoch,
        valid_until_epoch,
    );

    let authority_valid_from =
        agent_authority::authority_valid_from_epoch(
            authorities,
            authority_id,
        );

    let authority_valid_until =
        agent_authority::authority_valid_until_epoch(
            authorities,
            authority_id,
        );

    assert!(
        valid_from_epoch >= authority_valid_from,
        E_INVALID_VALIDITY_RANGE,
    );

    if (authority_valid_until != 0) {
        assert!(
            valid_until_epoch != 0
                && valid_until_epoch
                    <= authority_valid_until,
            E_INVALID_VALIDITY_RANGE,
        );
    };

    assert_no_duplicate_active_assignment(
        registry,
        capability_id,
        authority_id,
        0,
        world_id,
        space_binding_id,
    );

    let assignment_id =
        registry.next_assignment_id;

    let created_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.assignments,
        CapabilityAssignment {
            assignment_id,

            capability_id,

            authority_id,
            delegation_id: 0,

            world_id,
            space_binding_id,

            valid_from_epoch,
            valid_until_epoch,

            status: STATUS_ACTIVE,

            created_epoch,
            updated_epoch: created_epoch,
        },
    );

    registry.next_assignment_id =
        assignment_id + 1;

    registry.total_assignments =
        registry.total_assignments + 1;

    registry.active_assignment_count =
        registry.active_assignment_count + 1;

    event::emit(CapabilityAssigned {
        registry_id: object::id(registry),

        assignment_id,
        capability_id,

        authority_id,
        delegation_id: 0,

        world_id,
        space_binding_id,

        valid_from_epoch,
        valid_until_epoch,

        assigned_by: tx_context::sender(ctx),
        created_epoch,
    });

    assignment_id
}


/* ============================================================
   Assign Capability To Delegation
   ============================================================ */

public fun assign_to_delegation(
    access: &AccessControl,
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

    authorities: &GSOSAgentAuthorityRegistry,
    worlds: &GSOSWorldSpaceRegistry,

    capability_id: u64,
    delegation_id: u64,

    world_id: u64,
    space_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    current_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    let capability =
        borrow_capability_internal(
            registry,
            capability_id,
        );

    assert!(
        capability.status == STATUS_ACTIVE,
        E_CAPABILITY_NOT_FOUND,
    );

    assert!(
        agent_authority::delegation_status(
            authorities,
            delegation_id,
        ) == agent_authority::status_active(),
        E_INVALID_DELEGATION_ID,
    );

    assert!(
        agent_authority::is_delegation_valid(
            authorities,
            delegation_id,
            current_epoch,
        ),
        E_INVALID_DELEGATION_ID,
    );

    let parent_authority_id =
        agent_authority::delegation_parent_authority_id(
            authorities,
            delegation_id,
        );

    assert!(
        agent_authority::delegation_world_id(
            authorities,
            delegation_id,
        ) == world_id,
        E_ASSIGNMENT_SCOPE_MISMATCH,
    );

    let delegation_space =
        agent_authority::delegation_space_binding_id(
            authorities,
            delegation_id,
        );

    if (delegation_space != 0) {
        assert!(
            space_binding_id == delegation_space,
            E_ASSIGNMENT_SCOPE_MISMATCH,
        );
    };

    assert_world_space_scope(
        worlds,
        world_id,
        space_binding_id,
    );

    assert!(
        agent_authority::delegation_authority_type(
            authorities,
            delegation_id,
        ) >= required_authority_type(
            capability.capability_type,
        ),
        E_ASSIGNMENT_EXCEEDS_AUTHORITY,
    );

    assert_validity_range(
        valid_from_epoch,
        valid_until_epoch,
    );

    let delegation_valid_from =
        agent_authority::delegation_valid_from_epoch(
            authorities,
            delegation_id,
        );

    let delegation_valid_until =
        agent_authority::delegation_valid_until_epoch(
            authorities,
            delegation_id,
        );

    assert!(
        valid_from_epoch >= delegation_valid_from,
        E_INVALID_VALIDITY_RANGE,
    );

    if (delegation_valid_until != 0) {
        assert!(
            valid_until_epoch != 0
                && valid_until_epoch
                    <= delegation_valid_until,
            E_INVALID_VALIDITY_RANGE,
        );
    };

    assert_no_duplicate_active_assignment(
        registry,
        capability_id,
        0,
        delegation_id,
        world_id,
        space_binding_id,
    );

    let assignment_id =
        registry.next_assignment_id;

    let created_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.assignments,
        CapabilityAssignment {
            assignment_id,

            capability_id,

            authority_id: 0,
            delegation_id,

            world_id,
            space_binding_id,

            valid_from_epoch,
            valid_until_epoch,

            status: STATUS_ACTIVE,

            created_epoch,
            updated_epoch: created_epoch,
        },
    );

    registry.next_assignment_id =
        assignment_id + 1;

    registry.total_assignments =
        registry.total_assignments + 1;

    registry.active_assignment_count =
        registry.active_assignment_count + 1;

    event::emit(CapabilityAssigned {
        registry_id: object::id(registry),

        assignment_id,
        capability_id,

        authority_id: 0,
        delegation_id,

        world_id,
        space_binding_id,

        valid_from_epoch,
        valid_until_epoch,

        assigned_by: tx_context::sender(ctx),
        created_epoch,
    });

    assignment_id
}


/* ============================================================
   Internal Assignment Borrow
   ============================================================ */

fun borrow_assignment_internal(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): &CapabilityAssignment {
    let index =
        assignment_index(
            registry,
            assignment_id,
        );

    vector::borrow(
        &registry.assignments,
        index,
    )
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun version(
    registry: &GSOSCapabilityRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSCapabilityRegistry,
): bool {
    registry.paused
}

public fun total_capabilities(
    registry: &GSOSCapabilityRegistry,
): u64 {
    registry.total_capabilities
}

public fun total_assignments(
    registry: &GSOSCapabilityRegistry,
): u64 {
    registry.total_assignments
}

public fun active_capability_count(
    registry: &GSOSCapabilityRegistry,
): u64 {
    registry.active_capability_count
}

public fun active_assignment_count(
    registry: &GSOSCapabilityRegistry,
): u64 {
    registry.active_assignment_count
}


/* ============================================================
   Capability Read API
   ============================================================ */

public fun capability_type(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
): u8 {
    borrow_capability_internal(
        registry,
        capability_id,
    ).capability_type
}

public fun capability_name(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
): &vector<u8> {
    &borrow_capability_internal(
        registry,
        capability_id,
    ).capability_name
}

public fun capability_protocol_id(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
): u64 {
    borrow_capability_internal(
        registry,
        capability_id,
    ).protocol_id
}

public fun capability_status(
    registry: &GSOSCapabilityRegistry,
    capability_id: u64,
): u8 {
    borrow_capability_internal(
        registry,
        capability_id,
    ).status
}


/* ============================================================
   Assignment Read API
   ============================================================ */

public fun assignment_capability_id(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u64 {
    borrow_assignment_internal(
        registry,
        assignment_id,
    ).capability_id
}

public fun assignment_authority_id(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u64 {
    borrow_assignment_internal(
        registry,
        assignment_id,
    ).authority_id
}

public fun assignment_delegation_id(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u64 {
    borrow_assignment_internal(
        registry,
        assignment_id,
    ).delegation_id
}

public fun assignment_world_id(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u64 {
    borrow_assignment_internal(
        registry,
        assignment_id,
    ).world_id
}

public fun assignment_space_binding_id(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u64 {
    borrow_assignment_internal(
        registry,
        assignment_id,
    ).space_binding_id
}

public fun assignment_status(
    registry: &GSOSCapabilityRegistry,
    assignment_id: u64,
): u8 {
    borrow_assignment_internal(
        registry,
        assignment_id,
    ).status
}


/* ============================================================
   Constant Accessors
   ============================================================ */

public fun capability_read(): u8 {
    CAPABILITY_READ
}

public fun capability_write(): u8 {
    CAPABILITY_WRITE
}

public fun capability_execute(): u8 {
    CAPABILITY_EXECUTE
}

public fun capability_enter(): u8 {
    CAPABILITY_ENTER
}

public fun capability_trade(): u8 {
    CAPABILITY_TRADE
}

public fun capability_control(): u8 {
    CAPABILITY_CONTROL
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
   Runtime Assignment Validity
   ============================================================ */

public fun is_assignment_valid(
    registry: &GSOSCapabilityRegistry,
    authorities: &GSOSAgentAuthorityRegistry,

    assignment_id: u64,
    current_epoch: u64,
): bool {
    if (registry.paused) {
        return false
    };

    let assignment =
        borrow_assignment_internal(
            registry,
            assignment_id,
        );

    if (assignment.status != STATUS_ACTIVE) {
        return false
    };

    let capability =
        borrow_capability_internal(
            registry,
            assignment.capability_id,
        );

    if (capability.status != STATUS_ACTIVE) {
        return false
    };

    let time_valid =
        current_epoch >= assignment.valid_from_epoch
            && (
                assignment.valid_until_epoch == 0
                    || current_epoch
                        <= assignment.valid_until_epoch
            );

    if (!time_valid) {
        return false
    };

    if (assignment.authority_id != 0) {
        return agent_authority::is_authority_valid(
            authorities,
            assignment.authority_id,
            current_epoch,
        )
    };

    if (assignment.delegation_id != 0) {
        return agent_authority::is_delegation_valid(
            authorities,
            assignment.delegation_id,
            current_epoch,
        )
    };

    false
}


/* ============================================================
   Mutable Lookup
   ============================================================ */

fun borrow_capability_internal_mut(
    registry: &mut GSOSCapabilityRegistry,
    capability_id: u64,
): &mut CapabilityDefinition {
    let index =
        capability_index(
            registry,
            capability_id,
        );

    vector::borrow_mut(
        &mut registry.capabilities,
        index,
    )
}

fun borrow_assignment_internal_mut(
    registry: &mut GSOSCapabilityRegistry,
    assignment_id: u64,
): &mut CapabilityAssignment {
    let index =
        assignment_index(
            registry,
            assignment_id,
        );

    vector::borrow_mut(
        &mut registry.assignments,
        index,
    )
}


/* ============================================================
   Capability Status Lifecycle
   ============================================================ */

public fun set_capability_status(
    access: &AccessControl,
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

    capability_id: u64,
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
        let capability =
            borrow_capability_internal_mut(
                registry,
                capability_id,
            );

        previous_status = capability.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        capability.status = new_status;
        capability.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_capability_count =
            registry.active_capability_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_capability_count =
            registry.active_capability_count + 1;
    };

    event::emit(CapabilityStatusChanged {
        registry_id: object::id(registry),
        capability_id,

        previous_status,
        new_status,

        changed_by: tx_context::sender(ctx),
        updated_epoch: current_epoch,
    });
}


/* ============================================================
   Assignment Status Lifecycle
   ============================================================ */

public fun set_assignment_status(
    access: &AccessControl,
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

    assignment_id: u64,
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
        let assignment =
            borrow_assignment_internal_mut(
                registry,
                assignment_id,
            );

        previous_status = assignment.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        assignment.status = new_status;
        assignment.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_assignment_count =
            registry.active_assignment_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_assignment_count =
            registry.active_assignment_count + 1;
    };

    event::emit(CapabilityAssignmentStatusChanged {
        registry_id: object::id(registry),
        assignment_id,

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
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

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

    event::emit(CapabilityRegistryPauseChanged {
        registry_id: object::id(registry),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Registry Version Control
   ============================================================ */

public fun set_version(
    access: &AccessControl,
    registry: &mut GSOSCapabilityRegistry,
    admin_cap: &GSOSCapabilityAdminCap,

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

    event::emit(CapabilityRegistryVersionChanged {
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
    registry: GSOSCapabilityRegistry,
) {
    let GSOSCapabilityRegistry {
        id,
        version: _,
        paused: _,
        next_capability_id: _,
        next_assignment_id: _,
        capabilities,
        assignments,
        total_capabilities: _,
        total_assignments: _,
        active_capability_count: _,
        active_assignment_count: _,
    } = registry;

    let mut capabilities = capabilities;

    while (!vector::is_empty(&capabilities)) {
        let capability =
            vector::pop_back(&mut capabilities);

        let CapabilityDefinition {
            capability_id: _,
            capability_type: _,
            capability_name: _,
            protocol_id: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = capability;
    };

    vector::destroy_empty(capabilities);

    let mut assignments = assignments;

    while (!vector::is_empty(&assignments)) {
        let assignment =
            vector::pop_back(&mut assignments);

        let CapabilityAssignment {
            assignment_id: _,
            capability_id: _,
            authority_id: _,
            delegation_id: _,
            world_id: _,
            space_binding_id: _,
            valid_from_epoch: _,
            valid_until_epoch: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = assignment;
    };

    vector::destroy_empty(assignments);

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSCapabilityAdminCap,
) {
    let GSOSCapabilityAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}


/* ============================================================
   Registry Object ID
   Stage 11 Part 10 Governance Integration
   ============================================================ */

public fun registry_id(
    registry: &GSOSCapabilityRegistry,
): ID {
    object::id(registry)
}
