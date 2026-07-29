#[test_only]
module tobmate_enterprise_security::cross_network_incident_containment_tests {

    use std::vector;
    use sui::test_scenario;

    use tobmate_enterprise_security::cross_network_security_telemetry;
    use tobmate_enterprise_security::cross_network_anomaly_scoring;
    use tobmate_enterprise_security::cross_network_incident_severity;
    use tobmate_enterprise_security::cross_network_security_snapshot;
    use tobmate_enterprise_security::cross_network_security_response_policy;
    use tobmate_enterprise_security::cross_network_incident_containment;

    fun net_a(): vector<u8> { b"network-a" }
    fun domain_a(): vector<u8> { b"domain-a" }
    fun operator_a(): vector<u8> { b"operator-a" }

    fun make_single_critical_snapshot(
        telemetry:
            &mut cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,

        anomaly:
            &cross_network_anomaly_scoring::
                AnomalyScoringPolicy,

        incident_policy:
            &cross_network_incident_severity::
                IncidentThresholdPolicy,

        incident_state:
            &mut cross_network_incident_severity::
                IncidentSeverityState,

        sequence: u64,
        ctx: &mut sui::tx_context::TxContext,
    ): cross_network_security_snapshot::SecuritySnapshot {

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

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    anomaly,
                    telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                incident_policy,
                incident_state,
                score,
            );

        cross_network_security_snapshot::
            capture(
                telemetry,
                anomaly,
                incident_policy,
                incident_state,
                sequence,
                net_a(),
                domain_a(),
                operator_a(),
                ctx,
            )
    }

    #[test]
    fun test_01_operator_quarantine_execution() {
        let mut scenario = test_scenario::begin(@0x1301);
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

        let snapshot =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                1,
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
                operator_quarantined(&containment),
            0,
        );

        assert!(
            cross_network_incident_containment::
                receipt_scope_type(&receipt)
                ==
                cross_network_incident_containment::
                    scope_operator(),
            1,
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
    fun test_02_repeated_critical_execution_pause() {
        let mut scenario = test_scenario::begin(@0x1302);
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

        let snapshot_a =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                1,
                ctx,
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

        let snapshot_b =
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
                evaluate(&response, &snapshot_b);

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
            0,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_a);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_b);

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
    fun test_03_receipt_binding() {
        let mut scenario = test_scenario::begin(@0x1303);
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

        let snapshot =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                33,
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
                receipt_snapshot_sequence(&receipt) == 33,
            0,
        );

        assert!(
            cross_network_incident_containment::
                receipt_policy_version(&receipt) == 1,
            1,
        );

        assert!(
            cross_network_incident_containment::
                receipt_scope_type(&receipt)
                ==
                cross_network_incident_containment::
                    scope_operator(),
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
    fun test_04_containment_count_increments() {
        let mut scenario = test_scenario::begin(@0x1304);
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

        let snapshot =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                4,
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
                containment_count(&containment) == 1,
            0,
        );

        assert!(
            cross_network_incident_containment::
                receipt_containment_count_after(&receipt) == 1,
            1,
        );

        assert!(
            cross_network_incident_containment::
                escalation_count(&containment) == 0,
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
    #[expected_failure(abort_code = 3)]
    fun test_05_stale_decision_rejected() {
        let mut scenario = test_scenario::begin(@0x1305);
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

        let snapshot =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                5,
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

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt);

        // Same decision/snapshot cannot be reused.
        let _receipt2 =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_06_paused_executor_rejected() {
        let mut scenario = test_scenario::begin(@0x1306);
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

        let snapshot =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                6,
                ctx,
            );

        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        cross_network_incident_containment::
            set_paused(
                &mut containment,
                true,
            );

        let _receipt =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        abort 999
    }

    #[test]
    fun test_07_state_version_upgrade() {
        let mut scenario = test_scenario::begin(@0x1307);
        let ctx = scenario.ctx();

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        cross_network_incident_containment::
            set_version(
                &mut containment,
                2,
            );

        assert!(
            cross_network_incident_containment::
                version(&containment) == 2,
            0,
        );

        assert!(
            cross_network_incident_containment::
                protocol_version(&containment) == 1,
            1,
        );

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        scenario.end();
    }

    #[test]
    fun test_08_operator_scope_persists() {
        let mut scenario = test_scenario::begin(@0x1308);
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

        let snapshot =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                8,
                ctx,
            );

        let decision =
            cross_network_security_response_policy::
                evaluate(
                    &response,
                    &snapshot,
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
                operator_id(&containment)
                == &operator_a(),
            0,
        );

        assert!(
            cross_network_incident_containment::
                last_snapshot_sequence(
                    &containment,
                ) == 8,
            1,
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
    #[expected_failure(abort_code = 6)]
    fun test_09_non_increasing_version_rejected() {
        let mut scenario = test_scenario::begin(@0x1309);
        let ctx = scenario.ctx();

        let mut containment =
            cross_network_incident_containment::
                new_state_for_testing(ctx);

        cross_network_incident_containment::
            set_version(
                &mut containment,
                1,
            );

        abort 999
    }

    #[test]
    fun test_10_execution_pause_receipt_binding() {
        let mut scenario = test_scenario::begin(@0x1310);
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

        let snapshot_a =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                9,
                ctx,
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

        let snapshot_b =
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
                evaluate(
                    &response,
                    &snapshot_b,
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
                receipt_scope_type(&receipt)
                ==
                cross_network_incident_containment::
                    scope_execution(),
            0,
        );

        assert!(
            cross_network_incident_containment::
                receipt_action(&receipt)
                ==
                cross_network_security_response_policy::
                    action_pause_execution(),
            1,
        );

        assert!(
            cross_network_incident_containment::
                receipt_snapshot_sequence(&receipt)
                    == 10,
            2,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_a);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_b);

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
    fun test_11_containment_escalation_accounting() {
        let mut scenario = test_scenario::begin(@0x1311);
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

        // First CRITICAL -> operator quarantine.
        let snapshot_a =
            make_single_critical_snapshot(
                &mut telemetry,
                &anomaly,
                &incident_policy,
                &mut incident_state,
                11,
                ctx,
            );

        let decision_a =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_a);

        let receipt_a =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision_a,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        // Second CRITICAL -> execution pause.
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

        let decision_b =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot_b);

        let receipt_b =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision_b,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        assert!(
            cross_network_incident_containment::
                containment_count(&containment) == 2,
            0,
        );

        assert!(
            cross_network_incident_containment::
                escalation_count(&containment) == 1,
            1,
        );

        assert!(
            cross_network_incident_containment::
                receipt_escalation_count_after(
                    &receipt_b,
                ) == 1,
            2,
        );

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt_a);

        cross_network_incident_containment::
            destroy_receipt_for_testing(receipt_b);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_a);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_b);

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
    #[expected_failure(abort_code = 1)]
    fun test_12_non_containment_decision_rejected() {
        let mut scenario = test_scenario::begin(@0x1312);
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
                    13,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        // Clean state produces RECOVERY_ELIGIBLE, not containment.
        let decision =
            cross_network_security_response_policy::
                evaluate(&response, &snapshot);

        let _receipt =
            cross_network_incident_containment::
                execute(
                    &mut containment,
                    &decision,
                    operator_a(),
                    domain_a(),
                    net_a(),
                    ctx,
                );

        abort 999
    }
}
