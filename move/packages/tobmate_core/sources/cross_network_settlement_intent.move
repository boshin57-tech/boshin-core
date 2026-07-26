module tobmate_core::cross_network_settlement_intent;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::external_network_registry::{
    Self as external_network,
    ExternalNetworkRegistry,
};


/* ============================================================
   Stage 12 Part 5-B
   Cross-Network Message / Settlement Intent
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Intent Types
   ============================================================ */

const INTENT_ASSET_TRANSFER: u8 = 1;
const INTENT_SETTLEMENT: u8 = 2;
const INTENT_REDEMPTION: u8 = 3;
const INTENT_MINT: u8 = 4;
const INTENT_BURN: u8 = 5;


/* ============================================================
   Intent Status
   ============================================================ */

const STATUS_PENDING: u8 = 1;
const STATUS_CONFIRMED: u8 = 2;
const STATUS_FINALIZED: u8 = 3;
const STATUS_CANCELLED: u8 = 4;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_INTENT_TYPE: u64 = 2;
const E_ZERO_AMOUNT: u64 = 3;
const E_EMPTY_ASSET_CODE: u64 = 4;
const E_EMPTY_EXTERNAL_REFERENCE: u64 = 5;
const E_DUPLICATE_EXTERNAL_REFERENCE: u64 = 6;
const E_INTENT_NOT_FOUND: u64 = 7;
const E_INTENT_NOT_PENDING: u64 = 8;
const E_INTENT_NOT_CONFIRMED: u64 = 9;
const E_SOURCE_DESTINATION_SAME: u64 = 10;
const E_SOURCE_OPERATOR_MISMATCH: u64 = 11;
const E_DESTINATION_OPERATOR_MISMATCH: u64 = 12;
const E_ALREADY_TERMINAL: u64 = 13;
const E_VERSION_NOT_INCREASING: u64 = 14;
const E_STATE_UNCHANGED: u64 = 15;
const E_ADMIN_CAP_MISMATCH: u64 = 16;


/* ============================================================
   Registry
   ============================================================ */

public struct CrossNetworkIntentRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_intent_id: u64,

    intents: vector<CrossNetworkIntent>,

    total_intents: u64,
    pending_count: u64,
    confirmed_count: u64,
    finalized_count: u64,
    cancelled_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct CrossNetworkIntentAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Intent Record
   ============================================================ */

public struct CrossNetworkIntent has store {
    intent_id: u64,

    source_network_id: u64,
    destination_network_id: u64,

    source_operator: address,
    destination_operator: address,

    intent_type: u8,

    asset_code: vector<u8>,
    amount: u64,

    beneficiary: address,

    external_reference: vector<u8>,
    confirmation_hash: vector<u8>,

    status: u8,

    created_epoch: u64,
    confirmed_epoch: u64,
    finalized_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct CrossNetworkIntentCreated has copy, drop {
    registry_id: ID,
    intent_id: u64,

    source_network_id: u64,
    destination_network_id: u64,

    intent_type: u8,
    amount: u64,

    beneficiary: address,
}

public struct CrossNetworkIntentConfirmed has copy, drop {
    registry_id: ID,
    intent_id: u64,

    confirmed_by: address,
    confirmed_epoch: u64,
}

public struct CrossNetworkIntentFinalized has copy, drop {
    registry_id: ID,
    intent_id: u64,

    finalized_by: address,
    finalized_epoch: u64,
}

public struct CrossNetworkIntentCancelled has copy, drop {
    registry_id: ID,
    intent_id: u64,

    cancelled_by: address,
    cancelled_epoch: u64,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    CrossNetworkIntentRegistry,
    CrossNetworkIntentAdminCap,
) {
    let registry =
        CrossNetworkIntentRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_intent_id:
                1,

            intents:
                vector[],

            total_intents:
                0,

            pending_count:
                0,

            confirmed_count:
                0,

            finalized_count:
                0,

            cancelled_count:
                0,
        };

