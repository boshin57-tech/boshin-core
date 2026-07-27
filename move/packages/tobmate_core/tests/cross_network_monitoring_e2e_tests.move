#[test_only]
module tobmate_core::cross_network_monitoring_e2e_tests {

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

    // ============================================================
    // TEST 01
    // Clean execution -> zero anomaly -> NORMAL -> valid audit
    // ============================================================

    #[test]
    fun test_01_clean_execution_full_pipeline() {
        let mut scenario =
            test_scenario::begin(@0xF01);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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

        let composite =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        assert!(composite == 0, 0);

        let severity =
            cross_network_incident_severity::
                evaluate(
                    &incident_policy,
                    &mut incident_state,
                    composite,
                );

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_normal(),
            1,
        );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    1,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        assert!(
            cross_network_security_audit_export::
                export_matches_snapshot(
                    &export,
                    &snapshot,
                ),
            2,
        );

        cross_network_security_audit_export::
            verify_export(
                &export,
                &snapshot,
            );

        cross_network_security_audit_export::
            destroy_for_testing(export);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 02
    // Failure -> deterministic anomaly -> snapshot persistence
    // ============================================================

    #[test]
    fun test_02_failure_pipeline() {
        let mut scenario =
            test_scenario::begin(@0xF02);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
            record_execution_failure(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let composite =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        assert!(composite == 1_000, 0);

        let severity =
            cross_network_incident_severity::
                evaluate(
                    &incident_policy,
                    &mut incident_state,
                    composite,
                );

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_normal(),
            1,
        );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly_policy,
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
                composite_anomaly_score_bps(
                    &snapshot,
                ) == 1_000,
            2,
        );

