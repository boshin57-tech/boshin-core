module tobmate_enterprise_security::external_network_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_foundation::institution_registry::{
    Self as institution_registry,
    InstitutionRegistry,
};


/* ============================================================
   Stage 12 Part 5-A
   External Network Registry
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Network Types
   ============================================================ */

const NETWORK_BLOCKCHAIN: u8 = 1;
const NETWORK_BANK_RAIL: u8 = 2;
const NETWORK_CUSTODIAN_RAIL: u8 = 3;
const NETWORK_CLEARING_NETWORK: u8 = 4;
const NETWORK_CBDC_NETWORK: u8 = 5;
const NETWORK_INSTITUTIONAL_LEDGER: u8 = 6;


/* ============================================================
   Network Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_RETIRED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_NETWORK_TYPE: u64 = 2;
const E_EMPTY_NETWORK_KEY: u64 = 3;
const E_EMPTY_DOMAIN: u64 = 4;
const E_DUPLICATE_NETWORK: u64 = 5;
const E_NETWORK_NOT_FOUND: u64 = 6;
const E_NETWORK_NOT_ACTIVE: u64 = 7;
const E_INVALID_STATUS_TRANSITION: u64 = 8;
const E_VERSION_NOT_INCREASING: u64 = 9;
const E_ADMIN_CAP_MISMATCH: u64 = 10;
const E_OPERATOR_MISMATCH: u64 = 11;


/* ============================================================
   Registry
   ============================================================ */

public struct ExternalNetworkRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_network_id: u64,

    networks: vector<ExternalNetworkRecord>,

    total_networks: u64,
    active_network_count: u64,
    suspended_network_count: u64,
    retired_network_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct ExternalNetworkAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   External Network Record
   ============================================================ */

public struct ExternalNetworkRecord has store {
    network_id: u64,

    network_key: vector<u8>,
    domain: vector<u8>,

    network_type: u8,

    operator_institution_id: u64,
    operator_authority: address,

    status: u8,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct ExternalNetworkRegistered has copy, drop {
    registry_id: ID,
    network_id: u64,
    network_type: u8,
    operator_institution_id: u64,
    operator_authority: address,
}

public struct ExternalNetworkStatusChanged has copy, drop {
    registry_id: ID,
    network_id: u64,
    previous_status: u8,
    new_status: u8,
    changed_by: address,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    ExternalNetworkRegistry,
    ExternalNetworkAdminCap,
) {
    let registry =
        ExternalNetworkRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_network_id:
                1,

            networks:
                vector[],

            total_networks:
                0,

            active_network_count:
                0,

            suspended_network_count:
                0,

            retired_network_count:
                0,
        };

    let admin_cap =
        ExternalNetworkAdminCap {
            id: object::new(ctx),

            registry_id:
                object::id(&registry),
        };

    (
        registry,
        admin_cap,
    )
}


/* ============================================================
   Guards
   ============================================================ */

