#[test_only]
module tobmate_integration_tests::cross_network_settlement_intent_tests;

use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::institution_registry::{
    Self as institution_registry,
};

use tobmate_enterprise_security::external_network_registry::{
    Self as external_network,
};

use tobmate_enterprise_security::cross_network_settlement_intent::{
    Self as cross_intent,
};


const ADMIN: address = @0xA11CE;
const SOURCE_OPERATOR: address = @0xE101;
const DEST_OPERATOR: address = @0xE102;
const OTHER: address = @0xE103;
const BENEFICIARY: address = @0xC001;


/* ============================================================
   Fixture
   ============================================================ */

fun setup_networks(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,
    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,
    external_network::ExternalNetworkRegistry,
    external_network::ExternalNetworkAdminCap,
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

    let source_operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"SOURCE-OPERATOR",
            SOURCE_OPERATOR,
            institution_registry::institution_payment_provider(),
            b"AU",
            test_scenario::ctx(scenario),
        );

    let dest_operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"DEST-OPERATOR",
            DEST_OPERATOR,
            institution_registry::institution_payment_provider(),
            b"US",
            test_scenario::ctx(scenario),
        );

    let mut networks =
        external_network::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let network_admin =
        external_network::admin_cap_for_testing(
            &networks,
            test_scenario::ctx(scenario),
        );

    let source_network_id =
        external_network::register_network(
            &access,
            &mut networks,
            &network_admin,
            &institutions,
            b"SOURCE-NETWORK",
            b"source:network",
            external_network::network_blockchain(),
            source_operator_id,
            test_scenario::ctx(scenario),
        );

    let dest_network_id =
        external_network::register_network(
            &access,
            &mut networks,
            &network_admin,
            &institutions,
            b"DEST-NETWORK",
            b"destination:network",
            external_network::network_bank_rail(),
            dest_operator_id,
            test_scenario::ctx(scenario),
        );

    (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        source_network_id,
        dest_network_id,
    )
}


/* ============================================================
   Test 01 — Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        cross_intent::version(&registry) == 1,
        10,
    );

    assert!(
        !cross_intent::is_paused(&registry),
        11,
    );

    assert!(
        cross_intent::total_intents(&registry) == 0,
        12,
    );

    cross_intent::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Create Intent
   ============================================================ */

