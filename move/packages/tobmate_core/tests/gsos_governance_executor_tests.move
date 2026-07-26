#[test_only]
module tobmate_core::gsos_governance_executor_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::protocol_governance::{
    Self as governance,
};

use tobmate_core::gsos_identity_binding::{
    Self as identity_binding,
};

use tobmate_core::gsos_protocol_registry::{
    Self as protocol_registry,
};

use tobmate_core::gsos_governance_executor::{
    Self as gsos_executor,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Governance Fixture
   ============================================================ */

fun setup_governance(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
): (
    governance::GovernanceRegistry,
    governance::GovernanceAdminCap,
    governance::EmergencyGovernanceCap,
) {
    let mut registry =
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
   Test 01 — Action Constants
   ============================================================ */

#[test]
fun test_01_action_constants() {
    assert!(
        gsos_executor::action_identity_set_paused()
            == 1001,
        1,
    );

    assert!(
        gsos_executor::action_identity_set_version()
            == 1002,
        2,
    );

    assert!(
        gsos_executor::action_protocol_set_paused()
            == 1201,
        3,
    );

    assert!(
        gsos_executor::action_event_anchor_set_version()
            == 1802,
        4,
    );
}


/* ============================================================
   Test 02 — Payload Encoding
   ============================================================ */

#[test]
fun test_02_payload_encoding() {
    let payload_true =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let payload_false =
        gsos_executor::payload_bool_for_testing(
            false,
        );

    let payload_version =
        gsos_executor::payload_u64_for_testing(
            2,
        );

    assert!(vector::length(&payload_true) == 1, 10);
    assert!(vector::borrow(&payload_true, 0) == 1, 11);

    assert!(vector::length(&payload_false) == 1, 12);
    assert!(vector::borrow(&payload_false, 0) == 0, 13);

    assert!(vector::length(&payload_version) == 8, 14);
}


/* ============================================================
   Test 03 — Governance Fixture
   ============================================================ */

#[test]
fun test_03_governance_fixture() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        governance_registry,
        governance_admin,
        emergency_cap,
    ) = setup_governance(
        &mut scenario,
        &access,
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

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Identity Target ID
   ============================================================ */

#[test]
fun test_04_identity_target_id() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let id =
        identity_binding::registry_id(
            &registry,
        );

    assert!(id == identity_binding::registry_id(&registry), 30);

    identity_binding::destroy_for_testing(registry);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Protocol Target ID
   ============================================================ */

#[test]
fun test_05_protocol_target_id() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (registry, admin_cap) =
        protocol_registry::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let id =
        protocol_registry::registry_id(
            &registry,
        );

    assert!(
        id == protocol_registry::registry_id(
            &registry,
        ),
        40,
    );

    protocol_registry::destroy_for_testing(registry);
    protocol_registry::destroy_admin_cap_for_testing(admin_cap);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Governance Proposal Lifecycle Helper
   ============================================================ */

fun prepare_execution(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
    governance_registry: &mut governance::GovernanceRegistry,
    governance_cap: &governance::GovernanceAdminCap,
    action_type: u64,
    target_id: sui::object::ID,
    payload: vector<u8>,
): (
    u64,
    governance::ExecutionAuthorization,
) {
    let proposal_id =
        governance::submit_proposal(
            access,
            governance_registry,
            action_type,
            b"gsos_control_plane",
            target_id,
            payload,
            test_scenario::ctx(scenario),
        );

    test_scenario::next_epoch(
        scenario,
        ADMIN,
    );

    governance::open_voting(
        governance_registry,
        governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(scenario),
    );

    governance::cast_vote(
        governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(scenario),
    );

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
        governance_cap,
        proposal_id,
        test_scenario::ctx(scenario),
    );

    governance::authorize_execution(
        governance_registry,
        governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(scenario),
    );

    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);

    let authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            scenario,
        );

    (
        proposal_id,
        authorization,
    )
}


/* ============================================================
   Test 06
   Identity Pause Governance Execution
   ============================================================ */

