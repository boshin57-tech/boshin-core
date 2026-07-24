module tobmate_core::dex_fee_settlement;

use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID};
use sui::sui::SUI;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::AccessControl;

use tobmate_core::fee_vault::{
    Self as fee_vault,
    FeeCollectorCap,
    FeeVault,
};

use tobmate_core::insurance_fund::InsuranceFund;

use tobmate_core::liquidity_pool::{
    Self as liquidity_pool,
    LiquidityPool,
    LiquidityPoolAdminCap,
};

use tobmate_core::lp_reward_distributor::LPRewardDistributor;

use tobmate_core::revenue_router::{
    Self as revenue_router,
    RevenueRouter,
};

use tobmate_core::treasury::ProtocolTreasury;

/* ============================================================
   Error codes
   ============================================================ */

/// The selected pool side did not contain any SUI protocol fee.
const E_NO_SUI_PROTOCOL_FEE: u64 = 1;

/// Settlement accounting did not preserve the withdrawn value.
const E_SETTLEMENT_ACCOUNTING_INVARIANT: u64 = 2;

/* ============================================================
   Receipt and events
   ============================================================ */

/// Immutable transaction receipt returned after a successful
/// DEX protocol-fee settlement.
///
/// The receipt records:
/// - the underlying LiquidityPool object;
/// - the FeeVault receiving the SUI fee;
/// - which side of the pool contained SUI;
/// - SUI settled into FeeVault;
/// - non-SUI protocol fees returned to the caller.
public struct DexFeeSettlementReceipt has copy, drop, store {
    pool_id: ID,
    fee_vault_id: ID,

    /// True when SUI is pool type X.
    sui_is_x: bool,

    sui_amount: u64,
    non_sui_amount: u64,

    fee_vault_pending_before: u64,
    fee_vault_pending_after: u64,

    settled_by: address,
    settlement_epoch: u64,
}

/// Emitted whenever DEX protocol fees enter FeeVault.
public struct DexProtocolFeesSettled has copy, drop {
    pool_id: ID,
    fee_vault_id: ID,

    sui_is_x: bool,

    sui_amount: u64,
    non_sui_amount: u64,

    fee_vault_pending_before: u64,
    fee_vault_pending_after: u64,

    settled_by: address,
    settlement_epoch: u64,
}

/// Emitted after settled FeeVault funds have been distributed
/// through RevenueRouter.
public struct DexProtocolFeesRouted has copy, drop {
    pool_id: ID,
    fee_vault_id: ID,

    routed_amount: u64,

    settled_by: address,
    routing_epoch: u64,
}

/* ============================================================
   SUI-X settlement
   ============================================================ */

/// Withdraws protocol fees from LiquidityPool<SUI, X>.
///
/// The SUI fee is deposited into FeeVault under the liquidity-fee
/// category. Any protocol fee denominated in X is returned to the
/// caller and must be consumed or transferred in the same PTB.
///
/// Aborts when the pool contains no pending SUI protocol fee.
public fun settle_sui_x_protocol_fees<X>(
    access_control: &AccessControl,
    pool_admin_cap: &LiquidityPoolAdminCap,
    pool: &mut LiquidityPool<SUI, X>,
    fee_vault: &mut FeeVault,
    ctx: &mut TxContext,
): (
    Coin<X>,
    DexFeeSettlementReceipt,
) {
    let pool_id = object::id(pool);
    let fee_vault_id = fee_vault::vault_id(fee_vault);

    let pending_before =
        fee_vault::pending_balance(fee_vault);

    let (
        sui_fee,
        non_sui_fee,
    ) = liquidity_pool::withdraw_protocol_fees(
        pool_admin_cap,
        pool,
        ctx,
    );

    let sui_amount = coin::value(&sui_fee);
    let non_sui_amount = coin::value(&non_sui_fee);

    assert!(
        sui_amount > 0,
        E_NO_SUI_PROTOCOL_FEE,
    );

    fee_vault::collect_fee(
        access_control,
        fee_vault,
        fee_vault::fee_liquidity(),
        sui_fee,
        ctx,
    );

    let pending_after =
        fee_vault::pending_balance(fee_vault);

    assert!(
        pending_after
            == pending_before + sui_amount,
        E_SETTLEMENT_ACCOUNTING_INVARIANT,
    );

    let receipt = DexFeeSettlementReceipt {
        pool_id,
        fee_vault_id,
        sui_is_x: true,
        sui_amount,
        non_sui_amount,
        fee_vault_pending_before: pending_before,
        fee_vault_pending_after: pending_after,
        settled_by: tx_context::sender(ctx),
        settlement_epoch: tx_context::epoch(ctx),
    };

    event::emit(DexProtocolFeesSettled {
        pool_id,
        fee_vault_id,
        sui_is_x: true,
        sui_amount,
        non_sui_amount,
        fee_vault_pending_before: pending_before,
        fee_vault_pending_after: pending_after,
        settled_by: tx_context::sender(ctx),
        settlement_epoch: tx_context::epoch(ctx),
    });

    (
        non_sui_fee,
        receipt,
    )
}

