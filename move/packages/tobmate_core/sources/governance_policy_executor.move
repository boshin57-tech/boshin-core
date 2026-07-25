module tobmate_core::governance_policy_executor;

use sui::object::{Self, ID};
use sui::tx_context::TxContext;

use tobmate_core::protocol_governance::{
    Self as governance,
    ExecutionAuthorization,
    GovernanceRegistry,
};

use tobmate_core::treasury_yield_engine::{
    Self as yield_engine,
    TreasuryYieldEngine,
    YieldEngineAdminCap,
};

use tobmate_core::treasury_strategy_recovery_mode::{
    Self as recovery_mode,
    TreasuryStrategyRecoveryModeRegistry,
    TreasuryStrategyRecoveryModeAdminCap,
};


/* ============================================================
   Stage 10 Part 4
   Governance Policy Executor

   Canonical payload encoding:
   - action type is bound separately by ExecutionAuthorization
   - target object ID is bound separately by ExecutionAuthorization
   - payload bytes deterministically encode policy parameters
   ============================================================ */


/* ============================================================
   Governance Action Types
   ============================================================ */

const ACTION_SET_GLOBAL_EXPOSURE: u64 = 1;
const ACTION_SET_STRATEGY_ALLOCATION: u64 = 2;
const ACTION_SET_STRATEGY_CONCENTRATION: u64 = 3;
const ACTION_SET_STRATEGY_ACTIVE: u64 = 4;
const ACTION_RETIRE_STRATEGY: u64 = 5;
const ACTION_SET_RECOVERY_THRESHOLD: u64 = 6;


/* ============================================================
   Canonical Payload Encoding
   ============================================================ */

fun append_u64_le(
    bytes: &mut vector<u8>,
    value: u64,
) {
    vector::push_back(
        bytes,
        (value & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 8) & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 16) & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 24) & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 32) & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 40) & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 48) & 0xff) as u8,
    );

    vector::push_back(
        bytes,
        ((value >> 56) & 0xff) as u8,
    );
}


fun payload_u64(
    value: u64,
): vector<u8> {
    let mut bytes =
        vector::empty<u8>();

    append_u64_le(
        &mut bytes,
        value,
    );

    bytes
}


fun payload_strategy_u64(
    strategy_id: u64,
    value: u64,
): vector<u8> {
    let mut bytes =
        vector::empty<u8>();

    append_u64_le(
        &mut bytes,
        strategy_id,
    );

    append_u64_le(
        &mut bytes,
        value,
    );

    bytes
}


fun payload_strategy_bool(
    strategy_id: u64,
    value: bool,
): vector<u8> {
    let mut bytes =
        vector::empty<u8>();

    append_u64_le(
        &mut bytes,
        strategy_id,
    );

    vector::push_back(
        &mut bytes,
        if (value) {
            1
        } else {
            0
        },
    );

    bytes
}


/* ============================================================
   Action Type Read API
   ============================================================ */

public fun action_set_global_exposure(): u64 {
    ACTION_SET_GLOBAL_EXPOSURE
}

public fun action_set_strategy_allocation(): u64 {
    ACTION_SET_STRATEGY_ALLOCATION
}

public fun action_set_strategy_concentration(): u64 {
    ACTION_SET_STRATEGY_CONCENTRATION
}

public fun action_set_strategy_active(): u64 {
    ACTION_SET_STRATEGY_ACTIVE
}

public fun action_retire_strategy(): u64 {
    ACTION_RETIRE_STRATEGY
}

public fun action_set_recovery_threshold(): u64 {
    ACTION_SET_RECOVERY_THRESHOLD
}


/* ============================================================
   Stage 10 Part 4-A
   Yield Strategy Policy Execution
   ============================================================ */


/* ------------------------------------------------------------
   Action 1
   Set Global Exposure Limit
   ------------------------------------------------------------ */

public fun execute_set_global_exposure(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    yield_admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,

    proposal_id: u64,
    exposure_limit_bps: u64,

    ctx: &TxContext,
) {
    let target_id =
        yield_engine::engine_id(
            engine,
        );

    let payload =
        payload_u64(
            exposure_limit_bps,
        );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        ACTION_SET_GLOBAL_EXPOSURE,
        target_id,
        &payload,
        ctx,
    );

    yield_engine::set_global_exposure_limit_bps(
        yield_admin_cap,
        engine,
        exposure_limit_bps,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_SET_GLOBAL_EXPOSURE,
        target_id,
        &payload,
        ctx,
    );
}


/* ------------------------------------------------------------
   Action 2
   Set Strategy Allocation Limit
   ------------------------------------------------------------ */

