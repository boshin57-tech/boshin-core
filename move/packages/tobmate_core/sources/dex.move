module tobmate_core::dex;

use std::string::String;

use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control;
use tobmate_core::liquidity_pool::{
    Self,
    LiquidityPool,
};

use tobmate_core::oracle_price_router::{
    Self,
    PriceQuote,
};

/* ============================================================
   Constants
   ============================================================ */

const BPS_DENOMINATOR: u64 = 10_000;
const INITIAL_VERSION: u64 = 1;

const E_DEX_PAUSED: u64 = 1;
const E_INVALID_ADMIN_CAP: u64 = 2;
const E_INVALID_ORACLE_DEVIATION: u64 = 3;
const E_INVALID_DEADLINE_WINDOW: u64 = 4;
const E_POOL_ALREADY_REGISTERED: u64 = 5;
const E_POOL_NOT_FOUND: u64 = 6;
const E_POOL_STATE_UNCHANGED: u64 = 7;
const E_DEX_STATE_UNCHANGED: u64 = 8;
const E_VERSION_NOT_INCREASING: u64 = 9;
const E_UNDERLYING_POOL_PAUSED: u64 = 10;
const E_ACCOUNTING_INVARIANT: u64 = 11;
const E_POOL_INACTIVE: u64 = 12;
const E_POOL_OBJECT_MISMATCH: u64 = 13;
const E_SWAP_DEADLINE_EXPIRED: u64 = 14;
const E_SWAP_DEADLINE_TOO_FAR: u64 = 15;
const E_ZERO_SWAP_INPUT: u64 = 16;
const E_ORACLE_GUARD_NOT_CONNECTED: u64 = 17;
const E_SWAP_ACCOUNTING_INVARIANT: u64 = 18;
const E_ORACLE_CIRCUIT_BREAKER_ACTIVE: u64 = 19;
const E_ORACLE_CIRCUIT_BREAKER_STATE_UNCHANGED: u64 = 20;
const E_INVALID_ORACLE_PRICE: u64 = 21;
const E_ORACLE_DEVIATION_EXCEEDED: u64 = 22;
const E_ORACLE_QUOTE_TIME_MISMATCH: u64 = 23;
const E_INVALID_PRICE_SCALE: u64 = 24;

/* ============================================================
   Core Objects
   ============================================================ */

public struct DexAdminCap has key, store {
    id: UID,
    registry_id: ID,
}

public struct DexRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_pool_id: u64,
    registered_pool_count: u64,
    active_pool_count: u64,

    total_swap_count: u64,
    total_input_volume: u64,
    total_output_volume: u64,
    total_fee_collected: u64,

    max_oracle_deviation_bps: u64,
    oracle_circuit_breaker_active: bool,
    default_deadline_window_ms: u64,

    pools: vector<DexPoolRecord>,
}

public struct DexPoolRecord has drop, store {
    pool_id: u64,
    pool_object_id: ID,

    base_symbol: String,
    quote_symbol: String,

    active: bool,
    oracle_guard_enabled: bool,

    created_at_epoch: u64,
}

/* ============================================================
   Events
   ============================================================ */

public struct DexRegistryCreated has copy, drop {
    registry_id: ID,
    version: u64,
    max_oracle_deviation_bps: u64,
    default_deadline_window_ms: u64,
}

public struct DexPoolRegistered has copy, drop {
    registry_id: ID,
    pool_id: u64,
    pool_object_id: ID,
    oracle_guard_enabled: bool,
    created_at_epoch: u64,
}

public struct DexPoolStateChanged has copy, drop {
    registry_id: ID,
    pool_id: u64,
    active: bool,
}

public struct DexPauseStateChanged has copy, drop {
    registry_id: ID,
    paused: bool,
}

public struct DexVersionChanged has copy, drop {
    registry_id: ID,
    old_version: u64,
    new_version: u64,
}

public struct DexOraclePolicyChanged has copy, drop {
    registry_id: ID,
    old_max_deviation_bps: u64,
    new_max_deviation_bps: u64,
}

public struct DexDeadlinePolicyChanged has copy, drop {
    registry_id: ID,
    old_deadline_window_ms: u64,
    new_deadline_window_ms: u64,
}

public struct DexOracleCircuitBreakerChanged has copy, drop {
    registry_id: ID,
    active: bool,
}

/* ============================================================
   Registry Creation
   ============================================================ */

