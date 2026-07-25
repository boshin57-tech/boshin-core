module tobmate_core::treasury_strategy_recovery;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::AccessControl;

use tobmate_core::insurance_fund::{
    Self as insurance_fund,
    InsuranceFund,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
    TreasuryYieldEngine,
};

use tobmate_core::treasury::{
    Self as treasury,
    ProtocolTreasury,
    TreasuryAdminCap,
};

/* ============================================================
   Stage 9 Part 3-A
   Treasury Strategy Loss Recovery Registry
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

const STATUS_OPEN: u8 = 1;
const STATUS_PARTIALLY_RECOVERED: u8 = 2;
const STATUS_RECOVERED: u8 = 3;

const E_NOT_ADMIN: u64 = 1;
const E_PAUSED: u64 = 2;
const E_ZERO_LOSS: u64 = 3;
const E_DUPLICATE_RECOVERY: u64 = 4;
const E_RECORD_NOT_FOUND: u64 = 5;
const E_INVALID_VERSION: u64 = 6;
const E_RECOVERY_ABOVE_REMAINING: u64 = 7;
const E_ACCOUNTING_INVARIANT: u64 = 8;
const E_STRATEGY_LOSS_MISMATCH: u64 = 9;
const E_INVALID_RECOVERY_STATUS: u64 = 10;
const E_INSURANCE_CLAIM_ALREADY_LINKED: u64 = 11;
const E_INSURANCE_CLAIM_NOT_PAID: u64 = 12;
const E_INSURANCE_RECOVERY_ALREADY_APPLIED: u64 = 13;

const INSURANCE_CLAIM_TYPE_STRATEGY_LOSS: u64 = 2;

/* ============================================================
   Registry
   ============================================================ */

public struct TreasuryStrategyRecoveryRegistry has key {
    id: UID,
    version: u64,
    paused: bool,

    next_record_id: u64,
    records: vector<StrategyRecoveryRecord>,

    total_loss_recorded: u64,
    total_insurance_recovered: u64,
    total_treasury_recovered: u64,
    total_recovered: u64,
}

/* ============================================================
   Admin Capability
   ============================================================ */

public struct TreasuryStrategyRecoveryAdminCap has key, store {
    id: UID,
    registry_id: ID,
}

/* ============================================================
   Recovery Record
   ============================================================ */

public struct StrategyRecoveryRecord has store {
    record_id: u64,
    yield_engine_id: ID,
    strategy_id: u64,

    original_loss: u64,

    insurance_claim_id: u64,
    insurance_recovery_applied: bool,

    insurance_recovered: u64,
    treasury_recovered: u64,
    total_recovered: u64,
    remaining_loss: u64,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}

/* ============================================================
   Events
   ============================================================ */

public struct StrategyRecoveryRegistryCreated has copy, drop {
    registry_id: ID,
    administrator: address,
}

public struct StrategyLossRecoveryRecorded has copy, drop {
    registry_id: ID,
    record_id: u64,
    yield_engine_id: ID,
    strategy_id: u64,
    original_loss: u64,
}

/* ============================================================
   Initialization
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
) {
    let administrator = tx_context::sender(ctx);

    let registry =
        TreasuryStrategyRecoveryRegistry {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,
            paused: false,

            next_record_id: 1,
            records: vector[],

            total_loss_recorded: 0,
            total_insurance_recovered: 0,
            total_treasury_recovered: 0,
            total_recovered: 0,
        };

    let registry_id = object::id(&registry);

    let admin_cap =
        TreasuryStrategyRecoveryAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    event::emit(
        StrategyRecoveryRegistryCreated {
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
    registry: &mut TreasuryStrategyRecoveryRegistry,
    admin_cap: &TreasuryStrategyRecoveryAdminCap,
    paused: bool,
) {
    assert_admin(registry, admin_cap);
    registry.paused = paused;
}

public fun set_version(
    registry: &mut TreasuryStrategyRecoveryRegistry,
    admin_cap: &TreasuryStrategyRecoveryAdminCap,
    new_version: u64,
) {
    assert_admin(registry, admin_cap);

    assert!(
        new_version > registry.version,
        E_INVALID_VERSION,
    );

    registry.version = new_version;
}

/* ============================================================
   Record Strategy Loss
   ============================================================ */

