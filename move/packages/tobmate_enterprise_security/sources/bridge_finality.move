module tobmate_enterprise_security::bridge_finality;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_enterprise_security::external_network_registry::{
    Self as external_network,
    ExternalNetworkRegistry,
};

use tobmate_enterprise_security::cross_network_settlement_intent::{
    Self as cross_intent,
    CrossNetworkIntentRegistry,
};


/* ============================================================
   Stage 12 Part 5-C
   Bridge Finality / Confirmation Control Plane
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Attestor Status
   ============================================================ */

const ATTESTOR_ACTIVE: u8 = 1;
const ATTESTOR_SUSPENDED: u8 = 2;


/* ============================================================
   Finality Status
   ============================================================ */

const FINALITY_PENDING: u8 = 1;
const FINALITY_FINALIZED: u8 = 2;
const FINALITY_REJECTED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_ZERO_THRESHOLD: u64 = 2;
const E_ATTESTOR_ALREADY_REGISTERED: u64 = 3;
const E_ATTESTOR_NOT_FOUND: u64 = 4;
const E_ATTESTOR_INACTIVE: u64 = 5;
const E_UNAUTHORIZED_ATTESTOR: u64 = 6;
const E_FINALITY_ALREADY_EXISTS: u64 = 7;
const E_FINALITY_NOT_FOUND: u64 = 8;
const E_FINALITY_NOT_PENDING: u64 = 9;
const E_DUPLICATE_ATTESTATION: u64 = 10;
const E_EMPTY_PROOF_HASH: u64 = 11;
const E_THRESHOLD_NOT_REACHED: u64 = 12;
const E_INTENT_NOT_CONFIRMED: u64 = 13;
const E_NETWORK_NOT_ACTIVE: u64 = 14;
const E_VERSION_NOT_INCREASING: u64 = 15;
const E_STATE_UNCHANGED: u64 = 16;
const E_ADMIN_CAP_MISMATCH: u64 = 17;


/* ============================================================
   Registry
   ============================================================ */

public struct BridgeFinalityRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    threshold: u64,

    attestors: vector<BridgeAttestor>,
    finalities: vector<BridgeFinalityRecord>,

    total_attestors: u64,
    active_attestor_count: u64,

    total_finalities: u64,
    pending_count: u64,
    finalized_count: u64,
    rejected_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct BridgeFinalityAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Bridge Attestor
   ============================================================ */

public struct BridgeAttestor has store {
    authority: address,

    status: u8,

    registered_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Individual Attestation
   ============================================================ */

public struct FinalityAttestation has store {
    attestor: address,

    proof_hash: vector<u8>,

    attested_epoch: u64,
}


/* ============================================================
   Finality Record
   ============================================================ */

public struct BridgeFinalityRecord has store {
    intent_id: u64,

    source_network_id: u64,
    destination_network_id: u64,

    status: u8,

    attestations: vector<FinalityAttestation>,
    attestation_count: u64,

    finality_proof_hash: vector<u8>,

    created_epoch: u64,
    finalized_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct BridgeAttestorRegistered has copy, drop {
    registry_id: ID,
    authority: address,
}

public struct BridgeAttestorStatusChanged has copy, drop {
    registry_id: ID,
    authority: address,
    previous_status: u8,
    new_status: u8,
}

public struct BridgeFinalityOpened has copy, drop {
    registry_id: ID,
    intent_id: u64,
    source_network_id: u64,
    destination_network_id: u64,
}

public struct BridgeFinalityAttested has copy, drop {
    registry_id: ID,
    intent_id: u64,
    attestor: address,
    attestation_count: u64,
}

public struct BridgeFinalityCompleted has copy, drop {
    registry_id: ID,
    intent_id: u64,
    finality_proof_hash: vector<u8>,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    threshold: u64,
    ctx: &mut TxContext,
): (
    BridgeFinalityRegistry,
    BridgeFinalityAdminCap,
) {
    assert!(
        threshold > 0,
        E_ZERO_THRESHOLD,
    );

    let registry =
        BridgeFinalityRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            threshold,

            attestors:
                vector[],

            finalities:
                vector[],

            total_attestors:
                0,

            active_attestor_count:
                0,

            total_finalities:
                0,

            pending_count:
                0,

            finalized_count:
                0,

            rejected_count:
                0,
        };

