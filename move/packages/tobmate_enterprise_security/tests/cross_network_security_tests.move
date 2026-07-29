#[test_only]
module tobmate_enterprise_security::cross_network_security_tests {

    use tobmate_enterprise_security::cross_network_security;

    #[test]
    fun test_01_create_binding() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"tobmate-gsos",
            b"network-b",
            b"external-settlement",
        );

        assert!(
            cross_network_security::source_matches(
                &binding,
                &b"sui-mainnet",
                &b"tobmate-gsos",
            ),
            1,
        );

        assert!(
            cross_network_security::destination_matches(
                &binding,
                &b"network-b",
                &b"external-settlement",
            ),
            2,
        );
    }

    #[test]
    fun test_02_exact_binding_matches() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        assert!(
            cross_network_security::matches_binding(
                &binding,
                &b"sui-mainnet",
                &b"gsos",
                &b"network-b",
                &b"settlement",
            ),
            3,
        );
    }

    #[test]
    fun test_03_wrong_source_network_rejected() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        assert!(
            !cross_network_security::matches_binding(
                &binding,
                &b"sui-testnet",
                &b"gsos",
                &b"network-b",
                &b"settlement",
            ),
            4,
        );
    }

    #[test]
    fun test_04_wrong_source_domain_rejected() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        assert!(
            !cross_network_security::matches_binding(
                &binding,
                &b"sui-mainnet",
                &b"wrong-domain",
                &b"network-b",
                &b"settlement",
            ),
            5,
        );
    }

    #[test]
    fun test_05_wrong_destination_network_rejected() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        assert!(
            !cross_network_security::matches_binding(
                &binding,
                &b"sui-mainnet",
                &b"gsos",
                &b"network-c",
                &b"settlement",
            ),
            6,
        );
    }

    #[test]
    fun test_06_wrong_destination_domain_rejected() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        assert!(
            !cross_network_security::matches_binding(
                &binding,
                &b"sui-mainnet",
                &b"gsos",
                &b"network-b",
                &b"wrong-domain",
            ),
            7,
        );
    }

    #[test]
    fun test_07_reverse_route_detected() {
        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        assert!(
            cross_network_security::is_reverse_route(
                &binding,
                &b"network-b",
                &b"domain-b",
                &b"network-a",
                &b"domain-a",
            ),
            8,
        );
    }

    #[test]
    fun test_08_destination_change_changes_hash() {
        let hash_a =
            cross_network_security::calculate_binding_hash(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let hash_b =
            cross_network_security::calculate_binding_hash(
                b"network-a",
                b"domain-a",
                b"network-c",
                b"domain-b",
            );

        assert!(hash_a != hash_b, 9);
    }

    #[test]
    fun test_09_reverse_route_changes_hash() {
        let forward =
            cross_network_security::calculate_binding_hash(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let reverse =
            cross_network_security::calculate_binding_hash(
                b"network-b",
                b"domain-b",
                b"network-a",
                b"domain-a",
            );

        assert!(forward != reverse, 10);
    }

    #[test]
    fun test_10_assert_binding_success() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"tobmate-gsos",
            b"network-b",
            b"external-domain",
        );

        cross_network_security::assert_binding(
            &binding,
            &b"sui-mainnet",
            &b"tobmate-gsos",
            &b"network-b",
            &b"external-domain",
        );
    }

