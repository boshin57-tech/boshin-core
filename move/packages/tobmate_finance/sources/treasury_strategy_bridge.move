module tobmate_finance::treasury_strategy_bridge;

use sui::tx_context::TxContext;

use tobmate_foundation::access_control::AccessControl;

use tobmate_finance::treasury::{
    Self as treasury,
    ProtocolTreasury,
    TreasuryAdminCap,
};

use tobmate_finance::treasury_yield_engine::{
    Self as yield_engine,
    TreasuryYieldEngine,
};


/* ============================================================
   Stage 9 Part 1-B
   Treasury → Yield Engine Funding Bridge
   ============================================================ */

public fun deploy_to_yield_engine(
    treasury_admin_cap: &TreasuryAdminCap,
    access: &AccessControl,
    treasury: &mut ProtocolTreasury,
    engine: &mut TreasuryYieldEngine,
    amount: u64,
    ctx: &mut TxContext,
) {
    let capital =
        treasury::withdraw_for_yield_strategy(
            treasury_admin_cap,
            access,
            treasury,
            amount,
            ctx,
        );

    yield_engine::fund(
        access,
        engine,
        capital,
        ctx,
    );

    treasury::assert_accounting_invariant(
        treasury,
    );

    yield_engine::assert_accounting_invariant(
        engine,
    );
}


/* ============================================================
   Stage 9 Part 1-D
   Yield Engine → Treasury Sweep Bridge
   ============================================================ */

public fun sweep_to_treasury(
    yield_admin_cap: &yield_engine::YieldEngineAdminCap,
    access: &AccessControl,
    treasury: &mut ProtocolTreasury,
    engine: &mut TreasuryYieldEngine,
    amount: u64,
    ctx: &mut TxContext,
) {
    let payment =
        yield_engine::withdraw_for_treasury(
            yield_admin_cap,
            access,
            engine,
            amount,
            ctx,
        );

    treasury::deposit(
        access,
        treasury,
        payment,
        ctx,
    );

    treasury::assert_accounting_invariant(
        treasury,
    );

    yield_engine::assert_accounting_invariant(
        engine,
    );
}
