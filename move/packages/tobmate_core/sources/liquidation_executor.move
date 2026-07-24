module tobmate_core::liquidation_executor;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::liquidation_engine;

use tobmate_core::access_control::AccessControl;

use tobmate_core::collateral_manager::{
    Self as collateral_manager,
    CollateralManager,
    CollateralManagerAdminCap,
};

use tobmate_core::lending_pool::{
    Self as lending_pool,
    LendingPool,
};

use tobmate_core::oracle_price_router::{
    Self as oracle_price_router,
    PriceQuote,
};

use sui::coin::{Self as coin, Coin};
use sui::sui::SUI;

/* ============================================================
   TOBMATE Blockchain
   Stage 6D-2 — Liquidation Execution Engine
   Part 3/4 — Core State + Execution Records
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

const E_NOT_ADMIN: u64 = 1;
const E_EXECUTOR_PAUSED: u64 = 2;
const E_INVALID_VERSION: u64 = 3;
const E_ZERO_AMOUNT: u64 = 4;
const E_POSITION_LINK_MISMATCH: u64 = 6;
const E_POSITION_INACTIVE: u64 = 7;
const E_POSITION_NOT_LIQUIDATABLE: u64 = 8;
const E_REPAY_MISMATCH: u64 = 9;
const E_POLICY_ENGINE_MISMATCH: u64 = 10;

/* ============================================================
   Executor State
   ============================================================ */

public struct LiquidationExecutor has key {
    id: UID,

    version: u64,
    paused: bool,

    next_execution_id: u64,

    total_executions: u64,
    total_repaid_principal: u64,
    total_collateral_seized: u64,

    executions: vector<LiquidationExecution>,
}

/* ============================================================
   Administration Capability
   ============================================================ */

public struct LiquidationExecutorAdminCap has key, store {
    id: UID,
    executor_id: ID,
}

/* ============================================================
   Execution Record
   ============================================================ */

public struct LiquidationExecution has store {
    execution_id: u64,

    borrow_position_id: u64,
    collateral_position_id: u64,

    borrower: address,
    liquidator: address,

    repay_amount: u64,
    collateral_seized: u64,

    debt_before: u64,
    debt_after: u64,

    collateral_before: u64,
    collateral_after: u64,

    health_factor_bps: u64,

    executed_epoch: u64,
}


/* ============================================================
   Liquidator Collateral Claim
   ============================================================ */

public struct LiquidatorClaim has key, store {
    id: UID,

    execution_id: u64,
    collateral_position_id: u64,

    liquidator: address,
    seized_units: u64,

    claimed: bool,
    created_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct LiquidationExecutorCreated has copy, drop {
    executor_id: ID,
    administrator: address,
}

public struct LiquidationExecutorPauseChanged has copy, drop {
    executor_id: ID,
    paused: bool,
}

public struct LiquidationExecuted has copy, drop {
    executor_id: ID,

    execution_id: u64,

    borrow_position_id: u64,
    collateral_position_id: u64,

    borrower: address,
    liquidator: address,

    repay_amount: u64,
    collateral_seized: u64,

