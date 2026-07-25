module tobmate_core::gsos_identity_binding;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::tmid::{
    Self as tmid,
    TMID,
};


/* ============================================================
   Stage 11 Part 1
   GSOS ↔ TMID Identity Binding
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Identity Types
   ============================================================ */

const IDENTITY_USER: u8 = 1;
const IDENTITY_AGENT: u8 = 2;
const IDENTITY_AVATAR: u8 = 3;


/* ============================================================
   Binding Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_REVOKED: u8 = 2;


/* ============================================================
   Errors
   ============================================================ */

const E_BINDING_PAUSED: u64 = 1;
const E_INVALID_IDENTITY_TYPE: u64 = 2;
const E_EMPTY_IDENTITY_KEY: u64 = 3;
const E_EMPTY_GSAP_REFERENCE: u64 = 4;
const E_TMID_NOT_ACTIVE: u64 = 5;
const E_NOT_TMID_CONTROLLER: u64 = 6;
const E_DUPLICATE_ACTIVE_IDENTITY: u64 = 7;
const E_BINDING_NOT_FOUND: u64 = 8;
const E_BINDING_ALREADY_REVOKED: u64 = 9;
const E_STATE_UNCHANGED: u64 = 10;
const E_VERSION_UNCHANGED: u64 = 11;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSIdentityRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_binding_id: u64,
    bindings: vector<GSOSIdentityBinding>,

    total_created: u64,
    total_revoked: u64,
    active_binding_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct GSOSIdentityAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Binding Record
   ============================================================ */

public struct GSOSIdentityBinding has store {
    binding_id: u64,

    tmid_id: ID,
    tmid_controller: address,

    identity_type: u8,
    identity_key: vector<u8>,
    gsap_reference: vector<u8>,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct GSOSIdentityBindingCreated has copy, drop {
    registry_id: ID,
    binding_id: u64,
    tmid_id: ID,
    controller: address,
    identity_type: u8,
    created_epoch: u64,
}

public struct GSOSIdentityBindingRevoked has copy, drop {
    registry_id: ID,
    binding_id: u64,
    tmid_id: ID,
    revoked_by: address,
    revoked_epoch: u64,
}

public struct GSOSIdentityPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct GSOSIdentityVersionChanged has copy, drop {
    registry_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}


/* ============================================================
   Registry Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (GSOSIdentityRegistry, GSOSIdentityAdminCap) {
    let registry =
        GSOSIdentityRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused: false,

            next_binding_id: 1,
            bindings:
                vector::empty<GSOSIdentityBinding>(),

            total_created: 0,
            total_revoked: 0,
            active_binding_count: 0,
        };

    let registry_id =
        object::id(
            &registry,
        );

    let admin_cap =
        GSOSIdentityAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    (
        registry,
        admin_cap,
    )
}


/* ============================================================
   Operational Guards
   ============================================================ */

public fun assert_operational(
    access: &AccessControl,
    registry: &GSOSIdentityRegistry,
) {
    access_control::assert_not_paused(
        access,
    );

    assert!(
        !registry.paused,
        E_BINDING_PAUSED,
    );
}


fun assert_valid_identity_type(
    identity_type: u8,
) {
    assert!(
        identity_type == IDENTITY_USER
            || identity_type == IDENTITY_AGENT
            || identity_type == IDENTITY_AVATAR,
        E_INVALID_IDENTITY_TYPE,
    );
}


fun assert_admin(
    registry: &GSOSIdentityRegistry,
    admin_cap: &GSOSIdentityAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_INVALID_IDENTITY_TYPE,
    );
}


/* ============================================================
   Duplicate Active Binding Detection
   ============================================================ */

