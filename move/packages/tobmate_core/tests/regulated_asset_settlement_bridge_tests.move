#[test_only]
module tobmate_core::regulated_asset_settlement_bridge_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::institution_registry::{
    Self as institution_registry,
};

use tobmate_core::institutional_settlement::{
    Self as settlement,
};

use tobmate_core::regulated_asset_registry::{
    Self as regulated_asset,
};

use tobmate_core::etf_instrument::{
    Self as etf,
};

use tobmate_core::cbdc_instrument::{
    Self as cbdc,
};

use tobmate_core::regulated_asset_settlement_bridge::{
    Self as bridge,
};


const ADMIN: address = @0xA11CE;
const ETF_ISSUER: address = @0xE710;
const CBDC_OPERATOR: address = @0xCB01;
const BENEFICIARY: address = @0xC001;


/* ============================================================
   ETF Fixture
   ============================================================ */

fun setup_etf_fixture(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,

    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,

    regulated_asset::RegulatedAssetRegistry,
    regulated_asset::RegulatedAssetAdminCap,

    etf::ETFInstrumentRegistry,
    etf::ETFInstrumentAdminCap,

    settlement::InstitutionalSettlementRegistry,
    settlement::InstitutionalSettlementAdminCap,

    bridge::RegulatedAssetSettlementBridge,
    bridge::RegulatedAssetSettlementBridgeAdminCap,

    u64,
    u64,
) {
    let access =
        access_control::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let mut institutions =
        institution_registry::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institutions,
            test_scenario::ctx(scenario),
        );

    let issuer_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,

            b"ETF-ISSUER-BRIDGE",
            ETF_ISSUER,

            institution_registry::institution_etf_issuer(),
            b"AU",

            test_scenario::ctx(scenario),
        );

    let mut assets =
        regulated_asset::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let asset_admin =
        regulated_asset::admin_cap_for_testing(
            &assets,
            test_scenario::ctx(scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut assets,
            &asset_admin,
            &institutions,

            b"ETF-BRIDGE-ASSET",
            b"ETFBR",

            regulated_asset::asset_etf(),
            issuer_id,
            b"AU",

            test_scenario::ctx(scenario),
        );

    let mut etf_registry =
        etf::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let etf_admin =
        etf::admin_cap_for_testing(
            &etf_registry,
            test_scenario::ctx(scenario),
        );

    let instrument_id =
        etf::register_instrument(
            &access,
            &mut etf_registry,
            &etf_admin,
            &institutions,
            &assets,
            asset_id,
            issuer_id,
            100,
            test_scenario::ctx(scenario),
        );

    let settlement_registry =
        settlement::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let settlement_admin =
        settlement::admin_cap_for_testing(
            &settlement_registry,
            test_scenario::ctx(scenario),
        );

    let bridge_obj =
        bridge::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let bridge_admin =
        bridge::admin_cap_for_testing(
            &bridge_obj,
            test_scenario::ctx(scenario),
        );

    (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        etf_registry,
        etf_admin,
        settlement_registry,
        settlement_admin,
        bridge_obj,
        bridge_admin,
        issuer_id,
        instrument_id,
    )
}


/* ============================================================
   Helper
   Create Finalized Settlement
   ============================================================ */

fun create_finalized_settlement(
    scenario: &mut test_scenario::Scenario,

    access: &access_control::AccessControl,

    institutions: &institution_registry::InstitutionRegistry,

    settlement_registry:
        &mut settlement::InstitutionalSettlementRegistry,

    settlement_admin:
        &settlement::InstitutionalSettlementAdminCap,

    institution_id: u64,

    external_reference: vector<u8>,
): u64 {
    let settlement_id =
        settlement::create_settlement(
            access,
            settlement_registry,
            institutions,

            institution_id,

            settlement::settlement_asset_purchase(),

            b"AUD",
            100000,

            BENEFICIARY,
            external_reference,

            test_scenario::ctx(scenario),
        );

    test_scenario::next_tx(
        scenario,
        ETF_ISSUER,
    );

    settlement::confirm_settlement(
        access,
        settlement_registry,
        institutions,

        settlement_id,
        institution_id,

        b"CONFIRMED",

        test_scenario::ctx(scenario),
    );

    test_scenario::next_tx(
        scenario,
        ADMIN,
    );

    settlement::finalize_settlement(
        access,
        settlement_registry,
        settlement_admin,
        settlement_id,
        test_scenario::ctx(scenario),
    );

    settlement_id
}


