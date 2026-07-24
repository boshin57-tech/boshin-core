module tobmate_core::treasury_yield_engine;

use std::vector;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::sui::SUI;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

const E_ZERO_AMOUNT: u64 = 1;
const E_ENGINE_PAUSED: u64 = 2;
const E_STATE_UNCHANGED: u64 = 3;
const E_VERSION_UNCHANGED: u64 = 4;
const E_DUPLICATE_STRATEGY: u64 = 5;
const E_STRATEGY_NOT_FOUND: u64 = 6;
const E_STRATEGY_INACTIVE: u64 = 7;
const E_ALLOCATION_LIMIT_EXCEEDED: u64 = 8;
const E_INSUFFICIENT_IDLE_FUNDS: u64 = 9;
const E_LOSS_EXCEEDS_OUTSTANDING: u64 = 10;
const E_RETURN_EXCEEDS_OUTSTANDING: u64 = 11;
const E_ACCOUNTING_INVARIANT: u64 = 12;
const E_ZERO_ALLOCATION_LIMIT: u64 = 13;

public struct YieldEngineAdminCap has key, store {
    id: UID,
}

public struct YieldStrategy has store {
    strategy_id: u64,
    external_key: vector<u8>,
    active: bool,
    allocation_limit: u64,

    total_allocated: u64,
    total_returned: u64,
    gross_yield: u64,
    recognized_loss: u64,

    allocation_count: u64,
    return_count: u64,
    yield_record_count: u64,
    loss_record_count: u64,
}

public struct TreasuryYieldEngine has key {
    id: UID,

    version: u64,
    paused: bool,

    funds: Balance<SUI>,

    strategies: vector<YieldStrategy>,
    next_strategy_id: u64,

    total_funded: u64,
    total_allocated: u64,
    total_returned: u64,

    gross_yield: u64,
    recognized_loss: u64,

    funding_count: u64,
    allocation_count: u64,
    return_count: u64,
    yield_record_count: u64,
    loss_record_count: u64,
}

public struct YieldEngineFunded has copy, drop {
    engine_id: ID,
    amount: u64,
    idle_balance_after: u64,
    total_funded: u64,
    funded_by: address,
}

public struct YieldStrategyRegistered has copy, drop {
    engine_id: ID,
    strategy_id: u64,
    allocation_limit: u64,
    registered_by: address,
}

public struct YieldStrategyStateChanged has copy, drop {
    engine_id: ID,
    strategy_id: u64,
    active: bool,
    changed_by: address,
}

public struct YieldCapitalAllocated has copy, drop {
    engine_id: ID,
    strategy_id: u64,
    amount: u64,
    outstanding_after: u64,
    recipient: address,
    allocated_by: address,
}

public struct YieldCapitalReturned has copy, drop {
    engine_id: ID,
    strategy_id: u64,
    amount: u64,
    outstanding_after: u64,
    idle_balance_after: u64,
    returned_by: address,
}

public struct StrategyYieldRecorded has copy, drop {
    engine_id: ID,
    strategy_id: u64,
    amount: u64,
    strategy_gross_yield: u64,
    engine_gross_yield: u64,
    recorded_by: address,
}

public struct StrategyLossRecorded has copy, drop {
    engine_id: ID,
    strategy_id: u64,
    amount: u64,
    strategy_recognized_loss: u64,
    engine_recognized_loss: u64,
    recorded_by: address,
}

public struct YieldEnginePauseChanged has copy, drop {
    engine_id: ID,
    paused: bool,
    changed_by: address,
}

public struct YieldEngineVersionChanged has copy, drop {
    engine_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        YieldEngineAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        TreasuryYieldEngine {
            id: object::new(ctx),
            version: 1,
            paused: false,
            funds: balance::zero<SUI>(),
            strategies: vector::empty<YieldStrategy>(),
            next_strategy_id: 1,
            total_funded: 0,
            total_allocated: 0,
            total_returned: 0,
            gross_yield: 0,
            recognized_loss: 0,
            funding_count: 0,
            allocation_count: 0,
            return_count: 0,
            yield_record_count: 0,
            loss_record_count: 0,
        },
    );
}

public fun fund(
    access: &AccessControl,
    engine: &mut TreasuryYieldEngine,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(access, engine);

    let amount = coin::value(&payment);

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    balance::join(
        &mut engine.funds,
        coin::into_balance(payment),
    );

    engine.total_funded =
        engine.total_funded + amount;

    engine.funding_count =
        engine.funding_count + 1;

    assert_accounting_invariant(engine);

    event::emit(YieldEngineFunded {
        engine_id: object::uid_to_inner(&engine.id),
        amount,
        idle_balance_after:
            balance::value(&engine.funds),
        total_funded:
            engine.total_funded,
        funded_by:
            tx_context::sender(ctx),
    });
}