/* ============================================================
   X-SUI settlement
   ============================================================ */

/// Withdraws protocol fees from LiquidityPool<X, SUI>.
///
/// The SUI fee is deposited into FeeVault under the liquidity-fee
/// category. Any protocol fee denominated in X is returned to the
/// caller.
///
/// Aborts when the pool contains no pending SUI protocol fee.
public fun settle_x_sui_protocol_fees<X>(
    access_control: &AccessControl,
    pool_admin_cap: &LiquidityPoolAdminCap,
    pool: &mut LiquidityPool<X, SUI>,
    fee_vault: &mut FeeVault,
    ctx: &mut TxContext,
): (
    Coin<X>,
    DexFeeSettlementReceipt,
) {
    let pool_id = object::id(pool);
    let fee_vault_id = fee_vault::vault_id(fee_vault);

    let pending_before =
        fee_vault::pending_balance(fee_vault);

    let (
        non_sui_fee,
        sui_fee,
    ) = liquidity_pool::withdraw_protocol_fees(
        pool_admin_cap,
        pool,
        ctx,
    );

    let sui_amount = coin::value(&sui_fee);
    let non_sui_amount = coin::value(&non_sui_fee);

    assert!(
        sui_amount > 0,
        E_NO_SUI_PROTOCOL_FEE,
    );

    fee_vault::collect_fee(
        access_control,
        fee_vault,
        fee_vault::fee_liquidity(),
        sui_fee,
        ctx,
    );

    let pending_after =
        fee_vault::pending_balance(fee_vault);

    assert!(
        pending_after
            == pending_before + sui_amount,
        E_SETTLEMENT_ACCOUNTING_INVARIANT,
    );

    let receipt = DexFeeSettlementReceipt {
        pool_id,
        fee_vault_id,
        sui_is_x: false,
        sui_amount,
        non_sui_amount,
        fee_vault_pending_before: pending_before,
        fee_vault_pending_after: pending_after,
        settled_by: tx_context::sender(ctx),
        settlement_epoch: tx_context::epoch(ctx),
    };

    event::emit(DexProtocolFeesSettled {
        pool_id,
        fee_vault_id,
        sui_is_x: false,
        sui_amount,
        non_sui_amount,
        fee_vault_pending_before: pending_before,
        fee_vault_pending_after: pending_after,
        settled_by: tx_context::sender(ctx),
        settlement_epoch: tx_context::epoch(ctx),
    });

    (
        non_sui_fee,
        receipt,
    )
}

/* ============================================================
   Settlement + RevenueRouter integration
   ============================================================ */

