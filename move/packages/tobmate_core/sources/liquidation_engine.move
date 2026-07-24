module tobmate_core::liquidation_engine;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

/* ============================================================
   TOBMATE Blockchain
   Stage 6D-1 — Liquidation Engine
   ============================================================ */

/* ============================================================
   Constants
   ============================================================ */

const BPS_DENOMINATOR: u64 = 10_000;
const HEALTH_FACTOR_BASE_BPS: u64 = 10_000;
const PROTOCOL_VERSION: u64 = 1;

/* ============================================================
   Errors
   ============================================================ */

const E_NOT_ADMIN: u64 = 1;
const E_PROTOCOL_PAUSED: u64 = 2;
const E_INVALID_THRESHOLD: u64 = 3;
const E_INVALID_CLOSE_FACTOR: u64 = 4;
const E_INVALID_BONUS: u64 = 5;
const E_ZERO_PRICE: u64 = 6;
const E_ZERO_PRICE_SCALE: u64 = 7;
const E_ZERO_DEBT: u64 = 8;
const E_POSITION_HEALTHY: u64 = 9;
const E_REPAY_EXCEEDS_CLOSE_FACTOR: u64 = 10;
const E_REPAY_EXCEEDS_DEBT: u64 = 11;
const E_ZERO_REPAY: u64 = 12;
const E_INSUFFICIENT_COLLATERAL: u64 = 13;
const E_INVALID_VERSION: u64 = 14;

/* ============================================================
   Core Objects
   ============================================================ */

public struct LiquidationEngine has key {
    id: UID,

    version: u64,
    paused: bool,

    /// Percentage of collateral value counted
    /// for liquidation safety.
    ///
    /// Example:
    /// 8_000 = 80%
    liquidation_threshold_bps: u64,

    /// Maximum percentage of debt that may be
    /// repaid in one liquidation.
    ///
    /// Example:
    /// 5_000 = 50%
    close_factor_bps: u64,

    /// Additional collateral awarded
    /// to the liquidator.
    ///
    /// Example:
    /// 500 = 5%
    liquidation_bonus_bps: u64,

    total_liquidation_quotes: u64,
}

/* ============================================================
   Administration Capability
   ============================================================ */

public struct LiquidationAdminCap has key, store {
    id: UID,
    engine_id: ID,
}

/* ============================================================
   Liquidation Quote
   ============================================================ */

public struct LiquidationQuote has copy, drop, store {
    collateral_value: u128,
    debt_value: u128,

    adjusted_collateral_value: u128,

    health_factor_bps: u64,

    max_repay_amount: u64,
    repay_amount: u64,

    seize_amount: u64,

    liquidatable: bool,
}

/* ============================================================
   Events
   ============================================================ */

public struct LiquidationEngineCreated has copy, drop {
    engine_id: ID,
    administrator: address,

    liquidation_threshold_bps: u64,
    close_factor_bps: u64,
    liquidation_bonus_bps: u64,
}

public struct LiquidationParametersUpdated has copy, drop {
    engine_id: ID,

    liquidation_threshold_bps: u64,
    close_factor_bps: u64,
    liquidation_bonus_bps: u64,
}

public struct LiquidationEnginePauseChanged has copy, drop {
    engine_id: ID,
    paused: bool,
}

public struct LiquidationQuoteCreated has copy, drop {
    engine_id: ID,

    health_factor_bps: u64,

    repay_amount: u64,
    seize_amount: u64,
}

/* ============================================================
   Initialization
   ============================================================ */

public fun create(
    liquidation_threshold_bps: u64,
    close_factor_bps: u64,
    liquidation_bonus_bps: u64,
    ctx: &mut TxContext,
) {
    validate_parameters(
        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,
    );

    let administrator = tx_context::sender(ctx);

    let engine = LiquidationEngine {
        id: object::new(ctx),

        version: PROTOCOL_VERSION,
        paused: false,

        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,

        total_liquidation_quotes: 0,
    };

    let engine_id = object::id(&engine);

    let admin_cap = LiquidationAdminCap {
        id: object::new(ctx),
        engine_id,
    };

    event::emit(LiquidationEngineCreated {
        engine_id,
        administrator,
        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,
    });

    transfer::share_object(engine);
    transfer::public_transfer(admin_cap, administrator);
}

