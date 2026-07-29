#[test_only]
module tobmate_enterprise_security::cross_network_policy_tests {

    use tobmate_enterprise_security::cross_network_policy;


    #[test]
    fun test_01_create_policy_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_medium(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_policy::policy_enabled(&policy),
            9101,
        );

        assert!(
            cross_network_policy::policy_risk_tier(&policy)
                == cross_network_policy::risk_medium(),
            9102,
        );

        assert!(
            cross_network_policy::max_transaction_amount(&policy)
                == 10000,
            9103,
        );

        assert!(
            cross_network_policy::total_policies(&registry)
                == 1,
            9104,
        );

        cross_network_policy::destroy_policy_for_testing(
            policy,
        );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_02_amount_within_limit_allowed() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_low(),
                5000,
                50000,
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_policy::assert_policy_allows_amount(
            &policy,
            5000,
        );

        cross_network_policy::destroy_policy_for_testing(
            policy,
        );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1209008)]
    fun test_03_amount_over_limit_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_high(),
                5000,
                50000,
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_policy::assert_policy_allows_amount(
            &policy,
            5001,
        );

        abort 9300
    }

    #[test]
    #[expected_failure(abort_code = 1209007)]
    fun test_04_disabled_policy_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_medium(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_policy::disable_policy(
            &mut policy,
        );

        cross_network_policy::assert_policy_allows_amount(
            &policy,
            1000,
        );

        abort 9400
    }


    #[test]
    #[expected_failure(abort_code = 1209003)]
    fun test_05_invalid_risk_tier_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                9,
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 9500
    }


    #[test]
    #[expected_failure(abort_code = 1209004)]
    fun test_06_zero_transaction_limit_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_low(),
                0,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 9600
    }

    #[test]
    fun test_07_risk_tier_update() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_low(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let version_before =
            cross_network_policy::policy_version(
                &policy,
            );

        cross_network_policy::set_risk_tier(
            &mut policy,
            cross_network_policy::risk_critical(),
        );

        assert!(
            cross_network_policy::policy_risk_tier(&policy)
                == cross_network_policy::risk_critical(),
            9701,
        );

        assert!(
            cross_network_policy::policy_version(&policy)
                == version_before + 1,
            9702,
        );

        cross_network_policy::destroy_policy_for_testing(
            policy,
        );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_08_limit_update_and_version_increment() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_medium(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let version_before =
            cross_network_policy::policy_version(
                &policy,
            );

        cross_network_policy::set_limits(
            &mut policy,
            20000,
            200000,
            50000,
        );

        assert!(
            cross_network_policy::max_transaction_amount(
                &policy,
            ) == 20000,
            9801,
        );

        assert!(
            cross_network_policy::epoch_volume_limit(
                &policy,
            ) == 200000,
            9802,
        );

        assert!(
            cross_network_policy::operator_epoch_limit(
                &policy,
            ) == 50000,
            9803,
        );

        assert!(
            cross_network_policy::policy_version(&policy)
                == version_before + 1,
            9804,
        );

        cross_network_policy::destroy_policy_for_testing(
            policy,
        );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }

    #[test]
    fun test_09_enable_disable_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_policy::new_policy_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut policy =
            cross_network_policy::create_policy(
                &mut registry,
                b"network-a",
                b"domain-a",
                cross_network_policy::risk_medium(),
                10000,
                100000,
                25000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_policy::disable_policy(
            &mut policy,
        );

        assert!(
            !cross_network_policy::policy_enabled(
                &policy,
            ),
            9901,
        );

        cross_network_policy::enable_policy(
            &mut policy,
        );

        assert!(
            cross_network_policy::policy_enabled(
                &policy,
            ),
            9902,
        );

        cross_network_policy::assert_policy_allows_amount(
            &policy,
            10000,
        );

        cross_network_policy::destroy_policy_for_testing(
            policy,
        );

        cross_network_policy::
            destroy_policy_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_10_policy_id_deterministic() {
        let id_a =
            cross_network_policy::calculate_policy_id(
                b"network-a",
                b"domain-a",
                1,
            );

        let id_b =
            cross_network_policy::calculate_policy_id(
                b"network-a",
                b"domain-a",
                1,
            );

        assert!(id_a == id_b, 91001);

        let id_c =
            cross_network_policy::calculate_policy_id(
                b"network-b",
                b"domain-a",
                1,
            );

        assert!(id_a != id_c, 91002);
    }
}
