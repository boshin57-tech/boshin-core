module tobmate_finance::enterprise_governance_executor;

use sui::object::{Self, ID};
use sui::tx_context::TxContext;

use tobmate_foundation::protocol_governance::{
    Self as governance,
    GovernanceRegistry,
    ExecutionAuthorization,
};

use tobmate_foundation::enterprise_identity::{
    Self as enterprise_identity,
    EnterpriseIdentityRegistry,
    EnterpriseIdentityAdminCap,
};


use tobmate_foundation::custodian_registry::{
    Self as custodian_registry,
    CustodianRegistry,
    CustodianAdminCap,
};

use tobmate_finance::reserve_attestation::{
    Self as reserve_attestation,
    ReserveAttestationRegistry,
    ReserveAttestationAdminCap,
};


use tobmate_foundation::institution_registry::{
    Self as institution_registry,
    InstitutionRegistry,
    InstitutionAdminCap,
};

use tobmate_finance::institutional_settlement::{
    Self as institutional_settlement,
    InstitutionalSettlementRegistry,
    InstitutionalSettlementAdminCap,
};


use tobmate_foundation::regulated_asset_registry::{
    Self as regulated_asset_registry,
    RegulatedAssetRegistry,
    RegulatedAssetAdminCap,
};

use tobmate_finance::etf_instrument::{
    Self as etf_instrument,
    ETFInstrumentRegistry,
    ETFInstrumentAdminCap,
};

use tobmate_finance::cbdc_instrument::{
    Self as cbdc_instrument,
    CBDCInstrumentRegistry,
    CBDCInstrumentAdminCap,
};

