module tobmate_core::gsos_world_space_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::gsap_spatial_registry::{
    Self as spatial,
    GSAPSpatialRegistry,
};

use tobmate_core::gsos_protocol_registry::{
    Self as protocol_registry,
    GSOSProtocolRegistry,
};


/* ============================================================
   Stage 11 Part 4
   GSOS World / Space Registry
   Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Operational Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_DEPRECATED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_GSAP_SPACE_ID: u64 = 2;
const E_INVALID_PROTOCOL_ID: u64 = 3;
const E_WORLD_NOT_FOUND: u64 = 4;
const E_SPACE_BINDING_NOT_FOUND: u64 = 5;
const E_DUPLICATE_WORLD_ROOT: u64 = 6;
const E_DUPLICATE_SPACE_BINDING: u64 = 7;
const E_WORLD_INACTIVE: u64 = 8;
const E_ALREADY_DEPRECATED: u64 = 9;
const E_STATE_UNCHANGED: u64 = 10;
const E_VERSION_UNCHANGED: u64 = 11;
const E_ADMIN_CAP_MISMATCH: u64 = 12;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSWorldSpaceRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_world_id: u64,
    next_space_binding_id: u64,

    worlds: vector<GSOSWorld>,
    space_bindings: vector<GSOSSpaceBinding>,

    total_worlds: u64,
    total_space_bindings: u64,

    active_world_count: u64,
    active_space_binding_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSWorldSpaceAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   GSOS World

   root_gsap_space_id is canonical in GSAP Spatial Registry.
   Parent/controller hierarchy is NOT duplicated here.
   ============================================================ */

public struct GSOSWorld has store {
    world_id: u64,

    root_gsap_space_id: u64,

    entry_protocol_id: u64,
    presence_protocol_id: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   GSOS Space Binding

   A binding attaches an existing canonical GSAP space
   to a GSOS World and its operational protocol set.

   GSAP parent/controller state remains authoritative in
   gsap_spatial_registry.
   ============================================================ */

public struct GSOSSpaceBinding has store {
    binding_id: u64,

    world_id: u64,
    gsap_space_id: u64,

    entry_protocol_id: u64,
    presence_protocol_id: u64,
    capability_protocol_id: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct GSOSWorldRegistered has copy, drop {
    registry_id: ID,
    world_id: u64,
    root_gsap_space_id: u64,

    entry_protocol_id: u64,
    presence_protocol_id: u64,

    registered_by: address,
    created_epoch: u64,
}

public struct GSOSSpaceBound has copy, drop {
    registry_id: ID,

    binding_id: u64,
    world_id: u64,
    gsap_space_id: u64,

    entry_protocol_id: u64,
    presence_protocol_id: u64,
    capability_protocol_id: u64,

