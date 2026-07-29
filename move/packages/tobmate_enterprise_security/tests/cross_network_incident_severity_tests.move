#[test_only]
module tobmate_enterprise_security::cross_network_incident_severity_tests {

    use sui::test_scenario;
    use tobmate_enterprise_security::cross_network_incident_severity;

    #[test]
    fun test_01_default_policy() {
        let mut scenario = test_scenario::begin(@0xC01);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        assert!(
            cross_network_incident_severity::
                watch_threshold_bps(&policy) == 2_000,
            0,
        );

        assert!(
            cross_network_incident_severity::
                warning_threshold_bps(&policy) == 4_000,
            1,
        );

        assert!(
            cross_network_incident_severity::
                critical_threshold_bps(&policy) == 7_000,
            2,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        scenario.end();
    }

    #[test]
    fun test_02_initial_state_normal() {
        let mut scenario = test_scenario::begin(@0xC02);
        let ctx = scenario.ctx();

        let state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        assert!(
            cross_network_incident_severity::
                current_severity(&state)
                ==
                cross_network_incident_severity::
                    severity_normal(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                evaluation_count(&state) == 0,
            1,
        );

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_03_normal_to_watch() {
        let mut scenario = test_scenario::begin(@0xC03);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        let severity =
            cross_network_incident_severity::
                evaluate(
                    &policy,
                    &mut state,
                    2_000,
                );

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_watch(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                escalation_count(&state) == 1,
            1,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_04_watch_to_warning() {
        let mut scenario = test_scenario::begin(@0xC04);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 2_000);

        let severity =
            cross_network_incident_severity::
                evaluate(&policy, &mut state, 4_000);

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_warning(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                escalation_count(&state) == 2,
            1,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_05_warning_to_critical() {
        let mut scenario = test_scenario::begin(@0xC05);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 4_000);

        let severity =
            cross_network_incident_severity::
                evaluate(&policy, &mut state, 7_000);

        assert!(
            severity ==
                cross_network_incident_severity::
                    severity_critical(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                critical_count(&state) == 1,
            1,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_06_critical_to_warning() {
        let mut scenario = test_scenario::begin(@0xC06);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 7_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 6_999);

        assert!(
            cross_network_incident_severity::
                current_severity(&state)
                ==
                cross_network_incident_severity::
                    severity_warning(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                deescalation_count(&state) == 1,
            1,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_07_warning_to_watch() {
        let mut scenario = test_scenario::begin(@0xC07);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 4_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 3_999);

        assert!(
            cross_network_incident_severity::
                current_severity(&state)
                ==
                cross_network_incident_severity::
                    severity_watch(),
            0,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_08_watch_to_normal() {
        let mut scenario = test_scenario::begin(@0xC08);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 2_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 1_999);

        assert!(
            cross_network_incident_severity::
                current_severity(&state)
                ==
                cross_network_incident_severity::
                    severity_normal(),
            0,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_09_exact_threshold_boundaries() {
        let mut scenario = test_scenario::begin(@0xC09);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        assert!(
            cross_network_incident_severity::
                classify_score(&policy, 1_999)
                ==
                cross_network_incident_severity::
                    severity_normal(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                classify_score(&policy, 2_000)
                ==
                cross_network_incident_severity::
                    severity_watch(),
            1,
        );

        assert!(
            cross_network_incident_severity::
                classify_score(&policy, 4_000)
                ==
                cross_network_incident_severity::
                    severity_warning(),
            2,
        );

        assert!(
            cross_network_incident_severity::
                classify_score(&policy, 7_000)
                ==
                cross_network_incident_severity::
                    severity_critical(),
            3,
        );

        assert!(
            cross_network_incident_severity::
                classify_score(&policy, 10_000)
                ==
                cross_network_incident_severity::
                    severity_critical(),
            4,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        scenario.end();
    }

    #[test]
    fun test_10_same_severity_increments_unchanged() {
        let mut scenario = test_scenario::begin(@0xC10);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 2_500);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 3_000);

        assert!(
            cross_network_incident_severity::
                unchanged_count(&state) == 1,
            0,
        );

        assert!(
            cross_network_incident_severity::
                evaluation_count(&state) == 2,
            1,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    fun test_11_repeated_critical_accounting() {
        let mut scenario = test_scenario::begin(@0xC11);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 7_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 8_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 9_000);

        assert!(
            cross_network_incident_severity::
                critical_count(&state) == 3,
            0,
        );

        assert!(
            cross_network_incident_severity::
                escalation_count(&state) == 1,
            1,
        );

        assert!(
            cross_network_incident_severity::
                unchanged_count(&state) == 2,
            2,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_12_invalid_threshold_order_rejected() {
        let mut scenario = test_scenario::begin(@0xC12);
        let ctx = scenario.ctx();

        let _policy =
            cross_network_incident_severity::
                new_policy(
                    4_000,
                    2_000,
                    7_000,
                    ctx,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_13_threshold_above_max_rejected() {
        let mut scenario = test_scenario::begin(@0xC13);
        let ctx = scenario.ctx();

        let _policy =
            cross_network_incident_severity::
                new_policy(
                    2_000,
                    4_000,
                    10_001,
                    ctx,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_14_paused_policy_blocks_classification() {
        let mut scenario = test_scenario::begin(@0xC14);
        let ctx = scenario.ctx();

        let mut policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        cross_network_incident_severity::
            set_paused(&mut policy, true);

        let _severity =
            cross_network_incident_severity::
                classify_score(
                    &policy,
                    2_000,
                );

        abort 999
    }

    #[test]
    #[expected_failure(abort_code = 6)]
    fun test_15_score_above_max_rejected() {
        let mut scenario = test_scenario::begin(@0xC15);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let _severity =
            cross_network_incident_severity::
                classify_score(
                    &policy,
                    10_001,
                );

        abort 999
    }

    #[test]
    fun test_16_full_escalation_deescalation_cycle() {
        let mut scenario = test_scenario::begin(@0xC16);
        let ctx = scenario.ctx();

        let policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(ctx);

        let mut state =
            cross_network_incident_severity::
                new_state_for_testing(ctx);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 2_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 4_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 7_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 6_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 3_000);

        cross_network_incident_severity::
            evaluate(&policy, &mut state, 1_000);

        assert!(
            cross_network_incident_severity::
                current_severity(&state)
                ==
                cross_network_incident_severity::
                    severity_normal(),
            0,
        );

        assert!(
            cross_network_incident_severity::
                escalation_count(&state) == 3,
            1,
        );

        assert!(
            cross_network_incident_severity::
                deescalation_count(&state) == 3,
            2,
        );

        assert!(
            cross_network_incident_severity::
                evaluation_count(&state) == 6,
            3,
        );

        cross_network_incident_severity::
            destroy_policy_for_testing(policy);

        cross_network_incident_severity::
            destroy_state_for_testing(state);

        scenario.end();
    }
}
