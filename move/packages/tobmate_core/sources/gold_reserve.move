module tobmate_core::gold_reserve;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{Self, AccessControl};

/// General validation failures.
const E_ZERO_WEIGHT: u64 = 1;
const E_INVALID_PURITY: u64 = 2;
const E_INVALID_STATUS: u64 = 3;
const E_INSUFFICIENT_AVAILABLE_WEIGHT: u64 = 4;
const E_INSUFFICIENT_ALLOCATED_WEIGHT: u64 = 5;
const E_CUSTODIAN_MISMATCH: u64 = 6;
const E_CUSTODIAN_INACTIVE: u64 = 8;
const E_OUTSTANDING_ALLOCATION: u64 = 9;
const E_UNCHANGED_VALUE: u64 = 10;

/// Reserve status values.
const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_RETIRED: u8 = 3;

/// Maximum purity value in basis points.
const MAX_PURITY_BPS: u64 = 10000;

/// Root capability for reserve administration.
public struct ReserveAdminCap has key, store {
    id: UID,
}

/// Capability owned by an approved physical gold custodian.
public struct CustodianCap has key, store {
    id: UID,
    custodian: address,
    active: bool,
}

/// Shared registry containing protocol-wide reserve totals.
public struct GoldReserveRegistry has key {
    id: UID,
    version: u64,
    total_reserves: u64,
    total_custodians: u64,
    total_weight_mg: u64,
    total_allocated_mg: u64,
    total_available_mg: u64,
}

/// Shared object representing a specific physical gold reserve.
///
/// The physical gold remains under the responsibility of `custodian`.
/// The on-chain object tracks weight, purity, allocation and audit state.
public struct GoldReserve has key {
    id: UID,
    sequence: u64,
    custodian: address,
    vault_id: vector<u8>,
    bar_reference: vector<u8>,
    gross_weight_mg: u64,
    allocated_weight_mg: u64,
    available_weight_mg: u64,
    purity_bps: u64,
    audit_hash: vector<u8>,
    last_audit_epoch: u64,
    status: u8,
    created_at_epoch: u64,
}

/// Emitted when a custodian is registered.
public struct CustodianRegistered has copy, drop {
    custodian: address,
    registered_by: address,
}

/// Emitted when custodian status changes.
public struct CustodianStatusChanged has copy, drop {
    custodian: address,
    active: bool,
    changed_by: address,
}

/// Emitted when a reserve object is created.
public struct ReserveCreated has copy, drop {
    reserve_id: ID,
    sequence: u64,
    custodian: address,
    gross_weight_mg: u64,
    purity_bps: u64,
}

/// Emitted when reserve weight is allocated.
public struct ReserveAllocated has copy, drop {
    reserve_id: ID,
    amount_mg: u64,
    total_allocated_mg: u64,
    available_weight_mg: u64,
    allocated_by: address,
}

/// Emitted when allocated reserve weight is released.
public struct ReserveReleased has copy, drop {
    reserve_id: ID,
    amount_mg: u64,
    total_allocated_mg: u64,
    available_weight_mg: u64,
    released_by: address,
}

/// Emitted when reserve audit data is updated.
public struct ReserveAudited has copy, drop {
    reserve_id: ID,
    audit_epoch: u64,
    audited_by: address,
}

/// Emitted when reserve status changes.
public struct ReserveStatusChanged has copy, drop {
    reserve_id: ID,
    previous_status: u8,
    new_status: u8,
    changed_by: address,
}

/// Initializes the Gold Reserve subsystem.
///
/// The publisher receives the unique ReserveAdminCap.
/// GoldReserveRegistry becomes a shared object.
fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        ReserveAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        GoldReserveRegistry {
            id: object::new(ctx),
            version: 1,
            total_reserves: 0,
            total_custodians: 0,
            total_weight_mg: 0,
            total_allocated_mg: 0,
            total_available_mg: 0,
        },
    );
}

/// Registers a physical gold custodian and transfers its capability.
public fun register_custodian(
    _admin_cap: &ReserveAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldReserveRegistry,
    custodian: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    registry.total_custodians = registry.total_custodians + 1;

    transfer::transfer(
        CustodianCap {
            id: object::new(ctx),
            custodian,
            active: true,
        },
        custodian,
    );

    event::emit(CustodianRegistered {
        custodian,
        registered_by: tx_context::sender(ctx),
    });
}