    bound_by: address,
    created_epoch: u64,
}

public struct GSOSWorldStatusChanged has copy, drop {
    registry_id: ID,
    world_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct GSOSSpaceBindingStatusChanged has copy, drop {
    registry_id: ID,
    binding_id: u64,

    previous_status: u8,
    new_status: u8,

    changed_by: address,
    updated_epoch: u64,
}

public struct GSOSWorldSpacePauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct GSOSWorldSpaceVersionChanged has copy, drop {
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
): (GSOSWorldSpaceRegistry, GSOSWorldSpaceAdminCap) {
    access_control::assert_not_paused(access);

    let registry = GSOSWorldSpaceRegistry {
        id: object::new(ctx),

        version: REGISTRY_VERSION,
        paused: false,

        next_world_id: 1,
        next_space_binding_id: 1,

        worlds: vector[],
        space_bindings: vector[],

        total_worlds: 0,
        total_space_bindings: 0,

        active_world_count: 0,
        active_space_binding_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSWorldSpaceAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Core Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSWorldSpaceRegistry,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}


/* ============================================================
   GSAP Canonical Space Validation

   Existence is delegated to GSAP space_status().
   Unknown space_id aborts inside canonical GSAP registry.
   ============================================================ */

fun assert_gsap_space_active(
    spatial_registry: &GSAPSpatialRegistry,
    gsap_space_id: u64,
) {
    assert!(
        gsap_space_id != 0,
        E_INVALID_GSAP_SPACE_ID,
    );

    assert!(
        spatial::space_status(
            spatial_registry,
            gsap_space_id,
        ) == spatial::status_active(),
        E_INVALID_GSAP_SPACE_ID,
    );
}


/* ============================================================
   Protocol Validation
   ============================================================ */

fun assert_active_protocol_family(
    protocols: &GSOSProtocolRegistry,
    protocol_id: u64,
    expected_family: u8,
) {
    assert!(
        protocol_id != 0,
        E_INVALID_PROTOCOL_ID,
    );

    assert!(
        protocol_registry::protocol_exists(
            protocols,
            protocol_id,
        ),
        E_INVALID_PROTOCOL_ID,
    );

    assert!(
        protocol_registry::is_protocol_active(
            protocols,
            protocol_id,
        ),
        E_INVALID_PROTOCOL_ID,
    );

    assert!(
        protocol_registry::protocol_family(
            protocols,
            protocol_id,
        ) == expected_family,
        E_INVALID_PROTOCOL_ID,
    );
}


/* ============================================================
   World Lookup
   ============================================================ */

fun world_index(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
): u64 {
    let length = vector::length(&registry.worlds);
    let mut i = 0;

    while (i < length) {
        let world = vector::borrow(
            &registry.worlds,
            i,
        );

        if (world.world_id == world_id) {
            return i
        };

        i = i + 1;
    };

    abort E_WORLD_NOT_FOUND
}

fun borrow_world_internal(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
): &GSOSWorld {
    let index = world_index(
        registry,
        world_id,
    );

    vector::borrow(
        &registry.worlds,
        index,
    )
}


/* ============================================================
   Space Binding Lookup
   ============================================================ */

fun space_binding_index(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u64 {
    let length =
        vector::length(&registry.space_bindings);

    let mut i = 0;

    while (i < length) {
        let binding = vector::borrow(
            &registry.space_bindings,
            i,
        );

        if (binding.binding_id == binding_id) {
            return i
        };

        i = i + 1;
    };

    abort E_SPACE_BINDING_NOT_FOUND
}

fun borrow_space_binding_internal(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): &GSOSSpaceBinding {
    let index = space_binding_index(
        registry,
        binding_id,
    );

    vector::borrow(
        &registry.space_bindings,
        index,
    )
}


/* ============================================================
   Duplicate Detection
   ============================================================ */

fun assert_unique_world_root(
    registry: &GSOSWorldSpaceRegistry,
    root_gsap_space_id: u64,
) {
    let length = vector::length(&registry.worlds);
    let mut i = 0;

    while (i < length) {
        let world = vector::borrow(
            &registry.worlds,
            i,
        );

        assert!(
            world.root_gsap_space_id
                != root_gsap_space_id,
            E_DUPLICATE_WORLD_ROOT,
        );

        i = i + 1;
    };
}

fun assert_unique_space_binding(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
    gsap_space_id: u64,
) {
    let length =
        vector::length(&registry.space_bindings);

    let mut i = 0;

    while (i < length) {
        let binding = vector::borrow(
            &registry.space_bindings,
            i,
        );

        let duplicate =
            binding.world_id == world_id
                && binding.gsap_space_id
                    == gsap_space_id
                && binding.status
                    != STATUS_DEPRECATED;

        assert!(
            !duplicate,
            E_DUPLICATE_SPACE_BINDING,
        );

        i = i + 1;
    };
}


/* ============================================================
   World Registration
   ============================================================ */

public fun register_world(
    access: &AccessControl,
    registry: &mut GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,

    spatial_registry: &GSAPSpatialRegistry,
    protocols: &GSOSProtocolRegistry,

    root_gsap_space_id: u64,
    entry_protocol_id: u64,
    presence_protocol_id: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_gsap_space_active(
        spatial_registry,
        root_gsap_space_id,
    );

    assert_active_protocol_family(
        protocols,
        entry_protocol_id,
        protocol_registry::family_entry(),
    );

    assert_active_protocol_family(
        protocols,
        presence_protocol_id,
        protocol_registry::family_presence(),
    );

    assert_unique_world_root(
        registry,
        root_gsap_space_id,
    );

    let world_id = registry.next_world_id;
    let current_epoch = tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.worlds,
        GSOSWorld {
            world_id,
            root_gsap_space_id,

            entry_protocol_id,
            presence_protocol_id,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_world_id =
        world_id + 1;

    registry.total_worlds =
        registry.total_worlds + 1;

    registry.active_world_count =
        registry.active_world_count + 1;

    event::emit(GSOSWorldRegistered {
        registry_id: object::id(registry),

        world_id,
        root_gsap_space_id,

        entry_protocol_id,
        presence_protocol_id,

        registered_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    world_id
}


/* ============================================================
   GSOS Space Binding
   ============================================================ */

public fun bind_space(
    access: &AccessControl,
    registry: &mut GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,

    spatial_registry: &GSAPSpatialRegistry,
    protocols: &GSOSProtocolRegistry,

    world_id: u64,
    gsap_space_id: u64,

    entry_protocol_id: u64,
    presence_protocol_id: u64,
    capability_protocol_id: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_gsap_space_active(
        spatial_registry,
        gsap_space_id,
    );

    {
        let world =
            borrow_world_internal(
                registry,
                world_id,
            );

        assert!(
            world.status == STATUS_ACTIVE,
            E_WORLD_INACTIVE,
        );
    };

    assert_active_protocol_family(
        protocols,
        entry_protocol_id,
        protocol_registry::family_entry(),
    );

    assert_active_protocol_family(
        protocols,
        presence_protocol_id,
        protocol_registry::family_presence(),
    );

    assert_active_protocol_family(
        protocols,
        capability_protocol_id,
        protocol_registry::family_capability(),
    );

    assert_unique_space_binding(
        registry,
        world_id,
        gsap_space_id,
    );

    let binding_id =
        registry.next_space_binding_id;

    let current_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.space_bindings,
        GSOSSpaceBinding {
            binding_id,

            world_id,
            gsap_space_id,

            entry_protocol_id,
            presence_protocol_id,
            capability_protocol_id,

            status: STATUS_ACTIVE,

            created_epoch: current_epoch,
            updated_epoch: current_epoch,
        },
    );

    registry.next_space_binding_id =
        binding_id + 1;

    registry.total_space_bindings =
        registry.total_space_bindings + 1;

    registry.active_space_binding_count =
        registry.active_space_binding_count + 1;

    event::emit(GSOSSpaceBound {
        registry_id: object::id(registry),

        binding_id,
        world_id,
        gsap_space_id,

        entry_protocol_id,
        presence_protocol_id,
        capability_protocol_id,

        bound_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    binding_id
}


/* ============================================================
   Mutable Lookup
   ============================================================ */

fun borrow_world_internal_mut(
    registry: &mut GSOSWorldSpaceRegistry,
    world_id: u64,
): &mut GSOSWorld {
    let index = world_index(
        registry,
        world_id,
    );

    vector::borrow_mut(
        &mut registry.worlds,
        index,
    )
}

fun borrow_space_binding_internal_mut(
    registry: &mut GSOSWorldSpaceRegistry,
    binding_id: u64,
): &mut GSOSSpaceBinding {
    let index = space_binding_index(
        registry,
        binding_id,
    );

    vector::borrow_mut(
        &mut registry.space_bindings,
        index,
    )
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun version(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSWorldSpaceRegistry,
): bool {
    registry.paused
}

public fun next_world_id(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.next_world_id
}

public fun next_space_binding_id(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.next_space_binding_id
}

public fun total_worlds(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.total_worlds
}

public fun total_space_bindings(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.total_space_bindings
}

public fun active_world_count(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.active_world_count
}

public fun active_space_binding_count(
    registry: &GSOSWorldSpaceRegistry,
): u64 {
    registry.active_space_binding_count
}


/* ============================================================
   World Read API
   ============================================================ */

public fun world_root_gsap_space_id(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
): u64 {
    borrow_world_internal(
        registry,
        world_id,
    ).root_gsap_space_id
}

public fun world_entry_protocol_id(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
): u64 {
    borrow_world_internal(
        registry,
        world_id,
    ).entry_protocol_id
}

public fun world_presence_protocol_id(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
): u64 {
    borrow_world_internal(
        registry,
        world_id,
    ).presence_protocol_id
}

public fun world_status(
    registry: &GSOSWorldSpaceRegistry,
    world_id: u64,
): u8 {
    borrow_world_internal(
        registry,
        world_id,
    ).status
}


/* ============================================================
   Space Binding Read API
   ============================================================ */

public fun binding_world_id(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u64 {
    borrow_space_binding_internal(
        registry,
        binding_id,
    ).world_id
}

public fun binding_gsap_space_id(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u64 {
    borrow_space_binding_internal(
        registry,
        binding_id,
    ).gsap_space_id
}

public fun binding_entry_protocol_id(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u64 {
    borrow_space_binding_internal(
        registry,
        binding_id,
    ).entry_protocol_id
}

public fun binding_presence_protocol_id(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u64 {
    borrow_space_binding_internal(
        registry,
        binding_id,
    ).presence_protocol_id
}

public fun binding_capability_protocol_id(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u64 {
    borrow_space_binding_internal(
        registry,
        binding_id,
    ).capability_protocol_id
}

public fun binding_status(
    registry: &GSOSWorldSpaceRegistry,
    binding_id: u64,
): u8 {
    borrow_space_binding_internal(
        registry,
        binding_id,
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

public fun status_deprecated(): u8 {
    STATUS_DEPRECATED
}


/* ============================================================
   World Status Lifecycle
   ============================================================ */

public fun set_world_status(
    access: &AccessControl,
    registry: &mut GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,
    world_id: u64,
    new_status: u8,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert!(
        new_status == STATUS_ACTIVE
            || new_status == STATUS_SUSPENDED
            || new_status == STATUS_DEPRECATED,
        E_STATE_UNCHANGED,
    );

    let current_epoch = tx_context::epoch(ctx);

    let previous_status;

    {
        let world =
            borrow_world_internal_mut(
                registry,
                world_id,
            );

        previous_status = world.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_DEPRECATED,
            E_ALREADY_DEPRECATED,
        );

        world.status = new_status;
        world.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_world_count =
            registry.active_world_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_world_count =
            registry.active_world_count + 1;
    };

    event::emit(GSOSWorldStatusChanged {
        registry_id: object::id(registry),
        world_id,

        previous_status,
        new_status,

        changed_by: tx_context::sender(ctx),
        updated_epoch: current_epoch,
    });
}


/* ============================================================
   Space Binding Status Lifecycle
   ============================================================ */

public fun set_space_binding_status(
    access: &AccessControl,
    registry: &mut GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,
    binding_id: u64,
    new_status: u8,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert!(
        new_status == STATUS_ACTIVE
            || new_status == STATUS_SUSPENDED
            || new_status == STATUS_DEPRECATED,
        E_STATE_UNCHANGED,
    );

    let current_epoch = tx_context::epoch(ctx);

    let previous_status;

    {
        let binding =
            borrow_space_binding_internal_mut(
                registry,
                binding_id,
            );

        previous_status = binding.status;

        assert!(
            previous_status != new_status,
            E_STATE_UNCHANGED,
        );

        assert!(
            previous_status != STATUS_DEPRECATED,
            E_ALREADY_DEPRECATED,
        );

        binding.status = new_status;
        binding.updated_epoch = current_epoch;
    };

    if (
        previous_status == STATUS_ACTIVE
            && new_status != STATUS_ACTIVE
    ) {
        registry.active_space_binding_count =
            registry.active_space_binding_count - 1;
    };

    if (
        previous_status != STATUS_ACTIVE
            && new_status == STATUS_ACTIVE
    ) {
        registry.active_space_binding_count =
            registry.active_space_binding_count + 1;
    };

    event::emit(GSOSSpaceBindingStatusChanged {
        registry_id: object::id(registry),
        binding_id,

        previous_status,
        new_status,

        changed_by: tx_context::sender(ctx),
        updated_epoch: current_epoch,
    });
}


/* ============================================================
   Registry Pause Control
   ============================================================ */

public fun set_paused(
    access: &AccessControl,
    registry: &mut GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,
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

    event::emit(GSOSWorldSpacePauseChanged {
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
    registry: &mut GSOSWorldSpaceRegistry,
    admin_cap: &GSOSWorldSpaceAdminCap,
    new_version: u64,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_admin(registry, admin_cap);

    assert!(
        registry.version != new_version,
        E_VERSION_UNCHANGED,
    );

    let previous_version = registry.version;

    registry.version = new_version;

    event::emit(GSOSWorldSpaceVersionChanged {
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
    registry: GSOSWorldSpaceRegistry,
) {
    let GSOSWorldSpaceRegistry {
        id,
        version: _,
        paused: _,
        next_world_id: _,
        next_space_binding_id: _,
        worlds,
        space_bindings,
        total_worlds: _,
        total_space_bindings: _,
        active_world_count: _,
        active_space_binding_count: _,
    } = registry;

    let mut worlds = worlds;

    while (!vector::is_empty(&worlds)) {
        let world = vector::pop_back(&mut worlds);

        let GSOSWorld {
            world_id: _,
            root_gsap_space_id: _,
            entry_protocol_id: _,
            presence_protocol_id: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = world;
    };

    vector::destroy_empty(worlds);

    let mut space_bindings = space_bindings;

    while (!vector::is_empty(&space_bindings)) {
        let binding =
            vector::pop_back(&mut space_bindings);

        let GSOSSpaceBinding {
            binding_id: _,
            world_id: _,
            gsap_space_id: _,
            entry_protocol_id: _,
            presence_protocol_id: _,
            capability_protocol_id: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = binding;
    };

    vector::destroy_empty(space_bindings);

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSWorldSpaceAdminCap,
) {
    let GSOSWorldSpaceAdminCap {
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
    registry: &GSOSWorldSpaceRegistry,
): ID {
    object::id(registry)
}
