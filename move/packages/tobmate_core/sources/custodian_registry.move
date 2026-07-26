module tobmate_core::custodian_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};


/* ============================================================
   Stage 12 Part 2-A
   Custodian Registry
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Custodian Types
   ============================================================ */

const CUSTODIAN_BANK: u8 = 1;
const CUSTODIAN_VAULT: u8 = 2;
const CUSTODIAN_TRUST: u8 = 3;
const CUSTODIAN_INSTITUTIONAL: u8 = 4;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_CUSTODIAN_TYPE: u64 = 2;
const E_EMPTY_CUSTODIAN_KEY: u64 = 3;
const E_EMPTY_JURISDICTION: u64 = 4;
const E_DUPLICATE_CUSTODIAN: u64 = 5;
const E_CUSTODIAN_NOT_FOUND: u64 = 6;
const E_STATE_UNCHANGED: u64 = 7;
const E_VERSION_NOT_INCREASING: u64 = 8;
const E_ADMIN_CAP_MISMATCH: u64 = 9;


/* ============================================================
   Registry
   ============================================================ */

public struct CustodianRegistry has key {
    id: UID,
    version: u64,
    paused: bool,

    next_custodian_id: u64,
    custodians: vector<CustodianRecord>,

    total_custodians: u64,
    active_custodian_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct CustodianAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Custodian Record
   ============================================================ */

public struct CustodianRecord has store {
    custodian_id: u64,

    custodian_key: vector<u8>,
    authority: address,

    custodian_type: u8,
    jurisdiction: vector<u8>,

    active: bool,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct CustodianRegistered has copy, drop {
    registry_id: ID,
    custodian_id: u64,
    authority: address,
    custodian_type: u8,
    created_epoch: u64,
}

public struct CustodianStatusChanged has copy, drop {
    registry_id: ID,
    custodian_id: u64,
    active: bool,
    changed_by: address,
}

public struct CustodianPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct CustodianVersionChanged has copy, drop {
    registry_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    CustodianRegistry,
    CustodianAdminCap,
) {
    let registry =
        CustodianRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_custodian_id:
                1,

            custodians:
                vector[],

            total_custodians:
                0,

            active_custodian_count:
                0,
        };

    let registry_id =
        object::id(
            &registry,
        );

