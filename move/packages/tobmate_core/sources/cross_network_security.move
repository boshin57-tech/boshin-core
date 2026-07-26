module tobmate_core::cross_network_security {

    use std::bcs;
    use sui::hash;

    // ============================================================
    // Error Codes
    // ============================================================

    const E_EMPTY_SOURCE_NETWORK_ID: u64 = 1205001;
    const E_EMPTY_SOURCE_DOMAIN: u64 = 1205002;
    const E_EMPTY_DESTINATION_NETWORK_ID: u64 = 1205003;
    const E_EMPTY_DESTINATION_DOMAIN: u64 = 1205004;

    const E_SOURCE_NETWORK_MISMATCH: u64 = 1205005;
    const E_SOURCE_DOMAIN_MISMATCH: u64 = 1205006;
    const E_DESTINATION_NETWORK_MISMATCH: u64 = 1205007;
    const E_DESTINATION_DOMAIN_MISMATCH: u64 = 1205008;
    const E_BINDING_HASH_MISMATCH: u64 = 1205009;


    // ============================================================
    // Canonical Binding Material
    // ============================================================

    public struct BindingMaterial has drop, store {
        source_network_id: vector<u8>,
        source_domain: vector<u8>,
        destination_network_id: vector<u8>,
        destination_domain: vector<u8>,
    }


    // ============================================================
    // Cross-Network Security Binding
    // ============================================================

    public struct CrossNetworkBinding has drop, store {
        source_network_id: vector<u8>,
        source_domain: vector<u8>,

        destination_network_id: vector<u8>,
        destination_domain: vector<u8>,

        binding_hash: vector<u8>,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_binding(
        source_network_id: vector<u8>,
        source_domain: vector<u8>,
        destination_network_id: vector<u8>,
        destination_domain: vector<u8>,
    ): CrossNetworkBinding {

        assert!(
            vector::length(&source_network_id) > 0,
            E_EMPTY_SOURCE_NETWORK_ID,
        );

        assert!(
            vector::length(&source_domain) > 0,
            E_EMPTY_SOURCE_DOMAIN,
        );

        assert!(
            vector::length(&destination_network_id) > 0,
            E_EMPTY_DESTINATION_NETWORK_ID,
        );

        assert!(
            vector::length(&destination_domain) > 0,
            E_EMPTY_DESTINATION_DOMAIN,
        );

        let material = BindingMaterial {
            source_network_id,
            source_domain,
            destination_network_id,
            destination_domain,
        };

        let encoded = bcs::to_bytes(&material);
        let binding_hash = hash::blake2b256(&encoded);

        let BindingMaterial {
            source_network_id,
            source_domain,
            destination_network_id,
            destination_domain,
        } = material;

        CrossNetworkBinding {
            source_network_id,
            source_domain,
            destination_network_id,
            destination_domain,
            binding_hash,
        }
    }


    // ============================================================
    // Canonical Binding Hash
    // ============================================================

    public fun calculate_binding_hash(
        source_network_id: vector<u8>,
        source_domain: vector<u8>,
        destination_network_id: vector<u8>,
        destination_domain: vector<u8>,
    ): vector<u8> {

        assert!(
            vector::length(&source_network_id) > 0,
            E_EMPTY_SOURCE_NETWORK_ID,
        );

        assert!(
            vector::length(&source_domain) > 0,
            E_EMPTY_SOURCE_DOMAIN,
        );

        assert!(
            vector::length(&destination_network_id) > 0,
            E_EMPTY_DESTINATION_NETWORK_ID,
        );

        assert!(
            vector::length(&destination_domain) > 0,
            E_EMPTY_DESTINATION_DOMAIN,
        );

        let material = BindingMaterial {
            source_network_id,
            source_domain,
            destination_network_id,
            destination_domain,
        };

        hash::blake2b256(&bcs::to_bytes(&material))
    }


    // ============================================================
    // Full Binding Assertion
    // ============================================================

    public fun assert_binding(
        binding: &CrossNetworkBinding,
        expected_source_network_id: &vector<u8>,
        expected_source_domain: &vector<u8>,
        expected_destination_network_id: &vector<u8>,
        expected_destination_domain: &vector<u8>,
    ) {

        assert!(
            &binding.source_network_id == expected_source_network_id,
            E_SOURCE_NETWORK_MISMATCH,
        );

        assert!(
            &binding.source_domain == expected_source_domain,
            E_SOURCE_DOMAIN_MISMATCH,
        );

        assert!(
            &binding.destination_network_id == expected_destination_network_id,
            E_DESTINATION_NETWORK_MISMATCH,
        );

        assert!(
            &binding.destination_domain == expected_destination_domain,
            E_DESTINATION_DOMAIN_MISMATCH,
        );

        let material = BindingMaterial {
            source_network_id: copy binding.source_network_id,
            source_domain: copy binding.source_domain,
            destination_network_id: copy binding.destination_network_id,
            destination_domain: copy binding.destination_domain,
        };

        let recalculated_hash =
            hash::blake2b256(&bcs::to_bytes(&material));

        assert!(
            binding.binding_hash == recalculated_hash,
            E_BINDING_HASH_MISMATCH,
        );
    }


    // ============================================================
    // Non-Aborting Full Match
    // ============================================================

    public fun matches_binding(
        binding: &CrossNetworkBinding,
        source_network_id: &vector<u8>,
        source_domain: &vector<u8>,
        destination_network_id: &vector<u8>,
        destination_domain: &vector<u8>,
    ): bool {

        &binding.source_network_id == source_network_id
            && &binding.source_domain == source_domain
            && &binding.destination_network_id == destination_network_id
            && &binding.destination_domain == destination_domain
    }


    // ============================================================
    // Endpoint Consistency
    // ============================================================

    public fun source_matches(
        binding: &CrossNetworkBinding,
        network_id: &vector<u8>,
        domain: &vector<u8>,
    ): bool {

        &binding.source_network_id == network_id
            && &binding.source_domain == domain
    }


    public fun destination_matches(
        binding: &CrossNetworkBinding,
        network_id: &vector<u8>,
        domain: &vector<u8>,
    ): bool {

        &binding.destination_network_id == network_id
            && &binding.destination_domain == domain
    }


    // ============================================================
    // Reverse Route Detection
    //
    // Binding A -> B must not be reused as B -> A.
    // ============================================================

    public fun is_reverse_route(
        binding: &CrossNetworkBinding,
        source_network_id: &vector<u8>,
        source_domain: &vector<u8>,
        destination_network_id: &vector<u8>,
        destination_domain: &vector<u8>,
    ): bool {

        &binding.source_network_id == destination_network_id
            && &binding.source_domain == destination_domain
            && &binding.destination_network_id == source_network_id
            && &binding.destination_domain == source_domain
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun source_network_id(
        binding: &CrossNetworkBinding,
    ): &vector<u8> {
        &binding.source_network_id
    }


    public fun source_domain(
        binding: &CrossNetworkBinding,
    ): &vector<u8> {
        &binding.source_domain
    }


    public fun destination_network_id(
        binding: &CrossNetworkBinding,
    ): &vector<u8> {
        &binding.destination_network_id
    }


    public fun destination_domain(
        binding: &CrossNetworkBinding,
    ): &vector<u8> {
        &binding.destination_domain
    }


    public fun binding_hash(
        binding: &CrossNetworkBinding,
    ): &vector<u8> {
        &binding.binding_hash
    }

// NOTE:
// Stage 12 Part 5-D Source 1-B extends the module above.
// The additional definitions below are intentionally kept
// compact for terminal-safe input.

    // ============================================================
    // Intent / Finality Binding Errors
    // ============================================================

    const E_EMPTY_INTENT_ID: u64 = 1205010;
    const E_EMPTY_FINALITY_RECORD_ID: u64 = 1205011;
    const E_INTENT_ID_MISMATCH: u64 = 1205012;
    const E_FINALITY_RECORD_ID_MISMATCH: u64 = 1205013;
    const E_INTENT_FINALITY_HASH_MISMATCH: u64 = 1205014;


    // ============================================================
    // Intent / Finality Binding Material
    // ============================================================

    public struct IntentFinalityMaterial has drop, store {
        binding_hash: vector<u8>,
        intent_id: vector<u8>,
        finality_record_id: vector<u8>,
    }


    public struct IntentFinalityBinding has drop, store {
        binding_hash: vector<u8>,
        intent_id: vector<u8>,
        finality_record_id: vector<u8>,
        intent_finality_hash: vector<u8>,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_intent_finality_binding(
        binding: &CrossNetworkBinding,
        intent_id: vector<u8>,
        finality_record_id: vector<u8>,
    ): IntentFinalityBinding {

        assert!(
            vector::length(&intent_id) > 0,
            E_EMPTY_INTENT_ID,
        );

        assert!(
            vector::length(&finality_record_id) > 0,
            E_EMPTY_FINALITY_RECORD_ID,
        );

        let binding_hash = copy binding.binding_hash;

        let material = IntentFinalityMaterial {
            binding_hash,
            intent_id,
            finality_record_id,
        };

        let intent_finality_hash =
            hash::blake2b256(&bcs::to_bytes(&material));

        let IntentFinalityMaterial {
            binding_hash,
            intent_id,
            finality_record_id,
        } = material;

        IntentFinalityBinding {
            binding_hash,
            intent_id,
            finality_record_id,
            intent_finality_hash,
        }
    }


    // ============================================================
    // Canonical Intent / Finality Hash
    // ============================================================

    public fun calculate_intent_finality_hash(
        binding_hash: vector<u8>,
        intent_id: vector<u8>,
        finality_record_id: vector<u8>,
    ): vector<u8> {

        assert!(
            vector::length(&intent_id) > 0,
            E_EMPTY_INTENT_ID,
        );

        assert!(
            vector::length(&finality_record_id) > 0,
            E_EMPTY_FINALITY_RECORD_ID,
        );

        let material = IntentFinalityMaterial {
            binding_hash,
            intent_id,
            finality_record_id,
        };

        hash::blake2b256(&bcs::to_bytes(&material))
    }


    // ============================================================
    // Full Intent / Finality Assertion
    // ============================================================

    public fun assert_intent_finality_binding(
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
        expected_intent_id: &vector<u8>,
        expected_finality_record_id: &vector<u8>,
    ) {

        assert!(
            &intent_binding.intent_id == expected_intent_id,
            E_INTENT_ID_MISMATCH,
        );

        assert!(
            &intent_binding.finality_record_id
                == expected_finality_record_id,
            E_FINALITY_RECORD_ID_MISMATCH,
        );

        assert!(
            intent_binding.binding_hash == binding.binding_hash,
            E_BINDING_HASH_MISMATCH,
        );

        let material = IntentFinalityMaterial {
            binding_hash: copy intent_binding.binding_hash,
            intent_id: copy intent_binding.intent_id,
            finality_record_id:
                copy intent_binding.finality_record_id,
        };

        let recalculated =
            hash::blake2b256(&bcs::to_bytes(&material));

        assert!(
            intent_binding.intent_finality_hash == recalculated,
            E_INTENT_FINALITY_HASH_MISMATCH,
        );
    }


    // ============================================================
    // Boolean Match
    // ============================================================

    public fun matches_intent_finality(
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
        intent_id: &vector<u8>,
        finality_record_id: &vector<u8>,
    ): bool {

        intent_binding.binding_hash == binding.binding_hash
            && &intent_binding.intent_id == intent_id
            && &intent_binding.finality_record_id
                == finality_record_id
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun intent_id(
        binding: &IntentFinalityBinding,
    ): &vector<u8> {
        &binding.intent_id
    }


    public fun finality_record_id(
        binding: &IntentFinalityBinding,
    ): &vector<u8> {
        &binding.finality_record_id
    }


    public fun intent_finality_hash(
        binding: &IntentFinalityBinding,
    ): &vector<u8> {
        &binding.intent_finality_hash
    }


    // ============================================================
    // Source 2-A
    // Replay Protection Registry
    // ============================================================

    const E_EMPTY_EXTERNAL_REFERENCE: u64 = 1205020;
    const E_EMPTY_CONFIRMATION_HASH: u64 = 1205021;
    const E_EMPTY_PROOF_FINGERPRINT: u64 = 1205022;

    const E_EXTERNAL_REFERENCE_REPLAY: u64 = 1205023;
    const E_CONFIRMATION_HASH_REPLAY: u64 = 1205024;
    const E_PROOF_FINGERPRINT_REPLAY: u64 = 1205025;

    const E_CONTEXT_REPLAY: u64 = 1205026;
    const E_INVALID_REPLAY_TYPE: u64 = 1205027;


    // ============================================================
    // Replay Types
    // ============================================================

    const REPLAY_TYPE_EXTERNAL_REFERENCE: u8 = 1;
    const REPLAY_TYPE_CONFIRMATION_HASH: u8 = 2;
    const REPLAY_TYPE_PROOF: u8 = 3;


    // ============================================================
    // Fingerprint Material
    //
    // replay_type is part of the hash domain separation.
    // Therefore identical bytes used as:
    //
    // external reference
    // confirmation hash
    // proof
    //
    // do not collide across semantic categories.
    // ============================================================

    public struct RawReplayFingerprintMaterial has drop, store {
        replay_type: u8,
        value: vector<u8>,
    }


    // ============================================================
    // Context Replay Material
    //
    // intent_finality_hash already contains:
    //
    // source network
    // source domain
    // destination network
    // destination domain
    // direction
    // intent id
    // finality record id
    //
    // The value fingerprint is then bound to that context.
    // ============================================================

    public struct ContextReplayMaterial has drop, store {
        replay_type: u8,
        intent_finality_hash: vector<u8>,
        value_fingerprint: vector<u8>,
    }


    // ============================================================
    // Replay Protection Registry
    //
    // Global fingerprints prevent the SAME raw value from being
    // reused under a different network/domain/intent.
    //
    // Context keys additionally provide exact execution-context
    // replay tracking.
    // ============================================================

    public struct ReplayProtectionRegistry has key, store {
        id: sui::object::UID,

        consumed_external_references: vector<vector<u8>>,
        consumed_confirmation_hashes: vector<vector<u8>>,
        consumed_proof_fingerprints: vector<vector<u8>>,

        consumed_context_keys: vector<vector<u8>>,

        total_consumed: u64,
        version: u64,
    }


    // ============================================================
    // Registry Constructor
    // ============================================================

    public fun new_replay_protection_registry(
        ctx: &mut sui::tx_context::TxContext,
    ): ReplayProtectionRegistry {

        ReplayProtectionRegistry {
            id: sui::object::new(ctx),

            consumed_external_references: vector[],
            consumed_confirmation_hashes: vector[],
            consumed_proof_fingerprints: vector[],

            consumed_context_keys: vector[],

            total_consumed: 0,
            version: 1,
        }
    }


    // ============================================================
    // Internal Byte Membership
    // ============================================================

    fun contains_bytes(
        values: &vector<vector<u8>>,
        target: &vector<u8>,
    ): bool {

        let mut index = 0;
        let length = vector::length(values);

        while (index < length) {
            if (vector::borrow(values, index) == target) {
                return true
            };

            index = index + 1;
        };

        false
    }


    // ============================================================
    // Replay Type Validation
    // ============================================================

    fun assert_valid_replay_type(
        replay_type: u8,
    ) {

        assert!(
            replay_type == REPLAY_TYPE_EXTERNAL_REFERENCE
                || replay_type == REPLAY_TYPE_CONFIRMATION_HASH
                || replay_type == REPLAY_TYPE_PROOF,
            E_INVALID_REPLAY_TYPE,
        );
    }


    // ============================================================
    // Raw Fingerprint Calculation
    // ============================================================

    public fun calculate_raw_replay_fingerprint(
        replay_type: u8,
        value: vector<u8>,
    ): vector<u8> {

        assert_valid_replay_type(replay_type);

        let material = RawReplayFingerprintMaterial {
            replay_type,
            value,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Context Replay Key Calculation
    // ============================================================

    public fun calculate_context_replay_key(
        intent_binding: &IntentFinalityBinding,
        replay_type: u8,
        value_fingerprint: vector<u8>,
    ): vector<u8> {

        assert_valid_replay_type(replay_type);

        let material = ContextReplayMaterial {
            replay_type,
            intent_finality_hash:
                copy intent_binding.intent_finality_hash,
            value_fingerprint,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // External Reference Consumption
    //
    // Global fingerprint:
    // same external reference cannot be reused anywhere.
    //
    // Context key:
    // exact network/domain/intent/finality execution is also
    // permanently marked as consumed.
    // ============================================================

    public fun consume_external_reference(
        registry: &mut ReplayProtectionRegistry,
        intent_binding: &IntentFinalityBinding,
        external_reference: vector<u8>,
    ) {

        assert!(
            vector::length(&external_reference) > 0,
            E_EMPTY_EXTERNAL_REFERENCE,
        );

        let fingerprint =
            calculate_raw_replay_fingerprint(
                REPLAY_TYPE_EXTERNAL_REFERENCE,
                external_reference,
            );

        assert!(
            !contains_bytes(
                &registry.consumed_external_references,
                &fingerprint,
            ),
            E_EXTERNAL_REFERENCE_REPLAY,
        );

        let context_key =
            calculate_context_replay_key(
                intent_binding,
                REPLAY_TYPE_EXTERNAL_REFERENCE,
                copy fingerprint,
            );

        assert!(
            !contains_bytes(
                &registry.consumed_context_keys,
                &context_key,
            ),
            E_CONTEXT_REPLAY,
        );

        vector::push_back(
            &mut registry.consumed_external_references,
            fingerprint,
        );

        vector::push_back(
            &mut registry.consumed_context_keys,
            context_key,
        );

        registry.total_consumed =
            registry.total_consumed + 1;
    }


    // ============================================================
    // Confirmation Hash Consumption
    // ============================================================

    public fun consume_confirmation_hash(
        registry: &mut ReplayProtectionRegistry,
        intent_binding: &IntentFinalityBinding,
        confirmation_hash: vector<u8>,
    ) {

        assert!(
            vector::length(&confirmation_hash) > 0,
            E_EMPTY_CONFIRMATION_HASH,
        );

        let fingerprint =
            calculate_raw_replay_fingerprint(
                REPLAY_TYPE_CONFIRMATION_HASH,
                confirmation_hash,
            );

        assert!(
            !contains_bytes(
                &registry.consumed_confirmation_hashes,
                &fingerprint,
            ),
            E_CONFIRMATION_HASH_REPLAY,
        );

        let context_key =
            calculate_context_replay_key(
                intent_binding,
                REPLAY_TYPE_CONFIRMATION_HASH,
                copy fingerprint,
            );

        assert!(
            !contains_bytes(
                &registry.consumed_context_keys,
                &context_key,
            ),
            E_CONTEXT_REPLAY,
        );

        vector::push_back(
            &mut registry.consumed_confirmation_hashes,
            fingerprint,
        );

        vector::push_back(
            &mut registry.consumed_context_keys,
            context_key,
        );

        registry.total_consumed =
            registry.total_consumed + 1;
    }


    // ============================================================
    // Proof Fingerprint Consumption
    //
    // This is deliberately GLOBAL.
    //
    // A valid proof created for Network A -> Network B cannot be
    // moved into Network A -> Network C and consumed again.
    // ============================================================

    public fun consume_proof(
        registry: &mut ReplayProtectionRegistry,
        intent_binding: &IntentFinalityBinding,
        proof_fingerprint: vector<u8>,
    ) {

        assert!(
            vector::length(&proof_fingerprint) > 0,
            E_EMPTY_PROOF_FINGERPRINT,
        );

        let fingerprint =
            calculate_raw_replay_fingerprint(
                REPLAY_TYPE_PROOF,
                proof_fingerprint,
            );

        assert!(
            !contains_bytes(
                &registry.consumed_proof_fingerprints,
                &fingerprint,
            ),
            E_PROOF_FINGERPRINT_REPLAY,
        );

        let context_key =
            calculate_context_replay_key(
                intent_binding,
                REPLAY_TYPE_PROOF,
                copy fingerprint,
            );

        assert!(
            !contains_bytes(
                &registry.consumed_context_keys,
                &context_key,
            ),
            E_CONTEXT_REPLAY,
        );

        vector::push_back(
            &mut registry.consumed_proof_fingerprints,
            fingerprint,
        );

        vector::push_back(
            &mut registry.consumed_context_keys,
            context_key,
        );

        registry.total_consumed =
            registry.total_consumed + 1;
    }


    // ============================================================
    // Global Replay Queries
    // ============================================================

    public fun is_external_reference_consumed(
        registry: &ReplayProtectionRegistry,
        external_reference: vector<u8>,
    ): bool {

        if (vector::length(&external_reference) == 0) {
            return false
        };

        let fingerprint =
            calculate_raw_replay_fingerprint(
                REPLAY_TYPE_EXTERNAL_REFERENCE,
                external_reference,
            );

        contains_bytes(
            &registry.consumed_external_references,
            &fingerprint,
        )
    }


    public fun is_confirmation_hash_consumed(
        registry: &ReplayProtectionRegistry,
        confirmation_hash: vector<u8>,
    ): bool {

        if (vector::length(&confirmation_hash) == 0) {
            return false
        };

        let fingerprint =
            calculate_raw_replay_fingerprint(
                REPLAY_TYPE_CONFIRMATION_HASH,
                confirmation_hash,
            );

        contains_bytes(
            &registry.consumed_confirmation_hashes,
            &fingerprint,
        )
    }


    public fun is_proof_consumed(
        registry: &ReplayProtectionRegistry,
        proof_fingerprint: vector<u8>,
    ): bool {

        if (vector::length(&proof_fingerprint) == 0) {
            return false
        };

        let fingerprint =
            calculate_raw_replay_fingerprint(
                REPLAY_TYPE_PROOF,
                proof_fingerprint,
            );

        contains_bytes(
            &registry.consumed_proof_fingerprints,
            &fingerprint,
        )
    }


    // ============================================================
    // Context Replay Query
    // ============================================================

    public fun is_context_consumed(
        registry: &ReplayProtectionRegistry,
        intent_binding: &IntentFinalityBinding,
        replay_type: u8,
        raw_value: vector<u8>,
    ): bool {

        assert_valid_replay_type(replay_type);

        let fingerprint =
            calculate_raw_replay_fingerprint(
                replay_type,
                raw_value,
            );

        let context_key =
            calculate_context_replay_key(
                intent_binding,
                replay_type,
                fingerprint,
            );

        contains_bytes(
            &registry.consumed_context_keys,
            &context_key,
        )
    }


    // ============================================================
    // Registry Accessors
    // ============================================================

    public fun replay_total_consumed(
        registry: &ReplayProtectionRegistry,
    ): u64 {
        registry.total_consumed
    }


    public fun replay_registry_version(
        registry: &ReplayProtectionRegistry,
    ): u64 {
        registry.version
    }


    public fun external_reference_count(
        registry: &ReplayProtectionRegistry,
    ): u64 {
        vector::length(
            &registry.consumed_external_references,
        )
    }


    public fun confirmation_hash_count(
        registry: &ReplayProtectionRegistry,
    ): u64 {
        vector::length(
            &registry.consumed_confirmation_hashes,
        )
    }


    public fun proof_fingerprint_count(
        registry: &ReplayProtectionRegistry,
    ): u64 {
        vector::length(
            &registry.consumed_proof_fingerprints,
        )
    }


    public fun context_replay_count(
        registry: &ReplayProtectionRegistry,
    ): u64 {
        vector::length(
            &registry.consumed_context_keys,
        )
    }


    // ============================================================
    // Test-only object cleanup
    // ============================================================

    #[test_only]
    public fun destroy_replay_registry_for_testing(
        registry: ReplayProtectionRegistry,
    ) {
        let ReplayProtectionRegistry {
            id,
            consumed_external_references: _,
            consumed_confirmation_hashes: _,
            consumed_proof_fingerprints: _,
            consumed_context_keys: _,
            total_consumed: _,
            version: _,
        } = registry;

        sui::object::delete(id);
    }


    // ============================================================
    // Source 2-B
    // Terminal / Finality Enforcement
    // ============================================================

    const E_TERMINAL_RECORD_BINDING_MISMATCH: u64 = 1205030;
    const E_TERMINAL_INTENT_BINDING_MISMATCH: u64 = 1205031;
    const E_FINALITY_NOT_PENDING: u64 = 1205032;
    const E_FINALITY_NOT_CONFIRMED: u64 = 1205033;
    const E_TERMINAL_RECORD_ALREADY_EXECUTED: u64 = 1205034;
    const E_TERMINAL_RECORD_ALREADY_TERMINAL: u64 = 1205035;

    const FINALITY_PENDING: u8 = 0;
    const FINALITY_CONFIRMED: u8 = 1;
    const FINALITY_REJECTED: u8 = 2;
    const FINALITY_EXPIRED: u8 = 3;
    const FINALITY_EXECUTED: u8 = 4;


    // ============================================================
    // Terminal Finality Record
    //
    // The record is permanently bound to:
    //
    //   network/domain binding hash
    //   intent/finality binding hash
    //
    // It therefore cannot migrate to another network, domain,
    // direction, intent, or finality record.
    // ============================================================

    public struct TerminalFinalityRecord has drop, store {
        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,
        status: u8,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_terminal_finality_record(
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ): TerminalFinalityRecord {

        assert!(
            intent_binding.binding_hash == binding.binding_hash,
            E_TERMINAL_RECORD_BINDING_MISMATCH,
        );

        TerminalFinalityRecord {
            binding_hash: copy binding.binding_hash,
            intent_finality_hash:
                copy intent_binding.intent_finality_hash,
            status: FINALITY_PENDING,
        }
    }


    // ============================================================
    // Binding Verification
    // ============================================================

    public fun assert_terminal_record_binding(
        record: &TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert!(
            record.binding_hash == binding.binding_hash,
            E_TERMINAL_RECORD_BINDING_MISMATCH,
        );

        assert!(
            intent_binding.binding_hash == binding.binding_hash,
            E_TERMINAL_RECORD_BINDING_MISMATCH,
        );

        assert!(
            record.intent_finality_hash
                == intent_binding.intent_finality_hash,
            E_TERMINAL_INTENT_BINDING_MISMATCH,
        );
    }


    // ============================================================
    // Terminal State Detection
    // ============================================================

    public fun is_terminal(
        record: &TerminalFinalityRecord,
    ): bool {

        record.status == FINALITY_REJECTED
            || record.status == FINALITY_EXPIRED
            || record.status == FINALITY_EXECUTED
    }


    public fun is_confirmed(
        record: &TerminalFinalityRecord,
    ): bool {
        record.status == FINALITY_CONFIRMED
    }


    public fun is_executed(
        record: &TerminalFinalityRecord,
    ): bool {
        record.status == FINALITY_EXECUTED
    }


    // ============================================================
    // Confirm
    // ============================================================

    public fun mark_finality_confirmed(
        record: &mut TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert_terminal_record_binding(
            record,
            binding,
            intent_binding,
        );

        assert!(
            record.status == FINALITY_PENDING,
            E_FINALITY_NOT_PENDING,
        );

        record.status = FINALITY_CONFIRMED;
    }


    // ============================================================
    // Reject
    // ============================================================

    public fun mark_finality_rejected(
        record: &mut TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert_terminal_record_binding(
            record,
            binding,
            intent_binding,
        );

        assert!(
            record.status == FINALITY_PENDING,
            E_FINALITY_NOT_PENDING,
        );

        record.status = FINALITY_REJECTED;
    }


    // ============================================================
    // Expire
    // ============================================================

    public fun mark_finality_expired(
        record: &mut TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert_terminal_record_binding(
            record,
            binding,
            intent_binding,
        );

        assert!(
            record.status == FINALITY_PENDING,
            E_FINALITY_NOT_PENDING,
        );

        record.status = FINALITY_EXPIRED;
    }


    // ============================================================
    // Execution Guard
    //
    // Only CONFIRMED records may execute.
    //
    // Before execution:
    //
    // 1. network/domain binding must match
    // 2. intent/finality binding must match
    // 3. record must be CONFIRMED
    // 4. EXECUTED can never execute again
    // ============================================================

    public fun assert_finality_executable(
        record: &TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert_terminal_record_binding(
            record,
            binding,
            intent_binding,
        );

        assert!(
            record.status != FINALITY_EXECUTED,
            E_TERMINAL_RECORD_ALREADY_EXECUTED,
        );

        assert!(
            record.status != FINALITY_REJECTED
                && record.status != FINALITY_EXPIRED,
            E_TERMINAL_RECORD_ALREADY_TERMINAL,
        );

        assert!(
            record.status == FINALITY_CONFIRMED,
            E_FINALITY_NOT_CONFIRMED,
        );
    }


    // ============================================================
    // Execute Once
    //
    // Successful execution atomically changes:
    //
    // CONFIRMED -> EXECUTED
    //
    // Any later attempt is rejected.
    // ============================================================

    public fun mark_finality_executed(
        record: &mut TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert_finality_executable(
            record,
            binding,
            intent_binding,
        );

        record.status = FINALITY_EXECUTED;
    }


    // ============================================================
    // Combined Security Guard
    //
    // This guard is intended for execution paths that also consume
    // replay-protected external reference / confirmation / proof.
    // ============================================================

    public fun assert_execution_context(
        record: &TerminalFinalityRecord,
        binding: &CrossNetworkBinding,
        intent_binding: &IntentFinalityBinding,
    ) {

        assert_binding(
            binding,
            &binding.source_network_id,
            &binding.source_domain,
            &binding.destination_network_id,
            &binding.destination_domain,
        );

        assert_intent_finality_binding(
            binding,
            intent_binding,
            &intent_binding.intent_id,
            &intent_binding.finality_record_id,
        );

        assert_finality_executable(
            record,
            binding,
            intent_binding,
        );
    }


    // ============================================================
    // Status Accessors
    // ============================================================

    public fun finality_status(
        record: &TerminalFinalityRecord,
    ): u8 {
        record.status
    }


    public fun finality_pending_status(): u8 {
        FINALITY_PENDING
    }


    public fun finality_confirmed_status(): u8 {
        FINALITY_CONFIRMED
    }


    public fun finality_rejected_status(): u8 {
        FINALITY_REJECTED
    }


    public fun finality_expired_status(): u8 {
        FINALITY_EXPIRED
    }


    public fun finality_executed_status(): u8 {
        FINALITY_EXECUTED
    }
}
