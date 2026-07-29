module tobmate_foundation::institution_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};


/* ============================================================
   Stage 12 Part 3-A
   Bank / Institutional Registry
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Institution Types
   ============================================================ */

const INSTITUTION_BANK: u8 = 1;
const INSTITUTION_TRUST: u8 = 2;
const INSTITUTION_BROKER_DEALER: u8 = 3;
const INSTITUTION_ETF_ISSUER: u8 = 4;
const INSTITUTION_PAYMENT_PROVIDER: u8 = 5;
const INSTITUTION_CBDC_OPERATOR: u8 = 6;
const INSTITUTION_CLEARING_HOUSE: u8 = 7;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_INSTITUTION_TYPE: u64 = 2;
const E_EMPTY_INSTITUTION_KEY: u64 = 3;
const E_EMPTY_JURISDICTION: u64 = 4;
const E_DUPLICATE_INSTITUTION: u64 = 5;
const E_INSTITUTION_NOT_FOUND: u64 = 6;
const E_INSTITUTION_INACTIVE: u64 = 7;
const E_STATE_UNCHANGED: u64 = 8;
const E_VERSION_NOT_INCREASING: u64 = 9;
const E_ADMIN_CAP_MISMATCH: u64 = 10;


/* ============================================================
   Registry
   ============================================================ */

public struct InstitutionRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_institution_id: u64,

    institutions: vector<InstitutionRecord>,

    total_institutions: u64,
    active_institution_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct InstitutionAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Institution Record
   ============================================================ */

public struct InstitutionRecord has store {
    institution_id: u64,

    institution_key: vector<u8>,
    authority: address,

    institution_type: u8,
    jurisdiction: vector<u8>,

    active: bool,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct InstitutionRegistered has copy, drop {
    registry_id: ID,
    institution_id: u64,
    authority: address,
    institution_type: u8,
    created_epoch: u64,
}

public struct InstitutionStatusChanged has copy, drop {
    registry_id: ID,
    institution_id: u64,
    active: bool,
    changed_by: address,
}

public struct InstitutionPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct InstitutionVersionChanged has copy, drop {
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
    InstitutionRegistry,
    InstitutionAdminCap,
) {
    let registry =
        InstitutionRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_institution_id:
                1,

            institutions:
                vector[],

            total_institutions:
                0,

            active_institution_count:
                0,
        };

    let registry_id =
        object::id(
            &registry,
        );