/// Changes whether a custodian capability can be used.
public fun set_custodian_active(
    _admin_cap: &ReserveAdminCap,
    access_control: &AccessControl,
    custodian_cap: &mut CustodianCap,
    active: bool,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(custodian_cap.active != active, E_UNCHANGED_VALUE);

    custodian_cap.active = active;

    event::emit(CustodianStatusChanged {
        custodian: custodian_cap.custodian,
        active,
        changed_by: tx_context::sender(ctx),
    });
}

/// Creates a shared physical gold reserve object.
public fun create_reserve(
    _admin_cap: &ReserveAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldReserveRegistry,
    custodian: address,
    vault_id: vector<u8>,
    bar_reference: vector<u8>,
    gross_weight_mg: u64,
    purity_bps: u64,
    initial_audit_hash: vector<u8>,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(gross_weight_mg > 0, E_ZERO_WEIGHT);
    assert!(
        purity_bps > 0 && purity_bps <= MAX_PURITY_BPS,
        E_INVALID_PURITY,
    );

    registry.total_reserves = registry.total_reserves + 1;
    registry.total_weight_mg =
        registry.total_weight_mg + gross_weight_mg;
    registry.total_available_mg =
        registry.total_available_mg + gross_weight_mg;

    let sequence = registry.total_reserves;

    let reserve = GoldReserve {
        id: object::new(ctx),
        sequence,
        custodian,
        vault_id,
        bar_reference,
        gross_weight_mg,
        allocated_weight_mg: 0,
        available_weight_mg: gross_weight_mg,
        purity_bps,
        audit_hash: initial_audit_hash,
        last_audit_epoch: tx_context::epoch(ctx),
        status: STATUS_ACTIVE,
        created_at_epoch: tx_context::epoch(ctx),
    };

    let reserve_id = object::uid_to_inner(&reserve.id);

    event::emit(ReserveCreated {
        reserve_id,
        sequence,
        custodian,
        gross_weight_mg,
        purity_bps,
    });

    transfer::share_object(reserve);
}

/// Allocates available reserve weight.
///
/// Later Gold NFT and GOLDPEG minting modules will invoke this operation
/// before creating reserve-backed digital assets.
public fun allocate(
    custodian_cap: &CustodianCap,
    access_control: &AccessControl,
    registry: &mut GoldReserveRegistry,
    reserve: &mut GoldReserve,
    amount_mg: u64,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(custodian_cap.active, E_CUSTODIAN_INACTIVE);
    assert!(
        custodian_cap.custodian == reserve.custodian,
        E_CUSTODIAN_MISMATCH,
    );
    assert!(reserve.status == STATUS_ACTIVE, E_INVALID_STATUS);
    assert!(amount_mg > 0, E_ZERO_WEIGHT);
    assert!(
        reserve.available_weight_mg >= amount_mg,
        E_INSUFFICIENT_AVAILABLE_WEIGHT,
    );

    reserve.available_weight_mg =
        reserve.available_weight_mg - amount_mg;
    reserve.allocated_weight_mg =
        reserve.allocated_weight_mg + amount_mg;

    registry.total_available_mg =
        registry.total_available_mg - amount_mg;
    registry.total_allocated_mg =
        registry.total_allocated_mg + amount_mg;

    event::emit(ReserveAllocated {
        reserve_id: object::uid_to_inner(&reserve.id),
        amount_mg,
        total_allocated_mg: reserve.allocated_weight_mg,
        available_weight_mg: reserve.available_weight_mg,
        allocated_by: tx_context::sender(ctx),
    });
}

