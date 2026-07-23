module tobmate_core::lp_reward_distributor;

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

const E_DISTRIBUTOR_PAUSED: u64 = 1;
const E_ZERO_FUNDING: u64 = 2;
const E_ZERO_LIQUIDITY_WEIGHT: u64 = 3;
const E_POSITION_NOT_FOUND: u64 = 4;
const E_POSITION_INACTIVE: u64 = 5;
const E_ZERO_REWARD: u64 = 6;
const E_INSUFFICIENT_UNALLOCATED_REWARDS: u64 = 7;
const E_NOT_POSITION_OWNER: u64 = 8;
const E_NO_PENDING_REWARD: u64 = 9;
const E_DUPLICATE_EXTERNAL_POSITION: u64 = 10;
const E_STATE_UNCHANGED: u64 = 11;
const E_VERSION_UNCHANGED: u64 = 12;
const E_ACCOUNTING_INVARIANT: u64 = 13;

public struct LPRewardAdminCap has key, store {
    id: UID,
}

public struct LPPosition has store {
    position_id: u64,
    owner: address,
    pool_id: ID,
    external_position_ref: vector<u8>,
    liquidity_weight: u64,
    active: bool,
    total_accrued: u64,
    total_claimed: u64,
    pending_reward: u64,
    created_epoch: u64,
    last_accrual_epoch: u64,
    last_claim_epoch: u64,
}

public struct LPRewardDistributor has key {
    id: UID,
    version: u64,
    paused: bool,
    reward_funds: Balance<SUI>,
    positions: vector<LPPosition>,
    next_position_id: u64,
    total_funded: u64,
    total_accrued: u64,
    total_pending: u64,
    total_claimed: u64,
    funding_count: u64,
    accrual_count: u64,
    claim_count: u64,
}

public struct LPRewardFunded has copy, drop {
    distributor_id: ID,
    amount: u64,
    funded_by: address,
    epoch: u64,
}

public struct LPPositionRegistered has copy, drop {
    distributor_id: ID,
    position_id: u64,
    owner: address,
    pool_id: ID,
    liquidity_weight: u64,
    epoch: u64,
}

public struct LPRewardAccrued has copy, drop {
    distributor_id: ID,
    position_id: u64,
    owner: address,
    amount: u64,
    total_position_pending: u64,
    epoch: u64,
}

public struct LPRewardClaimed has copy, drop {
    distributor_id: ID,
    position_id: u64,
    owner: address,
    amount: u64,
    epoch: u64,
}

public struct LPPositionActiveStateChanged has copy, drop {
    distributor_id: ID,
    position_id: u64,
    active: bool,
    changed_by: address,
}

public struct LPPositionOwnerChanged has copy, drop {
    distributor_id: ID,
    position_id: u64,
    previous_owner: address,
    new_owner: address,
    changed_by: address,
}

public struct LPRewardDistributorPauseChanged has copy, drop {
    distributor_id: ID,
    paused: bool,
    changed_by: address,
}

public struct LPRewardDistributorVersionChanged has copy, drop {
    distributor_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

fun init(ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);

    transfer::transfer(
        LPRewardAdminCap {
            id: object::new(ctx),
        },
        sender,
    );

    transfer::share_object(
        LPRewardDistributor {
            id: object::new(ctx),
            version: 1,
            paused: false,
            reward_funds: balance::zero<SUI>(),
            positions: vector[],
            next_position_id: 1,
            total_funded: 0,
            total_accrued: 0,
            total_pending: 0,
            total_claimed: 0,
            funding_count: 0,
            accrual_count: 0,
            claim_count: 0,
        },
    );
}

