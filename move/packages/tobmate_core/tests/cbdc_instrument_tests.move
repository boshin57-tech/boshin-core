#[test_only]
module tobmate_core::cbdc_instrument_tests;

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

use tobmate_core::cbdc_instrument::{
    Self as cbdc,
};


const ADMIN: address = @0xA11CE;
const OPERATOR: address = @0xCB01;
const OTHER: address = @0xCB02;


/* ============================================================
   Fixture
   ============================================================ */

fun setup_cbdc(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,

    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,

    regulated_asset::RegulatedAssetRegistry,
    regulated_asset::RegulatedAssetAdminCap,

    cbdc::CBDCInstrumentRegistry,
    cbdc::CBDCInstrumentAdminCap,

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

    let operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,

            b"CBDC-OPERATOR-001",
            OPERATOR,

            institution_registry::institution_cbdc_operator(),

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

            b"CBDC-AU-001",
            b"AUDC",

            regulated_asset::asset_cbdc(),

            operator_id,

            b"AU",

            test_scenario::ctx(scenario),
        );

    let mut registry =
        cbdc::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let admin =
        cbdc::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(scenario),
        );

    let instrument_id =
        cbdc::register_instrument(
            &access,
            &mut registry,
            &admin,
            &institutions,
            &assets,
            asset_id,
            operator_id,
            100,
            test_scenario::ctx(scenario),
        );

    (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        registry,
        admin,
        operator_id,
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
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(cbdc::version(&registry) == 1, 10);
    assert!(!cbdc::is_paused(&registry), 11);
    assert!(cbdc::total_instruments(&registry) == 0, 12);

    cbdc::destroy_for_testing(registry);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   CBDC Instrument Registration
   ============================================================ */

#[test]
fun test_02_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        registry,
        admin,
        operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    assert!(instrument_id == 1, 20);

    assert!(
        cbdc::instrument_status(
            &registry,
            instrument_id,
        ) == cbdc::status_active(),
        21,
    );

    assert!(
        cbdc::operator_institution_id(
            &registry,
            instrument_id,
        ) == operator_id,
        22,
    );

    assert!(
        cbdc::circulating_supply(
            &registry,
            instrument_id,
        ) == 0,
        23,
    );

    cbdc::destroy_admin_cap_for_testing(admin);
    cbdc::destroy_for_testing(registry);

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
   Test 03
   Non-CBDC Asset Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::cbdc_instrument,
)]
fun test_03_non_cbdc_asset_rejected() {
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
            b"ETF-ISSUER",
            OPERATOR,
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
            b"ETF-ASSET",
            b"ETF",
            regulated_asset::asset_etf(),
            operator_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cbdc::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    cbdc::register_instrument(
        &access,
        &mut registry,
        &admin,
        &institutions,
        &assets,
        asset_id,
        operator_id,
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
    location = tobmate_core::cbdc_instrument,
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
        operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    let asset_id =
        cbdc::instrument_regulated_asset_id(
            &registry,
            instrument_id,
        );

    cbdc::register_instrument(
        &access,
        &mut registry,
        &admin,
        &institutions,
        &assets,
        asset_id,
        operator_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Successful Mint
   ============================================================ */

#[test]
fun test_05_mint_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut registry,
        admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::mint(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        1000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cbdc::total_minted(
            &registry,
            instrument_id,
        ) == 1000,
        50,
    );

    assert!(
        cbdc::circulating_supply(
            &registry,
            instrument_id,
        ) == 1000,
        51,
    );

    cbdc::destroy_admin_cap_for_testing(admin);
    cbdc::destroy_for_testing(registry);

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
   Test 06
   Unauthorized Mint Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::cbdc_instrument,
)]
fun test_06_unauthorized_mint_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    cbdc::mint(
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
   Test 07
   Successful Burn
   ============================================================ */

#[test]
fun test_07_burn_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut registry,
        admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::mint(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        1000,
        test_scenario::ctx(&mut scenario),
    );

    cbdc::burn(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        400,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cbdc::total_minted(
            &registry,
            instrument_id,
        ) == 1000,
        70,
    );

    assert!(
        cbdc::total_burned(
            &registry,
            instrument_id,
        ) == 400,
        71,
    );

    assert!(
        cbdc::circulating_supply(
            &registry,
            instrument_id,
        ) == 600,
        72,
    );

    cbdc::destroy_admin_cap_for_testing(admin);
    cbdc::destroy_for_testing(registry);

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
   Over Burn Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::cbdc_instrument,
)]
fun test_08_over_burn_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::mint(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        100,
        test_scenario::ctx(&mut scenario),
    );

    cbdc::burn(
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
   Test 09
   Zero Mint Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::cbdc_instrument,
)]
fun test_09_zero_mint_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::mint(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Zero Burn Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::cbdc_instrument,
)]
fun test_10_zero_burn_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        assets,
        _asset_admin,
        mut registry,
        _admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::burn(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11
   Suspended Instrument Blocks Mint
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::cbdc_instrument,
)]
fun test_11_suspended_instrument_blocks_mint() {
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
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    cbdc::set_instrument_status(
        &access,
        &mut registry,
        &admin,
        instrument_id,
        cbdc::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::mint(
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
    location = tobmate_core::cbdc_instrument,
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
        admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    cbdc::set_instrument_status(
        &access,
        &mut registry,
        &admin,
        instrument_id,
        cbdc::status_retired(),
        test_scenario::ctx(&mut scenario),
    );

    cbdc::set_instrument_status(
        &access,
        &mut registry,
        &admin,
        instrument_id,
        cbdc::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13
   Inactive Regulated Asset Blocks Mint
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_13_inactive_asset_blocks_mint() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        mut assets,
        asset_admin,
        mut registry,
        _admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    let asset_id =
        cbdc::instrument_regulated_asset_id(
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
        OPERATOR,
    );

    cbdc::mint(
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
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cbdc::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    cbdc::set_paused(
        &admin,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cbdc::is_paused(
            &registry,
        ),
        140,
    );

    cbdc::set_version(
        &admin,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cbdc::version(
            &registry,
        ) == 2,
        141,
    );

    cbdc::destroy_admin_cap_for_testing(
        admin,
    );

    cbdc::destroy_for_testing(
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
    location = tobmate_core::cbdc_instrument,
)]
fun test_15_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry_a =
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        cbdc::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        cbdc::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    cbdc::set_paused(
        &admin_b,
        &mut registry_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 16
   Circulation Accounting Invariant
   ============================================================ */

#[test]
fun test_16_circulation_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        assets,
        asset_admin,
        mut registry,
        admin,
        _operator_id,
        instrument_id,
    ) =
        setup_cbdc(&mut scenario);

    test_scenario::next_tx(
        &mut scenario,
        OPERATOR,
    );

    cbdc::mint(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        1000,
        test_scenario::ctx(&mut scenario),
    );

    cbdc::burn(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        300,
        test_scenario::ctx(&mut scenario),
    );

    cbdc::mint(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    cbdc::burn(
        &access,
        &mut registry,
        &institutions,
        &assets,
        instrument_id,
        200,
        test_scenario::ctx(&mut scenario),
    );

    let minted =
        cbdc::total_minted(
            &registry,
            instrument_id,
        );

    let burned =
        cbdc::total_burned(
            &registry,
            instrument_id,
        );

    let circulating =
        cbdc::circulating_supply(
            &registry,
            instrument_id,
        );

    assert!(
        minted == 1500,
        160,
    );

    assert!(
        burned == 500,
        161,
    );

    assert!(
        circulating == 1000,
        162,
    );

    assert!(
        circulating == minted - burned,
        163,
    );

    cbdc::destroy_admin_cap_for_testing(
        admin,
    );

    cbdc::destroy_for_testing(
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