public fun create_registry(
    access: &access_control::AccessControl,
    max_oracle_deviation_bps: u64,
    default_deadline_window_ms: u64,
    ctx: &mut TxContext,
): (DexRegistry, DexAdminCap) {
    access_control::assert_not_paused(access);

    assert!(
        max_oracle_deviation_bps <= BPS_DENOMINATOR,
        E_INVALID_ORACLE_DEVIATION,
    );

    assert!(
        default_deadline_window_ms > 0,
        E_INVALID_DEADLINE_WINDOW,
    );

    let registry = DexRegistry {
        id: object::new(ctx),

        version: INITIAL_VERSION,
        paused: false,

        next_pool_id: 1,
        registered_pool_count: 0,
        active_pool_count: 0,

        total_swap_count: 0,
        total_input_volume: 0,
        total_output_volume: 0,
        total_fee_collected: 0,

        max_oracle_deviation_bps,
        oracle_circuit_breaker_active: false,
        default_deadline_window_ms,

        pools: vector[],
    };

    let registry_id = object::id(&registry);

    let admin_cap = DexAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    event::emit(DexRegistryCreated {
        registry_id,
        version: INITIAL_VERSION,
        max_oracle_deviation_bps,
        default_deadline_window_ms,
    });

    (registry, admin_cap)
}

/* ============================================================
   Pool Registration
   ============================================================ */

public fun register_pool<X, Y>(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    pool: &LiquidityPool<X, Y>,
    base_symbol: String,
    quote_symbol: String,
    oracle_guard_enabled: bool,
    ctx: &TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);
    assert_operational(registry);

    assert!(
        !liquidity_pool::is_paused(pool),
        E_UNDERLYING_POOL_PAUSED,
    );

    let pool_object_id =
        liquidity_pool::pool_id(pool);

    assert!(
        !pool_object_exists(registry, pool_object_id),
        E_POOL_ALREADY_REGISTERED,
    );

    let pool_id = registry.next_pool_id;

    registry.next_pool_id = pool_id + 1;
    registry.registered_pool_count =
        registry.registered_pool_count + 1;

    registry.active_pool_count =
        registry.active_pool_count + 1;

    let created_at_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.pools,
        DexPoolRecord {
            pool_id,
            pool_object_id,

            base_symbol,
            quote_symbol,

            active: true,
            oracle_guard_enabled,

            created_at_epoch,
        },
    );

    assert_accounting_invariant(registry);

    event::emit(DexPoolRegistered {
        registry_id: object::id(registry),
        pool_id,
        pool_object_id,
        oracle_guard_enabled,
        created_at_epoch,
    });

    pool_id
}

/* ============================================================
   Pool Administration
   ============================================================ */

public fun set_pool_active(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    pool_id: u64,
    active: bool,
) {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);
    assert_operational(registry);

    let index =
        find_pool_index(registry, pool_id);

    let record =
        vector::borrow_mut(&mut registry.pools, index);

    assert!(
        record.active != active,
        E_POOL_STATE_UNCHANGED,
    );

    record.active = active;

    if (active) {
        registry.active_pool_count =
            registry.active_pool_count + 1;
    } else {
        registry.active_pool_count =
            registry.active_pool_count - 1;
    };

    assert_accounting_invariant(registry);

    event::emit(DexPoolStateChanged {
        registry_id: object::id(registry),
        pool_id,
        active,
    });
}

public fun set_paused(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    paused: bool,
) {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);

    assert!(
        registry.paused != paused,
        E_DEX_STATE_UNCHANGED,
    );

    registry.paused = paused;

    event::emit(DexPauseStateChanged {
        registry_id: object::id(registry),
        paused,
    });
}

public fun set_version(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    new_version: u64,
) {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);

    assert!(
        new_version > registry.version,
        E_VERSION_NOT_INCREASING,
    );

    let old_version = registry.version;
    registry.version = new_version;

    event::emit(DexVersionChanged {
        registry_id: object::id(registry),
        old_version,
        new_version,
    });
}

public fun set_max_oracle_deviation_bps(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    new_max_deviation_bps: u64,
) {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);

    assert!(
        new_max_deviation_bps <= BPS_DENOMINATOR,
        E_INVALID_ORACLE_DEVIATION,
    );

    let old_max_deviation_bps =
        registry.max_oracle_deviation_bps;

    assert!(
        old_max_deviation_bps != new_max_deviation_bps,
        E_DEX_STATE_UNCHANGED,
    );

    registry.max_oracle_deviation_bps =
        new_max_deviation_bps;

    event::emit(DexOraclePolicyChanged {
        registry_id: object::id(registry),
        old_max_deviation_bps,
        new_max_deviation_bps,
    });
}

