#[test_only]
module tobmate_core::cross_network_risk_limit_tests {

    use tobmate_core::cross_network_policy;
    use tobmate_core::cross_network_risk_limit;


    #[test]
    fun test_01_record_usage_success() {
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
                50000,
                20000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            5000,
            1,
        );

        assert!(
            cross_network_risk_limit::epoch_total_volume(
                &usage,
            ) == 5000,
            91101,
        );

        assert!(
            cross_network_risk_limit::epoch_transaction_count(
                &usage,
            ) == 1,
            91102,
        );

        assert!(
            cross_network_risk_limit::operator_volume(
                &usage,
                @0xB,
            ) == 5000,
            91103,
        );

        cross_network_risk_limit::
            destroy_risk_limit_usage_for_testing(
                usage,
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
    #[expected_failure(abort_code = 1209101)]
    fun test_02_epoch_volume_limit_rejected() {
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
                15000,
                15000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            10000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xC,
            6000,
            1,
        );

        abort 91200
    }


    #[test]
    #[expected_failure(abort_code = 1209102)]
    fun test_03_operator_epoch_limit_rejected() {
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
                50000,
                12000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            7000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            6000,
            1,
        );

        abort 91300
    }

    #[test]
    #[expected_failure(abort_code = 1209104)]
    fun test_04_zero_amount_rejected() {
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
                50000,
                20000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            0,
            1,
        );

        abort 91400
    }


    #[test]
    fun test_05_epoch_rollover_resets_usage() {
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
                50000,
                20000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            5000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xC,
            3000,
            1,
        );

        assert!(
            cross_network_risk_limit::epoch_total_volume(
                &usage,
            ) == 8000,
            91501,
        );

        let version_before =
            cross_network_risk_limit::usage_version(
                &usage,
            );

        cross_network_risk_limit::rollover_if_needed(
            &mut usage,
            2,
        );

        assert!(
            cross_network_risk_limit::usage_epoch(
                &usage,
            ) == 2,
            91502,
        );

        assert!(
            cross_network_risk_limit::epoch_total_volume(
                &usage,
            ) == 0,
            91503,
        );

        assert!(
            cross_network_risk_limit::epoch_transaction_count(
                &usage,
            ) == 0,
            91504,
        );

        assert!(
            cross_network_risk_limit::operator_count(
                &usage,
            ) == 0,
            91505,
        );

        assert!(
            cross_network_risk_limit::usage_version(
                &usage,
            ) == version_before + 1,
            91506,
        );

        cross_network_risk_limit::
            destroy_risk_limit_usage_for_testing(
                usage,
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
    fun test_06_multi_operator_accounting() {
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
                50000,
                20000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            5000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xC,
            7000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            3000,
            1,
        );

        assert!(
            cross_network_risk_limit::operator_count(
                &usage,
            ) == 2,
            91601,
        );

        assert!(
            cross_network_risk_limit::operator_volume(
                &usage,
                @0xB,
            ) == 8000,
            91602,
        );

        assert!(
            cross_network_risk_limit::operator_volume(
                &usage,
                @0xC,
            ) == 7000,
            91603,
        );

        assert!(
            cross_network_risk_limit::operator_transaction_count(
                &usage,
                @0xB,
            ) == 2,
            91604,
        );

        assert!(
            cross_network_risk_limit::epoch_total_volume(
                &usage,
            ) == 15000,
            91605,
        );

        cross_network_risk_limit::
            destroy_risk_limit_usage_for_testing(
                usage,
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
    #[expected_failure(abort_code = 1209103)]
    fun test_07_critical_risk_tx_count_limit_rejected() {
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
                1000,
                20000,
                20000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut i = 0;

        while (i < 10) {
            cross_network_risk_limit::record_usage(
                &mut usage,
                &policy,
                @0xB,
                100,
                1,
            );

            i = i + 1;
        };

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            100,
            1,
        );

        abort 91700
    }


    #[test]
    fun test_08_operator_limit_boundary_allowed() {
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
                50000,
                12000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            7000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            5000,
            1,
        );

        assert!(
            cross_network_risk_limit::operator_volume(
                &usage,
                @0xB,
            ) == 12000,
            91801,
        );

        assert!(
            cross_network_risk_limit::operator_transaction_count(
                &usage,
                @0xB,
            ) == 2,
            91802,
        );

        cross_network_risk_limit::
            destroy_risk_limit_usage_for_testing(
                usage,
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
    fun test_09_epoch_volume_boundary_allowed() {
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
                15000,
                15000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            10000,
            1,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xC,
            5000,
            1,
        );

        assert!(
            cross_network_risk_limit::epoch_total_volume(
                &usage,
            ) == 15000,
            91901,
        );

        assert!(
            cross_network_risk_limit::epoch_transaction_count(
                &usage,
            ) == 2,
            91902,
        );

        cross_network_risk_limit::
            destroy_risk_limit_usage_for_testing(
                usage,
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
    fun test_10_rollover_restores_quota() {
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
                12000,
                12000,
                12000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut usage =
            cross_network_risk_limit::new_risk_limit_usage(
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            12000,
            1,
        );

        assert!(
            cross_network_risk_limit::operator_volume(
                &usage,
                @0xB,
            ) == 12000,
            911001,
        );

        cross_network_risk_limit::record_usage(
            &mut usage,
            &policy,
            @0xB,
            12000,
            2,
        );

        assert!(
            cross_network_risk_limit::usage_epoch(
                &usage,
            ) == 2,
            911002,
        );

        assert!(
            cross_network_risk_limit::epoch_total_volume(
                &usage,
            ) == 12000,
            911003,
        );

        assert!(
            cross_network_risk_limit::operator_volume(
                &usage,
                @0xB,
            ) == 12000,
            911004,
        );

        assert!(
            cross_network_risk_limit::operator_transaction_count(
                &usage,
                @0xB,
            ) == 1,
            911005,
        );

        cross_network_risk_limit::
            destroy_risk_limit_usage_for_testing(
                usage,
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