public fun execute_set_strategy_allocation(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    yield_admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,

    proposal_id: u64,
    strategy_id: u64,
    allocation_limit: u64,

    ctx: &TxContext,
) {
    let target_id =
        yield_engine::engine_id(
            engine,
        );

    let payload =
        payload_strategy_u64(
            strategy_id,
            allocation_limit,
        );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        ACTION_SET_STRATEGY_ALLOCATION,
        target_id,
        &payload,
        ctx,
    );

    yield_engine::set_strategy_allocation_limit(
        yield_admin_cap,
        engine,
        strategy_id,
        allocation_limit,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_SET_STRATEGY_ALLOCATION,
        target_id,
        &payload,
        ctx,
    );
}


/* ------------------------------------------------------------
   Action 3
   Set Strategy Concentration Limit
   ------------------------------------------------------------ */

public fun execute_set_strategy_concentration(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    yield_admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,

    proposal_id: u64,
    strategy_id: u64,
    concentration_limit_bps: u64,

    ctx: &TxContext,
) {
    let target_id =
        yield_engine::engine_id(
            engine,
        );

    let payload =
        payload_strategy_u64(
            strategy_id,
            concentration_limit_bps,
        );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        ACTION_SET_STRATEGY_CONCENTRATION,
        target_id,
        &payload,
        ctx,
    );

    yield_engine::set_strategy_concentration_limit_bps(
        yield_admin_cap,
        engine,
        strategy_id,
        concentration_limit_bps,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_SET_STRATEGY_CONCENTRATION,
        target_id,
        &payload,
        ctx,
    );
}


/* ------------------------------------------------------------
   Action 4
   Set Strategy Active / Inactive
   ------------------------------------------------------------ */

public fun execute_set_strategy_active(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    yield_admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,

    proposal_id: u64,
    strategy_id: u64,
    active: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        yield_engine::engine_id(
            engine,
        );

    let payload =
        payload_strategy_bool(
            strategy_id,
            active,
        );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        ACTION_SET_STRATEGY_ACTIVE,
        target_id,
        &payload,
        ctx,
    );

    yield_engine::set_strategy_active(
        yield_admin_cap,
        engine,
        strategy_id,
        active,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_SET_STRATEGY_ACTIVE,
        target_id,
        &payload,
        ctx,
    );
}


/* ------------------------------------------------------------
   Action 5
   Retire Strategy
   ------------------------------------------------------------ */

public fun execute_retire_strategy(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    yield_admin_cap: &YieldEngineAdminCap,
    engine: &mut TreasuryYieldEngine,

    proposal_id: u64,
    strategy_id: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        yield_engine::engine_id(
            engine,
        );

    let payload =
        payload_u64(
            strategy_id,
        );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        ACTION_RETIRE_STRATEGY,
        target_id,
        &payload,
        ctx,
    );

    yield_engine::retire_strategy(
        yield_admin_cap,
        engine,
        strategy_id,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_RETIRE_STRATEGY,
        target_id,
        &payload,
        ctx,
    );
}


/* ------------------------------------------------------------
   Action 6
   Set Recovery Threshold
   ------------------------------------------------------------ */

public fun execute_set_recovery_threshold(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    recovery_admin_cap:
        &TreasuryStrategyRecoveryModeAdminCap,

    recovery_registry:
        &mut TreasuryStrategyRecoveryModeRegistry,

    proposal_id: u64,
    threshold_bps: u64,

    ctx: &TxContext,
) {
    let target_id =
        object::id(
            recovery_registry,
        );

    let payload =
        payload_u64(
            threshold_bps,
        );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        ACTION_SET_RECOVERY_THRESHOLD,
        target_id,
        &payload,
        ctx,
    );

    recovery_mode::set_recovery_threshold_bps(
        recovery_registry,
        recovery_admin_cap,
        threshold_bps,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_SET_RECOVERY_THRESHOLD,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Test-only Canonical Payload Helpers
   ============================================================ */

#[test_only]
public fun payload_global_exposure_for_testing(
    exposure_limit_bps: u64,
): vector<u8> {
    payload_u64(
        exposure_limit_bps,
    )
}


#[test_only]
public fun payload_strategy_allocation_for_testing(
    strategy_id: u64,
    allocation_limit: u64,
): vector<u8> {
    payload_strategy_u64(
        strategy_id,
        allocation_limit,
    )
}


#[test_only]
public fun payload_strategy_concentration_for_testing(
    strategy_id: u64,
    concentration_limit_bps: u64,
): vector<u8> {
    payload_strategy_u64(
        strategy_id,
        concentration_limit_bps,
    )
}


#[test_only]
public fun payload_strategy_active_for_testing(
    strategy_id: u64,
    active: bool,
): vector<u8> {
    payload_strategy_bool(
        strategy_id,
        active,
    )
}


#[test_only]
public fun payload_retire_strategy_for_testing(
    strategy_id: u64,
): vector<u8> {
    payload_u64(
        strategy_id,
    )
}


#[test_only]
public fun payload_recovery_threshold_for_testing(
    threshold_bps: u64,
): vector<u8> {
    payload_u64(
        threshold_bps,
    )
}
