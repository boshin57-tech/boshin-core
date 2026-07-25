module tobmate_core::gsap_spatial_registry;

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


/* ============================================================
   Stage 11 Part 2
   GSAP Spatial Registry / World Binding
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Space Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_INACTIVE: u8 = 2;


/* ============================================================
   Space Types
   ============================================================ */

const SPACE_WORLD: u8 = 1;
const SPACE_REGION: u8 = 2;
const SPACE_ROOM: u8 = 3;
const SPACE_CELL: u8 = 4;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_EMPTY_GSAP_ADDRESS: u64 = 2;
const E_EMPTY_NAMESPACE: u64 = 3;
const E_EMPTY_WORLD_KEY: u64 = 4;
const E_INVALID_SPACE_TYPE: u64 = 5;
const E_DUPLICATE_ACTIVE_GSAP: u64 = 6;
const E_IDENTITY_BINDING_NOT_ACTIVE: u64 = 7;
const E_NOT_BINDING_CONTROLLER: u64 = 8;
const E_SPACE_NOT_FOUND: u64 = 9;
const E_SPACE_ALREADY_INACTIVE: u64 = 10;
const E_STATE_UNCHANGED: u64 = 11;
const E_VERSION_UNCHANGED: u64 = 12;
const E_ADMIN_CAP_MISMATCH: u64 = 13;
const E_INVALID_PARENT_SPACE: u64 = 14;
const E_PARENT_SPACE_INACTIVE: u64 = 15;
const E_INVALID_PARENT_TYPE: u64 = 16;
const E_ACTIVE_CHILD_EXISTS: u64 = 17;


/* ============================================================
   Spatial Registry
   ============================================================ */

public struct GSAPSpatialRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_space_id: u64,
    spaces: vector<GSAPSpace>,

    total_registered: u64,
    total_deactivated: u64,
    active_space_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct GSAPSpatialAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Spatial Record
   ============================================================ */

public struct GSAPSpace has store {
    space_id: u64,

    gsap_address: vector<u8>,
    namespace: vector<u8>,
    world_key: vector<u8>,

    space_type: u8,
    parent_space_id: u64,

    controller_tmid_id: ID,
    controller_binding_id: u64,
    controller: address,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct GSAPSpaceRegistered has copy, drop {
    registry_id: ID,
    space_id: u64,
    controller_tmid_id: ID,
    controller_binding_id: u64,
    space_type: u8,
    controller: address,
    created_epoch: u64,
}

public struct GSAPSpaceDeactivated has copy, drop {
    registry_id: ID,
    space_id: u64,
    deactivated_by: address,
    deactivated_epoch: u64,
}

public struct GSAPSpatialPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct GSAPSpatialVersionChanged has copy, drop {
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
): (GSAPSpatialRegistry, GSAPSpatialAdminCap) {
    let registry =
        GSAPSpatialRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused: false,

            next_space_id: 1,
            spaces:
                vector::empty<GSAPSpace>(),

            total_registered: 0,
            total_deactivated: 0,
            active_space_count: 0,
        };

    let registry_id =
        object::id(
            &registry,
        );

    let admin_cap =
        GSAPSpatialAdminCap {
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
    registry: &GSAPSpatialRegistry,
) {
    access_control::assert_not_paused(
        access,
    );

    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}


fun assert_admin(
    registry: &GSAPSpatialRegistry,
    admin_cap: &GSAPSpatialAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}


fun assert_valid_space_type(
    space_type: u8,
) {
    assert!(
        space_type == SPACE_WORLD
            || space_type == SPACE_REGION
            || space_type == SPACE_ROOM
            || space_type == SPACE_CELL,
        E_INVALID_SPACE_TYPE,
    );
}


/* ============================================================
   Duplicate Detection
   ============================================================ */

fun contains_active_gsap(
    registry: &GSAPSpatialRegistry,
    gsap_address: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.spaces,
        );

    let mut i = 0;

