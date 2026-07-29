#[test_only]
module tobmate_enterprise_security::cross_network_execution_guard_tests {

    use tobmate_enterprise_security::cross_network_security;
    use tobmate_enterprise_security::cross_network_execution_guard;


    // ============================================================
    // Test 01
    // Confirmed execution succeeds atomically.
    // ============================================================

    #[test]
    fun test_01_atomic_execution_success() {
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
                b"intent-6a-001",
                b"finality-6a-001",
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

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record,
            &binding,
            &intent_binding,
            b"external-6a-001",
            b"confirmation-6a-001",
            b"proof-6a-001",
        );

        assert!(
            cross_network_execution_guard::is_execution_complete(
                &registry,
                &record,
                b"external-6a-001",
                b"confirmation-6a-001",
                b"proof-6a-001",
            ),
            1,
        );

        assert!(
            cross_network_security::replay_total_consumed(
                &registry,
            ) == 3,
            2,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    // ============================================================
    // Test 02
    // Pending finality cannot execute.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205033)]
    fun test_02_pending_execution_rejected() {
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
                b"intent-6a-002",
                b"finality-6a-002",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record,
            &binding,
            &intent_binding,
            b"external-6a-002",
            b"confirmation-6a-002",
            b"proof-6a-002",
        );

        abort 6002
    }


    // ============================================================
    // Test 03
    // Same terminal record cannot execute twice.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205034)]
    fun test_03_double_execution_rejected() {
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
                b"intent-6a-003",
                b"finality-6a-003",
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

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record,
            &binding,
            &intent_binding,
            b"external-6a-003",
            b"confirmation-6a-003",
            b"proof-6a-003",
        );

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record,
            &binding,
            &intent_binding,
            b"external-6a-003-b",
            b"confirmation-6a-003-b",
            b"proof-6a-003-b",
        );

        abort 6003
    }


    // ============================================================
    // Test 04
    // Wrong-network execution cannot use valid finality.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205009)]
    fun test_04_wrong_network_execution_rejected() {
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
                b"intent-6a-004",
                b"finality-6a-004",
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

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record,
            &binding_b,
            &intent_binding,
            b"external-6a-004",
            b"confirmation-6a-004",
            b"proof-6a-004",
        );

        abort 6004
    }


    // ============================================================
    // Test 05
    // Consumed proof cannot execute another confirmed intent.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205025)]
    fun test_05_cross_intent_proof_execution_rejected() {
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
                b"intent-6a-005-a",
                b"finality-6a-005-a",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-6a-005-b",
                b"finality-6a-005-b",
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

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record_a,
            &binding,
            &intent_a,
            b"external-6a-005-a",
            b"confirmation-6a-005-a",
            b"proof-shared-6a-005",
        );

        cross_network_execution_guard::execute_once(
            &mut registry,
            &mut record_b,
            &binding,
            &intent_b,
            b"external-6a-005-b",
            b"confirmation-6a-005-b",
            b"proof-shared-6a-005",
        );

        abort 6005
    }
}
