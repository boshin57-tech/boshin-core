module tobmate_core::treasury_backstop;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::AccessControl;

use tobmate_core::bad_debt_settlement::{
    Self as bad_debt_settlement,
    BadDebtSettlementRegistry,
};

use tobmate_core::lending_pool::LendingPool;

use tobmate_core::treasury::{
    Self as treasury,
    ProtocolTreasury,
    TreasuryAdminCap,
};

/* ============================================================
   Stage 7G
   Treasury Backstop
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

const E_NOT_ADMIN: u64 = 1;
const E_PAUSED: u64 = 2;
const E_ZERO_AMOUNT: u64 = 3;
const E_NO_BAD_DEBT: u64 = 4;
const E_ABOVE_REMAINING_BAD_DEBT: u64 = 5;
const E_INVALID_VERSION: u64 = 6;

/* ============================================================
   Registry
   ============================================================ */

public struct TreasuryBackstopRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    total_backstop_paid: u64,
    settlement_count: u64,
}

/* ============================================================
   Admin Capability
   ============================================================ */

public struct TreasuryBackstopAdminCap has key, store {
    id: UID,
    registry_id: ID,
}

/* ============================================================
   Events
   ============================================================ */

public struct TreasuryBackstopCreated has copy, drop {
    registry_id: ID,
    administrator: address,
}

public struct TreasuryBackstopExecuted has copy, drop {
    registry_id: ID,

    bad_debt_record_id: u64,

    amount: u64,
    remaining_bad_debt: u64,

    total_backstop_paid: u64,
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
        TreasuryBackstopRegistry {
            id: object::new(ctx),

            version: PROTOCOL_VERSION,
            paused: false,

            total_backstop_paid: 0,
            settlement_count: 0,
        };

    let registry_id =
        object::id(&registry);

    let admin_cap =
        TreasuryBackstopAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    event::emit(
        TreasuryBackstopCreated {
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
   Treasury Backstop Settlement
   ============================================================ */

public fun execute_backstop(
    access: &AccessControl,

    registry: &mut TreasuryBackstopRegistry,
    admin_cap: &TreasuryBackstopAdminCap,

    treasury_admin_cap: &TreasuryAdminCap,
    protocol_treasury: &mut ProtocolTreasury,

    bad_debt_registry: &mut BadDebtSettlementRegistry,
    lending_pool: &mut LendingPool,

    bad_debt_record_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert_operational(
        registry,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let remaining_before =
        bad_debt_settlement::
            record_remaining_bad_debt(
                bad_debt_registry,
                bad_debt_record_id,
            );

    assert!(
        remaining_before > 0,
        E_NO_BAD_DEBT,
    );

    assert!(
        amount <= remaining_before,
        E_ABOVE_REMAINING_BAD_DEBT,
    );

    let recovery =
        treasury::withdraw_for_backstop(
            treasury_admin_cap,
            access,
            protocol_treasury,
            amount,
            ctx,
        );

    bad_debt_settlement::apply_recovery(
        access,
        bad_debt_registry,
        lending_pool,
        bad_debt_record_id,
        recovery,
        ctx,
    );

    registry.total_backstop_paid =
        registry.total_backstop_paid
            + amount;

    registry.settlement_count =
        registry.settlement_count + 1;

    let remaining_after =
        bad_debt_settlement::
            record_remaining_bad_debt(
                bad_debt_registry,
                bad_debt_record_id,
            );

    event::emit(
        TreasuryBackstopExecuted {
            registry_id:
                object::id(registry),

            bad_debt_record_id,

            amount,

            remaining_bad_debt:
                remaining_after,

            total_backstop_paid:
                registry.total_backstop_paid,
        },
    );
}

/* ============================================================
   Administration
   ============================================================ */

public fun set_paused(
    registry: &mut TreasuryBackstopRegistry,
    admin_cap: &TreasuryBackstopAdminCap,
    paused: bool,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    registry.paused = paused;
}

public fun set_version(
    registry: &mut TreasuryBackstopRegistry,
    admin_cap: &TreasuryBackstopAdminCap,
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
   Internal
   ============================================================ */

fun assert_admin(
    registry: &TreasuryBackstopRegistry,
    admin_cap: &TreasuryBackstopAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_NOT_ADMIN,
    );
}

fun assert_operational(
    registry: &TreasuryBackstopRegistry,
) {
    assert!(
        !registry.paused,
        E_PAUSED,
    );
}

/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &TreasuryBackstopRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &TreasuryBackstopRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &TreasuryBackstopRegistry,
): bool {
    registry.paused
}

public fun total_backstop_paid(
    registry: &TreasuryBackstopRegistry,
): u64 {
    registry.total_backstop_paid
}

public fun settlement_count(
    registry: &TreasuryBackstopRegistry,
): u64 {
    registry.settlement_count
}

/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): TreasuryBackstopRegistry {
    TreasuryBackstopRegistry {
        id: object::new(ctx),

        version: PROTOCOL_VERSION,
        paused: false,

        total_backstop_paid: 0,
        settlement_count: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &TreasuryBackstopRegistry,
    ctx: &mut TxContext,
): TreasuryBackstopAdminCap {
    TreasuryBackstopAdminCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: TreasuryBackstopAdminCap,
) {
    let TreasuryBackstopAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: TreasuryBackstopRegistry,
) {
    let TreasuryBackstopRegistry {
        id,
        version: _,
        paused: _,
        total_backstop_paid: _,
        settlement_count: _,
    } = registry;

    object::delete(id);
}