    while (i < length) {
        let space =
            vector::borrow(
                &registry.spaces,
                i,
            );

        if (
            space.status == STATUS_ACTIVE
                && space.gsap_address
                    == *gsap_address
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Internal Lookup
   ============================================================ */



fun has_active_child(
    registry: &GSAPSpatialRegistry,
    parent_space_id: u64,
): bool {
    let length =
        vector::length(
            &registry.spaces,
        );

    let mut i = 0;

    while (i < length) {
        let space =
            vector::borrow(
                &registry.spaces,
                i,
            );

        if (
            space.status == STATUS_ACTIVE
                && space.parent_space_id
                    == parent_space_id
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


fun assert_valid_parent(
    registry: &GSAPSpatialRegistry,
    space_type: u8,
    parent_space_id: u64,
) {
    if (space_type == SPACE_WORLD) {
        assert!(
            parent_space_id == 0,
            E_INVALID_PARENT_SPACE,
        );
        return
    };

    assert!(
        parent_space_id != 0,
        E_INVALID_PARENT_SPACE,
    );

    let parent_index =
        find_space_index(
            registry,
            parent_space_id,
        );

    let parent =
        vector::borrow(
            &registry.spaces,
            parent_index,
        );

    assert!(
        parent.status == STATUS_ACTIVE,
        E_PARENT_SPACE_INACTIVE,
    );

    if (space_type == SPACE_REGION) {
        assert!(
            parent.space_type == SPACE_WORLD
                || parent.space_type == SPACE_REGION,
            E_INVALID_PARENT_TYPE,
        );
    } else if (space_type == SPACE_ROOM) {
        assert!(
            parent.space_type == SPACE_WORLD
                || parent.space_type == SPACE_REGION
                || parent.space_type == SPACE_ROOM,
            E_INVALID_PARENT_TYPE,
        );
    } else if (space_type == SPACE_CELL) {
        assert!(
            parent.space_type == SPACE_WORLD
                || parent.space_type == SPACE_REGION
                || parent.space_type == SPACE_ROOM,
            E_INVALID_PARENT_TYPE,
        );
    };
}


fun find_space_index(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.spaces,
        );

    let mut i = 0;

    while (i < length) {
        if (
            vector::borrow(
                &registry.spaces,
                i,
            ).space_id
                == space_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_SPACE_NOT_FOUND
}


/* ============================================================
   Spatial Lifecycle
   ============================================================ */

public fun register_space(
    access: &AccessControl,
    registry: &mut GSAPSpatialRegistry,
    identity_registry: &GSOSIdentityRegistry,

    controller_binding_id: u64,

    gsap_address: vector<u8>,
    namespace: vector<u8>,
    world_key: vector<u8>,

    space_type: u8,
    parent_space_id: u64,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert_valid_space_type(
        space_type,
    );


    assert_valid_parent(
        registry,
        space_type,
        parent_space_id,
    );

    assert!(
        vector::length(&gsap_address) > 0,
        E_EMPTY_GSAP_ADDRESS,
    );

    assert!(
        vector::length(&namespace) > 0,
        E_EMPTY_NAMESPACE,
    );

    assert!(
        vector::length(&world_key) > 0,
        E_EMPTY_WORLD_KEY,
    );

    assert!(
        !contains_active_gsap(
            registry,
            &gsap_address,
        ),
        E_DUPLICATE_ACTIVE_GSAP,
    );

    assert!(
        identity_binding::binding_status(
            identity_registry,
            controller_binding_id,
        ) == identity_binding::status_active(),
        E_IDENTITY_BINDING_NOT_ACTIVE,
    );

    let controller =
        identity_binding::binding_tmid_controller(
            identity_registry,
            controller_binding_id,
        );

    assert!(
        controller == tx_context::sender(ctx),
        E_NOT_BINDING_CONTROLLER,
    );

    let controller_tmid_id =
        identity_binding::binding_tmid_id(
            identity_registry,
            controller_binding_id,
        );

    let space_id =
        registry.next_space_id;

    registry.next_space_id =
        space_id + 1;

    let epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.spaces,
        GSAPSpace {
            space_id,

            gsap_address,
            namespace,
            world_key,

            space_type,
            parent_space_id,

            controller_tmid_id,
            controller_binding_id,
            controller,

            status:
                STATUS_ACTIVE,

            created_epoch:
                epoch,

            updated_epoch:
                epoch,
        },
    );

    registry.total_registered =
        registry.total_registered + 1;

    registry.active_space_count =
        registry.active_space_count + 1;

    event::emit(
        GSAPSpaceRegistered {
            registry_id:
                object::id(registry),

            space_id,
            controller_tmid_id,
            controller_binding_id,
            space_type,
            controller,

            created_epoch:
                epoch,
        },
    );

    space_id
}


public fun deactivate_space(
    access: &AccessControl,
    registry: &mut GSAPSpatialRegistry,
    admin_cap: &GSAPSpatialAdminCap,
    space_id: u64,
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
        find_space_index(
            registry,
            space_id,
        );


    assert!(
        !has_active_child(
            registry,
            space_id,
        ),
        E_ACTIVE_CHILD_EXISTS,
    );

    {
        let space =
            vector::borrow_mut(
                &mut registry.spaces,
                index,
            );

        assert!(
            space.status == STATUS_ACTIVE,
            E_SPACE_ALREADY_INACTIVE,
        );

        space.status =
            STATUS_INACTIVE;

        space.updated_epoch =
            tx_context::epoch(ctx);
    };

    registry.total_deactivated =
        registry.total_deactivated + 1;

    registry.active_space_count =
        registry.active_space_count - 1;

    event::emit(
        GSAPSpaceDeactivated {
            registry_id:
                object::id(registry),

            space_id,

            deactivated_by:
                tx_context::sender(ctx),

            deactivated_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &GSAPSpatialAdminCap,
    registry: &mut GSAPSpatialRegistry,
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
        GSAPSpatialPauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


public fun set_version(
    admin_cap: &GSAPSpatialAdminCap,
    registry: &mut GSAPSpatialRegistry,
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
        GSAPSpatialVersionChanged {
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
   Read API
   ============================================================ */

public fun registry_id(
    registry: &GSAPSpatialRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &GSAPSpatialRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSAPSpatialRegistry,
): bool {
    registry.paused
}

public fun space_count(
    registry: &GSAPSpatialRegistry,
): u64 {
    vector::length(
        &registry.spaces,
    )
}

public fun total_registered(
    registry: &GSAPSpatialRegistry,
): u64 {
    registry.total_registered
}

public fun total_deactivated(
    registry: &GSAPSpatialRegistry,
): u64 {
    registry.total_deactivated
}

public fun active_space_count(
    registry: &GSAPSpatialRegistry,
): u64 {
    registry.active_space_count
}

public fun space_status(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u8 {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).status
}

public fun space_gsap_address(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): vector<u8> {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).gsap_address
}

public fun space_namespace(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): vector<u8> {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).namespace
}

public fun space_world_key(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): vector<u8> {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).world_key
}

public fun space_type(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u8 {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).space_type
}

public fun space_parent_id(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u64 {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).parent_space_id
}

public fun space_controller_tmid_id(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): ID {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).controller_tmid_id
}

public fun space_controller_binding_id(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u64 {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).controller_binding_id
}

public fun space_controller(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): address {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).controller
}

public fun space_created_epoch(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u64 {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).created_epoch
}

public fun space_updated_epoch(
    registry: &GSAPSpatialRegistry,
    space_id: u64,
): u64 {
    let index =
        find_space_index(
            registry,
            space_id,
        );

    vector::borrow(
        &registry.spaces,
        index,
    ).updated_epoch
}


/* ============================================================
   Space / Status Constants
   ============================================================ */

public fun space_world(): u8 {
    SPACE_WORLD
}

public fun space_region(): u8 {
    SPACE_REGION
}

public fun space_room(): u8 {
    SPACE_ROOM
}

public fun space_cell(): u8 {
    SPACE_CELL
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_inactive(): u8 {
    STATUS_INACTIVE
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): GSAPSpatialRegistry {
    GSAPSpatialRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused: false,

        next_space_id: 1,
        spaces:
            vector::empty<GSAPSpace>(),

        total_registered: 0,
        total_deactivated: 0,
        active_space_count: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &GSAPSpatialRegistry,
    ctx: &mut TxContext,
): GSAPSpatialAdminCap {
    GSAPSpatialAdminCap {
        id: object::new(ctx),
        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSAPSpatialAdminCap,
) {
    let GSAPSpatialAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: GSAPSpatialRegistry,
) {
    let GSAPSpatialRegistry {
        id,

        version: _,
        paused: _,

        next_space_id: _,
        mut spaces,

        total_registered: _,
        total_deactivated: _,
        active_space_count: _,
    } = registry;

    while (
        vector::length(
            &spaces,
        ) > 0
    ) {
        let GSAPSpace {
            space_id: _,

            gsap_address: _,
            namespace: _,
            world_key: _,

            space_type: _,
            parent_space_id: _,

            controller_tmid_id: _,
            controller_binding_id: _,
            controller: _,

            status: _,

            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut spaces,
        );
    };

    vector::destroy_empty(
        spaces,
    );

    object::delete(id);
}
