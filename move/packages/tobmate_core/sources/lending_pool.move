module tobmate_core::lending_pool;

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

use tobmate_core::collateral_manager::{
    Self as collateral_manager,
    CollateralManager,
    CollateralManagerAdminCap,
};

use tobmate_core::oracle_price_router::PriceQuote;

const BPS_DENOMINATOR: u64 = 10_000;

const E_POOL_PAUSED: u64 = 1;
const E_STATE_UNCHANGED: u64 = 2;
const E_VERSION_UNCHANGED: u64 = 3;
const E_ZERO_AMOUNT: u64 = 4;
const E_INSUFFICIENT_LIQUIDITY: u64 = 5;
const E_SUPPLY_POSITION_NOT_FOUND: u64 = 6;
const E_BORROW_POSITION_NOT_FOUND: u64 = 7;
const E_NOT_POSITION_OWNER: u64 = 8;
const E_REPAY_ABOVE_DEBT: u64 = 9;
const E_WITHDRAW_ABOVE_SUPPLY: u64 = 10;
const E_INVALID_RESERVE_FACTOR: u64 = 11;
const E_INVALID_BORROW_RATE: u64 = 12;
const E_DUPLICATE_BORROW_POSITION: u64 = 13;
const E_ACCOUNTING_INVARIANT: u64 = 14;

public struct LendingAdminCap has key, store {
    id: UID,
}

public struct SupplyPosition has store {
    position_id: u64,
    owner: address,
    supplied_principal: u64,
    accrued_interest: u64,
    active: bool,
    created_epoch: u64,
    updated_epoch: u64,
}

public struct BorrowPosition has store {
    position_id: u64,
    owner: address,
    collateral_position_id: u64,
    principal_debt: u64,
    accrued_interest: u64,
    active: bool,
    created_epoch: u64,
    updated_epoch: u64,
}

public struct LendingPool has key {
    id: UID,

    version: u64,

    paused: bool,

    liquidity: Balance<SUI>,

    supply_positions: vector<SupplyPosition>,

    borrow_positions: vector<BorrowPosition>,

    next_supply_position_id: u64,

    next_borrow_position_id: u64,

    total_supplied_principal: u64,

    total_withdrawn_principal: u64,

    total_borrowed_principal: u64,

    total_repaid_principal: u64,

    total_borrow_interest_accrued: u64,

    total_borrow_interest_paid: u64,

    protocol_reserves: u64,

    reserve_factor_bps: u64,

    base_borrow_rate_bps: u64,

    supply_position_count: u64,

    borrow_position_count: u64,
}

public struct LendingPoolCreated has copy, drop {
    pool_id: ID,
    administrator: address,
    reserve_factor_bps: u64,
    base_borrow_rate_bps: u64,
}

public struct LendingPoolPauseChanged has copy, drop {
    pool_id: ID,
    paused: bool,
    changed_by: address,
}

