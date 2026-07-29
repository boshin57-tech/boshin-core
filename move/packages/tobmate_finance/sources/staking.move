module tobmate_finance::staking;

use sui::event;
use sui::balance::{Self as balance, Balance};
use sui::coin::{Self as coin, Coin};
use sui::sui::SUI;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

/* ============================================================
   Stage 8A
   Protocol Staking Registry & Position Foundation
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;

const BPS_DENOMINATOR: u64 = 10_000;

const E_NOT_ADMIN: u64 = 1;
const E_PAUSED: u64 = 2;
const E_INVALID_VERSION: u64 = 3;
const E_ZERO_VALUE: u64 = 4;
const E_INVALID_REWARD_RATE: u64 = 5;
const E_POOL_NOT_FOUND: u64 = 6;
const E_POOL_INACTIVE: u64 = 7;
const E_POSITION_NOT_FOUND: u64 = 8;
const E_POSITION_INACTIVE: u64 = 9;
const E_NOT_POSITION_OWNER: u64 = 10;
const E_STATE_UNCHANGED: u64 = 11;
const E_UNSTAKE_NOT_REQUESTED: u64 = 12;
const E_COOLDOWN_ACTIVE: u64 = 13;



/* ============================================================
   Registry
   ============================================================ */

public struct StakingRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_pool_id: u64,
    next_position_id: u64,

    pools: vector<StakingPool>,
    positions: vector<StakePosition>,

    principal_custody: Balance<SUI>,

    total_principal_staked: u64,
    total_positions_created: u64,
    active_position_count: u64,

    total_reward_accrued: u64,
    total_reward_pending: u64,
    total_reward_claimed: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct StakingAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Pool Configuration
   ============================================================ */

public struct StakingPool has store, drop {
    pool_id: u64,

    name: vector<u8>,

    reward_rate_bps: u64,

    minimum_stake: u64,

    lock_epochs: u64,
    cooldown_epochs: u64,

    active: bool,

    total_principal_staked: u64,
    position_count: u64,
}


/* ============================================================
   Stake Position
   ============================================================ */

public struct StakePosition has store, drop {
    position_id: u64,
    pool_id: u64,

    owner: address,

    principal: u64,

    pending_reward: u64,
    total_reward_accrued: u64,
    total_reward_claimed: u64,

    reward_position_linked: bool,
    reward_position_id: u64,
    last_reward_accrual_epoch: u64,

    active: bool,

    unstake_requested: bool,
    unstake_request_epoch: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct StakingRegistryCreated has copy, drop {
    registry_id: ID,
    administrator: address,
}

public struct StakingPoolRegistered has copy, drop {
    registry_id: ID,
    pool_id: u64,
    reward_rate_bps: u64,
    minimum_stake: u64,
    lock_epochs: u64,
    cooldown_epochs: u64,
}

public struct StakingPoolStateChanged has copy, drop {
    registry_id: ID,
    pool_id: u64,
    active: bool,
}

public struct StakingPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
}

public struct StakingVersionChanged has copy, drop {
    registry_id: ID,
    old_version: u64,
    new_version: u64,
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
        StakingRegistry {
            id: object::new(ctx),

            version: PROTOCOL_VERSION,
            paused: false,

            next_pool_id: 1,
            next_position_id: 1,

            pools: vector[],
            positions: vector[],

            principal_custody:
                balance::zero<SUI>(),

            total_principal_staked: 0,
            total_positions_created: 0,
            active_position_count: 0,

            total_reward_accrued: 0,
            total_reward_pending: 0,
            total_reward_claimed: 0,
        };

    let registry_id =
        object::id(&registry);

    let admin_cap =
        StakingAdminCap {
            id: object::new(ctx),
            registry_id,
        };

