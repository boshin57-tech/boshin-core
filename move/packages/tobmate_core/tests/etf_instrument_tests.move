#[test_only]
module tobmate_core::etf_instrument_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::institution_registry::{
    Self as institution_registry,
};

use tobmate_core::regulated_asset_registry::{
    Self as regulated_asset,
};

use tobmate_core::etf_instrument::{
    Self as etf,
};


const ADMIN: address = @0xA11CE;
const ISSUER: address = @0xE710;
const OTHER: address = @0xBEEF;


/* ============================================================
   Fixture
   ============================================================ */

fun setup_etf(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,

    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,

    regulated_asset::RegulatedAssetRegistry,
    regulated_asset::RegulatedAssetAdminCap,

    etf::ETFInstrumentRegistry,
    etf::ETFInstrumentAdminCap,

    u64,
    u64,
) {
    let access =
        access_control::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let mut institution_registry_obj =
        institution_registry::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institution_registry_obj,
            test_scenario::ctx(scenario),
        );

    let issuer_id =
        institution_registry::register_institution(
            &access,
            &mut institution_registry_obj,
            &institution_admin,

            b"ETF-ISSUER-001",
            ISSUER,

            institution_registry::institution_etf_issuer(),

            b"AU",

            test_scenario::ctx(scenario),
        );

    let mut asset_registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let asset_admin =
        regulated_asset::admin_cap_for_testing(
            &asset_registry,
            test_scenario::ctx(scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,

            &mut asset_registry,
            &asset_admin,

            &institution_registry_obj,

            b"ETF-AU-GOLD-001",
            b"TOBGOLD",

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

            &institution_registry_obj,
            &asset_registry,

            asset_id,
            issuer_id,

            100,

            test_scenario::ctx(scenario),
        );

    (
        access,

        institution_registry_obj,
        institution_admin,

        asset_registry,
        asset_admin,

        etf_registry,
        etf_admin,

        issuer_id,
        instrument_id,
    )
}


/* ============================================================
   Test 01
   Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        etf::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        etf::version(&registry) == 1,
        10,
    );

    assert!(
        !etf::is_paused(&registry),
        11,
    );

    assert!(
        etf::total_instruments(&registry) == 0,
        12,
    );

    assert!(
        etf::active_instrument_count(&registry) == 0,
        13,
    );

    etf::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 02
   ETF Instrument Registration
   ============================================================ */

#[test]
fun test_02_instrument_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        asset_registry,
        asset_admin,
        etf_registry,
        etf_admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    assert!(
        instrument_id == 1,
        20,
    );

    assert!(
        etf::instrument_status(
            &etf_registry,
            instrument_id,
        ) == etf::status_active(),
        21,
    );

    assert!(
        etf::instrument_issuer_institution_id(
            &etf_registry,
            instrument_id,
        ) == issuer_id,
        22,
    );

    assert!(
        etf::creation_unit_size(
            &etf_registry,
            instrument_id,
        ) == 100,
        23,
    );

    assert!(
        etf::outstanding_units(
            &etf_registry,
            instrument_id,
        ) == 0,
        24,
    );

    etf::assert_instrument_active(
        &etf_registry,
        instrument_id,
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
        asset_registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
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
   Non-ETF Asset Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::etf_instrument,
)]
fun test_03_non_etf_asset_rejected() {
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

    let issuer_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"CBDC-OPERATOR",
            ISSUER,
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

            b"CBDC-AU",
            b"AUDC",

            regulated_asset::asset_cbdc(),

            issuer_id,
            b"AU",

            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        etf::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        etf::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    etf::register_instrument(
        &access,
        &mut registry,
        &admin,
        &institutions,
        &assets,
        asset_id,
        issuer_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04
   Duplicate Instrument Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::etf_instrument,
)]
fun test_04_duplicate_instrument_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        admin,
        issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    let asset_id =
        etf::instrument_regulated_asset_id(
            &registry,
            instrument_id,
        );

    etf::register_instrument(
        &access,
        &mut registry,
        &admin,
        &institutions,
        &assets,
        asset_id,
        issuer_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Zero Creation Unit Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::etf_instrument,
)]
fun test_05_zero_creation_unit_rejected() {
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

    let issuer_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"ETF-ZERO-ISSUER",
            ISSUER,
            institution_registry::institution_etf_issuer(),
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
            b"ETF-ZERO",
            b"ZERO",
            regulated_asset::asset_etf(),
            issuer_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        etf::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        etf::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    etf::register_instrument(
        &access,
        &mut registry,
        &admin,
        &institutions,
        &assets,
        asset_id,
        issuer_id,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06
   Successful Issue Accounting
   ============================================================ */

#[test]
fun test_06_issue_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut registry,
        etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        etf::total_issued_units(
            &registry,
            instrument_id,
        ) == 500,
        60,
    );

    assert!(
        etf::total_redeemed_units(
            &registry,
            instrument_id,
        ) == 0,
        61,
    );

    assert!(
        etf::outstanding_units(
            &registry,
            instrument_id,
        ) == 500,
        62,
    );

    etf::destroy_admin_cap_for_testing(
        etf_admin,
    );

    etf::destroy_for_testing(
        registry,
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
   Test 07
   Unauthorized Issuer Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::etf_instrument,
)]
fun test_07_unauthorized_issuer_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08
   Creation Unit Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::etf_instrument,
)]
fun test_08_creation_unit_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        150,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Successful Redemption Accounting
   ============================================================ */

