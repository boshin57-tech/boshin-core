module tobmate_core::institutional_settlement;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::institution_registry::{
    Self as institution_registry,
    InstitutionRegistry,
};


/* ============================================================
   Stage 12 Part 3-B
   Institutional Settlement Control Plane
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Settlement Types
   ============================================================ */

const SETTLEMENT_FIAT_DEPOSIT: u8 = 1;
const SETTLEMENT_FIAT_WITHDRAWAL: u8 = 2;
const SETTLEMENT_ASSET_PURCHASE: u8 = 3;
const SETTLEMENT_ASSET_REDEMPTION: u8 = 4;
const SETTLEMENT_INSTITUTION_TRANSFER: u8 = 5;


/* ============================================================
   Settlement Status
   ============================================================ */

const STATUS_PENDING: u8 = 1;
const STATUS_CONFIRMED: u8 = 2;
const STATUS_FINALIZED: u8 = 3;
const STATUS_CANCELLED: u8 = 4;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_SETTLEMENT_TYPE: u64 = 2;
const E_ZERO_AMOUNT: u64 = 3;
const E_EMPTY_ASSET_CODE: u64 = 4;
const E_EMPTY_EXTERNAL_REFERENCE: u64 = 5;
const E_DUPLICATE_EXTERNAL_REFERENCE: u64 = 6;
const E_SETTLEMENT_NOT_FOUND: u64 = 7;
const E_SETTLEMENT_NOT_PENDING: u64 = 8;
const E_SETTLEMENT_NOT_CONFIRMED: u64 = 9;
const E_INSTITUTION_AUTHORITY_MISMATCH: u64 = 10;
const E_INSTITUTION_MISMATCH: u64 = 11;
const E_ALREADY_TERMINAL: u64 = 12;
const E_VERSION_NOT_INCREASING: u64 = 13;
const E_STATE_UNCHANGED: u64 = 14;
const E_ADMIN_CAP_MISMATCH: u64 = 15;


/* ============================================================
   Registry
   ============================================================ */

public struct InstitutionalSettlementRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_settlement_id: u64,

    settlements: vector<SettlementRecord>,

    total_settlements: u64,
    pending_count: u64,
    confirmed_count: u64,
    finalized_count: u64,
    cancelled_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct InstitutionalSettlementAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Settlement Record
   ============================================================ */

public struct SettlementRecord has store {
    settlement_id: u64,

    institution_id: u64,
    institution_authority: address,

    settlement_type: u8,

    asset_code: vector<u8>,
    amount: u64,

    beneficiary: address,

    external_reference: vector<u8>,
    external_confirmation_hash: vector<u8>,

    status: u8,