    debt_after: u64,
    collateral_after: u64,
}


public struct LiquidatorClaimCreated has copy, drop {
    executor_id: ID,
    execution_id: u64,
    collateral_position_id: u64,
    liquidator: address,
    seized_units: u64,
}


/* ============================================================
   Initialization
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
) {
    let administrator =
        tx_context::sender(ctx);

    let executor =
        LiquidationExecutor {
            id: object::new(ctx),

            version: PROTOCOL_VERSION,
            paused: false,

            next_execution_id: 1,

            total_executions: 0,
            total_repaid_principal: 0,
            total_collateral_seized: 0,

            executions: vector[],
        };

    let executor_id =
        object::id(&executor);

    let admin_cap =
        LiquidationExecutorAdminCap {
            id: object::new(ctx),
            executor_id,
        };

    event::emit(
        LiquidationExecutorCreated {
            executor_id,
            administrator,
        },
    );

    transfer::share_object(executor);

    transfer::public_transfer(
        admin_cap,
        administrator,
    );
}

/* ============================================================
   Administration
   ============================================================ */

public fun set_paused(
    executor: &mut LiquidationExecutor,
    admin_cap: &LiquidationExecutorAdminCap,
    paused: bool,
) {
    assert_admin(
        executor,
        admin_cap,
    );

    executor.paused = paused;

    event::emit(
        LiquidationExecutorPauseChanged {
            executor_id:
                object::id(executor),

            paused,
        },
    );
}

public fun set_version(
    executor: &mut LiquidationExecutor,
    admin_cap: &LiquidationExecutorAdminCap,
    new_version: u64,
) {
    assert_admin(
        executor,
        admin_cap,
    );

    assert!(
        new_version > executor.version,
        E_INVALID_VERSION,
    );

    executor.version =
        new_version;
}

/* ============================================================
   Internal Guards
   ============================================================ */

fun assert_admin(
    executor: &LiquidationExecutor,
    admin_cap: &LiquidationExecutorAdminCap,
) {
    assert!(
        admin_cap.executor_id
            == object::id(executor),
        E_NOT_ADMIN,
    );
}

fun assert_operational(
    executor: &LiquidationExecutor,
) {
    assert!(
        !executor.paused,
        E_EXECUTOR_PAUSED,
    );
}

/* ============================================================
   Read API
   ============================================================ */

public fun executor_id(
    executor: &LiquidationExecutor,
): ID {
    object::id(executor)
}

public fun version(
    executor: &LiquidationExecutor,
): u64 {
    executor.version
}

public fun is_paused(
    executor: &LiquidationExecutor,
): bool {
    executor.paused
}

public fun next_execution_id(
    executor: &LiquidationExecutor,
): u64 {
    executor.next_execution_id
}

public fun total_executions(
    executor: &LiquidationExecutor,
): u64 {
    executor.total_executions
}

public fun total_repaid_principal(
    executor: &LiquidationExecutor,
): u64 {
    executor.total_repaid_principal
}

public fun total_collateral_seized(
    executor: &LiquidationExecutor,
): u64 {
    executor.total_collateral_seized
}

public fun execution_count(
    executor: &LiquidationExecutor,
): u64 {
    vector::length(
        &executor.executions,
    )
}

/* ============================================================
   Stage 6D-2
   Atomic Liquidation Execution
   ============================================================ */

public fun execute_liquidation(
    executor: &mut LiquidationExecutor,
    engine: &mut liquidation_engine::LiquidationEngine,

    collateral_admin_cap: &CollateralManagerAdminCap,
    access: &AccessControl,

    pool: &mut LendingPool,
    collateral_manager: &mut CollateralManager,

    borrow_position_id: u64,
    collateral_position_id: u64,

    payment: Coin<SUI>,
    quote: &PriceQuote,

    ctx: &mut TxContext,
) {
    assert_operational(executor);

    let repay_amount =
        coin::value(&payment);

    assert!(
        repay_amount > 0,
        E_ZERO_AMOUNT,
    );

    /* --------------------------------------------------------
       Borrow ↔ Collateral linkage
       -------------------------------------------------------- */

    assert!(
        lending_pool::borrow_position_is_active(
            pool,
            borrow_position_id,
        ),
        E_POSITION_INACTIVE,
    );

    assert!(
        collateral_manager::position_is_active(
            collateral_manager,
            collateral_position_id,
        ),
        E_POSITION_INACTIVE,
    );

    let linked_collateral_id =
        lending_pool::borrow_position_collateral_id(
            pool,
            borrow_position_id,
        );

    assert!(
        linked_collateral_id
            == collateral_position_id,
        E_POSITION_LINK_MISMATCH,
    );

    let borrower =
        lending_pool::borrow_position_owner(
            pool,
            borrow_position_id,
        );

    assert!(
        collateral_manager::position_owner(
            collateral_manager,
            collateral_position_id,
        ) == borrower,
        E_POSITION_LINK_MISMATCH,
    );

    /* --------------------------------------------------------
       Snapshot before mutation
       -------------------------------------------------------- */

    let debt_before =
        lending_pool::borrow_position_principal_debt(
            pool,
            borrow_position_id,
        );

    let collateral_before =
        collateral_manager::position_collateral_units(
            collateral_manager,
            collateral_position_id,
        );

    let policy_id =
        collateral_manager::position_policy_id(
            collateral_manager,
            collateral_position_id,
        );

    let threshold_bps =
        collateral_manager::policy_liquidation_threshold_bps(
            collateral_manager,
            policy_id,
        );

    let bonus_bps =
        collateral_manager::policy_liquidation_bonus_bps(
            collateral_manager,
            policy_id,
        );

    /*
       Risk parameters must not silently diverge between
       CollateralManager and LiquidationEngine.
    */

    assert!(
        threshold_bps
            == liquidation_engine::liquidation_threshold_bps(
                engine,
            ),
        E_POLICY_ENGINE_MISMATCH,
    );

    assert!(
        bonus_bps
            == liquidation_engine::liquidation_bonus_bps(
                engine,
            ),
        E_POLICY_ENGINE_MISMATCH,
    );

    /* --------------------------------------------------------
       Canonical quote / liquidation eligibility
       -------------------------------------------------------- */

    assert!(
        collateral_manager::is_position_liquidatable_with_quote(
            collateral_manager,
            collateral_position_id,
            quote,
        ),
        E_POSITION_NOT_LIQUIDATABLE,
    );

    let health_factor_bps =
        collateral_manager::liquidation_health_factor_bps_with_quote(
            collateral_manager,
            collateral_position_id,
            quote,
        );

    assert!(
        health_factor_bps < 10_000,
        E_POSITION_NOT_LIQUIDATABLE,
    );

    /* --------------------------------------------------------
       Close Factor
       -------------------------------------------------------- */

    let max_repay =
        liquidation_engine::calculate_max_repay(
            debt_before,
            liquidation_engine::close_factor_bps(
                engine,
            ),
        );

    assert!(
        repay_amount <= max_repay,
        E_REPAY_MISMATCH,
    );

    assert!(
        repay_amount <= debt_before,
        E_REPAY_MISMATCH,
    );

    /* --------------------------------------------------------
       Seize calculation.

       CollateralManager defines collateral value as:

       collateral_units * price / 10^asset_decimals

       Debt is denominated in the same value unit used by
       LendingPool principal accounting.

       Therefore:

       seize_units =
           repay_value
           * 10^asset_decimals
           * (1 + bonus)
           / collateral_price
       -------------------------------------------------------- */

    let asset_decimals =
        collateral_manager::policy_asset_decimals(
            collateral_manager,
            policy_id,
        );

    let collateral_price =
        oracle_price_router::quote_price(
            quote,
        );

    let mut asset_scale: u64 = 1;
    let mut decimal_i: u8 = 0;

    while (decimal_i < asset_decimals) {
        asset_scale = asset_scale * 10;
        decimal_i = decimal_i + 1;
    };

    let seize_numerator =
        (repay_amount as u128)
            * (asset_scale as u128)
            * (
                (
                    10_000
                        + bonus_bps
                ) as u128
            );

    let seize_denominator =
        (collateral_price as u128)
            * 10_000u128;

    let seize_amount =
        (seize_numerator
            / seize_denominator) as u64;

    assert!(
        seize_amount > 0,
        E_ZERO_AMOUNT,
    );

    assert!(
        seize_amount <= collateral_before,
        E_REPAY_MISMATCH,
    );

    /* --------------------------------------------------------
       Atomic mutation #1
       Repay borrower principal using liquidator funds.
       -------------------------------------------------------- */

    let debt_after =
        lending_pool::repay_for_liquidation(
            collateral_admin_cap,
            access,
            pool,
            collateral_manager,
            borrow_position_id,
            payment,
            quote,
            ctx,
        );

    /* --------------------------------------------------------
       Atomic mutation #2
       Seize borrower collateral accounting.
       -------------------------------------------------------- */

    let collateral_after =
        collateral_manager::seize_collateral_after_liquidation_validation(
            collateral_admin_cap,
            access,
            collateral_manager,
            collateral_position_id,
            seize_amount,
            quote,
            ctx,
        );

    /* --------------------------------------------------------
       Accounting invariants
       -------------------------------------------------------- */

    assert!(
        debt_before - debt_after
            == repay_amount,
        E_REPAY_MISMATCH,
    );

    assert!(
        collateral_before - collateral_after
            == seize_amount,
        E_REPAY_MISMATCH,
    );

    /* --------------------------------------------------------
       Execution record
       -------------------------------------------------------- */

    let execution_id =
        executor.next_execution_id;

    executor.next_execution_id =
        execution_id + 1;

    let liquidator =
        tx_context::sender(ctx);

    vector::push_back(
        &mut executor.executions,
        LiquidationExecution {
            execution_id,

            borrow_position_id,
            collateral_position_id,

            borrower,
            liquidator,

            repay_amount,
            collateral_seized:
                seize_amount,

            debt_before,
            debt_after,

            collateral_before,
            collateral_after,

            health_factor_bps,

            executed_epoch:
                tx_context::epoch(ctx),
        },
    );

    executor.total_executions =
        executor.total_executions + 1;

    executor.total_repaid_principal =
        executor.total_repaid_principal
            + repay_amount;

    executor.total_collateral_seized =
        executor.total_collateral_seized
            + seize_amount;

    let claim =
        LiquidatorClaim {
            id: object::new(ctx),

            execution_id,
            collateral_position_id,

            liquidator,
            seized_units:
                seize_amount,

            claimed: false,

            created_epoch:
                tx_context::epoch(ctx),
        };

    transfer::public_transfer(
        claim,
        liquidator,
    );

    event::emit(
        LiquidatorClaimCreated {
            executor_id:
                object::id(executor),

            execution_id,
            collateral_position_id,

            liquidator,

            seized_units:
                seize_amount,
        },
    );

    event::emit(
        LiquidationExecuted {
            executor_id:
                object::id(executor),

            execution_id,

            borrow_position_id,
            collateral_position_id,

            borrower,
            liquidator,

            repay_amount,

            collateral_seized:
                seize_amount,

            debt_after,
            collateral_after,
        },
    );
}

/* ============================================================
   Stage 6D-2
   Execution Record Read API
   ============================================================ */

public fun execution_borrow_position_id(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).borrow_position_id
}