use tobmate_finance::regulated_asset_settlement_bridge::{
    Self as regulated_asset_settlement_bridge,
    RegulatedAssetSettlementBridge,
    RegulatedAssetSettlementBridgeAdminCap,
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

const ACTION_CUSTODIAN_SET_PAUSED: u64 = 2201;
const ACTION_CUSTODIAN_SET_VERSION: u64 = 2202;

const ACTION_RESERVE_ATTESTATION_SET_PAUSED: u64 = 2203;
const ACTION_RESERVE_ATTESTATION_SET_VERSION: u64 = 2204;


const ACTION_INSTITUTION_SET_PAUSED: u64 = 2301;
const ACTION_INSTITUTION_SET_VERSION: u64 = 2302;

const ACTION_SETTLEMENT_SET_PAUSED: u64 = 2303;
const ACTION_SETTLEMENT_SET_VERSION: u64 = 2304;


const ACTION_REGULATED_ASSET_SET_PAUSED: u64 = 2401;
const ACTION_REGULATED_ASSET_SET_VERSION: u64 = 2402;

const ACTION_ETF_INSTRUMENT_SET_PAUSED: u64 = 2403;
const ACTION_ETF_INSTRUMENT_SET_VERSION: u64 = 2404;

const ACTION_CBDC_INSTRUMENT_SET_PAUSED: u64 = 2405;
const ACTION_CBDC_INSTRUMENT_SET_VERSION: u64 = 2406;

const ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_PAUSED: u64 = 2407;
const ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_VERSION: u64 = 2408;


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
   Custodian Registry — Pause / Unpause
   ============================================================ */

public fun execute_custodian_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    custodian_registry_obj: &mut CustodianRegistry,
    custodian_admin_cap: &CustodianAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_object_id =
        custodian_registry::registry_id(
            custodian_registry_obj,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_CUSTODIAN_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );

    custodian_registry::set_paused(
        custodian_admin_cap,
        custodian_registry_obj,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_CUSTODIAN_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Custodian Registry — Version
   ============================================================ */

public fun execute_custodian_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    custodian_registry_obj: &mut CustodianRegistry,
    custodian_admin_cap: &CustodianAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_object_id =
        custodian_registry::registry_id(
            custodian_registry_obj,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_CUSTODIAN_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );

    custodian_registry::set_version(
        custodian_admin_cap,
        custodian_registry_obj,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_CUSTODIAN_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Reserve Attestation — Pause / Unpause
   ============================================================ */

public fun execute_reserve_attestation_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    attestation_registry: &mut ReserveAttestationRegistry,
    attestation_admin_cap: &ReserveAttestationAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_object_id =
        reserve_attestation::registry_id(
            attestation_registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_RESERVE_ATTESTATION_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );

    reserve_attestation::set_paused(
        attestation_admin_cap,
        attestation_registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_RESERVE_ATTESTATION_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Reserve Attestation — Version
   ============================================================ */

public fun execute_reserve_attestation_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    attestation_registry: &mut ReserveAttestationRegistry,
    attestation_admin_cap: &ReserveAttestationAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_object_id =
        reserve_attestation::registry_id(
            attestation_registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_RESERVE_ATTESTATION_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );

    reserve_attestation::set_version(
        attestation_admin_cap,
        attestation_registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_RESERVE_ATTESTATION_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );
}



/* ============================================================
   Institution Registry — Pause / Unpause
   ============================================================ */

public fun execute_institution_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    institution_registry_obj: &mut InstitutionRegistry,
    institution_admin_cap: &InstitutionAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_object_id =
        institution_registry::registry_id(
            institution_registry_obj,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_INSTITUTION_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );

    institution_registry::set_paused(
        institution_admin_cap,
        institution_registry_obj,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_INSTITUTION_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Institution Registry — Version
   ============================================================ */

public fun execute_institution_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    institution_registry_obj: &mut InstitutionRegistry,
    institution_admin_cap: &InstitutionAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_object_id =
        institution_registry::registry_id(
            institution_registry_obj,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_INSTITUTION_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );

    institution_registry::set_version(
        institution_admin_cap,
        institution_registry_obj,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_INSTITUTION_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Institutional Settlement — Pause / Unpause
   ============================================================ */

public fun execute_settlement_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    settlement_registry: &mut InstitutionalSettlementRegistry,
    settlement_admin_cap: &InstitutionalSettlementAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_object_id =
        institutional_settlement::registry_id(
            settlement_registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_SETTLEMENT_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );

    institutional_settlement::set_paused(
        settlement_admin_cap,
        settlement_registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_SETTLEMENT_SET_PAUSED,
        target_object_id,
        &payload,

        ctx,
    );
}


/* ============================================================
   Institutional Settlement — Version
   ============================================================ */

public fun execute_settlement_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    settlement_registry: &mut InstitutionalSettlementRegistry,
    settlement_admin_cap: &InstitutionalSettlementAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_object_id =
        institutional_settlement::registry_id(
            settlement_registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governance_execution(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_SETTLEMENT_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );

    institutional_settlement::set_version(
        settlement_admin_cap,
        settlement_registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,

        proposal_id,
        ACTION_SETTLEMENT_SET_VERSION,
        target_object_id,
        &payload,

        ctx,
    );
}



/* ============================================================
   Regulated Asset Registry — Pause
   ============================================================ */

public fun execute_regulated_asset_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    asset_registry: &mut RegulatedAssetRegistry,
    asset_admin_cap: &RegulatedAssetAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target =
        regulated_asset_registry::registry_id(
            asset_registry,
        );

    let payload =
        payload_bool(paused);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_ASSET_SET_PAUSED,
        target,
        &payload,
        ctx,
    );

    regulated_asset_registry::set_paused(
        asset_admin_cap,
        asset_registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_ASSET_SET_PAUSED,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   Regulated Asset Registry — Version
   ============================================================ */

public fun execute_regulated_asset_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    asset_registry: &mut RegulatedAssetRegistry,
    asset_admin_cap: &RegulatedAssetAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target =
        regulated_asset_registry::registry_id(
            asset_registry,
        );

    let payload =
        payload_u64(new_version);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_ASSET_SET_VERSION,
        target,
        &payload,
        ctx,
    );

    regulated_asset_registry::set_version(
        asset_admin_cap,
        asset_registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_ASSET_SET_VERSION,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   ETF Instrument Registry — Pause
   ============================================================ */

public fun execute_etf_instrument_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    etf_registry: &mut ETFInstrumentRegistry,
    etf_admin_cap: &ETFInstrumentAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target =
        etf_instrument::registry_id(
            etf_registry,
        );

    let payload =
        payload_bool(paused);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ETF_INSTRUMENT_SET_PAUSED,
        target,
        &payload,
        ctx,
    );

    etf_instrument::set_paused(
        etf_admin_cap,
        etf_registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ETF_INSTRUMENT_SET_PAUSED,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   ETF Instrument Registry — Version
   ============================================================ */

public fun execute_etf_instrument_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    etf_registry: &mut ETFInstrumentRegistry,
    etf_admin_cap: &ETFInstrumentAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target =
        etf_instrument::registry_id(
            etf_registry,
        );

    let payload =
        payload_u64(new_version);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ETF_INSTRUMENT_SET_VERSION,
        target,
        &payload,
        ctx,
    );

    etf_instrument::set_version(
        etf_admin_cap,
        etf_registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ETF_INSTRUMENT_SET_VERSION,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   CBDC Instrument Registry — Pause
   ============================================================ */

public fun execute_cbdc_instrument_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    cbdc_registry: &mut CBDCInstrumentRegistry,
    cbdc_admin_cap: &CBDCInstrumentAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target =
        cbdc_instrument::registry_id(
            cbdc_registry,
        );

    let payload =
        payload_bool(paused);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CBDC_INSTRUMENT_SET_PAUSED,
        target,
        &payload,
        ctx,
    );

    cbdc_instrument::set_paused(
        cbdc_admin_cap,
        cbdc_registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CBDC_INSTRUMENT_SET_PAUSED,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   CBDC Instrument Registry — Version
   ============================================================ */

public fun execute_cbdc_instrument_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    cbdc_registry: &mut CBDCInstrumentRegistry,
    cbdc_admin_cap: &CBDCInstrumentAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target =
        cbdc_instrument::registry_id(
            cbdc_registry,
        );

    let payload =
        payload_u64(new_version);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CBDC_INSTRUMENT_SET_VERSION,
        target,
        &payload,
        ctx,
    );

    cbdc_instrument::set_version(
        cbdc_admin_cap,
        cbdc_registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CBDC_INSTRUMENT_SET_VERSION,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   Regulated Settlement Bridge — Pause
   ============================================================ */

public fun execute_regulated_bridge_set_paused(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    bridge: &mut RegulatedAssetSettlementBridge,
    bridge_admin_cap: &RegulatedAssetSettlementBridgeAdminCap,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target =
        regulated_asset_settlement_bridge::bridge_id(
            bridge,
        );

    let payload =
        payload_bool(paused);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_PAUSED,
        target,
        &payload,
        ctx,
    );

    regulated_asset_settlement_bridge::set_paused(
        bridge_admin_cap,
        bridge,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_PAUSED,
        target,
        &payload,
        ctx,
    );
}


/* ============================================================
   Regulated Settlement Bridge — Version
   ============================================================ */

public fun execute_regulated_bridge_set_version(
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    bridge: &mut RegulatedAssetSettlementBridge,
    bridge_admin_cap: &RegulatedAssetSettlementBridgeAdminCap,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target =
        regulated_asset_settlement_bridge::bridge_id(
            bridge,
        );

    let payload =
        payload_u64(new_version);

    assert_governance_execution(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_VERSION,
        target,
        &payload,
        ctx,
    );

    regulated_asset_settlement_bridge::set_version(
        bridge_admin_cap,
        bridge,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_VERSION,
        target,
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


public fun action_custodian_set_paused(): u64 {
    ACTION_CUSTODIAN_SET_PAUSED
}

public fun action_custodian_set_version(): u64 {
    ACTION_CUSTODIAN_SET_VERSION
}

public fun action_reserve_attestation_set_paused(): u64 {
    ACTION_RESERVE_ATTESTATION_SET_PAUSED
}

public fun action_reserve_attestation_set_version(): u64 {
    ACTION_RESERVE_ATTESTATION_SET_VERSION
}


public fun action_institution_set_paused(): u64 {
    ACTION_INSTITUTION_SET_PAUSED
}

public fun action_institution_set_version(): u64 {
    ACTION_INSTITUTION_SET_VERSION
}

public fun action_settlement_set_paused(): u64 {
    ACTION_SETTLEMENT_SET_PAUSED
}

public fun action_settlement_set_version(): u64 {
    ACTION_SETTLEMENT_SET_VERSION
}


public fun action_regulated_asset_set_paused(): u64 {
    ACTION_REGULATED_ASSET_SET_PAUSED
}

public fun action_regulated_asset_set_version(): u64 {
    ACTION_REGULATED_ASSET_SET_VERSION
}

public fun action_etf_instrument_set_paused(): u64 {
    ACTION_ETF_INSTRUMENT_SET_PAUSED
}

public fun action_etf_instrument_set_version(): u64 {
    ACTION_ETF_INSTRUMENT_SET_VERSION
}

public fun action_cbdc_instrument_set_paused(): u64 {
    ACTION_CBDC_INSTRUMENT_SET_PAUSED
}

public fun action_cbdc_instrument_set_version(): u64 {
    ACTION_CBDC_INSTRUMENT_SET_VERSION
}

public fun action_regulated_bridge_set_paused(): u64 {
    ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_PAUSED
}

public fun action_regulated_bridge_set_version(): u64 {
    ACTION_REGULATED_SETTLEMENT_BRIDGE_SET_VERSION
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
