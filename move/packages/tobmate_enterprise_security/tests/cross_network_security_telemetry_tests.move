#[test_only]
module tobmate_enterprise_security::cross_network_security_telemetry_tests {

    use std::vector;
    use sui::test_scenario;
    use tobmate_enterprise_security::cross_network_security_telemetry;

    fun net_a(): vector<u8> { b"network-a" }
    fun net_b(): vector<u8> { b"network-b" }

    fun domain_a(): vector<u8> { b"domain-a" }
    fun domain_b(): vector<u8> { b"domain-b" }

    fun operator_a(): vector<u8> { b"operator-a" }
    fun operator_b(): vector<u8> { b"operator-b" }

    #[test]
    fun test_01_initial_state() {
        let mut scenario = test_scenario::begin(@0xA11);
        let ctx = scenario.ctx();

        let telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        assert!(
            cross_network_security_telemetry::
                version(&telemetry) == 1,
            0,
        );

        assert!(
            !cross_network_security_telemetry::
                is_paused(&telemetry),
            1,
        );

        assert!(
            cross_network_security_telemetry::
                total_attempts(&telemetry) == 0,
            2,
        );

        assert!(
            cross_network_security_telemetry::
                total_security_violations(&telemetry) == 0,
            3,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_02_execution_success() {
        let mut scenario = test_scenario::begin(@0xA12);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

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

        assert!(
            cross_network_security_telemetry::
                total_attempts(&telemetry) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                total_successes(&telemetry) == 1,
            1,
        );

        cross_network_security_telemetry::
            assert_accounting_invariant(&telemetry);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_03_failure_rejection() {
        let mut scenario = test_scenario::begin(@0xA13);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

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
            record_execution_rejection(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        assert!(
            cross_network_security_telemetry::
                total_attempts(&telemetry) == 2,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                total_failures(&telemetry) == 1,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                total_rejections(&telemetry) == 1,
            2,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_04_violation_aggregation() {
        let mut scenario = test_scenario::begin(@0xA14);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

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

        assert!(
            cross_network_security_telemetry::
                total_security_violations(&telemetry) == 4,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                total_rate_violations(&telemetry) == 1,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                total_risk_violations(&telemetry) == 1,
            2,
        );

        assert!(
            cross_network_security_telemetry::
                total_compliance_violations(&telemetry) == 1,
            3,
        );

        assert!(
            cross_network_security_telemetry::
                total_operator_trust_violations(
                    &telemetry,
                ) == 1,
            4,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_05_network_isolation() {
        let mut scenario = test_scenario::begin(@0xA15);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_b(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_b(),
                domain_a(),
                operator_a(),
            );

        let a =
            cross_network_security_telemetry::
                network_counters(
                    &telemetry,
                    net_a(),
                );

        let b =
            cross_network_security_telemetry::
                network_counters(
                    &telemetry,
                    net_b(),
                );

        assert!(
            cross_network_security_telemetry::
                counter_attempts(&a) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                counter_attempts(&b) == 2,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                network_metric_count(&telemetry) == 2,
            2,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_06_domain_isolation() {
        let mut scenario = test_scenario::begin(@0xA16);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_b(),
                operator_a(),
            );

        let a =
            cross_network_security_telemetry::
                domain_counters(
                    &telemetry,
                    domain_a(),
                );

        let b =
            cross_network_security_telemetry::
                domain_counters(
                    &telemetry,
                    domain_b(),
                );

        assert!(
            cross_network_security_telemetry::
                counter_attempts(&a) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                counter_attempts(&b) == 1,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                domain_metric_count(&telemetry) == 2,
            2,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_07_operator_isolation() {
        let mut scenario = test_scenario::begin(@0xA17);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_attempt(
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
                operator_b(),
            );

        let a =
            cross_network_security_telemetry::
                operator_counters(
                    &telemetry,
                    operator_a(),
                );

        let b =
            cross_network_security_telemetry::
                operator_counters(
                    &telemetry,
                    operator_b(),
                );

        assert!(
            cross_network_security_telemetry::
                counter_attempts(&a) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                counter_attempts(&b) == 1,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                operator_metric_count(&telemetry) == 2,
            2,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_08_pause_version() {
        let mut scenario = test_scenario::begin(@0xA18);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            set_paused(&mut telemetry, true);

        assert!(
            cross_network_security_telemetry::
                is_paused(&telemetry),
            0,
        );

        cross_network_security_telemetry::
            set_paused(&mut telemetry, false);

        cross_network_security_telemetry::
            set_version(&mut telemetry, 2);

        assert!(
            cross_network_security_telemetry::
                version(&telemetry) == 2,
            1,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }


    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_09_outcome_without_attempt_rejected() {
        let mut scenario = test_scenario::begin(@0xA19);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_10_paused_telemetry_blocks_recording() {
        let mut scenario = test_scenario::begin(@0xA20);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            set_paused(&mut telemetry, true);

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_a(),
                domain_a(),
                operator_a(),
            );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_11_non_increasing_version_rejected() {
        let mut scenario = test_scenario::begin(@0xA21);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            set_version(&mut telemetry, 1);

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_12_duplicate_pause_state_rejected() {
        let mut scenario = test_scenario::begin(@0xA22);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        cross_network_security_telemetry::
            set_paused(&mut telemetry, true);

        cross_network_security_telemetry::
            set_paused(&mut telemetry, true);

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_13_missing_scoped_metric_rejected() {
        let mut scenario = test_scenario::begin(@0xA23);
        let ctx = scenario.ctx();

        let telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        let _missing =
            cross_network_security_telemetry::
                network_counters(
                    &telemetry,
                    b"unknown-network",
                );

        abort 999
    }

    #[test]
    fun test_14_multiple_scope_violation_isolation() {
        let mut scenario = test_scenario::begin(@0xA24);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

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
                net_b(),
                domain_b(),
                operator_b(),
            );

        cross_network_security_telemetry::
            record_compliance_violation(
                &mut telemetry,
                net_b(),
                domain_b(),
                operator_b(),
            );

        let net_a_counters =
            cross_network_security_telemetry::
                network_counters(
                    &telemetry,
                    net_a(),
                );

        let net_b_counters =
            cross_network_security_telemetry::
                network_counters(
                    &telemetry,
                    net_b(),
                );

        assert!(
            cross_network_security_telemetry::
                counter_rate_violations(
                    &net_a_counters,
                ) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                counter_risk_violations(
                    &net_a_counters,
                ) == 0,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                counter_rate_violations(
                    &net_b_counters,
                ) == 0,
            2,
        );

        assert!(
            cross_network_security_telemetry::
                counter_risk_violations(
                    &net_b_counters,
                ) == 1,
            3,
        );

        assert!(
            cross_network_security_telemetry::
                counter_compliance_violations(
                    &net_b_counters,
                ) == 1,
            4,
        );

        assert!(
            cross_network_security_telemetry::
                total_security_violations(
                    &telemetry,
                ) == 3,
            5,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_15_accounting_boundary_preserved() {
        let mut scenario = test_scenario::begin(@0xA25);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

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

        cross_network_security_telemetry::
            assert_accounting_invariant(
                &telemetry,
            );

        assert!(
            cross_network_security_telemetry::
                total_attempts(&telemetry) == 1,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                total_successes(&telemetry) == 1,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                total_failures(&telemetry) == 0,
            2,
        );

        assert!(
            cross_network_security_telemetry::
                total_rejections(&telemetry) == 0,
            3,
        );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }

    #[test]
    fun test_16_mixed_execution_outcomes_aggregate() {
        let mut scenario = test_scenario::begin(@0xA26);
        let ctx = scenario.ctx();

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(ctx);

        // success
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

        // failure
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

        // rejection
        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                net_b(),
                domain_b(),
                operator_b(),
            );

        cross_network_security_telemetry::
            record_execution_rejection(
                &mut telemetry,
                net_b(),
                domain_b(),
                operator_b(),
            );

        assert!(
            cross_network_security_telemetry::
                total_attempts(&telemetry) == 3,
            0,
        );

        assert!(
            cross_network_security_telemetry::
                total_successes(&telemetry) == 1,
            1,
        );

        assert!(
            cross_network_security_telemetry::
                total_failures(&telemetry) == 1,
            2,
        );

        assert!(
            cross_network_security_telemetry::
                total_rejections(&telemetry) == 1,
            3,
        );

        cross_network_security_telemetry::
            assert_accounting_invariant(
                &telemetry,
            );

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        scenario.end();
    }
}
