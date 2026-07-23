module tobmate_core::liquidity_pool;

use tobmate_core::access_control;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

const BPS_DENOMINATOR: u64 = 10_000;

const E_POOL_PAUSED: u64 = 1;
const E_INVALID_FEE: u64 = 2;
const E_ALREADY_INITIALIZED: u64 = 3;
const E_NOT_INITIALIZED: u64 = 4;
const E_ZERO_AMOUNT: u64 = 5;
const E_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 6;
const E_INVALID_POSITION_POOL: u64 = 7;
const E_NOT_POSITION_OWNER: u64 = 8;
const E_POSITION_INACTIVE: u64 = 9;
const E_INSUFFICIENT_POSITION_LIQUIDITY: u64 = 10;
const E_INSUFFICIENT_POOL_LIQUIDITY: u64 = 11;
const E_SLIPPAGE_EXCEEDED: u64 = 12;
const E_ZERO_OUTPUT: u64 = 13;
const E_STATE_UNCHANGED: u64 = 14;
const E_VERSION_UNCHANGED: u64 = 15;
const E_ACCOUNTING_INVARIANT: u64 = 16;
const E_ZERO_PROTOCOL_FEES: u64 = 17;

public struct LiquidityPoolAdminCap has key, store {
    id: UID,
}

public struct LiquidityPool<phantom X, phantom Y> has key {
    id: UID,

    version: u64,
    paused: bool,

    reserve_x: Balance<X>,
    reserve_y: Balance<Y>,

    protocol_fees_x: Balance<X>,
    protocol_fees_y: Balance<Y>,

    total_liquidity: u64,
    position_count: u64,

    trading_fee_bps: u64,
    protocol_fee_share_bps: u64,

    total_volume_x: u64,
    total_volume_y: u64,

    total_protocol_fees_x: u64,
    total_protocol_fees_y: u64,

    liquidity_add_count: u64,
    liquidity_remove_count: u64,
    swap_count: u64,

    next_position_id: u64,
}

public struct LiquidityPosition<phantom X, phantom Y> has key, store {
    id: UID,

    position_id: u64,
    pool_id: ID,
    owner: address,

    liquidity: u64,

    deposited_x: u64,
    deposited_y: u64,

    withdrawn_x: u64,
    withdrawn_y: u64,

    active: bool,
}

public struct PoolCreated has copy, drop {
    pool_id: ID,
    trading_fee_bps: u64,
    protocol_fee_share_bps: u64,
}

public struct LiquidityAdded has copy, drop {
    pool_id: ID,
    position_id: u64,
    owner: address,

    amount_x: u64,
    amount_y: u64,

    liquidity_minted: u64,
}

public struct LiquidityRemoved has copy, drop {
    pool_id: ID,
    position_id: u64,
    owner: address,

    amount_x: u64,
    amount_y: u64,

    liquidity_burned: u64,
}

public struct SwapExecuted has copy, drop {
    pool_id: ID,
    trader: address,

    x_to_y: bool,

    amount_in: u64,
    amount_out: u64,

    trading_fee: u64,
    protocol_fee: u64,
}

public struct PoolPauseChanged has copy, drop {
    pool_id: ID,
    paused: bool,
}

public struct PoolVersionChanged has copy, drop {
    pool_id: ID,
    old_version: u64,
    new_version: u64,
}

fun init(ctx: &mut TxContext) {
    transfer::public_transfer(
        LiquidityPoolAdminCap {
            id: object::new(ctx),
        },
        tx_context::sender(ctx),
    );
}

