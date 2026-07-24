module tobmate_core::oracle;

use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::TxContext;

/* ============================================================
   Error codes
   ============================================================ */

const E_NOT_ADMIN: u64 = 1;
const E_PROTOCOL_PAUSED: u64 = 2;
const E_PUBLISHER_NOT_FOUND: u64 = 3;
const E_PUBLISHER_INACTIVE: u64 = 4;
const E_INVALID_WEIGHT: u64 = 5;
const E_INVALID_PUBLISHER_CAP: u64 = 6;
const E_INVALID_VERSION: u64 = 7;

/* ============================================================
   Protocol constants
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

/* ============================================================
   Core objects
   ============================================================ */

/// Oracle protocol configuration and publisher registry.
///
/// This object is shared so authorised publishers can later submit
/// observations against it.
public struct OracleRegistry has key {
    id: UID,
    version: u64,
    paused: bool,
    next_publisher_id: u64,
    active_publisher_count: u64,
    total_publisher_count: u64,
    publishers: vector<OraclePublisher>,
}

/// Administrative capability scoped to one OracleRegistry.
public struct OracleAdminCap has key, store {
    id: UID,
    registry_id: ID,
}

/// Publisher capability scoped to one OracleRegistry and publisher ID.
public struct OraclePublisherCap has key, store {
    id: UID,
    registry_id: ID,
    publisher_id: u64,
}

/// Registered oracle publisher information.
public struct OraclePublisher has copy, drop, store {
    publisher_id: u64,
    publisher: address,
    weight: u64,
    active: bool,
}

/* ============================================================
   Registry creation
   ============================================================ */

/// Creates and shares a new OracleRegistry.
///
/// The OracleAdminCap is returned to the caller so it can be transferred,
/// stored, or used in the same programmable transaction.
public fun create_registry(
    ctx: &mut TxContext,
): OracleAdminCap {
    let registry = OracleRegistry {
        id: object::new(ctx),
        version: PROTOCOL_VERSION,
        paused: false,
        next_publisher_id: 1,
        active_publisher_count: 0,
        total_publisher_count: 0,
        publishers: vector[],
    };

    let registry_id = object::id(&registry);

    let admin_cap = OracleAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    transfer::share_object(registry);

    admin_cap
}

/* ============================================================
   Publisher administration
   ============================================================ */

/// Registers a new publisher and returns its publisher capability.
public fun register_publisher(
    registry: &mut OracleRegistry,
    admin_cap: &OracleAdminCap,
    publisher: address,
    weight: u64,
    ctx: &mut TxContext,
): OraclePublisherCap {
    assert_admin(registry, admin_cap);
    assert_active_protocol(registry);
    assert!(weight > 0, E_INVALID_WEIGHT);

    let publisher_id = registry.next_publisher_id;

    vector::push_back(
        &mut registry.publishers,
        OraclePublisher {
            publisher_id,
            publisher,
            weight,
            active: true,
        },
    );

    registry.next_publisher_id = publisher_id + 1;
    registry.active_publisher_count =
        registry.active_publisher_count + 1;
    registry.total_publisher_count =
        registry.total_publisher_count + 1;

    OraclePublisherCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
        publisher_id,
    }
}

/// Activates or deactivates a registered publisher.
public fun set_publisher_status(
    registry: &mut OracleRegistry,
    admin_cap: &OracleAdminCap,
    publisher_id: u64,
    active: bool,
) {
    assert_admin(registry, admin_cap);

    let index = find_publisher_index(registry, publisher_id);
    let publisher = vector::borrow_mut(&mut registry.publishers, index);

    if (publisher.active != active) {
        if (active) {
            registry.active_publisher_count =
                registry.active_publisher_count + 1;
        } else {
            registry.active_publisher_count =
                registry.active_publisher_count - 1;
        };

        publisher.active = active;
    };
}

/// Updates a publisher's aggregation weight.
public fun set_publisher_weight(
    registry: &mut OracleRegistry,
    admin_cap: &OracleAdminCap,
    publisher_id: u64,
    weight: u64,
) {
    assert_admin(registry, admin_cap);
    assert!(weight > 0, E_INVALID_WEIGHT);

    let index = find_publisher_index(registry, publisher_id);
    let publisher = vector::borrow_mut(&mut registry.publishers, index);

    publisher.weight = weight;
}

/* ============================================================
   Protocol administration
   ============================================================ */

