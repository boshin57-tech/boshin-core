#[test_only]
module tobmate_core::cross_network_operator_trust_tests {

    use tobmate_core::cross_network_operator_trust;


    #[test]
    fun test_01_register_operator_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_verified(),
                b"attestation-001",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_operator_trust::
                operator_address(&record) == @0xB,
            10101,
        );

        assert!(
            cross_network_operator_trust::
                operator_active(&record),
            10102,
        );

        assert!(
            cross_network_operator_trust::
                total_operator_records(&registry) == 1,
            10103,
        );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                record,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_02_operator_eligible_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-002",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_verified(),
                5,
            );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                record,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1210005)]
    fun test_03_expired_attestation_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-003",
                5,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_verified(),
                6,
            );

        abort 10300
    }

    #[test]
    #[expected_failure(abort_code = 1210006)]
    fun test_04_insufficient_trust_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_verified(),
                b"attestation-004",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_trusted(),
                5,
            );

        abort 10400
    }


    #[test]
    fun test_05_suspend_restore_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-005",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let version_before =
            cross_network_operator_trust::
                operator_trust_version(
                    &record,
                );

        cross_network_operator_trust::
            suspend_operator(
                &mut record,
                b"compliance-review",
            );

        assert!(
            !cross_network_operator_trust::
                operator_active(&record),
            10501,
        );

        assert!(
            cross_network_operator_trust::
                operator_suspension_reason(&record)
                == &b"compliance-review",
            10502,
        );

        cross_network_operator_trust::
            restore_operator(
                &mut record,
            );

        assert!(
            cross_network_operator_trust::
                operator_active(&record),
            10503,
        );

        assert!(
            vector::length(
                cross_network_operator_trust::
                    operator_suspension_reason(&record),
            ) == 0,
            10504,
        );

        assert!(
            cross_network_operator_trust::
                operator_trust_version(&record)
                == version_before + 2,
            10505,
        );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                record,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1210004)]
    fun test_06_suspended_operator_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_institutional(),
                b"attestation-006",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_operator_trust::
            suspend_operator(
                &mut record,
                b"security-incident",
            );

        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_verified(),
                5,
            );

        abort 10600
    }

    #[test]
    fun test_07_trust_level_upgrade_and_version() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_verified(),
                b"attestation-007",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let version_before =
            cross_network_operator_trust::
                operator_trust_version(
                    &record,
                );

        cross_network_operator_trust::
            set_trust_level(
                &mut record,
                cross_network_operator_trust::
                    trust_institutional(),
            );

        assert!(
            cross_network_operator_trust::
                operator_trust_level(&record)
                == cross_network_operator_trust::
                    trust_institutional(),
            10701,
        );

        assert!(
            cross_network_operator_trust::
                operator_trust_version(&record)
                == version_before + 1,
            10702,
        );

        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_institutional(),
                5,
            );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                record,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_08_attestation_refresh() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-old",
                5,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let version_before =
            cross_network_operator_trust::
                operator_trust_version(
                    &record,
                );

        cross_network_operator_trust::
            refresh_attestation(
                &mut record,
                b"attestation-new",
                20,
                5,
            );

        assert!(
            cross_network_operator_trust::
                operator_attestation_hash(&record)
                == &b"attestation-new",
            10801,
        );

        assert!(
            cross_network_operator_trust::
                operator_attestation_expiry(&record)
                == 20,
            10802,
        );

        assert!(
            cross_network_operator_trust::
                operator_trust_version(&record)
                == version_before + 1,
            10803,
        );

        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_trusted(),
                20,
            );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                record,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1210003)]
    fun test_09_invalid_attestation_refresh_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-009",
                10,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        // current_epoch = 10
        // requested expiry = 9
        // Must be rejected as already expired.
        cross_network_operator_trust::
            refresh_attestation(
                &mut record,
                b"attestation-invalid",
                9,
                10,
            );

        abort 10900
    }


    #[test]
    fun test_10_institutional_trust_boundary_allowed() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let record =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_institutional(),
                b"attestation-010",
                20,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        // Exact minimum trust boundary must be allowed.
        cross_network_operator_trust::
            assert_operator_eligible(
                &record,
                cross_network_operator_trust::
                    trust_institutional(),
                20,
            );

        assert!(
            cross_network_operator_trust::
                operator_trust_level(&record)
                == cross_network_operator_trust::
                    trust_institutional(),
            11001,
        );

        assert!(
            cross_network_operator_trust::
                operator_attestation_expiry(&record)
                == 20,
            11002,
        );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                record,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }
}