public fun execution_collateral_position_id(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).collateral_position_id
}

public fun execution_borrower(
    executor: &LiquidationExecutor,
    index: u64,
): address {
    vector::borrow(
        &executor.executions,
        index,
    ).borrower
}

public fun execution_liquidator(
    executor: &LiquidationExecutor,
    index: u64,
): address {
    vector::borrow(
        &executor.executions,
        index,
    ).liquidator
}

public fun execution_repay_amount(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).repay_amount
}

public fun execution_collateral_seized(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).collateral_seized
}

public fun execution_debt_before(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).debt_before
}

public fun execution_debt_after(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).debt_after
}

public fun execution_collateral_before(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).collateral_before
}

public fun execution_collateral_after(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).collateral_after
}

public fun execution_health_factor_bps(
    executor: &LiquidationExecutor,
    index: u64,
): u64 {
    vector::borrow(
        &executor.executions,
        index,
    ).health_factor_bps
}

/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): LiquidationExecutor {
    LiquidationExecutor {
        id: object::new(ctx),

        version: PROTOCOL_VERSION,
        paused: false,

        next_execution_id: 1,

        total_executions: 0,
        total_repaid_principal: 0,
        total_collateral_seized: 0,

        executions: vector[],
    }
}

#[test_only]
public fun admin_cap_for_testing(
    executor: &LiquidationExecutor,
    ctx: &mut TxContext,
): LiquidationExecutorAdminCap {
    LiquidationExecutorAdminCap {
        id: object::new(ctx),
        executor_id: object::id(executor),
    }
}