#[test]
fun test_06_identity_pause_governance_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_admin =
        identity_binding::admin_cap_for_testing(
            &identity_registry,
            test_scenario::ctx(&mut scenario),
        );

    let target_id =
        identity_binding::registry_id(
            &identity_registry,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_identity_set_paused(),
        target_id,
        payload,
    );

    gsos_executor::execute_identity_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,
        &identity_admin,
        &mut identity_registry,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        identity_binding::is_paused(
            &identity_registry,
        ),
        60,
    );

    assert!(
        governance::proposal_status(
            &governance_registry,
            proposal_id,
        ) == governance::status_executed(),
        61,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        62,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    identity_binding::destroy_admin_cap_for_testing(
        identity_admin,
    );

    identity_binding::destroy_for_testing(
        identity_registry,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Protocol Version Governance Execution
   ============================================================ */

#[test]
fun test_07_protocol_version_governance_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_version(),
        target_id,
        payload,
    );

    gsos_executor::execute_protocol_set_version(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        protocol_registry::version(
            &protocols,
        ) == 2,
        70,
    );

    assert!(
        governance::proposal_status(
            &governance_registry,
            proposal_id,
        ) == governance::status_executed(),
        71,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        72,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(
        protocol_admin,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08
   Payload Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_08_payload_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    /*
     * Governance approves version 2.
     */
    let approved_payload =
        gsos_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_version(),
        target_id,
        approved_payload,
    );

    /*
     * Executor attempts version 3.
     * Canonical payload must mismatch.
     */
    gsos_executor::execute_protocol_set_version(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        3,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Wrong Action Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::protocol_governance,
)]
fun test_09_wrong_action_type_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    /*
     * Governance authorizes PROTOCOL pause.
     */
    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload,
    );

    /*
     * Executor intentionally tries VERSION action.
     */
    gsos_executor::execute_protocol_set_version(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Wrong Target Object Rejected
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

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        protocols_a,
        admin_a,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let (
        mut protocols_b,
        admin_b,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let approved_target =
        protocol_registry::registry_id(
            &protocols_a,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_paused(),
        approved_target,
        payload,
    );

    /*
     * Authorization targets registry A,
     * but executor is pointed at registry B.
     */
    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,
        &admin_b,
        &mut protocols_b,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    protocol_registry::destroy_for_testing(protocols_a);
    protocol_registry::destroy_admin_cap_for_testing(admin_a);

    abort 999
}


/* ============================================================
   Test 11
   Emergency Mode Blocks Execution
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_core::protocol_governance,
)]
fun test_11_emergency_mode_blocks_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload,
    );

    governance::activate_emergency(
        &mut governance_registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Authorization Reuse Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 26,
    location = tobmate_core::protocol_governance,
)]
fun test_12_authorization_reuse_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_u64_for_testing(
            2,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_version(),
        target_id,
        payload,
    );

    gsos_executor::execute_protocol_set_version(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        120,
    );

    /*
     * Direct authorization validation must reject reuse.
     * The executor has already consumed this authorization.
     */
    governance::consume_execution_authorization(
        &mut authorization,
        proposal_id,
        gsos_executor::action_protocol_set_version(),
        target_id,
        &gsos_executor::payload_u64_for_testing(2),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13
   Cross-Governance Registry Authorization Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 33,
    location = tobmate_core::protocol_governance,
)]
fun test_13_cross_governance_registry_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Governance Registry A
     */
    let mut governance_a =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap_a =
        governance::admin_cap_for_testing(
            &governance_a,
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Governance Registry B
     */
    let mut governance_b =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap_b =
        governance::admin_cap_for_testing(
            &governance_b,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload_a =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    /*
     * Create proposal #1 and authorization in Registry A.
     */
    let (
        proposal_a,
        mut authorization_a,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_a,
        &governance_cap_a,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload_a,
    );

    /*
     * Registry B must also contain proposal #1 in executable
     * state so execution reaches the registry-isolation guard.
     */
    let payload_b =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_b,
        authorization_b,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_b,
        &governance_cap_b,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload_b,
    );

    assert!(proposal_a == proposal_b, 130);

    /*
     * Authorization A is intentionally used against
     * Governance Registry B.
     */
    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_b,
        &mut authorization_a,
        &protocol_admin,
        &mut protocols,
        proposal_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    governance::destroy_execution_authorization_for_testing(
        authorization_b,
    );

    abort 999
}


/* ============================================================
   Test 14
   AccessControl Pause Blocks Governance Execution
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::access_control,
)]
fun test_14_access_control_pause_blocks_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let access_admin =
        access_control::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload,
    );

    /*
     * Global AccessControl is paused AFTER authorization
     * has already been created.
     */
    access_control::set_paused(
        &access_admin,
        &mut access,
        true,
        test_scenario::ctx(&mut scenario),
    );

    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 15
   Final Execution State Integrity
   ============================================================ */

#[test]
fun test_15_final_execution_state_integrity() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload,
    );

    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        protocol_registry::is_paused(
            &protocols,
        ),
        150,
    );

    assert!(
        governance::proposal_status(
            &governance_registry,
            proposal_id,
        ) == governance::status_executed(),
        151,
    );

    assert!(
        governance::proposal_executed(
            &governance_registry,
            proposal_id,
        ),
        152,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        153,
    );

    assert!(
        governance::authorization_proposal_id(
            &authorization,
        ) == proposal_id,
        154,
    );

    assert!(
        governance::authorization_action_type(
            &authorization,
        ) == gsos_executor::action_protocol_set_paused(),
        155,
    );

    assert!(
        governance::authorization_target_object_id(
            &authorization,
        ) == target_id,
        156,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    protocol_registry::destroy_for_testing(
        protocols,
    );

    protocol_registry::destroy_admin_cap_for_testing(
        protocol_admin,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