/// Settles the SUI side of LiquidityPool<SUI, X>, then immediately
/// distributes all FeeVault pending funds through RevenueRouter.
///
/// Note that RevenueRouter routes the entire pending FeeVault
/// balance, including fees collected by other protocol modules.
public fun settle_and_route_sui_x_protocol_fees<X>(
    access_control: &AccessControl,
    pool_admin_cap: &LiquidityPoolAdminCap,
    collector_cap: &FeeCollectorCap,

    pool: &mut LiquidityPool<SUI, X>,
    fee_vault: &mut FeeVault,

    protocol_treasury: &mut ProtocolTreasury,
    insurance_fund: &mut InsuranceFund,
    lp_reward_distributor: &mut LPRewardDistributor,
    revenue_router: &mut RevenueRouter,

    ctx: &mut TxContext,
): (
    Coin<X>,
    DexFeeSettlementReceipt,
) {
    let (
        non_sui_fee,
        receipt,
    ) = settle_sui_x_protocol_fees(
        access_control,
        pool_admin_cap,
        pool,
        fee_vault,
        ctx,
    );

    let routed_amount =
        fee_vault::pending_balance(fee_vault);

    revenue_router::route_all_pending_fees(
        collector_cap,
        access_control,
        fee_vault,
        protocol_treasury,
        insurance_fund,
        lp_reward_distributor,
        revenue_router,
        ctx,
    );

    assert!(
        fee_vault::pending_balance(fee_vault) == 0,
        E_SETTLEMENT_ACCOUNTING_INVARIANT,
    );

    event::emit(DexProtocolFeesRouted {
        pool_id: receipt.pool_id,
        fee_vault_id: receipt.fee_vault_id,
        routed_amount,
        settled_by: tx_context::sender(ctx),
        routing_epoch: tx_context::epoch(ctx),
    });

    (
        non_sui_fee,
        receipt,
    )
}

/// Settles the SUI side of LiquidityPool<X, SUI>, then immediately
/// distributes all FeeVault pending funds through RevenueRouter.
public fun settle_and_route_x_sui_protocol_fees<X>(
    access_control: &AccessControl,
    pool_admin_cap: &LiquidityPoolAdminCap,
    collector_cap: &FeeCollectorCap,

    pool: &mut LiquidityPool<X, SUI>,
    fee_vault: &mut FeeVault,

    protocol_treasury: &mut ProtocolTreasury,
    insurance_fund: &mut InsuranceFund,
    lp_reward_distributor: &mut LPRewardDistributor,
    revenue_router: &mut RevenueRouter,

    ctx: &mut TxContext,
): (
    Coin<X>,
    DexFeeSettlementReceipt,
) {
    let (
        non_sui_fee,
        receipt,
    ) = settle_x_sui_protocol_fees(
        access_control,
        pool_admin_cap,
        pool,
        fee_vault,
        ctx,
    );

    let routed_amount =
        fee_vault::pending_balance(fee_vault);

    revenue_router::route_all_pending_fees(
        collector_cap,
        access_control,
        fee_vault,
        protocol_treasury,
        insurance_fund,
        lp_reward_distributor,
        revenue_router,
        ctx,
    );

    assert!(
        fee_vault::pending_balance(fee_vault) == 0,
        E_SETTLEMENT_ACCOUNTING_INVARIANT,
    );

    event::emit(DexProtocolFeesRouted {
        pool_id: receipt.pool_id,
        fee_vault_id: receipt.fee_vault_id,
        routed_amount,
        settled_by: tx_context::sender(ctx),
        routing_epoch: tx_context::epoch(ctx),
    });

    (
        non_sui_fee,
        receipt,
    )
}

/* ============================================================
   Receipt read APIs
   ============================================================ */

public fun receipt_pool_id(
    receipt: &DexFeeSettlementReceipt,
): ID {
    receipt.pool_id
}

public fun receipt_fee_vault_id(
    receipt: &DexFeeSettlementReceipt,
): ID {
    receipt.fee_vault_id
}

public fun receipt_sui_is_x(
    receipt: &DexFeeSettlementReceipt,
): bool {
    receipt.sui_is_x
}

public fun receipt_sui_amount(
    receipt: &DexFeeSettlementReceipt,
): u64 {
    receipt.sui_amount
}

public fun receipt_non_sui_amount(
    receipt: &DexFeeSettlementReceipt,
): u64 {
    receipt.non_sui_amount
}

public fun receipt_pending_before(
    receipt: &DexFeeSettlementReceipt,
): u64 {
    receipt.fee_vault_pending_before
}

public fun receipt_pending_after(
    receipt: &DexFeeSettlementReceipt,
): u64 {
    receipt.fee_vault_pending_after
}

public fun receipt_settled_by(
    receipt: &DexFeeSettlementReceipt,
): address {
    receipt.settled_by
}

public fun receipt_settlement_epoch(
    receipt: &DexFeeSettlementReceipt,
): u64 {
    receipt.settlement_epoch
}