/* ============================================================
   Administration
   ============================================================ */

public fun update_parameters(
    engine: &mut LiquidationEngine,
    admin_cap: &LiquidationAdminCap,
    liquidation_threshold_bps: u64,
    close_factor_bps: u64,
    liquidation_bonus_bps: u64,
) {
    assert_admin(engine, admin_cap);

    validate_parameters(
        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,
    );

    engine.liquidation_threshold_bps =
        liquidation_threshold_bps;

    engine.close_factor_bps =
        close_factor_bps;

    engine.liquidation_bonus_bps =
        liquidation_bonus_bps;

    event::emit(LiquidationParametersUpdated {
        engine_id: object::id(engine),
        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,
    });
}

public fun set_paused(
    engine: &mut LiquidationEngine,
    admin_cap: &LiquidationAdminCap,
    paused: bool,
) {
    assert_admin(engine, admin_cap);

    engine.paused = paused;

    event::emit(LiquidationEnginePauseChanged {
        engine_id: object::id(engine),
        paused,
    });
}

public fun update_version(
    engine: &mut LiquidationEngine,
    admin_cap: &LiquidationAdminCap,
    new_version: u64,
) {
    assert_admin(engine, admin_cap);

    assert!(
        new_version > engine.version,
        E_INVALID_VERSION,
    );

    engine.version = new_version;
}

/* ============================================================
   Core Risk Math
   ============================================================ */

/// Calculates:
/// amount * price / price_scale
public fun asset_value(
    amount: u64,
    price: u64,
    price_scale: u64,
): u128 {
    assert!(price > 0, E_ZERO_PRICE);
    assert!(price_scale > 0, E_ZERO_PRICE_SCALE);

    ((amount as u128) * (price as u128))
        / (price_scale as u128)
}

/* ============================================================
   Adjusted Collateral
   ============================================================ */

public fun adjusted_collateral_value(
    collateral_amount: u64,
    collateral_price: u64,
    price_scale: u64,
    liquidation_threshold_bps: u64,
): u128 {
    let value = asset_value(
        collateral_amount,
        collateral_price,
        price_scale,
    );

    value
        * (liquidation_threshold_bps as u128)
        / (BPS_DENOMINATOR as u128)
}

/* ============================================================
   Health Factor
   ============================================================ */

/// Health factor representation:
///
/// 10_000 = 1.00
/// >10_000 = healthy
/// <10_000 = liquidatable
public fun calculate_health_factor_bps(
    collateral_amount: u64,
    collateral_price: u64,
    debt_amount: u64,
    debt_price: u64,
    price_scale: u64,
    liquidation_threshold_bps: u64,
): u64 {
    assert!(debt_amount > 0, E_ZERO_DEBT);

    let adjusted_collateral =
        adjusted_collateral_value(
            collateral_amount,
            collateral_price,
            price_scale,
            liquidation_threshold_bps,
        );

    let debt_value =
        asset_value(
            debt_amount,
            debt_price,
            price_scale,
        );

    assert!(debt_value > 0, E_ZERO_DEBT);

    let health_factor =
        adjusted_collateral
            * (HEALTH_FACTOR_BASE_BPS as u128)
            / debt_value;

    if (
        health_factor >
        (18446744073709551615u128)
    ) {
        18446744073709551615
    } else {
        health_factor as u64
    }
}

/* ============================================================
   Liquidation Eligibility
   ============================================================ */

public fun position_is_liquidatable(
    collateral_amount: u64,
    collateral_price: u64,
    debt_amount: u64,
    debt_price: u64,
    price_scale: u64,
    liquidation_threshold_bps: u64,
): bool {
    if (debt_amount == 0) {
        return false
    };

    calculate_health_factor_bps(
        collateral_amount,
        collateral_price,
        debt_amount,
        debt_price,
        price_scale,
        liquidation_threshold_bps,
    ) < HEALTH_FACTOR_BASE_BPS
}