/// Releases previously allocated reserve weight.
public fun release(
    custodian_cap: &CustodianCap,
    access_control: &AccessControl,
    registry: &mut GoldReserveRegistry,
    reserve: &mut GoldReserve,
    amount_mg: u64,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(custodian_cap.active, E_CUSTODIAN_INACTIVE);
    assert!(
        custodian_cap.custodian == reserve.custodian,
        E_CUSTODIAN_MISMATCH,
    );
    assert!(reserve.status != STATUS_RETIRED, E_INVALID_STATUS);
    assert!(amount_mg > 0, E_ZERO_WEIGHT);
    assert!(
        reserve.allocated_weight_mg >= amount_mg,
        E_INSUFFICIENT_ALLOCATED_WEIGHT,
    );

    reserve.allocated_weight_mg =
        reserve.allocated_weight_mg - amount_mg;
    reserve.available_weight_mg =
        reserve.available_weight_mg + amount_mg;

    registry.total_allocated_mg =
        registry.total_allocated_mg - amount_mg;
    registry.total_available_mg =
        registry.total_available_mg + amount_mg;

    event::emit(ReserveReleased {
        reserve_id: object::uid_to_inner(&reserve.id),
        amount_mg,
        total_allocated_mg: reserve.allocated_weight_mg,
        available_weight_mg: reserve.available_weight_mg,
        released_by: tx_context::sender(ctx),
    });
}

/// Updates the external audit commitment for a reserve.
public fun record_audit(
    custodian_cap: &CustodianCap,
    access_control: &AccessControl,
    reserve: &mut GoldReserve,
    new_audit_hash: vector<u8>,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(custodian_cap.active, E_CUSTODIAN_INACTIVE);
    assert!(
        custodian_cap.custodian == reserve.custodian,
        E_CUSTODIAN_MISMATCH,
    );
    assert!(reserve.status != STATUS_RETIRED, E_INVALID_STATUS);

    reserve.audit_hash = new_audit_hash;
    reserve.last_audit_epoch = tx_context::epoch(ctx);

    event::emit(ReserveAudited {
        reserve_id: object::uid_to_inner(&reserve.id),
        audit_epoch: reserve.last_audit_epoch,
        audited_by: tx_context::sender(ctx),
    });
}

/// Suspends an active reserve.
public fun suspend_reserve(
    _admin_cap: &ReserveAdminCap,
    access_control: &AccessControl,
    reserve: &mut GoldReserve,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(reserve.status == STATUS_ACTIVE, E_INVALID_STATUS);

    let previous_status = reserve.status;
    reserve.status = STATUS_SUSPENDED;

    event::emit(ReserveStatusChanged {
        reserve_id: object::uid_to_inner(&reserve.id),
        previous_status,
        new_status: STATUS_SUSPENDED,
        changed_by: tx_context::sender(ctx),
    });
}

/// Reactivates a suspended reserve.
public fun reactivate_reserve(
    _admin_cap: &ReserveAdminCap,
    access_control: &AccessControl,
    reserve: &mut GoldReserve,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(reserve.status == STATUS_SUSPENDED, E_INVALID_STATUS);

    let previous_status = reserve.status;
    reserve.status = STATUS_ACTIVE;

    event::emit(ReserveStatusChanged {
        reserve_id: object::uid_to_inner(&reserve.id),
        previous_status,
        new_status: STATUS_ACTIVE,
        changed_by: tx_context::sender(ctx),
    });
}

/// Permanently retires a reserve.
///
/// A reserve cannot be retired while digital assets remain allocated.
public fun retire_reserve(
    _admin_cap: &ReserveAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldReserveRegistry,
    reserve: &mut GoldReserve,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(reserve.status != STATUS_RETIRED, E_INVALID_STATUS);
    assert!(
        reserve.allocated_weight_mg == 0,
        E_OUTSTANDING_ALLOCATION,
    );

    let previous_status = reserve.status;
    reserve.status = STATUS_RETIRED;

    registry.total_weight_mg =
        registry.total_weight_mg - reserve.gross_weight_mg;
    registry.total_available_mg =
        registry.total_available_mg - reserve.available_weight_mg;

    event::emit(ReserveStatusChanged {
        reserve_id: object::uid_to_inner(&reserve.id),
        previous_status,
        new_status: STATUS_RETIRED,
        changed_by: tx_context::sender(ctx),
    });
}

