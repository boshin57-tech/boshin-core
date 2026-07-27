#[test_only]
module tobmate_core::cross_network_security_snapshot_tests {

    use std::vector;
    use sui::test_scenario;

    use tobmate_core::cross_network_security_telemetry;
    use tobmate_core::cross_network_anomaly_scoring;
    use tobmate_core::cross_network_incident_severity;
    use tobmate_core::cross_network_security_snapshot;

    fun net_a(): vector<u8> { b"network-a" }
    fun domain_a(): vector<u8> { b"domain-a" }
    fun operator_a(): vector<u8> { b"operator-a" }

    #[test]
    fun test_01_clean_snapshot() {
        let mut scenario = test_scenario::begin(@0xD01);
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
                    1,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        assert!(
            cross_network_security_snapshot::
                snapshot_sequence(&snapshot) == 1,
            0,
        );

        assert!(
            cross_network_security_snapshot::
                total_attempts(&snapshot) == 1,
            1,
        );

        assert!(
            cross_network_security_snapshot::
                composite_anomaly_score_bps(
                    &snapshot,
                ) == 0,
            2,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_02_failure_snapshot_score() {
        let mut scenario = test_scenario::begin(@0xD02);
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
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_failure(
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

        assert!(
            cross_network_security_snapshot::
                network_anomaly_score_bps(
                    &snapshot,
                ) == 1_000,
            0,
        );

        assert!(
            cross_network_security_snapshot::
                total_failures(&snapshot) == 1,
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_03_incident_state_captured() {
        let mut scenario = test_scenario::begin(@0xD03);
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

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                4_500,
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
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

        assert!(
            cross_network_security_snapshot::
                current_severity(&snapshot)
                ==
                cross_network_incident_severity::
                    severity_warning(),
            0,
        );

        assert!(
            cross_network_security_snapshot::
                incident_evaluation_count(
                    &snapshot,
                ) == 1,
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_04_source_versions_captured() {
        let mut scenario = test_scenario::begin(@0xD04);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let mut anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let mut incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_anomaly_scoring::
            set_version(&mut anomaly, 2);

        cross_network_incident_severity::
            set_version(&mut incident_policy, 3);

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

        assert!(
            cross_network_security_snapshot::
                telemetry_version(&snapshot) == 1,
            0,
        );

        assert!(
            cross_network_security_snapshot::
                anomaly_policy_version(
                    &snapshot,
                ) == 2,
            1,
        );

        assert!(
            cross_network_security_snapshot::
                incident_policy_version(
                    &snapshot,
                ) == 3,
            2,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_05_snapshot_is_immutable_copy() {
        let mut scenario = test_scenario::begin(@0xD05);
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
                    5,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        assert!(
            cross_network_security_snapshot::
                total_attempts(&snapshot) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                total_attempts(&telemetry) == 2,
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_06_composite_matches_scope_score() {
        let mut scenario = test_scenario::begin(@0xD06);
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

        assert!(
            cross_network_security_snapshot::
                composite_anomaly_score_bps(
                    &snapshot,
                ) == 2_500,
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_07_sequence_preserved() {
        let mut scenario = test_scenario::begin(@0xD07);
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
                    99,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        assert!(
            cross_network_security_snapshot::
                snapshot_sequence(&snapshot) == 99,
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_08_scope_ids_preserved() {
        let mut scenario = test_scenario::begin(@0xD08);
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

        assert!(
            cross_network_security_snapshot::
                network_id(&snapshot) == &net_a(),
            0,
        );

        assert!(
            cross_network_security_snapshot::
                domain_id(&snapshot) == &domain_a(),
            1,
        );

        assert!(
            cross_network_security_snapshot::
                operator_id(&snapshot) == &operator_a(),
            2,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_09_escalation_counters_captured() {
        let mut scenario = test_scenario::begin(@0xD09);
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

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_incident_severity::
            evaluate(&incident_policy, &mut incident_state, 2_000);

        cross_network_incident_severity::
            evaluate(&incident_policy, &mut incident_state, 4_000);

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

        assert!(
            cross_network_security_snapshot::
                incident_escalation_count(
                    &snapshot,
                ) == 2,
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_10_critical_state_captured() {
        let mut scenario = test_scenario::begin(@0xD10);
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

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_incident_severity::
            evaluate(&incident_policy, &mut incident_state, 7_000);

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

        assert!(
            cross_network_security_snapshot::
                current_severity(&snapshot)
                ==
                cross_network_incident_severity::
                    severity_critical(),
            0,
        );

        assert!(
            cross_network_security_snapshot::
                incident_critical_count(
                    &snapshot,
                ) == 1,
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
    fun test_11_multiple_snapshots_independent() {
        let mut scenario = test_scenario::begin(@0xD11);
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
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot_a =
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

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot_b =
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

        assert!(
            cross_network_security_snapshot::
                total_attempts(&snapshot_a) == 1,
            0,
        );

        assert!(
            cross_network_security_snapshot::
                total_attempts(&snapshot_b) == 2,
            1,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_a);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_b);

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
    fun test_12_protocol_version_fixed() {
        let mut scenario = test_scenario::begin(@0xD12);
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

        assert!(
            cross_network_security_snapshot::
                protocol_version(&snapshot) == 1,
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

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
