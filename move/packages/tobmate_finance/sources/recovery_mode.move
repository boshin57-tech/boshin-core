module tobmate_finance::recovery_mode;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_finance::insurance_fund::InsuranceFund;
use tobmate_finance::lending_pool::LendingPool;
use tobmate_finance::protocol_solvency;
use tobmate_finance::treasury::ProtocolTreasury;

/* ============================================================
   Stage 7I
   Emergency Controls / Recovery Mode
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

const MODE_NORMAL: u8 = 1;
const MODE_RECOVERY: u8 = 2;

const DEFAULT_RECOVERY_THRESHOLD_BPS: u128 = 10_000;

const E_NOT_ADMIN: u64 = 1;
const E_INVALID_VERSION: u64 = 2;
const E_INVALID_THRESHOLD: u64 = 3;
const E_STATE_UNCHANGED: u64 = 4;
const E_RISK_INCREASE_BLOCKED: u64 = 5;
const E_RECOVERY_NOT_REQUIRED: u64 = 6;
const E_RECOVERY_STILL_REQUIRED: u64 = 7;


/* ============================================================
   Registry
   ============================================================ */

public struct RecoveryModeRegistry has key {
    id: UID,

    version: u64,

    mode: u8,

    recovery_threshold_bps: u128,

    activation_count: u64,
    recovery_count: u64,

    last_observed_coverage_bps: u128,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct RecoveryModeAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Events
   ============================================================ */

public struct RecoveryModeCreated has copy, drop {
    registry_id: ID,
    administrator: address,
    threshold_bps: u128,
}

public struct RecoveryModeActivated has copy, drop {
    registry_id: ID,
    coverage_bps: u128,
    threshold_bps: u128,
}

public struct RecoveryModeCleared has copy, drop {
    registry_id: ID,
    coverage_bps: u128,
}

public struct RecoveryThresholdChanged has copy, drop {
    registry_id: ID,
    old_threshold_bps: u128,
    new_threshold_bps: u128,
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
        RecoveryModeRegistry {
            id: object::new(ctx),

            version: PROTOCOL_VERSION,

            mode: MODE_NORMAL,

            recovery_threshold_bps:
                DEFAULT_RECOVERY_THRESHOLD_BPS,

            activation_count: 0,
            recovery_count: 0,

            last_observed_coverage_bps:
                DEFAULT_RECOVERY_THRESHOLD_BPS,
        };

    let registry_id =
        object::id(&registry);

    let admin_cap =
        RecoveryModeAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    event::emit(
        RecoveryModeCreated {
            registry_id,
            administrator,
            threshold_bps:
                DEFAULT_RECOVERY_THRESHOLD_BPS,
        },
    );

    transfer::share_object(registry);

