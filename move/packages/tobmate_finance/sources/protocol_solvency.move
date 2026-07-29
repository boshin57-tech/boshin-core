module tobmate_finance::protocol_solvency;

use tobmate_finance::bad_debt_settlement::{
    Self as bad_debt_settlement,
    BadDebtSettlementRegistry,
};

use tobmate_finance::insurance_fund::{
    Self as insurance_fund,
    InsuranceFund,
};

use tobmate_finance::lending_pool::{
    Self as lending_pool,
    LendingPool,
};

use tobmate_finance::treasury::{
    Self as treasury,
    ProtocolTreasury,
};

use tobmate_finance::treasury_backstop::{
    Self as treasury_backstop,
    TreasuryBackstopRegistry,
};

/* ============================================================
   Stage 7H
   Protocol Solvency Accounting & Safety Invariants
   ============================================================ */

const BPS_DENOMINATOR: u128 = 10_000;

const E_BAD_DEBT_CREATED_MISMATCH: u64 = 1;
const E_BAD_DEBT_RECOVERED_MISMATCH: u64 = 2;
const E_BAD_DEBT_OUTSTANDING_MISMATCH: u64 = 3;
const E_RECOVERY_ABOVE_RECORDED: u64 = 4;


/* ============================================================
   Snapshot
   ============================================================ */

public struct SolvencySnapshot has copy, drop, store {
    outstanding_bad_debt: u64,

    protocol_reserves: u64,
    insurance_balance: u64,
    treasury_balance: u64,

    loss_absorption_capacity: u128,
    coverage_bps: u128,

    total_bad_debt_created: u64,
    total_bad_debt_recovered: u64,

    total_treasury_backstop_paid: u64,
}


/* ============================================================
   Cross-Module Accounting Invariant
   ============================================================ */

public fun assert_protocol_accounting_invariant(
    pool: &LendingPool,
    bad_debt_registry: &BadDebtSettlementRegistry,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
) {
    /*
       Preserve each subsystem's own invariant first.
    */

    lending_pool::assert_accounting_invariant(
        pool,
    );

    lending_pool::assert_bad_debt_accounting_invariant(
        pool,
    );

    insurance_fund::assert_accounting_invariant(
        insurance,
    );

    treasury::assert_accounting_invariant(
        protocol_treasury,
    );

    let pool_created =
        lending_pool::total_bad_debt_created(
            pool,
        );

    let registry_created =
        bad_debt_settlement::total_bad_debt_recorded(
            bad_debt_registry,
        );

    assert!(
        pool_created == registry_created,
        E_BAD_DEBT_CREATED_MISMATCH,
    );

    let pool_recovered =
        lending_pool::total_bad_debt_recovered(
            pool,
        );

    let registry_recovered =
        bad_debt_settlement::total_recovered(
            bad_debt_registry,
        );

    assert!(
        pool_recovered == registry_recovered,
        E_BAD_DEBT_RECOVERED_MISMATCH,
    );

    assert!(
        registry_recovered <= registry_created,
        E_RECOVERY_ABOVE_RECORDED,
    );

    let expected_outstanding =
        registry_created - registry_recovered;

    assert!(
        lending_pool::outstanding_bad_debt(
            pool,
        ) == expected_outstanding,
        E_BAD_DEBT_OUTSTANDING_MISMATCH,
    );
}


/* ============================================================
   Loss Absorption Capacity
   ============================================================ */

public fun loss_absorption_capacity(
    pool: &LendingPool,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
): u128 {
    (lending_pool::protocol_reserves(pool) as u128)
        + (insurance_fund::fund_balance(insurance) as u128)
        + (treasury::balance(protocol_treasury) as u128)
}


/* ============================================================
   Coverage Ratio
   basis points
   ============================================================ */

public(package) fun coverage_bps(
    pool: &LendingPool,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
): u128 {
    let outstanding =
        lending_pool::outstanding_bad_debt(
            pool,
        );

    if (outstanding == 0) {
        return BPS_DENOMINATOR
    };

    (
        loss_absorption_capacity(
            pool,
            insurance,
            protocol_treasury,
        )
        * BPS_DENOMINATOR
    ) / (outstanding as u128)
}


/* ============================================================
   Solvency State
   ============================================================ */

public fun is_fully_covered(
    pool: &LendingPool,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
): bool {
    let outstanding =
        lending_pool::outstanding_bad_debt(
            pool,
        ) as u128;

    if (outstanding == 0) {
        return true
    };

    loss_absorption_capacity(
        pool,
        insurance,
        protocol_treasury,
    ) >= outstanding
}


/* ============================================================
   Snapshot Construction
   ============================================================ */

public fun snapshot(
    pool: &LendingPool,
    bad_debt_registry: &BadDebtSettlementRegistry,
    insurance: &InsuranceFund,
    protocol_treasury: &ProtocolTreasury,
    backstop: &TreasuryBackstopRegistry,
): SolvencySnapshot {
    assert_protocol_accounting_invariant(
        pool,
        bad_debt_registry,
        insurance,
        protocol_treasury,
    );

    SolvencySnapshot {
        outstanding_bad_debt:
            lending_pool::outstanding_bad_debt(pool),

        protocol_reserves:
            lending_pool::protocol_reserves(pool),

        insurance_balance:
            insurance_fund::fund_balance(insurance),

        treasury_balance:
            treasury::balance(protocol_treasury),

        loss_absorption_capacity:
            loss_absorption_capacity(
                pool,
                insurance,
                protocol_treasury,
            ),

        coverage_bps:
            coverage_bps(
                pool,
                insurance,
                protocol_treasury,
            ),

        total_bad_debt_created:
            lending_pool::total_bad_debt_created(
                pool,
            ),

        total_bad_debt_recovered:
            lending_pool::total_bad_debt_recovered(
                pool,
            ),

        total_treasury_backstop_paid:
            treasury_backstop::total_backstop_paid(
                backstop,
            ),
    }
}


/* ============================================================
   Snapshot Read API
   ============================================================ */

public fun snapshot_outstanding_bad_debt(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.outstanding_bad_debt
}

public(package) fun snapshot_protocol_reserves(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.protocol_reserves
}

public(package) fun snapshot_insurance_balance(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.insurance_balance
}

public(package) fun snapshot_treasury_balance(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.treasury_balance
}

public fun snapshot_loss_absorption_capacity(
    snapshot: &SolvencySnapshot,
): u128 {
    snapshot.loss_absorption_capacity
}

public fun snapshot_coverage_bps(
    snapshot: &SolvencySnapshot,
): u128 {
    snapshot.coverage_bps
}

public fun snapshot_total_bad_debt_created(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.total_bad_debt_created
}

public fun snapshot_total_bad_debt_recovered(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.total_bad_debt_recovered
}

public fun snapshot_total_treasury_backstop_paid(
    snapshot: &SolvencySnapshot,
): u64 {
    snapshot.total_treasury_backstop_paid
}