/* ============================================================
   Close Factor
   ============================================================ */

public fun calculate_max_repay(
    debt_amount: u64,
    close_factor_bps: u64,
): u64 {
    assert!(
        close_factor_bps > 0
            && close_factor_bps <= BPS_DENOMINATOR,
        E_INVALID_CLOSE_FACTOR,
    );

    let result =
        (debt_amount as u128)
            * (close_factor_bps as u128)
            / (BPS_DENOMINATOR as u128);

    result as u64
}

/* ============================================================
   Collateral Seizure Math
   ============================================================ */

public fun calculate_seize_amount(
    repay_amount: u64,
    debt_price: u64,
    collateral_price: u64,
    liquidation_bonus_bps: u64,
): u64 {
    assert!(repay_amount > 0, E_ZERO_REPAY);
    assert!(debt_price > 0, E_ZERO_PRICE);
    assert!(collateral_price > 0, E_ZERO_PRICE);

    let numerator =
        (repay_amount as u128)
            * (debt_price as u128)
            * (
                (BPS_DENOMINATOR
                    + liquidation_bonus_bps) as u128
            );

    let denominator =
        (collateral_price as u128)
            * (BPS_DENOMINATOR as u128);

    (numerator / denominator) as u64
}

/* ============================================================
   Liquidation Quote Engine
   ============================================================ */

public fun quote_liquidation(
    engine: &mut LiquidationEngine,

    collateral_amount: u64,
    collateral_price: u64,

    debt_amount: u64,
    debt_price: u64,

    price_scale: u64,

    requested_repay_amount: u64,
): LiquidationQuote {
    assert!(!engine.paused, E_PROTOCOL_PAUSED);
    assert!(debt_amount > 0, E_ZERO_DEBT);
    assert!(requested_repay_amount > 0, E_ZERO_REPAY);

    let collateral_value =
        asset_value(
            collateral_amount,
            collateral_price,
            price_scale,
        );

    let debt_value =
        asset_value(
            debt_amount,
            debt_price,
            price_scale,
        );

    let adjusted_value =
        adjusted_collateral_value(
            collateral_amount,
            collateral_price,
            price_scale,
            engine.liquidation_threshold_bps,
        );

    let health_factor_bps =
        calculate_health_factor_bps(
            collateral_amount,
            collateral_price,
            debt_amount,
            debt_price,
            price_scale,
            engine.liquidation_threshold_bps,
        );

    let liquidatable =
        health_factor_bps < HEALTH_FACTOR_BASE_BPS;

    assert!(liquidatable, E_POSITION_HEALTHY);

    assert!(
        requested_repay_amount <= debt_amount,
        E_REPAY_EXCEEDS_DEBT,
    );

    let max_repay_amount =
        calculate_max_repay(
            debt_amount,
            engine.close_factor_bps,
        );

    assert!(
        requested_repay_amount <= max_repay_amount,
        E_REPAY_EXCEEDS_CLOSE_FACTOR,
    );

    let seize_amount =
        calculate_seize_amount(
            requested_repay_amount,
            debt_price,
            collateral_price,
            engine.liquidation_bonus_bps,
        );

    assert!(
        seize_amount <= collateral_amount,
        E_INSUFFICIENT_COLLATERAL,
    );

    engine.total_liquidation_quotes =
        engine.total_liquidation_quotes + 1;

    event::emit(LiquidationQuoteCreated {
        engine_id: object::id(engine),
        health_factor_bps,
        repay_amount: requested_repay_amount,
        seize_amount,
    });

    LiquidationQuote {
        collateral_value,
        debt_value,
        adjusted_collateral_value: adjusted_value,
        health_factor_bps,

        max_repay_amount,
        repay_amount: requested_repay_amount,
        seize_amount,

        liquidatable,
    }
}

/* ============================================================
   Internal Validation
   ============================================================ */

