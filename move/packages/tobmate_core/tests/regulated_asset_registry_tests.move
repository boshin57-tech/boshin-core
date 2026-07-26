#[test_only]
module tobmate_core::regulated_asset_registry_tests;

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


const ADMIN: address = @0xA11CE;
const ISSUER: address = @0xE710;


/* ============================================================
   Institution Fixture
   ============================================================ */

fun setup_issuer(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,
    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,
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

    (
        access,
        institution_registry_obj,
        institution_admin,
        issuer_id,
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
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        regulated_asset::version(&registry) == 1,
        10,
    );

    assert!(
        !regulated_asset::is_paused(&registry),
        11,
    );

    assert!(
        regulated_asset::total_assets(&registry) == 0,
        12,
    );

    assert!(
        regulated_asset::active_asset_count(&registry) == 0,
        13,
    );

    regulated_asset::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   ETF Registration
   ============================================================ */

#[test]
fun test_02_etf_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,

            b"ETF-AU-001",
            b"TOBETF",

            regulated_asset::asset_etf(),
            issuer_id,

            b"AU",

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        asset_id == 1,
        20,
    );

    assert!(
        regulated_asset::asset_status(
            &registry,
            asset_id,
        ) == regulated_asset::status_active(),
        21,
    );

    assert!(
        regulated_asset::asset_class(
            &registry,
            asset_id,
        ) == regulated_asset::asset_etf(),
        22,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            &registry,
            asset_id,
        ) == issuer_id,
        23,
    );

    assert!(
        regulated_asset::asset_issuer_authority(
            &registry,
            asset_id,
        ) == ISSUER,
        24,
    );

    regulated_asset::assert_asset_active(
        &registry,
        asset_id,
    );

    regulated_asset::destroy_admin_cap_for_testing(
        admin_cap,
    );

    regulated_asset::destroy_for_testing(
        registry,
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

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   CBDC Registration
   ============================================================ */

#[test]
fun test_03_cbdc_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,

            b"CBDC-AU-001",
            b"AUD-CBDC",

            regulated_asset::asset_cbdc(),
            issuer_id,

            b"AU",

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        regulated_asset::asset_class(
            &registry,
            asset_id,
        ) == regulated_asset::asset_cbdc(),
        30,
    );

    regulated_asset::destroy_admin_cap_for_testing(
        admin_cap,
    );

    regulated_asset::destroy_for_testing(
        registry,
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

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Duplicate Asset Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_04_duplicate_asset_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::register_asset(
        &access,
        &mut registry,
        &admin_cap,
        &institution_registry_obj,
        b"DUPLICATE-ASSET",
        b"ETF1",
        regulated_asset::asset_etf(),
        issuer_id,
        b"AU",
        test_scenario::ctx(&mut scenario),
    );

    regulated_asset::register_asset(
        &access,
        &mut registry,
        &admin_cap,
        &institution_registry_obj,
        b"DUPLICATE-ASSET",
        b"ETF2",
        regulated_asset::asset_etf(),
        issuer_id,
        b"AU",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Invalid Asset Class Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_05_invalid_asset_class_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::register_asset(
        &access,
        &mut registry,
        &admin_cap,
        &institution_registry_obj,
        b"BAD-CLASS",
        b"BAD",
        99,
        issuer_id,
        b"AU",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06
   Suspend / Reactivate Lifecycle
   ============================================================ */

#[test]
fun test_06_suspend_reactivate() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,
            b"ETF-LIFECYCLE",
            b"LIFE",
            regulated_asset::asset_etf(),
            issuer_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        asset_id,
        regulated_asset::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        regulated_asset::suspended_asset_count(
            &registry,
        ) == 1,
        60,
    );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        asset_id,
        regulated_asset::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        regulated_asset::active_asset_count(
            &registry,
        ) == 1,
        61,
    );

    regulated_asset::destroy_admin_cap_for_testing(
        admin_cap,
    );

    regulated_asset::destroy_for_testing(
        registry,
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

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Inactive Issuer Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::institution_registry,
)]
fun test_07_inactive_issuer_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        mut institution_registry_obj,
        institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    institution_registry::set_institution_active(
        &access,
        &mut institution_registry_obj,
        &institution_admin,
        issuer_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::register_asset(
        &access,
        &mut registry,
        &admin_cap,
        &institution_registry_obj,

        b"INACTIVE-ISSUER",
        b"STOP",

        regulated_asset::asset_etf(),
        issuer_id,

        b"AU",

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08
   Retired Asset Is Terminal
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_08_retired_asset_terminal() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,

            b"RETIRE-ASSET",
            b"RET",

            regulated_asset::asset_security_token(),
            issuer_id,

            b"AU",

            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        asset_id,
        regulated_asset::status_retired(),
        test_scenario::ctx(&mut scenario),
    );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        asset_id,
        regulated_asset::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Inactive Asset Assertion Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_09_inactive_asset_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let asset_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,

            b"SUSPENDED-ASSET",
            b"SUSP",

            regulated_asset::asset_cbdc(),
            issuer_id,

            b"AU",

            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        asset_id,
        regulated_asset::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    regulated_asset::assert_asset_active(
        &registry,
        asset_id,
    );

    abort 999
}


