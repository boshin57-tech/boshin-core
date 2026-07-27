#[test_only]
module tobmate_core::cross_network_incident_closure_governance_tests {

    use sui::test_scenario;

    use tobmate_core::cross_network_security_orchestrator;
    use tobmate_core::cross_network_incident_closure_governance;


    // ============================================================
    // Test 01
    // Verified orchestration can produce immutable closure receipt.
    // ============================================================

    #[test]
    fun test_01_finalize_verified_closure_success() {
        let mut scenario =
            test_scenario::begin(@0x1401);

        let ctx = scenario.ctx();

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                1,
                100,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        let receipt =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    b"audit-digest-001",
                    ctx,
                );

        cross_network_incident_closure_governance::
            verify_receipt(&receipt);

        assert!(
            cross_network_incident_closure_governance::
                receipt_case_sequence(&receipt) == 1,
            14001,
        );

        assert!(
            cross_network_incident_closure_governance::
                receipt_snapshot_sequence(&receipt) == 100,
            14002,
        );

        assert!(
            cross_network_incident_closure_governance::
                receipt_status(&receipt)
                ==
                cross_network_incident_closure_governance::
                    status_finalized(),
            14003,
        );

        assert!(
            cross_network_incident_closure_governance::
                total_finalized(&governance) == 1,
            14004,
        );

        cross_network_incident_closure_governance::
            destroy_receipt_for_testing(receipt);

        cross_network_incident_closure_governance::
            destroy_governance_for_testing(governance);

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        scenario.end();
    }


    // ============================================================
    // Test 02
    // Same case sequence cannot be finalized twice.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1207602)]
    fun test_02_duplicate_closure_rejected() {
        let mut scenario =
            test_scenario::begin(@0x1402);

        let ctx = scenario.ctx();

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                2,
                200,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        let receipt_1 =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    b"audit-digest-002",
                    ctx,
                );

        // Must abort with E_ALREADY_FINALIZED.
        let receipt_2 =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    b"audit-digest-002",
                    ctx,
                );

        // Unexpected-success cleanup path.
        cross_network_incident_closure_governance::
            destroy_receipt_for_testing(receipt_2);

        cross_network_incident_closure_governance::
            destroy_receipt_for_testing(receipt_1);

        cross_network_incident_closure_governance::
            destroy_governance_for_testing(governance);

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        scenario.end();

        abort 0
    }


    // ============================================================
    // Test 03
    // Tampered closure ID must fail receipt verification.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1207606)]
    fun test_03_tampered_closure_receipt_rejected() {
        let mut scenario =
            test_scenario::begin(@0x1403);

        let ctx = scenario.ctx();

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                3,
                300,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        let mut receipt =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    b"audit-digest-003",
                    ctx,
                );

        cross_network_incident_closure_governance::
            tamper_closure_id_for_testing(
                &mut receipt,
                b"tampered-closure-id",
            );

        // Must abort with E_CLOSURE_ID_MISMATCH.
        cross_network_incident_closure_governance::
            verify_receipt(&receipt);

        // Unexpected-success cleanup path.
        cross_network_incident_closure_governance::
            destroy_receipt_for_testing(receipt);

        cross_network_incident_closure_governance::
            destroy_governance_for_testing(governance);

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        scenario.end();

        abort 0
    }


    // ============================================================
    // Test 04
    // Paused closure governance must reject finalization.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1207607)]
    fun test_04_paused_governance_rejects_closure() {
        let mut scenario =
            test_scenario::begin(@0x1404);

        let ctx = scenario.ctx();

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                4,
                400,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        cross_network_incident_closure_governance::
            set_paused(
                &mut governance,
                true,
            );

        // Must abort with E_PAUSED.
        let receipt =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    b"audit-digest-004",
                    ctx,
                );

        // Unexpected-success cleanup path.
        cross_network_incident_closure_governance::
            destroy_receipt_for_testing(receipt);

        cross_network_incident_closure_governance::
            destroy_governance_for_testing(governance);

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        scenario.end();

        abort 0
    }
}
