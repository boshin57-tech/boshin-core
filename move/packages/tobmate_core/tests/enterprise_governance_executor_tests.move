#[test_only]
module tobmate_core::enterprise_governance_executor_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::protocol_governance::{
    Self as governance,
    ExecutionAuthorization,
};

use tobmate_core::enterprise_identity::{
    Self as enterprise_identity,
};


use tobmate_core::custodian_registry::{
    Self as custodian_registry,
};

use tobmate_core::reserve_attestation::{
    Self as reserve_attestation,
};


use tobmate_core::institution_registry::{
    Self as institution_registry,
};

use tobmate_core::institutional_settlement::{
    Self as institutional_settlement,
};

use tobmate_core::enterprise_governance_executor::{
    Self as enterprise_executor,
};


const ADMIN: address = @0xA11CE;


/* ============================================================
   Governance Fixture
   ============================================================ */

fun setup_governance(
    scenario: &mut test_scenario::Scenario,
): (
    governance::GovernanceRegistry,
    governance::GovernanceAdminCap,
    governance::EmergencyGovernanceCap,
) {
    let registry =
        governance::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let admin_cap =
        governance::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(scenario),
        );

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &registry,
            test_scenario::ctx(scenario),
        );

    (
        registry,
        admin_cap,
        emergency_cap,
    )
}


/* ============================================================
   Create Fully Authorized Governance Execution
   ============================================================ */

fun create_authorization(
    scenario: &mut test_scenario::Scenario,

    access: &access_control::AccessControl,

    governance_registry:
        &mut governance::GovernanceRegistry,

    governance_admin:
        &governance::GovernanceAdminCap,

    action_type: u64,
    target_object_id: sui::object::ID,
    payload: vector<u8>,
): (
    u64,
    ExecutionAuthorization,
) {
    let proposal_id =
        governance::submit_proposal(
            access,
            governance_registry,

            action_type,
            b"enterprise_identity",
            target_object_id,
            payload,

            test_scenario::ctx(scenario),
        );

    /*
       Default governance:
       voting delay = 1 epoch
    */
    test_scenario::next_epoch(
        scenario,
        ADMIN,
    );

    governance::open_voting(
        governance_registry,
        governance_admin,
        proposal_id,
        100,
        test_scenario::ctx(scenario),
    );

    governance::cast_vote(
        governance_registry,
        proposal_id,
        1,
        100,
        test_scenario::ctx(scenario),
    );

    /*
       Default voting period = 5 epochs.
       Advance beyond voting end.
    */
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);

    governance::finalize_vote(
        governance_registry,
        proposal_id,
        test_scenario::ctx(scenario),
    );

    governance::queue_proposal(
        governance_registry,
        governance_admin,
        proposal_id,
        test_scenario::ctx(scenario),
    );

    governance::authorize_execution(
        governance_registry,
        governance_admin,
        proposal_id,
        ADMIN,
        test_scenario::ctx(scenario),
    );

    /*
       Default execution delay = 2 epochs.
    */
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);

    let authorization =
        test_scenario::take_from_sender<
            ExecutionAuthorization,
        >(scenario);

    (
        proposal_id,
        authorization,
    )
}


/* ============================================================
   Test 01
   Enterprise Action Namespace
   ============================================================ */

#[test]
fun test_01_action_constants() {
    assert!(
        enterprise_executor::action_identity_set_paused()
            == 2101,
        1,
    );

    assert!(
        enterprise_executor::action_identity_set_version()
            == 2102,
        2,
    );
}


/* ============================================================
   Test 02
   Canonical Payload Encoding
   ============================================================ */

#[test]
fun test_02_payload_encoding() {
    let payload_true =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let payload_false =
        enterprise_executor::payload_bool_for_testing(
            false,
        );

    let payload_version =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    assert!(
        vector::length(&payload_true) == 1,
        10,
    );

    assert!(
        *vector::borrow(&payload_true, 0) == 1,
        11,
    );

    assert!(
        *vector::borrow(&payload_false, 0) == 0,
        12,
    );

    assert!(
        vector::length(&payload_version) == 8,
        13,
    );

    assert!(
        *vector::borrow(&payload_version, 0) == 2,
        14,
    );
}


/* ============================================================
   Test 03
   Governance Fixture
   ============================================================ */