fun validate_parameters(
    liquidation_threshold_bps: u64,
    close_factor_bps: u64,
    liquidation_bonus_bps: u64,
) {
    assert!(
        liquidation_threshold_bps > 0
            && liquidation_threshold_bps
                < BPS_DENOMINATOR,
        E_INVALID_THRESHOLD,
    );

    assert!(
        close_factor_bps > 0
            && close_factor_bps
                <= BPS_DENOMINATOR,
        E_INVALID_CLOSE_FACTOR,
    );

    assert!(
        liquidation_bonus_bps
            < BPS_DENOMINATOR,
        E_INVALID_BONUS,
    );
}

fun assert_admin(
    engine: &LiquidationEngine,
    admin_cap: &LiquidationAdminCap,
) {
    assert!(
        admin_cap.engine_id == object::id(engine),
        E_NOT_ADMIN,
    );
}

/* ============================================================
   Public Read API
   ============================================================ */

public fun engine_id(
    engine: &LiquidationEngine,
): ID {
    object::id(engine)
}

public fun admin_engine_id(
    admin_cap: &LiquidationAdminCap,
): ID {
    admin_cap.engine_id
}

public fun version(
    engine: &LiquidationEngine,
): u64 {
    engine.version
}

public fun is_paused(
    engine: &LiquidationEngine,
): bool {
    engine.paused
}

public fun liquidation_threshold_bps(
    engine: &LiquidationEngine,
): u64 {
    engine.liquidation_threshold_bps
}

public fun close_factor_bps(
    engine: &LiquidationEngine,
): u64 {
    engine.close_factor_bps
}

public fun liquidation_bonus_bps(
    engine: &LiquidationEngine,
): u64 {
    engine.liquidation_bonus_bps
}

public fun total_liquidation_quotes(
    engine: &LiquidationEngine,
): u64 {
    engine.total_liquidation_quotes
}

public fun quote_collateral_value(
    quote: &LiquidationQuote,
): u128 {
    quote.collateral_value
}

public fun quote_debt_value(
    quote: &LiquidationQuote,
): u128 {
    quote.debt_value
}

public fun quote_adjusted_collateral_value(
    quote: &LiquidationQuote,
): u128 {
    quote.adjusted_collateral_value
}

public fun quote_health_factor_bps(
    quote: &LiquidationQuote,
): u64 {
    quote.health_factor_bps
}

public fun quote_max_repay_amount(
    quote: &LiquidationQuote,
): u64 {
    quote.max_repay_amount
}

public fun quote_repay_amount(
    quote: &LiquidationQuote,
): u64 {
    quote.repay_amount
}

public fun quote_seize_amount(
    quote: &LiquidationQuote,
): u64 {
    quote.seize_amount
}

public fun quote_is_liquidatable(
    quote: &LiquidationQuote,
): bool {
    quote.liquidatable
}

public fun basis_point_denominator(): u64 {
    BPS_DENOMINATOR
}

public fun healthy_health_factor_bps(): u64 {
    HEALTH_FACTOR_BASE_BPS
}

/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    liquidation_threshold_bps: u64,
    close_factor_bps: u64,
    liquidation_bonus_bps: u64,
    ctx: &mut TxContext,
): LiquidationEngine {
    validate_parameters(
        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,
    );

    LiquidationEngine {
        id: object::new(ctx),
        version: PROTOCOL_VERSION,
        paused: false,

        liquidation_threshold_bps,
        close_factor_bps,
        liquidation_bonus_bps,

        total_liquidation_quotes: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    engine: &LiquidationEngine,
    ctx: &mut TxContext,
): LiquidationAdminCap {
    LiquidationAdminCap {
        id: object::new(ctx),
        engine_id: object::id(engine),
    }
}

#[test_only]
public fun destroy_for_testing(
    engine: LiquidationEngine,
) {
    let LiquidationEngine {
        id,
        version: _,
        paused: _,
        liquidation_threshold_bps: _,
        close_factor_bps: _,
        liquidation_bonus_bps: _,
        total_liquidation_quotes: _,
    } = engine;

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: LiquidationAdminCap,
) {
    let LiquidationAdminCap {
        id,
        engine_id: _,
    } = cap;

    object::delete(id);
}
