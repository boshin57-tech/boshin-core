module tobmate_core::treasury_strategy_recovery_mode;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::treasury_strategy_recovery::{
    Self as recovery,
    TreasuryStrategyRecoveryRegistry,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
    TreasuryYieldEngine,
};

const PROTOCOL_VERSION: u64 = 1;

const MODE_NORMAL: u8 = 1;
const MODE_RECOVERY: u8 = 2;

const DEFAULT_RECOVERY_THRESHOLD_BPS: u64 = 8_000;
const BPS_DENOMINATOR: u64 = 10_000;

const E_NOT_ADMIN: u64 = 1;
const E_INVALID_VERSION: u64 = 2;
const E_INVALID_THRESHOLD: u64 = 3;
const E_STATE_UNCHANGED: u64 = 4;
const E_RECOVERY_NOT_REQUIRED: u64 = 5;
const E_RECOVERY_STILL_REQUIRED: u64 = 6;
const E_RISK_INCREASE_BLOCKED: u64 = 7;

public struct TreasuryStrategyRecoveryModeRegistry has key {
    id: UID,
    version: u64,

    mode: u8,
    recovery_threshold_bps: u64,

    activation_count: u64,
    recovery_count: u64,

    last_observed_coverage_bps: u64,
}

public struct TreasuryStrategyRecoveryModeAdminCap has key, store {
    id: UID,
    registry_id: ID,
}

public struct StrategyRecoveryModeActivated has copy, drop {
    registry_id: ID,
    coverage_bps: u64,
    threshold_bps: u64,
}

public struct StrategyRecoveryModeCleared has copy, drop {
    registry_id: ID,
    coverage_bps: u64,
}

public fun create(
    ctx: &mut TxContext,
) {
    let administrator =
        tx_context::sender(ctx);

    let registry =
        TreasuryStrategyRecoveryModeRegistry {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,

            mode: MODE_NORMAL,
            recovery_threshold_bps:
                DEFAULT_RECOVERY_THRESHOLD_BPS,

            activation_count: 0,
            recovery_count: 0,
            last_observed_coverage_bps: 0,
        };

    let registry_id =
        object::id(&registry);

    let admin_cap =
        TreasuryStrategyRecoveryModeAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    transfer::share_object(registry);

    transfer::public_transfer(
        admin_cap,
        administrator,
    );
}

public fun recovery_coverage_bps(
    recovery_registry: &TreasuryStrategyRecoveryRegistry,
): u64 {
    let total_loss =
        recovery::total_loss_recorded(
            recovery_registry,
        );

    if (total_loss == 0) {
        return BPS_DENOMINATOR
    };

    recovery::total_recovered(
        recovery_registry,
    )
        * BPS_DENOMINATOR
        / total_loss
}

public fun evaluate_and_activate(
    registry: &mut TreasuryStrategyRecoveryModeRegistry,
    recovery_registry: &TreasuryStrategyRecoveryRegistry,
    engine: &mut TreasuryYieldEngine,
) {
    let coverage =
        recovery_coverage_bps(
            recovery_registry,
        );

    registry.last_observed_coverage_bps =
        coverage;

    assert!(
        recovery::total_loss_recorded(
            recovery_registry,
        ) > recovery::total_recovered(
            recovery_registry,
        ),
        E_RECOVERY_NOT_REQUIRED,
    );

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

    yield_engine::set_strategy_recovery_mode(
        engine,
        true,
    );

    event::emit(
        StrategyRecoveryModeActivated {
            registry_id: object::id(registry),
            coverage_bps: coverage,
            threshold_bps:
                registry.recovery_threshold_bps,
        },
    );
}

public fun evaluate_and_clear(
    registry: &mut TreasuryStrategyRecoveryModeRegistry,
    recovery_registry: &TreasuryStrategyRecoveryRegistry,
    engine: &mut TreasuryYieldEngine,
) {
    let coverage =
        recovery_coverage_bps(
            recovery_registry,
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

    yield_engine::set_strategy_recovery_mode(
        engine,
        false,
    );

    event::emit(
        StrategyRecoveryModeCleared {
            registry_id: object::id(registry),
            coverage_bps: coverage,
        },
    );
}

public fun assert_risk_increase_allowed(
    registry: &TreasuryStrategyRecoveryModeRegistry,
) {
    assert!(
        registry.mode == MODE_NORMAL,
        E_RISK_INCREASE_BLOCKED,
    );
}

public fun set_recovery_threshold_bps(
    registry: &mut TreasuryStrategyRecoveryModeRegistry,
    admin_cap: &TreasuryStrategyRecoveryModeAdminCap,
    threshold_bps: u64,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        threshold_bps > 0
            && threshold_bps <= BPS_DENOMINATOR,
        E_INVALID_THRESHOLD,
    );

    registry.recovery_threshold_bps =
        threshold_bps;
}

public fun set_version(
    registry: &mut TreasuryStrategyRecoveryModeRegistry,
    admin_cap: &TreasuryStrategyRecoveryModeAdminCap,
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

fun assert_admin(
    registry: &TreasuryStrategyRecoveryModeRegistry,
    admin_cap: &TreasuryStrategyRecoveryModeAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_NOT_ADMIN,
    );
}

public fun version(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): u64 {
    registry.version
}

public fun mode(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): u8 {
    registry.mode
}

public fun is_recovery_mode(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): bool {
    registry.mode == MODE_RECOVERY
}

public fun recovery_threshold_bps(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): u64 {
    registry.recovery_threshold_bps
}

public fun activation_count(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): u64 {
    registry.activation_count
}

public fun recovery_count(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): u64 {
    registry.recovery_count
}

public fun last_observed_coverage_bps(
    registry: &TreasuryStrategyRecoveryModeRegistry,
): u64 {
    registry.last_observed_coverage_bps
}

public fun normal_mode(): u8 {
    MODE_NORMAL
}

public fun recovery_mode(): u8 {
    MODE_RECOVERY
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): TreasuryStrategyRecoveryModeRegistry {
    TreasuryStrategyRecoveryModeRegistry {
        id: object::new(ctx),
        version: PROTOCOL_VERSION,

        mode: MODE_NORMAL,
        recovery_threshold_bps:
            DEFAULT_RECOVERY_THRESHOLD_BPS,

        activation_count: 0,
        recovery_count: 0,
        last_observed_coverage_bps: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &TreasuryStrategyRecoveryModeRegistry,
    ctx: &mut TxContext,
): TreasuryStrategyRecoveryModeAdminCap {
    TreasuryStrategyRecoveryModeAdminCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: TreasuryStrategyRecoveryModeAdminCap,
) {
    let TreasuryStrategyRecoveryModeAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: TreasuryStrategyRecoveryModeRegistry,
) {
    let TreasuryStrategyRecoveryModeRegistry {
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
