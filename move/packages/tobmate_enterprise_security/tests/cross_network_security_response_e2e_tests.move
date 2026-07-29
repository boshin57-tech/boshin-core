#[test_only]
module tobmate_enterprise_security::cross_network_security_response_e2e_tests {

    use std::vector;
    use sui::test_scenario;

    use tobmate_enterprise_security::cross_network_security_telemetry;
    use tobmate_enterprise_security::cross_network_anomaly_scoring;
    use tobmate_enterprise_security::cross_network_incident_severity;
    use tobmate_enterprise_security::cross_network_security_snapshot;
    use tobmate_enterprise_security::cross_network_security_response_policy;
    use tobmate_enterprise_security::cross_network_incident_containment;
    use tobmate_enterprise_security::cross_network_safe_release_control;

    fun net_a(): vector<u8> { b"network-a" }
    fun domain_a(): vector<u8> { b"domain-a" }
    fun operator_a(): vector<u8> { b"operator-a" }

    fun add_critical_signal(
        telemetry:
            &mut cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,
    ) {
        cross_network_security_telemetry::
            record_execution_attempt(
                telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_rate_violation(
                telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_risk_violation(
                telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_compliance_violation(
                telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_operator_trust_violation(
                telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );
    }

    #[test]
    fun test_01_critical_detection_to_operator_containment() {
        let mut scenario = test_scenario::begin(@0x1501);
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

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        add_critical_signal(&mut telemetry);

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        assert!(score >= 7_000, 0);

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score,
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    1,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        assert!(
            cross_network_security_response_policy::
                decision_action(&decision)
                ==
                cross_network_security_response_policy::
                    action_quarantine_operator(),
            1,
        );

        let receipt =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        assert!(
            cross_network_incident_containment::
                operator_quarantined(&containment),
            2,
        );

        assert!(
            cross_network_incident_containment::
                receipt_snapshot_sequence(&receipt) == 1,
            3,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_02_repeated_critical_to_execution_pause() {
        let mut scenario = test_scenario::begin(@0x1502);
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

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        add_critical_signal(&mut telemetry);

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score,
            );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score,
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    2,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        assert!(
            cross_network_security_response_policy::
                decision_action(&decision)
                ==
                cross_network_security_response_policy::
                    action_pause_execution(),
            0,
        );

        let receipt =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        assert!(
            cross_network_incident_containment::
                execution_paused(&containment),
            1,
        );

        assert!(
            cross_network_incident_containment::
                containment_count(&containment) == 1,
            2,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_03_operator_quarantine_then_execution_pause() {
        let mut scenario = test_scenario::begin(@0x1503);
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

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        add_critical_signal(&mut telemetry);

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        // First CRITICAL.
        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score,
            );

        let snapshot_1 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    1,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_1 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_1);

        let receipt_1 =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision_1,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        assert!(
            cross_network_incident_containment::
                operator_quarantined(&containment),
            0,
        );

        // Second CRITICAL.
        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score,
            );

        let snapshot_2 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    2,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_2 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_2);

        let receipt_2 =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision_2,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        assert!(
            cross_network_incident_containment::
                execution_paused(&containment),
            1,
        );

        assert!(
            cross_network_incident_containment::
                containment_count(&containment) == 2,
            2,
        );

        assert!(
            cross_network_incident_containment::
                escalation_count(&containment) == 1,
            3,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt_1);

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt_2);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_1);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_2);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_04_containment_receipts_follow_sequences() {
        let mut scenario = test_scenario::begin(@0x1504);
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

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        add_critical_signal(&mut telemetry);

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score,
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    44,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        let receipt =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        assert!(
            cross_network_incident_containment::
                receipt_snapshot_sequence(&receipt) == 44,
            0,
        );

        assert!(
            cross_network_incident_containment::
                last_snapshot_sequence(&containment) == 44,
            1,
        );

        assert!(
            cross_network_incident_containment::
                receipt_policy_version(&receipt)
                ==
                cross_network_security_response_policy::
                    version(&response),
            2,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_05_clean_recovery_resumes_execution() {
        let mut scenario = test_scenario::begin(@0x1505);
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

        let clean_incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        // Existing containment from earlier incident.
        cross_network_incident_containment::
            set_execution_paused_for_testing(
                &mut containment,
                true,
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                4,
            );

        // New clean observation.
        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &clean_incident_state,
                    5,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(
                    &response,
                    &snapshot,
                );

        assert!(
            cross_network_security_response_policy::
                recovery_eligible(&decision),
            0,
        );

        let receipt =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision,
                    &snapshot,
                    ctx,
                );

        assert!(
            !cross_network_incident_containment::
                execution_paused(&containment),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt)
                ==
                cross_network_safe_release_control::
                    recovery_execution_resume(),
            2,
        );

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(clean_incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_06_recovery_receipt_bound_to_fresh_snapshot() {
        let mut scenario = test_scenario::begin(@0x1506);
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

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        cross_network_incident_containment::
            set_operator_quarantined_for_testing(
                &mut containment,
                operator_a(),
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                5,
            );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    6,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(
                    &response,
                    &snapshot,
                );

        let receipt =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision,
                    &snapshot,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_snapshot_sequence(&receipt) == 6,
            0,
        );

        assert!(
            cross_network_safe_release_control::
                last_snapshot_sequence(&recovery) == 6,
            1,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_policy_version(&receipt)
                ==
                cross_network_security_response_policy::
                    version(&response),
            2,
        );

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_07_execution_then_network_release_order() {
        let mut scenario = test_scenario::begin(@0x1507);
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

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        // Simulate previous critical containment.
        cross_network_incident_containment::
            set_execution_paused_for_testing(
                &mut containment,
                true,
            );

        cross_network_incident_containment::
            set_network_quarantined_for_testing(
                &mut containment,
                net_a(),
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                6,
            );

        // Clean recovery telemetry.
        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        // Step 1: execution resume.
        let snapshot_7 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    7,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_7 =
            cross_network_security_response_policy::
                evaluate(
                    &response,
                    &snapshot_7,
                );

        let receipt_1 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_7,
                    &snapshot_7,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_1)
                ==
                cross_network_safe_release_control::
                    recovery_execution_resume(),
            0,
        );

        assert!(
            cross_network_incident_containment::
                network_quarantined(&containment),
            1,
        );

        // Step 2: next fresh snapshot releases network.
        let snapshot_8 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    8,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_8 =
            cross_network_security_response_policy::
                evaluate(
                    &response,
                    &snapshot_8,
                );

        let receipt_2 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_8,
                    &snapshot_8,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_2)
                ==
                cross_network_safe_release_control::
                    recovery_network_release(),
            2,
        );

