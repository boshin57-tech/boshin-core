#[test_only]
module tobmate_core::external_network_registry_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::institution_registry::{
    Self as institution_registry,
};

use tobmate_core::external_network_registry::{
    Self as external_network,
};


const ADMIN: address = @0xA11CE;
const OPERATOR: address = @0xE001;


/* ============================================================
   Fixture
   ============================================================ */

fun setup_operator(
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

            b"EXTERNAL-NETWORK-OPERATOR",
            OPERATOR,

            institution_registry::institution_payment_provider(),

            b"AU",

            test_scenario::ctx(scenario),
        );

    (
        access,
        institutions,
        institution_admin,
        operator_id,
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
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        external_network::version(&registry) == 1,
        10,
    );

    assert!(
        !external_network::is_paused(&registry),
        11,
    );

    assert!(
        external_network::total_networks(&registry) == 0,
        12,
    );

    assert!(
        external_network::active_network_count(&registry) == 0,
        13,
    );

    external_network::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Blockchain Network Registration
   ============================================================ */

#[test]
fun test_02_blockchain_network_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        operator_id,
    ) =
        setup_operator(&mut scenario);

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let network_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,

            b"SUI-MAINNET",
            b"sui:mainnet",

            external_network::network_blockchain(),
            operator_id,

            test_scenario::ctx(&mut scenario),
        );

    assert!(network_id == 1, 20);

    assert!(
        external_network::network_type(
            &registry,
            network_id,
        ) == external_network::network_blockchain(),
        21,
    );

    assert!(
        external_network::operator_institution_id(
            &registry,
            network_id,
        ) == operator_id,
        22,
    );

    assert!(
        external_network::operator_authority(
            &registry,
            network_id,
        ) == OPERATOR,
        23,
    );

    external_network::assert_network_active(
        &registry,
        network_id,
    );

    external_network::destroy_admin_cap_for_testing(admin);
    external_network::destroy_for_testing(registry);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   Bank Rail Registration
   ============================================================ */

#[test]
fun test_03_bank_rail_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        operator_id,
    ) =
        setup_operator(&mut scenario);

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let network_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,

            b"AU-BANK-RAIL",
            b"bank:au",

            external_network::network_bank_rail(),
            operator_id,

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        external_network::network_type(
            &registry,
            network_id,
        ) == external_network::network_bank_rail(),
        30,
    );

    external_network::destroy_admin_cap_for_testing(admin);
    external_network::destroy_for_testing(registry);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Duplicate Network Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::external_network_registry,
)]
fun test_04_duplicate_network_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        operator_id,
    ) =
        setup_operator(&mut scenario);

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    external_network::register_network(
        &access,
        &mut registry,
        &admin,
        &institutions,
        b"DUP-NET",
        b"domain:a",
        external_network::network_blockchain(),
        operator_id,
        test_scenario::ctx(&mut scenario),
    );

    external_network::register_network(
        &access,
        &mut registry,
        &admin,
        &institutions,
        b"DUP-NET",
        b"domain:b",
        external_network::network_bank_rail(),
        operator_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Invalid Network Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::external_network_registry,
)]
fun test_05_invalid_network_type_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        operator_id,
    ) =
        setup_operator(&mut scenario);

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    external_network::register_network(
        &access,
        &mut registry,
        &admin,
        &institutions,
        b"BAD-NET",
        b"bad:domain",
        99,
        operator_id,
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
        institutions,
        institution_admin,
        operator_id,
    ) =
        setup_operator(&mut scenario);

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let network_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,

            b"LIFECYCLE-NET",
            b"network:lifecycle",

            external_network::network_custodian_rail(),
            operator_id,

            test_scenario::ctx(&mut scenario),
        );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        network_id,
        external_network::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        external_network::suspended_network_count(
            &registry,
        ) == 1,
        60,
    );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        network_id,
        external_network::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        external_network::active_network_count(
            &registry,
        ) == 1,
        61,
    );

    external_network::destroy_admin_cap_for_testing(admin);
    external_network::destroy_for_testing(registry);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Inactive Operator Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::institution_registry,
)]
fun test_07_inactive_operator_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        mut institutions,
        institution_admin,
        operator_id,
    ) =
        setup_operator(
            &mut scenario,
        );

    institution_registry::set_institution_active(
        &access,
        &mut institutions,
        &institution_admin,
        operator_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    external_network::register_network(
        &access,
        &mut registry,
        &admin,
        &institutions,

        b"INACTIVE-OPERATOR",
        b"network:inactive-operator",

        external_network::network_bank_rail(),
        operator_id,

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08
   Inactive Network Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::external_network_registry,
)]
fun test_08_inactive_network_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        operator_id,
    ) =
        setup_operator(
            &mut scenario,
        );

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let network_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,

            b"INACTIVE-NETWORK",
            b"network:inactive",

            external_network::network_blockchain(),
            operator_id,

            test_scenario::ctx(&mut scenario),
        );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        network_id,
        external_network::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    external_network::assert_network_active(
        &registry,
        network_id,
    );

    abort 999
}