/// Asserts that a reserve can back a new digital asset.
public fun assert_allocatable(
    reserve: &GoldReserve,
    required_weight_mg: u64,
) {
    assert!(reserve.status == STATUS_ACTIVE, E_INVALID_STATUS);
    assert!(required_weight_mg > 0, E_ZERO_WEIGHT);
    assert!(
        reserve.available_weight_mg >= required_weight_mg,
        E_INSUFFICIENT_AVAILABLE_WEIGHT,
    );
}

/// Basic reserve getters.

public fun reserve_id(reserve: &GoldReserve): ID {
    object::uid_to_inner(&reserve.id)
}

public fun sequence(reserve: &GoldReserve): u64 {
    reserve.sequence
}

public fun custodian(reserve: &GoldReserve): address {
    reserve.custodian
}

public fun gross_weight_mg(reserve: &GoldReserve): u64 {
    reserve.gross_weight_mg
}

public fun allocated_weight_mg(reserve: &GoldReserve): u64 {
    reserve.allocated_weight_mg
}

public fun available_weight_mg(reserve: &GoldReserve): u64 {
    reserve.available_weight_mg
}

public fun purity_bps(reserve: &GoldReserve): u64 {
    reserve.purity_bps
}

public fun status(reserve: &GoldReserve): u8 {
    reserve.status
}

public fun is_active(reserve: &GoldReserve): bool {
    reserve.status == STATUS_ACTIVE
}

public fun is_suspended(reserve: &GoldReserve): bool {
    reserve.status == STATUS_SUSPENDED
}

public fun is_retired(reserve: &GoldReserve): bool {
    reserve.status == STATUS_RETIRED
}

public fun last_audit_epoch(reserve: &GoldReserve): u64 {
    reserve.last_audit_epoch
}

public fun registry_total_reserves(
    registry: &GoldReserveRegistry,
): u64 {
    registry.total_reserves
}

public fun registry_total_custodians(
    registry: &GoldReserveRegistry,
): u64 {
    registry.total_custodians
}

public fun registry_total_weight_mg(
    registry: &GoldReserveRegistry,
): u64 {
    registry.total_weight_mg
}

public fun registry_total_allocated_mg(
    registry: &GoldReserveRegistry,
): u64 {
    registry.total_allocated_mg
}

public fun registry_total_available_mg(
    registry: &GoldReserveRegistry,
): u64 {
    registry.total_available_mg
}

public fun custodian_address(
    custodian_cap: &CustodianCap,
): address {
    custodian_cap.custodian
}

public fun custodian_is_active(
    custodian_cap: &CustodianCap,
): bool {
    custodian_cap.active
}

/// ================================================================
/// Test-only reserve construction and destruction
/// ================================================================

#[test_only]
public fun new_reserve_for_testing(
    custodian: address,
    gross_weight_mg: u64,
    purity_bps: u64,
    ctx: &mut TxContext,
): GoldReserve {
    assert!(gross_weight_mg > 0, E_ZERO_WEIGHT);

    assert!(
        purity_bps > 0 && purity_bps <= MAX_PURITY_BPS,
        E_INVALID_PURITY,
    );

    GoldReserve {
        id: object::new(ctx),
        sequence: 1,
        custodian,
        vault_id: b"TEST-VAULT",
        bar_reference: b"TEST-BAR",
        gross_weight_mg,
        allocated_weight_mg: gross_weight_mg,
        available_weight_mg: 0,
        purity_bps,
        audit_hash: b"TEST-AUDIT",
        last_audit_epoch: tx_context::epoch(ctx),
        status: STATUS_ACTIVE,
        created_at_epoch: tx_context::epoch(ctx),
    }
}

#[test_only]
public fun destroy_reserve_for_testing(
    reserve: GoldReserve,
) {
    let GoldReserve {
        id,
        sequence: _,
        custodian: _,
        vault_id: _,
        bar_reference: _,
        gross_weight_mg: _,
        allocated_weight_mg: _,
        available_weight_mg: _,
        purity_bps: _,
        audit_hash: _,
        last_audit_epoch: _,
        status: _,
        created_at_epoch: _,
    } = reserve;

    object::delete(id);
}

#[test_only]
public fun suspend_for_testing(
    reserve: &mut GoldReserve,
) {
    reserve.status = STATUS_SUSPENDED;
}

// TOBMATE_GOLD_MARKETPLACE_RESERVE_TEST_HELPERS
