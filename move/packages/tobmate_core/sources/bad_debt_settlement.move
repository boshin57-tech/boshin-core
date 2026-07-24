module tobmate_core::bad_debt_settlement;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::AccessControl;
use tobmate_core::lending_pool::{Self as lending_pool, LendingPool};
use tobmate_core::insurance_fund::{Self as insurance_fund, InsuranceFund};

/* ============================================================
   Stage 6D-3
   Bad Debt & Insurance Settlement Registry
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

const E_NOT_ADMIN: u64 = 1;
const E_PAUSED: u64 = 2;
const E_INVALID_VERSION: u64 = 3;
const E_ZERO_BAD_DEBT: u64 = 4;
const E_DUPLICATE_BAD_DEBT: u64 = 5;
const E_BAD_DEBT_NOT_FOUND: u64 = 6;
const E_INVALID_STATUS: u64 = 7;
const E_RECOVERY_ABOVE_REMAINING: u64 = 8;

const STATUS_OPEN: u8 = 1;
const STATUS_CLAIM_SUBMITTED: u8 = 2;
const STATUS_PARTIALLY_RECOVERED: u8 = 3;
const STATUS_RECOVERED: u8 = 4;

const INSURANCE_CLAIM_TYPE_BAD_DEBT: u64 = 100;

/* ============================================================
   Registry
   ============================================================ */

public struct BadDebtSettlementRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_record_id: u64,

    records: vector<BadDebtRecord>,

    total_bad_debt_recorded: u64,
    total_recovered: u64,
}

/* ============================================================
   Admin Capability
   ============================================================ */

public struct BadDebtSettlementAdminCap has key, store {
    id: UID,
    registry_id: ID,
}

/* ============================================================
   Bad Debt Record
   ============================================================ */

public struct BadDebtRecord has store {
    record_id: u64,

    borrow_position_id: u64,
    collateral_position_id: u64,

    borrower: address,

    original_bad_debt: u64,
    recovered_amount: u64,
    remaining_bad_debt: u64,

    insurance_claim_id: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}

/* ============================================================
   Events
   ============================================================ */

public struct BadDebtRegistryCreated has copy, drop {
    registry_id: ID,
    administrator: address,
}

public struct BadDebtRecorded has copy, drop {
    registry_id: ID,
    record_id: u64,

    borrow_position_id: u64,
    collateral_position_id: u64,

    borrower: address,
    bad_debt_amount: u64,
}

public struct InsuranceClaimLinked has copy, drop {
    registry_id: ID,
    record_id: u64,
    insurance_claim_id: u64,
}

public struct BadDebtRecovered has copy, drop {
    registry_id: ID,
    record_id: u64,

    recovered_amount: u64,
    remaining_bad_debt: u64,
}

/* ============================================================
   Initialization
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
) {
    let administrator =
        tx_context::sender(ctx);

    let registry =
        BadDebtSettlementRegistry {
            id: object::new(ctx),

            version: PROTOCOL_VERSION,
            paused: false,

            next_record_id: 1,

            records: vector[],

            total_bad_debt_recorded: 0,
            total_recovered: 0,
        };

    let registry_id =
        object::id(&registry);

    let admin_cap =
        BadDebtSettlementAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    event::emit(
        BadDebtRegistryCreated {
            registry_id,
            administrator,
        },
    );

    transfer::share_object(registry);

    transfer::public_transfer(
        admin_cap,
        administrator,
    );
}

/* ============================================================
   Administration
   ============================================================ */

public fun set_paused(
    registry: &mut BadDebtSettlementRegistry,
    admin_cap: &BadDebtSettlementAdminCap,
    paused: bool,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    registry.paused = paused;
}

public fun set_version(
    registry: &mut BadDebtSettlementRegistry,
    admin_cap: &BadDebtSettlementAdminCap,
    new_version: u64,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_version > registry.version,
        E_INVALID_VERSION,
    );

    registry.version =
        new_version;
}

/* ============================================================
   Record Bad Debt
   ============================================================ */

public(package) fun record_bad_debt(
    access: &AccessControl,
    registry: &mut BadDebtSettlementRegistry,
    pool: &mut LendingPool,

    borrow_position_id: u64,
    collateral_position_id: u64,
    borrower: address,

    amount: u64,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        registry,
    );

    assert!(
        amount > 0,
        E_ZERO_BAD_DEBT,
    );

    assert!(
        !contains_open_record(
            registry,
            borrow_position_id,
        ),
        E_DUPLICATE_BAD_DEBT,
    );

    lending_pool::record_bad_debt(
        access,
        pool,
        amount,
    );

    let record_id =
        registry.next_record_id;

    registry.next_record_id =
        record_id + 1;

    vector::push_back(
        &mut registry.records,
        BadDebtRecord {
            record_id,

            borrow_position_id,
            collateral_position_id,

            borrower,

            original_bad_debt:
                amount,

            recovered_amount:
                0,

            remaining_bad_debt:
                amount,

            insurance_claim_id:
                0,

            status:
                STATUS_OPEN,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_bad_debt_recorded =
        registry.total_bad_debt_recorded
            + amount;

    event::emit(
        BadDebtRecorded {
            registry_id:
                object::id(registry),

            record_id,

            borrow_position_id,
            collateral_position_id,

            borrower,

            bad_debt_amount:
                amount,
        },
    );

    record_id
}

/* ============================================================
   Link Insurance Claim
   ============================================================ */

public fun link_insurance_claim(
    registry: &mut BadDebtSettlementRegistry,
    admin_cap: &BadDebtSettlementAdminCap,
    record_id: u64,
    insurance_claim_id: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert_operational(
        registry,
    );

    let index =
        find_record_index(
            registry,
            record_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.records,
            index,
        );

    assert!(
        record.status == STATUS_OPEN,
        E_INVALID_STATUS,
    );

    record.insurance_claim_id =
        insurance_claim_id;

    record.status =
        STATUS_CLAIM_SUBMITTED;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        InsuranceClaimLinked {
            registry_id:
                object::id(registry),

            record_id,
            insurance_claim_id,
        },
    );
}