        assert!(
            cross_network_security_snapshot::
                total_failures(&snapshot) == 1,
            3,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 03
    // Compliance violation -> WATCH severity
    // ============================================================

    #[test]
    fun test_03_compliance_violation_escalates_watch() {
        let mut scenario =
            test_scenario::begin(@0xF03);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
            record_compliance_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let composite =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        assert!(composite == 2_500, 0);

        let severity =
            cross_network_incident_severity::
                evaluate(
                    &incident_policy,
                    &mut incident_state,
                    composite,
                );

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_watch(),
            1,
        );

        assert!(
            cross_network_incident_severity::
                escalation_count(
                    &incident_state,
                ) == 1,
            2,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 04
    // Multiple security violations -> CRITICAL
    // ============================================================

    #[test]
    fun test_04_multi_violation_critical_pipeline() {
        let mut scenario =
            test_scenario::begin(@0xF04);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
            record_execution_failure(
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

        let composite =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        assert!(composite == 9_000, 0);

        let severity =
            cross_network_incident_severity::
                evaluate(
                    &incident_policy,
                    &mut incident_state,
                    composite,
                );

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_critical(),
            1,
        );

        assert!(
            cross_network_incident_severity::
                critical_count(
                    &incident_state,
                ) == 1,
            2,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 05
    // Repeated observations escalate severity
    // ============================================================

    #[test]
    fun test_05_repeated_observations_escalate() {
        let mut scenario =
            test_scenario::begin(@0xF05);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        // WATCH
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

        let score_watch =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score_watch,
            );

        assert!(
            cross_network_incident_severity::
                current_severity(&incident_state)
                ==
                cross_network_incident_severity::
                    severity_watch(),
            0,
        );

        // Increase pressure to CRITICAL
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
            record_operator_trust_violation(
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

        let score_critical =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                score_critical,
            );

        assert!(
            cross_network_incident_severity::
                current_severity(&incident_state)
                ==
                cross_network_incident_severity::
                    severity_critical(),
            1,
        );

        assert!(
            cross_network_incident_severity::
                escalation_count(
                    &incident_state,
                ) == 2,
            2,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 06
    // Recovery lowers anomaly severity
    // ============================================================

    #[test]
    fun test_06_recovery_deescalates() {
        let mut scenario =
            test_scenario::begin(@0xF06);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        // Initial compliance violation -> WATCH
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

        let initial_score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                initial_score,
            );

        assert!(
            cross_network_incident_severity::
                current_severity(&incident_state)
                ==
                cross_network_incident_severity::
                    severity_watch(),
            0,
        );

        // Add nine clean attempts.
        // Compliance ratio becomes 1 / 10.
        let mut i = 0;

        while (i < 9) {
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

            i = i + 1;
        };

        let recovered_score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                recovered_score,
            );

        assert!(
            recovered_score < 2_000,
            1,
        );

        assert!(
            cross_network_incident_severity::
                current_severity(&incident_state)
                ==
                cross_network_incident_severity::
                    severity_normal(),
            2,
        );

        assert!(
            cross_network_incident_severity::
                deescalation_count(
                    &incident_state,
                ) == 1,
            3,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 07
    // Snapshot remains immutable after telemetry changes
    // ============================================================

    #[test]
    fun test_07_snapshot_immutable_across_change() {
        let mut scenario =
            test_scenario::begin(@0xF07);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    7,
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

        cross_network_security_telemetry::
            record_execution_failure(
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
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 08
    // Security state change produces new audit digest
    // ============================================================

    #[test]
    fun test_08_security_change_changes_digest() {
        let mut scenario =
            test_scenario::begin(@0xF08);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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

        let snapshot_a =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    8,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let digest_a =
            cross_network_security_audit_export::
                snapshot_digest(
                    &snapshot_a,
                    1,
                );

        cross_network_security_telemetry::
            record_compliance_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
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
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    9,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let digest_b =
            cross_network_security_audit_export::
                snapshot_digest(
                    &snapshot_b,
                    1,
                );

        assert!(
            digest_a != digest_b,
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_a);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_b);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 09
    // Audit export verifies final security state
    // ============================================================

    #[test]
    fun test_09_final_state_audit_verification() {
        let mut scenario =
            test_scenario::begin(@0xF09);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
            record_risk_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
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
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    9,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    9,
                    ctx,
                );

        cross_network_security_audit_export::
            verify_export(
                &export,
                &snapshot,
            );

        assert!(
            cross_network_security_audit_export::
                export_matches_snapshot(
                    &export,
                    &snapshot,
                ),
            0,
        );

        cross_network_security_audit_export::
            destroy_for_testing(export);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 10
    // Different snapshots cannot share identical audit digest
    // ============================================================

    #[test]
    fun test_10_distinct_snapshots_distinct_digest() {
        let mut scenario =
            test_scenario::begin(@0xF10);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    10,
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

        cross_network_security_telemetry::
            record_execution_failure(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let snapshot_b =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    11,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let digest_a =
            cross_network_security_audit_export::
                snapshot_digest(
                    &snapshot_a,
                    1,
                );

        let digest_b =
            cross_network_security_audit_export::
                snapshot_digest(
                    &snapshot_b,
                    1,
                );

        assert!(
            digest_a != digest_b,
            0,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_a);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot_b);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    // ============================================================
    // TEST 11
    // Tampered audit record rejected
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_11_tampered_audit_rejected_e2e() {
        let mut scenario =
            test_scenario::begin(@0xF11);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
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
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    11,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let mut export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    1,
                    ctx,
                );

        cross_network_security_audit_export::
            tamper_digest_for_testing(
                &mut export,
                vector[9, 9, 9],
            );

        cross_network_security_audit_export::
            verify_export(
                &export,
                &snapshot,
            );

        abort 999
    }

    // ============================================================
    // TEST 12
    // Full monitoring lifecycle
    // ============================================================

    #[test]
    fun test_12_full_monitoring_lifecycle() {
        let mut scenario =
            test_scenario::begin(@0xF12);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let anomaly_policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut incident_state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        // Clean state
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

        let clean_score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                clean_score,
            );

        // Security deterioration
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
            record_operator_trust_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let degraded_score =
            cross_network_anomaly_scoring::
                score_composite(
                    &anomaly_policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        cross_network_incident_severity::
            evaluate(
                &incident_policy,
                &mut incident_state,
                degraded_score,
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly_policy,
                    &incident_policy,
                    &incident_state,
                    12,
                    net_a(),
                    domain_a(),
                    operator_a(),
                    ctx,
                );

        let export =
            cross_network_security_audit_export::
                create_export(
                    &snapshot,
                    12,
                    ctx,
                );

        assert!(
            cross_network_security_snapshot::
                total_security_violations(
                    &snapshot,
                ) == 3,
            0,
        );

        assert!(
            cross_network_security_snapshot::
                composite_anomaly_score_bps(
                    &snapshot,
                ) == degraded_score,
            1,
        );

        assert!(
            cross_network_security_audit_export::
                export_matches_snapshot(
                    &export,
                    &snapshot,
                ),
            2,
        );

        cross_network_security_audit_export::
            verify_export(
                &export,
                &snapshot,
            );

        cross_network_security_audit_export::
            destroy_for_testing(export);

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(
                anomaly_policy,
            );

        cross_network_incident_severity::
            destroy_policy_for_testing(
                incident_policy,
            );

        cross_network_incident_severity::
            destroy_state_for_testing(
                incident_state,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }
}