public fun create_pool<X, Y>(
    _: &LiquidityPoolAdminCap,
    access: &access_control::AccessControl,
    trading_fee_bps: u64,
    protocol_fee_share_bps: u64,
    ctx: &mut TxContext,
): LiquidityPool<X, Y> {
    access_control::assert_not_paused(access);

    assert!(
        trading_fee_bps < BPS_DENOMINATOR,
        E_INVALID_FEE,
    );

    assert!(
        protocol_fee_share_bps <= BPS_DENOMINATOR,
        E_INVALID_FEE,
    );

    let pool = LiquidityPool<X, Y> {
        id: object::new(ctx),

        version: 1,
        paused: false,

        reserve_x: balance::zero<X>(),
        reserve_y: balance::zero<Y>(),

        protocol_fees_x: balance::zero<X>(),
        protocol_fees_y: balance::zero<Y>(),

        total_liquidity: 0,
        position_count: 0,

        trading_fee_bps,
        protocol_fee_share_bps,

        total_volume_x: 0,
        total_volume_y: 0,

        total_protocol_fees_x: 0,
        total_protocol_fees_y: 0,

        liquidity_add_count: 0,
        liquidity_remove_count: 0,
        swap_count: 0,

        next_position_id: 1,
    };

    event::emit(PoolCreated {
        pool_id: object::id(&pool),
        trading_fee_bps,
        protocol_fee_share_bps,
    });

    pool
}

public fun initialize_liquidity<X, Y>(
    access: &access_control::AccessControl,
    pool: &mut LiquidityPool<X, Y>,
    coin_x: Coin<X>,
    coin_y: Coin<Y>,
    ctx: &mut TxContext,
): LiquidityPosition<X, Y> {
    assert_operational(access, pool);

    assert!(
        pool.total_liquidity == 0,
        E_ALREADY_INITIALIZED,
    );

    let amount_x = coin::value(&coin_x);
    let amount_y = coin::value(&coin_y);

    assert!(
        amount_x > 0 && amount_y > 0,
        E_ZERO_AMOUNT,
    );

    let product =
        (amount_x as u128) * (amount_y as u128);

    let liquidity =
        integer_sqrt(product);

    assert!(
        liquidity > 0,
        E_INSUFFICIENT_LIQUIDITY_MINTED,
    );

    balance::join(
        &mut pool.reserve_x,
        coin::into_balance(coin_x),
    );

    balance::join(
        &mut pool.reserve_y,
        coin::into_balance(coin_y),
    );

    pool.total_liquidity = liquidity;
    pool.position_count = 1;
    pool.liquidity_add_count = 1;

    let position_id =
        pool.next_position_id;

    pool.next_position_id =
        position_id + 1;

    let owner =
        tx_context::sender(ctx);

    let position = LiquidityPosition<X, Y> {
        id: object::new(ctx),

        position_id,
        pool_id: object::id(pool),
        owner,

        liquidity,

        deposited_x: amount_x,
        deposited_y: amount_y,

        withdrawn_x: 0,
        withdrawn_y: 0,

        active: true,
    };

    assert_accounting_invariant(pool);

    event::emit(LiquidityAdded {
        pool_id: object::id(pool),
        position_id,
        owner,

        amount_x,
        amount_y,

        liquidity_minted: liquidity,
    });

    position
}