/* ============================================================
   Apply Recovery
   ============================================================ */

public(package) fun apply_recovery(
    access: &AccessControl,
    registry: &mut BadDebtSettlementRegistry,
    pool: &mut LendingPool,

    record_id: u64,
    recovery: sui::coin::Coin<sui::sui::SUI>,

    ctx: &mut TxContext,
) {
    assert_operational(
        registry,
    );

    let index =
        find_record_index(
            registry,
            record_id,
        );

    let recovery_amount =
        sui::coin::value(
            &recovery,
        );

    assert!(
        recovery_amount > 0,
        E_ZERO_BAD_DEBT,
    );

    let remaining_before;

    {
        let record =
            vector::borrow(
                &registry.records,
                index,
            );

        assert!(
            record.status == STATUS_CLAIM_SUBMITTED
                || record.status == STATUS_PARTIALLY_RECOVERED,
            E_INVALID_STATUS,
        );

        remaining_before =
            record.remaining_bad_debt;
    };

    assert!(
        recovery_amount
            <= remaining_before,
        E_RECOVERY_ABOVE_REMAINING,
    );

    lending_pool::recover_bad_debt(
        access,
        pool,
        recovery,
    );

    {
        let record =
            vector::borrow_mut(
                &mut registry.records,
                index,
            );

        record.recovered_amount =
            record.recovered_amount
                + recovery_amount;

        record.remaining_bad_debt =
            record.remaining_bad_debt
                - recovery_amount;

        if (record.remaining_bad_debt == 0) {
            record.status =
                STATUS_RECOVERED;
        } else {
            record.status =
                STATUS_PARTIALLY_RECOVERED;
        };

        record.updated_epoch =
            tx_context::epoch(ctx);
    };

    registry.total_recovered =
        registry.total_recovered
            + recovery_amount;

    let remaining_after =
        vector::borrow(
            &registry.records,
            index,
        ).remaining_bad_debt;

    event::emit(
        BadDebtRecovered {
            registry_id:
                object::id(registry),

            record_id,

            recovered_amount:
                recovery_amount,

            remaining_bad_debt:
                remaining_after,
        },
    );
}

/* ============================================================
   Internal Helpers
   ============================================================ */

fun assert_admin(
    registry: &BadDebtSettlementRegistry,
    admin_cap: &BadDebtSettlementAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_NOT_ADMIN,
    );
}

fun assert_operational(
    registry: &BadDebtSettlementRegistry,
) {
    assert!(
        !registry.paused,
        E_PAUSED,
    );
}

fun find_record_index(
    registry: &BadDebtSettlementRegistry,
    record_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.records,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.records,
                i,
            );

        if (record.record_id == record_id) {
            return i
        };

        i = i + 1;
    };

    abort E_BAD_DEBT_NOT_FOUND
}

fun contains_open_record(
    registry: &BadDebtSettlementRegistry,
    borrow_position_id: u64,
): bool {
    let length =
        vector::length(
            &registry.records,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.records,
                i,
            );

        if (
            record.borrow_position_id
                == borrow_position_id
            && record.remaining_bad_debt > 0
        ) {
            return true
        };

        i = i + 1;
    };

    false
}

/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &BadDebtSettlementRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &BadDebtSettlementRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &BadDebtSettlementRegistry,
): bool {
    registry.paused
}

public fun record_count(
    registry: &BadDebtSettlementRegistry,
): u64 {
    vector::length(
        &registry.records,
    )
}

public fun total_bad_debt_recorded(
    registry: &BadDebtSettlementRegistry,
): u64 {
    registry.total_bad_debt_recorded
}

public fun total_recovered(
    registry: &BadDebtSettlementRegistry,
): u64 {
    registry.total_recovered
}

public fun record_original_bad_debt(
    registry: &BadDebtSettlementRegistry,
    record_id: u64,
): u64 {
    let index =
        find_record_index(
            registry,
            record_id,
        );

    vector::borrow(
        &registry.records,
        index,
    ).original_bad_debt
}

public fun record_recovered_amount(
    registry: &BadDebtSettlementRegistry,
    record_id: u64,
): u64 {
    let index =
        find_record_index(
            registry,
            record_id,
        );

    vector::borrow(
        &registry.records,
        index,
    ).recovered_amount
}

