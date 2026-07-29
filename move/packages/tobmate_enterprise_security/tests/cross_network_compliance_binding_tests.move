#[test_only]
module tobmate_enterprise_security::cross_network_compliance_binding_tests {

    use tobmate_enterprise_security::cross_network_operator_trust;
    use tobmate_enterprise_security::cross_network_compliance_binding;


    #[test]
    fun test_01_create_binding_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-10b-001",
                20,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        assert!(
            cross_network_compliance_binding::
                binding_operator(&binding) == @0xB,
            101101,
        );

        assert!(
            cross_network_compliance_binding::
                binding_profile(&binding)
                == cross_network_compliance_binding::
                    profile_regulated(),
            101102,
        );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_basic(),
                10,
            );

        cross_network_compliance_binding::
            destroy_compliance_binding_for_testing(
                binding,
            );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                trust,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                trust_registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_02_binding_hash_deterministic() {
        let hash_a =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-a",
                    b"domain-a",
                    b"attestation-10b-002",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        let hash_b =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-a",
                    b"domain-a",
                    b"attestation-10b-002",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        assert!(hash_a == hash_b, 101201);
    }


    #[test]
    #[expected_failure(abort_code = 1210107)]
    fun test_03_wrong_network_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-10b-003",
                20,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-b",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_basic(),
                10,
            );

        abort 101300
    }

    #[test]
    #[expected_failure(abort_code = 1210108)]
    fun test_04_wrong_domain_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-10b-004",
                20,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-b",
                cross_network_compliance_binding::
                    profile_basic(),
                10,
            );

        abort 101400
    }


    #[test]
    #[expected_failure(abort_code = 1210109)]
    fun test_05_attestation_refresh_mismatch_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-old-10b-005",
                20,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_operator_trust::
            refresh_attestation(
                &mut trust,
                b"attestation-new-10b-005",
                30,
                10,
            );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_basic(),
                10,
            );

        abort 101500
    }


    #[test]
    #[expected_failure(abort_code = 1210110)]
    fun test_06_not_yet_valid_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-10b-006",
                30,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    10,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_basic(),
                9,
            );

        abort 101600
    }

    #[test]
    #[expected_failure(abort_code = 1210111)]
    fun test_07_expired_binding_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_trusted(),
                b"attestation-10b-007",
                30,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_basic(),
                11,
            );

        abort 101700
    }


    #[test]
    #[expected_failure(abort_code = 1210112)]
    fun test_08_profile_too_low_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_institutional(),
                b"attestation-10b-008",
                30,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_basic(),
                    1,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_institutional(),
                10,
            );

        abort 101800
    }

    #[test]
    fun test_09_exact_validity_boundary_allowed() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut trust_registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut trust_registry,
                @0xB,
                cross_network_operator_trust::
                    trust_institutional(),
                b"attestation-10b-009",
                20,
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let binding =
            cross_network_compliance_binding::
                create_compliance_binding(
                    &trust,
                    b"network-a",
                    b"domain-a",
                    cross_network_compliance_binding::
                        profile_institutional(),
                    10,
                    20,
                    sui::test_scenario::ctx(&mut scenario),
                );

        // valid_from exact boundary
        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_institutional(),
                10,
            );

        // valid_until exact boundary
        cross_network_compliance_binding::
            assert_compliance_valid(
                &binding,
                &trust,
                &b"network-a",
                &b"domain-a",
                cross_network_compliance_binding::
                    profile_institutional(),
                20,
            );

        cross_network_compliance_binding::
            destroy_compliance_binding_for_testing(
                binding,
            );

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(
                trust,
            );

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                trust_registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_10_binding_hash_context_sensitive() {
        let base =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-a",
                    b"domain-a",
                    b"attestation-10b-010",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        let wrong_operator =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xC,
                    b"network-a",
                    b"domain-a",
                    b"attestation-10b-010",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        let wrong_network =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-b",
                    b"domain-a",
                    b"attestation-10b-010",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        let wrong_domain =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-a",
                    b"domain-b",
                    b"attestation-10b-010",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        let wrong_attestation =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-a",
                    b"domain-a",
                    b"attestation-other",
                    cross_network_compliance_binding::
                        profile_regulated(),
                    1,
                    20,
                );

        let wrong_profile =
            cross_network_compliance_binding::
                calculate_binding_hash(
                    @0xB,
                    b"network-a",
                    b"domain-a",
                    b"attestation-10b-010",
                    cross_network_compliance_binding::
                        profile_institutional(),
                    1,
                    20,
                );

        assert!(base != wrong_operator, 101001);
        assert!(base != wrong_network, 101002);
        assert!(base != wrong_domain, 101003);
        assert!(base != wrong_attestation, 101004);
        assert!(base != wrong_profile, 101005);
    }
}