public struct LendingPoolVersionChanged has copy, drop {
    pool_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

public struct ReserveFactorChanged has copy, drop {
    pool_id: ID,
    previous_reserve_factor_bps: u64,
    new_reserve_factor_bps: u64,
    changed_by: address,
}

public struct BaseBorrowRateChanged has copy, drop {
    pool_id: ID,
    previous_base_borrow_rate_bps: u64,
    new_base_borrow_rate_bps: u64,
    changed_by: address,
}

public struct LiquiditySupplied has copy, drop {
    pool_id: ID,
    position_id: u64,
    owner: address,
    amount: u64,
    liquidity_after: u64,
}

public struct LiquidityWithdrawn has copy, drop {
    pool_id: ID,
    position_id: u64,
    owner: address,
    amount: u64,
    liquidity_after: u64,
}

public struct PrincipalBorrowed has copy, drop {
    pool_id: ID,
    borrow_position_id: u64,
    collateral_position_id: u64,
    borrower: address,
    amount: u64,
    debt_after: u64,
}

public struct PrincipalRepaid has copy, drop {
    pool_id: ID,
    borrow_position_id: u64,
    payer: address,
    amount: u64,
    debt_after: u64,
}

fun assert_operational(
    access: &AccessControl,
    pool: &LendingPool,
) {
    access_control::assert_not_paused(access);

    assert!(
        !pool.paused,
        E_POOL_PAUSED,
    );
}

fun assert_valid_reserve_factor(
    reserve_factor_bps: u64,
) {
    assert!(
        reserve_factor_bps <= BPS_DENOMINATOR,
        E_INVALID_RESERVE_FACTOR,
    );
}

fun assert_valid_borrow_rate(
    borrow_rate_bps: u64,
) {
    assert!(
        borrow_rate_bps <= BPS_DENOMINATOR,
        E_INVALID_BORROW_RATE,
    );
}

public fun create_pool(
    reserve_factor_bps: u64,
    base_borrow_rate_bps: u64,
    ctx: &mut TxContext,
) {
    assert_valid_reserve_factor(
        reserve_factor_bps,
    );

    assert_valid_borrow_rate(
        base_borrow_rate_bps,
    );

    let administrator =
        tx_context::sender(ctx);

    let admin_cap =
        LendingAdminCap {
            id: object::new(ctx),
        };

    let pool =
        LendingPool {
            id: object::new(ctx),

            version: 1,

            paused: false,

            liquidity:
                balance::zero<SUI>(),

            supply_positions:
                vector[],

            borrow_positions:
                vector[],

            next_supply_position_id: 1,

            next_borrow_position_id: 1,

            total_supplied_principal: 0,

            total_withdrawn_principal: 0,

            total_borrowed_principal: 0,

            total_repaid_principal: 0,

            total_borrow_interest_accrued: 0,

            total_borrow_interest_paid: 0,

            protocol_reserves: 0,

            reserve_factor_bps,

            base_borrow_rate_bps,

            supply_position_count: 0,

            borrow_position_count: 0,
        };

    event::emit(LendingPoolCreated {
        pool_id:
            object::uid_to_inner(&pool.id),

        administrator,

        reserve_factor_bps,

        base_borrow_rate_bps,
    });

    transfer::public_transfer(
        admin_cap,
        administrator,
    );

    transfer::share_object(pool);
}

public fun set_paused(
    _admin_cap: &LendingAdminCap,
    pool: &mut LendingPool,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(
        pool.paused != paused,
        E_STATE_UNCHANGED,
    );

    pool.paused = paused;

    event::emit(LendingPoolPauseChanged {
        pool_id:
            object::uid_to_inner(&pool.id),

        paused,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_version(
    _admin_cap: &LendingAdminCap,
    pool: &mut LendingPool,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version =
        pool.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    pool.version =
        new_version;

    event::emit(LendingPoolVersionChanged {
        pool_id:
            object::uid_to_inner(&pool.id),

        previous_version,

        new_version,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_reserve_factor(
    _admin_cap: &LendingAdminCap,
    pool: &mut LendingPool,
    new_reserve_factor_bps: u64,
    ctx: &mut TxContext,
) {
    assert_valid_reserve_factor(
        new_reserve_factor_bps,
    );

    let previous_reserve_factor_bps =
        pool.reserve_factor_bps;

    assert!(
        previous_reserve_factor_bps
            != new_reserve_factor_bps,
        E_STATE_UNCHANGED,
    );

    pool.reserve_factor_bps =
        new_reserve_factor_bps;

    event::emit(ReserveFactorChanged {
        pool_id:
            object::uid_to_inner(&pool.id),

        previous_reserve_factor_bps,

        new_reserve_factor_bps,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_base_borrow_rate(
    _admin_cap: &LendingAdminCap,
    pool: &mut LendingPool,
    new_base_borrow_rate_bps: u64,
    ctx: &mut TxContext,
) {
    assert_valid_borrow_rate(
        new_base_borrow_rate_bps,
    );

    let previous_base_borrow_rate_bps =
        pool.base_borrow_rate_bps;

    assert!(
        previous_base_borrow_rate_bps
            != new_base_borrow_rate_bps,
        E_STATE_UNCHANGED,
    );

    pool.base_borrow_rate_bps =
        new_base_borrow_rate_bps;

    event::emit(BaseBorrowRateChanged {
        pool_id:
            object::uid_to_inner(&pool.id),

        previous_base_borrow_rate_bps,

        new_base_borrow_rate_bps,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun pool_id(
    pool: &LendingPool,
): ID {
    object::uid_to_inner(&pool.id)
}

public fun version(
    pool: &LendingPool,
): u64 {
    pool.version
}

public fun is_paused(
    pool: &LendingPool,
): bool {
    pool.paused
}

public fun available_liquidity(
    pool: &LendingPool,
): u64 {
    balance::value(&pool.liquidity)
}

public fun total_supplied_principal(
    pool: &LendingPool,
): u64 {
    pool.total_supplied_principal
}

public fun total_borrowed_principal(
    pool: &LendingPool,
): u64 {
    pool.total_borrowed_principal
}

public fun outstanding_borrow_principal(
    pool: &LendingPool,
): u64 {
    pool.total_borrowed_principal
        - pool.total_repaid_principal
}

public fun reserve_factor_bps(
    pool: &LendingPool,
): u64 {
    pool.reserve_factor_bps
}

public fun base_borrow_rate_bps(
    pool: &LendingPool,
): u64 {
    pool.base_borrow_rate_bps
}

public fun utilization_bps(
    pool: &LendingPool,
): u64 {
    let borrowed =
        outstanding_borrow_principal(pool);

    let liquidity =
        balance::value(&pool.liquidity);

    let total_assets =
        liquidity + borrowed;

    if (total_assets == 0) {
        return 0
    };

    borrowed
        * BPS_DENOMINATOR
        / total_assets
}

fun find_supply_position_index(
    pool: &LendingPool,
    position_id: u64,
): u64 {
    let length =
        vector::length(
            &pool.supply_positions,
        );

    let mut i = 0;

    while (i < length) {
        let position =
            vector::borrow(
                &pool.supply_positions,
                i,
            );

        if (position.position_id == position_id) {
            return i
        };

        i = i + 1;
    };

    abort E_SUPPLY_POSITION_NOT_FOUND
}

public fun supply(
    access: &AccessControl,
    pool: &mut LendingPool,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        pool,
    );

    let amount =
        coin::value(&payment);

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let owner =
        tx_context::sender(ctx);

    let position_id =
        pool.next_supply_position_id;

    pool.next_supply_position_id =
        position_id + 1;

    balance::join(
        &mut pool.liquidity,
        coin::into_balance(payment),
    );

    vector::push_back(
        &mut pool.supply_positions,
        SupplyPosition {
            position_id,
            owner,
            supplied_principal: amount,
            accrued_interest: 0,
            active: true,
            created_epoch:
                tx_context::epoch(ctx),
            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    pool.total_supplied_principal =
        pool.total_supplied_principal + amount;

    pool.supply_position_count =
        pool.supply_position_count + 1;

    event::emit(LiquiditySupplied {
        pool_id:
            object::uid_to_inner(&pool.id),

        position_id,

        owner,

        amount,

        liquidity_after:
            balance::value(&pool.liquidity),
    });

    position_id
}

public fun supply_position_owner(
    pool: &LendingPool,
    position_id: u64,
): address {
    let index =
        find_supply_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.supply_positions,
        index,
    ).owner
}

public fun supply_position_principal(
    pool: &LendingPool,
    position_id: u64,
): u64 {
    let index =
        find_supply_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.supply_positions,
        index,
    ).supplied_principal
}

public fun supply_position_is_active(
    pool: &LendingPool,
    position_id: u64,
): bool {
    let index =
        find_supply_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.supply_positions,
        index,
    ).active
}

public fun withdraw_supply(
    access: &AccessControl,
    pool: &mut LendingPool,
    position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert_operational(
        access,
        pool,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let index =
        find_supply_position_index(
            pool,
            position_id,
        );

    {
        let position =
            vector::borrow(
                &pool.supply_positions,
                index,
            );

        assert!(
            position.active,
            E_SUPPLY_POSITION_NOT_FOUND,
        );

        assert!(
            position.owner
                == tx_context::sender(ctx),
            E_NOT_POSITION_OWNER,
        );

        assert!(
            position.supplied_principal
                >= amount,
            E_WITHDRAW_ABOVE_SUPPLY,
        );
    };

    assert!(
        balance::value(&pool.liquidity)
            >= amount,
        E_INSUFFICIENT_LIQUIDITY,
    );

    {
        let position =
            vector::borrow_mut(
                &mut pool.supply_positions,
                index,
            );

        position.supplied_principal =
            position.supplied_principal
                - amount;

        position.updated_epoch =
            tx_context::epoch(ctx);

        if (position.supplied_principal == 0
            && position.accrued_interest == 0) {
            position.active = false;
        };
    };

    pool.total_withdrawn_principal =
        pool.total_withdrawn_principal
            + amount;

    let withdrawn_balance =
        balance::split(
            &mut pool.liquidity,
            amount,
        );

    let coin =
        coin::from_balance(
            withdrawn_balance,
            ctx,
        );

    event::emit(LiquidityWithdrawn {
        pool_id:
            object::uid_to_inner(&pool.id),

        position_id,

        owner:
            tx_context::sender(ctx),

        amount,

        liquidity_after:
            balance::value(&pool.liquidity),
    });

    coin
}

public fun net_supplied_principal(
    pool: &LendingPool,
): u64 {
    pool.total_supplied_principal
        - pool.total_withdrawn_principal
}

fun find_borrow_position_index(
    pool: &LendingPool,
    position_id: u64,
): u64 {
    let length =
        vector::length(
            &pool.borrow_positions,
        );

    let mut i = 0;

    while (i < length) {
        let position =
            vector::borrow(
                &pool.borrow_positions,
                i,
            );

        if (position.position_id == position_id) {
            return i
        };

        i = i + 1;
    };

    abort E_BORROW_POSITION_NOT_FOUND
}

fun contains_collateral_borrow_position(
    pool: &LendingPool,
    collateral_position_id: u64,
): bool {
    let length =
        vector::length(
            &pool.borrow_positions,
        );

    let mut i = 0;

    while (i < length) {
        let position =
            vector::borrow(
                &pool.borrow_positions,
                i,
            );

        if (
            position.collateral_position_id
                == collateral_position_id
            && position.active
        ) {
            return true
        };

        i = i + 1;
    };

    false
}

public fun borrow(
    lending_admin_cap: &LendingAdminCap,
    collateral_admin_cap: &CollateralManagerAdminCap,
    access: &AccessControl,
    pool: &mut LendingPool,
    collateral_manager: &mut CollateralManager,
    collateral_position_id: u64,
    amount: u64,
    quote: &PriceQuote,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert_operational(
        access,
        pool,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    assert!(
        balance::value(&pool.liquidity)
            >= amount,
        E_INSUFFICIENT_LIQUIDITY,
    );

    let borrower =
        tx_context::sender(ctx);

    assert!(
        collateral_manager::position_owner(
            collateral_manager,
            collateral_position_id,
        ) == borrower,
        E_NOT_POSITION_OWNER,
    );

    assert!(
        collateral_manager::position_is_active(
            collateral_manager,
            collateral_position_id,
        ),
        E_BORROW_POSITION_NOT_FOUND,
    );

    assert!(
        !contains_collateral_borrow_position(
            pool,
            collateral_position_id,
        ),
        E_DUPLICATE_BORROW_POSITION,
    );

    let current_debt =
        collateral_manager::position_debt_value(
            collateral_manager,
            collateral_position_id,
        );

    let new_debt =
        current_debt + amount;

    collateral_manager::set_position_debt_value_with_quote(
        collateral_admin_cap,
        access,
        collateral_manager,
        collateral_position_id,
        new_debt,
        quote,
        ctx,
    );

    let borrow_position_id =
        pool.next_borrow_position_id;

    pool.next_borrow_position_id =
        borrow_position_id + 1;

    vector::push_back(
        &mut pool.borrow_positions,
        BorrowPosition {
            position_id:
                borrow_position_id,

            owner:
                borrower,

            collateral_position_id,

            principal_debt:
                amount,

            accrued_interest:
                0,

            active:
                true,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    pool.total_borrowed_principal =
        pool.total_borrowed_principal
            + amount;

    pool.borrow_position_count =
        pool.borrow_position_count + 1;

    let borrowed_balance =
        balance::split(
            &mut pool.liquidity,
            amount,
        );

    let borrowed_coin =
        coin::from_balance(
            borrowed_balance,
            ctx,
        );

    event::emit(PrincipalBorrowed {
        pool_id:
            object::uid_to_inner(&pool.id),

        borrow_position_id,

        collateral_position_id,

        borrower,

        amount,

        debt_after:
            new_debt,
    });

    let _ = lending_admin_cap;

    borrowed_coin
}

public fun borrow_position_owner(
    pool: &LendingPool,
    position_id: u64,
): address {
    let index =
        find_borrow_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.borrow_positions,
        index,
    ).owner
}

public fun borrow_position_collateral_id(
    pool: &LendingPool,
    position_id: u64,
): u64 {
    let index =
        find_borrow_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.borrow_positions,
        index,
    ).collateral_position_id
}

public fun borrow_position_principal_debt(
    pool: &LendingPool,
    position_id: u64,
): u64 {
    let index =
        find_borrow_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.borrow_positions,
        index,
    ).principal_debt
}

public fun borrow_position_accrued_interest(
    pool: &LendingPool,
    position_id: u64,
): u64 {
    let index =
        find_borrow_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.borrow_positions,
        index,
    ).accrued_interest
}

public fun borrow_position_is_active(
    pool: &LendingPool,
    position_id: u64,
): bool {
    let index =
        find_borrow_position_index(
            pool,
            position_id,
        );

    vector::borrow(
        &pool.borrow_positions,
        index,
    ).active
}

public fun repay(
    collateral_admin_cap: &CollateralManagerAdminCap,
    access: &AccessControl,
    pool: &mut LendingPool,
    collateral_manager: &mut CollateralManager,
    borrow_position_id: u64,
    payment: Coin<SUI>,
    quote: &PriceQuote,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        pool,
    );

    let amount =
        coin::value(&payment);

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let index =
        find_borrow_position_index(
            pool,
            borrow_position_id,
        );

    let collateral_position_id;
    let current_principal;

    {
        let position =
            vector::borrow(
                &pool.borrow_positions,
                index,
            );

        assert!(
            position.active,
            E_BORROW_POSITION_NOT_FOUND,
        );

        assert!(
            position.owner
                == tx_context::sender(ctx),
            E_NOT_POSITION_OWNER,
        );

        collateral_position_id =
            position.collateral_position_id;

        current_principal =
            position.principal_debt;
    };

    assert!(
        amount <= current_principal,
        E_REPAY_ABOVE_DEBT,
    );

    balance::join(
        &mut pool.liquidity,
        coin::into_balance(payment),
    );

    let remaining_principal =
        current_principal - amount;

    {
        let position =
            vector::borrow_mut(
                &mut pool.borrow_positions,
                index,
            );

        position.principal_debt =
            remaining_principal;

        position.updated_epoch =
            tx_context::epoch(ctx);

        if (
            remaining_principal == 0
            && position.accrued_interest == 0
        ) {
            position.active = false;
        };
    };

    pool.total_repaid_principal =
        pool.total_repaid_principal + amount;

    collateral_manager::set_position_debt_value_with_quote(
        collateral_admin_cap,
        access,
        collateral_manager,
        collateral_position_id,
        remaining_principal,
        quote,
        ctx,
    );

    event::emit(PrincipalRepaid {
        pool_id:
            object::uid_to_inner(&pool.id),

        borrow_position_id,

        payer:
            tx_context::sender(ctx),

        amount,

        debt_after:
            remaining_principal,
    });
}

public fun calculate_interest(
    principal: u64,
    rate_bps: u64,
    periods: u64,
): u64 {
    principal
        * rate_bps
        * periods
        / BPS_DENOMINATOR
}

public fun accrue_borrow_interest(
    _admin_cap: &LendingAdminCap,
    pool: &mut LendingPool,
    borrow_position_id: u64,
    periods: u64,
) {
    let index =
        find_borrow_position_index(
            pool,
            borrow_position_id,
        );

    let principal;

    {
        let position =
            vector::borrow(
                &pool.borrow_positions,
                index,
            );

        assert!(
            position.active,
            E_BORROW_POSITION_NOT_FOUND,
        );

        principal =
            position.principal_debt;
    };

    let interest =
        calculate_interest(
            principal,
            pool.base_borrow_rate_bps,
            periods,
        );

    {
        let position =
            vector::borrow_mut(
                &mut pool.borrow_positions,
                index,
            );

        position.accrued_interest =
            position.accrued_interest
                + interest;
    };

    pool.total_borrow_interest_accrued =
        pool.total_borrow_interest_accrued
            + interest;
}

public fun reserve_share_from_interest(
    interest_amount: u64,
    reserve_factor_bps: u64,
): u64 {
    interest_amount
        * reserve_factor_bps
        / BPS_DENOMINATOR
}

public fun supplier_share_from_interest(
    interest_amount: u64,
    reserve_factor_bps: u64,
): u64 {
    interest_amount
        - reserve_share_from_interest(
            interest_amount,
            reserve_factor_bps,
        )
}

public struct BorrowInterestPaid has copy, drop {
    pool_id: ID,
    borrow_position_id: u64,
    payer: address,
    interest_paid: u64,
    reserve_share: u64,
    supplier_share: u64,
    remaining_interest: u64,
}

public fun repay_interest(
    access: &AccessControl,
    pool: &mut LendingPool,
    borrow_position_id: u64,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        pool,
    );

    let amount =
        coin::value(&payment);

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    let index =
        find_borrow_position_index(
            pool,
            borrow_position_id,
        );

    let accrued_interest;

    {
        let position =
            vector::borrow(
                &pool.borrow_positions,
                index,
            );

        assert!(
            position.owner
                == tx_context::sender(ctx),
            E_NOT_POSITION_OWNER,
        );

        accrued_interest =
            position.accrued_interest;
    };

    assert!(
        amount <= accrued_interest,
        E_REPAY_ABOVE_DEBT,
    );

    let reserve_share =
        reserve_share_from_interest(
            amount,
            pool.reserve_factor_bps,
        );

    let supplier_share =
        amount - reserve_share;

    balance::join(
        &mut pool.liquidity,
        coin::into_balance(payment),
    );

    {
        let position =
            vector::borrow_mut(
                &mut pool.borrow_positions,
                index,
            );

        position.accrued_interest =
            position.accrued_interest
                - amount;

        position.updated_epoch =
            tx_context::epoch(ctx);

        if (
            position.principal_debt == 0
            && position.accrued_interest == 0
        ) {
            position.active = false;
        };
    };

    pool.total_borrow_interest_paid =
        pool.total_borrow_interest_paid
            + amount;

    pool.protocol_reserves =
        pool.protocol_reserves
            + reserve_share;

    let remaining_interest =
        borrow_position_accrued_interest(
            pool,
            borrow_position_id,
        );

    event::emit(BorrowInterestPaid {
        pool_id:
            object::uid_to_inner(&pool.id),

        borrow_position_id,

        payer:
            tx_context::sender(ctx),

        interest_paid:
            amount,

        reserve_share,

        supplier_share,

        remaining_interest,
    });
}

public fun total_borrow_interest_accrued(
    pool: &LendingPool,
): u64 {
    pool.total_borrow_interest_accrued
}

public fun total_borrow_interest_paid(
    pool: &LendingPool,
): u64 {
    pool.total_borrow_interest_paid
}

public fun protocol_reserves(
    pool: &LendingPool,
): u64 {
    pool.protocol_reserves
}

public fun assert_accounting_invariant(
    pool: &LendingPool,
) {
    let outstanding =
        outstanding_borrow_principal(
            pool,
        );

    let expected_assets =
        net_supplied_principal(pool)
            + pool.total_borrow_interest_paid;

    let actual_assets =
        balance::value(&pool.liquidity)
            + outstanding;

    assert!(
        actual_assets
            == expected_assets,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        pool.protocol_reserves
            <= pool.total_borrow_interest_paid,
        E_ACCOUNTING_INVARIANT,
    );
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): LendingAdminCap {
    LendingAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    reserve_factor_bps: u64,
    base_borrow_rate_bps: u64,
    ctx: &mut TxContext,
): LendingPool {
    assert_valid_reserve_factor(
        reserve_factor_bps,
    );

    assert_valid_borrow_rate(
        base_borrow_rate_bps,
    );

    LendingPool {
        id: object::new(ctx),

        version: 1,

        paused: false,

        liquidity:
            balance::zero<SUI>(),

        supply_positions:
            vector[],

        borrow_positions:
            vector[],

        next_supply_position_id: 1,

        next_borrow_position_id: 1,

        total_supplied_principal: 0,

        total_withdrawn_principal: 0,

        total_borrowed_principal: 0,

        total_repaid_principal: 0,

        total_borrow_interest_accrued: 0,

        total_borrow_interest_paid: 0,

        protocol_reserves: 0,

        reserve_factor_bps,

        base_borrow_rate_bps,

        supply_position_count: 0,

        borrow_position_count: 0,
    }
}

#[test_only]
public fun drain_for_testing(
    pool: &mut LendingPool,
    ctx: &mut TxContext,
): Coin<SUI> {
    let amount =
        balance::value(
            &pool.liquidity,
        );

    let drained =
        balance::split(
            &mut pool.liquidity,
            amount,
        );

    coin::from_balance(
        drained,
        ctx,
    )
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: LendingAdminCap,
) {
    let LendingAdminCap { id } =
        cap;

    object::delete(id);
}

#[test_only]
public fun destroy_empty_for_testing(
    pool: LendingPool,
) {
    let LendingPool {
        id,
        version: _,
        paused: _,
        liquidity,
        mut supply_positions,
        mut borrow_positions,
        next_supply_position_id: _,
        next_borrow_position_id: _,
        total_supplied_principal: _,
        total_withdrawn_principal: _,
        total_borrowed_principal: _,
        total_repaid_principal: _,
        total_borrow_interest_accrued: _,
        total_borrow_interest_paid: _,
        protocol_reserves: _,
        reserve_factor_bps: _,
        base_borrow_rate_bps: _,
        supply_position_count: _,
        borrow_position_count: _,
    } = pool;

    balance::destroy_zero(
        liquidity,
    );

    while (!vector::is_empty(
        &supply_positions,
    )) {
        let SupplyPosition {
            position_id: _,
            owner: _,
            supplied_principal: _,
            accrued_interest: _,
            active: _,
            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut supply_positions,
        );
    };

    vector::destroy_empty(
        supply_positions,
    );

    while (!vector::is_empty(
        &borrow_positions,
    )) {
        let BorrowPosition {
            position_id: _,
            owner: _,
            collateral_position_id: _,
            principal_debt: _,
            accrued_interest: _,
            active: _,
            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut borrow_positions,
        );
    };

    vector::destroy_empty(
        borrow_positions,
    );

    object::delete(id);
}
