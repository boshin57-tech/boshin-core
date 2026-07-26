#[test_only]
module tobmate_core::bridge_finality_tests;

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

use tobmate_core::cross_network_settlement_intent::{
    Self as cross_intent,
};

use tobmate_core::bridge_finality::{
    Self as bridge_finality,
};


const ADMIN: address = @0xA11CE;
const SOURCE_OPERATOR: address = @0xE101;
const DEST_OPERATOR: address = @0xE102;

const ATTESTOR_1: address = @0xF101;
const ATTESTOR_2: address = @0xF102;
const ATTESTOR_3: address = @0xF103;

const BENEFICIARY: address = @0xC001;


/* ============================================================
   Fixture
   ============================================================ */

fun setup_confirmed_intent(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,

    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,

    external_network::ExternalNetworkRegistry,
    external_network::ExternalNetworkAdminCap,

    cross_intent::CrossNetworkIntentRegistry,
    cross_intent::CrossNetworkIntentAdminCap,

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
            b"SOURCE-NET",
            b"source:net",
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
            b"DEST-NET",
            b"dest:net",
            external_network::network_bank_rail(),
            dest_operator_id,
            test_scenario::ctx(scenario),
        );

    let mut intents =
        cross_intent::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let intent_admin =
        cross_intent::admin_cap_for_testing(
            &intents,
            test_scenario::ctx(scenario),
        );

    test_scenario::next_tx(
        scenario,
        SOURCE_OPERATOR,
    );

    let intent_id =
        cross_intent::create_intent(
            &access,
            &mut intents,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            1000,
            BENEFICIARY,
            b"FINALITY-INTENT-001",
            test_scenario::ctx(scenario),
        );

    test_scenario::next_tx(
        scenario,
        DEST_OPERATOR,
    );

    cross_intent::confirm_intent(
        &access,
        &mut intents,
        &networks,
        intent_id,
        b"DEST-CONFIRM",
        test_scenario::ctx(scenario),
    );

    (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        intents,
        intent_admin,
        intent_id,
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
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        bridge_finality::version(&registry) == 1,
        10,
    );

    assert!(
        bridge_finality::threshold(&registry) == 2,
        11,
    );

    assert!(
        bridge_finality::total_attestors(&registry) == 0,
        12,
    );

    bridge_finality::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Attestor Registration
   ============================================================ */

#[test]
fun test_02_attestor_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::total_attestors(
            &registry,
        ) == 1,
        20,
    );

    assert!(
        bridge_finality::active_attestor_count(
            &registry,
        ) == 1,
        21,
    );

    bridge_finality::destroy_admin_cap_for_testing(admin);
    bridge_finality::destroy_for_testing(registry);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Duplicate Attestor Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::bridge_finality,
)]
fun test_03_duplicate_attestor_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04 — Open Finality
   ============================================================ */

#[test]
fun test_04_open_finality() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        intents,
        intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::finality_status(
            &registry,
            intent_id,
        ) == bridge_finality::finality_pending(),
        40,
    );

    assert!(
        bridge_finality::pending_count(
            &registry,
        ) == 1,
        41,
    );

    bridge_finality::destroy_for_testing(registry);

    cross_intent::destroy_admin_cap_for_testing(intent_admin);
    cross_intent::destroy_for_testing(intents);

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
   Test 05 — Attestor Suspension
   ============================================================ */

#[test]
fun test_05_attestor_suspension() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::set_attestor_status(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        bridge_finality::attestor_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::active_attestor_count(
            &registry,
        ) == 0,
        50,
    );

    bridge_finality::destroy_admin_cap_for_testing(admin);
    bridge_finality::destroy_for_testing(registry);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Unauthorized Attestor Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::bridge_finality,
)]
fun test_06_unauthorized_attestor_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        intents,
        _intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_1,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-1",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Duplicate Attestation Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::bridge_finality,
)]
fun test_07_duplicate_attestation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        intents,
        _intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_1,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-1",
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-1-REPLAY",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Threshold Not Reached
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::bridge_finality,
)]
fun test_08_threshold_not_reached() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        intents,
        _intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_1,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-1",
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::assert_threshold_reached(
        &registry,
        intent_id,
    );

    abort 999
}


/* ============================================================
   Test 09 — Threshold Reached
   ============================================================ */

#[test]
fun test_09_threshold_reached() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        intents,
        intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_2,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_1,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-A",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_2,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-B",
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::assert_threshold_reached(
        &registry,
        intent_id,
    );

    assert!(
        bridge_finality::attestation_count(
            &registry,
            intent_id,
        ) == 2,
        90,
    );

    bridge_finality::destroy_admin_cap_for_testing(admin);
    bridge_finality::destroy_for_testing(registry);

    cross_intent::destroy_admin_cap_for_testing(intent_admin);
    cross_intent::destroy_for_testing(intents);

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
   Test 10 — Successful Finalization
   ============================================================ */