fun contains_active_identity(
    registry: &GSOSIdentityRegistry,
    identity_type: u8,
    identity_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.bindings,
        );

    let mut i = 0;

    while (i < length) {
        let binding =
            vector::borrow(
                &registry.bindings,
                i,
            );

        if (
            binding.status == STATUS_ACTIVE
                && binding.identity_type
                    == identity_type
                && binding.identity_key
                    == *identity_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


fun contains_active_tmid_identity(
    registry: &GSOSIdentityRegistry,
    tmid_id: ID,
    identity_type: u8,
    identity_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.bindings,
        );

    let mut i = 0;

    while (i < length) {
        let binding =
            vector::borrow(
                &registry.bindings,
                i,
            );

        if (
            binding.status == STATUS_ACTIVE
                && binding.tmid_id == tmid_id
                && binding.identity_type
                    == identity_type
                && binding.identity_key
                    == *identity_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Binding Lifecycle
   ============================================================ */

public fun create_binding(
    access: &AccessControl,
    registry: &mut GSOSIdentityRegistry,
    tmid_obj: &TMID,

    identity_type: u8,
    identity_key: vector<u8>,
    gsap_reference: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert_valid_identity_type(
        identity_type,
    );

    assert!(
        vector::length(&identity_key) > 0,
        E_EMPTY_IDENTITY_KEY,
    );

    assert!(
        vector::length(&gsap_reference) > 0,
        E_EMPTY_GSAP_REFERENCE,
    );

    assert!(
        tmid::is_active(
            tmid_obj,
        ),
        E_TMID_NOT_ACTIVE,
    );

    let controller =
        tmid::controller(
            tmid_obj,
        );

    assert!(
        controller
            == tx_context::sender(ctx),
        E_NOT_TMID_CONTROLLER,
    );

    let tmid_id =
        tmid::tmid_id(
            tmid_obj,
        );

    assert!(
        !contains_active_identity(
            registry,
            identity_type,
            &identity_key,
        ),
        E_DUPLICATE_ACTIVE_IDENTITY,
    );

    assert!(
        !contains_active_tmid_identity(
            registry,
            tmid_id,
            identity_type,
            &identity_key,
        ),
        E_DUPLICATE_ACTIVE_IDENTITY,
    );

    let binding_id =
        registry.next_binding_id;

    registry.next_binding_id =
        binding_id + 1;

    let epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.bindings,
        GSOSIdentityBinding {
            binding_id,

            tmid_id,
            tmid_controller:
                controller,

            identity_type,
            identity_key,
            gsap_reference,

            status:
                STATUS_ACTIVE,

            created_epoch:
                epoch,

            updated_epoch:
                epoch,
        },
    );

    registry.total_created =
        registry.total_created + 1;

    registry.active_binding_count =
        registry.active_binding_count + 1;

    event::emit(
        GSOSIdentityBindingCreated {
            registry_id:
                object::id(registry),

            binding_id,
            tmid_id,
            controller,
            identity_type,
            created_epoch:
                epoch,
        },
    );

    binding_id
}


public fun revoke_binding(
    access: &AccessControl,
    registry: &mut GSOSIdentityRegistry,
    admin_cap: &GSOSIdentityAdminCap,
    binding_id: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert_admin(
        registry,
        admin_cap,
    );

    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    let tmid_id = {
        let binding =
            vector::borrow_mut(
                &mut registry.bindings,
                index,
            );

        assert!(
            binding.status
                != STATUS_REVOKED,
            E_BINDING_ALREADY_REVOKED,
        );

        binding.status =
            STATUS_REVOKED;

        binding.updated_epoch =
            tx_context::epoch(ctx);

        binding.tmid_id
    };

    registry.total_revoked =
        registry.total_revoked + 1;

    registry.active_binding_count =
        registry.active_binding_count - 1;

    event::emit(
        GSOSIdentityBindingRevoked {
            registry_id:
                object::id(registry),

            binding_id,
            tmid_id,

            revoked_by:
                tx_context::sender(ctx),

            revoked_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &GSOSIdentityAdminCap,
    registry: &mut GSOSIdentityRegistry,
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
        GSOSIdentityPauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


public fun set_version(
    admin_cap: &GSOSIdentityAdminCap,
    registry: &mut GSOSIdentityRegistry,
    new_version: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    let previous_version =
        registry.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    registry.version =
        new_version;

    event::emit(
        GSOSIdentityVersionChanged {
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
   Internal Lookup
   ============================================================ */

fun find_binding_index(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.bindings,
        );

    let mut i = 0;

    while (i < length) {
        if (
            vector::borrow(
                &registry.bindings,
                i,
            ).binding_id
                == binding_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_BINDING_NOT_FOUND
}


/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &GSOSIdentityRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &GSOSIdentityRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSIdentityRegistry,
): bool {
    registry.paused
}

public fun binding_count(
    registry: &GSOSIdentityRegistry,
): u64 {
    vector::length(
        &registry.bindings,
    )
}

public fun total_created(
    registry: &GSOSIdentityRegistry,
): u64 {
    registry.total_created
}

public fun total_revoked(
    registry: &GSOSIdentityRegistry,
): u64 {
    registry.total_revoked
}

public fun active_binding_count(
    registry: &GSOSIdentityRegistry,
): u64 {
    registry.active_binding_count
}

public fun binding_status(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): u8 {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).status
}

public fun binding_tmid_id(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): ID {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).tmid_id
}

public fun binding_tmid_controller(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): address {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).tmid_controller
}

public fun binding_identity_type(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): u8 {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).identity_type
}

public fun binding_identity_key(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): vector<u8> {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).identity_key
}

public fun binding_gsap_reference(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): vector<u8> {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).gsap_reference
}

public fun binding_created_epoch(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): u64 {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).created_epoch
}

public fun binding_updated_epoch(
    registry: &GSOSIdentityRegistry,
    binding_id: u64,
): u64 {
    let index =
        find_binding_index(
            registry,
            binding_id,
        );

    vector::borrow(
        &registry.bindings,
        index,
    ).updated_epoch
}


/* ============================================================
   Identity / Status Constants
   ============================================================ */

public fun identity_user(): u8 {
    IDENTITY_USER
}

public fun identity_agent(): u8 {
    IDENTITY_AGENT
}

public fun identity_avatar(): u8 {
    IDENTITY_AVATAR
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_revoked(): u8 {
    STATUS_REVOKED
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): GSOSIdentityRegistry {
    GSOSIdentityRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused: false,

        next_binding_id: 1,
        bindings:
            vector::empty<GSOSIdentityBinding>(),

        total_created: 0,
        total_revoked: 0,
        active_binding_count: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &GSOSIdentityRegistry,
    ctx: &mut TxContext,
): GSOSIdentityAdminCap {
    GSOSIdentityAdminCap {
        id: object::new(ctx),
        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSIdentityAdminCap,
) {
    let GSOSIdentityAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: GSOSIdentityRegistry,
) {
    let GSOSIdentityRegistry {
        id,

        version: _,
        paused: _,

        next_binding_id: _,
        mut bindings,

        total_created: _,
        total_revoked: _,
        active_binding_count: _,
    } = registry;

    while (
        vector::length(
            &bindings,
        ) > 0
    ) {
        let GSOSIdentityBinding {
            binding_id: _,

            tmid_id: _,
            tmid_controller: _,

            identity_type: _,
            identity_key: _,
            gsap_reference: _,

            status: _,

            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut bindings,
        );
    };

    vector::destroy_empty(
        bindings,
    );

    object::delete(id);
}