        assert!(
            !cross_network_incident_containment::
                network_quarantined(&containment),
            3,
        );

        assert!(
            cross_network_safe_release_control::
                recovery_count(&recovery) == 2,
            4,
        );

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_1);

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_2);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_7);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_8);

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_08_network_then_domain_release_order() {
        let mut scenario = test_scenario::begin(@0x1508);
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

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        cross_network_incident_containment::
            set_network_quarantined_for_testing(
                &mut containment,
                net_a(),
            );

        cross_network_incident_containment::
            set_domain_quarantined_for_testing(
                &mut containment,
                domain_a(),
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                8,
            );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot_9 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    9,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_9 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_9);

        let receipt_1 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_9,
                    &snapshot_9,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_1)
                ==
                cross_network_safe_release_control::
                    recovery_network_release(),
            0,
        );

        assert!(
            cross_network_incident_containment::
                domain_quarantined(&containment),
            1,
        );

        let snapshot_10 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    10,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_10 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_10);

        let receipt_2 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_10,
                    &snapshot_10,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_2)
                ==
                cross_network_safe_release_control::
                    recovery_domain_release(),
            2,
        );

        assert!(
            !cross_network_incident_containment::
                domain_quarantined(&containment),
            3,
        );

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_1);

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_2);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_9);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_10);

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_09_domain_then_operator_release_order() {
        let mut scenario = test_scenario::begin(@0x1509);
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

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        cross_network_incident_containment::
            set_domain_quarantined_for_testing(
                &mut containment,
                domain_a(),
            );

        cross_network_incident_containment::
            set_operator_quarantined_for_testing(
                &mut containment,
                operator_a(),
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                10,
            );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot_11 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    11,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_11 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_11);

        let receipt_1 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_11,
                    &snapshot_11,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_1)
                ==
                cross_network_safe_release_control::
                    recovery_domain_release(),
            0,
        );

        assert!(
            cross_network_incident_containment::
                operator_quarantined(&containment),
            1,
        );

        let snapshot_12 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    12,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_12 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_12);

        let receipt_2 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_12,
                    &snapshot_12,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_2)
                ==
                cross_network_safe_release_control::
                    recovery_operator_release(),
            2,
        );

        assert!(
            !cross_network_incident_containment::
                operator_quarantined(&containment),
            3,
        );

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_1);

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_2);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_11);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_12);

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_10_stale_recovery_snapshot_rejected() {
        let mut scenario = test_scenario::begin(@0x1510);
        let ctx = scenario.ctx();

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        cross_network_safe_release_control::
            set_last_snapshot_sequence_for_testing(
                &mut recovery,
                20,
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                20,
            );

        cross_network_safe_release_control::
            assert_fresh_sequence_for_testing(
                &recovery,
                &containment,
                20,
            );

        abort 999
    }

    #[test]
    fun test_11_full_containment_recovery_lifecycle() {
        let mut scenario = test_scenario::begin(@0x1511);
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

        let response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        // Simulate fully contained state after critical escalation.
        cross_network_incident_containment::
            set_execution_paused_for_testing(
                &mut containment,
                true,
            );

        cross_network_incident_containment::
            set_network_quarantined_for_testing(
                &mut containment,
                net_a(),
            );

        cross_network_incident_containment::
            set_domain_quarantined_for_testing(
                &mut containment,
                domain_a(),
            );

        cross_network_incident_containment::
            set_operator_quarantined_for_testing(
                &mut containment,
                operator_a(),
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                10,
            );

        // Clean recovery observation.
        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        // STEP 1 — execution resume
        let incident_1 =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let snapshot_11 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_1,
                    11,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_11 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_11);

        let receipt_1 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_11,
                    &snapshot_11,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_1)
                ==
                cross_network_safe_release_control::
                    recovery_execution_resume(),
            0,
        );

        // STEP 2 — network release
        let snapshot_12 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_1,
                    12,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_12 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_12);

        let receipt_2 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_12,
                    &snapshot_12,
                    ctx,
                );

        // STEP 3 — domain release
        let snapshot_13 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_1,
                    13,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_13 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_13);

        let receipt_3 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_13,
                    &snapshot_13,
                    ctx,
                );

        // STEP 4 — operator release
        let snapshot_14 =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_1,
                    14,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision_14 =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_14);

        let receipt_4 =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision_14,
                    &snapshot_14,
                    ctx,
                );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_2)
                ==
                cross_network_safe_release_control::
                    recovery_network_release(),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_3)
                ==
                cross_network_safe_release_control::
                    recovery_domain_release(),
            2,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt_4)
                ==
                cross_network_safe_release_control::
                    recovery_operator_release(),
            3,
        );

        assert!(
            cross_network_safe_release_control::
                recovery_count(&recovery) == 4,
            4,
        );

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_1);

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_2);

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_3);

        cross_network_safe_release_control::
            destroy_receipt_for_testing(receipt_4);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_11);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_12);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_13);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_14);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_1);

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_12_final_state_fully_recovered() {
        let mut scenario = test_scenario::begin(@0x1512);
        let ctx = scenario.ctx();

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        assert!(
            !cross_network_incident_containment::
                execution_paused(&containment),
            0,
        );

        assert!(
            !cross_network_incident_containment::
                network_quarantined(&containment),
            1,
        );

        assert!(
            !cross_network_incident_containment::
                domain_quarantined(&containment),
            2,
        );

        assert!(
            !cross_network_incident_containment::
                operator_quarantined(&containment),
            3,
        );

        assert!(
            cross_network_safe_release_control::
                recovery_count(&recovery) == 0,
            4,
        );

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        scenario.end();
    }
}