    let admin_cap =
        CrossNetworkIntentAdminCap {
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
    registry: &CrossNetworkIntentRegistry,
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
    registry: &CrossNetworkIntentRegistry,
    admin_cap: &CrossNetworkIntentAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_intent_type(
    intent_type: u8,
) {
    assert!(
        intent_type == INTENT_ASSET_TRANSFER
            || intent_type == INTENT_SETTLEMENT
            || intent_type == INTENT_REDEMPTION
            || intent_type == INTENT_MINT
            || intent_type == INTENT_BURN,
        E_INVALID_INTENT_TYPE,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun intent_index(
    registry: &CrossNetworkIntentRegistry,
    intent_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.intents,
        );

    let mut i = 0;

    while (i < length) {
        let intent =
            vector::borrow(
                &registry.intents,
                i,
            );

        if (
            intent.intent_id == intent_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_INTENT_NOT_FOUND
}

fun external_reference_exists(
    registry: &CrossNetworkIntentRegistry,
    external_reference: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.intents,
        );

    let mut i = 0;

    while (i < length) {
        let intent =
            vector::borrow(
                &registry.intents,
                i,
            );

        if (
            intent.external_reference
                == *external_reference
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Create Cross-Network Intent
   ============================================================ */

public fun create_intent(
    access: &AccessControl,

    registry: &mut CrossNetworkIntentRegistry,

    network_registry:
        &ExternalNetworkRegistry,

    source_network_id: u64,
    destination_network_id: u64,

    intent_type: u8,

    asset_code: vector<u8>,
    amount: u64,

    beneficiary: address,
    external_reference: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert_valid_intent_type(
        intent_type,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    assert!(
        vector::length(&asset_code) > 0,
        E_EMPTY_ASSET_CODE,
    );

    assert!(
        vector::length(
            &external_reference,
        ) > 0,
        E_EMPTY_EXTERNAL_REFERENCE,
    );

    assert!(
        source_network_id
            != destination_network_id,
        E_SOURCE_DESTINATION_SAME,
    );

    external_network::assert_network_active(
        network_registry,
        source_network_id,
    );

    external_network::assert_network_active(
        network_registry,
        destination_network_id,
    );

    assert!(
        !external_reference_exists(
            registry,
            &external_reference,
        ),
        E_DUPLICATE_EXTERNAL_REFERENCE,
    );

    let source_operator =
        external_network::operator_authority(
            network_registry,
            source_network_id,
        );

    let destination_operator =
        external_network::operator_authority(
            network_registry,
            destination_network_id,
        );

    assert!(
        source_operator
            == tx_context::sender(ctx),
        E_SOURCE_OPERATOR_MISMATCH,
    );

    let intent_id =
        registry.next_intent_id;

    registry.next_intent_id =
        intent_id + 1;

    vector::push_back(
        &mut registry.intents,

        CrossNetworkIntent {
            intent_id,

            source_network_id,
            destination_network_id,

            source_operator,
            destination_operator,

            intent_type,

            asset_code,
            amount,

            beneficiary,

            external_reference,

            confirmation_hash:
                vector[],

            status:
                STATUS_PENDING,

            created_epoch:
                tx_context::epoch(ctx),

            confirmed_epoch:
                0,

            finalized_epoch:
                0,

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_intents =
        registry.total_intents + 1;

    registry.pending_count =
        registry.pending_count + 1;

    event::emit(
        CrossNetworkIntentCreated {
            registry_id:
                object::id(registry),

            intent_id,

            source_network_id,
            destination_network_id,

            intent_type,
            amount,

            beneficiary,
        },
    );

    intent_id
}


/* ============================================================
   Destination Confirmation
   ============================================================ */

public fun confirm_intent(
    access: &AccessControl,

    registry: &mut CrossNetworkIntentRegistry,

    network_registry:
        &ExternalNetworkRegistry,

    intent_id: u64,

    confirmation_hash: vector<u8>,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    let index =
        intent_index(
            registry,
            intent_id,
        );

    let (
        destination_network_id,
        destination_operator,
        status,
    ) = {
        let intent =
            vector::borrow(
                &registry.intents,
                index,
            );

        (
            intent.destination_network_id,
            intent.destination_operator,
            intent.status,
        )
    };

    assert!(
        status == STATUS_PENDING,
        E_INTENT_NOT_PENDING,
    );

    external_network::assert_network_active(
        network_registry,
        destination_network_id,
    );

    let current_destination_operator =
        external_network::operator_authority(
            network_registry,
            destination_network_id,
        );

    assert!(
        current_destination_operator
            == destination_operator,
        E_DESTINATION_OPERATOR_MISMATCH,
    );

    assert!(
        destination_operator
            == tx_context::sender(ctx),
        E_DESTINATION_OPERATOR_MISMATCH,
    );

    assert!(
        vector::length(
            &confirmation_hash,
        ) > 0,
        E_EMPTY_EXTERNAL_REFERENCE,
    );

    let intent =
        vector::borrow_mut(
            &mut registry.intents,
            index,
        );

    intent.confirmation_hash =
        confirmation_hash;

    intent.status =
        STATUS_CONFIRMED;

    intent.confirmed_epoch =
        tx_context::epoch(ctx);

    intent.updated_epoch =
        tx_context::epoch(ctx);

    registry.pending_count =
        registry.pending_count - 1;

    registry.confirmed_count =
        registry.confirmed_count + 1;

    event::emit(
        CrossNetworkIntentConfirmed {
            registry_id:
                object::id(registry),

            intent_id,

            confirmed_by:
                tx_context::sender(ctx),

            confirmed_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Finalization
   ============================================================ */

public fun finalize_intent(
    access: &AccessControl,

    registry: &mut CrossNetworkIntentRegistry,
    admin_cap: &CrossNetworkIntentAdminCap,

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
        intent_index(
            registry,
            intent_id,
        );

    let intent =
        vector::borrow_mut(
            &mut registry.intents,
            index,
        );

    assert!(
        intent.status == STATUS_CONFIRMED,
        E_INTENT_NOT_CONFIRMED,
    );

    intent.status =
        STATUS_FINALIZED;

    intent.finalized_epoch =
        tx_context::epoch(ctx);

    intent.updated_epoch =
        tx_context::epoch(ctx);

    registry.confirmed_count =
        registry.confirmed_count - 1;

    registry.finalized_count =
        registry.finalized_count + 1;

    event::emit(
        CrossNetworkIntentFinalized {
            registry_id:
                object::id(registry),

            intent_id,

            finalized_by:
                tx_context::sender(ctx),

            finalized_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Cancellation
   ============================================================ */

public fun cancel_intent(
    access: &AccessControl,

    registry: &mut CrossNetworkIntentRegistry,
    admin_cap: &CrossNetworkIntentAdminCap,

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
        intent_index(
            registry,
            intent_id,
        );

    let intent =
        vector::borrow_mut(
            &mut registry.intents,
            index,
        );

    assert!(
        intent.status != STATUS_FINALIZED
            && intent.status != STATUS_CANCELLED,
        E_ALREADY_TERMINAL,
    );

    if (intent.status == STATUS_PENDING) {
        registry.pending_count =
            registry.pending_count - 1;
    } else {
        assert!(
            intent.status == STATUS_CONFIRMED,
            E_ALREADY_TERMINAL,
        );

        registry.confirmed_count =
            registry.confirmed_count - 1;
    };

    intent.status =
        STATUS_CANCELLED;

    intent.updated_epoch =
        tx_context::epoch(ctx);

    registry.cancelled_count =
        registry.cancelled_count + 1;

    event::emit(
        CrossNetworkIntentCancelled {
            registry_id:
                object::id(registry),

            intent_id,

            cancelled_by:
                tx_context::sender(ctx),

            cancelled_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &CrossNetworkIntentAdminCap,
    registry: &mut CrossNetworkIntentRegistry,
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
    admin_cap: &CrossNetworkIntentAdminCap,
    registry: &mut CrossNetworkIntentRegistry,
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
    registry: &CrossNetworkIntentRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &CrossNetworkIntentRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &CrossNetworkIntentRegistry,
): bool {
    registry.paused
}

public fun total_intents(
    registry: &CrossNetworkIntentRegistry,
): u64 {
    registry.total_intents
}

public fun pending_count(
    registry: &CrossNetworkIntentRegistry,
): u64 {
    registry.pending_count
}

public fun confirmed_count(
    registry: &CrossNetworkIntentRegistry,
): u64 {
    registry.confirmed_count
}

public fun finalized_count(
    registry: &CrossNetworkIntentRegistry,
): u64 {
    registry.finalized_count
}

public fun cancelled_count(
    registry: &CrossNetworkIntentRegistry,
): u64 {
    registry.cancelled_count
}

public fun intent_status(
    registry: &CrossNetworkIntentRegistry,
    intent_id: u64,
): u8 {
    let index =
        intent_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.intents,
        index,
    ).status
}

public fun source_network_id(
    registry: &CrossNetworkIntentRegistry,
    intent_id: u64,
): u64 {
    let index =
        intent_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.intents,
        index,
    ).source_network_id
}

public fun destination_network_id(
    registry: &CrossNetworkIntentRegistry,
    intent_id: u64,
): u64 {
    let index =
        intent_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.intents,
        index,
    ).destination_network_id
}

public fun intent_amount(
    registry: &CrossNetworkIntentRegistry,
    intent_id: u64,
): u64 {
    let index =
        intent_index(
            registry,
            intent_id,
        );

    vector::borrow(
        &registry.intents,
        index,
    ).amount
}


/* ============================================================
   Intent Type API
   ============================================================ */

public fun intent_asset_transfer(): u8 {
    INTENT_ASSET_TRANSFER
}

public fun intent_settlement(): u8 {
    INTENT_SETTLEMENT
}

public fun intent_redemption(): u8 {
    INTENT_REDEMPTION
}

public fun intent_mint(): u8 {
    INTENT_MINT
}

public fun intent_burn(): u8 {
    INTENT_BURN
}


/* ============================================================
   Status API
   ============================================================ */

public fun status_pending(): u8 {
    STATUS_PENDING
}

public fun status_confirmed(): u8 {
    STATUS_CONFIRMED
}

public fun status_finalized(): u8 {
    STATUS_FINALIZED
}

public fun status_cancelled(): u8 {
    STATUS_CANCELLED
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): CrossNetworkIntentRegistry {
    CrossNetworkIntentRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_intent_id:
            1,

        intents:
            vector[],

        total_intents:
            0,

        pending_count:
            0,

        confirmed_count:
            0,

        finalized_count:
            0,

        cancelled_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &CrossNetworkIntentRegistry,
    ctx: &mut TxContext,
): CrossNetworkIntentAdminCap {
    CrossNetworkIntentAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: CrossNetworkIntentRegistry,
) {
    let CrossNetworkIntentRegistry {
        id,

        version: _,
        paused: _,

        next_intent_id: _,

        intents,

        total_intents: _,
        pending_count: _,
        confirmed_count: _,
        finalized_count: _,
        cancelled_count: _,
    } = registry;

    let mut intents =
        intents;

    while (
        !vector::is_empty(
            &intents,
        )
    ) {
        let intent =
            vector::pop_back(
                &mut intents,
            );

        let CrossNetworkIntent {
            intent_id: _,

            source_network_id: _,
            destination_network_id: _,

            source_operator: _,
            destination_operator: _,

            intent_type: _,

            asset_code: _,
            amount: _,

            beneficiary: _,

            external_reference: _,
            confirmation_hash: _,

            status: _,

            created_epoch: _,
            confirmed_epoch: _,
            finalized_epoch: _,
            updated_epoch: _,
        } = intent;
    };

    vector::destroy_empty(
        intents,
    );

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: CrossNetworkIntentAdminCap,
) {
    let CrossNetworkIntentAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}
