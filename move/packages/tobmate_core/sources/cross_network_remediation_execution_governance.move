module tobmate_core::cross_network_remediation_execution_governance {

    use std::bcs;
    use sui::hash;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    use tobmate_core::cross_network_remediation;


    // ============================================================
    // Errors
    // ============================================================

    const E_ALREADY_EXECUTING: u64 = 1207401;
    const E_NOT_EXECUTING: u64 = 1207402;
    const E_ALREADY_COMPLETED: u64 = 1207403;
    const E_REMEDIATION_ID_MISMATCH: u64 = 1207404;
    const E_INVALID_AMOUNT: u64 = 1207405;
    const E_EMPTY_EXECUTION_TYPE: u64 = 1207406;
    const E_EXECUTION_TYPE_MISMATCH: u64 = 1207407;
    const E_DUPLICATE_REMEDIATION: u64 = 1207408;
    const E_INVALID_VERSION: u64 = 1207409;
    const E_PAUSED: u64 = 1207410;


    // ============================================================
    // Status
    // ============================================================

    const STATUS_NONE: u8 = 0;
    const STATUS_EXECUTING: u8 = 1;
    const STATUS_COMPLETED: u8 = 2;

    const PROTOCOL_VERSION: u64 = 1;


    // ============================================================
    // Deterministic execution receipt material
    // ============================================================

    public struct RemediationExecutionIdMaterial has drop, store {
        remediation_id: vector<u8>,
        remediation_type: vector<u8>,
        remediation_amount: u64,
        execution_sequence: u64,
        completed_epoch: u64,
    }


    // ============================================================
    // Governance State
    // ============================================================

    public struct RemediationExecutionGovernance has key, store {
        id: UID,

        protocol_version: u64,
        version: u64,
        paused: bool,

        status: u8,

        active_remediation_id: vector<u8>,
        active_remediation_type: vector<u8>,
        active_remediation_amount: u64,

        execution_sequence: u64,

        total_started: u64,
        total_completed: u64,

        last_completed_remediation_id: vector<u8>,
    }


    // ============================================================
    // Immutable Execution Receipt
    // ============================================================

    public struct RemediationExecutionReceipt has key, store {
        id: UID,

        execution_id: vector<u8>,

        remediation_id: vector<u8>,
        remediation_type: vector<u8>,
        remediation_amount: u64,

        execution_sequence: u64,
        completed_epoch: u64,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_governance(
        ctx: &mut TxContext,
    ): RemediationExecutionGovernance {

        RemediationExecutionGovernance {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            version: 1,
            paused: false,

            status: STATUS_NONE,

            active_remediation_id: vector[],
            active_remediation_type: vector[],
            active_remediation_amount: 0,

            execution_sequence: 0,

            total_started: 0,
            total_completed: 0,

            last_completed_remediation_id: vector[],
        }
    }


    // ============================================================
    // Deterministic execution ID
    // ============================================================

    public fun calculate_execution_id(
        remediation_id: vector<u8>,
        remediation_type: vector<u8>,
        remediation_amount: u64,
        execution_sequence: u64,
        completed_epoch: u64,
    ): vector<u8> {

        let material =
            RemediationExecutionIdMaterial {
                remediation_id,
                remediation_type,
                remediation_amount,
                execution_sequence,
                completed_epoch,
            };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Begin remediation execution
    // ============================================================

    public fun begin_execution(
        governance: &mut RemediationExecutionGovernance,
        remediation:
            &cross_network_remediation::RemediationRecord,
        ctx: &mut TxContext,
    ) {

        assert!(
            !governance.paused,
            E_PAUSED,
        );

        assert!(
            governance.status != STATUS_EXECUTING,
            E_ALREADY_EXECUTING,
        );

        assert!(
            governance.status != STATUS_COMPLETED
                ||
            governance.last_completed_remediation_id
                !=
            *cross_network_remediation::
                remediation_id(remediation),
            E_DUPLICATE_REMEDIATION,
        );

        let remediation_amount =
            cross_network_remediation::
                remediation_amount(remediation);

        assert!(
            remediation_amount > 0,
            E_INVALID_AMOUNT,
        );

        let remediation_type =
            *cross_network_remediation::
                remediation_type(remediation);

        assert!(
            vector::length(&remediation_type) > 0,
            E_EMPTY_EXECUTION_TYPE,
        );

        governance.execution_sequence =
            governance.execution_sequence + 1;

        governance.active_remediation_id =
            *cross_network_remediation::
                remediation_id(remediation);

        governance.active_remediation_type =
            remediation_type;

        governance.active_remediation_amount =
            remediation_amount;

        governance.status =
            STATUS_EXECUTING;

        governance.total_started =
            governance.total_started + 1;

        let _epoch = tx_context::epoch(ctx);
    }


    // ============================================================
    // Complete remediation execution
    // ============================================================

    public fun complete_execution(
        governance: &mut RemediationExecutionGovernance,
        remediation:
            &cross_network_remediation::RemediationRecord,
        ctx: &mut TxContext,
    ): RemediationExecutionReceipt {

        assert!(
            !governance.paused,
            E_PAUSED,
        );

        assert!(
            governance.status == STATUS_EXECUTING,
            E_NOT_EXECUTING,
        );

        let remediation_id =
            *cross_network_remediation::
                remediation_id(remediation);

        assert!(
            governance.active_remediation_id
                == remediation_id,
            E_REMEDIATION_ID_MISMATCH,
        );

        let remediation_type =
            *cross_network_remediation::
                remediation_type(remediation);

        assert!(
            governance.active_remediation_type
                == remediation_type,
            E_EXECUTION_TYPE_MISMATCH,
        );

        let remediation_amount =
            cross_network_remediation::
                remediation_amount(remediation);

        assert!(
            governance.active_remediation_amount
                == remediation_amount,
            E_INVALID_AMOUNT,
        );

        let completed_epoch =
            tx_context::epoch(ctx);

        let execution_id =
            calculate_execution_id(
                copy remediation_id,
                copy remediation_type,
                remediation_amount,
                governance.execution_sequence,
                completed_epoch,
            );

        governance.status =
            STATUS_COMPLETED;

        governance.total_completed =
            governance.total_completed + 1;

        governance.last_completed_remediation_id =
            copy remediation_id;

        RemediationExecutionReceipt {
            id: object::new(ctx),

            execution_id,

            remediation_id,
            remediation_type,
            remediation_amount,

            execution_sequence:
                governance.execution_sequence,

            completed_epoch,
        }
    }


    // ============================================================
    // Receipt validation
    // ============================================================

    public fun assert_execution_binding(
        receipt: &RemediationExecutionReceipt,
        remediation:
            &cross_network_remediation::RemediationRecord,
    ) {

        assert!(
            &receipt.remediation_id
                ==
            cross_network_remediation::
                remediation_id(remediation),
            E_REMEDIATION_ID_MISMATCH,
        );

        assert!(
            &receipt.remediation_type
                ==
            cross_network_remediation::
                remediation_type(remediation),
            E_EXECUTION_TYPE_MISMATCH,
        );

        assert!(
            receipt.remediation_amount
                ==
            cross_network_remediation::
                remediation_amount(remediation),
            E_INVALID_AMOUNT,
        );
    }


    // ============================================================
    // Administrative controls
    // ============================================================

    public fun set_paused(
        governance: &mut RemediationExecutionGovernance,
        paused: bool,
    ) {
        governance.paused = paused;
    }


    public fun set_version(
        governance: &mut RemediationExecutionGovernance,
        version: u64,
    ) {

        assert!(
            version > governance.version,
            E_INVALID_VERSION,
        );

        governance.version = version;
    }


    // ============================================================
    // Governance accessors
    // ============================================================

    public fun status(
        governance: &RemediationExecutionGovernance,
    ): u8 {
        governance.status
    }


    public fun execution_sequence(
        governance: &RemediationExecutionGovernance,
    ): u64 {
        governance.execution_sequence
    }


    public fun total_started(
        governance: &RemediationExecutionGovernance,
    ): u64 {
        governance.total_started
    }


    public fun total_completed(
        governance: &RemediationExecutionGovernance,
    ): u64 {
        governance.total_completed
    }


    public fun paused(
        governance: &RemediationExecutionGovernance,
    ): bool {
        governance.paused
    }


    public fun status_none(): u8 {
        STATUS_NONE
    }


    public fun status_executing(): u8 {
        STATUS_EXECUTING
    }


    public fun status_completed(): u8 {
        STATUS_COMPLETED
    }


    // ============================================================
    // Receipt accessors
    // ============================================================

    public fun receipt_execution_id(
        receipt: &RemediationExecutionReceipt,
    ): &vector<u8> {
        &receipt.execution_id
    }


    public fun receipt_remediation_id(
        receipt: &RemediationExecutionReceipt,
    ): &vector<u8> {
        &receipt.remediation_id
    }


    public fun receipt_remediation_type(
        receipt: &RemediationExecutionReceipt,
    ): &vector<u8> {
        &receipt.remediation_type
    }


    public fun receipt_remediation_amount(
        receipt: &RemediationExecutionReceipt,
    ): u64 {
        receipt.remediation_amount
    }


    public fun receipt_execution_sequence(
        receipt: &RemediationExecutionReceipt,
    ): u64 {
        receipt.execution_sequence
    }


    public fun receipt_completed_epoch(
        receipt: &RemediationExecutionReceipt,
    ): u64 {
        receipt.completed_epoch
    }


    // ============================================================
    // Test cleanup
    // ============================================================

    #[test_only]
    public fun destroy_governance_for_testing(
        governance: RemediationExecutionGovernance,
    ) {

        let RemediationExecutionGovernance {
            id,
            protocol_version: _,
            version: _,
            paused: _,
            status: _,
            active_remediation_id: _,
            active_remediation_type: _,
            active_remediation_amount: _,
            execution_sequence: _,
            total_started: _,
            total_completed: _,
            last_completed_remediation_id: _,
        } = governance;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_receipt_for_testing(
        receipt: RemediationExecutionReceipt,
    ) {

        let RemediationExecutionReceipt {
            id,
            execution_id: _,
            remediation_id: _,
            remediation_type: _,
            remediation_amount: _,
            execution_sequence: _,
            completed_epoch: _,
        } = receipt;

        object::delete(id);
    }
}
