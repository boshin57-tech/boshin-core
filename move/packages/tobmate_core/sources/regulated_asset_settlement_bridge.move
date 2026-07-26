module tobmate_core::regulated_asset_settlement_bridge;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::institutional_settlement::{
    Self as institutional_settlement,
    InstitutionalSettlementRegistry,
};

use tobmate_core::institution_registry::{
    InstitutionRegistry,
};

use tobmate_core::regulated_asset_registry::{
    RegulatedAssetRegistry,
};

use tobmate_core::etf_instrument::{
    Self as etf,
    ETFInstrumentRegistry,
};

use tobmate_core::cbdc_instrument::{
    Self as cbdc,
    CBDCInstrumentRegistry,
};


/* ============================================================
   Stage 12 Part 4-D
   Regulated Asset Settlement Bridge
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Bridge Operation Types
   ============================================================ */

const OP_ETF_ISSUE: u8 = 1;
const OP_ETF_REDEEM: u8 = 2;
const OP_CBDC_MINT: u8 = 3;
const OP_CBDC_BURN: u8 = 4;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_OPERATION: u64 = 2;
const E_ZERO_AMOUNT: u64 = 3;
const E_SETTLEMENT_NOT_FINALIZED: u64 = 4;
const E_SETTLEMENT_ALREADY_CONSUMED: u64 = 5;
const E_SETTLEMENT_NOT_FOUND: u64 = 6;
const E_VERSION_NOT_INCREASING: u64 = 7;
const E_ADMIN_CAP_MISMATCH: u64 = 8;
const E_STATE_UNCHANGED: u64 = 9;


/* ============================================================
   Registry
   ============================================================ */

public struct RegulatedAssetSettlementBridge has key {
    id: UID,

    version: u64,
    paused: bool,

    records: vector<SettlementConsumptionRecord>,

    total_consumed: u64,

    etf_issue_count: u64,
    etf_redeem_count: u64,
    cbdc_mint_count: u64,
    cbdc_burn_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct RegulatedAssetSettlementBridgeAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Settlement Consumption Record
   ============================================================ */

public struct SettlementConsumptionRecord has store {
    settlement_id: u64,

    operation: u8,

    instrument_id: u64,
    amount: u64,

    consumed_epoch: u64,
    consumed_by: address,
}


/* ============================================================
   Events
   ============================================================ */

public struct SettlementConsumed has copy, drop {
    bridge_id: ID,

    settlement_id: u64,
    operation: u8,

    instrument_id: u64,
    amount: u64,