    let admin_cap =
        CustodianAdminCap {
            id: object::new(ctx),
            registry_id,
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
    registry: &CustodianRegistry,
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
    registry: &CustodianRegistry,
    admin_cap: &CustodianAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_custodian_type(
    custodian_type: u8,
) {
    assert!(
        custodian_type == CUSTODIAN_BANK
            || custodian_type == CUSTODIAN_VAULT
            || custodian_type == CUSTODIAN_TRUST
            || custodian_type == CUSTODIAN_INSTITUTIONAL,
        E_INVALID_CUSTODIAN_TYPE,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun custodian_index(
    registry: &CustodianRegistry,
    custodian_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.custodians,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.custodians,
                i,
            );

        if (
            record.custodian_id
                == custodian_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_CUSTODIAN_NOT_FOUND
}


fun contains_custodian_key(
    registry: &CustodianRegistry,
    custodian_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.custodians,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.custodians,
                i,
            );

        if (
            record.custodian_key
                == *custodian_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Custodian Registration
   ============================================================ */

public fun register_custodian(
    access: &AccessControl,
    registry: &mut CustodianRegistry,
    admin_cap: &CustodianAdminCap,

    custodian_key: vector<u8>,
    authority: address,

    custodian_type: u8,
    jurisdiction: vector<u8>,

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

    assert_valid_custodian_type(
        custodian_type,
    );

    assert!(
        vector::length(&custodian_key) > 0,
        E_EMPTY_CUSTODIAN_KEY,
    );

    assert!(
        vector::length(&jurisdiction) > 0,
        E_EMPTY_JURISDICTION,
    );

    assert!(
        !contains_custodian_key(
            registry,
            &custodian_key,
        ),
        E_DUPLICATE_CUSTODIAN,
    );

    let custodian_id =
        registry.next_custodian_id;

    registry.next_custodian_id =
        custodian_id + 1;

    vector::push_back(
        &mut registry.custodians,

        CustodianRecord {
            custodian_id,

            custodian_key,
            authority,

            custodian_type,
            jurisdiction,

            active:
                true,

            version:
                1,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_custodians =
        registry.total_custodians + 1;

    registry.active_custodian_count =
        registry.active_custodian_count + 1;

    event::emit(
        CustodianRegistered {
            registry_id:
                object::id(registry),

            custodian_id,
            authority,
            custodian_type,

            created_epoch:
                tx_context::epoch(ctx),
        },
    );

    custodian_id
}


/* ============================================================
   Custodian Status
   ============================================================ */

public fun set_custodian_active(
    access: &AccessControl,
    registry: &mut CustodianRegistry,
    admin_cap: &CustodianAdminCap,

    custodian_id: u64,
    active: bool,

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
        custodian_index(
            registry,
            custodian_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.custodians,
            index,
        );

    assert!(
        record.active != active,
        E_STATE_UNCHANGED,
    );

    if (active) {
        registry.active_custodian_count =
            registry.active_custodian_count + 1;
    } else {
        registry.active_custodian_count =
            registry.active_custodian_count - 1;
    };

    record.active = active;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        CustodianStatusChanged {
            registry_id:
                object::id(registry),

            custodian_id,
            active,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Custodian Validation / Read API
   ============================================================ */

public fun assert_custodian_active(
    registry: &CustodianRegistry,
    custodian_id: u64,
) {
    let index =
        custodian_index(
            registry,
            custodian_id,
        );

    let record =
        vector::borrow(
            &registry.custodians,
            index,
        );

    assert!(
        record.active,
        E_CUSTODIAN_NOT_FOUND,
    );
}

public fun custodian_authority(
    registry: &CustodianRegistry,
    custodian_id: u64,
): address {
    let index =
        custodian_index(
            registry,
            custodian_id,
        );

    vector::borrow(
        &registry.custodians,
        index,
    ).authority
}

public fun custodian_jurisdiction(
    registry: &CustodianRegistry,
    custodian_id: u64,
): vector<u8> {
    let index =
        custodian_index(
            registry,
            custodian_id,
        );

    vector::borrow(
        &registry.custodians,
        index,
    ).jurisdiction
}

public fun custodian_is_active(
    registry: &CustodianRegistry,
    custodian_id: u64,
): bool {
    let index =
        custodian_index(
            registry,
            custodian_id,
        );

    vector::borrow(
        &registry.custodians,
        index,
    ).active
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &CustodianAdminCap,
    registry: &mut CustodianRegistry,
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

    registry.paused = paused;

    event::emit(
        CustodianPauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}

public fun set_version(
    admin_cap: &CustodianAdminCap,
    registry: &mut CustodianRegistry,
    new_version: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_version > registry.version,
        E_VERSION_NOT_INCREASING,
    );

    let previous_version =
        registry.version;

    registry.version =
        new_version;

    event::emit(
        CustodianVersionChanged {
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
   Registry Read API
   ============================================================ */

public fun registry_id(
    registry: &CustodianRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &CustodianRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &CustodianRegistry,
): bool {
    registry.paused
}

public fun total_custodians(
    registry: &CustodianRegistry,
): u64 {
    registry.total_custodians
}

public fun active_custodian_count(
    registry: &CustodianRegistry,
): u64 {
    registry.active_custodian_count
}


/* ============================================================
   Custodian Type API
   ============================================================ */

public fun custodian_bank(): u8 {
    CUSTODIAN_BANK
}

public fun custodian_vault(): u8 {
    CUSTODIAN_VAULT
}

public fun custodian_trust(): u8 {
    CUSTODIAN_TRUST
}

public fun custodian_institutional(): u8 {
    CUSTODIAN_INSTITUTIONAL
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): CustodianRegistry {
    CustodianRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_custodian_id:
            1,

        custodians:
            vector[],

        total_custodians:
            0,

        active_custodian_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &CustodianRegistry,
    ctx: &mut TxContext,
): CustodianAdminCap {
    CustodianAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: CustodianRegistry,
) {
    let CustodianRegistry {
        id,

        version: _,
        paused: _,

        next_custodian_id: _,

        custodians,

        total_custodians: _,
        active_custodian_count: _,
    } = registry;

    let mut custodians =
        custodians;

    while (
        !vector::is_empty(
            &custodians,
        )
    ) {
        let record =
            vector::pop_back(
                &mut custodians,
            );

        let CustodianRecord {
            custodian_id: _,

            custodian_key: _,
            authority: _,

            custodian_type: _,
            jurisdiction: _,

            active: _,
            version: _,

            created_epoch: _,
            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        custodians,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: CustodianAdminCap,
) {
    let CustodianAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
