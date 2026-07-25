module tobmate_core::risk_controller;

use sui::coin::Coin;
use sui::sui::SUI;
use sui::tx_context::TxContext;

use tobmate_core::access_control::AccessControl;

use tobmate_core::collateral_manager::{
    Self as collateral_manager,
    CollateralManager,
    CollateralManagerAdminCap,
};

use tobmate_core::lending_pool::{
    Self as lending_pool,
    LendingAdminCap,
    LendingPool,
};

use tobmate_core::oracle_price_router::PriceQuote;

use tobmate_core::recovery_mode::{
    Self as recovery_mode,
    RecoveryModeRegistry,
};


/* ============================================================
   Stage 7J
   Recovery Mode Enforcement Controller

   Risk-increasing operations MUST pass through this controller
   before mutating Lending or Collateral state.
   ============================================================ */


/* ============================================================
   Guarded Borrow

   Borrowing increases protocol credit exposure and therefore
   must be blocked while Recovery Mode is active.
   ============================================================ */

public fun borrow(
    recovery_registry: &RecoveryModeRegistry,
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
    recovery_mode::assert_risk_increase_allowed(
        recovery_registry,
    );

    lending_pool::borrow(
        lending_admin_cap,
        collateral_admin_cap,
        access,
        pool,
        collateral_manager,
        collateral_position_id,
        amount,
        quote,
        ctx,
    )
}


/* ============================================================
   Guarded Collateral Withdrawal — Legacy / Debt-Free Path

   Any collateral withdrawal reduces protocol protection and is
   treated as a risk-increasing operation while Recovery Mode
   is active.
   ============================================================ */

public fun withdraw_collateral(
    recovery_registry: &RecoveryModeRegistry,
    access: &AccessControl,
    collateral_manager: &mut CollateralManager,
    position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
) {
    recovery_mode::assert_risk_increase_allowed(
        recovery_registry,
    );

    collateral_manager::withdraw_collateral(
        access,
        collateral_manager,
        position_id,
        amount,
        ctx,
    );
}


/* ============================================================
   Guarded Collateral Withdrawal — Oracle-Safe Path

   Debt-bearing collateral withdrawals must preserve both:
     1. Recovery Mode safety
     2. collateral / oracle safety
   ============================================================ */

public fun withdraw_collateral_with_quote(
    recovery_registry: &RecoveryModeRegistry,
    access: &AccessControl,
    collateral_manager: &mut CollateralManager,
    position_id: u64,
    amount: u64,
    quote: &PriceQuote,
    ctx: &mut TxContext,
) {
    recovery_mode::assert_risk_increase_allowed(
        recovery_registry,
    );

    collateral_manager::withdraw_collateral_with_quote(
        access,
        collateral_manager,
        position_id,
        amount,
        quote,
        ctx,
    );
}


/* ============================================================
   Read Guard

   Useful for PTB / integration layers that need to preflight
   whether risk-increasing operations are currently permitted.
   ============================================================ */

public fun assert_risk_increase_allowed(
    recovery_registry: &RecoveryModeRegistry,
) {
    recovery_mode::assert_risk_increase_allowed(
        recovery_registry,
    );
}

public fun risk_increase_allowed(
    recovery_registry: &RecoveryModeRegistry,
): bool {
    !recovery_mode::is_recovery_mode(
        recovery_registry,
    )
}