public fun add_liquidity<X, Y>(
    access: &access_control::AccessControl,
    pool: &mut LiquidityPool<X, Y>,
    position: &mut LiquidityPosition<X, Y>,
    mut coin_x: Coin<X>,
    mut coin_y: Coin<Y>,
    ctx: &mut TxContext,
): (Coin<X>, Coin<Y>, u64) {
    assert_operational(access, pool);
    assert_position_owner_and_pool(pool, position, ctx);

    assert!(
        pool.total_liquidity > 0,
        E_NOT_INITIALIZED,
    );

    let offered_x =
        coin::value(&coin_x);

    let offered_y =
        coin::value(&coin_y);

    assert!(
        offered_x > 0 && offered_y > 0,
        E_ZERO_AMOUNT,
    );

    let reserve_x =
        balance::value(&pool.reserve_x);

    let reserve_y =
        balance::value(&pool.reserve_y);

    let liquidity_from_x =
        (
            (offered_x as u128)
                * (pool.total_liquidity as u128)
                / (reserve_x as u128)
        ) as u64;

    let liquidity_from_y =
        (
            (offered_y as u128)
                * (pool.total_liquidity as u128)
                / (reserve_y as u128)
        ) as u64;

    let liquidity_minted =
        min_u64(
            liquidity_from_x,
            liquidity_from_y,
        );

    assert!(
        liquidity_minted > 0,
        E_INSUFFICIENT_LIQUIDITY_MINTED,
    );

    let used_x =
        (
            (liquidity_minted as u128)
                * (reserve_x as u128)
                / (pool.total_liquidity as u128)
        ) as u64;

    let used_y =
        (
            (liquidity_minted as u128)
                * (reserve_y as u128)
                / (pool.total_liquidity as u128)
        ) as u64;

    assert!(
        used_x > 0 && used_y > 0,
        E_ZERO_AMOUNT,
    );

    let used_coin_x =
        coin::split(
            &mut coin_x,
            used_x,
            ctx,
        );

    let used_coin_y =
        coin::split(
            &mut coin_y,
            used_y,
            ctx,
        );

    balance::join(
        &mut pool.reserve_x,
        coin::into_balance(used_coin_x),
    );

    balance::join(
        &mut pool.reserve_y,
        coin::into_balance(used_coin_y),
    );

    pool.total_liquidity =
        pool.total_liquidity
            + liquidity_minted;

    pool.liquidity_add_count =
        pool.liquidity_add_count + 1;

    position.liquidity =
        position.liquidity
            + liquidity_minted;

    position.deposited_x =
        position.deposited_x
            + used_x;

    position.deposited_y =
        position.deposited_y
            + used_y;

    assert_accounting_invariant(pool);

    event::emit(LiquidityAdded {
        pool_id: object::id(pool),
        position_id: position.position_id,
        owner: position.owner,

        amount_x: used_x,
        amount_y: used_y,

        liquidity_minted,
    });

    (
        coin_x,
        coin_y,
        liquidity_minted,
    )
}

public fun remove_liquidity<X, Y>(
    access: &access_control::AccessControl,
    pool: &mut LiquidityPool<X, Y>,
    position: &mut LiquidityPosition<X, Y>,
    liquidity_amount: u64,
    minimum_x: u64,
    minimum_y: u64,
    ctx: &mut TxContext,
): (Coin<X>, Coin<Y>) {
    assert_operational(access, pool);
    assert_position_owner_and_pool(pool, position, ctx);

    assert!(
        liquidity_amount > 0,
        E_ZERO_AMOUNT,
    );

    assert!(
        liquidity_amount <= position.liquidity,
        E_INSUFFICIENT_POSITION_LIQUIDITY,
    );

    assert!(
        liquidity_amount <= pool.total_liquidity,
        E_INSUFFICIENT_POOL_LIQUIDITY,
    );

    let reserve_x =
        balance::value(&pool.reserve_x);

    let reserve_y =
        balance::value(&pool.reserve_y);

    let amount_x =
        (
            (reserve_x as u128)
                * (liquidity_amount as u128)
                / (pool.total_liquidity as u128)
        ) as u64;

    let amount_y =
        (
            (reserve_y as u128)
                * (liquidity_amount as u128)
                / (pool.total_liquidity as u128)
        ) as u64;

    assert!(
        amount_x >= minimum_x
            && amount_y >= minimum_y,
        E_SLIPPAGE_EXCEEDED,
    );

    assert!(
        amount_x > 0 && amount_y > 0,
        E_ZERO_OUTPUT,
    );

    let withdrawn_x =
        balance::split(
            &mut pool.reserve_x,
            amount_x,
        );

    let withdrawn_y =
        balance::split(
            &mut pool.reserve_y,
            amount_y,
        );

    pool.total_liquidity =
        pool.total_liquidity
            - liquidity_amount;

    pool.liquidity_remove_count =
        pool.liquidity_remove_count + 1;

    position.liquidity =
        position.liquidity
            - liquidity_amount;

    position.withdrawn_x =
        position.withdrawn_x
            + amount_x;

    position.withdrawn_y =
        position.withdrawn_y
            + amount_y;

    if (position.liquidity == 0) {
        position.active = false;
    };

    assert_accounting_invariant(pool);

    event::emit(LiquidityRemoved {
        pool_id: object::id(pool),
        position_id: position.position_id,
        owner: position.owner,

        amount_x,
        amount_y,

        liquidity_burned: liquidity_amount,
    });

    (
        coin::from_balance(
            withdrawn_x,
            ctx,
        ),
        coin::from_balance(
            withdrawn_y,
            ctx,
        ),
    )
}

