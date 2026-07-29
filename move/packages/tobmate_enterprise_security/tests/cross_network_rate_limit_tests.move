#[test_only]
module tobmate_enterprise_security::cross_network_rate_limit_tests {

    use tobmate_enterprise_security::cross_network_policy;
    use tobmate_enterprise_security::cross_network_rate_limit;


    #[test]
    fun test_01_consume_request_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_medium(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        assert!(
            cross_network_rate_limit::total_requests(
                &state,
            ) == 1,
            92101,
        );

        assert!(
            cross_network_rate_limit::operator_request_count(
                &state,
                @0xB,
            ) == 1,
            92102,
        );

        cross_network_rate_limit::
            destroy_rate_limit_state_for_testing(
                state,
            );

        cross_network_policy::
            destroy_policy_for_testing(
                policy,
            );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                policy_registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_02_multi_operator_accounting() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_low(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xC,
            1,
        );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        assert!(
            cross_network_rate_limit::operator_count(
                &state,
            ) == 2,
            92201,
        );

        assert!(
            cross_network_rate_limit::operator_request_count(
                &state,
                @0xB,
            ) == 2,
            92202,
        );

        assert!(
            cross_network_rate_limit::operator_request_count(
                &state,
                @0xC,
            ) == 1,
            92203,
        );

        assert!(
            cross_network_rate_limit::total_requests(
                &state,
            ) == 3,
            92204,
        );

        cross_network_rate_limit::
            destroy_rate_limit_state_for_testing(
                state,
            );

        cross_network_policy::
            destroy_policy_for_testing(
                policy,
            );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                policy_registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_03_operator_burst_boundary_allowed() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_critical(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut i = 0;

        while (i < 4) {
            cross_network_rate_limit::consume_request(
                &mut state,
                &policy,
                @0xB,
                1,
            );

            i = i + 1;
        };

        assert!(
            cross_network_rate_limit::operator_request_count(
                &state,
                @0xB,
            ) == 4,
            92301,
        );

        cross_network_rate_limit::
            destroy_rate_limit_state_for_testing(
                state,
            );

        cross_network_policy::
            destroy_policy_for_testing(
                policy,
            );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                policy_registry,
            );

        sui::test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1209202)]
    fun test_04_operator_rate_limit_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_critical(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut i = 0;

        while (i < 4) {
            cross_network_rate_limit::consume_request(
                &mut state,
                &policy,
                @0xB,
                1,
            );

            i = i + 1;
        };

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        abort 92400
    }


    #[test]
    fun test_05_global_burst_boundary_allowed() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_critical(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let operators = vector[
            @0xB,
            @0xC,
            @0xD,
            @0xE,
            @0xF,
            @0x10
        ];

        let mut i = 0;

        while (i < 6) {
            cross_network_rate_limit::consume_request(
                &mut state,
                &policy,
                *vector::borrow(&operators, i),
                1,
            );

            i = i + 1;
        };

        assert!(
            cross_network_rate_limit::total_requests(
                &state,
            ) == 6,
            92501,
        );

        cross_network_rate_limit::
            destroy_rate_limit_state_for_testing(
                state,
            );

        cross_network_policy::
            destroy_policy_for_testing(
                policy,
            );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                policy_registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1209201)]
    fun test_06_global_rate_limit_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_critical(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let operators = vector[
            @0xB,
            @0xC,
            @0xD,
            @0xE,
            @0xF,
            @0x10,
            @0x11
        ];

        let mut i = 0;

        while (i < 6) {
            cross_network_rate_limit::consume_request(
                &mut state,
                &policy,
                *vector::borrow(&operators, i),
                1,
            );

            i = i + 1;
        };

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            *vector::borrow(&operators, 6),
            1,
        );

        abort 92600
    }

    #[test]
    fun test_07_window_rollover_resets_counts() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_medium(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        assert!(
            cross_network_rate_limit::total_requests(
                &state,
            ) == 2,
            92701,
        );

        let version_before =
            cross_network_rate_limit::rate_limit_version(
                &state,
            );

        cross_network_rate_limit::
            rollover_window_if_needed(
                &mut state,
                2,
            );

        assert!(
            cross_network_rate_limit::current_window_id(
                &state,
            ) == 2,
            92702,
        );

        assert!(
            cross_network_rate_limit::total_requests(
                &state,
            ) == 0,
            92703,
        );

        assert!(
            cross_network_rate_limit::operator_count(
                &state,
            ) == 0,
            92704,
        );

        assert!(
            cross_network_rate_limit::rate_limit_version(
                &state,
            ) == version_before + 1,
            92705,
        );

        cross_network_rate_limit::
            destroy_rate_limit_state_for_testing(
                state,
            );

        cross_network_policy::
            destroy_policy_for_testing(
                policy,
            );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                policy_registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1209007)]
    fun test_08_disabled_policy_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_low(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_policy::disable_policy(
            &mut policy,
        );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            1,
        );

        abort 92800
    }

    #[test]
    fun test_09_critical_risk_has_tighter_quota() {
        assert!(
            cross_network_rate_limit::global_base_limit(
                cross_network_policy::risk_critical(),
            )
            <
            cross_network_rate_limit::global_base_limit(
                cross_network_policy::risk_low(),
            ),
            92901,
        );

        assert!(
            cross_network_rate_limit::operator_base_limit(
                cross_network_policy::risk_critical(),
            )
            <
            cross_network_rate_limit::operator_base_limit(
                cross_network_policy::risk_low(),
            ),
            92902,
        );

        assert!(
            cross_network_rate_limit::global_burst_allowance(
                cross_network_policy::risk_critical(),
            )
            <
            cross_network_rate_limit::global_burst_allowance(
                cross_network_policy::risk_low(),
            ),
            92903,
        );

        assert!(
            cross_network_rate_limit::operator_burst_allowance(
                cross_network_policy::risk_critical(),
            )
            <
            cross_network_rate_limit::operator_burst_allowance(
                cross_network_policy::risk_low(),
            ),
            92904,
        );
    }


    #[test]
    fun test_10_rollover_restores_request_quota() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut policy_registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut policy_registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_critical(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut state =
            cross_network_rate_limit::new_rate_limit_state(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut i = 0;

        while (i < 4) {
            cross_network_rate_limit::consume_request(
                &mut state,
                &policy,
                @0xB,
                1,
            );

            i = i + 1;
        };

        assert!(
            cross_network_rate_limit::operator_request_count(
                &state,
                @0xB,
            ) == 4,
            921001,
        );

        cross_network_rate_limit::consume_request(
            &mut state,
            &policy,
            @0xB,
            2,
        );

        assert!(
            cross_network_rate_limit::current_window_id(
                &state,
            ) == 2,
            921002,
        );

        assert!(
            cross_network_rate_limit::total_requests(
                &state,
            ) == 1,
            921003,
        );

        assert!(
            cross_network_rate_limit::operator_request_count(
                &state,
                @0xB,
            ) == 1,
            921004,
        );

        cross_network_rate_limit::
            destroy_rate_limit_state_for_testing(
                state,
            );

        cross_network_policy::
            destroy_policy_for_testing(
                policy,
            );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                policy_registry,
            );

        sui::test_scenario::end(scenario);
    }
}
