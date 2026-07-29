module tobmate_gsos::gsos_entry_authorization;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_gsos::gsos_identity_binding::{
    Self as identity_binding,
    GSOSIdentityRegistry,
};

use tobmate_gsos::gsos_protocol_registry::{
    Self as protocol_registry,
    GSOSProtocolRegistry,
};

use tobmate_gsos::gsos_world_space_registry::{
    Self as world_space,
    GSOSWorldSpaceRegistry,
};


/* ============================================================
   Stage 11 Part 5
   GSOS Entry Authorization
   Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Entry Policy Types
   ============================================================ */

const POLICY_PUBLIC: u8 = 1;
const POLICY_IDENTITY: u8 = 2;
const POLICY_ALLOWLIST: u8 = 3;
const POLICY_CAPABILITY: u8 = 4;
const POLICY_DELEGATED: u8 = 5;


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
const E_INVALID_POLICY_TYPE: u64 = 2;
const E_INVALID_WORLD_ID: u64 = 3;
const E_INVALID_SPACE_BINDING_ID: u64 = 4;
const E_INVALID_ENTRY_PROTOCOL: u64 = 5;
const E_INVALID_IDENTITY_BINDING: u64 = 6;
const E_INVALID_VALIDITY_RANGE: u64 = 7;
const E_POLICY_NOT_FOUND: u64 = 8;
const E_GRANT_NOT_FOUND: u64 = 9;
const E_DUPLICATE_ACTIVE_POLICY: u64 = 10;
const E_DUPLICATE_ACTIVE_GRANT: u64 = 11;
const E_POLICY_INACTIVE: u64 = 12;
const E_GRANT_INACTIVE: u64 = 13;
const E_GRANT_NOT_YET_VALID: u64 = 14;
const E_GRANT_EXPIRED: u64 = 15;
const E_STATE_UNCHANGED: u64 = 16;
const E_ALREADY_REVOKED: u64 = 17;
const E_VERSION_UNCHANGED: u64 = 18;
const E_ADMIN_CAP_MISMATCH: u64 = 19;


/* ============================================================
   Entry Authorization Registry
   ============================================================ */

public struct GSOSEntryAuthorizationRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_policy_id: u64,
    next_grant_id: u64,

    policies: vector<EntryPolicy>,
    grants: vector<EntryGrant>,

    total_policies: u64,
    total_grants: u64,

    active_policy_count: u64,
    active_grant_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSEntryAuthorizationAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Entry Policy

   space_binding_id == 0 means world-level policy.
   Non-zero space_binding_id means a specific GSOS space binding.
   ============================================================ */

public struct EntryPolicy has store {
    policy_id: u64,

    world_id: u64,
    space_binding_id: u64,

    entry_protocol_id: u64,
    policy_type: u8,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Entry Grant

   valid_until_epoch == 0 means no fixed expiry.
   ============================================================ */

public struct EntryGrant has store {
    grant_id: u64,

    policy_id: u64,
    identity_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct EntryPolicyCreated has copy, drop {
    registry_id: ID,

    policy_id: u64,
    world_id: u64,
    space_binding_id: u64,

    entry_protocol_id: u64,
    policy_type: u8,

    created_by: address,
    created_epoch: u64,
}

public struct EntryGrantCreated has copy, drop {
    registry_id: ID,