public fun swap_exact_x_for_y<X, Y>(
    access: &access_control::AccessControl,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<X>,
    minimum_output: u64,
    ctx: &mut TxContext,
): Coin<Y> {
    assert_operational(access, pool);

    assert!(
        pool.total_liquidity > 0,
        E_NOT_INITIALIZED,
    );

    let amount_in =
        coin::value(&input);

    assert!(
        amount_in > 0,
        E_ZERO_AMOUNT,
    );

    let reserve_x_before =
        balance::value(&pool.reserve_x);

    let reserve_y_before =
        balance::value(&pool.reserve_y);

    let trading_fee =
        (
            (amount_in as u128)
                * (pool.trading_fee_bps as u128)
                / (BPS_DENOMINATOR as u128)
        ) as u64;

    let protocol_fee =
        (
            (trading_fee as u128)
                * (pool.protocol_fee_share_bps as u128)
                / (BPS_DENOMINATOR as u128)
        ) as u64;

    let effective_input =
        amount_in - trading_fee;

    let amount_out =
        (
            (reserve_y_before as u128)
                * (effective_input as u128)
                / (
                    (reserve_x_before as u128)
                        + (effective_input as u128)
                )
        ) as u64;

    assert!(
        amount_out > 0,
        E_ZERO_OUTPUT,
    );

    assert!(
        amount_out >= minimum_output,
        E_SLIPPAGE_EXCEEDED,
    );

    assert!(
        amount_out < reserve_y_before,
        E_INSUFFICIENT_POOL_LIQUIDITY,
    );

    let mut input_balance =
        coin::into_balance(input);

    if (protocol_fee > 0) {
        let protocol_balance =
            balance::split(
                &mut input_balance,
                protocol_fee,
            );

        balance::join(
            &mut pool.protocol_fees_x,
            protocol_balance,
        );
    };

    balance::join(
        &mut pool.reserve_x,
        input_balance,
    );

    let output_balance =
        balance::split(
            &mut pool.reserve_y,
            amount_out,
        );

    pool.total_volume_x =
        pool.total_volume_x + amount_in;

    pool.total_protocol_fees_x =
        pool.total_protocol_fees_x
            + protocol_fee;

    pool.swap_count =
        pool.swap_count + 1;

    assert_accounting_invariant(pool);

    event::emit(SwapExecuted {
        pool_id: object::id(pool),
        trader: tx_context::sender(ctx),

        x_to_y: true,

        amount_in,
        amount_out,

        trading_fee,
        protocol_fee,
    });

    coin::from_balance(
        output_balance,
        ctx,
    )
}

public fun swap_exact_y_for_x<X, Y>(
    access: &access_control::AccessControl,
    pool: &mut LiquidityPool<X, Y>,
    input: Coin<Y>,
    minimum_output: u64,
    ctx: &mut TxContext,
): Coin<X> {
    assert_operational(access, pool);

    assert!(
        pool.total_liquidity > 0,
        E_NOT_INITIALIZED,
    );

    let amount_in =
        coin::value(&input);

    assert!(
        amount_in > 0,
        E_ZERO_AMOUNT,
    );

    let reserve_x_before =
        balance::value(&pool.reserve_x);

    let reserve_y_before =
        balance::value(&pool.reserve_y);

    let trading_fee =
        (
            (amount_in as u128)
                * (pool.trading_fee_bps as u128)
                / (BPS_DENOMINATOR as u128)
        ) as u64;

    let protocol_fee =
        (
            (trading_fee as u128)
                * (pool.protocol_fee_share_bps as u128)
                / (BPS_DENOMINATOR as u128)
        ) as u64;

    let effective_input =
        amount_in - trading_fee;

    let amount_out =
        (
            (reserve_x_before as u128)
                * (effective_input as u128)
                / (
                    (reserve_y_before as u128)
                        + (effective_input as u128)
                )
        ) as u64;

    assert!(
        amount_out > 0,
        E_ZERO_OUTPUT,
    );

    assert!(
        amount_out >= minimum_output,
        E_SLIPPAGE_EXCEEDED,
    );

    assert!(
        amount_out < reserve_x_before,
        E_INSUFFICIENT_POOL_LIQUIDITY,
    );

    let mut input_balance =
        coin::into_balance(input);

    if (protocol_fee > 0) {
        let protocol_balance =
            balance::split(
                &mut input_balance,
                protocol_fee,
            );

        balance::join(
            &mut pool.protocol_fees_y,
            protocol_balance,
        );
    };

    balance::join(
        &mut pool.reserve_y,
        input_balance,
    );

    let output_balance =
        balance::split(
            &mut pool.reserve_x,
            amount_out,
        );

    pool.total_volume_y =
        pool.total_volume_y + amount_in;

    pool.total_protocol_fees_y =
        pool.total_protocol_fees_y
            + protocol_fee;

    pool.swap_count =
        pool.swap_count + 1;

    assert_accounting_invariant(pool);

    event::emit(SwapExecuted {
        pool_id: object::id(pool),
        trader: tx_context::sender(ctx),

        x_to_y: false,

        amount_in,
        amount_out,

        trading_fee,
        protocol_fee,
    });

    coin::from_balance(
        output_balance,
        ctx,
    )
}