    let admin_cap =
        BridgeFinalityAdminCap {
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
    registry: &BridgeFinalityRegistry,
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
    registry: &BridgeFinalityRegistry,
    admin_cap: &BridgeFinalityAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}


/* ============================================================
   Attestor Lookup
   ============================================================ */

fun attestor_index(
    registry: &BridgeFinalityRegistry,
    authority: address,
): u64 {
    let length =
        vector::length(
            &registry.attestors,
        );

    let mut i = 0;

    while (i < length) {
        let attestor =
            vector::borrow(
                &registry.attestors,
                i,
            );

        if (
            attestor.authority == authority
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_ATTESTOR_NOT_FOUND
}

fun attestor_exists(
    registry: &BridgeFinalityRegistry,
    authority: address,
): bool {
    let length =
        vector::length(
            &registry.attestors,
        );

    let mut i = 0;

    while (i < length) {
        let attestor =
            vector::borrow(
                &registry.attestors,
                i,
            );

        if (
            attestor.authority == authority
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

    registry: &mut BridgeFinalityRegistry,
    admin_cap: &BridgeFinalityAdminCap,

    authority: address,

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

    assert!(
        !attestor_exists(
            registry,
            authority,
        ),
        E_ATTESTOR_ALREADY_REGISTERED,
    );

    vector::push_back(
        &mut registry.attestors,

        BridgeAttestor {
            authority,

            status:
                ATTESTOR_ACTIVE,

            registered_epoch:
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
        BridgeAttestorRegistered {
            registry_id:
                object::id(registry),

            authority,
        },
    );
}


/* ============================================================
   Attestor Status
   ============================================================ */

public fun set_attestor_status(
    access: &AccessControl,

    registry: &mut BridgeFinalityRegistry,
    admin_cap: &BridgeFinalityAdminCap,

    authority: address,
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

    assert!(
        new_status == ATTESTOR_ACTIVE
            || new_status == ATTESTOR_SUSPENDED,
        E_STATE_UNCHANGED,
    );

    let index =
        attestor_index(
            registry,
            authority,
        );

    let attestor =
        vector::borrow_mut(
            &mut registry.attestors,
            index,
        );

    let previous_status =
        attestor.status;

    assert!(
        previous_status != new_status,
        E_STATE_UNCHANGED,
    );

    if (previous_status == ATTESTOR_ACTIVE) {
        registry.active_attestor_count =
            registry.active_attestor_count - 1;
    } else {
        registry.active_attestor_count =
            registry.active_attestor_count + 1;
    };

    attestor.status =
        new_status;

    attestor.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        BridgeAttestorStatusChanged {
            registry_id:
                object::id(registry),

            authority,
            previous_status,
            new_status,
        },
    );
}


/* ============================================================
   Finality Lookup
   ============================================================ */

fun finality_index(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.finalities,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.finalities,
                i,
            );

        if (
            record.intent_id == intent_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_FINALITY_NOT_FOUND
}

fun finality_exists(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
): bool {
    let length =
        vector::length(
            &registry.finalities,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.finalities,
                i,
            );

        if (
            record.intent_id == intent_id
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Open Finality Record
   ============================================================ */

public fun open_finality(
    access: &AccessControl,

    registry: &mut BridgeFinalityRegistry,

    network_registry:
        &ExternalNetworkRegistry,

    intent_registry:
        &CrossNetworkIntentRegistry,

    intent_id: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        !finality_exists(
            registry,
            intent_id,
        ),
        E_FINALITY_ALREADY_EXISTS,
    );

    assert!(
        cross_intent::intent_status(
            intent_registry,
            intent_id,
        ) == cross_intent::status_confirmed(),
        E_INTENT_NOT_CONFIRMED,
    );

    let source_network_id =
        cross_intent::source_network_id(
            intent_registry,
            intent_id,
        );

    let destination_network_id =
        cross_intent::destination_network_id(
            intent_registry,
            intent_id,
        );

    external_network::assert_network_active(
        network_registry,
        source_network_id,
    );

    external_network::assert_network_active(
        network_registry,
        destination_network_id,
    );

    vector::push_back(
        &mut registry.finalities,

        BridgeFinalityRecord {
            intent_id,

            source_network_id,
            destination_network_id,

            status:
                FINALITY_PENDING,

            attestations:
                vector[],

            attestation_count:
                0,

            finality_proof_hash:
                vector[],

            created_epoch:
                tx_context::epoch(ctx),

            finalized_epoch:
                0,

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_finalities =
        registry.total_finalities + 1;

    registry.pending_count =
        registry.pending_count + 1;

    event::emit(
        BridgeFinalityOpened {
            registry_id:
                object::id(registry),

            intent_id,
            source_network_id,
            destination_network_id,
        },
    );
}


/* ============================================================
   Attestation Lookup
   ============================================================ */

fun has_attested(
    record: &BridgeFinalityRecord,
    authority: address,
): bool {
    let length =
        vector::length(
            &record.attestations,
        );

    let mut i = 0;

    while (i < length) {
        let attestation =
            vector::borrow(
                &record.attestations,
                i,
            );

        if (
            attestation.attestor == authority
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Submit Finality Attestation
   ============================================================ */

public fun submit_attestation(
    access: &AccessControl,

    registry: &mut BridgeFinalityRegistry,

    intent_id: u64,
    proof_hash: vector<u8>,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        vector::length(&proof_hash) > 0,
        E_EMPTY_PROOF_HASH,
    );

    let authority =
        tx_context::sender(ctx);

    assert!(
        attestor_exists(
            registry,
            authority,
        ),
        E_UNAUTHORIZED_ATTESTOR,
    );

    let attestor_idx =
        attestor_index(
            registry,
            authority,
        );

    let attestor =
        vector::borrow(
            &registry.attestors,
            attestor_idx,
        );

    assert!(
        attestor.status == ATTESTOR_ACTIVE,
        E_ATTESTOR_INACTIVE,
    );

    let finality_idx =
        finality_index(
            registry,
            intent_id,
        );

    {
        let record =
            vector::borrow(
                &registry.finalities,
                finality_idx,
            );

        assert!(
            record.status == FINALITY_PENDING,
            E_FINALITY_NOT_PENDING,
        );

        assert!(
            !has_attested(
                record,
                authority,
            ),
            E_DUPLICATE_ATTESTATION,
        );
    };

    let registry_id =
        object::id(registry);

    let record =
        vector::borrow_mut(
            &mut registry.finalities,
            finality_idx,
        );

    vector::push_back(
        &mut record.attestations,

        FinalityAttestation {
            attestor:
                authority,

            proof_hash,

            attested_epoch:
                tx_context::epoch(ctx),
        },
    );

    record.attestation_count =
        record.attestation_count + 1;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        BridgeFinalityAttested {
            registry_id,

            intent_id,

            attestor:
                authority,

            attestation_count:
                record.attestation_count,
        },
    );
}


/* ============================================================
   Threshold Guard
   ============================================================ */

public fun assert_threshold_reached(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
) {
    let index =
        finality_index(
            registry,
            intent_id,
        );

    let record =
        vector::borrow(
            &registry.finalities,
            index,
        );

    assert!(
        record.status == FINALITY_PENDING,
        E_FINALITY_NOT_PENDING,
    );

    assert!(
        record.attestation_count
            >= registry.threshold,
        E_THRESHOLD_NOT_REACHED,
    );
}


/* ============================================================
   Threshold Read API
   ============================================================ */

public fun threshold(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.threshold
}

public fun attestation_count(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
): u64 {
    let index =
        finality_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.finalities,
        index,
    ).attestation_count
}


/* ============================================================
   Finalize Finality
   ============================================================ */

public fun finalize_finality(
    access: &AccessControl,

    registry: &mut BridgeFinalityRegistry,
    admin_cap: &BridgeFinalityAdminCap,

    intent_id: u64,
    finality_proof_hash: vector<u8>,

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

    assert!(
        vector::length(
            &finality_proof_hash,
        ) > 0,
        E_EMPTY_PROOF_HASH,
    );

    let index =
        finality_index(
            registry,
            intent_id,
        );

    {
        let record =
            vector::borrow(
                &registry.finalities,
                index,
            );

        assert!(
            record.status == FINALITY_PENDING,
            E_FINALITY_NOT_PENDING,
        );

        assert!(
            record.attestation_count
                >= registry.threshold,
            E_THRESHOLD_NOT_REACHED,
        );
    };

    let registry_id =
        object::id(registry);

    let record =
        vector::borrow_mut(
            &mut registry.finalities,
            index,
        );

    record.status =
        FINALITY_FINALIZED;

    record.finality_proof_hash =
        finality_proof_hash;

    record.finalized_epoch =
        tx_context::epoch(ctx);

    record.updated_epoch =
        tx_context::epoch(ctx);

    registry.pending_count =
        registry.pending_count - 1;

    registry.finalized_count =
        registry.finalized_count + 1;

    event::emit(
        BridgeFinalityCompleted {
            registry_id,

            intent_id,

            finality_proof_hash:
                record.finality_proof_hash,
        },
    );
}


/* ============================================================
   Reject Finality
   ============================================================ */

public fun reject_finality(
    access: &AccessControl,

    registry: &mut BridgeFinalityRegistry,
    admin_cap: &BridgeFinalityAdminCap,

    intent_id: u64,

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
        finality_index(
            registry,
            intent_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.finalities,
            index,
        );

    assert!(
        record.status == FINALITY_PENDING,
        E_FINALITY_NOT_PENDING,
    );

    record.status =
        FINALITY_REJECTED;

    record.updated_epoch =
        tx_context::epoch(ctx);

    registry.pending_count =
        registry.pending_count - 1;

    registry.rejected_count =
        registry.rejected_count + 1;
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &BridgeFinalityAdminCap,
    registry: &mut BridgeFinalityRegistry,
    paused: bool,
    _ctx: &mut TxContext,
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
}

public fun set_version(
    admin_cap: &BridgeFinalityAdminCap,
    registry: &mut BridgeFinalityRegistry,
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
   Read API
   ============================================================ */

public fun registry_id(
    registry: &BridgeFinalityRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &BridgeFinalityRegistry,
): bool {
    registry.paused
}

public fun total_attestors(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.total_attestors
}

public fun active_attestor_count(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.active_attestor_count
}

public fun total_finalities(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.total_finalities
}

public fun pending_count(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.pending_count
}

public fun finalized_count(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.finalized_count
}

public fun rejected_count(
    registry: &BridgeFinalityRegistry,
): u64 {
    registry.rejected_count
}

public fun finality_status(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
): u8 {
    let index =
        finality_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.finalities,
        index,
    ).status
}

public fun finality_source_network_id(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
): u64 {
    let index =
        finality_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.finalities,
        index,
    ).source_network_id
}

public fun finality_destination_network_id(
    registry: &BridgeFinalityRegistry,
    intent_id: u64,
): u64 {
    let index =
        finality_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.finalities,
        index,
    ).destination_network_id
}


/* ============================================================
   Status API
   ============================================================ */

public fun attestor_active(): u8 {
    ATTESTOR_ACTIVE
}

public fun attestor_suspended(): u8 {
    ATTESTOR_SUSPENDED
}

public fun finality_pending(): u8 {
    FINALITY_PENDING
}

public fun finality_finalized(): u8 {
    FINALITY_FINALIZED
}

public fun finality_rejected(): u8 {
    FINALITY_REJECTED
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    threshold: u64,
    ctx: &mut TxContext,
): BridgeFinalityRegistry {
    assert!(
        threshold > 0,
        E_ZERO_THRESHOLD,
    );

    BridgeFinalityRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        threshold,

        attestors:
            vector[],

        finalities:
            vector[],

        total_attestors:
            0,

        active_attestor_count:
            0,

        total_finalities:
            0,

        pending_count:
            0,

        finalized_count:
            0,

        rejected_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &BridgeFinalityRegistry,
    ctx: &mut TxContext,
): BridgeFinalityAdminCap {
    BridgeFinalityAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: BridgeFinalityRegistry,
) {
    let BridgeFinalityRegistry {
        id,

        version: _,
        paused: _,

        threshold: _,

        attestors,
        finalities,

        total_attestors: _,
        active_attestor_count: _,

        total_finalities: _,
        pending_count: _,
        finalized_count: _,
        rejected_count: _,
    } = registry;

    let mut attestors =
        attestors;

    while (
        !vector::is_empty(
            &attestors,
        )
    ) {
        let attestor =
            vector::pop_back(
                &mut attestors,
            );

        let BridgeAttestor {
            authority: _,
            status: _,
            registered_epoch: _,
            updated_epoch: _,
        } = attestor;
    };

    vector::destroy_empty(
        attestors,
    );

    let mut finalities =
        finalities;

    while (
        !vector::is_empty(
            &finalities,
        )
    ) {
        let record =
            vector::pop_back(
                &mut finalities,
            );

        let BridgeFinalityRecord {
            intent_id: _,

            source_network_id: _,
            destination_network_id: _,

            status: _,

            attestations,
            attestation_count: _,

            finality_proof_hash: _,

            created_epoch: _,
            finalized_epoch: _,
            updated_epoch: _,
        } = record;

        let mut attestations =
            attestations;

        while (
            !vector::is_empty(
                &attestations,
            )
        ) {
            let attestation =
                vector::pop_back(
                    &mut attestations,
                );

            let FinalityAttestation {
                attestor: _,
                proof_hash: _,
                attested_epoch: _,
            } = attestation;
        };

        vector::destroy_empty(
            attestations,
        );
    };

    vector::destroy_empty(
        finalities,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: BridgeFinalityAdminCap,
) {
    let BridgeFinalityAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