#[test]
fun test_02_create_intent() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            100000,
            BENEFICIARY,
            b"INTENT-001",
            test_scenario::ctx(&mut scenario),
        );

    assert!(intent_id == 1, 20);

    assert!(
        cross_intent::intent_status(
            &registry,
            intent_id,
        ) == cross_intent::status_pending(),
        21,
    );

    cross_intent::destroy_for_testing(registry);

    external_network::destroy_admin_cap_for_testing(
        network_admin,
    );

    external_network::destroy_for_testing(
        networks,
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

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Unauthorized Source Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_03_unauthorized_source_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    cross_intent::create_intent(
        &access,
        &mut registry,
        &networks,
        source_network_id,
        dest_network_id,
        cross_intent::intent_settlement(),
        b"USD",
        100,
        BENEFICIARY,
        b"BAD-SOURCE",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04 — Same Network Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_04_same_network_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        source_network_id,
        _dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    cross_intent::create_intent(
        &access,
        &mut registry,
        &networks,
        source_network_id,
        source_network_id,
        cross_intent::intent_settlement(),
        b"USD",
        100,
        BENEFICIARY,
        b"SAME-NETWORK",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05 — Duplicate External Reference Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_05_duplicate_external_reference_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    cross_intent::create_intent(
        &access,
        &mut registry,
        &networks,
        source_network_id,
        dest_network_id,
        cross_intent::intent_asset_transfer(),
        b"USD",
        100,
        BENEFICIARY,
        b"DUPLICATE-REF",
        test_scenario::ctx(&mut scenario),
    );

    cross_intent::create_intent(
        &access,
        &mut registry,
        &networks,
        source_network_id,
        dest_network_id,
        cross_intent::intent_asset_transfer(),
        b"USD",
        200,
        BENEFICIARY,
        b"DUPLICATE-REF",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06 — Destination Confirmation
   ============================================================ */

#[test]
fun test_06_destination_confirmation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            1000,
            BENEFICIARY,
            b"CONFIRM-001",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        DEST_OPERATOR,
    );

    cross_intent::confirm_intent(
        &access,
        &mut registry,
        &networks,
        intent_id,
        b"DEST-CONFIRM-HASH",
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cross_intent::intent_status(
            &registry,
            intent_id,
        ) == cross_intent::status_confirmed(),
        60,
    );

    assert!(
        cross_intent::pending_count(
            &registry,
        ) == 0,
        61,
    );

    assert!(
        cross_intent::confirmed_count(
            &registry,
        ) == 1,
        62,
    );

    cross_intent::destroy_admin_cap_for_testing(admin);
    cross_intent::destroy_for_testing(registry);

    external_network::destroy_admin_cap_for_testing(
        network_admin,
    );

    external_network::destroy_for_testing(networks);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07 — Unauthorized Destination Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_07_unauthorized_destination_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            100,
            BENEFICIARY,
            b"BAD-DEST",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    cross_intent::confirm_intent(
        &access,
        &mut registry,
        &networks,
        intent_id,
        b"BAD-CONFIRM",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Finalize Before Confirmation Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_08_finalize_before_confirmation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(
            &mut scenario,
        );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            100,
            BENEFICIARY,
            b"EARLY-FINALIZE",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    cross_intent::finalize_intent(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09 — Successful Finalization
   ============================================================ */

#[test]
fun test_09_successful_finalization() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(&mut scenario);

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            1000,
            BENEFICIARY,
            b"FINALIZE-001",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        DEST_OPERATOR,
    );

    cross_intent::confirm_intent(
        &access,
        &mut registry,
        &networks,
        intent_id,
        b"CONFIRM-FINAL",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    cross_intent::finalize_intent(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cross_intent::intent_status(
            &registry,
            intent_id,
        ) == cross_intent::status_finalized(),
        90,
    );

    assert!(
        cross_intent::finalized_count(
            &registry,
        ) == 1,
        91,
    );

    cross_intent::destroy_admin_cap_for_testing(admin);
    cross_intent::destroy_for_testing(registry);

    external_network::destroy_admin_cap_for_testing(network_admin);
    external_network::destroy_for_testing(networks);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 10 — Cancel Pending
   ============================================================ */

#[test]
fun test_10_cancel_pending() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(&mut scenario);

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_asset_transfer(),
            b"USD",
            100,
            BENEFICIARY,
            b"CANCEL-PENDING",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    cross_intent::cancel_intent(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cross_intent::intent_status(
            &registry,
            intent_id,
        ) == cross_intent::status_cancelled(),
        100,
    );

    assert!(
        cross_intent::cancelled_count(
            &registry,
        ) == 1,
        101,
    );

    cross_intent::destroy_admin_cap_for_testing(admin);
    cross_intent::destroy_for_testing(registry);

    external_network::destroy_admin_cap_for_testing(network_admin);
    external_network::destroy_for_testing(networks);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 11 — Cancel Confirmed
   ============================================================ */

#[test]
fun test_11_cancel_confirmed() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(&mut scenario);

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            100,
            BENEFICIARY,
            b"CANCEL-CONFIRMED",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        DEST_OPERATOR,
    );

    cross_intent::confirm_intent(
        &access,
        &mut registry,
        &networks,
        intent_id,
        b"CONFIRMED-THEN-CANCEL",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    cross_intent::cancel_intent(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cross_intent::intent_status(
            &registry,
            intent_id,
        ) == cross_intent::status_cancelled(),
        110,
    );

    assert!(
        cross_intent::confirmed_count(
            &registry,
        ) == 0,
        111,
    );

    cross_intent::destroy_admin_cap_for_testing(admin);
    cross_intent::destroy_for_testing(registry);

    external_network::destroy_admin_cap_for_testing(network_admin);
    external_network::destroy_for_testing(networks);

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(institutions);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 12 — Terminal Replay Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_12_terminal_replay_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(&mut scenario);

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut registry,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            100,
            BENEFICIARY,
            b"TERMINAL-REPLAY",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    cross_intent::cancel_intent(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    cross_intent::cancel_intent(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Inactive Destination Network Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_enterprise_security::external_network_registry,
)]
fun test_13_inactive_destination_network_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        mut networks,
        network_admin,
        source_network_id,
        dest_network_id,
    ) =
        setup_networks(&mut scenario);

    external_network::set_network_status(
        &access,
        &mut networks,
        &network_admin,
        dest_network_id,
        external_network::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        SOURCE_OPERATOR,
    );

    cross_intent::create_intent(
        &access,
        &mut registry,
        &networks,
        source_network_id,
        dest_network_id,
        cross_intent::intent_settlement(),
        b"USD",
        100,
        BENEFICIARY,
        b"INACTIVE-DEST",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14 — Pause and Version
   ============================================================ */

#[test]
fun test_14_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        cross_intent::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    cross_intent::set_paused(
        &admin,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cross_intent::is_paused(
            &registry,
        ),
        140,
    );

    cross_intent::set_version(
        &admin,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        cross_intent::version(
            &registry,
        ) == 2,
        141,
    );

    cross_intent::destroy_admin_cap_for_testing(
        admin,
    );

    cross_intent::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 15 — Wrong Admin Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_enterprise_security::cross_network_settlement_intent,
)]
fun test_15_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry_a =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        cross_intent::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    cross_intent::set_paused(
        &admin_b,
        &mut registry_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 16 — Accounting Invariant
   ============================================================ */

#[test]
fun test_16_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        cross_intent::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        cross_intent::total_intents(
            &registry,
        )
        ==
        cross_intent::pending_count(&registry)
        + cross_intent::confirmed_count(&registry)
        + cross_intent::finalized_count(&registry)
        + cross_intent::cancelled_count(&registry),
        160,
    );

    cross_intent::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}