public fun record_strategy_loss(
    registry: &mut TreasuryStrategyRecoveryRegistry,
    admin_cap: &TreasuryStrategyRecoveryAdminCap,
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
    loss_amount: u64,
    ctx: &mut TxContext,
): u64 {
    assert_admin(registry, admin_cap);
    assert_operational(registry);

    assert!(
        loss_amount > 0,
        E_ZERO_LOSS,
    );

    assert!(
        !contains_open_record(
            registry,
            yield_engine::engine_id(engine),
            strategy_id,
        ),
        E_DUPLICATE_RECOVERY,
    );

    let recognized_loss =
        yield_engine::strategy_recognized_loss(
            engine,
            strategy_id,
        );

    assert!(
        loss_amount <= recognized_loss,
        E_STRATEGY_LOSS_MISMATCH,
    );

    let record_id = registry.next_record_id;

    registry.next_record_id =
        record_id + 1;

    let engine_id =
        yield_engine::engine_id(engine);

    vector::push_back(
        &mut registry.records,
        StrategyRecoveryRecord {
            record_id,
            yield_engine_id: engine_id,
            strategy_id,

            original_loss: loss_amount,

            insurance_claim_id: 0,
            insurance_recovery_applied: false,

            insurance_recovered: 0,
            treasury_recovered: 0,
            total_recovered: 0,
            remaining_loss: loss_amount,

            status: STATUS_OPEN,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_loss_recorded =
        registry.total_loss_recorded
            + loss_amount;

    assert_accounting_invariant(registry);

    event::emit(
        StrategyLossRecoveryRecorded {
            registry_id: object::id(registry),
            record_id,
            yield_engine_id: engine_id,
            strategy_id,
            original_loss: loss_amount,
        },
    );

    record_id
}

/* ============================================================
   Internal Helpers
   ============================================================ */

fun assert_admin(
    registry: &TreasuryStrategyRecoveryRegistry,
    admin_cap: &TreasuryStrategyRecoveryAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_NOT_ADMIN,
    );
}

fun assert_operational(
    registry: &TreasuryStrategyRecoveryRegistry,
) {
    assert!(
        !registry.paused,
        E_PAUSED,
    );
}

fun contains_open_record(
    registry: &TreasuryStrategyRecoveryRegistry,
    yield_engine_id: ID,
    strategy_id: u64,
): bool {
    let mut i = 0;
    let length = vector::length(&registry.records);

    while (i < length) {
        let record =
            vector::borrow(
                &registry.records,
                i,
            );

        if (
            record.yield_engine_id
                == yield_engine_id
                && record.strategy_id
                    == strategy_id
                && record.status
                    != STATUS_RECOVERED
        ) {
            return true
        };

        i = i + 1;
    };

    false
}

fun find_record_index(
    registry: &TreasuryStrategyRecoveryRegistry,
    record_id: u64,
): u64 {
    let mut i = 0;
    let length = vector::length(&registry.records);

    while (i < length) {
        if (
            vector::borrow(
                &registry.records,
                i,
            ).record_id == record_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_RECORD_NOT_FOUND
}

/* ============================================================
   Accounting Invariant
   ============================================================ */

public fun assert_accounting_invariant(
    registry: &TreasuryStrategyRecoveryRegistry,
) {
    assert!(
        registry.total_recovered
            == registry.total_insurance_recovered
                + registry.total_treasury_recovered,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        registry.total_recovered
            <= registry.total_loss_recorded,
        E_ACCOUNTING_INVARIANT,
    );

    let mut i = 0;
    let length = vector::length(&registry.records);

    while (i < length) {
        let record =
            vector::borrow(
                &registry.records,
                i,
            );

        assert!(
            record.total_recovered
                == record.insurance_recovered
                    + record.treasury_recovered,
            E_ACCOUNTING_INVARIANT,
        );

        assert!(
            record.total_recovered
                <= record.original_loss,
            E_ACCOUNTING_INVARIANT,
        );

        assert!(
            record.remaining_loss
                == record.original_loss
                    - record.total_recovered,
            E_ACCOUNTING_INVARIANT,
        );

        i = i + 1;
    };
}

/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &TreasuryStrategyRecoveryRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &TreasuryStrategyRecoveryRegistry,
): bool {
    registry.paused
}

public fun record_count(
    registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    vector::length(&registry.records)
}

public fun total_loss_recorded(
    registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    registry.total_loss_recorded
}

public fun total_insurance_recovered(
    registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    registry.total_insurance_recovered
}

public fun total_treasury_recovered(
    registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    registry.total_treasury_recovered
}

public fun total_recovered(
    registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    registry.total_recovered
}

public fun record_original_loss(
    registry: &TreasuryStrategyRecoveryRegistry,
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
    ).original_loss
}

public fun record_remaining_loss(
    registry: &TreasuryStrategyRecoveryRegistry,
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
    ).remaining_loss
}