/* ============================================================
   Test 09
   Retired Network Is Terminal
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::external_network_registry,
)]
fun test_09_retired_network_terminal() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        _institution_admin,
        operator_id,
    ) =
        setup_operator(
            &mut scenario,
        );

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let network_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,

            b"RETIRE-NETWORK",
            b"network:retire",

            external_network::network_clearing_network(),
            operator_id,

            test_scenario::ctx(&mut scenario),
        );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        network_id,
        external_network::status_retired(),
        test_scenario::ctx(&mut scenario),
    );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        network_id,
        external_network::status_active(),
        test_scenario::ctx(&mut scenario),
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
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    external_network::set_paused(
        &admin,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        external_network::is_paused(
            &registry,
        ),
        100,
    );

    external_network::set_version(
        &admin,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        external_network::version(
            &registry,
        ) == 2,
        101,
    );

    external_network::destroy_admin_cap_for_testing(
        admin,
    );

    external_network::destroy_for_testing(
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
    abort_code = 10,
    location = tobmate_core::external_network_registry,
)]
fun test_11_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry_a =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        external_network::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    external_network::set_paused(
        &admin_b,
        &mut registry_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Multi-Network Accounting Invariant
   ============================================================ */

#[test]
fun test_12_multi_network_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        operator_id,
    ) =
        setup_operator(
            &mut scenario,
        );

    let mut registry =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        external_network::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let blockchain_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,
            b"CHAIN-001",
            b"chain:001",
            external_network::network_blockchain(),
            operator_id,
            test_scenario::ctx(&mut scenario),
        );

    let bank_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,
            b"BANK-001",
            b"bank:001",
            external_network::network_bank_rail(),
            operator_id,
            test_scenario::ctx(&mut scenario),
        );

    let cbdc_id =
        external_network::register_network(
            &access,
            &mut registry,
            &admin,
            &institutions,
            b"CBDC-001",
            b"cbdc:001",
            external_network::network_cbdc_network(),
            operator_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        blockchain_id == 1
            && bank_id == 2
            && cbdc_id == 3,
        120,
    );

    assert!(
        external_network::total_networks(
            &registry,
        ) == 3,
        121,
    );

    assert!(
        external_network::active_network_count(
            &registry,
        ) == 3,
        122,
    );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        bank_id,
        external_network::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    external_network::set_network_status(
        &access,
        &mut registry,
        &admin,
        cbdc_id,
        external_network::status_retired(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        external_network::total_networks(
            &registry,
        ) == 3,
        123,
    );

    assert!(
        external_network::active_network_count(
            &registry,
        ) == 1,
        124,
    );

    assert!(
        external_network::suspended_network_count(
            &registry,
        ) == 1,
        125,
    );

    assert!(
        external_network::retired_network_count(
            &registry,
        ) == 1,
        126,
    );

    external_network::assert_network_active(
        &registry,
        blockchain_id,
    );

    external_network::destroy_admin_cap_for_testing(
        admin,
    );

    external_network::destroy_for_testing(
        registry,
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