    transfer::public_transfer(
        admin_cap,
        administrator,
    );
}


/* ============================================================
   Automatic Solvency Evaluation
   ============================================================ */

public fun evaluate_and_activate(
    registry: &mut RecoveryModeRegistry,

    pool: &LendingPool,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
) {
    let coverage =
        protocol_solvency::coverage_bps(
            pool,
            insurance,
            protocol_treasury,
        );

    registry.last_observed_coverage_bps =
        coverage;

    assert!(
        coverage
            < registry.recovery_threshold_bps,
        E_RECOVERY_NOT_REQUIRED,
    );

    assert!(
        registry.mode == MODE_NORMAL,
        E_STATE_UNCHANGED,
    );

    registry.mode =
        MODE_RECOVERY;

    registry.activation_count =
        registry.activation_count + 1;

    event::emit(
        RecoveryModeActivated {
            registry_id:
                object::id(registry),

            coverage_bps:
                coverage,

            threshold_bps:
                registry.recovery_threshold_bps,
        },
    );
}


/* ============================================================
   Clear Recovery Mode
   ============================================================ */

public fun evaluate_and_clear(
    registry: &mut RecoveryModeRegistry,

    pool: &LendingPool,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
) {
    let coverage =
        protocol_solvency::coverage_bps(
            pool,
            insurance,
            protocol_treasury,
        );

    registry.last_observed_coverage_bps =
        coverage;

    assert!(
        coverage
            >= registry.recovery_threshold_bps,
        E_RECOVERY_STILL_REQUIRED,
    );

    assert!(
        registry.mode == MODE_RECOVERY,
        E_STATE_UNCHANGED,
    );

    registry.mode =
        MODE_NORMAL;

    registry.recovery_count =
        registry.recovery_count + 1;

    event::emit(
        RecoveryModeCleared {
            registry_id:
                object::id(registry),

            coverage_bps:
                coverage,
        },
    );
}


/* ============================================================
   Risk-Increase Guard
   ============================================================ */

public(package) fun assert_risk_increase_allowed(
    registry: &RecoveryModeRegistry,
) {
    assert!(
        registry.mode == MODE_NORMAL,
        E_RISK_INCREASE_BLOCKED,
    );
}


/* ============================================================
   Threshold Administration
   ============================================================ */

public fun set_recovery_threshold_bps(
    registry: &mut RecoveryModeRegistry,
    admin_cap: &RecoveryModeAdminCap,
    new_threshold_bps: u128,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_threshold_bps > 0,
        E_INVALID_THRESHOLD,
    );

    assert!(
        new_threshold_bps
            != registry.recovery_threshold_bps,
        E_STATE_UNCHANGED,
    );

    let old_threshold =
        registry.recovery_threshold_bps;

    registry.recovery_threshold_bps =
        new_threshold_bps;

    event::emit(
        RecoveryThresholdChanged {
            registry_id:
                object::id(registry),

            old_threshold_bps:
                old_threshold,

            new_threshold_bps,
        },
    );
}

public fun set_version(
    registry: &mut RecoveryModeRegistry,
    admin_cap: &RecoveryModeAdminCap,
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
    registry: &RecoveryModeRegistry,
    admin_cap: &RecoveryModeAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_NOT_ADMIN,
    );
}


/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &RecoveryModeRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &RecoveryModeRegistry,
): u64 {
    registry.version
}

public fun mode(
    registry: &RecoveryModeRegistry,
): u8 {
    registry.mode
}

public fun is_recovery_mode(
    registry: &RecoveryModeRegistry,
): bool {
    registry.mode == MODE_RECOVERY
}

public fun recovery_threshold_bps(
    registry: &RecoveryModeRegistry,
): u128 {
    registry.recovery_threshold_bps
}

public(package) fun activation_count(
    registry: &RecoveryModeRegistry,
): u64 {
    registry.activation_count
}

public(package) fun recovery_count(
    registry: &RecoveryModeRegistry,
): u64 {
    registry.recovery_count
}

public fun last_observed_coverage_bps(
    registry: &RecoveryModeRegistry,
): u128 {
    registry.last_observed_coverage_bps
}

public fun normal_mode(): u8 {
    MODE_NORMAL
}

public fun recovery_mode(): u8 {
    MODE_RECOVERY
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): RecoveryModeRegistry {
    RecoveryModeRegistry {
        id: object::new(ctx),

        version: PROTOCOL_VERSION,

        mode: MODE_NORMAL,

        recovery_threshold_bps:
            DEFAULT_RECOVERY_THRESHOLD_BPS,

        activation_count: 0,
        recovery_count: 0,

        last_observed_coverage_bps:
            DEFAULT_RECOVERY_THRESHOLD_BPS,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &RecoveryModeRegistry,
    ctx: &mut TxContext,
): RecoveryModeAdminCap {
    RecoveryModeAdminCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: RecoveryModeAdminCap,
) {
    let RecoveryModeAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: RecoveryModeRegistry,
) {
    let RecoveryModeRegistry {
        id,
        version: _,
        mode: _,
        recovery_threshold_bps: _,
        activation_count: _,
        recovery_count: _,
        last_observed_coverage_bps: _,
    } = registry;

    object::delete(id);
}