public fun set_oracle_circuit_breaker(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    active: bool,
) {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);

    assert!(
        registry.oracle_circuit_breaker_active != active,
        E_ORACLE_CIRCUIT_BREAKER_STATE_UNCHANGED,
    );

    registry.oracle_circuit_breaker_active = active;

    event::emit(DexOracleCircuitBreakerChanged {
        registry_id: object::id(registry),
        active,
    });
}

public fun set_default_deadline_window_ms(
    admin_cap: &DexAdminCap,
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    new_deadline_window_ms: u64,
) {
    access_control::assert_not_paused(access);
    assert_admin(admin_cap, registry);

    assert!(
        new_deadline_window_ms > 0,
        E_INVALID_DEADLINE_WINDOW,
    );

    let old_deadline_window_ms =
        registry.default_deadline_window_ms;

    assert!(
        old_deadline_window_ms != new_deadline_window_ms,
        E_DEX_STATE_UNCHANGED,
    );

    registry.default_deadline_window_ms =
        new_deadline_window_ms;

    event::emit(DexDeadlinePolicyChanged {
        registry_id: object::id(registry),
        old_deadline_window_ms,
        new_deadline_window_ms,
    });
}

/* ============================================================
   Assertions and Internal Search
   ============================================================ */

public fun assert_operational(
    registry: &DexRegistry,
) {
    assert!(
        !registry.paused,
        E_DEX_PAUSED,
    );
}

public fun assert_admin(
    admin_cap: &DexAdminCap,
    registry: &DexRegistry,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_INVALID_ADMIN_CAP,
    );
}

public fun assert_accounting_invariant(
    registry: &DexRegistry,
) {
    assert!(
        registry.active_pool_count
            <= registry.registered_pool_count,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        vector::length(&registry.pools)
            == registry.registered_pool_count,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        registry.next_pool_id
            == registry.registered_pool_count + 1,
        E_ACCOUNTING_INVARIANT,
    );
}

fun pool_object_exists(
    registry: &DexRegistry,
    pool_object_id: ID,
): bool {
    let length =
        vector::length(&registry.pools);

    let mut index = 0;

    while (index < length) {
        let record =
            vector::borrow(&registry.pools, index);

        if (record.pool_object_id == pool_object_id) {
            return true
        };

        index = index + 1;
    };

    false
}

fun find_pool_index(
    registry: &DexRegistry,
    pool_id: u64,
): u64 {
    let length =
        vector::length(&registry.pools);

    let mut index = 0;

    while (index < length) {
        let record =
            vector::borrow(&registry.pools, index);

        if (record.pool_id == pool_id) {
            return index
        };

        index = index + 1;
    };

    abort E_POOL_NOT_FOUND
}

/* ============================================================
   Public Read API
   ============================================================ */

public fun registry_id(
    registry: &DexRegistry,
): ID {
    object::id(registry)
}

public fun admin_registry_id(
    admin_cap: &DexAdminCap,
): ID {
    admin_cap.registry_id
}

public fun version(
    registry: &DexRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &DexRegistry,
): bool {
    registry.paused
}

public fun next_pool_id(
    registry: &DexRegistry,
): u64 {
    registry.next_pool_id
}

public fun registered_pool_count(
    registry: &DexRegistry,
): u64 {
    registry.registered_pool_count
}

public fun active_pool_count(
    registry: &DexRegistry,
): u64 {
    registry.active_pool_count
}

public fun total_swap_count(
    registry: &DexRegistry,
): u64 {
    registry.total_swap_count
}

public fun total_input_volume(
    registry: &DexRegistry,
): u64 {
    registry.total_input_volume
}

public fun total_output_volume(
    registry: &DexRegistry,
): u64 {
    registry.total_output_volume
}

public fun total_fee_collected(
    registry: &DexRegistry,
): u64 {
    registry.total_fee_collected
}

public fun max_oracle_deviation_bps(
    registry: &DexRegistry,
): u64 {
    registry.max_oracle_deviation_bps
}

public fun oracle_circuit_breaker_active(
    registry: &DexRegistry,
): bool {
    registry.oracle_circuit_breaker_active
}

public fun default_deadline_window_ms(
    registry: &DexRegistry,
): u64 {
    registry.default_deadline_window_ms
}