/// Pauses or resumes publisher operations.
public fun set_protocol_paused(
    registry: &mut OracleRegistry,
    admin_cap: &OracleAdminCap,
    paused: bool,
) {
    assert_admin(registry, admin_cap);
    registry.paused = paused;
}

/// Updates the stored protocol version.
///
/// Later upgrades can require a specific previous version before migration.
public fun update_version(
    registry: &mut OracleRegistry,
    admin_cap: &OracleAdminCap,
    expected_current_version: u64,
    new_version: u64,
) {
    assert_admin(registry, admin_cap);

    assert!(
        registry.version == expected_current_version,
        E_INVALID_VERSION,
    );

    assert!(
        new_version > expected_current_version,
        E_INVALID_VERSION,
    );

    registry.version = new_version;
}

/* ============================================================
   Capability validation
   ============================================================ */

/// Verifies that a publisher capability belongs to the registry and that
/// the publisher is active.
///
/// Observation submission will call this function in the next stage.
public fun assert_valid_publisher(
    registry: &OracleRegistry,
    publisher_cap: &OraclePublisherCap,
    sender: address,
) {
    assert_active_protocol(registry);

    assert!(
        publisher_cap.registry_id == object::id(registry),
        E_INVALID_PUBLISHER_CAP,
    );

    let index =
        find_publisher_index(registry, publisher_cap.publisher_id);

    let publisher = vector::borrow(&registry.publishers, index);

    assert!(publisher.active, E_PUBLISHER_INACTIVE);

    assert!(
        publisher.publisher == sender,
        E_INVALID_PUBLISHER_CAP,
    );
}

/* ============================================================
   Internal helpers
   ============================================================ */

fun assert_admin(
    registry: &OracleRegistry,
    admin_cap: &OracleAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_NOT_ADMIN,
    );
}

fun assert_active_protocol(registry: &OracleRegistry) {
    assert!(!registry.paused, E_PROTOCOL_PAUSED);
}

fun find_publisher_index(
    registry: &OracleRegistry,
    publisher_id: u64,
): u64 {
    let length = vector::length(&registry.publishers);
    let mut index = 0;

    while (index < length) {
        let publisher =
            vector::borrow(&registry.publishers, index);

        if (publisher.publisher_id == publisher_id) {
            return index
        };

        index = index + 1;
    };

    abort E_PUBLISHER_NOT_FOUND
}

/* ============================================================
   Read-only functions
   ============================================================ */

public fun registry_id(
    registry: &OracleRegistry,
): ID {
    object::id(registry)
}

public fun admin_registry_id(
    admin_cap: &OracleAdminCap,
): ID {
    admin_cap.registry_id
}

public fun publisher_cap_registry_id(
    publisher_cap: &OraclePublisherCap,
): ID {
    publisher_cap.registry_id
}

public fun publisher_cap_id(
    publisher_cap: &OraclePublisherCap,
): u64 {
    publisher_cap.publisher_id
}

public fun protocol_version(): u64 {
    PROTOCOL_VERSION
}

public fun registry_version(
    registry: &OracleRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &OracleRegistry,
): bool {
    registry.paused
}

public fun active_publisher_count(
    registry: &OracleRegistry,
): u64 {
    registry.active_publisher_count
}

public fun total_publisher_count(
    registry: &OracleRegistry,
): u64 {
    registry.total_publisher_count
}

public fun publisher_exists(
    registry: &OracleRegistry,
    publisher_id: u64,
): bool {
    let length = vector::length(&registry.publishers);
    let mut index = 0;

    while (index < length) {
        let publisher =
            vector::borrow(&registry.publishers, index);

        if (publisher.publisher_id == publisher_id) {
            return true
        };

        index = index + 1;
    };

    false
}

public fun publisher_address(
    registry: &OracleRegistry,
    publisher_id: u64,
): address {
    let index = find_publisher_index(registry, publisher_id);
    vector::borrow(&registry.publishers, index).publisher
}

public fun publisher_weight(
    registry: &OracleRegistry,
    publisher_id: u64,
): u64 {
    let index = find_publisher_index(registry, publisher_id);
    vector::borrow(&registry.publishers, index).weight
}

public fun publisher_is_active(
    registry: &OracleRegistry,
    publisher_id: u64,
): bool {
    let index = find_publisher_index(registry, publisher_id);
    vector::borrow(&registry.publishers, index).active
}
