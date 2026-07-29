#[test_only]
module tobmate_enterprise_security::cross_network_incident_closure_binding_tests {

    use sui::test_scenario;

    use tobmate_enterprise_security::cross_network_security_telemetry;
    use tobmate_enterprise_security::cross_network_anomaly_scoring;
    use tobmate_enterprise_security::cross_network_incident_severity;
    use tobmate_enterprise_security::cross_network_security_snapshot;
    use tobmate_enterprise_security::cross_network_security_audit_export;
    use tobmate_enterprise_security::cross_network_security_orchestrator;
    use tobmate_enterprise_security::cross_network_incident_closure_governance;
    use tobmate_enterprise_security::cross_network_incident_closure_binding;


    fun net(): vector<u8> {
        b"network-14"
    }

    fun domain(): vector<u8> {
        b"domain-14"
    }

    fun operator(): vector<u8> {
        b"operator-14"
    }


    // ============================================================
    // Test 05
    // Snapshot -> AuditExport -> ClosureReceipt full binding.
    // ============================================================

    #[test]
    fun test_05_full_closure_evidence_binding_success() {
        let mut scenario =
            test_scenario::begin(@0x1405);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net(),
                domain(),
                operator(),
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    500,
                    net(),
                    domain(),
                    operator(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                5,
                500,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        let receipt =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    *cross_network_security_audit_export::
                        audit_digest(&export),
                    ctx,
                );

        cross_network_incident_closure_binding::
            assert_full_closure_binding(
                &snapshot,
                &export,
                &receipt,
            );

        assert!(
            cross_network_incident_closure_binding::
                export_snapshot_bound(
                    &snapshot,
                    &export,
                ),
            14501,
        );

        assert!(
            cross_network_incident_closure_binding::
                receipt_export_bound(
                    &receipt,
                    &export,
                ),
            14502,
        );

        cross_network_incident_closure_governance::
            destroy_receipt_for_testing(receipt);

        cross_network_incident_closure_governance::
            destroy_governance_for_testing(governance);

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        cross_network_security_audit_export::
            destroy_for_testing(export);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        scenario.end();
    }


    // ============================================================
    // Test 06
    // Audit export cannot bind to a different snapshot sequence.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1207701)]
    fun test_06_wrong_snapshot_export_rejected() {
        let mut scenario =
            test_scenario::begin(@0x1406);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net(),
                domain(),
                operator(),
            );

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let snapshot_a =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    600,
                    net(),
                    domain(),
                    operator(),
                    ctx,
                );

        let snapshot_b =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    601,
                    net(),
                    domain(),
                    operator(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot_a,
                    1,
                    ctx,
                );

        cross_network_incident_closure_binding::
            assert_export_snapshot_binding(
                &snapshot_b,
                &export,
            );

        abort 0
    }


    // ============================================================
    // Test 07
    // Closure receipt snapshot must match AuditExport snapshot.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1207702)]
    fun test_07_receipt_snapshot_mismatch_rejected() {
        let mut scenario =
            test_scenario::begin(@0x1407);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net(),
                domain(),
                operator(),
            );

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    700,
                    net(),
                    domain(),
                    operator(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        // Deliberately different from export snapshot 700.
        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                7,
                701,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        let receipt =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    *cross_network_security_audit_export::
                        audit_digest(&export),
                    ctx,
                );

        cross_network_incident_closure_binding::
            assert_receipt_export_binding(
                &receipt,
                &export,
            );

        abort 0
    }


    // ============================================================
    // Test 08
    // Closure receipt digest must equal verified AuditExport digest.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1207703)]
    fun test_08_audit_digest_mismatch_rejected() {
        let mut scenario =
            test_scenario::begin(@0x1408);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net(),
                domain(),
                operator(),
            );

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    800,
                    net(),
                    domain(),
                    operator(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(ctx);

        cross_network_security_orchestrator::
            set_verified_state_for_testing(
                &mut orchestration,
                8,
                800,
            );

        let mut governance =
            cross_network_incident_closure_governance::
                new_governance(ctx);

        // Deliberately not the AuditExport digest.
        let receipt =
            cross_network_incident_closure_governance::
                finalize_closure(
                    &mut governance,
                    &orchestration,
                    b"wrong-audit-digest",
                    ctx,
                );

        cross_network_incident_closure_binding::
            assert_receipt_export_binding(
                &receipt,
                &export,
            );

        abort 0
    }
}