    event::emit(
        StakingRegistryCreated {
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
   Pool Registration
   ============================================================ */

public fun register_pool(
    access: &AccessControl,
    registry: &mut StakingRegistry,
    admin_cap: &StakingAdminCap,

    name: vector<u8>,
    reward_rate_bps: u64,
    minimum_stake: u64,
    lock_epochs: u64,
    cooldown_epochs: u64,

    _ctx: &mut TxContext,
): u64 {
    assert_admin(
        registry,
        admin_cap,
    );

    assert_operational(
        access,
        registry,
    );

    assert!(
        minimum_stake > 0,
        E_ZERO_VALUE,
    );

    assert!(
        reward_rate_bps <= BPS_DENOMINATOR,
        E_INVALID_REWARD_RATE,
    );

    let pool_id =
        registry.next_pool_id;

    registry.next_pool_id =
        pool_id + 1;

    vector::push_back(
        &mut registry.pools,
        StakingPool {
            pool_id,

            name,

            reward_rate_bps,

            minimum_stake,

            lock_epochs,
            cooldown_epochs,

            active: false,

            total_principal_staked: 0,
            position_count: 0,
        },
    );

    event::emit(
        StakingPoolRegistered {
            registry_id:
                object::id(registry),

            pool_id,

            reward_rate_bps,
            minimum_stake,
            lock_epochs,
            cooldown_epochs,
        },
    );

    pool_id
}


/* ============================================================
   Pool Administration
   ============================================================ */

public fun set_pool_active(
    access: &AccessControl,
    registry: &mut StakingRegistry,
    admin_cap: &StakingAdminCap,
    pool_id: u64,
    active: bool,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert_operational(
        access,
        registry,
    );

    let index =
        find_pool_index(
            registry,
            pool_id,
        );

    let pool =
        vector::borrow_mut(
            &mut registry.pools,
            index,
        );

    assert!(
        pool.active != active,
        E_STATE_UNCHANGED,
    );

    pool.active = active;

    event::emit(
        StakingPoolStateChanged {
            registry_id:
                object::id(registry),

            pool_id,
            active,
        },
    );
}


/* ============================================================
   Administration
   ============================================================ */

public fun set_paused(
    registry: &mut StakingRegistry,
    admin_cap: &StakingAdminCap,
    paused: bool,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        registry.paused != paused,
        E_STATE_UNCHANGED,
    );

    registry.paused = paused;

    event::emit(
        StakingPauseChanged {
            registry_id:
                object::id(registry),

            paused,
        },
    );
}

public fun set_version(
    registry: &mut StakingRegistry,
    admin_cap: &StakingAdminCap,
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

    let old_version =
        registry.version;

    registry.version =
        new_version;

    event::emit(
        StakingVersionChanged {
            registry_id:
                object::id(registry),

            old_version,
            new_version,
        },
    );
}


/* ============================================================
   Operational Guard
   ============================================================ */

public fun assert_operational(
    access: &AccessControl,
    registry: &StakingRegistry,
) {
    access_control::assert_not_paused(
        access,
    );

    assert!(
        !registry.paused,
        E_PAUSED,
    );
}


/* ============================================================
   Internal Helpers
   ============================================================ */

fun assert_admin(
    registry: &StakingRegistry,
    admin_cap: &StakingAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_NOT_ADMIN,
    );
}

fun find_pool_index(
    registry: &StakingRegistry,
    pool_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.pools,
        );

    let mut i = 0;

