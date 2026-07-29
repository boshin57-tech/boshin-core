#[test_only]
module tobmate_enterprise_security::cross_network_recovery_control_tests {

    use tobmate_enterprise_security::cross_network_security;
    use tobmate_enterprise_security::cross_network_execution_receipt;
    use tobmate_enterprise_security::cross_network_recovery_control;

    #[test]
    fun test_01_open_recovery_case() {
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
                b"intent-7a-001",
                b"finality-7a-001",
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
                b"external-7a-001",
                b"confirmation-7a-001",
                b"proof-7a-001",
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"external-settlement-mismatch",
                1000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_recovery_control::case_status(&case)
                == cross_network_recovery_control::case_open_status(),
            7101,
        );

        assert!(
            cross_network_recovery_control::case_requested_amount(
                &case,
            ) == 1000,
            7102,
        );

        assert!(
            cross_network_recovery_control::recovery_total_cases(
                &recovery_registry,
            ) == 1,
            7103,
        );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                recovery_registry,
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
    fun test_02_begin_review() {
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
                b"intent-7a-002",
                b"finality-7a-002",
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
                b"external-7a-002",
                b"confirmation-7a-002",
                b"proof-7a-002",
                2,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"finality-dispute",
                2000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case,
            &receipt,
        );

        assert!(
            cross_network_recovery_control::case_status(&case)
                == cross_network_recovery_control::
                    case_under_review_status(),
            7201,
        );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                recovery_registry,
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
    fun test_03_approve_case() {
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
                b"intent-7a-003",
                b"finality-7a-003",
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
                b"external-7a-003",
                b"confirmation-7a-003",
                b"proof-7a-003",
                3,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"approved-recovery",
                3000,
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

        assert!(
            cross_network_recovery_control::case_status(&case)
                == cross_network_recovery_control::
                    case_approved_status(),
            7301,
        );

        assert!(
            cross_network_recovery_control::is_case_terminal(
                &case,
            ),
            7302,
        );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                recovery_registry,
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
    fun test_04_reject_case() {
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
                b"intent-7a-004",
                b"finality-7a-004",
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
                b"external-7a-004",
                b"confirmation-7a-004",
                b"proof-7a-004",
                4,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"rejected-recovery",
                4000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case,
            &receipt,
        );

        cross_network_recovery_control::reject_recovery_case(
            &mut case,
            &receipt,
        );

        assert!(
            cross_network_recovery_control::case_status(&case)
                == cross_network_recovery_control::
                    case_rejected_status(),
            7401,
        );

        assert!(
            cross_network_recovery_control::is_case_terminal(
                &case,
            ),
            7402,
        );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                recovery_registry,
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
    fun test_05_cancel_case() {
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
                b"intent-7a-005",
                b"finality-7a-005",
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
                b"external-7a-005",
                b"confirmation-7a-005",
                b"proof-7a-005",
                5,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"cancel-before-review",
                5000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::cancel_recovery_case(
            &mut case,
            &receipt,
        );

        assert!(
            cross_network_recovery_control::case_status(&case)
                == cross_network_recovery_control::
                    case_cancelled_status(),
            7501,
        );

        assert!(
            cross_network_recovery_control::is_case_terminal(
                &case,
            ),
            7502,
        );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                recovery_registry,
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
    #[expected_failure(abort_code = 1207006)]
    fun test_06_wrong_receipt_binding_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let binding_a =
            cross_network_security::new_binding(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let binding_b =
            cross_network_security::new_binding(
                b"network-a",
                b"domain-a",
                b"network-c",
                b"domain-c",
            );

        let intent_a =
            cross_network_security::new_intent_finality_binding(
                &binding_a,
                b"intent-7a-006-a",
                b"finality-7a-006-a",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding_b,
                b"intent-7a-006-b",
                b"finality-7a-006-b",
            );

        let mut record_a =
            cross_network_security::new_terminal_finality_record(
                &binding_a,
                &intent_a,
            );

        let mut record_b =
            cross_network_security::new_terminal_finality_record(
                &binding_b,
                &intent_b,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record_a,
            &binding_a,
            &intent_a,
        );

        cross_network_security::mark_finality_confirmed(
            &mut record_b,
            &binding_b,
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
                &binding_a,
                &intent_a,
                b"external-7a-006-a",
                b"confirmation-7a-006-a",
                b"proof-7a-006-a",
                6,
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt_b =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay_registry,
                &mut record_b,
                &binding_b,
                &intent_b,
                b"external-7a-006-b",
                b"confirmation-7a-006-b",
                b"proof-7a-006-b",
                7,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt_a,
                b"wrong-receipt-test",
                6000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case,
            &receipt_b,
        );

        abort 7600
    }


    #[test]
    #[expected_failure(abort_code = 1207004)]
    fun test_07_approve_without_review_rejected() {
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
                b"intent-7a-007",
                b"finality-7a-007",
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
                b"external-7a-007",
                b"confirmation-7a-007",
                b"proof-7a-007",
                7,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"approve-without-review",
                7000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::approve_recovery_case(
            &mut case,
            &receipt,
        );

        abort 7700
    }

    #[test]
    #[expected_failure(abort_code = 1207005)]
    fun test_08_terminal_case_reprocess_rejected() {
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
                b"intent-7a-008",
                b"finality-7a-008",
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
                b"external-7a-008",
                b"confirmation-7a-008",
                b"proof-7a-008",
                8,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"terminal-reprocess",
                8000,
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

        cross_network_recovery_control::reject_recovery_case(
            &mut case,
            &receipt,
        );

        abort 7800
    }


    #[test]
    #[expected_failure(abort_code = 1207003)]
    fun test_09_cancel_after_review_rejected() {
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
                b"intent-7a-009",
                b"finality-7a-009",
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
                b"external-7a-009",
                b"confirmation-7a-009",
                b"proof-7a-009",
                9,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"cancel-after-review",
                9000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case,
            &receipt,
        );

        cross_network_recovery_control::cancel_recovery_case(
            &mut case,
            &receipt,
        );

        abort 7900
    }


    #[test]
    #[expected_failure(abort_code = 1207004)]
    fun test_10_reject_without_review_rejected() {
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
                b"intent-7a-010",
                b"finality-7a-010",
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
                b"external-7a-010",
                b"confirmation-7a-010",
                b"proof-7a-010",
                10,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut recovery_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut recovery_registry,
                &receipt,
                b"reject-without-review",
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::reject_recovery_case(
            &mut case,
            &receipt,
        );

        abort 71000
    }
}
