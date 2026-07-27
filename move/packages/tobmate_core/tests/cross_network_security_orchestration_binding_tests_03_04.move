#[test_only]
module tobmate_core::cross_network_security_orchestration_binding_tests_03_04 {

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_receipt;
    use tobmate_core::cross_network_recovery_control;
    use tobmate_core::cross_network_recovery_authorization;
    use tobmate_core::cross_network_remediation;

    use tobmate_core::cross_network_security_orchestrator;
    use tobmate_core::cross_network_security_orchestration_binding;

    #[test]
    fun test_03_remediation_record_binding() {
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

        let mut authorization =
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
                authorization_status(&authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_pending_status(),
            73019,
        );

        cross_network_recovery_authorization::
            consume_authorization(
                &mut authorization,
                &case,
            );

        assert!(
            cross_network_recovery_authorization::
                authorization_status(&authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_consumed_status(),
            73020,
        );

        cross_network_security_orchestration_binding::
            confirm_consumed_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );

        assert!(
            cross_network_security_orchestrator::
                authorization_complete(&orchestration),
            73021,
        );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_authorized(),
            73021,
        );

        assert!(
            cross_network_recovery_authorization::
                authorized_amount(&authorization) == 8000,
            71001,
        );


        let mut remediation_registry =
            cross_network_remediation::
                new_remediation_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let remediation =
            cross_network_remediation::
                create_remediation_record(
                    &mut remediation_registry,
                    &authorization,
                    &case,
                    b"security-remediation",
                    8000,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_orchestration_binding::
            bind_remediation_record(
                &mut orchestration,
                &case,
                &authorization,
                &remediation,
            );

        assert!(
            !cross_network_security_orchestrator::
                remediation_complete(&orchestration),
            73030,
        );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_remediating(),
            73031,
        );

        cross_network_remediation::
            destroy_remediation_record_for_testing(
                remediation,
            );

        cross_network_remediation::
            destroy_remediation_registry_for_testing(
                remediation_registry,
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
    fun test_04_full_triple_binding_verification() {
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

        let mut authorization =
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
                authorization_status(&authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_pending_status(),
            73019,
        );

        cross_network_recovery_authorization::
            consume_authorization(
                &mut authorization,
                &case,
            );

        assert!(
            cross_network_recovery_authorization::
                authorization_status(&authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_consumed_status(),
            73020,
        );

        cross_network_security_orchestration_binding::
            confirm_consumed_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );

        assert!(
            cross_network_security_orchestrator::
                authorization_complete(&orchestration),
            73021,
        );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_authorized(),
            73021,
        );

        assert!(
            cross_network_recovery_authorization::
                authorized_amount(&authorization) == 8000,
            71001,
        );


        let mut remediation_registry =
            cross_network_remediation::
                new_remediation_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let remediation =
            cross_network_remediation::
                create_remediation_record(
                    &mut remediation_registry,
                    &authorization,
                    &case,
                    b"security-remediation",
                    8000,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_orchestration_binding::
            bind_remediation_record(
                &mut orchestration,
                &case,
                &authorization,
                &remediation,
            );

        cross_network_security_orchestration_binding::
            assert_full_binding(
                &case,
                &authorization,
                &remediation,
            );

        assert!(
            cross_network_remediation::
                remediation_case_id(&remediation)
                ==
                cross_network_recovery_control::
                    case_id(&case),
            73040,
        );

        assert!(
            cross_network_remediation::
                remediation_authorization_id(&remediation)
                ==
                cross_network_recovery_authorization::
                    authorization_id(&authorization),
            73041,
        );

        assert!(
            !cross_network_security_orchestrator::
                remediation_complete(&orchestration),
            73042,
        );

        cross_network_remediation::
            destroy_remediation_record_for_testing(
                remediation,
            );

        cross_network_remediation::
            destroy_remediation_registry_for_testing(
                remediation_registry,
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