#[test]
    fun test_11_create_intent_finality_binding() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-001",
                b"finality-001",
            );

        assert!(
            cross_network_security::matches_intent_finality(
                &binding,
                &intent_binding,
                &b"intent-001",
                &b"finality-001",
            ),
            11,
        );
    }


    #[test]
    fun test_12_wrong_intent_rejected() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-001",
                b"finality-001",
            );

        assert!(
            !cross_network_security::matches_intent_finality(
                &binding,
                &intent_binding,
                &b"intent-002",
                &b"finality-001",
            ),
            12,
        );
    }


    #[test]
    fun test_13_wrong_finality_record_rejected() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-001",
                b"finality-001",
            );

        assert!(
            !cross_network_security::matches_intent_finality(
                &binding,
                &intent_binding,
                &b"intent-001",
                &b"finality-002",
            ),
            13,
        );
    }


    #[test]
    fun test_14_wrong_network_binding_rejected() {
        let binding_a = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let binding_b = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-c",
            b"settlement",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding_a,
                b"intent-001",
                b"finality-001",
            );

        assert!(
            !cross_network_security::matches_intent_finality(
                &binding_b,
                &intent_binding,
                &b"intent-001",
                &b"finality-001",
            ),
            14,
        );
    }


    #[test]
    fun test_15_assert_intent_finality_success() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-001",
                b"finality-001",
            );

        cross_network_security::assert_intent_finality_binding(
            &binding,
            &intent_binding,
            &b"intent-001",
            &b"finality-001",
        );
    }


    #[test]
    fun test_16_different_intent_changes_hash() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let hash_a =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-b",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-001",
            );

        let hash_b =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-b",
                    b"settlement",
                ),
                b"intent-002",
                b"finality-001",
            );

        assert!(hash_a != hash_b, 16);
    }


    #[test]
    fun test_17_different_finality_changes_hash() {
        let binding = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let hash_a =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-b",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-001",
            );

        let hash_b =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-b",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-002",
            );

        assert!(hash_a != hash_b, 17);
    }


    #[test]
    fun test_18_different_network_changes_intent_finality_hash() {
        let binding_a = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let binding_b = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-c",
            b"settlement",
        );

        let hash_a =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-b",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-001",
            );

        let hash_b =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-c",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-001",
            );

        assert!(hash_a != hash_b, 18);
    }


    #[test]
    fun test_19_different_domain_changes_intent_finality_hash() {
        let binding_a = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos",
            b"network-b",
            b"settlement",
        );

        let binding_b = cross_network_security::new_binding(
            b"sui-mainnet",
            b"gsos-other",
            b"network-b",
            b"settlement",
        );

        let hash_a =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-b",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-001",
            );

        let hash_b =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"sui-mainnet",
                    b"gsos",
                    b"network-c",
                    b"settlement",
                ),
                b"intent-001",
                b"finality-001",
            );

        assert!(hash_a != hash_b, 19);
    }


    #[test]
    fun test_20_reverse_route_changes_intent_finality_hash() {
        let forward = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let reverse = cross_network_security::new_binding(
            b"network-b",
            b"domain-b",
            b"network-a",
            b"domain-a",
        );

        let forward_hash =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"network-a",
                    b"domain-a",
                    b"network-b",
                    b"domain-b",
                ),
                b"intent-001",
                b"finality-001",
            );

        let reverse_hash =
            cross_network_security::calculate_intent_finality_hash(
                cross_network_security::calculate_binding_hash(
                    b"network-b",
                    b"domain-b",
                    b"network-a",
                    b"domain-a",
                ),
                b"intent-001",
                b"finality-001",
            );

        assert!(forward_hash != reverse_hash, 20);
    }


    #[test]
    fun test_21_external_reference_consumption() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-021",
                b"finality-021",
            );

        let registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut registry = registry;

        cross_network_security::consume_external_reference(
            &mut registry,
            &intent_binding,
            b"external-ref-021",
        );

        assert!(
            cross_network_security::is_external_reference_consumed(
                &registry,
                b"external-ref-021",
            ),
            21,
        );

        assert!(
            cross_network_security::replay_total_consumed(
                &registry,
            ) == 1,
            22,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_22_confirmation_hash_consumption() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-022",
                b"finality-022",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_confirmation_hash(
            &mut registry,
            &intent_binding,
            b"confirmation-022",
        );

        assert!(
            cross_network_security::is_confirmation_hash_consumed(
                &registry,
                b"confirmation-022",
            ),
            23,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_23_proof_consumption() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-023",
                b"finality-023",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_binding,
            b"proof-023",
        );

        assert!(
            cross_network_security::is_proof_consumed(
                &registry,
                b"proof-023",
            ),
            24,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_24_context_marked_consumed() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-024",
                b"finality-024",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_external_reference(
            &mut registry,
            &intent_binding,
            b"external-ref-024",
        );

        assert!(
            cross_network_security::is_context_consumed(
                &registry,
                &intent_binding,
                1,
                b"external-ref-024",
            ),
            25,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_25_category_counts() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-025",
                b"finality-025",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_external_reference(
            &mut registry,
            &intent_binding,
            b"external-025",
        );

        cross_network_security::consume_confirmation_hash(
            &mut registry,
            &intent_binding,
            b"confirmation-025",
        );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_binding,
            b"proof-025",
        );

        assert!(
            cross_network_security::external_reference_count(
                &registry,
            ) == 1,
            26,
        );

        assert!(
            cross_network_security::confirmation_hash_count(
                &registry,
            ) == 1,
            27,
        );

        assert!(
            cross_network_security::proof_fingerprint_count(
                &registry,
            ) == 1,
            28,
        );

        assert!(
            cross_network_security::context_replay_count(
                &registry,
            ) == 3,
            29,
        );

        assert!(
            cross_network_security::replay_total_consumed(
                &registry,
            ) == 3,
            30,
        );

        cross_network_security::destroy_replay_registry_for_testing(
            registry,
        );

        sui::test_scenario::end(scenario);
    }


    // ============================================================
    // Test 26
    // Same external reference cannot be consumed twice.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205023)]
    fun test_26_external_reference_replay_rejected() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-026",
                b"finality-026",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_external_reference(
            &mut registry,
            &intent_binding,
            b"external-replay-026",
        );

        cross_network_security::consume_external_reference(
            &mut registry,
            &intent_binding,
            b"external-replay-026",
        );

        abort 2600
    }


    // ============================================================
    // Test 27
    // Same confirmation hash cannot be consumed twice.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205024)]
    fun test_27_confirmation_hash_replay_rejected() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-027",
                b"finality-027",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_confirmation_hash(
            &mut registry,
            &intent_binding,
            b"confirmation-replay-027",
        );

        cross_network_security::consume_confirmation_hash(
            &mut registry,
            &intent_binding,
            b"confirmation-replay-027",
        );

        abort 2700
    }


    // ============================================================
    // Test 28
    // Same proof cannot be consumed twice.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205025)]
    fun test_28_proof_replay_rejected() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-028",
                b"finality-028",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_binding,
            b"proof-replay-028",
        );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_binding,
            b"proof-replay-028",
        );

        abort 2800
    }


    // ============================================================
    // Test 29
    // Same proof + different intent is still globally rejected.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205025)]
    fun test_29_cross_intent_proof_reuse_rejected() {
        let mut scenario = sui::test_scenario::begin(@0xA);

        let binding = cross_network_security::new_binding(
            b"network-a",
            b"domain-a",
            b"network-b",
            b"domain-b",
        );

        let intent_a =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-029-a",
                b"finality-029-a",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-029-b",
                b"finality-029-b",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_a,
            b"proof-global-029",
        );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_b,
            b"proof-global-029",
        );

        abort 2900
    }


    // ============================================================
    // Test 30
    // Same proof cannot migrate to another network/domain route.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205025)]
    fun test_30_cross_network_proof_reuse_rejected() {
        let mut scenario = sui::test_scenario::begin(@0xA);

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
                b"intent-030",
                b"finality-030",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding_b,
                b"intent-030",
                b"finality-030",
            );

        let mut registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_a,
            b"proof-global-030",
        );

        cross_network_security::consume_proof(
            &mut registry,
            &intent_b,
            b"proof-global-030",
        );

        abort 3000
    }


    // ============================================================
    // Test 31
    // PENDING -> CONFIRMED
    // ============================================================

    #[test]
    fun test_31_pending_to_confirmed() {
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
                b"intent-031",
                b"finality-031",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        assert!(
            cross_network_security::finality_status(&record)
                == cross_network_security::finality_pending_status(),
            3101,
        );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding,
            &intent_binding,
        );

        assert!(
            cross_network_security::is_confirmed(&record),
            3102,
        );

        assert!(
            !cross_network_security::is_terminal(&record),
            3103,
        );
    }


    // ============================================================
    // Test 32
    // CONFIRMED -> EXECUTED
    // ============================================================

    #[test]
    fun test_32_confirmed_to_executed() {
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
                b"intent-032",
                b"finality-032",
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

        cross_network_security::assert_execution_context(
            &record,
            &binding,
            &intent_binding,
        );

        cross_network_security::mark_finality_executed(
            &mut record,
            &binding,
            &intent_binding,
        );

        assert!(
            cross_network_security::is_executed(&record),
            3201,
        );

        assert!(
            cross_network_security::is_terminal(&record),
            3202,
        );

        assert!(
            cross_network_security::finality_status(&record)
                == cross_network_security::finality_executed_status(),
            3203,
        );
    }


    // ============================================================
    // Test 33
    // PENDING cannot execute.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205033)]
    fun test_33_pending_execution_rejected() {
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
                b"intent-033",
                b"finality-033",
            );

        let record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::assert_finality_executable(
            &record,
            &binding,
            &intent_binding,
        );

        abort 3300
    }


    // ============================================================
    // Test 34
    // REJECTED is terminal and cannot execute.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205035)]
    fun test_34_rejected_execution_rejected() {
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
                b"intent-034",
                b"finality-034",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_rejected(
            &mut record,
            &binding,
            &intent_binding,
        );

        cross_network_security::assert_finality_executable(
            &record,
            &binding,
            &intent_binding,
        );

        abort 3400
    }


    // ============================================================
    // Test 35
    // EXPIRED is terminal and cannot execute.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205035)]
    fun test_35_expired_execution_rejected() {
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
                b"intent-035",
                b"finality-035",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_expired(
            &mut record,
            &binding,
            &intent_binding,
        );

        cross_network_security::assert_finality_executable(
            &record,
            &binding,
            &intent_binding,
        );

        abort 3500
    }

    // ============================================================
    // Test 36
    // EXECUTED cannot execute again.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205034)]
    fun test_36_executed_record_reexecution_rejected() {
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
                b"intent-036",
                b"finality-036",
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

        cross_network_security::mark_finality_executed(
            &mut record,
            &binding,
            &intent_binding,
        );

        cross_network_security::assert_finality_executable(
            &record,
            &binding,
            &intent_binding,
        );

        abort 3600
    }


    // ============================================================
    // Test 37
    // Wrong destination network must fail.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205030)]
    fun test_37_wrong_network_finality_rejected() {
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
                b"domain-b",
            );

        let intent_a =
            cross_network_security::new_intent_finality_binding(
                &binding_a,
                b"intent-037",
                b"finality-037",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding_a,
                &intent_a,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding_a,
            &intent_a,
        );

        cross_network_security::assert_finality_executable(
            &record,
            &binding_b,
            &intent_a,
        );

        abort 3700
    }


    // ============================================================
    // Test 38
    // Wrong domain must fail.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205030)]
    fun test_38_wrong_domain_finality_rejected() {
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
                b"domain-x",
                b"network-b",
                b"domain-b",
            );

        let intent_a =
            cross_network_security::new_intent_finality_binding(
                &binding_a,
                b"intent-038",
                b"finality-038",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding_a,
                &intent_a,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding_a,
            &intent_a,
        );

        cross_network_security::assert_finality_executable(
            &record,
            &binding_b,
            &intent_a,
        );

        abort 3800
    }


    // ============================================================
    // Test 39
    // Wrong intent binding must fail.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205031)]
    fun test_39_wrong_intent_finality_rejected() {
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
                b"intent-039-a",
                b"finality-039",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-039-b",
                b"finality-039",
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

        cross_network_security::assert_finality_executable(
            &record,
            &binding,
            &intent_b,
        );

        abort 3900
    }


    // ============================================================
    // Test 40
    // Wrong finality record binding must fail.
    // ============================================================

    #[test]
    #[expected_failure(abort_code = 1205031)]
    fun test_40_wrong_finality_record_rejected() {
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
                b"intent-040",
                b"finality-040-a",
            );

        let intent_b =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-040",
                b"finality-040-b",
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

        cross_network_security::assert_finality_executable(
            &record,
            &binding,
            &intent_b,
        );

        abort 4000
    }
}