    created_epoch: u64,
    confirmed_epoch: u64,
    finalized_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct SettlementCreated has copy, drop {
    registry_id: ID,
    settlement_id: u64,
    institution_id: u64,
    settlement_type: u8,
    amount: u64,
    beneficiary: address,
}

public struct SettlementConfirmed has copy, drop {
    registry_id: ID,
    settlement_id: u64,
    institution_id: u64,
    confirmed_by: address,
    confirmed_epoch: u64,
}

public struct SettlementFinalized has copy, drop {
    registry_id: ID,
    settlement_id: u64,
    finalized_by: address,
    finalized_epoch: u64,
}

public struct SettlementCancelled has copy, drop {
    registry_id: ID,
    settlement_id: u64,
    cancelled_by: address,
    cancelled_epoch: u64,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    InstitutionalSettlementRegistry,
    InstitutionalSettlementAdminCap,
) {
    let registry =
        InstitutionalSettlementRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_settlement_id:
                1,

            settlements:
                vector[],

            total_settlements:
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
        InstitutionalSettlementAdminCap {
            id: object::new(ctx),
            registry_id: object::id(&registry),
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
    registry: &InstitutionalSettlementRegistry,
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
    registry: &InstitutionalSettlementRegistry,
    admin_cap: &InstitutionalSettlementAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_settlement_type(
    settlement_type: u8,
) {
    assert!(
        settlement_type == SETTLEMENT_FIAT_DEPOSIT
            || settlement_type == SETTLEMENT_FIAT_WITHDRAWAL
            || settlement_type == SETTLEMENT_ASSET_PURCHASE
            || settlement_type == SETTLEMENT_ASSET_REDEMPTION
            || settlement_type == SETTLEMENT_INSTITUTION_TRANSFER,
        E_INVALID_SETTLEMENT_TYPE,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun settlement_index(
    registry: &InstitutionalSettlementRegistry,
    settlement_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.settlements,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.settlements,
                i,
            );

        if (
            record.settlement_id == settlement_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_SETTLEMENT_NOT_FOUND
}

fun external_reference_exists(
    registry: &InstitutionalSettlementRegistry,
    external_reference: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.settlements,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.settlements,
                i,
            );

        if (
            record.external_reference == *external_reference
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Settlement Instruction
   ============================================================ */

public fun create_settlement(
    access: &AccessControl,
    registry: &mut InstitutionalSettlementRegistry,

    institution_registry_obj: &InstitutionRegistry,

    institution_id: u64,
    settlement_type: u8,

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

    institution_registry::assert_institution_active(
        institution_registry_obj,
        institution_id,
    );

    assert_valid_settlement_type(
        settlement_type,
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
        vector::length(&external_reference) > 0,
        E_EMPTY_EXTERNAL_REFERENCE,
    );

    assert!(
        !external_reference_exists(
            registry,
            &external_reference,
        ),
        E_DUPLICATE_EXTERNAL_REFERENCE,
    );

    let institution_authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            institution_id,
        );

    let settlement_id =
        registry.next_settlement_id;

    registry.next_settlement_id =
        settlement_id + 1;

    vector::push_back(
        &mut registry.settlements,

        SettlementRecord {
            settlement_id,

            institution_id,
            institution_authority,

            settlement_type,

            asset_code,
            amount,

            beneficiary,

            external_reference,

            external_confirmation_hash:
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

    registry.total_settlements =
        registry.total_settlements + 1;

    registry.pending_count =
        registry.pending_count + 1;

    event::emit(
        SettlementCreated {
            registry_id:
                object::id(registry),

            settlement_id,
            institution_id,
            settlement_type,
            amount,
            beneficiary,
        },
    );

    settlement_id
}


/* ============================================================
   Institutional Confirmation
   ============================================================ */

public fun confirm_settlement(
    access: &AccessControl,
    registry: &mut InstitutionalSettlementRegistry,

    institution_registry_obj: &InstitutionRegistry,

    settlement_id: u64,
    institution_id: u64,

    external_confirmation_hash: vector<u8>,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    institution_registry::assert_institution_active(
        institution_registry_obj,
        institution_id,
    );

    let index =
        settlement_index(
            registry,
            settlement_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.settlements,
            index,
        );

    assert!(
        record.status == STATUS_PENDING,
        E_SETTLEMENT_NOT_PENDING,
    );

    assert!(
        record.institution_id == institution_id,
        E_INSTITUTION_MISMATCH,
    );

    let institution_authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            institution_id,
        );

    assert!(
        institution_authority
            == tx_context::sender(ctx),
        E_INSTITUTION_AUTHORITY_MISMATCH,
    );

    assert!(
        vector::length(
            &external_confirmation_hash,
        ) > 0,
        E_EMPTY_EXTERNAL_REFERENCE,
    );

    record.external_confirmation_hash =
        external_confirmation_hash;

    record.status =
        STATUS_CONFIRMED;

    record.confirmed_epoch =
        tx_context::epoch(ctx);

    record.updated_epoch =
        tx_context::epoch(ctx);

    registry.pending_count =
        registry.pending_count - 1;

    registry.confirmed_count =
        registry.confirmed_count + 1;

    event::emit(
        SettlementConfirmed {
            registry_id:
                object::id(registry),

            settlement_id,
            institution_id,

            confirmed_by:
                tx_context::sender(ctx),

            confirmed_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Settlement Finalization
   ============================================================ */

public fun finalize_settlement(
    access: &AccessControl,
    registry: &mut InstitutionalSettlementRegistry,
    admin_cap: &InstitutionalSettlementAdminCap,

    settlement_id: u64,

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
        settlement_index(
            registry,
            settlement_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.settlements,
            index,
        );

    assert!(
        record.status == STATUS_CONFIRMED,
        E_SETTLEMENT_NOT_CONFIRMED,
    );

    record.status =
        STATUS_FINALIZED;

    record.finalized_epoch =
        tx_context::epoch(ctx);

    record.updated_epoch =
        tx_context::epoch(ctx);

    registry.confirmed_count =
        registry.confirmed_count - 1;

    registry.finalized_count =
        registry.finalized_count + 1;

    event::emit(
        SettlementFinalized {
            registry_id:
                object::id(registry),

            settlement_id,

            finalized_by:
                tx_context::sender(ctx),

            finalized_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Settlement Cancellation
   ============================================================ */

public fun cancel_settlement(
    access: &AccessControl,
    registry: &mut InstitutionalSettlementRegistry,
    admin_cap: &InstitutionalSettlementAdminCap,

    settlement_id: u64,

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
        settlement_index(
            registry,
            settlement_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.settlements,
            index,
        );

    assert!(
        record.status != STATUS_FINALIZED
            && record.status != STATUS_CANCELLED,
        E_ALREADY_TERMINAL,
    );

    if (record.status == STATUS_PENDING) {
        registry.pending_count =
            registry.pending_count - 1;
    } else {
        assert!(
            record.status == STATUS_CONFIRMED,
            E_ALREADY_TERMINAL,
        );

        registry.confirmed_count =
            registry.confirmed_count - 1;
    };

    record.status =
        STATUS_CANCELLED;

    record.updated_epoch =
        tx_context::epoch(ctx);

    registry.cancelled_count =
        registry.cancelled_count + 1;

    event::emit(
        SettlementCancelled {
            registry_id:
                object::id(registry),

            settlement_id,

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
    admin_cap: &InstitutionalSettlementAdminCap,
    registry: &mut InstitutionalSettlementRegistry,
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
}

public fun set_version(
    admin_cap: &InstitutionalSettlementAdminCap,
    registry: &mut InstitutionalSettlementRegistry,
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
    registry: &InstitutionalSettlementRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &InstitutionalSettlementRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &InstitutionalSettlementRegistry,
): bool {
    registry.paused
}

public fun total_settlements(
    registry: &InstitutionalSettlementRegistry,
): u64 {
    registry.total_settlements
}

public fun pending_count(
    registry: &InstitutionalSettlementRegistry,
): u64 {
    registry.pending_count
}

public fun confirmed_count(
    registry: &InstitutionalSettlementRegistry,
): u64 {
    registry.confirmed_count
}

public fun finalized_count(
    registry: &InstitutionalSettlementRegistry,
): u64 {
    registry.finalized_count
}

public fun cancelled_count(
    registry: &InstitutionalSettlementRegistry,
): u64 {
    registry.cancelled_count
}

public fun settlement_status(
    registry: &InstitutionalSettlementRegistry,
    settlement_id: u64,
): u8 {
    let index =
        settlement_index(
            registry,
            settlement_id,
        );

    vector::borrow(
        &registry.settlements,
        index,
    ).status
}

public fun settlement_institution_id(
    registry: &InstitutionalSettlementRegistry,
    settlement_id: u64,
): u64 {
    let index =
        settlement_index(
            registry,
            settlement_id,
        );

    vector::borrow(
        &registry.settlements,
        index,
    ).institution_id
}

public fun settlement_amount(
    registry: &InstitutionalSettlementRegistry,
    settlement_id: u64,
): u64 {
    let index =
        settlement_index(
            registry,
            settlement_id,
        );

    vector::borrow(
        &registry.settlements,
        index,
    ).amount
}


/* ============================================================
   Type / Status API
   ============================================================ */

public fun settlement_fiat_deposit(): u8 {
    SETTLEMENT_FIAT_DEPOSIT
}

public fun settlement_fiat_withdrawal(): u8 {
    SETTLEMENT_FIAT_WITHDRAWAL
}

public fun settlement_asset_purchase(): u8 {
    SETTLEMENT_ASSET_PURCHASE
}

public fun settlement_asset_redemption(): u8 {
    SETTLEMENT_ASSET_REDEMPTION
}

public fun settlement_institution_transfer(): u8 {
    SETTLEMENT_INSTITUTION_TRANSFER
}

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
): InstitutionalSettlementRegistry {
    InstitutionalSettlementRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_settlement_id:
            1,

        settlements:
            vector[],

        total_settlements:
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
    registry: &InstitutionalSettlementRegistry,
    ctx: &mut TxContext,
): InstitutionalSettlementAdminCap {
    InstitutionalSettlementAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: InstitutionalSettlementRegistry,
) {
    let InstitutionalSettlementRegistry {
        id,

        version: _,
        paused: _,

        next_settlement_id: _,

        settlements,

        total_settlements: _,
        pending_count: _,
        confirmed_count: _,
        finalized_count: _,
        cancelled_count: _,
    } = registry;

    let mut settlements =
        settlements;

    while (
        !vector::is_empty(
            &settlements,
        )
    ) {
        let record =
            vector::pop_back(
                &mut settlements,
            );

        let SettlementRecord {
            settlement_id: _,

            institution_id: _,
            institution_authority: _,

            settlement_type: _,

            asset_code: _,
            amount: _,

            beneficiary: _,

            external_reference: _,
            external_confirmation_hash: _,

            status: _,

            created_epoch: _,
            confirmed_epoch: _,
            finalized_epoch: _,
            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        settlements,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: InstitutionalSettlementAdminCap,
) {
    let InstitutionalSettlementAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
