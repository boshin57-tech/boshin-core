module tobmate_gsos::gsos_avatar_identity_binding;

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
   Stage 11 Part 6
   GSOS Avatar Identity Binding
   Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Avatar Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_REVOKED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_IDENTITY_BINDING: u64 = 2;
const E_IDENTITY_NOT_AVATAR: u64 = 3;
const E_INVALID_WORLD_ID: u64 = 4;
const E_INVALID_SPACE_BINDING_ID: u64 = 5;
const E_WORLD_SPACE_MISMATCH: u64 = 6;
const E_INVALID_AVATAR_PROTOCOL: u64 = 7;
const E_DUPLICATE_ACTIVE_AVATAR: u64 = 8;
const E_AVATAR_NOT_FOUND: u64 = 9;
const E_STATE_UNCHANGED: u64 = 10;
const E_ALREADY_REVOKED: u64 = 11;
const E_VERSION_UNCHANGED: u64 = 12;
const E_ADMIN_CAP_MISMATCH: u64 = 13;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSAvatarBindingRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_avatar_id: u64,

    avatars: vector<GSOSAvatarBinding>,

    total_created: u64,
    total_revoked: u64,
    active_avatar_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSAvatarBindingAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Avatar Binding

   identity_binding_id remains canonical in
   gsos_identity_binding.

   world_id / space_binding_id remain canonical in
   gsos_world_space_registry.

   avatar_protocol_id remains canonical in
   gsos_protocol_registry.
   ============================================================ */

public struct GSOSAvatarBinding has store {
    avatar_id: u64,

    identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    avatar_protocol_id: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct GSOSAvatarBound has copy, drop {
    registry_id: ID,

    avatar_id: u64,
    identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    avatar_protocol_id: u64,

    bound_by: address,
    created_epoch: u64,
}

public struct GSOSAvatarStatusChanged has copy, drop {
    registry_id: ID,
    avatar_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct GSOSAvatarBindingPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct GSOSAvatarBindingVersionChanged has copy, drop {
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
    GSOSAvatarBindingRegistry,
    GSOSAvatarBindingAdminCap,
) {
    access_control::assert_not_paused(access);

    let registry = GSOSAvatarBindingRegistry {
        id: object::new(ctx),

        version: REGISTRY_VERSION,
        paused: false,

        next_avatar_id: 1,

        avatars: vector[],

        total_created: 0,
        total_revoked: 0,
        active_avatar_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSAvatarBindingAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Core Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSAvatarBindingRegistry,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &GSOSAvatarBindingRegistry,
    admin_cap: &GSOSAvatarBindingAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}


/* ============================================================
   Identity Validation
   ============================================================ */

fun assert_avatar_identity(
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

    assert!(
        identity_binding::binding_identity_type(
            identities,
            identity_binding_id,
        ) == identity_binding::identity_avatar(),
        E_IDENTITY_NOT_AVATAR,
    );
}


/* ============================================================
   World / Space Validation
   ============================================================ */

fun assert_world_and_space(
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

    assert!(
        space_binding_id != 0,
        E_INVALID_SPACE_BINDING_ID,
    );

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
   AVATAR Protocol Validation
   ============================================================ */

fun assert_avatar_protocol(
    protocols: &GSOSProtocolRegistry,
    avatar_protocol_id: u64,
) {
    assert!(
        avatar_protocol_id != 0,
        E_INVALID_AVATAR_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_exists(
            protocols,
            avatar_protocol_id,
        ),
        E_INVALID_AVATAR_PROTOCOL,
    );

    assert!(
        protocol_registry::is_protocol_active(
            protocols,
            avatar_protocol_id,
        ),
        E_INVALID_AVATAR_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_family(
            protocols,
            avatar_protocol_id,
        ) == protocol_registry::family_avatar(),
        E_INVALID_AVATAR_PROTOCOL,
    );
}


/* ============================================================
   Duplicate Active Avatar Guard
   ============================================================ */

fun assert_no_duplicate_active_avatar(
    registry: &GSOSAvatarBindingRegistry,
    identity_binding_id: u64,
) {
    let length = vector::length(&registry.avatars);
    let mut i = 0;

    while (i < length) {
        let avatar =
            vector::borrow(
                &registry.avatars,
                i,
            );

        let duplicate =
            avatar.status == STATUS_ACTIVE
                && avatar.identity_binding_id
                    == identity_binding_id;

        assert!(
            !duplicate,
            E_DUPLICATE_ACTIVE_AVATAR,
        );

        i = i + 1;
    };
}


/* ============================================================
   Avatar Lookup
   ============================================================ */

fun avatar_index(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): u64 {
    let length = vector::length(&registry.avatars);
    let mut i = 0;

    while (i < length) {
        let avatar =
            vector::borrow(
                &registry.avatars,
                i,
            );

        if (avatar.avatar_id == avatar_id) {
            return i
        };

        i = i + 1;
    };

    abort E_AVATAR_NOT_FOUND
}

fun borrow_avatar_internal(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): &GSOSAvatarBinding {
    let index =
        avatar_index(
            registry,
            avatar_id,
        );

    vector::borrow(
        &registry.avatars,
        index,
    )
}


/* ============================================================
   Bind Avatar
   ============================================================ */

public fun bind_avatar(
    access: &AccessControl,
    registry: &mut GSOSAvatarBindingRegistry,
    admin_cap: &GSOSAvatarBindingAdminCap,

    identities: &GSOSIdentityRegistry,
    worlds: &GSOSWorldSpaceRegistry,
    protocols: &GSOSProtocolRegistry,

    identity_binding_id: u64,

    world_id: u64,
    space_binding_id: u64,

    avatar_protocol_id: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_avatar_identity(
        identities,
        identity_binding_id,
    );

    assert_world_and_space(
        worlds,
        world_id,
        space_binding_id,
    );

    assert_avatar_protocol(
        protocols,
        avatar_protocol_id,
    );

    assert_no_duplicate_active_avatar(
        registry,
        identity_binding_id,
    );

    let avatar_id =
        registry.next_avatar_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.avatars,
        GSOSAvatarBinding {
            avatar_id,

            identity_binding_id,

            world_id,
            space_binding_id,

            avatar_protocol_id,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_avatar_id =
        avatar_id + 1;

    registry.total_created =
        registry.total_created + 1;

    registry.active_avatar_count =
        registry.active_avatar_count + 1;

    event::emit(GSOSAvatarBound {
        registry_id: object::id(registry),

        avatar_id,
        identity_binding_id,

        world_id,
        space_binding_id,

        avatar_protocol_id,

        bound_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    avatar_id
}


/* ============================================================
   Mutable Lookup
   ============================================================ */

fun borrow_avatar_internal_mut(
    registry: &mut GSOSAvatarBindingRegistry,
    avatar_id: u64,
): &mut GSOSAvatarBinding {
    let index =
        avatar_index(
            registry,
            avatar_id,
        );

    vector::borrow_mut(
        &mut registry.avatars,
        index,
    )
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun version(
    registry: &GSOSAvatarBindingRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSAvatarBindingRegistry,
): bool {
    registry.paused
}

public fun total_created(
    registry: &GSOSAvatarBindingRegistry,
): u64 {
    registry.total_created
}

public fun total_revoked(
    registry: &GSOSAvatarBindingRegistry,
): u64 {
    registry.total_revoked
}

public fun active_avatar_count(
    registry: &GSOSAvatarBindingRegistry,
): u64 {
    registry.active_avatar_count
}


/* ============================================================
   Avatar Read API
   ============================================================ */

public fun avatar_identity_binding_id(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): u64 {
    borrow_avatar_internal(
        registry,
        avatar_id,
    ).identity_binding_id
}

public fun avatar_world_id(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): u64 {
    borrow_avatar_internal(
        registry,
        avatar_id,
    ).world_id
}

public fun avatar_space_binding_id(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): u64 {
    borrow_avatar_internal(
        registry,
        avatar_id,
    ).space_binding_id
}

public fun avatar_protocol_id(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): u64 {
    borrow_avatar_internal(
        registry,
        avatar_id,
    ).avatar_protocol_id
}

public fun avatar_status(
    registry: &GSOSAvatarBindingRegistry,
    avatar_id: u64,
): u8 {
    borrow_avatar_internal(
        registry,
        avatar_id,
    ).status
}


/* ============================================================
   Status Constants
   ============================================================ */

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
   Avatar Status Lifecycle
   ============================================================ */

public fun set_avatar_status(
    access: &AccessControl,
    registry: &mut GSOSAvatarBindingRegistry,
    admin_cap: &GSOSAvatarBindingAdminCap,

    avatar_id: u64,
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
        let avatar =
            borrow_avatar_internal_mut(
                registry,
                avatar_id,
            );

        previous_status = avatar.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_REVOKED,
            E_ALREADY_REVOKED,
        );

        avatar.status = new_status;
        avatar.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_avatar_count =
            registry.active_avatar_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_avatar_count =
            registry.active_avatar_count + 1;
    };

    if (new_status == STATUS_REVOKED) {
        registry.total_revoked =
            registry.total_revoked + 1;
    };

    event::emit(GSOSAvatarStatusChanged {
        registry_id: object::id(registry),
        avatar_id,

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
    registry: &mut GSOSAvatarBindingRegistry,
    admin_cap: &GSOSAvatarBindingAdminCap,

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

    event::emit(GSOSAvatarBindingPauseChanged {
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
    registry: &mut GSOSAvatarBindingRegistry,
    admin_cap: &GSOSAvatarBindingAdminCap,

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

    event::emit(GSOSAvatarBindingVersionChanged {
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
    registry: GSOSAvatarBindingRegistry,
) {
    let GSOSAvatarBindingRegistry {
        id,
        version: _,
        paused: _,
        next_avatar_id: _,
        avatars,
        total_created: _,
        total_revoked: _,
        active_avatar_count: _,
    } = registry;

    let mut avatars = avatars;

    while (!vector::is_empty(&avatars)) {
        let avatar =
            vector::pop_back(&mut avatars);

        let GSOSAvatarBinding {
            avatar_id: _,
            identity_binding_id: _,
            world_id: _,
            space_binding_id: _,
            avatar_protocol_id: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = avatar;
    };

    vector::destroy_empty(avatars);
    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSAvatarBindingAdminCap,
) {
    let GSOSAvatarBindingAdminCap {
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
    registry: &GSOSAvatarBindingRegistry,
): ID {
    object::id(registry)
}