public fun record_total_recovered(
    registry: &TreasuryStrategyRecoveryRegistry,
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
    ).total_recovered
}

public fun record_strategy_id(
    registry: &TreasuryStrategyRecoveryRegistry,
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
    ).strategy_id
}

public fun record_status(
    registry: &TreasuryStrategyRecoveryRegistry,
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
): TreasuryStrategyRecoveryRegistry {
    TreasuryStrategyRecoveryRegistry {
        id: object::new(ctx),
        version: PROTOCOL_VERSION,
        paused: false,

        next_record_id: 1,
        records: vector[],

        total_loss_recorded: 0,
        total_insurance_recovered: 0,
        total_treasury_recovered: 0,
        total_recovered: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &TreasuryStrategyRecoveryRegistry,
    ctx: &mut TxContext,
): TreasuryStrategyRecoveryAdminCap {
    TreasuryStrategyRecoveryAdminCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: TreasuryStrategyRecoveryAdminCap,
) {
    let TreasuryStrategyRecoveryAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: TreasuryStrategyRecoveryRegistry,
) {
    let TreasuryStrategyRecoveryRegistry {
        id,
        version: _,
        paused: _,
        next_record_id: _,
        mut records,
        total_loss_recorded: _,
        total_insurance_recovered: _,
        total_treasury_recovered: _,
        total_recovered: _,
    } = registry;

    while (!vector::is_empty(&records)) {
        let StrategyRecoveryRecord {
            record_id: _,
            yield_engine_id: _,
            strategy_id: _,
            original_loss: _,
            insurance_claim_id: _,
            insurance_recovery_applied: _,
            insurance_recovered: _,
            treasury_recovered: _,
            total_recovered: _,
            remaining_loss: _,
            status: _,
            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut records,
        );
    };

    vector::destroy_empty(records);
    object::delete(id);
}


/* ============================================================
   Stage 9 Part 3-B
   Insurance Recovery Integration
   ============================================================ */

public fun submit_insurance_claim_for_strategy_loss(
    access: &AccessControl,
    registry: &mut TreasuryStrategyRecoveryRegistry,
    admin_cap: &TreasuryStrategyRecoveryAdminCap,
    insurance: &mut InsuranceFund,
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
            record.status == STATUS_OPEN
                || record.status == STATUS_PARTIALLY_RECOVERED,
            E_INVALID_RECOVERY_STATUS,
        );

        assert!(
            record.remaining_loss > 0,
            E_INVALID_RECOVERY_STATUS,
        );

        assert!(
            record.insurance_claim_id == 0,
            E_INSURANCE_CLAIM_ALREADY_LINKED,
        );

        requested_amount =
            record.remaining_loss;
    };

    let claim_id =
        insurance_fund::submit_claim(
            access,
            insurance,
            requested_amount,
            INSURANCE_CLAIM_TYPE_STRATEGY_LOSS,
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

        record.updated_epoch =
            tx_context::epoch(ctx);
    };

    claim_id
}