public fun pool_exists(
    registry: &DexRegistry,
    pool_id: u64,
): bool {
    let length =
        vector::length(&registry.pools);

    let mut index = 0;

    while (index < length) {
        let record =
            vector::borrow(&registry.pools, index);

        if (record.pool_id == pool_id) {
            return true
        };

        index = index + 1;
    };

    false
}

public fun pool_object_id(
    registry: &DexRegistry,
    pool_id: u64,
): ID {
    let index =
        find_pool_index(registry, pool_id);

    vector::borrow(
        &registry.pools,
        index,
    ).pool_object_id
}

public fun pool_is_active(
    registry: &DexRegistry,
    pool_id: u64,
): bool {
    let index =
        find_pool_index(registry, pool_id);

    vector::borrow(
        &registry.pools,
        index,
    ).active
}

public fun pool_oracle_guard_enabled(
    registry: &DexRegistry,
    pool_id: u64,
): bool {
    let index =
        find_pool_index(registry, pool_id);

    vector::borrow(
        &registry.pools,
        index,
    ).oracle_guard_enabled
}

public fun pool_base_symbol(
    registry: &DexRegistry,
    pool_id: u64,
): &String {
    let index =
        find_pool_index(registry, pool_id);

    &vector::borrow(
        &registry.pools,
        index,
    ).base_symbol
}

public fun pool_quote_symbol(
    registry: &DexRegistry,
    pool_id: u64,
): &String {
    let index =
        find_pool_index(registry, pool_id);

    &vector::borrow(
        &registry.pools,
        index,
    ).quote_symbol
}

public fun basis_point_denominator(): u64 {
    BPS_DENOMINATOR
}


/* ============================================================
   Stage 5D — Oracle Guard Validation Engine
   ============================================================ */

/// Validates an Oracle quote against the current DEX pool state.
///
/// The Oracle price must represent the price of one unit of X,
/// expressed in Y, using `price_scale` fixed-point units.
///
/// Example:
/// - price_scale = 1_000_000
/// - oracle price = 2_500_000
/// - interpreted price = 2.5 Y per X
public fun assert_oracle_guard<X, Y>(
    registry: &DexRegistry,
    dex_pool_id: u64,
    pool: &LiquidityPool<X, Y>,
    quote: &PriceQuote,
    price_scale: u64,
    clock: &Clock,
) {
    assert_registered_oracle_pool_route(
        registry,
        dex_pool_id,
        liquidity_pool::pool_id(pool),
    );

    let index =
        find_pool_index(registry, dex_pool_id);

    let record =
        vector::borrow(&registry.pools, index);

    assert!(
        record.oracle_guard_enabled,
        E_ORACLE_GUARD_NOT_CONNECTED,
    );

    assert!(
        !registry.oracle_circuit_breaker_active,
        E_ORACLE_CIRCUIT_BREAKER_ACTIVE,
    );

    assert!(
        price_scale > 0,
        E_INVALID_PRICE_SCALE,
    );

    let queried_at_ms =
        oracle_price_router::quote_queried_at_ms(quote);

    let current_time_ms =
        clock::timestamp_ms(clock);

    assert!(
        queried_at_ms == current_time_ms,
        E_ORACLE_QUOTE_TIME_MISMATCH,
    );

    let quote_age_ms =
        oracle_price_router::quote_age_ms(quote);

    let effective_max_age_ms =
        oracle_price_router::quote_effective_max_age_ms(
            quote,
        );

    assert!(
        effective_max_age_ms > 0
            && quote_age_ms <= effective_max_age_ms,
        E_ORACLE_QUOTE_TIME_MISMATCH,
    );

    let oracle_price =
        oracle_price_router::quote_price(quote);

    assert!(
        oracle_price > 0,
        E_INVALID_ORACLE_PRICE,
    );

    let spot_price =
        calculate_pool_spot_price(
            pool,
            price_scale,
        );

    let deviation_bps =
        calculate_price_deviation_bps(
            spot_price,
            oracle_price,
        );

    assert!(
        deviation_bps
            <= registry.max_oracle_deviation_bps,
        E_ORACLE_DEVIATION_EXCEEDED,
    );
}