    consumed_by: address,
    consumed_epoch: u64,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    RegulatedAssetSettlementBridge,
    RegulatedAssetSettlementBridgeAdminCap,
) {
    let bridge =
        RegulatedAssetSettlementBridge {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            records:
                vector[],

            total_consumed:
                0,

            etf_issue_count:
                0,

            etf_redeem_count:
                0,

            cbdc_mint_count:
                0,

            cbdc_burn_count:
                0,
        };

    let admin_cap =
        RegulatedAssetSettlementBridgeAdminCap {
            id: object::new(ctx),

            registry_id:
                object::id(&bridge),
        };

    (
        bridge,
        admin_cap,
    )
}


/* ============================================================
   Guards
   ============================================================ */

public fun assert_operational(
    access: &AccessControl,
    bridge: &RegulatedAssetSettlementBridge,
) {
    access_control::assert_not_paused(
        access,
    );

    assert!(
        !bridge.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    bridge: &RegulatedAssetSettlementBridge,
    admin_cap: &RegulatedAssetSettlementBridgeAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(bridge),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_operation(
    operation: u8,
) {
    assert!(
        operation == OP_ETF_ISSUE
            || operation == OP_ETF_REDEEM
            || operation == OP_CBDC_MINT
            || operation == OP_CBDC_BURN,
        E_INVALID_OPERATION,
    );
}

fun settlement_consumed(
    bridge: &RegulatedAssetSettlementBridge,
    settlement_id: u64,
): bool {
    let length =
        vector::length(
            &bridge.records,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &bridge.records,
                i,
            );

        if (
            record.settlement_id
                == settlement_id
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Settlement Finality Guard
   ============================================================ */

fun assert_finalized_settlement(
    settlement_registry:
        &InstitutionalSettlementRegistry,

    settlement_id: u64,
) {
    assert!(
        institutional_settlement::settlement_status(
            settlement_registry,
            settlement_id,
        ) == institutional_settlement::status_finalized(),
        E_SETTLEMENT_NOT_FINALIZED,
    );
}


/* ============================================================
   Consumption Accounting
   ============================================================ */

fun record_consumption(
    bridge: &mut RegulatedAssetSettlementBridge,

    settlement_id: u64,
    operation: u8,

    instrument_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_valid_operation(
        operation,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    assert!(
        !settlement_consumed(
            bridge,
            settlement_id,
        ),
        E_SETTLEMENT_ALREADY_CONSUMED,
    );

    vector::push_back(
        &mut bridge.records,

        SettlementConsumptionRecord {
            settlement_id,
            operation,

            instrument_id,
            amount,

            consumed_epoch:
                tx_context::epoch(ctx),

            consumed_by:
                tx_context::sender(ctx),
        },
    );

    bridge.total_consumed =
        bridge.total_consumed + 1;

    if (operation == OP_ETF_ISSUE) {
        bridge.etf_issue_count =
            bridge.etf_issue_count + 1;
    } else if (operation == OP_ETF_REDEEM) {
        bridge.etf_redeem_count =
            bridge.etf_redeem_count + 1;
    } else if (operation == OP_CBDC_MINT) {
        bridge.cbdc_mint_count =
            bridge.cbdc_mint_count + 1;
    } else {
        bridge.cbdc_burn_count =
            bridge.cbdc_burn_count + 1;
    };

    event::emit(
        SettlementConsumed {
            bridge_id:
                object::id(bridge),

            settlement_id,
            operation,

            instrument_id,
            amount,

            consumed_by:
                tx_context::sender(ctx),

            consumed_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   ETF Issue Through Finalized Settlement
   ============================================================ */

public fun execute_etf_issue(
    access: &AccessControl,

    bridge: &mut RegulatedAssetSettlementBridge,

    settlement_registry:
        &InstitutionalSettlementRegistry,

    institution_registry_obj:
        &InstitutionRegistry,

    regulated_asset_registry_obj:
        &RegulatedAssetRegistry,

    etf_registry:
        &mut ETFInstrumentRegistry,

    settlement_id: u64,
    instrument_id: u64,
    issue_units: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        bridge,
    );

    assert!(
        issue_units > 0,
        E_ZERO_AMOUNT,
    );

    assert_finalized_settlement(
        settlement_registry,
        settlement_id,
    );

    assert!(
        !settlement_consumed(
            bridge,
            settlement_id,
        ),
        E_SETTLEMENT_ALREADY_CONSUMED,
    );

    etf::issue_units(
        access,

        etf_registry,

        institution_registry_obj,
        regulated_asset_registry_obj,

        instrument_id,
        issue_units,

        ctx,
    );

    record_consumption(
        bridge,

        settlement_id,
        OP_ETF_ISSUE,

        instrument_id,
        issue_units,

        ctx,
    );
}


/* ============================================================
   ETF Redeem Through Finalized Settlement
   ============================================================ */

public fun execute_etf_redeem(
    access: &AccessControl,

    bridge: &mut RegulatedAssetSettlementBridge,

    settlement_registry:
        &InstitutionalSettlementRegistry,

    institution_registry_obj:
        &InstitutionRegistry,

    regulated_asset_registry_obj:
        &RegulatedAssetRegistry,

    etf_registry:
        &mut ETFInstrumentRegistry,

    settlement_id: u64,
    instrument_id: u64,
    redeem_units: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        bridge,
    );

    assert!(
        redeem_units > 0,
        E_ZERO_AMOUNT,
    );

    assert_finalized_settlement(
        settlement_registry,
        settlement_id,
    );

    assert!(
        !settlement_consumed(
            bridge,
            settlement_id,
        ),
        E_SETTLEMENT_ALREADY_CONSUMED,
    );

    etf::redeem_units(
        access,

        etf_registry,

        institution_registry_obj,
        regulated_asset_registry_obj,

        instrument_id,
        redeem_units,

        ctx,
    );

    record_consumption(
        bridge,

        settlement_id,
        OP_ETF_REDEEM,

        instrument_id,
        redeem_units,

        ctx,
    );
}


/* ============================================================
   CBDC Mint Through Finalized Settlement
   ============================================================ */

public fun execute_cbdc_mint(
    access: &AccessControl,

    bridge: &mut RegulatedAssetSettlementBridge,

    settlement_registry:
        &InstitutionalSettlementRegistry,

    institution_registry_obj:
        &InstitutionRegistry,

    regulated_asset_registry_obj:
        &RegulatedAssetRegistry,

    cbdc_registry:
        &mut CBDCInstrumentRegistry,

    settlement_id: u64,
    instrument_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        bridge,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    assert_finalized_settlement(
        settlement_registry,
        settlement_id,
    );

    assert!(
        !settlement_consumed(
            bridge,
            settlement_id,
        ),
        E_SETTLEMENT_ALREADY_CONSUMED,
    );

    cbdc::mint(
        access,

        cbdc_registry,

        institution_registry_obj,
        regulated_asset_registry_obj,

        instrument_id,
        amount,

        ctx,
    );

    record_consumption(
        bridge,

        settlement_id,
        OP_CBDC_MINT,

        instrument_id,
        amount,

        ctx,
    );
}


/* ============================================================
   CBDC Burn Through Finalized Settlement
   ============================================================ */

public fun execute_cbdc_burn(
    access: &AccessControl,

    bridge: &mut RegulatedAssetSettlementBridge,

    settlement_registry:
        &InstitutionalSettlementRegistry,

    institution_registry_obj:
        &InstitutionRegistry,

    regulated_asset_registry_obj:
        &RegulatedAssetRegistry,

    cbdc_registry:
        &mut CBDCInstrumentRegistry,

    settlement_id: u64,
    instrument_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        bridge,
    );

    assert!(
        amount > 0,
        E_ZERO_AMOUNT,
    );

    assert_finalized_settlement(
        settlement_registry,
        settlement_id,
    );

    assert!(
        !settlement_consumed(
            bridge,
            settlement_id,
        ),
        E_SETTLEMENT_ALREADY_CONSUMED,
    );

    cbdc::burn(
        access,

        cbdc_registry,

        institution_registry_obj,
        regulated_asset_registry_obj,

        instrument_id,
        amount,

        ctx,
    );

    record_consumption(
        bridge,

        settlement_id,
        OP_CBDC_BURN,

        instrument_id,
        amount,

        ctx,
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap:
        &RegulatedAssetSettlementBridgeAdminCap,

    bridge:
        &mut RegulatedAssetSettlementBridge,

    paused: bool,

    _ctx: &mut TxContext,
) {
    assert_admin(
        bridge,
        admin_cap,
    );

    assert!(
        bridge.paused != paused,
        E_STATE_UNCHANGED,
    );

    bridge.paused =
        paused;
}

public fun set_version(
    admin_cap:
        &RegulatedAssetSettlementBridgeAdminCap,

    bridge:
        &mut RegulatedAssetSettlementBridge,

    new_version: u64,

    _ctx: &mut TxContext,
) {
    assert_admin(
        bridge,
        admin_cap,
    );

    assert!(
        new_version > bridge.version,
        E_VERSION_NOT_INCREASING,
    );

    bridge.version =
        new_version;
}


/* ============================================================
   Read API
   ============================================================ */

public fun bridge_id(
    bridge: &RegulatedAssetSettlementBridge,
): ID {
    object::id(bridge)
}

public fun version(
    bridge: &RegulatedAssetSettlementBridge,
): u64 {
    bridge.version
}

public fun is_paused(
    bridge: &RegulatedAssetSettlementBridge,
): bool {
    bridge.paused
}

public fun total_consumed(
    bridge: &RegulatedAssetSettlementBridge,
): u64 {
    bridge.total_consumed
}

public fun etf_issue_count(
    bridge: &RegulatedAssetSettlementBridge,
): u64 {
    bridge.etf_issue_count
}

public fun etf_redeem_count(
    bridge: &RegulatedAssetSettlementBridge,
): u64 {
    bridge.etf_redeem_count
}

public fun cbdc_mint_count(
    bridge: &RegulatedAssetSettlementBridge,
): u64 {
    bridge.cbdc_mint_count
}

public fun cbdc_burn_count(
    bridge: &RegulatedAssetSettlementBridge,
): u64 {
    bridge.cbdc_burn_count
}

public fun is_settlement_consumed(
    bridge: &RegulatedAssetSettlementBridge,
    settlement_id: u64,
): bool {
    settlement_consumed(
        bridge,
        settlement_id,
    )
}


/* ============================================================
   Operation API
   ============================================================ */

public fun operation_etf_issue(): u8 {
    OP_ETF_ISSUE
}

public fun operation_etf_redeem(): u8 {
    OP_ETF_REDEEM
}

public fun operation_cbdc_mint(): u8 {
    OP_CBDC_MINT
}

public fun operation_cbdc_burn(): u8 {
    OP_CBDC_BURN
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): RegulatedAssetSettlementBridge {
    RegulatedAssetSettlementBridge {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        records:
            vector[],

        total_consumed:
            0,

        etf_issue_count:
            0,

        etf_redeem_count:
            0,

        cbdc_mint_count:
            0,

        cbdc_burn_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    bridge: &RegulatedAssetSettlementBridge,
    ctx: &mut TxContext,
): RegulatedAssetSettlementBridgeAdminCap {
    RegulatedAssetSettlementBridgeAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(bridge),
    }
}

#[test_only]
public fun destroy_for_testing(
    bridge: RegulatedAssetSettlementBridge,
) {
    let RegulatedAssetSettlementBridge {
        id,

        version: _,
        paused: _,

        records,

        total_consumed: _,

        etf_issue_count: _,
        etf_redeem_count: _,
        cbdc_mint_count: _,
        cbdc_burn_count: _,
    } = bridge;

    let mut records =
        records;

    while (
        !vector::is_empty(
            &records,
        )
    ) {
        let record =
            vector::pop_back(
                &mut records,
            );

        let SettlementConsumptionRecord {
            settlement_id: _,

            operation: _,

            instrument_id: _,
            amount: _,

            consumed_epoch: _,
            consumed_by: _,
        } = record;
    };

    vector::destroy_empty(
        records,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: RegulatedAssetSettlementBridgeAdminCap,
) {
    let RegulatedAssetSettlementBridgeAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