public fun record_remaining_bad_debt(
    registry: &BadDebtSettlementRegistry,
    record_id: u64,
): u64 {
    let index =
        find_record_index(
            registry,
            record_id,
        );

    vector::borrow(
        &registry.records,
        index,
    ).remaining_bad_debt
}

public fun record_insurance_claim_id(
    registry: &BadDebtSettlementRegistry,
    record_id: u64,
): u64 {
    let index =
        find_record_index(
            registry,
            record_id,
        );

    vector::borrow(
        &registry.records,
        index,
    ).insurance_claim_id
}

public fun record_status(
    registry: &BadDebtSettlementRegistry,
    record_id: u64,
): u8 {
    let index =
        find_record_index(
            registry,
            record_id,
        );

    vector::borrow(
        &registry.records,
        index,
    ).status
}

public fun status_open(): u8 {
    STATUS_OPEN
}

public fun status_claim_submitted(): u8 {
    STATUS_CLAIM_SUBMITTED
}

public fun status_partially_recovered(): u8 {
    STATUS_PARTIALLY_RECOVERED
}

public fun status_recovered(): u8 {
    STATUS_RECOVERED
}

/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): BadDebtSettlementRegistry {
    BadDebtSettlementRegistry {
        id: object::new(ctx),

        version: PROTOCOL_VERSION,
        paused: false,

        next_record_id: 1,

        records: vector[],

        total_bad_debt_recorded: 0,
        total_recovered: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &BadDebtSettlementRegistry,
    ctx: &mut TxContext,
): BadDebtSettlementAdminCap {
    BadDebtSettlementAdminCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: BadDebtSettlementRegistry,
) {
    let BadDebtSettlementRegistry {
        id,
        version: _,
        paused: _,
        next_record_id: _,
        mut records,
        total_bad_debt_recorded: _,
        total_recovered: _,
    } = registry;

    while (!vector::is_empty(&records)) {
        let BadDebtRecord {
            record_id: _,
            borrow_position_id: _,
            collateral_position_id: _,
            borrower: _,
            original_bad_debt: _,
            recovered_amount: _,
            remaining_bad_debt: _,
            insurance_claim_id: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut records,
        );
    };

    vector::destroy_empty(
        records,
    );

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: BadDebtSettlementAdminCap,
) {
    let BadDebtSettlementAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

/* ============================================================
   Stage 6D-3
   Submit Insurance Claim For Bad Debt
   ============================================================ */

public fun submit_insurance_claim_for_bad_debt(
    access: &AccessControl,

    registry: &mut BadDebtSettlementRegistry,
    admin_cap: &BadDebtSettlementAdminCap,

    insurance_fund: &mut InsuranceFund,

    record_id: u64,
    evidence_hash: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    assert_admin(
        registry,
        admin_cap,
    );

    assert_operational(
        registry,
    );

    let index =
        find_record_index(
            registry,
            record_id,
        );

    let requested_amount;

    {
        let record =
            vector::borrow(
                &registry.records,
                index,
            );

        assert!(
            record.status == STATUS_OPEN,
            E_INVALID_STATUS,
        );

        assert!(
            record.remaining_bad_debt > 0,
            E_ZERO_BAD_DEBT,
        );

        assert!(
            record.insurance_claim_id == 0,
            E_INVALID_STATUS,
        );

        requested_amount =
            record.remaining_bad_debt;
    };

    /*
       InsuranceFund records tx_context::sender(ctx)
       as the claimant.

       The insurance payout will later be transferred
       to this claimant address.
    */

    let claim_id =
        insurance_fund::submit_claim(
            access,
            insurance_fund,

            requested_amount,

            INSURANCE_CLAIM_TYPE_BAD_DEBT,

            evidence_hash,

            ctx,
        );

    {
        let record =
            vector::borrow_mut(
                &mut registry.records,
                index,
            );

        record.insurance_claim_id =
            claim_id;

        record.status =
            STATUS_CLAIM_SUBMITTED;

        record.updated_epoch =
            tx_context::epoch(ctx);
    };

    event::emit(
        InsuranceClaimLinked {
            registry_id:
                object::id(registry),

            record_id,

            insurance_claim_id:
                claim_id,
        },
    );

    claim_id
}

/* ============================================================
   Insurance Settlement Validation
   ============================================================ */

public fun assert_insurance_claim_paid(
    registry: &BadDebtSettlementRegistry,
    insurance_fund: &InsuranceFund,
    record_id: u64,
) {
    let index =
        find_record_index(
            registry,
            record_id,
        );

    let record =
        vector::borrow(
            &registry.records,
            index,
        );

    assert!(
        record.insurance_claim_id > 0,
        E_INVALID_STATUS,
    );

    assert!(
        insurance_fund::claim_status(
            insurance_fund,
            record.insurance_claim_id,
        ) == insurance_fund::status_paid(),
        E_INVALID_STATUS,
    );
}

public fun insurance_claim_type_bad_debt(): u64 {
    INSURANCE_CLAIM_TYPE_BAD_DEBT
}