/// Returns the current pool spot price of X expressed in Y.
///
/// The returned value uses `price_scale` fixed-point units.
public fun calculate_pool_spot_price<X, Y>(
    pool: &LiquidityPool<X, Y>,
    price_scale: u64,
): u64 {
    assert!(
        price_scale > 0,
        E_INVALID_PRICE_SCALE,
    );

    let reserve_x =
        liquidity_pool::reserve_x(pool);

    let reserve_y =
        liquidity_pool::reserve_y(pool);

    assert!(
        reserve_x > 0 && reserve_y > 0,
        E_INVALID_ORACLE_PRICE,
    );

    let scaled_reserve_y =
        (reserve_y as u128)
            * (price_scale as u128);

    let spot_price =
        scaled_reserve_y / (reserve_x as u128);

    assert!(
        spot_price > 0,
        E_INVALID_ORACLE_PRICE,
    );

    spot_price as u64
}

/// Calculates the absolute price deviation in basis points.
///
/// The Oracle price is used as the reference denominator.
public fun calculate_price_deviation_bps(
    pool_spot_price: u64,
    oracle_price: u64,
): u64 {
    assert!(
        pool_spot_price > 0 && oracle_price > 0,
        E_INVALID_ORACLE_PRICE,
    );

    let absolute_difference =
        if (pool_spot_price >= oracle_price) {
            pool_spot_price - oracle_price
        } else {
            oracle_price - pool_spot_price
        };

    let deviation =
        ((absolute_difference as u128)
            * (BPS_DENOMINATOR as u128))
            / (oracle_price as u128);

    deviation as u64
}

/* ============================================================
   Stage 5D Part 3 — Oracle Guarded Swap API
   ============================================================ */

/// Executes an exact-input X → Y swap after validating the
/// current pool spot price against a canonical Oracle quote.
///
/// Oracle convention:
/// - quote price represents one unit of X expressed in Y;
/// - quote price and pool price use `price_scale` fixed-point
///   precision;
/// - Oracle validation is performed immediately before the swap.
public fun swap_exact_x_for_y_with_oracle<X, Y>(
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    dex_pool_id: u64,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<X>,
    minimum_amount_out: u64,
    deadline_ms: u64,
    quote: &PriceQuote,
    price_scale: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<Y>, DexSwapReceipt) {
    access_control::assert_not_paused(access);
    assert_operational(registry);

    assert_swap_deadline(
        registry,
        deadline_ms,
        clock,
    );

    assert_oracle_guard(
        registry,
        dex_pool_id,
        pool,
        quote,
        price_scale,
        clock,
    );

    execute_oracle_validated_x_for_y(
        access,
        registry,
        dex_pool_id,
        pool,
        input,
        minimum_amount_out,
        deadline_ms,
        clock,
        ctx,
    )
}

/// Executes an exact-input Y → X swap after validating the
/// current pool spot price against a canonical Oracle quote.
///
/// The same X/Y Oracle price convention is used for both swap
/// directions. The quote therefore continues to represent the
/// price of one unit of X expressed in Y.
public fun swap_exact_y_for_x_with_oracle<X, Y>(
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    dex_pool_id: u64,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<Y>,
    minimum_amount_out: u64,
    deadline_ms: u64,
    quote: &PriceQuote,
    price_scale: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<X>, DexSwapReceipt) {
    access_control::assert_not_paused(access);
    assert_operational(registry);

    assert_swap_deadline(
        registry,
        deadline_ms,
        clock,
    );

    assert_oracle_guard(
        registry,
        dex_pool_id,
        pool,
        quote,
        price_scale,
        clock,
    );

    swap_exact_y_for_x(
        access,
        registry,
        dex_pool_id,
        pool,
        input,
        minimum_amount_out,
        deadline_ms,
        clock,
        ctx,
    )
}


/* ============================================================
   Stage 5B — Swap Routing
   ============================================================ */

public struct DexSwapReceipt has copy, drop, store {
    registry_id: ID,
    dex_pool_id: u64,
    underlying_pool_id: ID,

    trader: address,
    x_to_y: bool,

    amount_in: u64,
    amount_out: u64,
    minimum_amount_out: u64,

    trading_fee: u64,
    protocol_fee: u64,

    executed_at_ms: u64,
    deadline_ms: u64,
}

public struct DexSwapExecuted has copy, drop {
    registry_id: ID,
    dex_pool_id: u64,
    underlying_pool_id: ID,

    trader: address,
    x_to_y: bool,

    amount_in: u64,
    amount_out: u64,

    trading_fee: u64,
    protocol_fee: u64,

    executed_at_ms: u64,
}