    while (i < length) {
        if (
            vector::borrow(
                &registry.pools,
                i,
            ).pool_id
                == pool_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_POOL_NOT_FOUND
}

fun find_position_index(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.positions,
        );

    let mut i = 0;

    while (i < length) {
        if (
            vector::borrow(
                &registry.positions,
                i,
            ).position_id
                == position_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_POSITION_NOT_FOUND
}


/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &StakingRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &StakingRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &StakingRegistry,
): bool {
    registry.paused
}

public(package) fun pool_count(
    registry: &StakingRegistry,
): u64 {
    vector::length(
        &registry.pools,
    )
}

public(package) fun position_count(
    registry: &StakingRegistry,
): u64 {
    vector::length(
        &registry.positions,
    )
}

public(package) fun total_principal_staked(
    registry: &StakingRegistry,
): u64 {
    registry.total_principal_staked
}

public fun total_positions_created(
    registry: &StakingRegistry,
): u64 {
    registry.total_positions_created
}

public fun active_position_count(
    registry: &StakingRegistry,
): u64 {
    registry.active_position_count
}

public(package) fun pool_is_active(
    registry: &StakingRegistry,
    pool_id: u64,
): bool {
    let index =
        find_pool_index(
            registry,
            pool_id,
        );

    vector::borrow(
        &registry.pools,
        index,
    ).active
}

public(package) fun pool_reward_rate_bps(
    registry: &StakingRegistry,
    pool_id: u64,
): u64 {
    let index =
        find_pool_index(
            registry,
            pool_id,
        );

    vector::borrow(
        &registry.pools,
        index,
    ).reward_rate_bps
}

public fun pool_minimum_stake(
    registry: &StakingRegistry,
    pool_id: u64,
): u64 {
    let index =
        find_pool_index(
            registry,
            pool_id,
        );

    vector::borrow(
        &registry.pools,
        index,
    ).minimum_stake
}

public fun pool_lock_epochs(
    registry: &StakingRegistry,
    pool_id: u64,
): u64 {
    let index =
        find_pool_index(
            registry,
            pool_id,
        );

    vector::borrow(
        &registry.pools,
        index,
    ).lock_epochs
}

public fun pool_cooldown_epochs(
    registry: &StakingRegistry,
    pool_id: u64,
): u64 {
    let index =
        find_pool_index(
            registry,
            pool_id,
        );

    vector::borrow(
        &registry.pools,
        index,
    ).cooldown_epochs
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun new_admin_cap_for_testing(
    registry: &StakingRegistry,
    ctx: &mut TxContext,
): StakingAdminCap {
    StakingAdminCap {
        id: object::new(ctx),
        registry_id: object::id(registry),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): StakingRegistry {
    StakingRegistry {
        id: object::new(ctx),

        version: PROTOCOL_VERSION,
        paused: false,

        next_pool_id: 1,
        next_position_id: 1,

        pools: vector[],
        positions: vector[],

        principal_custody:
            balance::zero<SUI>(),

        total_principal_staked: 0,
        total_positions_created: 0,
        active_position_count: 0,

        total_reward_accrued: 0,
        total_reward_claimed: 0,
        total_reward_pending: 0,
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: StakingAdminCap,
) {
    let StakingAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    registry: StakingRegistry,
) {
    let StakingRegistry {
        id,
        version: _,
        paused: _,
        next_pool_id: _,
        next_position_id: _,
        pools: _,
        positions: _,
        principal_custody,
        total_principal_staked: _,
        total_positions_created: _,
        active_position_count: _,
        total_reward_accrued: _,
        total_reward_pending: _,
        total_reward_claimed: _,
    } = registry;

    balance::destroy_zero(
        principal_custody,
    );

    object::delete(id);
}


/* ============================================================
   Stage 8B
   Stake Principal
   ============================================================ */

public fun stake(
    access: &AccessControl,
    registry: &mut StakingRegistry,
    pool_id: u64,
    principal: Coin<SUI>,
    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    let amount =
        coin::value(
            &principal,
        );

    assert!(
        amount > 0,
        E_ZERO_VALUE,
    );

    let pool_index =
        find_pool_index(
            registry,
            pool_id,
        );

    let minimum_stake;
    let pool_active;

    {
        let pool =
            vector::borrow(
                &registry.pools,
                pool_index,
            );

        minimum_stake =
            pool.minimum_stake;

        pool_active =
            pool.active;
    };

    assert!(
        pool_active,
        E_POOL_INACTIVE,
    );

    assert!(
        amount >= minimum_stake,
        E_ZERO_VALUE,
    );

    let owner =
        tx_context::sender(ctx);

    let position_id =
        registry.next_position_id;

    registry.next_position_id =
        position_id + 1;

    balance::join(
        &mut registry.principal_custody,
        coin::into_balance(principal),
    );

    vector::push_back(
        &mut registry.positions,
        StakePosition {
            position_id,
            pool_id,

            owner,

            principal:
                amount,

            pending_reward:
                0,

            total_reward_accrued:
                0,

            total_reward_claimed:
                0,

            reward_position_linked:
                false,

            reward_position_id:
                0,

            last_reward_accrual_epoch:
                tx_context::epoch(ctx),

            active:
                true,

            unstake_requested:
                false,

            unstake_request_epoch:
                0,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    {
        let pool =
            vector::borrow_mut(
                &mut registry.pools,
                pool_index,
            );

        pool.total_principal_staked =
            pool.total_principal_staked
                + amount;

        pool.position_count =
            pool.position_count + 1;
    };

    registry.total_principal_staked =
        registry.total_principal_staked
            + amount;

    registry.total_positions_created =
        registry.total_positions_created + 1;

    registry.active_position_count =
        registry.active_position_count + 1;

    position_id
}


/* ============================================================
   Stage 8B
   Principal Accounting
   ============================================================ */

public(package) fun principal_custody_balance(
    registry: &StakingRegistry,
): u64 {
    balance::value(
        &registry.principal_custody,
    )
}

public(package) fun position_owner(
    registry: &StakingRegistry,
    position_id: u64,
): address {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    vector::borrow(
        &registry.positions,
        index,
    ).owner
}

public(package) fun position_pool_id(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    vector::borrow(
        &registry.positions,
        index,
    ).pool_id
}

public fun position_principal(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    vector::borrow(
        &registry.positions,
        index,
    ).principal
}

public(package) fun position_is_active(
    registry: &StakingRegistry,
    position_id: u64,
): bool {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    vector::borrow(
        &registry.positions,
        index,
    ).active
}

public(package) fun assert_principal_accounting_invariant(
    registry: &StakingRegistry,
) {
    assert!(
        balance::value(
            &registry.principal_custody,
        )
            == registry.total_principal_staked,
        E_ZERO_VALUE,
    );
}


/* ============================================================
   Stage 8B
   Unstake Principal
   ============================================================ */

public fun unstake(
    access: &AccessControl,
    registry: &mut StakingRegistry,
    position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert_operational(
        access,
        registry,
    );

    assert!(
        amount > 0,
        E_ZERO_VALUE,
    );

    let position_index =
        find_position_index(
            registry,
            position_id,
        );

    let pool_id;
    let owner;
    let principal_before;
    let created_epoch;

    {
        let position =
            vector::borrow(
                &registry.positions,
                position_index,
            );

        assert!(
            position.active,
            E_POSITION_INACTIVE,
        );

        owner =
            position.owner;

        assert!(
            owner == tx_context::sender(ctx),
            E_NOT_POSITION_OWNER,
        );

        assert!(
            position.principal >= amount,
            E_ZERO_VALUE,
        );

        pool_id =
            position.pool_id;

        principal_before =
            position.principal;

        created_epoch =
            position.created_epoch;
    };

    let pool_index =
        find_pool_index(
            registry,
            pool_id,
        );

    let lock_epochs;
    let cooldown_epochs;

    {
        let pool =
            vector::borrow(
                &registry.pools,
                pool_index,
            );

        lock_epochs =
            pool.lock_epochs;

        cooldown_epochs =
            pool.cooldown_epochs;
    };

    assert!(
        tx_context::epoch(ctx)
            >= created_epoch + lock_epochs,
        E_POSITION_INACTIVE,
    );

    let unstake_requested;
    let unstake_request_epoch;

    {
        let position =
            vector::borrow(
                &registry.positions,
                position_index,
            );

        unstake_requested =
            position.unstake_requested;

        unstake_request_epoch =
            position.unstake_request_epoch;
    };

    if (cooldown_epochs > 0) {
        assert!(
            unstake_requested,
            E_UNSTAKE_NOT_REQUESTED,
        );

        assert!(
            tx_context::epoch(ctx)
                >= unstake_request_epoch
                    + cooldown_epochs,
            E_COOLDOWN_ACTIVE,
        );
    };

    let principal_after =
        principal_before - amount;

    {
        let position =
            vector::borrow_mut(
                &mut registry.positions,
                position_index,
            );

        position.principal =
            principal_after;

        position.updated_epoch =
            tx_context::epoch(ctx);

        if (principal_after == 0) {
            position.active = false;
        };
    };

    {
        let pool =
            vector::borrow_mut(
                &mut registry.pools,
                pool_index,
            );

        pool.total_principal_staked =
            pool.total_principal_staked
                - amount;

        if (principal_after == 0) {
            pool.position_count =
                pool.position_count - 1;
        };
    };

    registry.total_principal_staked =
        registry.total_principal_staked
            - amount;

    if (principal_after == 0) {
        registry.active_position_count =
            registry.active_position_count - 1;
    };

    let withdrawn_balance =
        balance::split(
            &mut registry.principal_custody,
            amount,
        );

    assert_principal_accounting_invariant(
        registry,
    );

    coin::from_balance(
        withdrawn_balance,
        ctx,
    )
}


/* ============================================================
   Stage 8B
   Unstake Cooldown Request
   ============================================================ */

public fun request_unstake(
    access: &AccessControl,
    registry: &mut StakingRegistry,
    position_id: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    let index =
        find_position_index(
            registry,
            position_id,
        );

    let position =
        vector::borrow_mut(
            &mut registry.positions,
            index,
        );

    assert!(
        position.active,
        E_POSITION_INACTIVE,
    );

    assert!(
        position.owner
            == tx_context::sender(ctx),
        E_NOT_POSITION_OWNER,
    );

    assert!(
        !position.unstake_requested,
        E_STATE_UNCHANGED,
    );

    position.unstake_requested =
        true;

    position.unstake_request_epoch =
        tx_context::epoch(ctx);

    position.updated_epoch =
        tx_context::epoch(ctx);
}


/* ============================================================
   Cooldown Read API
   ============================================================ */

public fun position_unstake_requested(
    registry: &StakingRegistry,
    position_id: u64,
): bool {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    vector::borrow(
        &registry.positions,
        index,
    ).unstake_requested
}

public fun position_unstake_request_epoch(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    vector::borrow(
        &registry.positions,
        index,
    ).unstake_request_epoch
}


/* ============================================================
   Stage 8C Part 2
   Reward Accounting Views
   ============================================================ */

public(package) fun total_reward_accrued(
    registry: &StakingRegistry,
): u64 {
    registry.total_reward_accrued
}

public(package) fun total_reward_pending(
    registry: &StakingRegistry,
): u64 {
    registry.total_reward_pending
}

public(package) fun total_reward_claimed(
    registry: &StakingRegistry,
): u64 {
    registry.total_reward_claimed
}

public fun position_pending_reward(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index = find_position_index(registry, position_id);
    vector::borrow(&registry.positions, index).pending_reward
}

public fun position_total_reward_accrued(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index = find_position_index(registry, position_id);
    vector::borrow(&registry.positions, index).total_reward_accrued
}

public fun position_total_reward_claimed(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index = find_position_index(registry, position_id);
    vector::borrow(&registry.positions, index).total_reward_claimed
}

public fun position_reward_position_linked(
    registry: &StakingRegistry,
    position_id: u64,
): bool {
    let index = find_position_index(registry, position_id);
    vector::borrow(&registry.positions, index).reward_position_linked
}

public(package) fun position_reward_position_id(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index = find_position_index(registry, position_id);
    vector::borrow(&registry.positions, index).reward_position_id
}

public fun position_last_reward_accrual_epoch(
    registry: &StakingRegistry,
    position_id: u64,
): u64 {
    let index = find_position_index(registry, position_id);
    vector::borrow(&registry.positions, index).last_reward_accrual_epoch
}


/* ============================================================
   Stage 8C
   Reward Integration — Package Internal API
   ============================================================ */

public(package) fun link_reward_position(
    registry: &mut StakingRegistry,
    position_id: u64,
    reward_position_id: u64,
    ctx: &TxContext,
) {
    let index =
        find_position_index(
            registry,
            position_id,
        );

    let position =
        vector::borrow_mut(
            &mut registry.positions,
            index,
        );

    assert!(
        position.active,
        E_POSITION_INACTIVE,
    );

    assert!(
        !position.reward_position_linked,
        E_STATE_UNCHANGED,
    );

    position.reward_position_linked =
        true;

    position.reward_position_id =
        reward_position_id;

    position.last_reward_accrual_epoch =
        tx_context::epoch(ctx);

    position.updated_epoch =
        tx_context::epoch(ctx);
}


public(package) fun record_reward_accrual(
    registry: &mut StakingRegistry,
    position_id: u64,
    amount: u64,
    ctx: &TxContext,
) {
    assert!(
        amount > 0,
        E_ZERO_VALUE,
    );

    let index =
        find_position_index(
            registry,
            position_id,
        );

    let position =
        vector::borrow_mut(
            &mut registry.positions,
            index,
        );

    assert!(
        position.active,
        E_POSITION_INACTIVE,
    );

    assert!(
        position.reward_position_linked,
        E_POSITION_NOT_FOUND,
    );

    position.pending_reward =
        position.pending_reward + amount;

    position.total_reward_accrued =
        position.total_reward_accrued + amount;

    position.last_reward_accrual_epoch =
        tx_context::epoch(ctx);

    position.updated_epoch =
        tx_context::epoch(ctx);

    registry.total_reward_accrued =
        registry.total_reward_accrued + amount;

    registry.total_reward_pending =
        registry.total_reward_pending + amount;

    assert_reward_accounting_invariant(
        registry,
    );
}


public(package) fun record_reward_claim(
    registry: &mut StakingRegistry,
    position_id: u64,
    amount: u64,
    ctx: &TxContext,
) {
    assert!(
        amount > 0,
        E_ZERO_VALUE,
    );

    let index =
        find_position_index(
            registry,
            position_id,
        );

    let position =
        vector::borrow_mut(
            &mut registry.positions,
            index,
        );

    assert!(
        position.pending_reward >= amount,
        E_ZERO_VALUE,
    );

    position.pending_reward =
        position.pending_reward - amount;

    position.total_reward_claimed =
        position.total_reward_claimed + amount;

    position.updated_epoch =
        tx_context::epoch(ctx);

    registry.total_reward_pending =
        registry.total_reward_pending - amount;

    registry.total_reward_claimed =
        registry.total_reward_claimed + amount;

    assert_reward_accounting_invariant(
        registry,
    );
}


/* ============================================================
   Reward Accounting Invariant
   ============================================================ */

public fun assert_reward_accounting_invariant(
    registry: &StakingRegistry,
) {
    assert!(
        registry.total_reward_accrued
            == registry.total_reward_pending
                + registry.total_reward_claimed,
        E_ZERO_VALUE,
    );
}