    grant_id: u64,
    policy_id: u64,
    identity_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    created_by: address,
    created_epoch: u64,
}

public struct EntryPolicyStatusChanged has copy, drop {
    registry_id: ID,
    policy_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct EntryGrantStatusChanged has copy, drop {
    registry_id: ID,
    grant_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct EntryAuthorizationPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct EntryAuthorizationVersionChanged has copy, drop {
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
    GSOSEntryAuthorizationRegistry,
    GSOSEntryAuthorizationAdminCap,
) {
    access_control::assert_not_paused(access);

    let registry = GSOSEntryAuthorizationRegistry {
        id: object::new(ctx),

        version: REGISTRY_VERSION,
        paused: false,

        next_policy_id: 1,
        next_grant_id: 1,

        policies: vector[],
        grants: vector[],

        total_policies: 0,
        total_grants: 0,

        active_policy_count: 0,
        active_grant_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSEntryAuthorizationAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Core Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSEntryAuthorizationRegistry,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_policy_type(
    policy_type: u8,
) {
    assert!(
        policy_type >= POLICY_PUBLIC
            && policy_type <= POLICY_DELEGATED,
        E_INVALID_POLICY_TYPE,
    );
}


/* ============================================================
   World / Space Validation
   ============================================================ */

fun assert_world_active(
    worlds: &GSOSWorldSpaceRegistry,
    world_id: u64,
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
}

fun assert_space_binding_active_for_world(
    worlds: &GSOSWorldSpaceRegistry,
    world_id: u64,
    space_binding_id: u64,
) {
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
        E_INVALID_SPACE_BINDING_ID,
    );
}


/* ============================================================
   Entry Protocol Validation
   ============================================================ */

fun assert_entry_protocol(
    protocols: &GSOSProtocolRegistry,
    protocol_id: u64,
) {
    assert!(
        protocol_id != 0,
        E_INVALID_ENTRY_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_exists(
            protocols,
            protocol_id,
        ),
        E_INVALID_ENTRY_PROTOCOL,
    );

    assert!(
        protocol_registry::is_protocol_active(
            protocols,
            protocol_id,
        ),
        E_INVALID_ENTRY_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_family(
            protocols,
            protocol_id,
        ) == protocol_registry::family_entry(),
        E_INVALID_ENTRY_PROTOCOL,
    );
}

fun assert_entry_protocol_matches_scope(
    worlds: &GSOSWorldSpaceRegistry,
    world_id: u64,
    space_binding_id: u64,
    entry_protocol_id: u64,
) {
    if (space_binding_id == 0) {
        assert!(
            world_space::world_entry_protocol_id(
                worlds,
                world_id,
            ) == entry_protocol_id,
            E_INVALID_ENTRY_PROTOCOL,
        );

        return
    };

    assert!(
        world_space::binding_entry_protocol_id(
            worlds,
            space_binding_id,
        ) == entry_protocol_id,
        E_INVALID_ENTRY_PROTOCOL,
    );
}


/* ============================================================
   Identity Validation
   ============================================================ */

fun assert_identity_active(
    identities: &GSOSIdentityRegistry,
    identity_binding_id: u64,
) {
    assert!(
        identity_binding_id != 0,
        E_INVALID_IDENTITY_BINDING,
    );

    assert!(
        identity_binding::binding_status(
            identities,
            identity_binding_id,
        ) == identity_binding::status_active(),
        E_INVALID_IDENTITY_BINDING,
    );
}


/* ============================================================
   Validity Range
   ============================================================ */

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
   Policy Lookup
   ============================================================ */

fun policy_index(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): u64 {
    let length = vector::length(&registry.policies);
    let mut i = 0;

    while (i < length) {
        let policy =
            vector::borrow(
                &registry.policies,
                i,
            );

        if (policy.policy_id == policy_id) {
            return i
        };

        i = i + 1;
    };

    abort E_POLICY_NOT_FOUND
}

fun borrow_policy_internal(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): &EntryPolicy {
    let index =
        policy_index(
            registry,
            policy_id,
        );

    vector::borrow(
        &registry.policies,
        index,
    )
}


/* ============================================================
   Grant Lookup
   ============================================================ */

fun grant_index(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): u64 {
    let length = vector::length(&registry.grants);
    let mut i = 0;

    while (i < length) {
        let grant =
            vector::borrow(
                &registry.grants,
                i,
            );

        if (grant.grant_id == grant_id) {
            return i
        };

        i = i + 1;
    };

    abort E_GRANT_NOT_FOUND
}

fun borrow_grant_internal(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): &EntryGrant {
    let index =
        grant_index(
            registry,
            grant_id,
        );

    vector::borrow(
        &registry.grants,
        index,
    )
}


/* ============================================================
   Duplicate Policy Detection
   ============================================================ */

fun assert_no_duplicate_active_policy(
    registry: &GSOSEntryAuthorizationRegistry,
    world_id: u64,
    space_binding_id: u64,
    policy_type: u8,
) {
    let length = vector::length(&registry.policies);
    let mut i = 0;

    while (i < length) {
        let policy =
            vector::borrow(
                &registry.policies,
                i,
            );

        let duplicate =
            policy.status == STATUS_ACTIVE
                && policy.world_id == world_id
                && policy.space_binding_id
                    == space_binding_id
                && policy.policy_type == policy_type;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_POLICY,
        );

        i = i + 1;
    };
}


/* ============================================================
   Duplicate Grant Detection
   ============================================================ */

fun assert_no_duplicate_active_grant(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
    identity_binding_id: u64,
) {
    let length = vector::length(&registry.grants);
    let mut i = 0;

    while (i < length) {
        let grant =
            vector::borrow(
                &registry.grants,
                i,
            );

        let duplicate =
            grant.status == STATUS_ACTIVE
                && grant.policy_id == policy_id
                && grant.identity_binding_id
                    == identity_binding_id;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_GRANT,
        );

        i = i + 1;
    };
}


/* ============================================================
   Create Entry Policy
   ============================================================ */

public fun create_policy(
    access: &AccessControl,
    registry: &mut GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,

    worlds: &GSOSWorldSpaceRegistry,
    protocols: &GSOSProtocolRegistry,

    world_id: u64,
    space_binding_id: u64,
    entry_protocol_id: u64,
    policy_type: u8,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_valid_policy_type(
        policy_type,
    );

    assert_world_active(
        worlds,
        world_id,
    );

    assert_space_binding_active_for_world(
        worlds,
        world_id,
        space_binding_id,
    );

    assert_entry_protocol(
        protocols,
        entry_protocol_id,
    );

    assert_entry_protocol_matches_scope(
        worlds,
        world_id,
        space_binding_id,
        entry_protocol_id,
    );

    assert_no_duplicate_active_policy(
        registry,
        world_id,
        space_binding_id,
        policy_type,
    );

    let policy_id =
        registry.next_policy_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.policies,
        EntryPolicy {
            policy_id,

            world_id,
            space_binding_id,

            entry_protocol_id,
            policy_type,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_policy_id =
        policy_id + 1;

    registry.total_policies =
        registry.total_policies + 1;

    registry.active_policy_count =
        registry.active_policy_count + 1;

    event::emit(EntryPolicyCreated {
        registry_id: object::id(registry),

        policy_id,
        world_id,
        space_binding_id,

        entry_protocol_id,
        policy_type,

        created_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    policy_id
}


/* ============================================================
   Create Entry Grant
   ============================================================ */

public fun create_grant(
    access: &AccessControl,
    registry: &mut GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,

    identities: &GSOSIdentityRegistry,

    policy_id: u64,
    identity_binding_id: u64,

    valid_from_epoch: u64,
    valid_until_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    {
        let policy =
            borrow_policy_internal(
                registry,
                policy_id,
            );

        assert!(
            policy.status == STATUS_ACTIVE,
            E_POLICY_INACTIVE,
        );
    };

    assert_identity_active(
        identities,
        identity_binding_id,
    );

    assert_validity_range(
        valid_from_epoch,
        valid_until_epoch,
    );

    assert_no_duplicate_active_grant(
        registry,
        policy_id,
        identity_binding_id,
    );

    let grant_id =
        registry.next_grant_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.grants,
        EntryGrant {
            grant_id,

            policy_id,
            identity_binding_id,

            valid_from_epoch,
            valid_until_epoch,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_grant_id =
        grant_id + 1;

    registry.total_grants =
        registry.total_grants + 1;

    registry.active_grant_count =
        registry.active_grant_count + 1;

    event::emit(EntryGrantCreated {
        registry_id: object::id(registry),

        grant_id,
        policy_id,
        identity_binding_id,

        valid_from_epoch,
        valid_until_epoch,

        created_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    grant_id
}


/* ============================================================
   Mutable Lookup
   ============================================================ */

fun borrow_policy_internal_mut(
    registry: &mut GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): &mut EntryPolicy {
    let index =
        policy_index(
            registry,
            policy_id,
        );

    vector::borrow_mut(
        &mut registry.policies,
        index,
    )
}

fun borrow_grant_internal_mut(
    registry: &mut GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): &mut EntryGrant {
    let index =
        grant_index(
            registry,
            grant_id,
        );

    vector::borrow_mut(
        &mut registry.grants,
        index,
    )
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun version(
    registry: &GSOSEntryAuthorizationRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSEntryAuthorizationRegistry,
): bool {
    registry.paused
}

public fun total_policies(
    registry: &GSOSEntryAuthorizationRegistry,
): u64 {
    registry.total_policies
}

public fun total_grants(
    registry: &GSOSEntryAuthorizationRegistry,
): u64 {
    registry.total_grants
}

public fun active_policy_count(
    registry: &GSOSEntryAuthorizationRegistry,
): u64 {
    registry.active_policy_count
}

public fun active_grant_count(
    registry: &GSOSEntryAuthorizationRegistry,
): u64 {
    registry.active_grant_count
}


/* ============================================================
   Policy Read API
   ============================================================ */

public fun policy_world_id(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): u64 {
    borrow_policy_internal(
        registry,
        policy_id,
    ).world_id
}

public fun policy_space_binding_id(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): u64 {
    borrow_policy_internal(
        registry,
        policy_id,
    ).space_binding_id
}

public fun policy_entry_protocol_id(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): u64 {
    borrow_policy_internal(
        registry,
        policy_id,
    ).entry_protocol_id
}

public fun policy_type(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): u8 {
    borrow_policy_internal(
        registry,
        policy_id,
    ).policy_type
}

public fun policy_status(
    registry: &GSOSEntryAuthorizationRegistry,
    policy_id: u64,
): u8 {
    borrow_policy_internal(
        registry,
        policy_id,
    ).status
}


/* ============================================================
   Grant Read API
   ============================================================ */

public fun grant_policy_id(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): u64 {
    borrow_grant_internal(
        registry,
        grant_id,
    ).policy_id
}

public fun grant_identity_binding_id(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): u64 {
    borrow_grant_internal(
        registry,
        grant_id,
    ).identity_binding_id
}

public fun grant_valid_from_epoch(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): u64 {
    borrow_grant_internal(
        registry,
        grant_id,
    ).valid_from_epoch
}

public fun grant_valid_until_epoch(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): u64 {
    borrow_grant_internal(
        registry,
        grant_id,
    ).valid_until_epoch
}

public fun grant_status(
    registry: &GSOSEntryAuthorizationRegistry,
    grant_id: u64,
): u8 {
    borrow_grant_internal(
        registry,
        grant_id,
    ).status
}


/* ============================================================
   Constant Accessors
   ============================================================ */

public fun policy_public(): u8 {
    POLICY_PUBLIC
}

public fun policy_identity(): u8 {
    POLICY_IDENTITY
}

public fun policy_allowlist(): u8 {
    POLICY_ALLOWLIST
}

public fun policy_capability(): u8 {
    POLICY_CAPABILITY
}

public fun policy_delegated(): u8 {
    POLICY_DELEGATED
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
   Entry Authorization Decision

   PUBLIC:
     Active policy is sufficient.

   Other policy types:
     Active identity-specific grant is required.
   ============================================================ */

public fun is_entry_authorized(
    registry: &GSOSEntryAuthorizationRegistry,
    identities: &GSOSIdentityRegistry,

    policy_id: u64,
    identity_binding_id: u64,

    current_epoch: u64,
): bool {
    if (registry.paused) {
        return false
    };

    let policy =
        borrow_policy_internal(
            registry,
            policy_id,
        );

    if (policy.status != STATUS_ACTIVE) {
        return false
    };

    if (policy.policy_type == POLICY_PUBLIC) {
        return true
    };

    if (identity_binding_id == 0) {
        return false
    };

    if (
        identity_binding::binding_status(
            identities,
            identity_binding_id,
        ) != identity_binding::status_active()
    ) {
        return false
    };

    let length = vector::length(&registry.grants);
    let mut i = 0;

    while (i < length) {
        let grant =
            vector::borrow(
                &registry.grants,
                i,
            );

        let valid_time =
            current_epoch >= grant.valid_from_epoch
                && (
                    grant.valid_until_epoch == 0
                        || current_epoch
                            <= grant.valid_until_epoch
                );

        if (
            grant.status == STATUS_ACTIVE
                && grant.policy_id == policy_id
                && grant.identity_binding_id
                    == identity_binding_id
                && valid_time
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Assert Entry Authorized
   ============================================================ */

public fun assert_entry_authorized(
    registry: &GSOSEntryAuthorizationRegistry,
    identities: &GSOSIdentityRegistry,

    policy_id: u64,
    identity_binding_id: u64,

    current_epoch: u64,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );

    let policy =
        borrow_policy_internal(
            registry,
            policy_id,
        );

    assert!(
        policy.status == STATUS_ACTIVE,
        E_POLICY_INACTIVE,
    );

    if (policy.policy_type == POLICY_PUBLIC) {
        return
    };

    assert_identity_active(
        identities,
        identity_binding_id,
    );

    let length = vector::length(&registry.grants);
    let mut i = 0;

    while (i < length) {
        let grant =
            vector::borrow(
                &registry.grants,
                i,
            );

        if (
            grant.policy_id == policy_id
                && grant.identity_binding_id
                    == identity_binding_id
                && grant.status == STATUS_ACTIVE
        ) {
            assert!(
                current_epoch >= grant.valid_from_epoch,
                E_GRANT_NOT_YET_VALID,
            );

            assert!(
                grant.valid_until_epoch == 0
                    || current_epoch
                        <= grant.valid_until_epoch,
                E_GRANT_EXPIRED,
            );

            return
        };

        i = i + 1;
    };

    abort E_GRANT_INACTIVE
}


/* ============================================================
   Policy Status Lifecycle
   ============================================================ */

public fun set_policy_status(
    access: &AccessControl,
    registry: &mut GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,

    policy_id: u64,
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
        let policy =
            borrow_policy_internal_mut(
                registry,
                policy_id,
            );

        previous_status = policy.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        policy.status = new_status;
        policy.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_policy_count =
            registry.active_policy_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_policy_count =
            registry.active_policy_count + 1;
    };

    event::emit(EntryPolicyStatusChanged {
        registry_id: object::id(registry),
        policy_id,

        previous_status,
        new_status,

        changed_by: tx_context::sender(ctx),
        updated_epoch: current_epoch,
    });
}


/* ============================================================
   Grant Status Lifecycle
   ============================================================ */

public fun set_grant_status(
    access: &AccessControl,
    registry: &mut GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,

    grant_id: u64,
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
        let grant =
            borrow_grant_internal_mut(
                registry,
                grant_id,
            );

        previous_status = grant.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        grant.status = new_status;
        grant.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_grant_count =
            registry.active_grant_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_grant_count =
            registry.active_grant_count + 1;
    };

    event::emit(EntryGrantStatusChanged {
        registry_id: object::id(registry),
        grant_id,

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
    registry: &mut GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,

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

    event::emit(EntryAuthorizationPauseChanged {
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
    registry: &mut GSOSEntryAuthorizationRegistry,
    admin_cap: &GSOSEntryAuthorizationAdminCap,

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

    event::emit(EntryAuthorizationVersionChanged {
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
    registry: GSOSEntryAuthorizationRegistry,
) {
    let GSOSEntryAuthorizationRegistry {
        id,
        version: _,
        paused: _,
        next_policy_id: _,
        next_grant_id: _,
        policies,
        grants,
        total_policies: _,
        total_grants: _,
        active_policy_count: _,
        active_grant_count: _,
    } = registry;

    let mut policies = policies;

    while (!vector::is_empty(&policies)) {
        let policy =
            vector::pop_back(&mut policies);

        let EntryPolicy {
            policy_id: _,
            world_id: _,
            space_binding_id: _,
            entry_protocol_id: _,
            policy_type: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = policy;
    };

    vector::destroy_empty(policies);

    let mut grants = grants;

    while (!vector::is_empty(&grants)) {
        let grant =
            vector::pop_back(&mut grants);

        let EntryGrant {
            grant_id: _,
            policy_id: _,
            identity_binding_id: _,
            valid_from_epoch: _,
            valid_until_epoch: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = grant;
    };

    vector::destroy_empty(grants);

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSEntryAuthorizationAdminCap,
) {
    let GSOSEntryAuthorizationAdminCap {
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
    registry: &GSOSEntryAuthorizationRegistry,
): ID {
    object::id(registry)
}
