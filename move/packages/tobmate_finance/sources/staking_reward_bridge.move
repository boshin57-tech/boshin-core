module tobmate_finance::staking_reward_bridge;

use sui::object::ID;
use sui::tx_context::TxContext;

use tobmate_foundation::access_control::AccessControl;

use tobmate_finance::staking::{
    Self as staking,
    StakingRegistry,
};

use tobmate_finance::lp_reward_distributor::{
    Self as lp_reward_distributor,
    LPRewardAdminCap,
    LPRewardDistributor,
};


/* ============================================================
   Stage 8C Part 3
   Staking ↔ LP Reward Distributor Bridge
   ============================================================ */

const E_STAKING_POSITION_INACTIVE: u64 = 1;


/* ============================================================
   Register Staking Position Into Reward Distributor
   ============================================================ */

public fun register_staking_position(
    access: &AccessControl,
    staking_registry: &mut StakingRegistry,
    distributor: &mut LPRewardDistributor,
    reward_admin_cap: &LPRewardAdminCap,
    staking_position_id: u64,
    lp_pool_id: ID,
    external_position_ref: vector<u8>,
    liquidity_weight: u64,
    ctx: &mut TxContext,
): u64 {
    assert!(
        staking::position_is_active(
            staking_registry,
            staking_position_id,
        ),
        E_STAKING_POSITION_INACTIVE,
    );

    let owner =
        staking::position_owner(
            staking_registry,
            staking_position_id,
        );

    let reward_position_id =
        lp_reward_distributor::register_position(
            reward_admin_cap,
            access,
            distributor,
            owner,
            lp_pool_id,
            external_position_ref,
            liquidity_weight,
            ctx,
        );

    staking::link_reward_position(
        staking_registry,
        staking_position_id,
        reward_position_id,
        ctx,
    );

    reward_position_id
}


/* ============================================================
   Accrue Reward Across Distributor And Staking
   ============================================================ */

public fun accrue_staking_reward(
    access: &AccessControl,
    staking_registry: &mut StakingRegistry,
    distributor: &mut LPRewardDistributor,
    reward_admin_cap: &LPRewardAdminCap,
    staking_position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(
        staking::position_is_active(
            staking_registry,
            staking_position_id,
        ),
        E_STAKING_POSITION_INACTIVE,
    );

    assert!(
        staking::position_reward_position_linked(
            staking_registry,
            staking_position_id,
        ),
        2,
    );

    let reward_position_id =
        staking::position_reward_position_id(
            staking_registry,
            staking_position_id,
        );

    let staking_owner =
        staking::position_owner(
            staking_registry,
            staking_position_id,
        );

    let reward_owner =
        lp_reward_distributor::position_owner(
            distributor,
            reward_position_id,
        );

    assert!(
        staking_owner == reward_owner,
        3,
    );

    lp_reward_distributor::accrue_reward(
        reward_admin_cap,
        access,
        distributor,
        reward_position_id,
        amount,
        ctx,
    );

    staking::record_reward_accrual(
        staking_registry,
        staking_position_id,
        amount,
        ctx,
    );

    staking::assert_reward_accounting_invariant(
        staking_registry,
    );

    lp_reward_distributor::assert_accounting_invariant(
        distributor,
    );
}


/* ============================================================
   Claim Reward Across Distributor And Staking
   ============================================================ */

public fun claim_staking_reward(
    access: &AccessControl,
    staking_registry: &mut StakingRegistry,
    distributor: &mut LPRewardDistributor,
    staking_position_id: u64,
    ctx: &mut TxContext,
) {
    assert!(
        staking::position_reward_position_linked(
            staking_registry,
            staking_position_id,
        ),
        2,
    );

    let reward_position_id =
        staking::position_reward_position_id(
            staking_registry,
            staking_position_id,
        );

    let staking_owner =
        staking::position_owner(
            staking_registry,
            staking_position_id,
        );

    let reward_owner =
        lp_reward_distributor::position_owner(
            distributor,
            reward_position_id,
        );

    assert!(
        staking_owner == reward_owner,
        3,
    );

    let pending_reward =
        lp_reward_distributor::position_pending_reward(
            distributor,
            reward_position_id,
        );

    lp_reward_distributor::claim_reward(
        access,
        distributor,
        reward_position_id,
        ctx,
    );

    staking::record_reward_claim(
        staking_registry,
        staking_position_id,
        pending_reward,
        ctx,
    );

    staking::assert_reward_accounting_invariant(
        staking_registry,
    );

    lp_reward_distributor::assert_accounting_invariant(
        distributor,
    );
}