/* ============================================================
   Test 10
   Pause and Version
   ============================================================ */

#[test]
fun test_10_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        regulated_asset::is_paused(
            &registry,
        ),
        100,
    );

    regulated_asset::set_version(
        &admin_cap,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        regulated_asset::version(
            &registry,
        ) == 2,
        101,
    );

    regulated_asset::destroy_admin_cap_for_testing(
        admin_cap,
    );

    regulated_asset::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 11
   Wrong Admin Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::regulated_asset_registry,
)]
fun test_11_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry_a =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        regulated_asset::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    regulated_asset::register_asset(
        &access,
        &mut registry_a,
        &admin_b,
        &institution_registry_obj,

        b"WRONG-ADMIN",
        b"BAD",

        regulated_asset::asset_etf(),
        issuer_id,

        b"AU",

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Multi-Asset Accounting Invariant
   ============================================================ */

#[test]
fun test_12_multi_asset_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        issuer_id,
    ) =
        setup_issuer(
            &mut scenario,
        );

    let mut registry =
        regulated_asset::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        regulated_asset::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let etf_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,
            b"ASSET-ETF",
            b"ETF",
            regulated_asset::asset_etf(),
            issuer_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let cbdc_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,
            b"ASSET-CBDC",
            b"CBDC",
            regulated_asset::asset_cbdc(),
            issuer_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let bond_id =
        regulated_asset::register_asset(
            &access,
            &mut registry,
            &admin_cap,
            &institution_registry_obj,
            b"ASSET-BOND",
            b"BOND",
            regulated_asset::asset_bond(),
            issuer_id,
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        etf_id == 1
            && cbdc_id == 2
            && bond_id == 3,
        120,
    );

    assert!(
        regulated_asset::total_assets(
            &registry,
        ) == 3,
        121,
    );

    assert!(
        regulated_asset::active_asset_count(
            &registry,
        ) == 3,
        122,
    );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        cbdc_id,
        regulated_asset::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    regulated_asset::set_asset_status(
        &access,
        &mut registry,
        &admin_cap,
        bond_id,
        regulated_asset::status_retired(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        regulated_asset::total_assets(
            &registry,
        ) == 3,
        123,
    );

    assert!(
        regulated_asset::active_asset_count(
            &registry,
        ) == 1,
        124,
    );

    assert!(
        regulated_asset::suspended_asset_count(
            &registry,
        ) == 1,
        125,
    );

    assert!(
        regulated_asset::retired_asset_count(
            &registry,
        ) == 1,
        126,
    );

    regulated_asset::assert_asset_active(
        &registry,
        etf_id,
    );

    regulated_asset::destroy_admin_cap_for_testing(
        admin_cap,
    );

    regulated_asset::destroy_for_testing(
        registry,
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