#[test]
fun test_03_governance_fixture() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    assert!(
        !governance::is_paused(
            &governance_registry,
        ),
        20,
    );

    assert!(
        !governance::is_emergency_mode(
            &governance_registry,
        ),
        21,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Enterprise Identity Target Binding
   ============================================================ */

#[test]
fun test_04_enterprise_target_binding() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &registry,
        );

    assert!(
        target
            == enterprise_identity::registry_id(
                &registry,
            ),
        30,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05
   Governed Pause Execution
   ============================================================ */

#[test]
fun test_05_governed_pause_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut enterprise_registry,
        &enterprise_admin,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        enterprise_identity::is_paused(
            &enterprise_registry,
        ),
        40,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        41,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        enterprise_admin,
    );

    enterprise_identity::destroy_for_testing(
        enterprise_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06
   Governed Version Upgrade
   ============================================================ */

#[test]
fun test_06_governed_version_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_identity_set_version(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_version(
        &mut governance_registry,
        &mut authorization,

        &mut enterprise_registry,
        &enterprise_admin,

        proposal_id,
        2,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        enterprise_identity::version(
            &enterprise_registry,
        ) == 2,
        50,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        51,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        enterprise_admin,
    );

    enterprise_identity::destroy_for_testing(
        enterprise_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Authorization Consumed After Execution
   ============================================================ */

#[test]
fun test_07_authorization_consumed() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(&mut scenario);

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        60,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        enterprise_admin,
    );

    enterprise_identity::destroy_for_testing(
        enterprise_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08
   Authorization Replay Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::protocol_governance,
)]
fun test_08_authorization_replay_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(&mut scenario);

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Wrong Action Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_09_wrong_action_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(&mut scenario);

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_version(
        &mut governance_registry,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        2,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Wrong Target Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_10_wrong_target_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(&mut scenario);

    let registry_a =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry_b =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        enterprise_identity::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    let target_a =
        enterprise_identity::registry_id(
            &registry_a,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_identity_set_paused(),
            target_a,
            payload,
        );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut registry_b,
        &admin_b,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11
   Wrong Payload Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_11_wrong_payload_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(&mut scenario);

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Cross-Registry Authorization Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::protocol_governance,
)]
fun test_12_cross_registry_authorization_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_a,
        governance_admin_a,
        _emergency_a,
    ) =
        setup_governance(&mut scenario);

    let (
        mut governance_b,
        _governance_admin_b,
        _emergency_b,
    ) =
        setup_governance(&mut scenario);

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_a,
            &governance_admin_a,
            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_b,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13
   Emergency Mode Blocks Enterprise Execution
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_core::protocol_governance,
)]
fun test_13_emergency_mode_blocks_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(&mut scenario);

    let mut enterprise_registry =
        enterprise_identity::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let enterprise_admin =
        enterprise_identity::admin_cap_for_testing(
            &enterprise_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        enterprise_identity::registry_id(
            &enterprise_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(true);

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_identity_set_paused(),
            target,
            payload,
        );

    governance::activate_emergency(
        &mut governance_registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_executor::execute_identity_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut enterprise_registry,
        &enterprise_admin,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14
   Governed Custodian Pause Execution
   ============================================================ */

#[test]
fun test_14_governed_custodian_pause_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        custodian_registry::registry_id(
            &custodian_registry_obj,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_custodian_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_custodian_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut custodian_registry_obj,
        &custodian_admin,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        custodian_registry::is_paused(
            &custodian_registry_obj,
        ),
        140,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        141,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        custodian_admin,
    );

    custodian_registry::destroy_for_testing(
        custodian_registry_obj,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 15
   Governed Custodian Version Execution
   ============================================================ */

#[test]
fun test_15_governed_custodian_version_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        custodian_registry::registry_id(
            &custodian_registry_obj,
        );

    let payload =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_custodian_set_version(),
            target,
            payload,
        );

    enterprise_executor::execute_custodian_set_version(
        &mut governance_registry,
        &mut authorization,

        &mut custodian_registry_obj,
        &custodian_admin,

        proposal_id,
        2,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        custodian_registry::version(
            &custodian_registry_obj,
        ) == 2,
        150,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        151,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        custodian_admin,
    );

    custodian_registry::destroy_for_testing(
        custodian_registry_obj,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 16
   Governed Reserve Attestation Pause Execution
   ============================================================ */

#[test]
fun test_16_governed_reserve_attestation_pause_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        reserve_attestation::registry_id(
            &attestation_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::
                action_reserve_attestation_set_paused(),

            target,
            payload,
        );

    enterprise_executor::
        execute_reserve_attestation_set_paused(
            &mut governance_registry,
            &mut authorization,

            &mut attestation_registry,
            &attestation_admin,

            proposal_id,
            true,

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        reserve_attestation::is_paused(
            &attestation_registry,
        ),
        160,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        161,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        attestation_admin,
    );

    reserve_attestation::destroy_for_testing(
        attestation_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 17
   Governed Reserve Attestation Version Execution
   ============================================================ */

#[test]
fun test_17_governed_reserve_attestation_version_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        reserve_attestation::registry_id(
            &attestation_registry,
        );

    let payload =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::
                action_reserve_attestation_set_version(),

            target,
            payload,
        );

    enterprise_executor::
        execute_reserve_attestation_set_version(
            &mut governance_registry,
            &mut authorization,

            &mut attestation_registry,
            &attestation_admin,

            proposal_id,
            2,

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        reserve_attestation::version(
            &attestation_registry,
        ) == 2,
        170,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        171,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        attestation_admin,
    );

    reserve_attestation::destroy_for_testing(
        attestation_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 18
   Custodian Wrong Payload Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_18_custodian_wrong_payload_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        custodian_registry::registry_id(
            &custodian_registry_obj,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_custodian_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_custodian_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut custodian_registry_obj,
        &custodian_admin,
        proposal_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 19
   Reserve Attestation Wrong Target Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_19_reserve_attestation_wrong_target_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let attestation_registry_a =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry_b =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry_b,
            test_scenario::ctx(&mut scenario),
        );

    let target_a =
        reserve_attestation::registry_id(
            &attestation_registry_a,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::
                action_reserve_attestation_set_paused(),
            target_a,
            payload,
        );

    enterprise_executor::
        execute_reserve_attestation_set_paused(
            &mut governance_registry,
            &mut authorization,
            &mut attestation_registry_b,
            &admin_b,
            proposal_id,
            true,
            test_scenario::ctx(&mut scenario),
        );

    abort 999
}


/* ============================================================
   Test 20
   Custodian Authorization Replay Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::protocol_governance,
)]
fun test_20_custodian_replay_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        custodian_registry::registry_id(
            &custodian_registry_obj,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::action_custodian_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_custodian_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut custodian_registry_obj,
        &custodian_admin,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_executor::execute_custodian_set_paused(
        &mut governance_registry,
        &mut authorization,
        &mut custodian_registry_obj,
        &custodian_admin,
        proposal_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 21
   Emergency Blocks Reserve Attestation Governance
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_core::protocol_governance,
)]
fun test_21_emergency_blocks_reserve_attestation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        reserve_attestation::registry_id(
            &attestation_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,
            enterprise_executor::
                action_reserve_attestation_set_paused(),
            target,
            payload,
        );

    governance::activate_emergency(
        &mut governance_registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_executor::
        execute_reserve_attestation_set_paused(
            &mut governance_registry,
            &mut authorization,
            &mut attestation_registry,
            &attestation_admin,
            proposal_id,
            true,
            test_scenario::ctx(&mut scenario),
        );

    abort 999
}


/* ============================================================
   Test 22
   Stage 12 Part 3 Action Namespace
   ============================================================ */

#[test]
fun test_22_part3_action_constants() {
    assert!(
        enterprise_executor::action_institution_set_paused()
            == 2301,
        220,
    );

    assert!(
        enterprise_executor::action_institution_set_version()
            == 2302,
        221,
    );

    assert!(
        enterprise_executor::action_settlement_set_paused()
            == 2303,
        222,
    );

    assert!(
        enterprise_executor::action_settlement_set_version()
            == 2304,
        223,
    );
}


/* ============================================================
   Test 23
   Governed Institution Pause Execution
   ============================================================ */

#[test]
fun test_23_governed_institution_pause_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut institution_registry_obj =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institution_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institution_registry::registry_id(
            &institution_registry_obj,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_institution_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_institution_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut institution_registry_obj,
        &institution_admin,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institution_registry::is_paused(
            &institution_registry_obj,
        ),
        230,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        231,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 24
   Governed Institution Version Execution
   ============================================================ */

#[test]
fun test_24_governed_institution_version_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut institution_registry_obj =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institution_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institution_registry::registry_id(
            &institution_registry_obj,
        );

    let payload =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_institution_set_version(),
            target,
            payload,
        );

    enterprise_executor::execute_institution_set_version(
        &mut governance_registry,
        &mut authorization,

        &mut institution_registry_obj,
        &institution_admin,

        proposal_id,
        2,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institution_registry::version(
            &institution_registry_obj,
        ) == 2,
        240,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        241,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 25
   Governed Settlement Pause Execution
   ============================================================ */

#[test]
fun test_25_governed_settlement_pause_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut settlement_registry =
        institutional_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin =
        institutional_settlement::admin_cap_for_testing(
            &settlement_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institutional_settlement::registry_id(
            &settlement_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_settlement_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_settlement_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut settlement_registry,
        &settlement_admin,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institutional_settlement::is_paused(
            &settlement_registry,
        ),
        250,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        251,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    institutional_settlement::destroy_admin_cap_for_testing(
        settlement_admin,
    );

    institutional_settlement::destroy_for_testing(
        settlement_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 26
   Governed Settlement Version Execution
   ============================================================ */

#[test]
fun test_26_governed_settlement_version_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut settlement_registry =
        institutional_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin =
        institutional_settlement::admin_cap_for_testing(
            &settlement_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institutional_settlement::registry_id(
            &settlement_registry,
        );

    let payload =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_settlement_set_version(),
            target,
            payload,
        );

    enterprise_executor::execute_settlement_set_version(
        &mut governance_registry,
        &mut authorization,

        &mut settlement_registry,
        &settlement_admin,

        proposal_id,
        2,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institutional_settlement::version(
            &settlement_registry,
        ) == 2,
        260,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        261,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    institutional_settlement::destroy_admin_cap_for_testing(
        settlement_admin,
    );

    institutional_settlement::destroy_for_testing(
        settlement_registry,
    );

    governance::destroy_emergency_cap_for_testing(
        emergency_cap,
    );

    governance::destroy_admin_cap_for_testing(
        governance_admin,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 27
   Institution Wrong Payload Rejected
   ============================================================ */

#[test]
#[expected_failure]
fun test_27_institution_wrong_payload_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut institution_registry_obj =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institution_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institution_registry::registry_id(
            &institution_registry_obj,
        );

    /*
       Authorization commits to "paused = false".
       Execution attempts "paused = true".
    */
    let payload =
        enterprise_executor::payload_bool_for_testing(
            false,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_institution_set_paused(),
            target,
            payload,
        );

    enterprise_executor::execute_institution_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut institution_registry_obj,
        &institution_admin,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 28
   Settlement Wrong Target Rejected
   ============================================================ */

#[test]
#[expected_failure]
fun test_28_settlement_wrong_target_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let settlement_registry_a =
        institutional_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut settlement_registry_b =
        institutional_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin_b =
        institutional_settlement::admin_cap_for_testing(
            &settlement_registry_b,
            test_scenario::ctx(&mut scenario),
        );

    /*
       Authorization is bound to registry A.
       Execution attempts to mutate registry B.
    */
    let target_a =
        institutional_settlement::registry_id(
            &settlement_registry_a,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_settlement_set_paused(),
            target_a,
            payload,
        );

    enterprise_executor::execute_settlement_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut settlement_registry_b,
        &settlement_admin_b,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 29
   Institution Authorization Replay Rejected
   ============================================================ */

#[test]
#[expected_failure]
fun test_29_institution_authorization_replay_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        _emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut institution_registry_obj =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institution_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institution_registry::registry_id(
            &institution_registry_obj,
        );

    let payload =
        enterprise_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_institution_set_version(),
            target,
            payload,
        );

    /*
       First execution consumes authorization.
    */
    enterprise_executor::execute_institution_set_version(
        &mut governance_registry,
        &mut authorization,

        &mut institution_registry_obj,
        &institution_admin,

        proposal_id,
        2,

        test_scenario::ctx(&mut scenario),
    );

    /*
       Same authorization cannot execute again.
    */
    enterprise_executor::execute_institution_set_version(
        &mut governance_registry,
        &mut authorization,

        &mut institution_registry_obj,
        &institution_admin,

        proposal_id,
        2,

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 30
   Emergency Mode Blocks Settlement Governance
   ============================================================ */

#[test]
#[expected_failure]
fun test_30_emergency_blocks_settlement_governance() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut governance_registry,
        governance_admin,
        emergency_cap,
    ) =
        setup_governance(
            &mut scenario,
        );

    let mut settlement_registry =
        institutional_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin =
        institutional_settlement::admin_cap_for_testing(
            &settlement_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target =
        institutional_settlement::registry_id(
            &settlement_registry,
        );

    let payload =
        enterprise_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) =
        create_authorization(
            &mut scenario,
            &access,
            &mut governance_registry,
            &governance_admin,

            enterprise_executor::action_settlement_set_paused(),
            target,
            payload,
        );

    /*
       Activate emergency governance after authorization
       but before execution.
    */
    governance::activate_emergency(
        &mut governance_registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_executor::execute_settlement_set_paused(
        &mut governance_registry,
        &mut authorization,

        &mut settlement_registry,
        &settlement_admin,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
