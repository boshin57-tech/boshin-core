#[test_only]
module tobmate_core::cross_network_remediation_tests {

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_receipt;
    use tobmate_core::cross_network_recovery_control;
    use tobmate_core::cross_network_recovery_authorization;
    use tobmate_core::cross_network_remediation;


    #[test]
    fun test_01_create_remediation_record() {
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
                b"intent-7c-001",
                b"finality-7c-001",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-001",
                b"confirmation-7c-001",
                b"proof-7c-001",
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
                b"compensation",
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

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"compensation-payment",
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_remediation::remediation_amount(
                &remediation,
            ) == 8000,
            72001,
        );

        cross_network_remediation::assert_remediation_binding(
            &remediation,
            &authorization,
            &case,
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
            destroy_replay_registry_for_testing(replay);

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1207201)]
    fun test_02_unconsumed_authorization_rejected() {
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
                b"intent-7c-002",
                b"finality-7c-002",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-002",
                b"confirmation-7c-002",
                b"proof-7c-002",
                2,
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
                b"unconsumed-auth",
                2000,
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
                2000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"should-fail",
                2000,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 72002
    }


    #[test]
    #[expected_failure(abort_code = 1207203)]
    fun test_03_amount_exceeds_authorization_rejected() {
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
                b"intent-7c-003",
                b"finality-7c-003",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-003",
                b"confirmation-7c-003",
                b"proof-7c-003",
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
                b"amount-exceeds",
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
                3000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"over-limit",
                3001,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 72003
    }

    #[test]
    #[expected_failure(abort_code = 1207202)]
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
                b"intent-7c-004",
                b"finality-7c-004",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-004",
                b"confirmation-7c-004",
                b"proof-7c-004",
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
                b"zero-remediation",
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

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                4000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"zero-amount",
                0,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 72004
    }


    #[test]
    #[expected_failure(abort_code = 1207205)]
    fun test_05_empty_type_rejected() {
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
                b"intent-7c-005",
                b"finality-7c-005",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-005",
                b"confirmation-7c-005",
                b"proof-7c-005",
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
                b"empty-type",
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

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"",
                5000,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 72005
    }


    #[test]
    fun test_06_binding_validation_success() {
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
                b"intent-7c-006",
                b"finality-7c-006",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-006",
                b"confirmation-7c-006",
                b"proof-7c-006",
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
                b"binding-check",
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

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"binding-check",
                6000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_remediation::assert_remediation_binding(
            &remediation,
            &authorization,
            &case,
        );

        cross_network_remediation::
            destroy_remediation_record_for_testing(remediation);

        cross_network_remediation::
            destroy_remediation_registry_for_testing(
                remediation_registry,
            );

        cross_network_recovery_authorization::
            destroy_authorization_for_testing(authorization);

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
            destroy_replay_registry_for_testing(replay);

        sui::test_scenario::end(scenario);
    }

    #[test]
    fun test_07_remediation_id_deterministic() {
        let id_a =
            cross_network_remediation::calculate_remediation_id(
                b"auth-007",
                b"case-007",
                b"compensation",
                7000,
                7,
                100,
            );

        let id_b =
            cross_network_remediation::calculate_remediation_id(
                b"auth-007",
                b"case-007",
                b"compensation",
                7000,
                7,
                100,
            );

        assert!(id_a == id_b, 72701);
    }


    #[test]
    fun test_08_registry_count() {
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
                b"intent-7c-008",
                b"finality-7c-008",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-008",
                b"confirmation-7c-008",
                b"proof-7c-008",
                8,
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

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"registry-count",
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_remediation::total_remediation_records(
                &remediation_registry,
            ) == 1,
            72801,
        );

        cross_network_remediation::
            destroy_remediation_record_for_testing(remediation);

        cross_network_remediation::
            destroy_remediation_registry_for_testing(
                remediation_registry,
            );

        cross_network_recovery_authorization::
            destroy_authorization_for_testing(authorization);

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
            destroy_replay_registry_for_testing(replay);

        sui::test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1207204)]
    fun test_09_wrong_case_binding_rejected() {
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
                b"intent-7c-009-a",
                b"finality-7c-009-a",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-7c-009-b",
                b"finality-7c-009-b",
            );

        let mut terminal_a =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_a,
            );

        let mut terminal_b =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_b,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal_a,
            &binding,
            &intent_a,
        );

        cross_network_security::mark_finality_confirmed(
            &mut terminal_b,
            &binding,
            &intent_b,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt_a =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal_a,
                &binding,
                &intent_a,
                b"external-7c-009-a",
                b"confirmation-7c-009-a",
                b"proof-7c-009-a",
                9,
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt_b =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal_b,
                &binding,
                &intent_b,
                b"external-7c-009-b",
                b"confirmation-7c-009-b",
                b"proof-7c-009-b",
                10,
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
                9000,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_b =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt_b,
                b"case-b",
                9000,
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
                9000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case_a,
        );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case_b,
                b"wrong-case",
                9000,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 72901
    }


    #[test]
    fun test_10_full_authorized_amount_allowed() {
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
                b"intent-7c-010",
                b"finality-7c-010",
            );

        let mut terminal =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut terminal,
            &binding,
            &intent_binding,
        );

        let mut replay =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay,
                &mut terminal,
                &binding,
                &intent_binding,
                b"external-7c-010",
                b"confirmation-7c-010",
                b"proof-7c-010",
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
                b"full-compensation",
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

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_authorization::consume_authorization(
            &mut authorization,
            &case,
        );

        let mut remediation_registry =
            cross_network_remediation::new_remediation_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let remediation =
            cross_network_remediation::create_remediation_record(
                &mut remediation_registry,
                &authorization,
                &case,
                b"full-compensation",
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        assert!(
            cross_network_remediation::remediation_amount(
                &remediation,
            ) == 10000,
            721001,
        );

        cross_network_remediation::
            destroy_remediation_record_for_testing(remediation);

        cross_network_remediation::
            destroy_remediation_registry_for_testing(
                remediation_registry,
            );

        cross_network_recovery_authorization::
            destroy_authorization_for_testing(authorization);

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
            destroy_replay_registry_for_testing(replay);

        sui::test_scenario::end(scenario);
    }
}
