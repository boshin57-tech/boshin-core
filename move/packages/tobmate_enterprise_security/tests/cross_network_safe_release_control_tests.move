#[test_only]
module tobmate_enterprise_security::cross_network_safe_release_control_tests {

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

    #[test]
    fun test_01_initial_recovery_state() {
        let mut scenario = test_scenario::begin(@0x1401);
        let ctx = scenario.ctx();

        let recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        assert!(
            cross_network_safe_release_control::
                recovery_count(&recovery) == 0,
            0,
        );

        assert!(
            cross_network_safe_release_control::
                last_snapshot_sequence(&recovery) == 0,
            1,
        );

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_02_no_active_containment_rejected() {
        let mut scenario = test_scenario::begin(@0x1402);
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
                    2,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        let _receipt =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision,
                    &snapshot,
                    ctx,
                );

        abort 999
    }

    #[test]
    fun test_03_recovery_state_version_upgrade() {
        let mut scenario = test_scenario::begin(@0x1403);
        let ctx = scenario.ctx();

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        cross_network_safe_release_control::
            set_version(&mut recovery, 2);

        assert!(
            cross_network_safe_release_control::
                version(&recovery) == 2,
            0,
        );

        assert!(
            cross_network_safe_release_control::
                protocol_version(&recovery) == 1,
            1,
        );

        cross_network_safe_release_control::
            destroy_state_for_testing(recovery);

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_04_paused_recovery_rejected() {
        let mut scenario = test_scenario::begin(@0x1404);
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

        cross_network_safe_release_control::
            set_paused(&mut recovery, true);

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
                    4,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        let _receipt =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision,
                    &snapshot,
                    ctx,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_05_stale_snapshot_rejected() {
        let mut scenario = test_scenario::begin(@0x1405);
        let ctx = scenario.ctx();

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        // Simulate containment already processed at snapshot 5.
        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                5,
            );

        // Simulate recovery already observing snapshot 5.
        cross_network_safe_release_control::
            set_last_snapshot_sequence_for_testing(
                &mut recovery,
                5,
            );

        // Incoming sequence 5 is stale.
        cross_network_safe_release_control::
            assert_fresh_sequence_for_testing(
                &recovery,
                &containment,
                5,
            );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_06_non_recovery_decision_rejected() {
        let mut scenario = test_scenario::begin(@0x1406);
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

        let mut recovery =
            cross_network_safe_release_control::
                new_state_for_testing(ctx);

        // Critical incident.
        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_rate_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_risk_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_compliance_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_operator_trust_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

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
                    6,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        let _receipt =
            cross_network_safe_release_control::
                execute_next_release(
                    &mut recovery,
                    &mut containment,
                    &decision,
                    &snapshot,
                    ctx,
                );

        abort 999
    }

    #[test]
    fun test_07_execution_resume_first() {
        let mut scenario = test_scenario::begin(@0x1407);
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
            set_execution_paused_for_testing(
                &mut containment,
                true,
            );

        cross_network_incident_containment::
            set_last_snapshot_sequence_for_testing(
                &mut containment,
                6,
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
                    7,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

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
            0,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt)
                ==
                cross_network_safe_release_control::
                    recovery_execution_resume(),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                execution_resume_count(&recovery) == 1,
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
    fun test_08_operator_release_after_resume() {
        let mut scenario = test_scenario::begin(@0x1408);
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
                7,
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
                    8,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

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
                operator_quarantined(&containment),
            0,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt)
                ==
                cross_network_safe_release_control::
                    recovery_operator_release(),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                operator_release_count(&recovery) == 1,
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
    fun test_09_network_release_before_domain() {
        let mut scenario = test_scenario::begin(@0x1409);
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

        let snapshot =
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

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

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
                network_quarantined(&containment),
            0,
        );

        assert!(
            cross_network_incident_containment::
                domain_quarantined(&containment),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt)
                ==
                cross_network_safe_release_control::
                    recovery_network_release(),
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
    fun test_10_domain_release_before_operator() {
        let mut scenario = test_scenario::begin(@0x1410);
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
                9,
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
                    10,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

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
                domain_quarantined(&containment),
            0,
        );

        assert!(
            cross_network_incident_containment::
                operator_quarantined(&containment),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_action(&receipt)
                ==
                cross_network_safe_release_control::
                    recovery_domain_release(),
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
    fun test_11_ordered_multi_step_recovery() {
        let mut scenario = test_scenario::begin(@0x1411);
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

        // All containment layers active.
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

        // Clean telemetry -> recovery eligible.
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
                    recovery_execution_resume(),
            0,
        );

        // Next fresh snapshot -> network release.
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
                    recovery_network_release(),
            1,
        );

        assert!(
            cross_network_safe_release_control::
                recovery_count(&recovery) == 2,
            2,
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
    fun test_12_recovery_receipt_counters() {
        let mut scenario = test_scenario::begin(@0x1412);
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
                11,
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
                    12,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

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
                receipt_recovery_count_after(&receipt) == 1,
            0,
        );

        assert!(
            cross_network_safe_release_control::
                operator_release_count(&recovery) == 1,
            1,
        );

        assert!(
            cross_network_safe_release_control::
                receipt_snapshot_sequence(&receipt) == 12,
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
}