public fun register_strategy(
    _admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,
    external_key: vector<u8>,
    allocation_limit: u64,
    ctx: &mut TxContext,
): u64 {
    assert!(
        !engine.paused,
        E_ENGINE_PAUSED,
    );

    assert!(
        allocation_limit > 0,
        E_ZERO_ALLOCATION_LIMIT,
    );

    assert!(
        !contains_strategy_key(
            engine,
            &external_key,
        ),
        E_DUPLICATE_STRATEGY,
    );

    let strategy_id =
        engine.next_strategy_id;

    engine.next_strategy_id =
        strategy_id + 1;

    vector::push_back(
        &mut engine.strategies,
        YieldStrategy {
            strategy_id,
            external_key,
            active: false,
            allocation_limit,
            total_allocated: 0,
            total_returned: 0,
            gross_yield: 0,
            recognized_loss: 0,
            allocation_count: 0,
            return_count: 0,
            yield_record_count: 0,
            loss_record_count: 0,
        },
    );

    event::emit(YieldStrategyRegistered {
        engine_id:
            object::uid_to_inner(&engine.id),
        strategy_id,
        allocation_limit,
        registered_by:
            tx_context::sender(ctx),
    });

    strategy_id
}

public fun set_strategy_active(
    _admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,
    strategy_id: u64,
    active: bool,
    ctx: &mut TxContext,
) {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    let strategy =
        vector::borrow_mut(
            &mut engine.strategies,
            index,
        );

    assert!(
        strategy.active != active,
        E_STATE_UNCHANGED,
    );

    strategy.active = active;

    event::emit(YieldStrategyStateChanged {
        engine_id:
            object::uid_to_inner(&engine.id),
        strategy_id,
        active,
        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_strategy_allocation_limit(
    _admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,
    strategy_id: u64,
    allocation_limit: u64,
) {
    assert!(
        allocation_limit > 0,
        E_ZERO_ALLOCATION_LIMIT,
    );

    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    let strategy =
        vector::borrow_mut(
            &mut engine.strategies,
            index,
        );

    assert!(
        strategy_outstanding(strategy)
            <= allocation_limit,
        E_ALLOCATION_LIMIT_EXCEEDED,
    );

    strategy.allocation_limit =
        allocation_limit;
}

public fun allocate_capital(
    _admin_cap: &YieldEngineAdminCap,
    access: &AccessControl,
    engine: &mut TreasuryYieldEngine,
    strategy_id: u64,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        engine,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    assert!(
        balance::value(&engine.funds)
            >= amount,
        E_INSUFFICIENT_IDLE_FUNDS,
    );

    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        assert!(
            strategy.active,
            E_STRATEGY_INACTIVE,
        );

        assert!(
            strategy_outstanding(strategy)
                + amount
                <= strategy.allocation_limit,
            E_ALLOCATION_LIMIT_EXCEEDED,
        );
    };

    {
        let strategy =
            vector::borrow_mut(
                &mut engine.strategies,
                index,
            );

        strategy.total_allocated =
            strategy.total_allocated + amount;

        strategy.allocation_count =
            strategy.allocation_count + 1;
    };

    engine.total_allocated =
        engine.total_allocated + amount;

    engine.allocation_count =
        engine.allocation_count + 1;

    let deployed_balance =
        balance::split(
            &mut engine.funds,
            amount,
        );

    let deployed_coin =
        coin::from_balance(
            deployed_balance,
            ctx,
        );

    transfer::public_transfer(
        deployed_coin,
        recipient,
    );

    assert_accounting_invariant(engine);

    let outstanding_after = {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        strategy_outstanding(strategy)
    };

    event::emit(YieldCapitalAllocated {
        engine_id:
            object::uid_to_inner(&engine.id),

        strategy_id,

        amount,

        outstanding_after,

        recipient,

        allocated_by:
            tx_context::sender(ctx),
    });
}

public fun return_capital(
    access: &AccessControl,
    engine: &mut TreasuryYieldEngine,
    strategy_id: u64,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        engine,
    );

    let amount =
        coin::value(&payment);

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        assert!(
            amount
                <= strategy_outstanding(strategy),
            E_RETURN_EXCEEDS_OUTSTANDING,
        );
    };

    balance::join(
        &mut engine.funds,
        coin::into_balance(payment),
    );

    {
        let strategy =
            vector::borrow_mut(
                &mut engine.strategies,
                index,
            );

        strategy.total_returned =
            strategy.total_returned + amount;

        strategy.return_count =
            strategy.return_count + 1;
    };

    engine.total_returned =
        engine.total_returned + amount;

    engine.return_count =
        engine.return_count + 1;

    assert_accounting_invariant(engine);

    let outstanding_after = {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        strategy_outstanding(strategy)
    };

    event::emit(YieldCapitalReturned {
        engine_id:
            object::uid_to_inner(&engine.id),

        strategy_id,

        amount,

        outstanding_after,

        idle_balance_after:
            balance::value(&engine.funds),

        returned_by:
            tx_context::sender(ctx),
    });
}

