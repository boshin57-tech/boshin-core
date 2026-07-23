module tobmate_core::revenue_router;

use sui::balance::{Self, Balance};
use sui::coin;
use sui::event;
use sui::object::{Self, ID, UID};
use sui::sui::SUI;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::fee_vault::{
    Self as fee_vault,
    FeeCollectorCap,
    FeeVault,
};

use tobmate_core::treasury::{
    Self as treasury,
    ProtocolTreasury,
};

const BPS_DENOMINATOR: u64 = 10_000;

const E_ROUTER_PAUSED: u64 = 1;
const E_INVALID_BPS_TOTAL: u64 = 2;
const E_STATE_UNCHANGED: u64 = 3;
const E_VERSION_UNCHANGED: u64 = 4;
const E_NO_PENDING_FEES: u64 = 5;
const E_ACCOUNTING_INVARIANT: u64 = 6;

public struct RevenueRouterAdminCap has key, store {
    id: UID,
}

public struct RevenueRouter has key {
    id: UID,
    version: u64,
    paused: bool,

    treasury_bps: u64,
    insurance_bps: u64,
    lp_reward_bps: u64,
    reserve_operation_bps: u64,
    dao_bps: u64,

    insurance_funds: Balance<SUI>,
    lp_reward_funds: Balance<SUI>,
    reserve_operation_funds: Balance<SUI>,
    dao_funds: Balance<SUI>,

    total_routed: u64,
    total_to_treasury: u64,
    total_to_insurance: u64,
    total_to_lp_rewards: u64,
    total_to_reserve_operations: u64,
    total_to_dao: u64,

    routing_count: u64,
    last_routing_epoch: u64,
}

public struct RevenueRouted has copy, drop {
    router_id: ID,
    fee_vault_id: ID,
    treasury_id: ID,

    total_amount: u64,
    treasury_amount: u64,
    insurance_amount: u64,
    lp_reward_amount: u64,
    reserve_operation_amount: u64,
    dao_amount: u64,

    routed_by: address,
    epoch: u64,
}

public struct RevenueDistributionUpdated has copy, drop {
    router_id: ID,

    treasury_bps: u64,
    insurance_bps: u64,
    lp_reward_bps: u64,
    reserve_operation_bps: u64,
    dao_bps: u64,

    changed_by: address,
}

public struct RevenueRouterPauseStateChanged has copy, drop {
    router_id: ID,
    paused: bool,
    changed_by: address,
}

public struct RevenueRouterVersionChanged has copy, drop {
    router_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        RevenueRouterAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        RevenueRouter {
            id: object::new(ctx),
            version: 1,
            paused: false,

            treasury_bps: 3_000,
            insurance_bps: 2_000,
            lp_reward_bps: 2_500,
            reserve_operation_bps: 1_500,
            dao_bps: 1_000,

            insurance_funds: balance::zero<SUI>(),
            lp_reward_funds: balance::zero<SUI>(),
            reserve_operation_funds: balance::zero<SUI>(),
            dao_funds: balance::zero<SUI>(),

            total_routed: 0,
            total_to_treasury: 0,
            total_to_insurance: 0,
            total_to_lp_rewards: 0,
            total_to_reserve_operations: 0,
            total_to_dao: 0,

            routing_count: 0,
            last_routing_epoch: 0,
        },
    );
}

