#[test_only]
module tobmate_enterprise_security::cross_network_security_response_policy_tests {

    use std::vector;
    use sui::test_scenario;

    use tobmate_enterprise_security::cross_network_security_telemetry;
    use tobmate_enterprise_security::cross_network_anomaly_scoring;
    use tobmate_enterprise_security::cross_network_incident_severity;
    use tobmate_enterprise_security::cross_network_security_snapshot;
    use tobmate_enterprise_security::cross_network_security_response_policy;

    fun net_a(): vector<u8> { b"network-a" }
    fun domain_a(): vector<u8> { b"domain-a" }
    fun operator_a(): vector<u8> { b"operator-a" }

    #[test]
    fun test_01_default_policy() {
        let mut scenario = test_scenario::begin(@0x1201);
        let ctx = scenario.ctx();

        let policy =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        assert!(
            cross_network_security_response_policy::
                warning_score_threshold_bps(&policy) == 2_000,
            0,
        );

        assert!(
            cross_network_security_response_policy::
                critical_score_threshold_bps(&policy) == 7_000,
            1,
        );

        assert!(
            cross_network_security_response_policy::
                critical_repeat_threshold(&policy) == 2,
            2,
        );

        cross_network_security_response_policy::
            destroy_policy_for_testing(policy);

        scenario.end();
    }

    #[test]
    fun test_02_clean_state_recovery_eligible() {
        let mut scenario = test_scenario::begin(@0x1202);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

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
            cross_network_security_snapshot::capture(
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
                    action_recovery_eligible(),
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_03_watch_state_monitor() {
        let mut scenario = test_scenario::begin(@0x1203);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

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

        cross_network_security_telemetry::
            record_execution_attempt(
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

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                2_500,
            );

        let snapshot =
            cross_network_security_snapshot::capture(
                &telemetry,
                &anomaly,
                &incident_policy,
                &incident_state,
                3,
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
                    action_restrict(),
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_04_single_critical_operator_quarantine() {
        let mut scenario = test_scenario::begin(@0x1204);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

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

        cross_network_security_telemetry::
            record_execution_attempt(
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
            record_risk_violation(
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
            record_operator_trust_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                7_000,
            );

        let snapshot =
            cross_network_security_snapshot::capture(
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

        assert!(
            cross_network_security_response_policy::
                operator_quarantine_eligible(&decision),
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_05_repeated_critical_pause_eligible() {
        let mut scenario = test_scenario::begin(@0x1205);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

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

        cross_network_security_telemetry::
            record_execution_attempt(
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
            record_risk_violation(
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
            record_operator_trust_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                7_500,
            );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                8_000,
            );

        let snapshot =
            cross_network_security_snapshot::capture(
                &telemetry,
                &anomaly,
                &incident_policy,
                &incident_state,
                5,
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
                execution_pause_eligible(&decision),
            0,
        );

        assert!(
            cross_network_security_response_policy::
                decision_action(&decision)
                ==
                cross_network_security_response_policy::
                    action_pause_execution(),
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    #[expected_failure(abort_code = 4)]
    fun test_06_paused_policy_rejects_evaluation() {
        let mut scenario = test_scenario::begin(@0x1206);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let mut response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_response_policy::
            set_paused(&mut response, true);

        let snapshot =
            cross_network_security_snapshot::capture(
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

        let _decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        abort 999
    }

    #[test]
    fun test_07_capability_disable_blocks_pause() {
        let mut scenario = test_scenario::begin(@0x1207);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let mut response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        cross_network_security_response_policy::
            set_capabilities(
                &mut response,
                true,
                true,
                true,
                false,
                true,
            );

        cross_network_security_telemetry::
            record_execution_attempt(
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

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                8_000,
            );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                8_000,
            );

        let snapshot =
            cross_network_security_snapshot::capture(
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

        assert!(
            !cross_network_security_response_policy::
                execution_pause_eligible(&decision),
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_08_policy_version_bound_to_decision() {
        let mut scenario = test_scenario::begin(@0x1208);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let mut response =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        cross_network_security_response_policy::
            set_version(&mut response, 2);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot =
            cross_network_security_snapshot::capture(
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

        assert!(
            cross_network_security_response_policy::
                decision_policy_version(&decision) == 2,
            0,
        );

        assert!(
            cross_network_security_response_policy::
                decision_snapshot_sequence(&decision) == 8,
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    #[expected_failure(abort_code = 1)]
    fun test_09_threshold_above_max_rejected() {
        let mut scenario = test_scenario::begin(@0x1209);
        let ctx = scenario.ctx();

        let _policy =
            cross_network_security_response_policy::create(
                2_000,
                10_001,
                2,
                true,
                true,
                true,
                true,
                true,
                ctx,
            );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_10_invalid_threshold_order_rejected() {
        let mut scenario = test_scenario::begin(@0x1210);
        let ctx = scenario.ctx();

        let _policy =
            cross_network_security_response_policy::create(
                7_000,
                2_000,
                2,
                true,
                true,
                true,
                true,
                true,
                ctx,
            );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_11_zero_repeat_threshold_rejected() {
        let mut scenario = test_scenario::begin(@0x1211);
        let ctx = scenario.ctx();

        let _policy =
            cross_network_security_response_policy::create(
                2_000,
                7_000,
                0,
                true,
                true,
                true,
                true,
                true,
                ctx,
            );

        abort 999
    }

    #[test]
    fun test_12_capability_matrix_persists() {
        let mut scenario = test_scenario::begin(@0x1212);
        let ctx = scenario.ctx();

        let mut policy =
            cross_network_security_response_policy::
                new_default_policy_for_testing(ctx);

        cross_network_security_response_policy::
            set_capabilities(
                &mut policy,
                false,
                true,
                false,
                true,
                false,
            );

        assert!(
            !cross_network_security_response_policy::
                allow_operator_quarantine(&policy),
            0,
        );

        assert!(
            cross_network_security_response_policy::
                allow_domain_quarantine(&policy),
            1,
        );

        assert!(
            !cross_network_security_response_policy::
                allow_network_quarantine(&policy),
            2,
        );

        assert!(
            cross_network_security_response_policy::
                allow_execution_pause(&policy),
            3,
        );

        assert!(
            !cross_network_security_response_policy::
                allow_automatic_recovery(&policy),
            4,
        );

        cross_network_security_response_policy::
            destroy_policy_for_testing(policy);

        scenario.end();
    }
}
