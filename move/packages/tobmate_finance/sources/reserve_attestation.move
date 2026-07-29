module tobmate_finance::reserve_attestation;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_asset::gold_reserve::{
    Self as gold_reserve,
    GoldReserve,
};

use tobmate_foundation::custodian_registry::{
    Self as custodian_registry,
    CustodianRegistry,
};


/* ============================================================
   Stage 12 Part 2-B
   Reserve Attestation Control Plane
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Attestation Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_REVOKED: u8 = 2;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_EMPTY_ATTESTOR_KEY: u64 = 2;
const E_EMPTY_ATTESTATION_HASH: u64 = 3;
const E_ZERO_ATTESTED_WEIGHT: u64 = 4;
const E_INVALID_EXPIRY: u64 = 5;
const E_RESERVE_NOT_ACTIVE: u64 = 6;
const E_CUSTODIAN_INACTIVE: u64 = 7;
const E_CUSTODIAN_RESERVE_MISMATCH: u64 = 8;
const E_ATTESTOR_NOT_FOUND: u64 = 9;
const E_ATTESTOR_INACTIVE: u64 = 10;
const E_ATTESTOR_AUTHORITY_MISMATCH: u64 = 11;
const E_DUPLICATE_ATTESTOR: u64 = 12;
const E_DUPLICATE_ACTIVE_ATTESTATION: u64 = 13;
const E_ATTESTATION_NOT_FOUND: u64 = 14;
const E_ATTESTATION_ALREADY_REVOKED: u64 = 15;
const E_ATTESTATION_EXPIRED: u64 = 16;
const E_STATE_UNCHANGED: u64 = 17;
const E_VERSION_NOT_INCREASING: u64 = 18;
const E_ADMIN_CAP_MISMATCH: u64 = 19;
const E_ATTESTED_WEIGHT_EXCEEDS_RESERVE: u64 = 20;


/* ============================================================
   Registry
   ============================================================ */

public struct ReserveAttestationRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_attestor_id: u64,
    next_attestation_id: u64,

    attestors: vector<AttestorRecord>,
    attestations: vector<ReserveAttestation>,

    total_attestors: u64,
    active_attestor_count: u64,

    total_attestations: u64,
    active_attestation_count: u64,
    revoked_attestation_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct ReserveAttestationAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Attestor
   ============================================================ */

public struct AttestorRecord has store {
    attestor_id: u64,

    attestor_key: vector<u8>,
    authority: address,

    active: bool,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Reserve Attestation
   ============================================================ */

public struct ReserveAttestation has store {
    attestation_id: u64,

    reserve_id: ID,
    reserve_custodian: address,

    custodian_id: u64,
    attestor_id: u64,

    attestation_hash: vector<u8>,

    attested_weight_mg: u64,
    reserve_gross_weight_mg: u64,
    reserve_purity_bps: u64,

    reserve_last_audit_epoch: u64,

    issued_epoch: u64,
    expires_epoch: u64,

    status: u8,
    version: u64,

    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct AttestorRegistered has copy, drop {
    registry_id: ID,
    attestor_id: u64,
    authority: address,
    created_epoch: u64,
}

public struct AttestorStatusChanged has copy, drop {
    registry_id: ID,
    attestor_id: u64,
    active: bool,
    changed_by: address,
}

public struct ReserveAttestationCreated has copy, drop {
    registry_id: ID,
    attestation_id: u64,
    reserve_id: ID,
    custodian_id: u64,
    attestor_id: u64,
    attested_weight_mg: u64,
    expires_epoch: u64,
}

public struct ReserveAttestationRevoked has copy, drop {
    registry_id: ID,
    attestation_id: u64,
    revoked_by: address,
    revoked_epoch: u64,
}

public struct ReserveAttestationPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct ReserveAttestationVersionChanged has copy, drop {
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
    ReserveAttestationRegistry,
    ReserveAttestationAdminCap,
) {
    let registry =
        ReserveAttestationRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_attestor_id:
                1,

            next_attestation_id:
                1,

            attestors:
                vector[],

            attestations:
                vector[],

            total_attestors:
                0,

            active_attestor_count:
                0,

            total_attestations:
                0,

            active_attestation_count:
                0,

            revoked_attestation_count:
                0,
        };