public fun withdraw_protocol_fees<X, Y>(
    _: &LiquidityPoolAdminCap,
    pool: &mut LiquidityPool<X, Y>,
    ctx: &mut TxContext,
): (Coin<X>, Coin<Y>) {
    let amount_x =
        balance::value(&pool.protocol_fees_x);

    let amount_y =
        balance::value(&pool.protocol_fees_y);

    assert!(
        amount_x > 0 || amount_y > 0,
        E_ZERO_PROTOCOL_FEES,
    );

    let fees_x =
        balance::withdraw_all(
            &mut pool.protocol_fees_x,
        );

    let fees_y =
        balance::withdraw_all(
            &mut pool.protocol_fees_y,
        );

    (
        coin::from_balance(
            fees_x,
            ctx,
        ),
        coin::from_balance(
            fees_y,
            ctx,
        ),
    )
}

public fun set_paused<X, Y>(
    _: &LiquidityPoolAdminCap,
    pool: &mut LiquidityPool<X, Y>,
    paused: bool,
) {
    assert!(
        pool.paused != paused,
        E_STATE_UNCHANGED,
    );

    pool.paused = paused;

    event::emit(PoolPauseChanged {
        pool_id: object::id(pool),
        paused,
    });
}

public fun set_version<X, Y>(
    _: &LiquidityPoolAdminCap,
    pool: &mut LiquidityPool<X, Y>,
    new_version: u64,
) {
    assert!(
        pool.version != new_version,
        E_VERSION_UNCHANGED,
    );

    let old_version =
        pool.version;

    pool.version =
        new_version;

    event::emit(PoolVersionChanged {
        pool_id: object::id(pool),
        old_version,
        new_version,
    });
}

fun assert_operational<X, Y>(
    access: &access_control::AccessControl,
    pool: &LiquidityPool<X, Y>,
) {
    access_control::assert_not_paused(access);

    assert!(
        !pool.paused,
        E_POOL_PAUSED,
    );
}

fun assert_position_owner_and_pool<X, Y>(
    pool: &LiquidityPool<X, Y>,
    position: &LiquidityPosition<X, Y>,
    ctx: &TxContext,
) {
    assert!(
        position.pool_id == object::id(pool),
        E_INVALID_POSITION_POOL,
    );

    assert!(
        position.owner == tx_context::sender(ctx),
        E_NOT_POSITION_OWNER,
    );

    assert!(
        position.active,
        E_POSITION_INACTIVE,
    );
}

fun assert_accounting_invariant<X, Y>(
    pool: &LiquidityPool<X, Y>,
) {
    let reserve_x =
        balance::value(&pool.reserve_x);

    let reserve_y =
        balance::value(&pool.reserve_y);

    let protocol_fees_x =
        balance::value(&pool.protocol_fees_x);

    let protocol_fees_y =
        balance::value(&pool.protocol_fees_y);

    if (pool.total_liquidity == 0) {
        assert!(
            reserve_x == 0 && reserve_y == 0,
            E_ACCOUNTING_INVARIANT,
        );
    } else {
        assert!(
            reserve_x > 0 && reserve_y > 0,
            E_ACCOUNTING_INVARIANT,
        );
    };

    assert!(
        protocol_fees_x
            <= pool.total_protocol_fees_x,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        protocol_fees_y
            <= pool.total_protocol_fees_y,
        E_ACCOUNTING_INVARIANT,
    );
}

