module tobmate_gsos::gsos_protocol_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};


/* ============================================================
   Stage 11 Part 3
   GSOS Protocol Registry / Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Protocol Families
   ============================================================ */

const FAMILY_GSAP: u8 = 1;
const FAMILY_ENTRY: u8 = 2;
const FAMILY_PRESENCE: u8 = 3;
const FAMILY_AVATAR: u8 = 4;
const FAMILY_AGENT: u8 = 5;
const FAMILY_CAPABILITY: u8 = 6;
const FAMILY_EVENT: u8 = 7;


/* ============================================================
   Protocol Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_DEPRECATED: u8 = 2;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_FAMILY: u64 = 2;
const E_EMPTY_PROTOCOL_NAME: u64 = 3;
const E_EMPTY_SPECIFICATION_HASH: u64 = 4;
const E_EMPTY_COMPATIBILITY_HASH: u64 = 5;
const E_DUPLICATE_ACTIVE_VERSION: u64 = 6;
const E_PROTOCOL_NOT_FOUND: u64 = 7;
const E_ALREADY_DEPRECATED: u64 = 8;
const E_STATE_UNCHANGED: u64 = 9;
const E_VERSION_UNCHANGED: u64 = 10;
const E_ADMIN_CAP_MISMATCH: u64 = 11;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSProtocolRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_protocol_id: u64,
    protocols: vector<GSOSProtocol>,

    total_registered: u64,
    total_deprecated: u64,
    active_protocol_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSProtocolAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Protocol Record
   ============================================================ */

public struct GSOSProtocol has store {
    protocol_id: u64,

    protocol_family: u8,
    protocol_name: vector<u8>,

    major_version: u64,
    minor_version: u64,
    patch_version: u64,