/* ------------------------------------------------------------
   X → Y routed swap
   ------------------------------------------------------------ */


/// Executes X → Y after the Oracle-aware route and price
/// validations have already succeeded.
///
/// This private executor skips only the ordinary route validator,
/// which intentionally rejects Oracle Guard-enabled pools. All
/// swap accounting, pool mutation, receipt creation and event
/// emission remain identical to the normal X → Y swap.
fun execute_oracle_validated_x_for_y<X, Y>(
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    dex_pool_id: u64,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<X>,
    minimum_amount_out: u64,
    deadline_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<Y>, DexSwapReceipt) {
    access_control::assert_not_paused(access);
    assert_operational(registry);


    assert!(
        !liquidity_pool::is_paused(pool),
        E_UNDERLYING_POOL_PAUSED,
    );

    assert_swap_deadline(
        registry,
        deadline_ms,
        clock,
    );

    let amount_in = coin::value(&input);

    assert!(
        amount_in > 0,
        E_ZERO_SWAP_INPUT,
    );

    let trading_fee =
        calculate_trading_fee(
            amount_in,
            liquidity_pool::trading_fee_bps(pool),
        );

    let protocol_fee_before =
        liquidity_pool::protocol_fees_x(pool);

    let output =
        liquidity_pool::swap_exact_x_for_y(
            access,
            pool,
            input,
            minimum_amount_out,
            ctx,
        );

    let amount_out =
        coin::value(&output);

    let protocol_fee_after =
        liquidity_pool::protocol_fees_x(pool);

    assert!(
        protocol_fee_after >= protocol_fee_before,
        E_SWAP_ACCOUNTING_INVARIANT,
    );

    let protocol_fee =
        protocol_fee_after - protocol_fee_before;

    let executed_at_ms =
        clock::timestamp_ms(clock);

    record_swap(
        registry,
        amount_in,
        amount_out,
        trading_fee,
    );

    let receipt = DexSwapReceipt {
        registry_id: object::id(registry),
        dex_pool_id,
        underlying_pool_id:
            liquidity_pool::pool_id(pool),

        trader: tx_context::sender(ctx),
        x_to_y: true,

        amount_in,
        amount_out,
        minimum_amount_out,

        trading_fee,
        protocol_fee,

        executed_at_ms,
        deadline_ms,
    };

    event::emit(DexSwapExecuted {
        registry_id: object::id(registry),
        dex_pool_id,
        underlying_pool_id:
            liquidity_pool::pool_id(pool),

        trader: tx_context::sender(ctx),
        x_to_y: true,

        amount_in,
        amount_out,

        trading_fee,
        protocol_fee,

        executed_at_ms,
    });

    (output, receipt)
}

public fun swap_exact_x_for_y<X, Y>(
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    dex_pool_id: u64,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<X>,
    minimum_amount_out: u64,
    deadline_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<Y>, DexSwapReceipt) {
    access_control::assert_not_paused(access);
    assert_operational(registry);

    assert_registered_pool_route(
        registry,
        dex_pool_id,
        liquidity_pool::pool_id(pool),
    );

    assert!(
        !liquidity_pool::is_paused(pool),
        E_UNDERLYING_POOL_PAUSED,
    );

    assert_swap_deadline(
        registry,
        deadline_ms,
        clock,
    );

    let amount_in = coin::value(&input);

    assert!(
        amount_in > 0,
        E_ZERO_SWAP_INPUT,
    );

    let trading_fee =
        calculate_trading_fee(
            amount_in,
            liquidity_pool::trading_fee_bps(pool),
        );

    let protocol_fee_before =
        liquidity_pool::protocol_fees_x(pool);

    let output =
        liquidity_pool::swap_exact_x_for_y(
            access,
            pool,
            input,
            minimum_amount_out,
            ctx,
        );

    let amount_out =
        coin::value(&output);

    let protocol_fee_after =
        liquidity_pool::protocol_fees_x(pool);

    assert!(
        protocol_fee_after >= protocol_fee_before,
        E_SWAP_ACCOUNTING_INVARIANT,
    );

    let protocol_fee =
        protocol_fee_after - protocol_fee_before;

    let executed_at_ms =
        clock::timestamp_ms(clock);

    record_swap(
        registry,
        amount_in,
        amount_out,
        trading_fee,
    );

    let receipt = DexSwapReceipt {
        registry_id: object::id(registry),
        dex_pool_id,
        underlying_pool_id:
            liquidity_pool::pool_id(pool),

        trader: tx_context::sender(ctx),
        x_to_y: true,

        amount_in,
        amount_out,
        minimum_amount_out,

        trading_fee,
        protocol_fee,

        executed_at_ms,
        deadline_ms,
    };

    event::emit(DexSwapExecuted {
        registry_id: object::id(registry),
        dex_pool_id,
        underlying_pool_id:
            liquidity_pool::pool_id(pool),

        trader: tx_context::sender(ctx),
        x_to_y: true,

        amount_in,
        amount_out,

        trading_fee,
        protocol_fee,

        executed_at_ms,
    });

    (output, receipt)
}

