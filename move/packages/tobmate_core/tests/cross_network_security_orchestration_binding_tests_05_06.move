#[test_only]
module tobmate_core::cross_network_security_orchestration_binding_tests_05_06 {

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_receipt;
    use tobmate_core::cross_network_recovery_control;
    use tobmate_core::cross_network_recovery_authorization;
    use tobmate_core::cross_network_remediation;

    use tobmate_core::cross_network_security_orchestrator;
    use tobmate_core::cross_network_security_orchestration_binding;

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_05_non_approved_recovery_case_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_orchestrator::
            set_open_state_for_testing(
                &mut orchestration,
                1,
            );


        let binding =
            cross_network_security::new_binding(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-7b-001",
                b"finality-7b-001",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding,
            &intent_binding,
        );

        let mut replay_registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay_registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-7b-001",
                b"confirmation-7b-001",
                b"proof-7b-001",
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt,
                b"recovery-approved",
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );


        cross_network_security_orchestration_binding::
            bind_recovery_case(
                &mut orchestration,
                &case,
            );

        assert!(
            cross_network_recovery_control::
                case_status(&case)
                ==
                cross_network_recovery_control::
                    case_approved_status(),
            73050,
        );

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security_orchestration_binding::
            bind_pending_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );

        assert!(
            cross_network_recovery_authorization::
                authorized_amount(&authorization) == 8000,
            71001,
        );

        assert!(
            cross_network_recovery_authorization::
                authorization_status(&authorization)
                == cross_network_recovery_authorization::
                    authorization_pending_status(),
            71002,
        );

        cross_network_recovery_authorization::
            destroy_authorization_for_testing(
                authorization,
            );

        cross_network_recovery_authorization::
            destroy_authorization_registry_for_testing(
                auth_registry,
            );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                case_registry,
            );

        cross_network_execution_receipt::
            destroy_receipt_for_testing(receipt);

        cross_network_security::
            destroy_replay_registry_for_testing(
                replay_registry,
            );

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        sui::test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_06_unconsumed_authorization_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_orchestrator::
            set_open_state_for_testing(
                &mut orchestration,
                1,
            );


        let binding =
            cross_network_security::new_binding(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-7b-001",
                b"finality-7b-001",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding,
            &intent_binding,
        );

        let mut replay_registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay_registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-7b-001",
                b"confirmation-7b-001",
                b"proof-7b-001",
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt,
                b"recovery-approved",
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case,
            &receipt,
        );

        cross_network_recovery_control::approve_recovery_case(
            &mut case,
            &receipt,
        );


        cross_network_security_orchestration_binding::
            bind_recovery_case(
                &mut orchestration,
                &case,
            );

        assert!(
            cross_network_recovery_control::
                case_status(&case)
                ==
                cross_network_recovery_control::
                    case_approved_status(),
            73001,
        );

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security_orchestration_binding::
            bind_pending_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );


        // Must abort: authorization is still PENDING.
        cross_network_security_orchestration_binding::
            confirm_consumed_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );

        assert!(
            cross_network_recovery_authorization::
                authorized_amount(&authorization) == 8000,
            71001,
        );

        assert!(
            cross_network_recovery_authorization::
                authorization_status(&authorization)
                == cross_network_recovery_authorization::
                    authorization_pending_status(),
            71002,
        );

        cross_network_recovery_authorization::
            destroy_authorization_for_testing(
                authorization,
            );

        cross_network_recovery_authorization::
            destroy_authorization_registry_for_testing(
                auth_registry,
            );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                case_registry,
            );

        cross_network_execution_receipt::
            destroy_receipt_for_testing(receipt);

        cross_network_security::
            destroy_replay_registry_for_testing(
                replay_registry,
            );

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        sui::test_scenario::end(scenario);
    }
}
