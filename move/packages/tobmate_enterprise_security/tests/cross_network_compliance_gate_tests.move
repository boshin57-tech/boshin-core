#[test_only]
module tobmate_enterprise_security::cross_network_compliance_gate_tests {

    use tobmate_enterprise_security::cross_network_operator_trust;
    use tobmate_enterprise_security::cross_network_compliance_binding;
    use tobmate_enterprise_security::cross_network_compliance_gate;


    #[test]
    fun test_01_execution_compliant_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::trust_trusted(),
                b"a1",
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

        let mut gate =
            cross_network_compliance_gate::
                new_compliance_gate_policy(
                    cross_network_operator_trust::
                        trust_verified(),
                    cross_network_compliance_binding::
                        profile_basic(),
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_gate::
            assert_execution_compliant(
                &mut gate,
                &trust,
                &binding,
                &b"network-a",
                &b"domain-a",
                10,
            );

        assert!(
            cross_network_compliance_gate::
                total_allowed(&gate) == 1,
            103001,
        );

        cross_network_compliance_gate::
            destroy_compliance_gate_for_testing(gate);

        cross_network_compliance_binding::
            destroy_compliance_binding_for_testing(binding);

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(trust);

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1210201)]
    fun test_02_disabled_gate_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::trust_trusted(),
                b"a2",
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

        let mut gate =
            cross_network_compliance_gate::
                new_compliance_gate_policy(
                    cross_network_operator_trust::
                        trust_verified(),
                    cross_network_compliance_binding::
                        profile_basic(),
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_gate::
            disable_gate(&mut gate);

        cross_network_compliance_gate::
            assert_execution_compliant(
                &mut gate,
                &trust,
                &binding,
                &b"network-a",
                &b"domain-a",
                10,
            );

        abort 103100
    }


    #[test]
    #[expected_failure(abort_code = 1210109)]
    fun test_03_stale_attestation_binding_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut trust =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::trust_trusted(),
                b"old",
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
                b"new",
                30,
                10,
            );

        let mut gate =
            cross_network_compliance_gate::
                new_compliance_gate_policy(
                    cross_network_operator_trust::
                        trust_verified(),
                    cross_network_compliance_binding::
                        profile_basic(),
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_gate::
            assert_execution_compliant(
                &mut gate,
                &trust,
                &binding,
                &b"network-a",
                &b"domain-a",
                10,
            );

        abort 103200
    }


    #[test]
    fun test_04_institutional_gate_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_operator_trust::
                new_operator_trust_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let trust =
            cross_network_operator_trust::register_operator(
                &mut registry,
                @0xB,
                cross_network_operator_trust::
                    trust_institutional(),
                b"inst",
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
                        profile_institutional(),
                    1,
                    30,
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut gate =
            cross_network_compliance_gate::
                new_compliance_gate_policy(
                    cross_network_operator_trust::
                        trust_institutional(),
                    cross_network_compliance_binding::
                        profile_institutional(),
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_compliance_gate::
            assert_execution_compliant(
                &mut gate,
                &trust,
                &binding,
                &b"network-a",
                &b"domain-a",
                30,
            );

        assert!(
            cross_network_compliance_gate::
                total_checks(&gate) == 1,
            103301,
        );

        assert!(
            cross_network_compliance_gate::
                total_allowed(&gate) == 1,
            103302,
        );

        cross_network_compliance_gate::
            destroy_compliance_gate_for_testing(gate);

        cross_network_compliance_binding::
            destroy_compliance_binding_for_testing(binding);

        cross_network_operator_trust::
            destroy_operator_trust_for_testing(trust);

        cross_network_operator_trust::
            destroy_operator_trust_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }
}