    specification_hash: vector<u8>,
    compatibility_hash: vector<u8>,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct GSOSProtocolRegistered has copy, drop {
    registry_id: ID,
    protocol_id: u64,
    protocol_family: u8,

    major_version: u64,
    minor_version: u64,
    patch_version: u64,

    registered_by: address,
    created_epoch: u64,
}

public struct GSOSProtocolDeprecated has copy, drop {
    registry_id: ID,
    protocol_id: u64,
    deprecated_by: address,
    deprecated_epoch: u64,
}

public struct GSOSProtocolPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct GSOSProtocolRegistryVersionChanged has copy, drop {
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
): (GSOSProtocolRegistry, GSOSProtocolAdminCap) {
    access_control::assert_not_paused(access);

    let registry = GSOSProtocolRegistry {
        id: object::new(ctx),

        version: REGISTRY_VERSION,
        paused: false,

        next_protocol_id: 1,
        protocols: vector[],

        total_registered: 0,
        total_deprecated: 0,
        active_protocol_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSProtocolAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Internal Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSProtocolRegistry,
) {
    assert!(!registry.paused, E_REGISTRY_PAUSED);
}

fun assert_admin(
    registry: &GSOSProtocolRegistry,
    admin_cap: &GSOSProtocolAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_family(
    protocol_family: u8,
) {
    assert!(
        protocol_family >= FAMILY_GSAP
            && protocol_family <= FAMILY_EVENT,
        E_INVALID_FAMILY,
    );
}

fun assert_non_empty_protocol_name(
    protocol_name: &vector<u8>,
) {
    assert!(
        vector::length(protocol_name) > 0,
        E_EMPTY_PROTOCOL_NAME,
    );
}

fun assert_non_empty_specification_hash(
    specification_hash: &vector<u8>,
) {
    assert!(
        vector::length(specification_hash) > 0,
        E_EMPTY_SPECIFICATION_HASH,
    );
}

fun assert_non_empty_compatibility_hash(
    compatibility_hash: &vector<u8>,
) {
    assert!(
        vector::length(compatibility_hash) > 0,
        E_EMPTY_COMPATIBILITY_HASH,
    );
}


/* ============================================================
   Duplicate Active Version Detection
   ============================================================ */

fun assert_no_duplicate_active_version(
    registry: &GSOSProtocolRegistry,
    protocol_family: u8,
    major_version: u64,
    minor_version: u64,
    patch_version: u64,
) {
    let length = vector::length(&registry.protocols);
    let mut i = 0;

    while (i < length) {
        let protocol = vector::borrow(&registry.protocols, i);

        let duplicate =
            protocol.status == STATUS_ACTIVE
                && protocol.protocol_family == protocol_family
                && protocol.major_version == major_version
                && protocol.minor_version == minor_version
                && protocol.patch_version == patch_version;

        assert!(!duplicate, E_DUPLICATE_ACTIVE_VERSION);

        i = i + 1;
    };
}


/* ============================================================
   Protocol Lookup
   ============================================================ */

fun protocol_index(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u64 {
    let length = vector::length(&registry.protocols);
    let mut i = 0;

    while (i < length) {
        let protocol = vector::borrow(&registry.protocols, i);

        if (protocol.protocol_id == protocol_id) {
            return i
        };

        i = i + 1;
    };

    abort E_PROTOCOL_NOT_FOUND
}

fun borrow_protocol_internal(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): &GSOSProtocol {
    let index = protocol_index(registry, protocol_id);
    vector::borrow(&registry.protocols, index)
}

fun borrow_protocol_internal_mut(
    registry: &mut GSOSProtocolRegistry,
    protocol_id: u64,
): &mut GSOSProtocol {
    let index = protocol_index(registry, protocol_id);
    vector::borrow_mut(&mut registry.protocols, index)
}


/* ============================================================
   Public Read API — Registry
   ============================================================ */

public fun version(
    registry: &GSOSProtocolRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSProtocolRegistry,
): bool {
    registry.paused
}

public fun next_protocol_id(
    registry: &GSOSProtocolRegistry,
): u64 {
    registry.next_protocol_id
}

public fun total_registered(
    registry: &GSOSProtocolRegistry,
): u64 {
    registry.total_registered
}

public fun total_deprecated(
    registry: &GSOSProtocolRegistry,
): u64 {
    registry.total_deprecated
}

public fun active_protocol_count(
    registry: &GSOSProtocolRegistry,
): u64 {
    registry.active_protocol_count
}

public fun protocol_count(
    registry: &GSOSProtocolRegistry,
): u64 {
    vector::length(&registry.protocols)
}


/* ============================================================
   Public Read API — Protocol
   ============================================================ */

public fun protocol_exists(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): bool {
    let length = vector::length(&registry.protocols);
    let mut i = 0;

    while (i < length) {
        let protocol = vector::borrow(&registry.protocols, i);

        if (protocol.protocol_id == protocol_id) {
            return true
        };

        i = i + 1;
    };

    false
}

public fun protocol_family(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u8 {
    borrow_protocol_internal(registry, protocol_id).protocol_family
}

public fun protocol_name(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): &vector<u8> {
    &borrow_protocol_internal(registry, protocol_id).protocol_name
}

public fun protocol_major_version(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u64 {
    borrow_protocol_internal(registry, protocol_id).major_version
}

public fun protocol_minor_version(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u64 {
    borrow_protocol_internal(registry, protocol_id).minor_version
}

public fun protocol_patch_version(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u64 {
    borrow_protocol_internal(registry, protocol_id).patch_version
}

public fun protocol_status(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u8 {
    borrow_protocol_internal(registry, protocol_id).status
}

public fun protocol_specification_hash(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): &vector<u8> {
    &borrow_protocol_internal(registry, protocol_id).specification_hash
}

public fun protocol_compatibility_hash(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): &vector<u8> {
    &borrow_protocol_internal(registry, protocol_id).compatibility_hash
}

public fun protocol_created_epoch(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u64 {
    borrow_protocol_internal(registry, protocol_id).created_epoch
}

public fun protocol_updated_epoch(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): u64 {
    borrow_protocol_internal(registry, protocol_id).updated_epoch
}


/* ============================================================
   Family / Status Constants
   ============================================================ */

public fun family_gsap(): u8 {
    FAMILY_GSAP
}

public fun family_entry(): u8 {
    FAMILY_ENTRY
}

public fun family_presence(): u8 {
    FAMILY_PRESENCE
}

public fun family_avatar(): u8 {
    FAMILY_AVATAR
}

public fun family_agent(): u8 {
    FAMILY_AGENT
}

public fun family_capability(): u8 {
    FAMILY_CAPABILITY
}

public fun family_event(): u8 {
    FAMILY_EVENT
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_deprecated(): u8 {
    STATUS_DEPRECATED
}


/* ============================================================
   Protocol Registration
   ============================================================ */

public fun register_protocol(
    access: &AccessControl,
    registry: &mut GSOSProtocolRegistry,
    admin_cap: &GSOSProtocolAdminCap,

    protocol_family: u8,
    protocol_name: vector<u8>,

    major_version: u64,
    minor_version: u64,
    patch_version: u64,

    specification_hash: vector<u8>,
    compatibility_hash: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_valid_family(protocol_family);
    assert_non_empty_protocol_name(&protocol_name);
    assert_non_empty_specification_hash(&specification_hash);
    assert_non_empty_compatibility_hash(&compatibility_hash);

    assert_no_duplicate_active_version(
        registry,
        protocol_family,
        major_version,
        minor_version,
        patch_version,
    );

    let protocol_id = registry.next_protocol_id;
    let current_epoch = tx_context::epoch(ctx);

    let protocol = GSOSProtocol {
        protocol_id,

        protocol_family,
        protocol_name,

        major_version,
        minor_version,
        patch_version,

        specification_hash,
        compatibility_hash,

        status: STATUS_ACTIVE,

        created_epoch: current_epoch,
        updated_epoch: current_epoch,
    };

    vector::push_back(
        &mut registry.protocols,
        protocol,
    );

    registry.next_protocol_id = protocol_id + 1;
    registry.total_registered = registry.total_registered + 1;
    registry.active_protocol_count =
        registry.active_protocol_count + 1;

    event::emit(GSOSProtocolRegistered {
        registry_id: object::id(registry),
        protocol_id,
        protocol_family,

        major_version,
        minor_version,
        patch_version,

        registered_by: tx_context::sender(ctx),
        created_epoch: current_epoch,
    });

    protocol_id
}


/* ============================================================
   Protocol Deprecation
   ============================================================ */

public fun deprecate_protocol(
    access: &AccessControl,
    registry: &mut GSOSProtocolRegistry,
    admin_cap: &GSOSProtocolAdminCap,
    protocol_id: u64,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    let current_epoch = tx_context::epoch(ctx);

    {
        let protocol =
            borrow_protocol_internal_mut(
                registry,
                protocol_id,
            );

        assert!(
            protocol.status == STATUS_ACTIVE,
            E_ALREADY_DEPRECATED,
        );

        protocol.status = STATUS_DEPRECATED;
        protocol.updated_epoch = current_epoch;
    };

    registry.total_deprecated =
        registry.total_deprecated + 1;

    registry.active_protocol_count =
        registry.active_protocol_count - 1;

    event::emit(GSOSProtocolDeprecated {
        registry_id: object::id(registry),
        protocol_id,
        deprecated_by: tx_context::sender(ctx),
        deprecated_epoch: current_epoch,
    });
}


/* ============================================================
   Active Protocol Queries
   ============================================================ */

public fun is_protocol_active(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): bool {
    borrow_protocol_internal(
        registry,
        protocol_id,
    ).status == STATUS_ACTIVE
}

public fun is_protocol_deprecated(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
): bool {
    borrow_protocol_internal(
        registry,
        protocol_id,
    ).status == STATUS_DEPRECATED
}


/* ============================================================
   Version Matching
   ============================================================ */

public fun matches_version(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
    major_version: u64,
    minor_version: u64,
    patch_version: u64,
): bool {
    let protocol =
        borrow_protocol_internal(
            registry,
            protocol_id,
        );

    protocol.major_version == major_version
        && protocol.minor_version == minor_version
        && protocol.patch_version == patch_version
}


/* ============================================================
   Family Matching
   ============================================================ */

public fun matches_family(
    registry: &GSOSProtocolRegistry,
    protocol_id: u64,
    protocol_family: u8,
): bool {
    borrow_protocol_internal(
        registry,
        protocol_id,
    ).protocol_family == protocol_family
}


/* ============================================================
   Registry Pause Control
   ============================================================ */

public fun set_paused(
    access: &AccessControl,
    registry: &mut GSOSProtocolRegistry,
    admin_cap: &GSOSProtocolAdminCap,
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

    event::emit(GSOSProtocolPauseChanged {
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
    registry: &mut GSOSProtocolRegistry,
    admin_cap: &GSOSProtocolAdminCap,
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

    event::emit(GSOSProtocolRegistryVersionChanged {
        registry_id: object::id(registry),
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Protocol Semantic Version Query
   ============================================================ */

public fun is_active_version(
    registry: &GSOSProtocolRegistry,
    protocol_family: u8,
    major_version: u64,
    minor_version: u64,
    patch_version: u64,
): bool {
    let length = vector::length(&registry.protocols);
    let mut i = 0;

    while (i < length) {
        let protocol = vector::borrow(&registry.protocols, i);

        if (
            protocol.status == STATUS_ACTIVE
                && protocol.protocol_family == protocol_family
                && protocol.major_version == major_version
                && protocol.minor_version == minor_version
                && protocol.patch_version == patch_version
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Active Protocol Lookup by Family / Version
   ============================================================ */

public fun active_protocol_id_by_version(
    registry: &GSOSProtocolRegistry,
    protocol_family: u8,
    major_version: u64,
    minor_version: u64,
    patch_version: u64,
): u64 {
    let length = vector::length(&registry.protocols);
    let mut i = 0;

    while (i < length) {
        let protocol = vector::borrow(&registry.protocols, i);

        if (
            protocol.status == STATUS_ACTIVE
                && protocol.protocol_family == protocol_family
                && protocol.major_version == major_version
                && protocol.minor_version == minor_version
                && protocol.patch_version == patch_version
        ) {
            return protocol.protocol_id
        };

        i = i + 1;
    };

    abort E_PROTOCOL_NOT_FOUND
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun destroy_for_testing(
    registry: GSOSProtocolRegistry,
) {
    let GSOSProtocolRegistry {
        id,
        version: _,
        paused: _,
        next_protocol_id: _,
        protocols,
        total_registered: _,
        total_deprecated: _,
        active_protocol_count: _,
    } = registry;

    let mut protocols = protocols;

    while (!vector::is_empty(&protocols)) {
        let protocol = vector::pop_back(&mut protocols);

        let GSOSProtocol {
            protocol_id: _,
            protocol_family: _,
            protocol_name: _,
            major_version: _,
            minor_version: _,
            patch_version: _,
            specification_hash: _,
            compatibility_hash: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = protocol;
    };

    vector::destroy_empty(protocols);
    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSProtocolAdminCap,
) {
    let GSOSProtocolAdminCap {
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
    registry: &GSOSProtocolRegistry,
): ID {
    object::id(registry)
}
