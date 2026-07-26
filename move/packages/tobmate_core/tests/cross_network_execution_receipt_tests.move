#[test_only]
module tobmate_core::cross_network_execution_receipt_tests {

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_receipt;


    // ============================================================
    // Test 01
    // Successful execution creates valid audit receipt.
    // ============================================================

    #[test]
    fun test_01_execute_and_anchor_success() {
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
                b"intent-6b-001",
                b"finality-6b-001",
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

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-001",
                b"confirmation-6b-001",
                b"proof-6b-001",
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_receipt::assert_receipt_valid(
            &receipt,
            &record,
            &binding,
            &intent_binding,
        );

        assert!(
            cross_network_security::is_executed(&record),
            6101,
        );

        assert!(
            cross_network_execution_receipt::receipt_sequence(
                &receipt,
            ) == 1,
            6102,
        );

        cross_network_execution_receipt::destroy_receipt_for_testing(
            receipt,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    // ============================================================
    // Test 02
    // Same input generates deterministic execution ID.
    // ============================================================

    #[test]
    fun test_02_execution_id_deterministic() {
        let id_a =
            cross_network_execution_receipt::calculate_execution_id(
                b"binding-hash",
                b"intent-finality-hash",
                b"external-digest",
                b"confirmation-digest",
                b"proof-digest",
                7,
                12,
            );

        let id_b =
            cross_network_execution_receipt::calculate_execution_id(
                b"binding-hash",
                b"intent-finality-hash",
                b"external-digest",
                b"confirmation-digest",
                b"proof-digest",
                7,
                12,
            );

        assert!(id_a == id_b, 6201);
    }


    // ============================================================
    // Test 03
    // Sequence changes execution ID.
    // ============================================================

    #[test]
    fun test_03_sequence_changes_execution_id() {
        let id_a =
            cross_network_execution_receipt::calculate_execution_id(
                b"binding-hash",
                b"intent-finality-hash",
                b"external-digest",
                b"confirmation-digest",
                b"proof-digest",
                1,
                12,
            );

        let id_b =
            cross_network_execution_receipt::calculate_execution_id(
                b"binding-hash",
                b"intent-finality-hash",
                b"external-digest",
                b"confirmation-digest",
                b"proof-digest",
                2,
                12,
            );

        assert!(id_a != id_b, 6301);
    }


    // ============================================================
    // Test 04
    // Epoch changes execution ID.
    // ============================================================

    #[test]
    fun test_04_epoch_changes_execution_id() {
        let id_a =
            cross_network_execution_receipt::calculate_execution_id(
                b"binding-hash",
                b"intent-finality-hash",
                b"external-digest",
                b"confirmation-digest",
                b"proof-digest",
                1,
                100,
            );

        let id_b =
            cross_network_execution_receipt::calculate_execution_id(
                b"binding-hash",
                b"intent-finality-hash",
                b"external-digest",
                b"confirmation-digest",
                b"proof-digest",
                1,
                101,
            );

        assert!(id_a != id_b, 6401);
    }


    // ============================================================
    // Test 05
    // Receipt sequence assertion succeeds.
    // ============================================================

    #[test]
    fun test_05_receipt_sequence_success() {
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
                b"intent-6b-005",
                b"finality-6b-005",
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

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-005",
                b"confirmation-6b-005",
                b"proof-6b-005",
                55,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_receipt::assert_receipt_sequence(
            &receipt,
            55,
        );

        cross_network_execution_receipt::destroy_receipt_for_testing(
            receipt,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }

    // ============================================================
    // Test 06
    // Receipt cannot validate against another network binding.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1206001)]
    fun test_06_wrong_binding_receipt_rejected() {
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

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding_a,
                b"intent-6b-006",
                b"finality-6b-006",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding_a,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding_a,
            &intent_binding,
        );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding_a,
                &intent_binding,
                b"external-6b-006",
                b"confirmation-6b-006",
                b"proof-6b-006",
                6,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_receipt::assert_receipt_valid(
            &receipt,
            &record,
            &binding_b,
            &intent_binding,
        );

        abort 6600
    }


    // ============================================================
    // Test 07
    // Receipt cannot validate against another intent.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1206002)]
    fun test_07_wrong_intent_receipt_rejected() {
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
                b"intent-6b-007-a",
                b"finality-6b-007",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-6b-007-b",
                b"finality-6b-007",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_a,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding,
            &intent_a,
        );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_a,
                b"external-6b-007",
                b"confirmation-6b-007",
                b"proof-6b-007",
                7,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_receipt::assert_receipt_valid(
            &receipt,
            &record,
            &binding,
            &intent_b,
        );

        abort 6700
    }


    // ============================================================
    // Test 08
    // Sequence mismatch rejected.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1206005)]
    fun test_08_sequence_mismatch_rejected() {
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
                b"intent-6b-008",
                b"finality-6b-008",
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

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-008",
                b"confirmation-6b-008",
                b"proof-6b-008",
                8,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_receipt::assert_receipt_sequence(
            &receipt,
            9,
        );

        abort 6800
    }


    // ============================================================
    // Test 09
    // Same replay-protected material cannot create second receipt.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205034)]
    fun test_09_second_receipt_same_record_rejected() {
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
                b"intent-6b-009",
                b"finality-6b-009",
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

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _receipt_a =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-009",
                b"confirmation-6b-009",
                b"proof-6b-009",
                9,
                sui::test_scenario::ctx(&mut scenario),
            );

        let _receipt_b =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-009",
                b"confirmation-6b-009",
                b"proof-6b-009",
                10,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 6900
    }


    // ============================================================
    // Test 10
    // Executed record cannot create fresh receipt with new proof.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205034)]
    fun test_10_executed_record_new_receipt_rejected() {
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
                b"intent-6b-010",
                b"finality-6b-010",
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

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let _receipt_a =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-010-a",
                b"confirmation-6b-010-a",
                b"proof-6b-010-a",
                10,
                sui::test_scenario::ctx(&mut scenario),
            );

        let _receipt_b =
            cross_network_execution_receipt::execute_and_anchor(
                &mut registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-6b-010-b",
                b"confirmation-6b-010-b",
                b"proof-6b-010-b",
                11,
                sui::test_scenario::ctx(&mut scenario),
            );

        abort 61000
    }
}