    let admin_cap =
        InstitutionAdminCap {
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
    registry: &InstitutionRegistry,
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
    registry: &InstitutionRegistry,
    admin_cap: &InstitutionAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_institution_type(
    institution_type: u8,
) {
    assert!(
        institution_type == INSTITUTION_BANK
            || institution_type == INSTITUTION_TRUST
            || institution_type == INSTITUTION_BROKER_DEALER
            || institution_type == INSTITUTION_ETF_ISSUER
            || institution_type == INSTITUTION_PAYMENT_PROVIDER
            || institution_type == INSTITUTION_CBDC_OPERATOR
            || institution_type == INSTITUTION_CLEARING_HOUSE,
        E_INVALID_INSTITUTION_TYPE,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun institution_index(
    registry: &InstitutionRegistry,
    institution_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.institutions,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.institutions,
                i,
            );

        if (
            record.institution_id
                == institution_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_INSTITUTION_NOT_FOUND
}

fun contains_institution_key(
    registry: &InstitutionRegistry,
    institution_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.institutions,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.institutions,
                i,
            );

        if (
            record.institution_key
                == *institution_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Institution Registration
   ============================================================ */

public fun register_institution(
    access: &AccessControl,
    registry: &mut InstitutionRegistry,
    admin_cap: &InstitutionAdminCap,

    institution_key: vector<u8>,
    authority: address,

    institution_type: u8,
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

    assert_valid_institution_type(
        institution_type,
    );

    assert!(
        vector::length(&institution_key) > 0,
        E_EMPTY_INSTITUTION_KEY,
    );

    assert!(
        vector::length(&jurisdiction) > 0,
        E_EMPTY_JURISDICTION,
    );

    assert!(
        !contains_institution_key(
            registry,
            &institution_key,
        ),
        E_DUPLICATE_INSTITUTION,
    );

    let institution_id =
        registry.next_institution_id;

    registry.next_institution_id =
        institution_id + 1;

    vector::push_back(
        &mut registry.institutions,

        InstitutionRecord {
            institution_id,
            institution_key,
            authority,

            institution_type,
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

    registry.total_institutions =
        registry.total_institutions + 1;

    registry.active_institution_count =
        registry.active_institution_count + 1;

    event::emit(
        InstitutionRegistered {
            registry_id:
                object::id(registry),

            institution_id,
            authority,
            institution_type,

            created_epoch:
                tx_context::epoch(ctx),
        },
    );

    institution_id
}


/* ============================================================
   Institution Status
   ============================================================ */

public fun set_institution_active(
    access: &AccessControl,
    registry: &mut InstitutionRegistry,
    admin_cap: &InstitutionAdminCap,

    institution_id: u64,
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
        institution_index(
            registry,
            institution_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.institutions,
            index,
        );

    assert!(
        record.active != active,
        E_STATE_UNCHANGED,
    );

    if (active) {
        registry.active_institution_count =
            registry.active_institution_count + 1;
    } else {
        registry.active_institution_count =
            registry.active_institution_count - 1;
    };

    record.active =
        active;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        InstitutionStatusChanged {
            registry_id:
                object::id(registry),

            institution_id,
            active,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Institution Validation / Read API
   ============================================================ */

public fun assert_institution_active(
    registry: &InstitutionRegistry,
    institution_id: u64,
) {
    let index =
        institution_index(
            registry,
            institution_id,
        );

    let record =
        vector::borrow(
            &registry.institutions,
            index,
        );

    assert!(
        record.active,
        E_INSTITUTION_INACTIVE,
    );
}

public fun institution_authority(
    registry: &InstitutionRegistry,
    institution_id: u64,
): address {
    let index =
        institution_index(
            registry,
            institution_id,
        );

    vector::borrow(
        &registry.institutions,
        index,
    ).authority
}

public fun institution_type(
    registry: &InstitutionRegistry,
    institution_id: u64,
): u8 {
    let index =
        institution_index(
            registry,
            institution_id,
        );

    vector::borrow(
        &registry.institutions,
        index,
    ).institution_type
}

public fun institution_jurisdiction(
    registry: &InstitutionRegistry,
    institution_id: u64,
): vector<u8> {
    let index =
        institution_index(
            registry,
            institution_id,
        );

    vector::borrow(
        &registry.institutions,
        index,
    ).jurisdiction
}

public fun institution_is_active(
    registry: &InstitutionRegistry,
    institution_id: u64,
): bool {
    let index =
        institution_index(
            registry,
            institution_id,
        );

    vector::borrow(
        &registry.institutions,
        index,
    ).active
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &InstitutionAdminCap,
    registry: &mut InstitutionRegistry,
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
        InstitutionPauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}

public fun set_version(
    admin_cap: &InstitutionAdminCap,
    registry: &mut InstitutionRegistry,
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
        InstitutionVersionChanged {
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
    registry: &InstitutionRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &InstitutionRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &InstitutionRegistry,
): bool {
    registry.paused
}

public fun total_institutions(
    registry: &InstitutionRegistry,
): u64 {
    registry.total_institutions
}

public fun active_institution_count(
    registry: &InstitutionRegistry,
): u64 {
    registry.active_institution_count
}


/* ============================================================
   Institution Type API
   ============================================================ */

public fun institution_bank(): u8 {
    INSTITUTION_BANK
}

public fun institution_trust(): u8 {
    INSTITUTION_TRUST
}

public fun institution_broker_dealer(): u8 {
    INSTITUTION_BROKER_DEALER
}

public fun institution_etf_issuer(): u8 {
    INSTITUTION_ETF_ISSUER
}

public fun institution_payment_provider(): u8 {
    INSTITUTION_PAYMENT_PROVIDER
}

public fun institution_cbdc_operator(): u8 {
    INSTITUTION_CBDC_OPERATOR
}

public fun institution_clearing_house(): u8 {
    INSTITUTION_CLEARING_HOUSE
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): InstitutionRegistry {
    InstitutionRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_institution_id:
            1,

        institutions:
            vector[],

        total_institutions:
            0,

        active_institution_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &InstitutionRegistry,
    ctx: &mut TxContext,
): InstitutionAdminCap {
    InstitutionAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: InstitutionRegistry,
) {
    let InstitutionRegistry {
        id,

        version: _,
        paused: _,

        next_institution_id: _,

        institutions,

        total_institutions: _,
        active_institution_count: _,
    } = registry;

    let mut institutions =
        institutions;

    while (
        !vector::is_empty(
            &institutions,
        )
    ) {
        let record =
            vector::pop_back(
                &mut institutions,
            );

        let InstitutionRecord {
            institution_id: _,

            institution_key: _,
            authority: _,

            institution_type: _,
            jurisdiction: _,

            active: _,
            version: _,

            created_epoch: _,
            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        institutions,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: InstitutionAdminCap,
) {
    let InstitutionAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