#[test]
fun test_10_successful_finalization() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        intents,
        intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_2,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_1,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-A",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_2,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF-B",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    bridge_finality::finalize_finality(
        &access,
        &mut registry,
        &admin,
        intent_id,
        b"FINALITY-PROOF",
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::finality_status(
            &registry,
            intent_id,
        ) == bridge_finality::finality_finalized(),
        100,
    );

    assert!(
        bridge_finality::finalized_count(
            &registry,
        ) == 1,
        101,
    );

    bridge_finality::destroy_admin_cap_for_testing(admin);
    bridge_finality::destroy_for_testing(registry);

    cross_intent::destroy_admin_cap_for_testing(intent_admin);
    cross_intent::destroy_for_testing(intents);

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
   Test 11 — Finality Replay Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::bridge_finality,
)]
fun test_11_finality_replay_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        intents,
        _intent_admin,
        intent_id,
    ) = setup_confirmed_intent(&mut scenario);

    let mut registry =
        bridge_finality::new_for_testing(
            1,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(&mut scenario, ATTESTOR_1);

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"PROOF",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(&mut scenario, ADMIN);

    bridge_finality::finalize_finality(
        &access,
        &mut registry,
        &admin,
        intent_id,
        b"FINAL-PROOF",
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::finalize_finality(
        &access,
        &mut registry,
        &admin,
        intent_id,
        b"FINAL-PROOF-REPLAY",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Reject Finality
   ============================================================ */

#[test]
fun test_12_reject_finality() {
    let mut scenario = test_scenario::begin(ADMIN);

    let (
        access,
        institutions,
        institution_admin,
        networks,
        network_admin,
        intents,
        intent_admin,
        intent_id,
    ) = setup_confirmed_intent(&mut scenario);

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::reject_finality(
        &access,
        &mut registry,
        &admin,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::finality_status(
            &registry,
            intent_id,
        ) == bridge_finality::finality_rejected(),
        120,
    );

    assert!(
        bridge_finality::rejected_count(&registry) == 1,
        121,
    );

    bridge_finality::destroy_admin_cap_for_testing(admin);
    bridge_finality::destroy_for_testing(registry);

    cross_intent::destroy_admin_cap_for_testing(intent_admin);
    cross_intent::destroy_for_testing(intents);

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
   Test 13 — Suspended Attestor Cannot Attest
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::bridge_finality,
)]
fun test_13_suspended_attestor_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        _institutions,
        _institution_admin,
        networks,
        _network_admin,
        intents,
        _intent_admin,
        intent_id,
    ) =
        setup_confirmed_intent(
            &mut scenario,
        );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::register_attestor(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::set_attestor_status(
        &access,
        &mut registry,
        &admin,
        ATTESTOR_1,
        bridge_finality::attestor_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR_1,
    );

    bridge_finality::submit_attestation(
        &access,
        &mut registry,
        intent_id,
        b"SUSPENDED-PROOF",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14 — Open Finality Requires Confirmed Intent
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::bridge_finality,
)]
fun test_14_unconfirmed_intent_rejected() {
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

    let source_operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"SOURCE-UNCONFIRMED",
            SOURCE_OPERATOR,
            institution_registry::institution_payment_provider(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let dest_operator_id =
        institution_registry::register_institution(
            &access,
            &mut institutions,
            &institution_admin,
            b"DEST-UNCONFIRMED",
            DEST_OPERATOR,
            institution_registry::institution_payment_provider(),
            b"US",
            test_scenario::ctx(&mut scenario),
        );

    let mut networks =
        external_network::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let network_admin =
        external_network::admin_cap_for_testing(
            &networks,
            test_scenario::ctx(&mut scenario),
        );

    let source_network_id =
        external_network::register_network(
            &access,
            &mut networks,
            &network_admin,
            &institutions,
            b"SOURCE-UNCONFIRMED-NET",
            b"source:unconfirmed",
            external_network::network_blockchain(),
            source_operator_id,
            test_scenario::ctx(&mut scenario),
        );

    let dest_network_id =
        external_network::register_network(
            &access,
            &mut networks,
            &network_admin,
            &institutions,
            b"DEST-UNCONFIRMED-NET",
            b"dest:unconfirmed",
            external_network::network_bank_rail(),
            dest_operator_id,
            test_scenario::ctx(&mut scenario),
        );

    let mut intents =
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
            &mut intents,
            &networks,
            source_network_id,
            dest_network_id,
            cross_intent::intent_settlement(),
            b"USD",
            100,
            BENEFICIARY,
            b"UNCONFIRMED-INTENT",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::open_finality(
        &access,
        &mut registry,
        &networks,
        &intents,
        intent_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 15 — Pause / Version / Wrong Admin
   ============================================================ */

#[test]
fun test_15_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin =
        bridge_finality::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::set_paused(
        &admin,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::is_paused(&registry),
        150,
    );

    bridge_finality::set_version(
        &admin,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        bridge_finality::version(&registry) == 2,
        151,
    );

    bridge_finality::destroy_admin_cap_for_testing(admin);
    bridge_finality::destroy_for_testing(registry);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 16 — Finality Accounting Invariant
   ============================================================ */

#[test]
fun test_16_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        bridge_finality::total_finalities(
            &registry,
        )
        ==
        bridge_finality::pending_count(&registry)
        + bridge_finality::finalized_count(&registry)
        + bridge_finality::rejected_count(&registry),
        160,
    );

    bridge_finality::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 17 — Wrong Admin Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::bridge_finality,
)]
fun test_17_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry_a =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        bridge_finality::new_for_testing(
            2,
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        bridge_finality::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    bridge_finality::set_paused(
        &admin_b,
        &mut registry_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
