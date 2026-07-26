module tobmate_core::cross_network_recovery_control {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_core::cross_network_execution_receipt;


    // ============================================================
    // Error Codes
    // ============================================================

    const E_EMPTY_REASON: u64 = 1207001;
    const E_ZERO_REQUESTED_AMOUNT: u64 = 1207002;

    const E_CASE_NOT_OPEN: u64 = 1207003;
    const E_CASE_NOT_UNDER_REVIEW: u64 = 1207004;

    const E_CASE_ALREADY_TERMINAL: u64 = 1207005;
    const E_CASE_EXECUTION_MISMATCH: u64 = 1207006;
    const E_CASE_BINDING_MISMATCH: u64 = 1207007;
    const E_CASE_INTENT_MISMATCH: u64 = 1207008;


    // ============================================================
    // Recovery Case Status
    // ============================================================

    const CASE_OPEN: u8 = 0;
    const CASE_UNDER_REVIEW: u8 = 1;
    const CASE_APPROVED: u8 = 2;
    const CASE_REJECTED: u8 = 3;
    const CASE_CANCELLED: u8 = 4;


    // ============================================================
    // Case ID Material
    //
    // A dispute/recovery case is deterministically anchored to:
    //
    // execution_id
    // network/domain binding
    // intent/finality
    // reason
    // requested amount
    // case sequence
    // opened epoch
    // ============================================================

    public struct RecoveryCaseIdMaterial has drop, store {
        execution_id: vector<u8>,
        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,

        reason_code: vector<u8>,
        requested_amount: u64,

        sequence: u64,
        opened_epoch: u64,
    }


    // ============================================================
    // Recovery Case
    // ============================================================

    public struct RecoveryCase has key, store {
        id: object::UID,

        case_id: vector<u8>,

        execution_id: vector<u8>,
        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,

        reason_code: vector<u8>,
        requested_amount: u64,

        sequence: u64,
        opened_epoch: u64,

        status: u8,
    }


    // ============================================================
    // Recovery Case Registry
    // ============================================================

    public struct RecoveryCaseRegistry has key, store {
        id: object::UID,

        total_cases: u64,
        next_sequence: u64,
        version: u64,
    }


    // ============================================================
    // Registry Constructor
    // ============================================================

    public fun new_recovery_case_registry(
        ctx: &mut tx_context::TxContext,
    ): RecoveryCaseRegistry {

        RecoveryCaseRegistry {
            id: object::new(ctx),
            total_cases: 0,
            next_sequence: 1,
            version: 1,
        }
    }


    // ============================================================
    // Deterministic Case ID
    // ============================================================

    public fun calculate_case_id(
        execution_id: vector<u8>,
        binding_hash: vector<u8>,
        intent_finality_hash: vector<u8>,
        reason_code: vector<u8>,
        requested_amount: u64,
        sequence: u64,
        opened_epoch: u64,
    ): vector<u8> {

        let material = RecoveryCaseIdMaterial {
            execution_id,
            binding_hash,
            intent_finality_hash,
            reason_code,
            requested_amount,
            sequence,
            opened_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Open Recovery Case
    //
    // Recovery may only originate from a real ExecutionReceipt.
    // No receipt -> no recovery case.
    // ============================================================

    public fun open_recovery_case(
        registry: &mut RecoveryCaseRegistry,
        receipt: &cross_network_execution_receipt::ExecutionReceipt,
        reason_code: vector<u8>,
        requested_amount: u64,
        ctx: &mut tx_context::TxContext,
    ): RecoveryCase {

        assert!(
            vector::length(&reason_code) > 0,
            E_EMPTY_REASON,
        );

        assert!(
            requested_amount > 0,
            E_ZERO_REQUESTED_AMOUNT,
        );

        let execution_id_ref =
            cross_network_execution_receipt::execution_id(
                receipt,
            );

        let execution_id =
            *execution_id_ref;

        let binding_hash_ref =
            cross_network_execution_receipt::receipt_binding_hash(
                receipt,
            );

        let binding_hash =
            *binding_hash_ref;

        let intent_hash_ref =
            cross_network_execution_receipt::
                receipt_intent_finality_hash(
                    receipt,
                );

        let intent_finality_hash =
            *intent_hash_ref;

        let sequence =
            registry.next_sequence;

        let opened_epoch =
            tx_context::epoch(ctx);

        let case_id =
            calculate_case_id(
                copy execution_id,
                copy binding_hash,
                copy intent_finality_hash,
                copy reason_code,
                requested_amount,
                sequence,
                opened_epoch,
            );

        registry.total_cases =
            registry.total_cases + 1;

        registry.next_sequence =
            registry.next_sequence + 1;

        RecoveryCase {
            id: object::new(ctx),

            case_id,

            execution_id,
            binding_hash,
            intent_finality_hash,

            reason_code,
            requested_amount,

            sequence,
            opened_epoch,

            status: CASE_OPEN,
        }
    }


    // ============================================================
    // Receipt ↔ Recovery Case Binding
    // ============================================================

    public fun assert_case_receipt_binding(
        case: &RecoveryCase,
        receipt: &cross_network_execution_receipt::ExecutionReceipt,
    ) {

        let execution_id_ref =
            cross_network_execution_receipt::execution_id(
                receipt,
            );

        assert!(
            &case.execution_id == execution_id_ref,
            E_CASE_EXECUTION_MISMATCH,
        );

        let binding_hash_ref =
            cross_network_execution_receipt::receipt_binding_hash(
                receipt,
            );

        assert!(
            &case.binding_hash == binding_hash_ref,
            E_CASE_BINDING_MISMATCH,
        );

        let intent_hash_ref =
            cross_network_execution_receipt::
                receipt_intent_finality_hash(
                    receipt,
                );

        assert!(
            &case.intent_finality_hash == intent_hash_ref,
            E_CASE_INTENT_MISMATCH,
        );
    }


    // ============================================================
    // Terminal Case Detection
    // ============================================================

    public fun is_case_terminal(
        case: &RecoveryCase,
    ): bool {

        case.status == CASE_APPROVED
            || case.status == CASE_REJECTED
            || case.status == CASE_CANCELLED
    }


    // ============================================================
    // OPEN -> UNDER_REVIEW
    // ============================================================

    public fun begin_case_review(
        case: &mut RecoveryCase,
        receipt: &cross_network_execution_receipt::ExecutionReceipt,
    ) {

        assert_case_receipt_binding(
            case,
            receipt,
        );

        assert!(
            case.status == CASE_OPEN,
            E_CASE_NOT_OPEN,
        );

        case.status = CASE_UNDER_REVIEW;
    }


    // ============================================================
    // UNDER_REVIEW -> APPROVED
    // ============================================================

    public fun approve_recovery_case(
        case: &mut RecoveryCase,
        receipt: &cross_network_execution_receipt::ExecutionReceipt,
    ) {

        assert_case_receipt_binding(
            case,
            receipt,
        );

        assert!(
            !is_case_terminal(case),
            E_CASE_ALREADY_TERMINAL,
        );

        assert!(
            case.status == CASE_UNDER_REVIEW,
            E_CASE_NOT_UNDER_REVIEW,
        );

        case.status = CASE_APPROVED;
    }


    // ============================================================
    // UNDER_REVIEW -> REJECTED
    // ============================================================

    public fun reject_recovery_case(
        case: &mut RecoveryCase,
        receipt: &cross_network_execution_receipt::ExecutionReceipt,
    ) {

        assert_case_receipt_binding(
            case,
            receipt,
        );

        assert!(
            !is_case_terminal(case),
            E_CASE_ALREADY_TERMINAL,
        );

        assert!(
            case.status == CASE_UNDER_REVIEW,
            E_CASE_NOT_UNDER_REVIEW,
        );

        case.status = CASE_REJECTED;
    }


    // ============================================================
    // OPEN -> CANCELLED
    //
    // Cancellation is only permitted before formal review begins.
    // ============================================================

    public fun cancel_recovery_case(
        case: &mut RecoveryCase,
        receipt: &cross_network_execution_receipt::ExecutionReceipt,
    ) {

        assert_case_receipt_binding(
            case,
            receipt,
        );

        assert!(
            !is_case_terminal(case),
            E_CASE_ALREADY_TERMINAL,
        );

        assert!(
            case.status == CASE_OPEN,
            E_CASE_NOT_OPEN,
        );

        case.status = CASE_CANCELLED;
    }


    // ============================================================
    // Read Accessors
    // ============================================================

    public fun case_id(
        case: &RecoveryCase,
    ): &vector<u8> {
        &case.case_id
    }


    public fun case_execution_id(
        case: &RecoveryCase,
    ): &vector<u8> {
        &case.execution_id
    }


    public fun case_binding_hash(
        case: &RecoveryCase,
    ): &vector<u8> {
        &case.binding_hash
    }


    public fun case_intent_finality_hash(
        case: &RecoveryCase,
    ): &vector<u8> {
        &case.intent_finality_hash
    }


    public fun case_reason_code(
        case: &RecoveryCase,
    ): &vector<u8> {
        &case.reason_code
    }


    public fun case_requested_amount(
        case: &RecoveryCase,
    ): u64 {
        case.requested_amount
    }


    public fun case_sequence(
        case: &RecoveryCase,
    ): u64 {
        case.sequence
    }


    public fun case_opened_epoch(
        case: &RecoveryCase,
    ): u64 {
        case.opened_epoch
    }


    public fun case_status(
        case: &RecoveryCase,
    ): u8 {
        case.status
    }


    public fun case_open_status(): u8 {
        CASE_OPEN
    }


    public fun case_under_review_status(): u8 {
        CASE_UNDER_REVIEW
    }


    public fun case_approved_status(): u8 {
        CASE_APPROVED
    }


    public fun case_rejected_status(): u8 {
        CASE_REJECTED
    }


    public fun case_cancelled_status(): u8 {
        CASE_CANCELLED
    }


    public fun recovery_total_cases(
        registry: &RecoveryCaseRegistry,
    ): u64 {
        registry.total_cases
    }


    public fun recovery_next_sequence(
        registry: &RecoveryCaseRegistry,
    ): u64 {
        registry.next_sequence
    }


    // ============================================================
    // Test-only cleanup
    // ============================================================

    #[test_only]
    public fun destroy_recovery_case_for_testing(
        case: RecoveryCase,
    ) {

        let RecoveryCase {
            id,
            case_id: _,
            execution_id: _,
            binding_hash: _,
            intent_finality_hash: _,
            reason_code: _,
            requested_amount: _,
            sequence: _,
            opened_epoch: _,
            status: _,
        } = case;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_recovery_registry_for_testing(
        registry: RecoveryCaseRegistry,
    ) {

        let RecoveryCaseRegistry {
            id,
            total_cases: _,
            next_sequence: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
