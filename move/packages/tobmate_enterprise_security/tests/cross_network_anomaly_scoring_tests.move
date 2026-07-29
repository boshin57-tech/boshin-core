#[test_only]
module tobmate_enterprise_security::cross_network_anomaly_scoring_tests {

    use std::vector;
    use sui::test_scenario;

    use tobmate_enterprise_security::cross_network_security_telemetry;
    use tobmate_enterprise_security::cross_network_anomaly_scoring;

    fun net_a(): vector<u8> { b"network-a" }
    fun net_b(): vector<u8> { b"network-b" }

    fun domain_a(): vector<u8> { b"domain-a" }
    fun domain_b(): vector<u8> { b"domain-b" }

    fun operator_a(): vector<u8> { b"operator-a" }
    fun operator_b(): vector<u8> { b"operator-b" }

    #[test]
    fun test_01_default_policy_weights() {
        let mut scenario =
            test_scenario::begin(@0xB01);

        let ctx = scenario.ctx();

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        assert!(
            cross_network_anomaly_scoring::
                failure_weight_bps(&policy) == 1_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                rejection_weight_bps(&policy) == 1_000,
            1,
        );

        assert!(
            cross_network_anomaly_scoring::
                compliance_violation_weight_bps(
                    &policy,
                ) == 2_500,
            2,
        );

        assert!(
            cross_network_anomaly_scoring::
                operator_trust_violation_weight_bps(
                    &policy,
                ) == 2_000,
            3,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        scenario.end();
    }

    #[test]
    fun test_02_clean_execution_scores_zero() {
        let mut scenario =
            test_scenario::begin(@0xB02);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
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

        let score =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score) == 0,
            0,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_03_failure_pressure_deterministic() {
        let mut scenario =
            test_scenario::begin(@0xB03);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

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

        let score =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                failure_pressure_bps(&score)
                    == 10_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score)
                    == 1_000,
            1,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_04_rejection_pressure_deterministic() {
        let mut scenario =
            test_scenario::begin(@0xB04);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_rejection(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let score =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                rejection_pressure_bps(&score)
                    == 10_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score)
                    == 1_000,
            1,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_05_compliance_violation_weight() {
        let mut scenario =
            test_scenario::begin(@0xB05);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
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

        let score =
            cross_network_anomaly_scoring::
                score_operator(
                    &policy,
                    &telemetry,
                    operator_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                compliance_violation_pressure_bps(
                    &score,
                ) == 10_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score)
                    == 2_500,
            1,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_06_operator_trust_violation_weight() {
        let mut scenario =
            test_scenario::begin(@0xB06);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
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
                score_operator(
                    &policy,
                    &telemetry,
                    operator_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score)
                    == 2_000,
            0,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_07_half_pressure_ratio() {
        let mut scenario =
            test_scenario::begin(@0xB07);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

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

        let score =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                failure_pressure_bps(&score)
                    == 5_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score)
                    == 500,
            1,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_08_scope_isolation() {
        let mut scenario =
            test_scenario::begin(@0xB08);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

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

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_b(),
                domain_b(),
                operator_b(),
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_b(),
                domain_b(),
                operator_b(),
            );

        let score_a =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        let score_b =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_b(),
                );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score_a)
                    == 2_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score_b)
                    == 0,
            1,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_09_composite_uses_max_scope() {
        let mut scenario =
            test_scenario::begin(@0xB09);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
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

        let composite =
            cross_network_anomaly_scoring::
                score_composite(
                    &policy,
                    &telemetry,
                    net_a(),
                    domain_a(),
                    operator_a(),
                );

        assert!(composite == 2_500, 0);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_10_zero_attempt_violation_max_pressure() {
        let mut scenario =
            test_scenario::begin(@0xB10);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        cross_network_security_telemetry::
            record_rate_violation(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        let score =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        assert!(
            cross_network_anomaly_scoring::
                rate_violation_pressure_bps(
                    &score,
                ) == 10_000,
            0,
        );

        assert!(
            cross_network_anomaly_scoring::
                final_score_bps(&score)
                    == 1_500,
            1,
        );

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(policy);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_11_invalid_weight_total_rejected() {
        let mut scenario =
            test_scenario::begin(@0xB11);

        let ctx = scenario.ctx();

        let _policy =
            cross_network_anomaly_scoring::
                new_policy(
                    1_000,
                    1_000,
                    1_000,
                    1_000,
                    1_000,
                    1_000,
                    ctx,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_12_paused_policy_blocks_scoring() {
        let mut scenario =
            test_scenario::begin(@0xB12);

        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let mut policy =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_anomaly_scoring::
            set_paused(
                &mut policy,
                true,
            );

        let _score =
            cross_network_anomaly_scoring::
                score_network(
                    &policy,
                    &telemetry,
                    net_a(),
                );

        abort 999
    }
}