/* ------------------------------------------------------------
   Y → X routed swap
   ------------------------------------------------------------ */

public fun swap_exact_y_for_x<X, Y>(
    access: &access_control::AccessControl,
    registry: &mut DexRegistry,
    dex_pool_id: u64,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<Y>,
    minimum_amount_out: u64,
    deadline_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<X>, DexSwapReceipt) {
    access_control::assert_not_paused(access);
    assert_operational(registry);

    assert_registered_pool_route(
        registry,
        dex_pool_id,
        liquidity_pool::pool_id(pool),
    );

    assert!(
        !liquidity_pool::is_paused(pool),
        E_UNDERLYING_POOL_PAUSED,
    );

    assert_swap_deadline(
        registry,
        deadline_ms,
        clock,
    );

    let amount_in = coin::value(&input);

    assert!(
        amount_in > 0,
        E_ZERO_SWAP_INPUT,
    );

    let trading_fee =
        calculate_trading_fee(
            amount_in,
            liquidity_pool::trading_fee_bps(pool),
        );

    let protocol_fee_before =
        liquidity_pool::protocol_fees_y(pool);

    let output =
        liquidity_pool::swap_exact_y_for_x(
            access,
            pool,
            input,
            minimum_amount_out,
            ctx,
        );

    let amount_out =
        coin::value(&output);

    let protocol_fee_after =
        liquidity_pool::protocol_fees_y(pool);

    assert!(
        protocol_fee_after >= protocol_fee_before,
        E_SWAP_ACCOUNTING_INVARIANT,
    );

    let protocol_fee =
        protocol_fee_after - protocol_fee_before;

    let executed_at_ms =
        clock::timestamp_ms(clock);

    record_swap(
        registry,
        amount_in,
        amount_out,
        trading_fee,
    );

    let receipt = DexSwapReceipt {
        registry_id: object::id(registry),
        dex_pool_id,
        underlying_pool_id:
            liquidity_pool::pool_id(pool),

        trader: tx_context::sender(ctx),
        x_to_y: false,

        amount_in,
        amount_out,
        minimum_amount_out,

        trading_fee,
        protocol_fee,

        executed_at_ms,
        deadline_ms,
    };

    event::emit(DexSwapExecuted {
        registry_id: object::id(registry),
        dex_pool_id,
        underlying_pool_id:
            liquidity_pool::pool_id(pool),

        trader: tx_context::sender(ctx),
        x_to_y: false,

        amount_in,
        amount_out,

        trading_fee,
        protocol_fee,

        executed_at_ms,
    });

    (output, receipt)
}

/* ------------------------------------------------------------
   Routing assertions
   ------------------------------------------------------------ */

fun assert_registered_pool_route(
    registry: &DexRegistry,
    dex_pool_id: u64,
    supplied_pool_object_id: ID,
) {
    let index =
        find_pool_index(registry, dex_pool_id);

    let record =
        vector::borrow(&registry.pools, index);

    assert!(
        record.active,
        E_POOL_INACTIVE,
    );

    assert!(
        record.pool_object_id
            == supplied_pool_object_id,
        E_POOL_OBJECT_MISMATCH,
    );

    // Stage 5D will replace this temporary rejection
    // with canonical Oracle Price Router validation.
    assert!(
        !record.oracle_guard_enabled,
        E_ORACLE_GUARD_NOT_CONNECTED,
    );
}