public fun assert_operational(
    access: &AccessControl,
    registry: &ExternalNetworkRegistry,
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
    registry: &ExternalNetworkRegistry,
    admin_cap: &ExternalNetworkAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_network_type(
    network_type: u8,
) {
    assert!(
        network_type == NETWORK_BLOCKCHAIN
            || network_type == NETWORK_BANK_RAIL
            || network_type == NETWORK_CUSTODIAN_RAIL
            || network_type == NETWORK_CLEARING_NETWORK
            || network_type == NETWORK_CBDC_NETWORK
            || network_type == NETWORK_INSTITUTIONAL_LEDGER,
        E_INVALID_NETWORK_TYPE,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun network_index(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.networks,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.networks,
                i,
            );

        if (
            record.network_id == network_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_NETWORK_NOT_FOUND
}

fun network_key_exists(
    registry: &ExternalNetworkRegistry,
    network_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.networks,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.networks,
                i,
            );

        if (
            record.network_key == *network_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   External Network Registration
   ============================================================ */

public fun register_network(
    access: &AccessControl,

    registry: &mut ExternalNetworkRegistry,
    admin_cap: &ExternalNetworkAdminCap,

    institution_registry_obj: &InstitutionRegistry,

    network_key: vector<u8>,
    domain: vector<u8>,

    network_type: u8,
    operator_institution_id: u64,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert_admin(
        registry,
        admin_cap,
    );

    assert_valid_network_type(
        network_type,
    );

    institution_registry::assert_institution_active(
        institution_registry_obj,
        operator_institution_id,
    );

    assert!(
        vector::length(&network_key) > 0,
        E_EMPTY_NETWORK_KEY,
    );

    assert!(
        vector::length(&domain) > 0,
        E_EMPTY_DOMAIN,
    );

    assert!(
        !network_key_exists(
            registry,
            &network_key,
        ),
        E_DUPLICATE_NETWORK,
    );

    let operator_authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            operator_institution_id,
        );

    let network_id =
        registry.next_network_id;

    registry.next_network_id =
        network_id + 1;

    vector::push_back(
        &mut registry.networks,

        ExternalNetworkRecord {
            network_id,

            network_key,
            domain,

            network_type,

            operator_institution_id,
            operator_authority,

            status:
                STATUS_ACTIVE,

            version:
                1,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_networks =
        registry.total_networks + 1;

    registry.active_network_count =
        registry.active_network_count + 1;

    event::emit(
        ExternalNetworkRegistered {
            registry_id:
                object::id(registry),

            network_id,
            network_type,

            operator_institution_id,
            operator_authority,
        },
    );

    network_id
}


/* ============================================================
   Network Status Lifecycle
   ============================================================ */

public fun set_network_status(
    access: &AccessControl,

    registry: &mut ExternalNetworkRegistry,
    admin_cap: &ExternalNetworkAdminCap,

    network_id: u64,
    new_status: u8,

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
        network_index(
            registry,
            network_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.networks,
            index,
        );

    let previous_status =
        record.status;

    assert!(
        new_status == STATUS_ACTIVE
            || new_status == STATUS_SUSPENDED
            || new_status == STATUS_RETIRED,
        E_INVALID_STATUS_TRANSITION,
    );

    assert!(
        previous_status != new_status,
        E_INVALID_STATUS_TRANSITION,
    );

    assert!(
        previous_status != STATUS_RETIRED,
        E_INVALID_STATUS_TRANSITION,
    );

    if (previous_status == STATUS_ACTIVE) {
        registry.active_network_count =
            registry.active_network_count - 1;
    } else {
        registry.suspended_network_count =
            registry.suspended_network_count - 1;
    };

    if (new_status == STATUS_ACTIVE) {
        registry.active_network_count =
            registry.active_network_count + 1;
    } else if (new_status == STATUS_SUSPENDED) {
        registry.suspended_network_count =
            registry.suspended_network_count + 1;
    } else {
        registry.retired_network_count =
            registry.retired_network_count + 1;
    };

    record.status =
        new_status;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        ExternalNetworkStatusChanged {
            registry_id:
                object::id(registry),

            network_id,
            previous_status,
            new_status,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Network Validation / Read API
   ============================================================ */

public fun assert_network_active(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
) {
    let index =
        network_index(
            registry,
            network_id,
        );

    let record =
        vector::borrow(
            &registry.networks,
            index,
        );

    assert!(
        record.status == STATUS_ACTIVE,
        E_NETWORK_NOT_ACTIVE,
    );
}

public fun network_status(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
): u8 {
    let index =
        network_index(
            registry,
            network_id,
        );

    vector::borrow(
        &registry.networks,
        index,
    ).status
}

public fun network_type(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
): u8 {
    let index =
        network_index(
            registry,
            network_id,
        );

    vector::borrow(
        &registry.networks,
        index,
    ).network_type
}

public fun network_domain(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
): vector<u8> {
    let index =
        network_index(
            registry,
            network_id,
        );

    vector::borrow(
        &registry.networks,
        index,
    ).domain
}

public fun operator_institution_id(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
): u64 {
    let index =
        network_index(
            registry,
            network_id,
        );

    vector::borrow(
        &registry.networks,
        index,
    ).operator_institution_id
}

public fun operator_authority(
    registry: &ExternalNetworkRegistry,
    network_id: u64,
): address {
    let index =
        network_index(
            registry,
            network_id,
        );

    vector::borrow(
        &registry.networks,
        index,
    ).operator_authority
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &ExternalNetworkAdminCap,
    registry: &mut ExternalNetworkRegistry,
    paused: bool,
    _ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        registry.paused != paused,
        E_INVALID_STATUS_TRANSITION,
    );

    registry.paused =
        paused;
}

public fun set_version(
    admin_cap: &ExternalNetworkAdminCap,
    registry: &mut ExternalNetworkRegistry,
    new_version: u64,
    _ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_version > registry.version,
        E_VERSION_NOT_INCREASING,
    );

    registry.version =
        new_version;
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun registry_id(
    registry: &ExternalNetworkRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &ExternalNetworkRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &ExternalNetworkRegistry,
): bool {
    registry.paused
}

public fun total_networks(
    registry: &ExternalNetworkRegistry,
): u64 {
    registry.total_networks
}

public fun active_network_count(
    registry: &ExternalNetworkRegistry,
): u64 {
    registry.active_network_count
}

public fun suspended_network_count(
    registry: &ExternalNetworkRegistry,
): u64 {
    registry.suspended_network_count
}

public fun retired_network_count(
    registry: &ExternalNetworkRegistry,
): u64 {
    registry.retired_network_count
}


/* ============================================================
   Network Type API
   ============================================================ */

public fun network_blockchain(): u8 {
    NETWORK_BLOCKCHAIN
}

public fun network_bank_rail(): u8 {
    NETWORK_BANK_RAIL
}

public fun network_custodian_rail(): u8 {
    NETWORK_CUSTODIAN_RAIL
}

public fun network_clearing_network(): u8 {
    NETWORK_CLEARING_NETWORK
}

public fun network_cbdc_network(): u8 {
    NETWORK_CBDC_NETWORK
}

public fun network_institutional_ledger(): u8 {
    NETWORK_INSTITUTIONAL_LEDGER
}


/* ============================================================
   Status API
   ============================================================ */

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_suspended(): u8 {
    STATUS_SUSPENDED
}

public fun status_retired(): u8 {
    STATUS_RETIRED
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): ExternalNetworkRegistry {
    ExternalNetworkRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_network_id:
            1,

        networks:
            vector[],

        total_networks:
            0,

        active_network_count:
            0,

        suspended_network_count:
            0,

        retired_network_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &ExternalNetworkRegistry,
    ctx: &mut TxContext,
): ExternalNetworkAdminCap {
    ExternalNetworkAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: ExternalNetworkRegistry,
) {
    let ExternalNetworkRegistry {
        id,

        version: _,
        paused: _,

        next_network_id: _,

        networks,

        total_networks: _,
        active_network_count: _,
        suspended_network_count: _,
        retired_network_count: _,
    } = registry;

    let mut networks =
        networks;

    while (
        !vector::is_empty(
            &networks,
        )
    ) {
        let record =
            vector::pop_back(
                &mut networks,
            );

        let ExternalNetworkRecord {
            network_id: _,

            network_key: _,
            domain: _,

            network_type: _,

            operator_institution_id: _,
            operator_authority: _,

            status: _,
            version: _,

            created_epoch: _,
            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        networks,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: ExternalNetworkAdminCap,
) {
    let ExternalNetworkAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
