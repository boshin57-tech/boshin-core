#[test_only]
module tobmate_core::cross_network_recovery_authorization_tests {

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_receipt;
    use tobmate_core::cross_network_recovery_control;
    use tobmate_core::cross_network_recovery_authorization;


    #[test]
    fun test_01_approved_case_issues_authorization() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1207101)]
    fun test_02_non_approved_case_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-002",
                b"finality-7b-002",
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
                b"external-7b-002",
                b"confirmation-7b-002",
                b"proof-7b-002",
                2,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let case =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt,
                b"not-approved",
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let _authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                5000,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 72000
    }


    #[test]
    #[expected_failure(abort_code = 1207103)]
    fun test_03_amount_exceeds_case_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-003",
                b"finality-7b-003",
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
                b"external-7b-003",
                b"confirmation-7b-003",
                b"proof-7b-003",
                3,
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
                b"amount-limit",
                5000,
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

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let _authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                5001,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 73000
    }

    #[test]
    #[expected_failure(abort_code = 1207102)]
    fun test_04_zero_amount_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-004",
                b"finality-7b-004",
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
                b"external-7b-004",
                b"confirmation-7b-004",
                b"proof-7b-004",
                4,
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
                b"zero-amount",
                4000,
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

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let _authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                0,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 74000
    }


    #[test]
    fun test_05_consume_authorization_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-005",
                b"finality-7b-005",
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
                b"external-7b-005",
                b"confirmation-7b-005",
                b"proof-7b-005",
                5,
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
                b"consume-success",
                5000,
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

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                5000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        assert!(
            cross_network_recovery_authorization::
                is_authorization_consumed(
                    &authorization,
                ),
            75001,
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

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1207104)]
    fun test_06_double_consume_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-006",
                b"finality-7b-006",
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
                b"external-7b-006",
                b"confirmation-7b-006",
                b"proof-7b-006",
                6,
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
                b"double-consume",
                6000,
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

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                6000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        abort 76000
    }

    #[test]
    #[expected_failure(abort_code = 1207105)]
    fun test_07_wrong_case_binding_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let binding =
            cross_network_security::new_binding(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let intent_a =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-7b-007-a",
                b"finality-7b-007-a",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-7b-007-b",
                b"finality-7b-007-b",
            );

        let mut record_a =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_a,
            );

        let mut record_b =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_b,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record_a,
            &binding,
            &intent_a,
        );

        cross_network_security::mark_finality_confirmed(
            &mut record_b,
            &binding,
            &intent_b,
        );

        let mut replay_registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt_a =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay_registry,
                &mut record_a,
                &binding,
                &intent_a,
                b"external-7b-007-a",
                b"confirmation-7b-007-a",
                b"proof-7b-007-a",
                7,
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt_b =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay_registry,
                &mut record_b,
                &binding,
                &intent_b,
                b"external-7b-007-b",
                b"confirmation-7b-007-b",
                b"proof-7b-007-b",
                8,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_a =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt_a,
                b"case-a",
                7000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_b =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt_b,
                b"case-b",
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case_a,
            &receipt_a,
        );

        cross_network_recovery_control::approve_recovery_case(
            &mut case_a,
            &receipt_a,
        );

        cross_network_recovery_control::begin_case_review(
            &mut case_b,
            &receipt_b,
        );

        cross_network_recovery_control::approve_recovery_case(
            &mut case_b,
            &receipt_b,
        );

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case_a,
                7000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case_b,
        );

        abort 77000
    }


    #[test]
    fun test_08_authorization_id_deterministic() {
        let id_a =
            cross_network_recovery_authorization::
                calculate_authorization_id(
                    b"case-id-008",
                    8000,
                    8,
                    100,
                );

        let id_b =
            cross_network_recovery_authorization::
                calculate_authorization_id(
                    b"case-id-008",
                    8000,
                    8,
                    100,
                );

        assert!(id_a == id_b, 78001);
    }

    #[test]
    fun test_09_registry_count() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-009",
                b"finality-7b-009",
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
                b"external-7b-009",
                b"confirmation-7b-009",
                b"proof-7b-009",
                9,
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
                b"registry-count",
                9000,
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

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                9000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_recovery_authorization::
                total_authorizations(
                    &auth_registry,
                ) == 1,
            79001,
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

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_10_full_amount_authorization_allowed() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

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
                b"intent-7b-010",
                b"finality-7b-010",
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
                b"external-7b-010",
                b"confirmation-7b-010",
                b"proof-7b-010",
                10,
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
                b"full-amount",
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

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_recovery_authorization::
                authorized_amount(
                    &authorization,
                ) == 10000,
            710001,
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

        sui::test_scenario::end(scenario);
    }
}