public fun record_yield(
    access: &AccessControl,
    engine: &mut TreasuryYieldEngine,
    strategy_id: u64,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        engine,
    );

    let amount =
        coin::value(&payment);

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    balance::join(
        &mut engine.funds,
        coin::into_balance(payment),
    );

    {
        let strategy =
            vector::borrow_mut(
                &mut engine.strategies,
                index,
            );

        strategy.gross_yield =
            strategy.gross_yield + amount;

        strategy.yield_record_count =
            strategy.yield_record_count + 1;
    };

    engine.gross_yield =
        engine.gross_yield + amount;

    engine.yield_record_count =
        engine.yield_record_count + 1;

    assert_accounting_invariant(engine);

    let strategy_gross_yield = {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        strategy.gross_yield
    };

    event::emit(StrategyYieldRecorded {
        engine_id:
            object::uid_to_inner(&engine.id),

        strategy_id,
        amount,
        strategy_gross_yield,

        engine_gross_yield:
            engine.gross_yield,

        recorded_by:
            tx_context::sender(ctx),
    });
}

public fun record_loss(
    _admin_cap: &YieldEngineAdminCap,
    access: &AccessControl,
    engine: &mut TreasuryYieldEngine,
    strategy_id: u64,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        engine,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        assert!(
            amount <=
                strategy_outstanding(strategy),
            E_LOSS_EXCEEDS_OUTSTANDING,
        );
    };

    {
        let strategy =
            vector::borrow_mut(
                &mut engine.strategies,
                index,
            );

        strategy.recognized_loss =
            strategy.recognized_loss + amount;

        strategy.loss_record_count =
            strategy.loss_record_count + 1;
    };

    engine.recognized_loss =
        engine.recognized_loss + amount;

    engine.loss_record_count =
        engine.loss_record_count + 1;

    assert_accounting_invariant(engine);

    let strategy_recognized_loss = {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        strategy.recognized_loss
    };

    event::emit(StrategyLossRecorded {
        engine_id:
            object::uid_to_inner(&engine.id),

        strategy_id,
        amount,
        strategy_recognized_loss,

        engine_recognized_loss:
            engine.recognized_loss,

        recorded_by:
            tx_context::sender(ctx),
    });
}

public fun set_paused(
    _admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(
        engine.paused != paused,
        E_STATE_UNCHANGED,
    );

    engine.paused = paused;

    event::emit(YieldEnginePauseChanged {
        engine_id:
            object::uid_to_inner(&engine.id),

        paused,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_version(
    _admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version =
        engine.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    engine.version =
        new_version;

    event::emit(YieldEngineVersionChanged {
        engine_id:
            object::uid_to_inner(&engine.id),

        previous_version,

        new_version,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun assert_operational(
    access: &AccessControl,
    engine: &TreasuryYieldEngine,
) {
    access_control::assert_not_paused(access);

    assert!(
        !engine.paused,
        E_ENGINE_PAUSED,
    );
}

public fun assert_accounting_invariant(
    engine: &TreasuryYieldEngine,
) {
    assert!(
        engine.total_funded
            + engine.gross_yield
            ==
            balance::value(&engine.funds)
                + outstanding_principal(engine)
                + engine.recognized_loss,
        E_ACCOUNTING_INVARIANT,
    );
}


fun contains_strategy_key(
    engine: &TreasuryYieldEngine,
    external_key: &vector<u8>,
): bool {
    let length =
        vector::length(&engine.strategies);

    let mut index = 0;

    while (index < length) {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        if (&strategy.external_key == external_key) {
            return true
        };

        index = index + 1;
    };

    false
}

fun find_strategy_index(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let length =
        vector::length(&engine.strategies);

    let mut index = 0;

    while (index < length) {
        let strategy =
            vector::borrow(
                &engine.strategies,
                index,
            );

        if (strategy.strategy_id == strategy_id) {
            return index
        };

        index = index + 1;
    };

    abort E_STRATEGY_NOT_FOUND
}

fun strategy_outstanding(
    strategy: &YieldStrategy,
): u64 {
    strategy.total_allocated
        - strategy.total_returned
        - strategy.recognized_loss
}

public fun engine_id(
    engine: &TreasuryYieldEngine,
): ID {
    object::uid_to_inner(&engine.id)
}

public fun version(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.version
}

public fun is_paused(
    engine: &TreasuryYieldEngine,
): bool {
    engine.paused
}

public fun idle_balance(
    engine: &TreasuryYieldEngine,
): u64 {
    balance::value(&engine.funds)
}

public fun strategy_count(
    engine: &TreasuryYieldEngine,
): u64 {
    vector::length(&engine.strategies)
}

public fun total_funded(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.total_funded
}

public fun total_allocated(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.total_allocated
}

public fun total_returned(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.total_returned
}

public fun gross_yield(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.gross_yield
}

public fun recognized_loss(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.recognized_loss
}

public fun outstanding_principal(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.total_allocated
        - engine.total_returned
        - engine.recognized_loss
}

public fun strategy_id_at(
    engine: &TreasuryYieldEngine,
    index: u64,
): u64 {
    vector::borrow(
        &engine.strategies,
        index,
    ).strategy_id
}

public fun strategy_external_key(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): &vector<u8> {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    &vector::borrow(
        &engine.strategies,
        index,
    ).external_key
}

public fun strategy_is_active(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): bool {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).active
}

public fun strategy_allocation_limit(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).allocation_limit
}

public fun strategy_total_allocated(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).total_allocated
}

public fun strategy_total_returned(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).total_returned
}

public fun strategy_gross_yield(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).gross_yield
}

public fun strategy_recognized_loss(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).recognized_loss
}