/// Validates the registered DEX-to-pool route for an Oracle
/// guarded swap.
///
/// Unlike `assert_registered_pool_route`, this validator permits
/// a pool whose Oracle Guard is enabled. The Oracle Guard state,
/// circuit breaker, quote freshness, price scale and deviation
/// are validated immediately afterward by `assert_oracle_guard`.
fun assert_registered_oracle_pool_route(
    registry: &DexRegistry,
    dex_pool_id: u64,
    supplied_pool_object_id: ID,
) {
    let index =
        find_pool_index(registry, dex_pool_id);

    let record =
        vector::borrow(&registry.pools, index);

    assert!(
        record.active,
        E_POOL_INACTIVE,
    );

    assert!(
        record.pool_object_id
            == supplied_pool_object_id,
        E_POOL_OBJECT_MISMATCH,
    );

    // Stage 5D will replace this temporary rejection
    // with canonical Oracle Price Router validation.
}


fun assert_swap_deadline(
    registry: &DexRegistry,
    deadline_ms: u64,
    clock: &Clock,
) {
    let current_time_ms =
        clock::timestamp_ms(clock);

    assert!(
        current_time_ms <= deadline_ms,
        E_SWAP_DEADLINE_EXPIRED,
    );

    assert!(
        deadline_ms - current_time_ms
            <= registry.default_deadline_window_ms,
        E_SWAP_DEADLINE_TOO_FAR,
    );
}

fun calculate_trading_fee(
    amount_in: u64,
    trading_fee_bps: u64,
): u64 {
    (
        ((amount_in as u128)
            * (trading_fee_bps as u128))
            / (BPS_DENOMINATOR as u128)
    ) as u64
}

fun record_swap(
    registry: &mut DexRegistry,
    amount_in: u64,
    amount_out: u64,
    trading_fee: u64,
) {
    let old_swap_count =
        registry.total_swap_count;

    let old_input_volume =
        registry.total_input_volume;

    let old_output_volume =
        registry.total_output_volume;

    let old_fee_collected =
        registry.total_fee_collected;

    registry.total_swap_count =
        old_swap_count + 1;

    registry.total_input_volume =
        old_input_volume + amount_in;

    registry.total_output_volume =
        old_output_volume + amount_out;

    registry.total_fee_collected =
        old_fee_collected + trading_fee;

    assert!(
        registry.total_swap_count
            > old_swap_count,
        E_SWAP_ACCOUNTING_INVARIANT,
    );

    assert!(
        registry.total_input_volume
            >= old_input_volume,
        E_SWAP_ACCOUNTING_INVARIANT,
    );

    assert!(
        registry.total_output_volume
            >= old_output_volume,
        E_SWAP_ACCOUNTING_INVARIANT,
    );

    assert!(
        registry.total_fee_collected
            >= old_fee_collected,
        E_SWAP_ACCOUNTING_INVARIANT,
    );
}

/* ------------------------------------------------------------
   Swap Receipt getters
   ------------------------------------------------------------ */

public fun receipt_registry_id(
    receipt: &DexSwapReceipt,
): ID {
    receipt.registry_id
}

public fun receipt_dex_pool_id(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.dex_pool_id
}

public fun receipt_underlying_pool_id(
    receipt: &DexSwapReceipt,
): ID {
    receipt.underlying_pool_id
}

public fun receipt_trader(
    receipt: &DexSwapReceipt,
): address {
    receipt.trader
}

public fun receipt_x_to_y(
    receipt: &DexSwapReceipt,
): bool {
    receipt.x_to_y
}

public fun receipt_amount_in(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.amount_in
}

public fun receipt_amount_out(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.amount_out
}

public fun receipt_minimum_amount_out(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.minimum_amount_out
}

public fun receipt_trading_fee(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.trading_fee
}

public fun receipt_protocol_fee(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.protocol_fee
}

public fun receipt_executed_at_ms(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.executed_at_ms
}

public fun receipt_deadline_ms(
    receipt: &DexSwapReceipt,
): u64 {
    receipt.deadline_ms
}


/* ============================================================
   Testing Helpers
   ============================================================ */

#[test_only]
public fun destroy_admin_cap_for_testing(
    admin_cap: DexAdminCap,
) {
    let DexAdminCap {
        id,
        registry_id: _,
    } = admin_cap;

    object::delete(id);
}

#[test_only]
public fun destroy_registry_for_testing(
    registry: DexRegistry,
) {
    let DexRegistry {
        id,

        version: _,
        paused: _,

        next_pool_id: _,
        registered_pool_count: _,
        active_pool_count: _,

        total_swap_count: _,
        total_input_volume: _,
        total_output_volume: _,
        total_fee_collected: _,

        max_oracle_deviation_bps: _,
        oracle_circuit_breaker_active: _,
        default_deadline_window_ms: _,

        pools: _,
    } = registry;

    object::delete(id);
}