public fun fund(
    access: &AccessControl,
    distributor: &mut LPRewardDistributor,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(access, distributor);

    let amount = coin::value(&payment);
    assert!(amount > 0, E_ZERO_FUNDING);

    balance::join(
        &mut distributor.reward_funds,
        coin::into_balance(payment),
    );

    distributor.total_funded =
        distributor.total_funded + amount;

    distributor.funding_count =
        distributor.funding_count + 1;

    assert_accounting_invariant(distributor);

    event::emit(LPRewardFunded {
        distributor_id: distributor_id(distributor),
        amount,
        funded_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

public fun register_position(
    _admin_cap: &LPRewardAdminCap,
    access: &AccessControl,
    distributor: &mut LPRewardDistributor,
    owner: address,
    pool_id: ID,
    external_position_ref: vector<u8>,
    liquidity_weight: u64,
    ctx: &mut TxContext,
): u64 {
    assert_operational(access, distributor);

    assert!(
        liquidity_weight > 0,
        E_ZERO_LIQUIDITY_WEIGHT,
    );

    assert_external_position_unique(
        distributor,
        pool_id,
        &external_position_ref,
    );

    let position_id = distributor.next_position_id;
    let epoch = tx_context::epoch(ctx);

    vector::push_back(
        &mut distributor.positions,
        LPPosition {
            position_id,
            owner,
            pool_id,
            external_position_ref,
            liquidity_weight,
            active: true,
            total_accrued: 0,
            total_claimed: 0,
            pending_reward: 0,
            created_epoch: epoch,
            last_accrual_epoch: 0,
            last_claim_epoch: 0,
        },
    );

    distributor.next_position_id =
        position_id + 1;

    event::emit(LPPositionRegistered {
        distributor_id: distributor_id(distributor),
        position_id,
        owner,
        pool_id,
        liquidity_weight,
        epoch,
    });

    position_id
}

public fun accrue_reward(
    _admin_cap: &LPRewardAdminCap,
    access: &AccessControl,
    distributor: &mut LPRewardDistributor,
    position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert_operational(access, distributor);
    assert!(amount > 0, E_ZERO_REWARD);

    let available =
        balance::value(&distributor.reward_funds)
            - distributor.total_pending;

    assert!(
        available >= amount,
        E_INSUFFICIENT_UNALLOCATED_REWARDS,
    );

    let index =
        find_position_index(distributor, position_id);

    let position =
        vector::borrow_mut(
            &mut distributor.positions,
            index,
        );

    assert!(position.active, E_POSITION_INACTIVE);

    position.pending_reward =
        position.pending_reward + amount;

    position.total_accrued =
        position.total_accrued + amount;

    position.last_accrual_epoch =
        tx_context::epoch(ctx);

    let owner = position.owner;
    let total_position_pending =
        position.pending_reward;

    distributor.total_accrued =
        distributor.total_accrued + amount;

    distributor.total_pending =
        distributor.total_pending + amount;

    distributor.accrual_count =
        distributor.accrual_count + 1;

    assert_accounting_invariant(distributor);

    event::emit(LPRewardAccrued {
        distributor_id: distributor_id(distributor),
        position_id,
        owner,
        amount,
        total_position_pending,
        epoch: tx_context::epoch(ctx),
    });
}

public fun claim_reward(
    access: &AccessControl,
    distributor: &mut LPRewardDistributor,
    position_id: u64,
    ctx: &mut TxContext,
) {
    assert_operational(access, distributor);

    let index =
        find_position_index(distributor, position_id);

    let sender = tx_context::sender(ctx);

    let (
        owner,
        pending_reward,
        active,
    ) = {
        let position =
            vector::borrow(
                &distributor.positions,
                index,
            );

        (
            position.owner,
            position.pending_reward,
            position.active,
        )
    };

    assert!(active, E_POSITION_INACTIVE);
    assert!(sender == owner, E_NOT_POSITION_OWNER);

    assert!(
        pending_reward > 0,
        E_NO_PENDING_REWARD,
    );

    let reward_balance =
        balance::split(
            &mut distributor.reward_funds,
            pending_reward,
        );

    let reward_coin =
        coin::from_balance(reward_balance, ctx);

    transfer::public_transfer(
        reward_coin,
        owner,
    );

    let position =
        vector::borrow_mut(
            &mut distributor.positions,
            index,
        );

    position.pending_reward = 0;

    position.total_claimed =
        position.total_claimed + pending_reward;

    position.last_claim_epoch =
        tx_context::epoch(ctx);

    distributor.total_pending =
        distributor.total_pending - pending_reward;

    distributor.total_claimed =
        distributor.total_claimed + pending_reward;

    distributor.claim_count =
        distributor.claim_count + 1;

    assert_accounting_invariant(distributor);

    event::emit(LPRewardClaimed {
        distributor_id: distributor_id(distributor),
        position_id,
        owner,
        amount: pending_reward,
        epoch: tx_context::epoch(ctx),
    });
}

public fun set_position_active(
    _admin_cap: &LPRewardAdminCap,
    distributor: &mut LPRewardDistributor,
    position_id: u64,
    active: bool,
    ctx: &mut TxContext,
) {
    let index =
        find_position_index(distributor, position_id);

    let position =
        vector::borrow_mut(
            &mut distributor.positions,
            index,
        );

    assert!(
        position.active != active,
        E_STATE_UNCHANGED,
    );

    position.active = active;

    event::emit(LPPositionActiveStateChanged {
        distributor_id: distributor_id(distributor),
        position_id,
        active,
        changed_by: tx_context::sender(ctx),
    });
}

public fun transfer_position_owner(
    _admin_cap: &LPRewardAdminCap,
    distributor: &mut LPRewardDistributor,
    position_id: u64,
    new_owner: address,
    ctx: &mut TxContext,
) {
    let index =
        find_position_index(distributor, position_id);

    let position =
        vector::borrow_mut(
            &mut distributor.positions,
            index,
        );

    let previous_owner = position.owner;

    assert!(
        previous_owner != new_owner,
        E_STATE_UNCHANGED,
    );

    position.owner = new_owner;

    event::emit(LPPositionOwnerChanged {
        distributor_id: distributor_id(distributor),
        position_id,
        previous_owner,
        new_owner,
        changed_by: tx_context::sender(ctx),
    });
}

public fun set_paused(
    _admin_cap: &LPRewardAdminCap,
    distributor: &mut LPRewardDistributor,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(
        distributor.paused != paused,
        E_STATE_UNCHANGED,
    );

    distributor.paused = paused;

    event::emit(LPRewardDistributorPauseChanged {
        distributor_id: distributor_id(distributor),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}

public fun set_version(
    _admin_cap: &LPRewardAdminCap,
    distributor: &mut LPRewardDistributor,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version = distributor.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    distributor.version = new_version;

    event::emit(LPRewardDistributorVersionChanged {
        distributor_id: distributor_id(distributor),
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

fun assert_external_position_unique(
    distributor: &LPRewardDistributor,
    pool_id: ID,
    external_position_ref: &vector<u8>,
) {
    let length =
        vector::length(&distributor.positions);

    let mut index = 0;

    while (index < length) {
        let position =
            vector::borrow(
                &distributor.positions,
                index,
            );

        assert!(
            !(
                position.pool_id == pool_id
                    && &position.external_position_ref
                        == external_position_ref
            ),
            E_DUPLICATE_EXTERNAL_POSITION,
        );

        index = index + 1;
    };
}

fun find_position_index(
    distributor: &LPRewardDistributor,
    position_id: u64,
): u64 {
    let length =
        vector::length(&distributor.positions);

    let mut index = 0;

    while (index < length) {
        let position =
            vector::borrow(
                &distributor.positions,
                index,
            );

        if (position.position_id == position_id) {
            return index
        };

        index = index + 1;
    };

    abort E_POSITION_NOT_FOUND
}

public fun assert_operational(
    access: &AccessControl,
    distributor: &LPRewardDistributor,
) {
    access_control::assert_not_paused(access);

    assert!(
        !distributor.paused,
        E_DISTRIBUTOR_PAUSED,
    );
}

public fun assert_accounting_invariant(
    distributor: &LPRewardDistributor,
) {
    let current_balance =
        balance::value(&distributor.reward_funds);

    assert!(
        distributor.total_funded
            == current_balance
                + distributor.total_claimed,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        distributor.total_accrued
            == distributor.total_pending
                + distributor.total_claimed,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        distributor.total_pending
            <= current_balance,
        E_ACCOUNTING_INVARIANT,
    );
}

public fun distributor_id(
    distributor: &LPRewardDistributor,
): ID {
    object::uid_to_inner(&distributor.id)
}

public fun version(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.version
}

public fun is_paused(
    distributor: &LPRewardDistributor,
): bool {
    distributor.paused
}

public fun reward_balance(
    distributor: &LPRewardDistributor,
): u64 {
    balance::value(&distributor.reward_funds)
}

public fun position_count(
    distributor: &LPRewardDistributor,
): u64 {
    vector::length(&distributor.positions)
}

public fun total_funded(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.total_funded
}

public fun total_accrued(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.total_accrued
}

public fun total_pending(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.total_pending
}

public fun total_claimed(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.total_claimed
}

public fun position_owner(
    distributor: &LPRewardDistributor,
    position_id: u64,
): address {
    let index =
        find_position_index(distributor, position_id);

    vector::borrow(
        &distributor.positions,
        index,
    ).owner
}

public fun position_pending_reward(
    distributor: &LPRewardDistributor,
    position_id: u64,
): u64 {
    let index =
        find_position_index(distributor, position_id);

    vector::borrow(
        &distributor.positions,
        index,
    ).pending_reward
}

public fun position_total_accrued(
    distributor: &LPRewardDistributor,
    position_id: u64,
): u64 {
    let index =
        find_position_index(distributor, position_id);

    vector::borrow(
        &distributor.positions,
        index,
    ).total_accrued
}

public fun position_total_claimed(
    distributor: &LPRewardDistributor,
    position_id: u64,
): u64 {
    let index =
        find_position_index(distributor, position_id);

    vector::borrow(
        &distributor.positions,
        index,
    ).total_claimed
}

#[test_only]
public fun next_position_id_for_testing(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.next_position_id
}

#[test_only]
public fun funding_count_for_testing(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.funding_count
}

#[test_only]
public fun accrual_count_for_testing(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.accrual_count
}

#[test_only]
public fun claim_count_for_testing(
    distributor: &LPRewardDistributor,
): u64 {
    distributor.claim_count
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): LPRewardAdminCap {
    LPRewardAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): LPRewardDistributor {
    LPRewardDistributor {
        id: object::new(ctx),
        version: 1,
        paused: false,
        reward_funds: balance::zero<SUI>(),
        positions: vector[],
        next_position_id: 1,
        total_funded: 0,
        total_accrued: 0,
        total_pending: 0,
        total_claimed: 0,
        funding_count: 0,
        accrual_count: 0,
        claim_count: 0,
    }
}

#[test_only]
public fun drain_for_testing(
    distributor: &mut LPRewardDistributor,
    ctx: &mut TxContext,
): Coin<SUI> {
    let funds =
        balance::withdraw_all(
            &mut distributor.reward_funds,
        );

    coin::from_balance(funds, ctx)
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: LPRewardAdminCap,
) {
    let LPRewardAdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    distributor: LPRewardDistributor,
) {
    let LPRewardDistributor {
        id,
        version: _,
        paused: _,
        reward_funds,
        mut positions,
        next_position_id: _,
        total_funded: _,
        total_accrued: _,
        total_pending: _,
        total_claimed: _,
        funding_count: _,
        accrual_count: _,
        claim_count: _,
    } = distributor;

    balance::destroy_zero(reward_funds);

    while (!vector::is_empty(&positions)) {
        let LPPosition {
            position_id: _,
            owner: _,
            pool_id: _,
            external_position_ref: _,
            liquidity_weight: _,
            active: _,
            total_accrued: _,
            total_claimed: _,
            pending_reward: _,
            created_epoch: _,
            last_accrual_epoch: _,
            last_claim_epoch: _,
        } = vector::pop_back(&mut positions);
    };

    vector::destroy_empty(positions);
    object::delete(id);
}