public fun strategy_outstanding_principal(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    strategy_outstanding(
        vector::borrow(
            &engine.strategies,
            index,
        ),
    )
}

public fun funding_count(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.funding_count
}

public fun allocation_count(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.allocation_count
}

public fun return_count(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.return_count
}

public fun yield_record_count(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.yield_record_count
}

public fun loss_record_count(
    engine: &TreasuryYieldEngine,
): u64 {
    engine.loss_record_count
}

public fun strategy_allocation_count(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).allocation_count
}

public fun strategy_return_count(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).return_count
}

public fun strategy_yield_record_count(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).yield_record_count
}

public fun strategy_loss_record_count(
    engine: &TreasuryYieldEngine,
    strategy_id: u64,
): u64 {
    let index =
        find_strategy_index(
            engine,
            strategy_id,
        );

    vector::borrow(
        &engine.strategies,
        index,
    ).loss_record_count
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): YieldEngineAdminCap {
    YieldEngineAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): TreasuryYieldEngine {
    TreasuryYieldEngine {
        id: object::new(ctx),

        version: 1,
        paused: false,

        funds: balance::zero<SUI>(),

        strategies:
            vector::empty<YieldStrategy>(),

        next_strategy_id: 1,

        total_funded: 0,
        total_allocated: 0,
        total_returned: 0,

        gross_yield: 0,
        recognized_loss: 0,

        funding_count: 0,
        allocation_count: 0,
        return_count: 0,
        yield_record_count: 0,
        loss_record_count: 0,
    }
}

#[test_only]
public fun drain_for_testing(
    engine: &mut TreasuryYieldEngine,
    ctx: &mut TxContext,
): Coin<SUI> {
    let amount =
        balance::value(&engine.funds);

    let drained =
        balance::split(
            &mut engine.funds,
            amount,
        );

    coin::from_balance(
        drained,
        ctx,
    )
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: YieldEngineAdminCap,
) {
    let YieldEngineAdminCap { id } =
        cap;

    object::delete(id);
}

#[test_only]
public fun destroy_empty_for_testing(
    engine: TreasuryYieldEngine,
) {
    let TreasuryYieldEngine {
        id,
        version: _,
        paused: _,
        funds,
        mut strategies,
        next_strategy_id: _,
        total_funded: _,
        total_allocated: _,
        total_returned: _,
        gross_yield: _,
        recognized_loss: _,
        funding_count: _,
        allocation_count: _,
        return_count: _,
        yield_record_count: _,
        loss_record_count: _,
    } = engine;

    balance::destroy_zero(funds);

    while (!vector::is_empty(&strategies)) {
        let YieldStrategy {
            strategy_id: _,
            external_key: _,
            active: _,
            allocation_limit: _,
            total_allocated: _,
            total_returned: _,
            gross_yield: _,
            recognized_loss: _,
            allocation_count: _,
            return_count: _,
            yield_record_count: _,
            loss_record_count: _,
        } = vector::pop_back(
            &mut strategies,
        );
    };

    vector::destroy_empty(strategies);

    object::delete(id);
}