#[test]
fun test_09_redeem_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut registry,
        etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    etf::redeem_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        200,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        etf::total_issued_units(
            &registry,
            instrument_id,
        ) == 500,
        90,
    );

    assert!(
        etf::total_redeemed_units(
            &registry,
            instrument_id,
        ) == 200,
        91,
    );

    assert!(
        etf::outstanding_units(
            &registry,
            instrument_id,
        ) == 300,
        92,
    );

    etf::destroy_admin_cap_for_testing(
        etf_admin,
    );

    etf::destroy_for_testing(
        registry,
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
   Test 10
   Over Redemption Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::etf_instrument,
)]
fun test_10_over_redemption_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    etf::redeem_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        200,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11
   Suspended Instrument Blocks Issuance
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::etf_instrument,
)]
fun test_11_suspended_instrument_blocks_issue() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    etf::set_instrument_status(
        &access,
        &mut registry,
        &etf_admin,
        instrument_id,
        etf::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Retired Instrument Is Terminal
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::etf_instrument,
)]
fun test_12_retired_instrument_terminal() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        _assets,
        _asset_admin,
        mut registry,
        etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    etf::set_instrument_status(
        &access,
        &mut registry,
        &etf_admin,
        instrument_id,
        etf::status_retired(),
        test_scenario::ctx(&mut scenario),
    );

    etf::set_instrument_status(
        &access,
        &mut registry,
        &etf_admin,
        instrument_id,
        etf::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13
   Inactive Regulated Asset Blocks Issuance
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_13_inactive_asset_blocks_issue() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        mut assets,
        asset_admin,
        mut registry,
        _etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    let asset_id =
        etf::instrument_regulated_asset_id(
            &registry,
            instrument_id,
        );

    regulated_asset::set_asset_status(
        &access,
        &mut assets,
        &asset_admin,
        asset_id,
        regulated_asset::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14
   Pause and Version
   ============================================================ */

#[test]
fun test_14_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        etf::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        etf::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    etf::set_paused(
        &admin,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        etf::is_paused(
            &registry,
        ),
        140,
    );

    etf::set_version(
        &admin,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        etf::version(
            &registry,
        ) == 2,
        141,
    );

    etf::destroy_admin_cap_for_testing(
        admin,
    );

    etf::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 15
   Wrong Admin Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::etf_instrument,
)]
fun test_15_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry_a =
        etf::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        etf::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        etf::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    etf::set_instrument_status(
        &access,
        &mut registry_a,
        &admin_b,
        1,
        etf::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 16
   Supply Accounting Invariant
   ============================================================ */

#[test]
fun test_16_supply_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut registry,
        etf_admin,
        _issuer_id,
        instrument_id,
    ) =
        setup_etf(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ISSUER,
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        1000,
        test_scenario::ctx(&mut scenario),
    );

    etf::redeem_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        300,
        test_scenario::ctx(&mut scenario),
    );

    etf::issue_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    etf::redeem_units(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        200,
        test_scenario::ctx(&mut scenario),
    );

    let issued =
        etf::total_issued_units(
            &registry,
            instrument_id,
        );

    let redeemed =
        etf::total_redeemed_units(
            &registry,
            instrument_id,
        );

    let outstanding =
        etf::outstanding_units(
            &registry,
            instrument_id,
        );

    assert!(
        issued == 1500,
        160,
    );

    assert!(
        redeemed == 500,
        161,
    );

    assert!(
        outstanding == 1000,
        162,
    );

    assert!(
        outstanding == issued - redeemed,
        163,
    );

    etf::destroy_admin_cap_for_testing(
        etf_admin,
    );

    etf::destroy_for_testing(
        registry,
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