    let registry_id =
        object::id(
            &registry,
        );

    let admin_cap =
        ReserveAttestationAdminCap {
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
    registry: &ReserveAttestationRegistry,
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
    registry: &ReserveAttestationRegistry,
    admin_cap: &ReserveAttestationAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun attestor_index(
    registry: &ReserveAttestationRegistry,
    attestor_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.attestors,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.attestors,
                i,
            );

        if (
            record.attestor_id
                == attestor_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_ATTESTOR_NOT_FOUND
}

fun attestation_index(
    registry: &ReserveAttestationRegistry,
    attestation_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.attestations,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.attestations,
                i,
            );

        if (
            record.attestation_id
                == attestation_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_ATTESTATION_NOT_FOUND
}

fun contains_attestor_key(
    registry: &ReserveAttestationRegistry,
    attestor_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.attestors,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.attestors,
                i,
            );

        if (
            record.attestor_key
                == *attestor_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}

fun has_active_attestation(
    registry: &ReserveAttestationRegistry,
    reserve_id: ID,
    custodian_id: u64,
): bool {
    let length =
        vector::length(
            &registry.attestations,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.attestations,
                i,
            );

        if (
            record.reserve_id == reserve_id
                && record.custodian_id == custodian_id
                && record.status == STATUS_ACTIVE
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Attestor Registration
   ============================================================ */

public fun register_attestor(
    access: &AccessControl,
    registry: &mut ReserveAttestationRegistry,
    admin_cap: &ReserveAttestationAdminCap,

    attestor_key: vector<u8>,
    authority: address,

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

    assert!(
        vector::length(&attestor_key) > 0,
        E_EMPTY_ATTESTOR_KEY,
    );

    assert!(
        !contains_attestor_key(
            registry,
            &attestor_key,
        ),
        E_DUPLICATE_ATTESTOR,
    );

    let attestor_id =
        registry.next_attestor_id;

    registry.next_attestor_id =
        attestor_id + 1;

    vector::push_back(
        &mut registry.attestors,

        AttestorRecord {
            attestor_id,
            attestor_key,
            authority,

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

    registry.total_attestors =
        registry.total_attestors + 1;

    registry.active_attestor_count =
        registry.active_attestor_count + 1;

    event::emit(
        AttestorRegistered {
            registry_id:
                object::id(registry),

            attestor_id,
            authority,

            created_epoch:
                tx_context::epoch(ctx),
        },
    );

    attestor_id
}


/* ============================================================
   Attestor Status
   ============================================================ */

public fun set_attestor_active(
    access: &AccessControl,
    registry: &mut ReserveAttestationRegistry,
    admin_cap: &ReserveAttestationAdminCap,

    attestor_id: u64,
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
        attestor_index(
            registry,
            attestor_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.attestors,
            index,
        );

    assert!(
        record.active != active,
        E_STATE_UNCHANGED,
    );

    if (active) {
        registry.active_attestor_count =
            registry.active_attestor_count + 1;
    } else {
        registry.active_attestor_count =
            registry.active_attestor_count - 1;
    };

    record.active =
        active;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        AttestorStatusChanged {
            registry_id:
                object::id(registry),

            attestor_id,
            active,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Reserve Attestation Creation
   ============================================================ */

public fun create_attestation(
    access: &AccessControl,
    registry: &mut ReserveAttestationRegistry,

    custodian_registry_obj: &CustodianRegistry,
    reserve: &GoldReserve,

    custodian_id: u64,
    attestor_id: u64,

    attestation_hash: vector<u8>,
    attested_weight_mg: u64,
    expires_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert!(
        gold_reserve::is_active(
            reserve,
        ),
        E_RESERVE_NOT_ACTIVE,
    );

    custodian_registry::assert_custodian_active(
        custodian_registry_obj,
        custodian_id,
    );

    let custodian_authority =
        custodian_registry::custodian_authority(
            custodian_registry_obj,
            custodian_id,
        );

    assert!(
        custodian_authority
            == gold_reserve::custodian(
                reserve,
            ),
        E_CUSTODIAN_RESERVE_MISMATCH,
    );

    let attestor_index_value =
        attestor_index(
            registry,
            attestor_id,
        );

    let attestor =
        vector::borrow(
            &registry.attestors,
            attestor_index_value,
        );

    assert!(
        attestor.active,
        E_ATTESTOR_INACTIVE,
    );

    assert!(
        attestor.authority
            == tx_context::sender(ctx),
        E_ATTESTOR_AUTHORITY_MISMATCH,
    );

    assert!(
        vector::length(
            &attestation_hash,
        ) > 0,
        E_EMPTY_ATTESTATION_HASH,
    );

    assert!(
        attested_weight_mg > 0,
        E_ZERO_ATTESTED_WEIGHT,
    );

    let reserve_weight =
        gold_reserve::gross_weight_mg(
            reserve,
        );

    assert!(
        attested_weight_mg
            <= reserve_weight,
        E_ATTESTED_WEIGHT_EXCEEDS_RESERVE,
    );

    assert!(
        expires_epoch
            > tx_context::epoch(ctx),
        E_INVALID_EXPIRY,
    );

    let reserve_id =
        gold_reserve::reserve_id(
            reserve,
        );

    assert!(
        !has_active_attestation(
            registry,
            reserve_id,
            custodian_id,
        ),
        E_DUPLICATE_ACTIVE_ATTESTATION,
    );

    let attestation_id =
        registry.next_attestation_id;

    registry.next_attestation_id =
        attestation_id + 1;

    vector::push_back(
        &mut registry.attestations,

        ReserveAttestation {
            attestation_id,

            reserve_id,

            reserve_custodian:
                gold_reserve::custodian(
                    reserve,
                ),

            custodian_id,
            attestor_id,

            attestation_hash,

            attested_weight_mg,

            reserve_gross_weight_mg:
                reserve_weight,

            reserve_purity_bps:
                gold_reserve::purity_bps(
                    reserve,
                ),

            reserve_last_audit_epoch:
                gold_reserve::last_audit_epoch(
                    reserve,
                ),

            issued_epoch:
                tx_context::epoch(ctx),

            expires_epoch,

            status:
                STATUS_ACTIVE,

            version:
                1,

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_attestations =
        registry.total_attestations + 1;

    registry.active_attestation_count =
        registry.active_attestation_count + 1;

    event::emit(
        ReserveAttestationCreated {
            registry_id:
                object::id(registry),

            attestation_id,
            reserve_id,
            custodian_id,
            attestor_id,
            attested_weight_mg,
            expires_epoch,
        },
    );

    attestation_id
}


/* ============================================================
   Attestation Revocation
   ============================================================ */

public fun revoke_attestation(
    access: &AccessControl,
    registry: &mut ReserveAttestationRegistry,
    admin_cap: &ReserveAttestationAdminCap,

    attestation_id: u64,

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
        attestation_index(
            registry,
            attestation_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.attestations,
            index,
        );

    assert!(
        record.status == STATUS_ACTIVE,
        E_ATTESTATION_ALREADY_REVOKED,
    );

    record.status =
        STATUS_REVOKED;

    record.updated_epoch =
        tx_context::epoch(ctx);

    registry.active_attestation_count =
        registry.active_attestation_count - 1;

    registry.revoked_attestation_count =
        registry.revoked_attestation_count + 1;

    event::emit(
        ReserveAttestationRevoked {
            registry_id:
                object::id(registry),

            attestation_id,

            revoked_by:
                tx_context::sender(ctx),

            revoked_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Attestation Eligibility
   ============================================================ */

public fun assert_attestation_valid(
    registry: &ReserveAttestationRegistry,
    attestation_id: u64,
    current_epoch: u64,
) {
    let index =
        attestation_index(
            registry,
            attestation_id,
        );

    let record =
        vector::borrow(
            &registry.attestations,
            index,
        );

    assert!(
        record.status == STATUS_ACTIVE,
        E_ATTESTATION_ALREADY_REVOKED,
    );

    assert!(
        current_epoch
            < record.expires_epoch,
        E_ATTESTATION_EXPIRED,
    );

    let attestor_idx =
        attestor_index(
            registry,
            record.attestor_id,
        );

    let attestor =
        vector::borrow(
            &registry.attestors,
            attestor_idx,
        );

    assert!(
        attestor.active,
        E_ATTESTOR_INACTIVE,
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &ReserveAttestationAdminCap,
    registry: &mut ReserveAttestationRegistry,
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
        ReserveAttestationPauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}

public fun set_version(
    admin_cap: &ReserveAttestationAdminCap,
    registry: &mut ReserveAttestationRegistry,
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
        ReserveAttestationVersionChanged {
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
    registry: &ReserveAttestationRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &ReserveAttestationRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &ReserveAttestationRegistry,
): bool {
    registry.paused
}

public fun total_attestors(
    registry: &ReserveAttestationRegistry,
): u64 {
    registry.total_attestors
}

public fun active_attestor_count(
    registry: &ReserveAttestationRegistry,
): u64 {
    registry.active_attestor_count
}

public fun total_attestations(
    registry: &ReserveAttestationRegistry,
): u64 {
    registry.total_attestations
}

public fun active_attestation_count(
    registry: &ReserveAttestationRegistry,
): u64 {
    registry.active_attestation_count
}

public fun revoked_attestation_count(
    registry: &ReserveAttestationRegistry,
): u64 {
    registry.revoked_attestation_count
}

public fun attestation_status(
    registry: &ReserveAttestationRegistry,
    attestation_id: u64,
): u8 {
    let index =
        attestation_index(
            registry,
            attestation_id,
        );

    vector::borrow(
        &registry.attestations,
        index,
    ).status
}

public fun attestation_reserve_id(
    registry: &ReserveAttestationRegistry,
    attestation_id: u64,
): ID {
    let index =
        attestation_index(
            registry,
            attestation_id,
        );

    vector::borrow(
        &registry.attestations,
        index,
    ).reserve_id
}

public fun attestation_custodian_id(
    registry: &ReserveAttestationRegistry,
    attestation_id: u64,
): u64 {
    let index =
        attestation_index(
            registry,
            attestation_id,
        );

    vector::borrow(
        &registry.attestations,
        index,
    ).custodian_id
}

public fun attestation_attested_weight_mg(
    registry: &ReserveAttestationRegistry,
    attestation_id: u64,
): u64 {
    let index =
        attestation_index(
            registry,
            attestation_id,
        );

    vector::borrow(
        &registry.attestations,
        index,
    ).attested_weight_mg
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_revoked(): u8 {
    STATUS_REVOKED
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): ReserveAttestationRegistry {
    ReserveAttestationRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_attestor_id:
            1,

        next_attestation_id:
            1,

        attestors:
            vector[],

        attestations:
            vector[],

        total_attestors:
            0,

        active_attestor_count:
            0,

        total_attestations:
            0,

        active_attestation_count:
            0,

        revoked_attestation_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &ReserveAttestationRegistry,
    ctx: &mut TxContext,
): ReserveAttestationAdminCap {
    ReserveAttestationAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: ReserveAttestationRegistry,
) {
    let ReserveAttestationRegistry {
        id,

        version: _,
        paused: _,

        next_attestor_id: _,
        next_attestation_id: _,

        attestors,
        attestations,

        total_attestors: _,
        active_attestor_count: _,

        total_attestations: _,
        active_attestation_count: _,
        revoked_attestation_count: _,
    } = registry;

    let mut attestors =
        attestors;

    while (
        !vector::is_empty(
            &attestors,
        )
    ) {
        let record =
            vector::pop_back(
                &mut attestors,
            );

        let AttestorRecord {
            attestor_id: _,
            attestor_key: _,
            authority: _,

            active: _,
            version: _,

            created_epoch: _,
            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        attestors,
    );

    let mut attestations =
        attestations;

    while (
        !vector::is_empty(
            &attestations,
        )
    ) {
        let record =
            vector::pop_back(
                &mut attestations,
            );

        let ReserveAttestation {
            attestation_id: _,

            reserve_id: _,
            reserve_custodian: _,

            custodian_id: _,
            attestor_id: _,

            attestation_hash: _,

            attested_weight_mg: _,
            reserve_gross_weight_mg: _,
            reserve_purity_bps: _,

            reserve_last_audit_epoch: _,

            issued_epoch: _,
            expires_epoch: _,

            status: _,
            version: _,

            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        attestations,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: ReserveAttestationAdminCap,
) {
    let ReserveAttestationAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