fun min_u64(
    a: u64,
    b: u64,
): u64 {
    if (a < b) {
        a
    } else {
        b
    }
}

fun integer_sqrt(
    value: u128,
): u64 {
    if (value == 0) {
        return 0
    };

    let mut x =
        value;

    let mut y =
        (x + 1) / 2;

    while (y < x) {
        x = y;
        y = (
            x + value / x
        ) / 2;
    };

    x as u64
}

public fun pool_id<X, Y>(
    pool: &LiquidityPool<X, Y>,
): ID {
    object::id(pool)
}

public fun version<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.version
}

public fun is_paused<X, Y>(
    pool: &LiquidityPool<X, Y>,
): bool {
    pool.paused
}

public fun reserve_x<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    balance::value(&pool.reserve_x)
}

public fun reserve_y<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    balance::value(&pool.reserve_y)
}

public fun protocol_fees_x<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    balance::value(&pool.protocol_fees_x)
}

public fun protocol_fees_y<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    balance::value(&pool.protocol_fees_y)
}

public fun total_liquidity<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.total_liquidity
}

public fun position_count<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.position_count
}

public fun trading_fee_bps<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.trading_fee_bps
}

public fun protocol_fee_share_bps<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.protocol_fee_share_bps
}

public fun total_volume_x<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.total_volume_x
}

public fun total_volume_y<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.total_volume_y
}

public fun swap_count<X, Y>(
    pool: &LiquidityPool<X, Y>,
): u64 {
    pool.swap_count
}

public fun position_id<X, Y>(
    position: &LiquidityPosition<X, Y>,
): u64 {
    position.position_id
}

public fun position_pool_id<X, Y>(
    position: &LiquidityPosition<X, Y>,
): ID {
    position.pool_id
}

public fun position_owner<X, Y>(
    position: &LiquidityPosition<X, Y>,
): address {
    position.owner
}

public fun position_liquidity<X, Y>(
    position: &LiquidityPosition<X, Y>,
): u64 {
    position.liquidity
}

public fun position_is_active<X, Y>(
    position: &LiquidityPosition<X, Y>,
): bool {
    position.active
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: LiquidityPoolAdminCap,
) {
    let LiquidityPoolAdminCap {
        id,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_position_for_testing<X, Y>(
    position: LiquidityPosition<X, Y>,
) {
    let LiquidityPosition {
        id,

        position_id: _,
        pool_id: _,
        owner: _,

        liquidity: _,

        deposited_x: _,
        deposited_y: _,

        withdrawn_x: _,
        withdrawn_y: _,

        active: _,
    } = position;

    object::delete(id);
}

#[test_only]
public fun destroy_pool_for_testing<X, Y>(
    pool: LiquidityPool<X, Y>,
) {
    let LiquidityPool {
        id,

        version: _,
        paused: _,

        reserve_x,
        reserve_y,

        protocol_fees_x,
        protocol_fees_y,

        total_liquidity: _,
        position_count: _,

        trading_fee_bps: _,
        protocol_fee_share_bps: _,

        total_volume_x: _,
        total_volume_y: _,

        total_protocol_fees_x: _,
        total_protocol_fees_y: _,

        liquidity_add_count: _,
        liquidity_remove_count: _,
        swap_count: _,

        next_position_id: _,
    } = pool;

    assert!(
        balance::value(&reserve_x) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&reserve_y) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&protocol_fees_x) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&protocol_fees_y) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    balance::destroy_zero(reserve_x);
    balance::destroy_zero(reserve_y);

    balance::destroy_zero(protocol_fees_x);
    balance::destroy_zero(protocol_fees_y);

    object::delete(id);
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): LiquidityPoolAdminCap {
    LiquidityPoolAdminCap {
        id: object::new(ctx),
    }
}
