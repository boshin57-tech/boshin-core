#[test_only]
module tobmate_core::cross_network_security_audit_export_tests {

    use std::vector;
    use sui::test_scenario;

    use tobmate_core::cross_network_security_telemetry;
    use tobmate_core::cross_network_anomaly_scoring;
    use tobmate_core::cross_network_incident_severity;
    use tobmate_core::cross_network_security_snapshot;
    use tobmate_core::cross_network_security_audit_export;

    fun net_a(): vector<u8> { b"network-a" }
    fun domain_a(): vector<u8> { b"domain-a" }
    fun operator_a(): vector<u8> { b"operator-a" }

    #[test]
    fun test_01_same_snapshot_same_digest() {
        let mut scenario = test_scenario::begin(@0xE01);
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
                    1,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let digest_a =
            cross_network_security_audit_export::
                snapshot_digest(
                    &snapshot,
                    1,
                );

        let digest_b =
            cross_network_security_audit_export::
                snapshot_digest(
                    &snapshot,
                    1,
                );

        assert!(digest_a == digest_b, 0);

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
    fun test_02_export_sequence_changes_digest() {
        let mut scenario = test_scenario::begin(@0xE02);
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
                    2,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let digest_a =
            cross_network_security_audit_export::
                snapshot_digest(&snapshot, 1);

        let digest_b =
            cross_network_security_audit_export::
                snapshot_digest(&snapshot, 2);

        assert!(digest_a != digest_b, 0);

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
    fun test_03_export_record_matches_snapshot() {
        let mut scenario = test_scenario::begin(@0xE03);
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
                    3,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                export_matches_snapshot(
                    &record,
                    &snapshot,
                ),
            0,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    fun test_04_snapshot_sequence_bound() {
        let mut scenario = test_scenario::begin(@0xE04);
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
                    44,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    7,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                snapshot_sequence(&record) == 44,
            0,
        );

        assert!(
            cross_network_security_audit_export::
                export_sequence(&record) == 7,
            1,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    fun test_05_source_versions_bound() {
        let mut scenario = test_scenario::begin(@0xE05);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::new_for_testing(ctx);

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
            set_version(
                &mut anomaly,
                2,
            );

        cross_network_incident_severity::
            set_version(
                &mut incident_policy,
                3,
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

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                telemetry_version(&record) == 1,
            0,
        );

        assert!(
            cross_network_security_audit_export::
                anomaly_policy_version(&record) == 2,
            1,
        );

        assert!(
            cross_network_security_audit_export::
                incident_policy_version(&record) == 3,
            2,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    fun test_06_severity_bound() {
        let mut scenario = test_scenario::begin(@0xE06);
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

        cross_network_security_telemetry::
            record_execution_attempt(
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

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                current_severity(&record)
                ==
                cross_network_incident_severity::
                    severity_critical(),
            0,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    fun test_07_scope_binding_preserved() {
        let mut scenario = test_scenario::begin(@0xE07);
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
                    7,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                network_id(&record) == &net_a(),
            0,
        );

        assert!(
            cross_network_security_audit_export::
                domain_id(&record) == &domain_a(),
            1,
        );

        assert!(
            cross_network_security_audit_export::
                operator_id(&record) == &operator_a(),
            2,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    fun test_08_score_binding_preserved() {
        let mut scenario = test_scenario::begin(@0xE08);
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
                    8,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                composite_anomaly_score_bps(&record)
                    ==
            cross_network_security_snapshot::
                composite_anomaly_score_bps(&snapshot),
            0,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    fun test_09_digest_length_is_32_bytes() {
        let mut scenario = test_scenario::begin(@0xE09);
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
                    9,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            vector::length(
                cross_network_security_audit_export::
                    audit_digest(&record),
            ) == 32,
            0,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
    #[expected_failure(abort_code = 2)]
    fun test_10_zero_export_sequence_rejected() {
        let mut scenario = test_scenario::begin(@0xE10);
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
                    10,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let _record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    0,
                    ctx,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_11_tampered_digest_rejected() {
        let mut scenario = test_scenario::begin(@0xE11);
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
                    11,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let mut record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        cross_network_security_audit_export::
            tamper_digest_for_testing(
                &mut record,
                vector[1, 2, 3],
            );

        cross_network_security_audit_export::
            verify_export(
                &record,
                &snapshot,
            );

        abort 999
    }

    #[test]
    fun test_12_verify_export_success() {
        let mut scenario = test_scenario::begin(@0xE12);
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

        let record =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        cross_network_security_audit_export::
            verify_export(
                &record,
                &snapshot,
            );

        assert!(
            cross_network_security_audit_export::
                export_matches_snapshot(
                    &record,
                    &snapshot,
                ),
            0,
        );

        cross_network_security_audit_export::
            destroy_for_testing(record);

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