/* ============================================================
   Test 01
   Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let bridge_obj =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        bridge::version(&bridge_obj) == 1,
        10,
    );

    assert!(
        !bridge::is_paused(&bridge_obj),
        11,
    );

    assert!(
        bridge::total_consumed(&bridge_obj) == 0,
        12,
    );

    bridge::destroy_for_testing(
        bridge_obj,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 02
   Finalized Settlement Executes ETF Issue
   ============================================================ */

#[test]
fun test_02_finalized_settlement_etf_issue() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut etf_registry,
        etf_admin,
        mut settlement_registry,
        settlement_admin,
        mut bridge_obj,
        bridge_admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf_fixture(
            &mut scenario,
        );

    let settlement_id =
        create_finalized_settlement(
            &mut scenario,
            &access,
            &institutions,
            &mut settlement_registry,
            &settlement_admin,
            issuer_id,
            b"ETF-ISSUE-001",
        );

    test_scenario::next_tx(
        &mut scenario,
        ETF_ISSUER,
    );

    bridge::execute_etf_issue(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut etf_registry,
        settlement_id,
        instrument_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        etf::outstanding_units(
            &etf_registry,
            instrument_id,
        ) == 500,
        20,
    );

    assert!(
        bridge::is_settlement_consumed(
            &bridge_obj,
            settlement_id,
        ),
        21,
    );

    assert!(
        bridge::etf_issue_count(
            &bridge_obj,
        ) == 1,
        22,
    );

    bridge::destroy_admin_cap_for_testing(
        bridge_admin,
    );

    bridge::destroy_for_testing(
        bridge_obj,
    );

    settlement::destroy_admin_cap_for_testing(
        settlement_admin,
    );

    settlement::destroy_for_testing(
        settlement_registry,
    );

    etf::destroy_admin_cap_for_testing(
        etf_admin,
    );

    etf::destroy_for_testing(
        etf_registry,
    );

    regulated_asset::destroy_admin_cap_for_testing(
        asset_admin,
    );

    regulated_asset::destroy_for_testing(
        assets,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institutions,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 03
   Pending Settlement Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::regulated_asset_settlement_bridge,
)]
fun test_03_pending_settlement_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut etf_registry,
        _etf_admin,
        mut settlement_registry,
        _settlement_admin,
        mut bridge_obj,
        _bridge_admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf_fixture(
            &mut scenario,
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut settlement_registry,
            &institutions,

            issuer_id,

            settlement::settlement_asset_purchase(),

            b"AUD",
            100000,

            BENEFICIARY,
            b"PENDING-001",

            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ETF_ISSUER,
    );

    bridge::execute_etf_issue(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut etf_registry,
        settlement_id,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04
   Settlement Replay Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::regulated_asset_settlement_bridge,
)]
fun test_04_settlement_replay_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut etf_registry,
        _etf_admin,
        mut settlement_registry,
        settlement_admin,
        mut bridge_obj,
        _bridge_admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf_fixture(
            &mut scenario,
        );

    let settlement_id =
        create_finalized_settlement(
            &mut scenario,
            &access,
            &institutions,
            &mut settlement_registry,
            &settlement_admin,
            issuer_id,
            b"REPLAY-001",
        );

    test_scenario::next_tx(
        &mut scenario,
        ETF_ISSUER,
    );

    bridge::execute_etf_issue(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut etf_registry,
        settlement_id,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    bridge::execute_etf_issue(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut etf_registry,
        settlement_id,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Pause and Version
   ============================================================ */

#[test]
fun test_05_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut bridge_obj =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge::admin_cap_for_testing(
            &bridge_obj,
            test_scenario::ctx(&mut scenario),
        );

    bridge::set_paused(
        &admin,
        &mut bridge_obj,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge::is_paused(
            &bridge_obj,
        ),
        50,
    );

    bridge::set_version(
        &admin,
        &mut bridge_obj,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge::version(
            &bridge_obj,
        ) == 2,
        51,
    );

    bridge::destroy_admin_cap_for_testing(
        admin,
    );

    bridge::destroy_for_testing(
        bridge_obj,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 06
   Finalized Settlement Executes ETF Redeem
   ============================================================ */

#[test]
fun test_06_finalized_settlement_etf_redeem() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut etf_registry,
        etf_admin,
        mut settlement_registry,
        settlement_admin,
        mut bridge_obj,
        bridge_admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf_fixture(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ETF_ISSUER,
    );

    etf::issue_units(
        &access,
        &mut etf_registry,
        &institutions,
        &assets,
        instrument_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let settlement_id =
        create_finalized_settlement(
            &mut scenario,
            &access,
            &institutions,
            &mut settlement_registry,
            &settlement_admin,
            issuer_id,
            b"ETF-REDEEM-001",
        );

    test_scenario::next_tx(
        &mut scenario,
        ETF_ISSUER,
    );

    bridge::execute_etf_redeem(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut etf_registry,
        settlement_id,
        instrument_id,
        200,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        etf::outstanding_units(
            &etf_registry,
            instrument_id,
        ) == 300,
        60,
    );

    assert!(
        bridge::etf_redeem_count(
            &bridge_obj,
        ) == 1,
        61,
    );

    bridge::destroy_admin_cap_for_testing(bridge_admin);
    bridge::destroy_for_testing(bridge_obj);

    settlement::destroy_admin_cap_for_testing(settlement_admin);
    settlement::destroy_for_testing(settlement_registry);

    etf::destroy_admin_cap_for_testing(etf_admin);
    etf::destroy_for_testing(etf_registry);

    regulated_asset::destroy_admin_cap_for_testing(asset_admin);
    regulated_asset::destroy_for_testing(assets);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Finalized Settlement Executes CBDC Mint
   ============================================================ */

#[test]
fun test_07_finalized_settlement_cbdc_mint() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut institutions =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institutions,
            test_scenario::ctx(&mut scenario),
        );

    let operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"CBDC-BRIDGE-OPERATOR",
            CBDC_OPERATOR,
            institution_registry::institution_cbdc_operator(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut assets =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let asset_admin =
        regulated_asset::admin_cap_for_testing(
            &assets,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut assets,
            &asset_admin,
            &institutions,
            b"CBDC-BRIDGE-ASSET",
            b"AUDC",
            regulated_asset::asset_cbdc(),
            operator_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut cbdc_registry =
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cbdc_admin =
        cbdc::admin_cap_for_testing(
            &cbdc_registry,
            test_scenario::ctx(&mut scenario),
        );

    let instrument_id =
        cbdc::register_instrument(
            &access,
            &mut cbdc_registry,
            &cbdc_admin,
            &institutions,
            &assets,
            asset_id,
            operator_id,
            100,
            test_scenario::ctx(&mut scenario),
        );

    let mut settlement_registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin =
        settlement::admin_cap_for_testing(
            &settlement_registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut settlement_registry,
            &institutions,
            operator_id,
            settlement::settlement_asset_purchase(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"CBDC-MINT-001",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        CBDC_OPERATOR,
    );

    settlement::confirm_settlement(
        &access,
        &mut settlement_registry,
        &institutions,
        settlement_id,
        operator_id,
        b"CBDC-CONFIRM",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    settlement::finalize_settlement(
        &access,
        &mut settlement_registry,
        &settlement_admin,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    let mut bridge_obj =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let bridge_admin =
        bridge::admin_cap_for_testing(
            &bridge_obj,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        CBDC_OPERATOR,
    );

    bridge::execute_cbdc_mint(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut cbdc_registry,
        settlement_id,
        instrument_id,
        1000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cbdc::circulating_supply(
            &cbdc_registry,
            instrument_id,
        ) == 1000,
        70,
    );

    assert!(
        bridge::cbdc_mint_count(
            &bridge_obj,
        ) == 1,
        71,
    );

    bridge::destroy_admin_cap_for_testing(bridge_admin);
    bridge::destroy_for_testing(bridge_obj);

    settlement::destroy_admin_cap_for_testing(settlement_admin);
    settlement::destroy_for_testing(settlement_registry);

    cbdc::destroy_admin_cap_for_testing(cbdc_admin);
    cbdc::destroy_for_testing(cbdc_registry);

    regulated_asset::destroy_admin_cap_for_testing(asset_admin);
    regulated_asset::destroy_for_testing(assets);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08
   Finalized Settlement Executes CBDC Burn
   ============================================================ */

#[test]
fun test_08_finalized_settlement_cbdc_burn() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut institutions =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institutions,
            test_scenario::ctx(&mut scenario),
        );

    let operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"CBDC-BURN-OPERATOR",
            CBDC_OPERATOR,
            institution_registry::institution_cbdc_operator(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut assets =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let asset_admin =
        regulated_asset::admin_cap_for_testing(
            &assets,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut assets,
            &asset_admin,
            &institutions,
            b"CBDC-BURN-ASSET",
            b"AUDC",
            regulated_asset::asset_cbdc(),
            operator_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut cbdc_registry =
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cbdc_admin =
        cbdc::admin_cap_for_testing(
            &cbdc_registry,
            test_scenario::ctx(&mut scenario),
        );

    let instrument_id =
        cbdc::register_instrument(
            &access,
            &mut cbdc_registry,
            &cbdc_admin,
            &institutions,
            &assets,
            asset_id,
            operator_id,
            100,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        CBDC_OPERATOR,
    );

    cbdc::mint(
        &access,
        &mut cbdc_registry,
        &institutions,
        &assets,
        instrument_id,
        1000,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let mut settlement_registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin =
        settlement::admin_cap_for_testing(
            &settlement_registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut settlement_registry,
            &institutions,
            operator_id,
            settlement::settlement_asset_redemption(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"CBDC-BURN-001",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        CBDC_OPERATOR,
    );

    settlement::confirm_settlement(
        &access,
        &mut settlement_registry,
        &institutions,
        settlement_id,
        operator_id,
        b"CBDC-BURN-CONFIRM",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    settlement::finalize_settlement(
        &access,
        &mut settlement_registry,
        &settlement_admin,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    let mut bridge_obj =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let bridge_admin =
        bridge::admin_cap_for_testing(
            &bridge_obj,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        CBDC_OPERATOR,
    );

    bridge::execute_cbdc_burn(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut cbdc_registry,
        settlement_id,
        instrument_id,
        400,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cbdc::circulating_supply(
            &cbdc_registry,
            instrument_id,
        ) == 600,
        80,
    );

    assert!(
        bridge::cbdc_burn_count(
            &bridge_obj,
        ) == 1,
        81,
    );

    bridge::destroy_admin_cap_for_testing(bridge_admin);
    bridge::destroy_for_testing(bridge_obj);

    settlement::destroy_admin_cap_for_testing(settlement_admin);
    settlement::destroy_for_testing(settlement_registry);

    cbdc::destroy_admin_cap_for_testing(cbdc_admin);
    cbdc::destroy_for_testing(cbdc_registry);

    regulated_asset::destroy_admin_cap_for_testing(asset_admin);
    regulated_asset::destroy_for_testing(assets);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 09
   Zero Amount Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::regulated_asset_settlement_bridge,
)]
fun test_09_zero_amount_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut etf_registry,
        _etf_admin,
        mut settlement_registry,
        settlement_admin,
        mut bridge_obj,
        _bridge_admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf_fixture(
            &mut scenario,
        );

    let settlement_id =
        create_finalized_settlement(
            &mut scenario,
            &access,
            &institutions,
            &mut settlement_registry,
            &settlement_admin,
            issuer_id,
            b"ZERO-AMOUNT-BRIDGE",
        );

    test_scenario::next_tx(
        &mut scenario,
        ETF_ISSUER,
    );

    bridge::execute_etf_issue(
        &access,
        &mut bridge_obj,
        &settlement_registry,
        &institutions,
        &assets,
        &mut etf_registry,
        settlement_id,
        instrument_id,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Wrong Admin Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::regulated_asset_settlement_bridge,
)]
fun test_10_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut bridge_a =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let bridge_b =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        bridge::admin_cap_for_testing(
            &bridge_b,
            test_scenario::ctx(&mut scenario),
        );

    bridge::set_paused(
        &admin_b,
        &mut bridge_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11
   Operation Accounting Invariant
   ============================================================ */

#[test]
fun test_11_operation_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let bridge_obj =
        bridge::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        bridge::total_consumed(
            &bridge_obj,
        )
            == bridge::etf_issue_count(&bridge_obj)
             + bridge::etf_redeem_count(&bridge_obj)
             + bridge::cbdc_mint_count(&bridge_obj)
             + bridge::cbdc_burn_count(&bridge_obj),
        110,
    );

    bridge::destroy_for_testing(
        bridge_obj,
    );

    test_scenario::end(
        scenario,
    );
}
