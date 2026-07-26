module tobmate_core::enterprise_governance_executor;

use sui::object::{Self, ID};
use sui::tx_context::TxContext;

use tobmate_core::protocol_governance::{
    Self as governance,
    GovernanceRegistry,
    ExecutionAuthorization,
};

use tobmate_core::enterprise_identity::{
    Self as enterprise_identity,
    EnterpriseIdentityRegistry,
    EnterpriseIdentityAdminCap,
};


/* ============================================================
   Stage 12 Part 1-D
   Enterprise Governance Executor

   Enterprise action namespace:

   2101 — Enterprise Identity set_paused
   2102 — Enterprise Identity set_version

   Reserved:
   2201+ — Custodian / Reserve Attestation
   2301+ — Bank Settlement
   2401+ — Institutional / ETF
   2501+ — CBDC / Regulated Asset
   2601+ — Bridge / Settlement
   2701+ — Validator / Operator
   ============================================================ */


/* ============================================================
   Action Types
   ============================================================ */

const ACTION_IDENTITY_SET_PAUSED: u64 = 2101;
const ACTION_IDENTITY_SET_VERSION: u64 = 2102;


/* ============================================================
   Payload Encoding

   Governance authorization binds:
       proposal
       action
       target object
       payload

   This prevents an authorization issued for one enterprise
   mutation from being reused for another mutation.
   ============================================================ */

fun payload_bool(
    value: bool,
): vector<u8> {
    if (value) {
        vector[1]
    } else {
        vector[0]
    }
}

fun payload_u64(
    value: u64,
): vector<u8> {
    vector[
        ((value >> 0) & 0xff) as u8,
        ((value >> 8) & 0xff) as u8,
        ((value >> 16) & 0xff) as u8,
        ((value >> 24) & 0xff) as u8,
        ((value >> 32) & 0xff) as u8,
        ((value >> 40) & 0xff) as u8,
        ((value >> 48) & 0xff) as u8,
        ((value >> 56) & 0xff) as u8,
    ]
}


/* ============================================================
   Governance Guard

   Required conditions:

   1. governance emergency mode inactive
   2. proposal queued and executable
   3. authorization belongs to same governance registry
   4. authorization matches proposal/action/target/payload
   5. timelock has expired
   ============================================================ */

fun assert_governance_execution(
    governance_registry: &GovernanceRegistry,
    authorization: &ExecutionAuthorization,

    proposal_id: u64,
    action_type: u64,
    target_object_id: ID,
    payload: &vector<u8>,

    ctx: &TxContext,
) {
    governance::assert_not_emergency(
        governance_registry,
    );

    governance::assert_proposal_execution_allowed(
        governance_registry,
        proposal_id,
    );

    governance::assert_authorization_registry(
        governance_registry,
        authorization,
    );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        action_type,
        target_object_id,
        payload,
        ctx,
    );
}


/* ============================================================
   Enterprise Identity — Pause / Unpause
   ============================================================ */

public fun execute_identity_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    enterprise_registry: &mut EnterpriseIdentityRegistry,
    enterprise_admin_cap: &EnterpriseIdentityAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_object_id =
        enterprise_identity::registry_id(
            enterprise_registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_IDENTITY_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );

    enterprise_identity::set_paused(
        enterprise_admin_cap,
        enterprise_registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_IDENTITY_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Enterprise Identity — Version Upgrade
   ============================================================ */

public fun execute_identity_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    enterprise_registry: &mut EnterpriseIdentityRegistry,
    enterprise_admin_cap: &EnterpriseIdentityAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_object_id =
        enterprise_identity::registry_id(
            enterprise_registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_IDENTITY_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );

    enterprise_identity::set_version(
        enterprise_admin_cap,
        enterprise_registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_IDENTITY_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Public Action API
   ============================================================ */

public fun action_identity_set_paused(): u64 {
    ACTION_IDENTITY_SET_PAUSED
}

public fun action_identity_set_version(): u64 {
    ACTION_IDENTITY_SET_VERSION
}


/* ============================================================
   Test Payload Helpers
   ============================================================ */

#[test_only]
public fun payload_bool_for_testing(
    value: bool,
): vector<u8> {
    payload_bool(value)
}

#[test_only]
public fun payload_u64_for_testing(
    value: u64,
): vector<u8> {
    payload_u64(value)
}