#[test_only]
public fun destroy_for_testing(
    executor: LiquidationExecutor,
) {
    let LiquidationExecutor {
        id,
        version: _,
        paused: _,
        next_execution_id: _,
        total_executions: _,
        total_repaid_principal: _,
        total_collateral_seized: _,
        mut executions,
    } = executor;

    while (!vector::is_empty(&executions)) {
        let execution =
            vector::pop_back(
                &mut executions,
            );

        let LiquidationExecution {
            execution_id: _,
            borrow_position_id: _,
            collateral_position_id: _,
            borrower: _,
            liquidator: _,
            repay_amount: _,
            collateral_seized: _,
            debt_before: _,
            debt_after: _,
            collateral_before: _,
            collateral_after: _,
            health_factor_bps: _,
            executed_epoch: _,
        } = execution;
    };

    vector::destroy_empty(executions);

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: LiquidationExecutorAdminCap,
) {
    let LiquidationExecutorAdminCap {
        id,
        executor_id: _,
    } = cap;

    object::delete(id);
}

/* ============================================================
   Liquidator Claim Read API
   ============================================================ */

public fun claim_execution_id(
    claim: &LiquidatorClaim,
): u64 {
    claim.execution_id
}

public fun claim_collateral_position_id(
    claim: &LiquidatorClaim,
): u64 {
    claim.collateral_position_id
}

public fun claim_liquidator(
    claim: &LiquidatorClaim,
): address {
    claim.liquidator
}

public fun claim_seized_units(
    claim: &LiquidatorClaim,
): u64 {
    claim.seized_units
}

public fun claim_is_claimed(
    claim: &LiquidatorClaim,
): bool {
    claim.claimed
}

#[test_only]
public fun destroy_claim_for_testing(
    claim: LiquidatorClaim,
) {
    let LiquidatorClaim {
        id,
        execution_id: _,
        collateral_position_id: _,
        liquidator: _,
        seized_units: _,
        claimed: _,
        created_epoch: _,
    } = claim;

    object::delete(id);
}
