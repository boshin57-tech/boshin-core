module tobmate_core::dex;

use std::string::String;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control;
use tobmate_core::liquidity_pool::{
    Self,
    LiquidityPool,
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
        default_deadline_window_ms: _,

        pools: _,
    } = registry;

    object::delete(id);
}