public fun route_all_pending_fees(
    collector_cap: &FeeCollectorCap,
    access_control: &AccessControl,
    fee_vault: &mut FeeVault,
    protocol_treasury: &mut ProtocolTreasury,
    router: &mut RevenueRouter,
    ctx: &mut TxContext,
) {
    assert_operational(access_control, router);

    let pending = fee_vault::pending_balance(fee_vault);
    assert!(pending > 0, E_NO_PENDING_FEES);

    let released_coin = fee_vault::release_all(
        collector_cap,
        access_control,
        fee_vault,
        ctx,
    );

    let total_amount = coin::value(&released_coin);
    let mut source_balance = coin::into_balance(released_coin);

    let treasury_amount =
        total_amount * router.treasury_bps / BPS_DENOMINATOR;

    let insurance_amount =
        total_amount * router.insurance_bps / BPS_DENOMINATOR;

    let lp_reward_amount =
        total_amount * router.lp_reward_bps / BPS_DENOMINATOR;

    let reserve_operation_amount =
        total_amount
            * router.reserve_operation_bps
            / BPS_DENOMINATOR;

    let allocated_before_dao =
        treasury_amount
            + insurance_amount
            + lp_reward_amount
            + reserve_operation_amount;

    let dao_amount =
        total_amount - allocated_before_dao;

    if (treasury_amount > 0) {
        let treasury_balance =
            balance::split(
                &mut source_balance,
                treasury_amount,
            );

        let treasury_coin =
            coin::from_balance(treasury_balance, ctx);

        treasury::deposit(
            access_control,
            protocol_treasury,
            treasury_coin,
            ctx,
        );
    };

    if (insurance_amount > 0) {
        let insurance_balance =
            balance::split(
                &mut source_balance,
                insurance_amount,
            );

        balance::join(
            &mut router.insurance_funds,
            insurance_balance,
        );
    };

    if (lp_reward_amount > 0) {
        let lp_reward_balance =
            balance::split(
                &mut source_balance,
                lp_reward_amount,
            );

        balance::join(
            &mut router.lp_reward_funds,
            lp_reward_balance,
        );
    };

    if (reserve_operation_amount > 0) {
        let reserve_operation_balance =
            balance::split(
                &mut source_balance,
                reserve_operation_amount,
            );

        balance::join(
            &mut router.reserve_operation_funds,
            reserve_operation_balance,
        );
    };

    if (dao_amount > 0) {
        balance::join(
            &mut router.dao_funds,
            source_balance,
        );
    } else {
        balance::destroy_zero(source_balance);
    };

    router.total_routed =
        router.total_routed + total_amount;

    router.total_to_treasury =
        router.total_to_treasury + treasury_amount;

    router.total_to_insurance =
        router.total_to_insurance + insurance_amount;

    router.total_to_lp_rewards =
        router.total_to_lp_rewards + lp_reward_amount;

    router.total_to_reserve_operations =
        router.total_to_reserve_operations
            + reserve_operation_amount;

    router.total_to_dao =
        router.total_to_dao + dao_amount;

    router.routing_count =
        router.routing_count + 1;

    router.last_routing_epoch =
        tx_context::epoch(ctx);

    assert_accounting_invariant(router);

    event::emit(RevenueRouted {
        router_id: object::uid_to_inner(&router.id),
        fee_vault_id: fee_vault::vault_id(fee_vault),
        treasury_id: treasury::treasury_id(
            protocol_treasury,
        ),

        total_amount,
        treasury_amount,
        insurance_amount,
        lp_reward_amount,
        reserve_operation_amount,
        dao_amount,

        routed_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

public fun set_distribution(
    _admin_cap: &RevenueRouterAdminCap,
    router: &mut RevenueRouter,

    treasury_bps: u64,
    insurance_bps: u64,
    lp_reward_bps: u64,
    reserve_operation_bps: u64,
    dao_bps: u64,

    ctx: &mut TxContext,
) {
    assert_valid_distribution(
        treasury_bps,
        insurance_bps,
        lp_reward_bps,
        reserve_operation_bps,
        dao_bps,
    );

    router.treasury_bps = treasury_bps;
    router.insurance_bps = insurance_bps;
    router.lp_reward_bps = lp_reward_bps;
    router.reserve_operation_bps = reserve_operation_bps;
    router.dao_bps = dao_bps;

    event::emit(RevenueDistributionUpdated {
        router_id: object::uid_to_inner(&router.id),

        treasury_bps,
        insurance_bps,
        lp_reward_bps,
        reserve_operation_bps,
        dao_bps,

        changed_by: tx_context::sender(ctx),
    });
}

public fun set_paused(
    _admin_cap: &RevenueRouterAdminCap,
    router: &mut RevenueRouter,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(router.paused != paused, E_STATE_UNCHANGED);

    router.paused = paused;

    event::emit(RevenueRouterPauseStateChanged {
        router_id: object::uid_to_inner(&router.id),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}

public fun set_version(
    _admin_cap: &RevenueRouterAdminCap,
    router: &mut RevenueRouter,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version = router.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    router.version = new_version;

    event::emit(RevenueRouterVersionChanged {
        router_id: object::uid_to_inner(&router.id),
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

public fun assert_valid_distribution(
    treasury_bps: u64,
    insurance_bps: u64,
    lp_reward_bps: u64,
    reserve_operation_bps: u64,
    dao_bps: u64,
) {
    assert!(
        treasury_bps
            + insurance_bps
            + lp_reward_bps
            + reserve_operation_bps
            + dao_bps
            == BPS_DENOMINATOR,
        E_INVALID_BPS_TOTAL,
    );
}

public fun assert_operational(
    access_control: &AccessControl,
    router: &RevenueRouter,
) {
    access_control::assert_not_paused(access_control);
    assert!(!router.paused, E_ROUTER_PAUSED);
}

public fun assert_accounting_invariant(
    router: &RevenueRouter,
) {
    assert!(
        router.total_routed
            == router.total_to_treasury
                + router.total_to_insurance
                + router.total_to_lp_rewards
                + router.total_to_reserve_operations
                + router.total_to_dao,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&router.insurance_funds)
            == router.total_to_insurance,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&router.lp_reward_funds)
            == router.total_to_lp_rewards,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(
            &router.reserve_operation_funds,
        ) == router.total_to_reserve_operations,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&router.dao_funds)
            == router.total_to_dao,
        E_ACCOUNTING_INVARIANT,
    );
}

public fun router_id(router: &RevenueRouter): ID {
    object::uid_to_inner(&router.id)
}

public fun version(router: &RevenueRouter): u64 {
    router.version
}

public fun is_paused(router: &RevenueRouter): bool {
    router.paused
}

public fun basis_point_denominator(): u64 {
    BPS_DENOMINATOR
}

public fun treasury_bps(router: &RevenueRouter): u64 {
    router.treasury_bps
}

public fun insurance_bps(router: &RevenueRouter): u64 {
    router.insurance_bps
}

public fun lp_reward_bps(router: &RevenueRouter): u64 {
    router.lp_reward_bps
}

public fun reserve_operation_bps(
    router: &RevenueRouter,
): u64 {
    router.reserve_operation_bps
}

public fun dao_bps(router: &RevenueRouter): u64 {
    router.dao_bps
}

public fun insurance_balance(
    router: &RevenueRouter,
): u64 {
    balance::value(&router.insurance_funds)
}

public fun lp_reward_balance(
    router: &RevenueRouter,
): u64 {
    balance::value(&router.lp_reward_funds)
}

public fun reserve_operation_balance(
    router: &RevenueRouter,
): u64 {
    balance::value(&router.reserve_operation_funds)
}

public fun dao_balance(router: &RevenueRouter): u64 {
    balance::value(&router.dao_funds)
}

public fun total_routed(router: &RevenueRouter): u64 {
    router.total_routed
}

public fun total_to_treasury(
    router: &RevenueRouter,
): u64 {
    router.total_to_treasury
}

public fun total_to_insurance(
    router: &RevenueRouter,
): u64 {
    router.total_to_insurance
}

public fun total_to_lp_rewards(
    router: &RevenueRouter,
): u64 {
    router.total_to_lp_rewards
}

public fun total_to_reserve_operations(
    router: &RevenueRouter,
): u64 {
    router.total_to_reserve_operations
}

public fun total_to_dao(
    router: &RevenueRouter,
): u64 {
    router.total_to_dao
}

public fun routing_count(
    router: &RevenueRouter,
): u64 {
    router.routing_count
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): RevenueRouterAdminCap {
    RevenueRouterAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): RevenueRouter {
    RevenueRouter {
        id: object::new(ctx),
        version: 1,
        paused: false,

        treasury_bps: 3_000,
        insurance_bps: 2_000,
        lp_reward_bps: 2_500,
        reserve_operation_bps: 1_500,
        dao_bps: 1_000,

        insurance_funds: balance::zero<SUI>(),
        lp_reward_funds: balance::zero<SUI>(),
        reserve_operation_funds: balance::zero<SUI>(),
        dao_funds: balance::zero<SUI>(),

        total_routed: 0,
        total_to_treasury: 0,
        total_to_insurance: 0,
        total_to_lp_rewards: 0,
        total_to_reserve_operations: 0,
        total_to_dao: 0,

        routing_count: 0,
        last_routing_epoch: 0,
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: RevenueRouterAdminCap,
) {
    let RevenueRouterAdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun destroy_empty_for_testing(
    router: RevenueRouter,
) {
    assert!(
        balance::value(&router.insurance_funds) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&router.lp_reward_funds) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(
            &router.reserve_operation_funds,
        ) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        balance::value(&router.dao_funds) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    let RevenueRouter {
        id,
        version: _,
        paused: _,

        treasury_bps: _,
        insurance_bps: _,
        lp_reward_bps: _,
        reserve_operation_bps: _,
        dao_bps: _,

        insurance_funds,
        lp_reward_funds,
        reserve_operation_funds,
        dao_funds,

        total_routed: _,
        total_to_treasury: _,
        total_to_insurance: _,
        total_to_lp_rewards: _,
        total_to_reserve_operations: _,
        total_to_dao: _,

        routing_count: _,
        last_routing_epoch: _,
    } = router;

    balance::destroy_zero(insurance_funds);
    balance::destroy_zero(lp_reward_funds);
    balance::destroy_zero(reserve_operation_funds);
    balance::destroy_zero(dao_funds);

    object::delete(id);
}

/// Removes every internally held destination balance for unit-test cleanup.
///
/// This function intentionally exists only in the test build. Production
/// withdrawals will be implemented through the dedicated InsuranceFund,
/// RewardDistributor, ReserveOperations and DAO Treasury modules.
#[test_only]
public fun drain_all_for_testing(
    router: &mut RevenueRouter,
    ctx: &mut TxContext,
): (
    coin::Coin<SUI>,
    coin::Coin<SUI>,
    coin::Coin<SUI>,
    coin::Coin<SUI>,
) {
    let insurance =
        balance::withdraw_all(
            &mut router.insurance_funds,
        );

    let lp_rewards =
        balance::withdraw_all(
            &mut router.lp_reward_funds,
        );

    let reserve_operations =
        balance::withdraw_all(
            &mut router.reserve_operation_funds,
        );

    let dao =
        balance::withdraw_all(
            &mut router.dao_funds,
        );

    (
        coin::from_balance(insurance, ctx),
        coin::from_balance(lp_rewards, ctx),
        coin::from_balance(reserve_operations, ctx),
        coin::from_balance(dao, ctx),
    )
}
