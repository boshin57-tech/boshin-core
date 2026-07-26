module tobmate_core::cross_network_execution_receipt {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_guard;


    // ============================================================
    // Errors
    // ============================================================

    const E_RECEIPT_BINDING_MISMATCH: u64 = 1206001;
    const E_RECEIPT_INTENT_MISMATCH: u64 = 1206002;
    const E_RECEIPT_EXECUTION_ID_MISMATCH: u64 = 1206003;
    const E_RECEIPT_NOT_EXECUTED: u64 = 1206004;
    const E_RECEIPT_SEQUENCE_MISMATCH: u64 = 1206005;


    // ============================================================
    // Domain-separated audit digest material
    // ============================================================

    public struct AuditDigestMaterial has drop, store {
        digest_type: u8,
        value: vector<u8>,
    }


    // ============================================================
    // Deterministic execution-id material
    // ============================================================

    public struct ExecutionIdMaterial has drop, store {
        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,

        external_reference_digest: vector<u8>,
        confirmation_digest: vector<u8>,
        proof_digest: vector<u8>,

        sequence: u64,
        executed_epoch: u64,
    }


    // ============================================================
    // Immutable execution evidence
    // ============================================================

    public struct ExecutionReceipt has key, store {
        id: object::UID,

        execution_id: vector<u8>,

        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,

        external_reference_digest: vector<u8>,
        confirmation_digest: vector<u8>,
        proof_digest: vector<u8>,

        sequence: u64,
        executed_epoch: u64,
    }


    // ============================================================
    // Digest helpers
    //
    // Types:
    // 1 = external reference
    // 2 = confirmation hash
    // 3 = proof fingerprint
    // ============================================================

    fun audit_digest(
        digest_type: u8,
        value: vector<u8>,
    ): vector<u8> {

        let material = AuditDigestMaterial {
            digest_type,
            value,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    public fun external_reference_digest(
        value: vector<u8>,
    ): vector<u8> {
        audit_digest(1, value)
    }


    public fun confirmation_digest(
        value: vector<u8>,
    ): vector<u8> {
        audit_digest(2, value)
    }


    public fun proof_digest(
        value: vector<u8>,
    ): vector<u8> {
        audit_digest(3, value)
    }


    // ============================================================
    // Execution ID
    // ============================================================

    public fun calculate_execution_id(
        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,
        external_reference_digest: vector<u8>,
        confirmation_digest: vector<u8>,
        proof_digest: vector<u8>,
        sequence: u64,
        executed_epoch: u64,
    ): vector<u8> {

        let material = ExecutionIdMaterial {
            binding_hash,
            intent_finality_hash,
            external_reference_digest,
            confirmation_digest,
            proof_digest,
            sequence,
            executed_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Atomic Execute and Anchor
    //
    // Receipt can only be created after execute_once succeeds.
    //
    // If replay/finality/network validation aborts,
    // receipt creation never occurs and all mutations roll back.
    // ============================================================

    public fun execute_and_anchor(
        registry:
            &mut cross_network_security::ReplayProtectionRegistry,

        record:
            &mut cross_network_security::TerminalFinalityRecord,

        binding:
            &cross_network_security::CrossNetworkBinding,

        intent_binding:
            &cross_network_security::IntentFinalityBinding,

        external_reference: vector<u8>,
        confirmation_hash: vector<u8>,
        proof_fingerprint: vector<u8>,

        sequence: u64,
        ctx: &mut tx_context::TxContext,
    ): ExecutionReceipt {

        // Preserve independent audit copies.
        let external_copy = copy external_reference;
        let confirmation_copy = copy confirmation_hash;
        let proof_copy = copy proof_fingerprint;

        // Actual protected execution.
        cross_network_execution_guard::execute_once(
            registry,
            record,
            binding,
            intent_binding,
            external_reference,
            confirmation_hash,
            proof_fingerprint,
        );

        // Execution must now be terminal EXECUTED.
        assert!(
            cross_network_security::is_executed(record),
            E_RECEIPT_NOT_EXECUTED,
        );

        let external_digest =
            external_reference_digest(external_copy);

        let confirmation_digest_value =
            confirmation_digest(confirmation_copy);

        let proof_digest_value =
            proof_digest(proof_copy);

        // Accessors return references.
        // Copy through named local references.
        let binding_hash_ref =
            cross_network_security::binding_hash(binding);

        let binding_hash =
            *binding_hash_ref;

        let intent_hash_ref =
            cross_network_security::intent_finality_hash(
                intent_binding,
            );

        let intent_finality_hash =
            *intent_hash_ref;

        let executed_epoch =
            tx_context::epoch(ctx);

        let execution_id =
            calculate_execution_id(
                copy binding_hash,
                copy intent_finality_hash,
                copy external_digest,
                copy confirmation_digest_value,
                copy proof_digest_value,
                sequence,
                executed_epoch,
            );

        ExecutionReceipt {
            id: object::new(ctx),

            execution_id,

            binding_hash,
            intent_finality_hash,

            external_reference_digest: external_digest,
            confirmation_digest: confirmation_digest_value,
            proof_digest: proof_digest_value,

            sequence,
            executed_epoch,
        }
    }


    // ============================================================
    // Audit Verification
    //
    // Verifies:
    //
    // receipt ↔ network/domain binding
    // receipt ↔ intent/finality binding
    // receipt ↔ deterministic execution id
    // receipt ↔ executed terminal record
    // ============================================================

    public fun assert_receipt_valid(
        receipt: &ExecutionReceipt,
        record: &cross_network_security::TerminalFinalityRecord,
        binding: &cross_network_security::CrossNetworkBinding,
        intent_binding: &cross_network_security::IntentFinalityBinding,
    ) {

        assert!(
            cross_network_security::is_executed(record),
            E_RECEIPT_NOT_EXECUTED,
        );

        let binding_hash_ref =
            cross_network_security::binding_hash(binding);

        assert!(
            &receipt.binding_hash == binding_hash_ref,
            E_RECEIPT_BINDING_MISMATCH,
        );

        let intent_hash_ref =
            cross_network_security::intent_finality_hash(
                intent_binding,
            );

        assert!(
            &receipt.intent_finality_hash == intent_hash_ref,
            E_RECEIPT_INTENT_MISMATCH,
        );

        let recalculated =
            calculate_execution_id(
                copy receipt.binding_hash,
                copy receipt.intent_finality_hash,
                copy receipt.external_reference_digest,
                copy receipt.confirmation_digest,
                copy receipt.proof_digest,
                receipt.sequence,
                receipt.executed_epoch,
            );

        assert!(
            receipt.execution_id == recalculated,
            E_RECEIPT_EXECUTION_ID_MISMATCH,
        );
    }


    // ============================================================
    // Sequence assertion
    // ============================================================

    public fun assert_receipt_sequence(
        receipt: &ExecutionReceipt,
        expected_sequence: u64,
    ) {

        assert!(
            receipt.sequence == expected_sequence,
            E_RECEIPT_SEQUENCE_MISMATCH,
        );
    }


    // ============================================================
    // Read accessors
    // ============================================================

    public fun execution_id(
        receipt: &ExecutionReceipt,
    ): &vector<u8> {
        &receipt.execution_id
    }


    public fun receipt_binding_hash(
        receipt: &ExecutionReceipt,
    ): &vector<u8> {
        &receipt.binding_hash
    }


    public fun receipt_intent_finality_hash(
        receipt: &ExecutionReceipt,
    ): &vector<u8> {
        &receipt.intent_finality_hash
    }


    public fun receipt_external_reference_digest(
        receipt: &ExecutionReceipt,
    ): &vector<u8> {
        &receipt.external_reference_digest
    }


    public fun receipt_confirmation_digest(
        receipt: &ExecutionReceipt,
    ): &vector<u8> {
        &receipt.confirmation_digest
    }


    public fun receipt_proof_digest(
        receipt: &ExecutionReceipt,
    ): &vector<u8> {
        &receipt.proof_digest
    }


    public fun receipt_sequence(
        receipt: &ExecutionReceipt,
    ): u64 {
        receipt.sequence
    }


    public fun receipt_executed_epoch(
        receipt: &ExecutionReceipt,
    ): u64 {
        receipt.executed_epoch
    }


    // ============================================================
    // Test-only cleanup
    // ============================================================

    #[test_only]
    public fun destroy_receipt_for_testing(
        receipt: ExecutionReceipt,
    ) {

        let ExecutionReceipt {
            id,
            execution_id: _,
            binding_hash: _,
            intent_finality_hash: _,
            external_reference_digest: _,
            confirmation_digest: _,
            proof_digest: _,
            sequence: _,
            executed_epoch: _,
        } = receipt;

        object::delete(id);
    }
}