public fun apply_paid_insurance_recovery(
    registry: &mut TreasuryStrategyRecoveryRegistry,
    admin_cap: &TreasuryStrategyRecoveryAdminCap,
    insurance: &InsuranceFund,
    record_id: u64,
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

    let claim_id;
    let remaining_before;

    {
        let record =
            vector::borrow(
                &registry.records,
                index,
            );

        assert!(
            record.insurance_claim_id > 0,
            E_INVALID_RECOVERY_STATUS,
        );

        assert!(
            !record.insurance_recovery_applied,
            E_INSURANCE_RECOVERY_ALREADY_APPLIED,
        );

        claim_id =
            record.insurance_claim_id;

        remaining_before =
            record.remaining_loss;
    };

    assert!(
        insurance_fund::claim_status(
            insurance,
            claim_id,
        ) == insurance_fund::status_paid(),
        E_INSURANCE_CLAIM_NOT_PAID,
    );

    let recovered_amount =
        insurance_fund::claim_approved_amount(
            insurance,
            claim_id,
        );

    assert!(
        recovered_amount > 0
            && recovered_amount <= remaining_before,
        E_RECOVERY_ABOVE_REMAINING,
    );

    {
        let record =
            vector::borrow_mut(
                &mut registry.records,
                index,
            );

        record.insurance_recovered =
            record.insurance_recovered
                + recovered_amount;

        record.total_recovered =
            record.total_recovered
                + recovered_amount;

        record.remaining_loss =
            record.remaining_loss
                - recovered_amount;

        record.insurance_recovery_applied =
            true;

        if (record.remaining_loss == 0) {
            record.status =
                STATUS_RECOVERED;
        } else {
            record.status =
                STATUS_PARTIALLY_RECOVERED;
        };

        record.updated_epoch =
            tx_context::epoch(ctx);
    };

    registry.total_insurance_recovered =
        registry.total_insurance_recovered
            + recovered_amount;

    registry.total_recovered =
        registry.total_recovered
            + recovered_amount;

    assert_accounting_invariant(
        registry,
    );
}


/* ============================================================
   Insurance Recovery Read API
   ============================================================ */

public fun record_insurance_claim_id(
    registry: &TreasuryStrategyRecoveryRegistry,
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

public fun record_insurance_recovered(
    registry: &TreasuryStrategyRecoveryRegistry,
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
    ).insurance_recovered
}

public fun insurance_claim_type_strategy_loss(): u64 {
    INSURANCE_CLAIM_TYPE_STRATEGY_LOSS
}


/* ============================================================
   Stage 9 Part 3-C
   Treasury Residual Recovery
   ============================================================ */

public fun execute_treasury_recovery(
    access: &AccessControl,

    registry: &mut TreasuryStrategyRecoveryRegistry,
    recovery_admin_cap: &TreasuryStrategyRecoveryAdminCap,

    treasury_admin_cap: &TreasuryAdminCap,
    protocol_treasury: &mut ProtocolTreasury,

    engine: &mut TreasuryYieldEngine,

    record_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        recovery_admin_cap,
    );

    assert_operational(
        registry,
    );

    assert!(
        amount > 0,
        E_ZERO_LOSS,
    );

    let index =
        find_record_index(
            registry,
            record_id,
        );

    let remaining_before;

    {
        let record =
            vector::borrow(
                &registry.records,
                index,
            );

        assert!(
            record.status == STATUS_OPEN
                || record.status == STATUS_PARTIALLY_RECOVERED,
            E_INVALID_RECOVERY_STATUS,
        );

        remaining_before =
            record.remaining_loss;
    };

    assert!(
        amount <= remaining_before,
        E_RECOVERY_ABOVE_REMAINING,
    );

    /*
     * Actual SUI leaves ProtocolTreasury.
     */
    let recovery_payment =
        treasury::withdraw_for_strategy_recovery(
            treasury_admin_cap,
            access,
            protocol_treasury,
            amount,
            ctx,
        );

    /*
     * The same SUI is atomically restored to the
     * Treasury Yield Engine as recovery inflow.
     */
    yield_engine::deposit_recovery(
        access,
        engine,
        recovery_payment,
    );

    {
        let record =
            vector::borrow_mut(
                &mut registry.records,
                index,
            );

        record.treasury_recovered =
            record.treasury_recovered + amount;

        record.total_recovered =
            record.total_recovered + amount;

        record.remaining_loss =
            record.remaining_loss - amount;

        if (record.remaining_loss == 0) {
            record.status =
                STATUS_RECOVERED;
        } else {
            record.status =
                STATUS_PARTIALLY_RECOVERED;
        };

        record.updated_epoch =
            tx_context::epoch(ctx);
    };

    registry.total_treasury_recovered =
        registry.total_treasury_recovered + amount;

    registry.total_recovered =
        registry.total_recovered + amount;

    assert_accounting_invariant(
        registry,
    );

    treasury::assert_accounting_invariant(
        protocol_treasury,
    );

    yield_engine::assert_accounting_invariant(
        engine,
    );
}


/* ============================================================
   Treasury Recovery Read API
   ============================================================ */

public fun record_treasury_recovered(
    registry: &TreasuryStrategyRecoveryRegistry,
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
    ).treasury_recovered
}
