module tobmate_enterprise_security::cross_network_incident_closure_governance {

    use sui::bcs;
    use sui::hash;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    use tobmate_enterprise_security::cross_network_security_orchestrator;


    // ============================================================
    // Errors
    // ============================================================

    const E_NOT_VERIFIED: u64 = 1207601;
    const E_ALREADY_FINALIZED: u64 = 1207602;
    const E_INVALID_CASE_SEQUENCE: u64 = 1207603;
    const E_INVALID_SNAPSHOT_SEQUENCE: u64 = 1207604;
    const E_EMPTY_AUDIT_DIGEST: u64 = 1207605;
    const E_CLOSURE_ID_MISMATCH: u64 = 1207606;
    const E_PAUSED: u64 = 1207607;
    const E_INVALID_VERSION: u64 = 1207608;


    // ============================================================
    // Status
    // ============================================================

    const STATUS_OPEN: u8 = 0;
    const STATUS_FINALIZED: u8 = 1;

    const PROTOCOL_VERSION: u64 = 1;


    // ============================================================
    // Deterministic Closure Material
    // ============================================================

    public struct ClosureIdMaterial has drop, store {
        case_sequence: u64,
        snapshot_sequence: u64,
        audit_digest: vector<u8>,
        closure_sequence: u64,
        finalized_epoch: u64,
    }


    // ============================================================
    // Closure Governance State
    // ============================================================

    public struct IncidentClosureGovernance has key, store {
        id: UID,

        protocol_version: u64,
        version: u64,
        paused: bool,

        closure_sequence: u64,
        total_finalized: u64,

        last_case_sequence: u64,
        last_snapshot_sequence: u64,
        last_closure_id: vector<u8>,
    }


    // ============================================================
    // Immutable Closure Receipt
    // ============================================================

    public struct IncidentClosureReceipt has key, store {
        id: UID,

        closure_id: vector<u8>,

        case_sequence: u64,
        snapshot_sequence: u64,
        audit_digest: vector<u8>,

        closure_sequence: u64,
        finalized_epoch: u64,

        status: u8,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_governance(
        ctx: &mut TxContext,
    ): IncidentClosureGovernance {

        IncidentClosureGovernance {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            version: 1,
            paused: false,

            closure_sequence: 0,
            total_finalized: 0,

            last_case_sequence: 0,
            last_snapshot_sequence: 0,
            last_closure_id: vector[],
        }
    }


    // ============================================================
    // Deterministic Closure ID
    // ============================================================

    public fun calculate_closure_id(
        case_sequence: u64,
        snapshot_sequence: u64,
        audit_digest: vector<u8>,
        closure_sequence: u64,
        finalized_epoch: u64,
    ): vector<u8> {

        let material =
            ClosureIdMaterial {
                case_sequence,
                snapshot_sequence,
                audit_digest,
                closure_sequence,
                finalized_epoch,
            };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Finalize Incident Closure Evidence
    // ============================================================

    public fun finalize_closure(
        governance: &mut IncidentClosureGovernance,

        orchestration:
            &cross_network_security_orchestrator::
                SecurityOrchestrationState,

        audit_digest: vector<u8>,

        ctx: &mut TxContext,
    ): IncidentClosureReceipt {

        assert!(
            !governance.paused,
            E_PAUSED,
        );

        assert!(
            cross_network_security_orchestrator::
                status(orchestration)
                ==
            cross_network_security_orchestrator::
                status_verified(),
            E_NOT_VERIFIED,
        );

        assert!(
            cross_network_security_orchestrator::
                post_incident_verified(orchestration),
            E_NOT_VERIFIED,
        );

        let case_sequence =
            cross_network_security_orchestrator::
                case_sequence(orchestration);

        let snapshot_sequence =
            cross_network_security_orchestrator::
                last_snapshot_sequence(orchestration);

        assert!(
            case_sequence > 0,
            E_INVALID_CASE_SEQUENCE,
        );

        assert!(
            snapshot_sequence > 0,
            E_INVALID_SNAPSHOT_SEQUENCE,
        );

        assert!(
            vector::length(&audit_digest) > 0,
            E_EMPTY_AUDIT_DIGEST,
        );

        assert!(
            case_sequence > governance.last_case_sequence,
            E_ALREADY_FINALIZED,
        );

        governance.closure_sequence =
            governance.closure_sequence + 1;

        let closure_sequence =
            governance.closure_sequence;

        let finalized_epoch =
            tx_context::epoch(ctx);

        let closure_id =
            calculate_closure_id(
                case_sequence,
                snapshot_sequence,
                copy audit_digest,
                closure_sequence,
                finalized_epoch,
            );

        governance.total_finalized =
            governance.total_finalized + 1;

        governance.last_case_sequence =
            case_sequence;

        governance.last_snapshot_sequence =
            snapshot_sequence;

        governance.last_closure_id =
            copy closure_id;

        IncidentClosureReceipt {
            id: object::new(ctx),

            closure_id,

            case_sequence,
            snapshot_sequence,
            audit_digest,

            closure_sequence,
            finalized_epoch,

            status: STATUS_FINALIZED,
        }
    }


    // ============================================================
    // Receipt Verification
    // ============================================================

    public fun verify_receipt(
        receipt: &IncidentClosureReceipt,
    ) {

        let expected =
            calculate_closure_id(
                receipt.case_sequence,
                receipt.snapshot_sequence,
                copy receipt.audit_digest,
                receipt.closure_sequence,
                receipt.finalized_epoch,
            );

        assert!(
            expected == receipt.closure_id,
            E_CLOSURE_ID_MISMATCH,
        );

        assert!(
            receipt.status == STATUS_FINALIZED,
            E_CLOSURE_ID_MISMATCH,
        );
    }


    // ============================================================
    // Governance Controls
    // ============================================================

    public fun set_paused(
        governance: &mut IncidentClosureGovernance,
        paused: bool,
    ) {
        governance.paused = paused;
    }

    public fun upgrade_version(
        governance: &mut IncidentClosureGovernance,
        new_version: u64,
    ) {
        assert!(
            new_version > governance.version,
            E_INVALID_VERSION,
        );

        governance.version = new_version;
    }


    // ============================================================
    // Governance Getters
    // ============================================================

    public fun protocol_version(
        governance: &IncidentClosureGovernance,
    ): u64 {
        governance.protocol_version
    }

    public fun version(
        governance: &IncidentClosureGovernance,
    ): u64 {
        governance.version
    }

    public fun paused(
        governance: &IncidentClosureGovernance,
    ): bool {
        governance.paused
    }

    public fun closure_sequence(
        governance: &IncidentClosureGovernance,
    ): u64 {
        governance.closure_sequence
    }

    public fun total_finalized(
        governance: &IncidentClosureGovernance,
    ): u64 {
        governance.total_finalized
    }

    public fun last_case_sequence(
        governance: &IncidentClosureGovernance,
    ): u64 {
        governance.last_case_sequence
    }

    public fun last_snapshot_sequence(
        governance: &IncidentClosureGovernance,
    ): u64 {
        governance.last_snapshot_sequence
    }

    public fun last_closure_id(
        governance: &IncidentClosureGovernance,
    ): &vector<u8> {
        &governance.last_closure_id
    }


    // ============================================================
    // Receipt Getters
    // ============================================================

    public fun closure_id(
        receipt: &IncidentClosureReceipt,
    ): &vector<u8> {
        &receipt.closure_id
    }

    public fun receipt_case_sequence(
        receipt: &IncidentClosureReceipt,
    ): u64 {
        receipt.case_sequence
    }

    public fun receipt_snapshot_sequence(
        receipt: &IncidentClosureReceipt,
    ): u64 {
        receipt.snapshot_sequence
    }

    public fun receipt_audit_digest(
        receipt: &IncidentClosureReceipt,
    ): &vector<u8> {
        &receipt.audit_digest
    }

    public fun receipt_closure_sequence(
        receipt: &IncidentClosureReceipt,
    ): u64 {
        receipt.closure_sequence
    }

    public fun finalized_epoch(
        receipt: &IncidentClosureReceipt,
    ): u64 {
        receipt.finalized_epoch
    }

    public fun receipt_status(
        receipt: &IncidentClosureReceipt,
    ): u8 {
        receipt.status
    }

    public fun status_open(): u8 {
        STATUS_OPEN
    }

    public fun status_finalized(): u8 {
        STATUS_FINALIZED
    }


    // ============================================================
    // Test Helpers
    // ============================================================

    #[test_only]
    public fun destroy_governance_for_testing(
        governance: IncidentClosureGovernance,
    ) {
        let IncidentClosureGovernance {
            id,

            protocol_version: _,
            version: _,
            paused: _,

            closure_sequence: _,
            total_finalized: _,

            last_case_sequence: _,
            last_snapshot_sequence: _,
            last_closure_id: _,
        } = governance;

        id.delete();
    }

    #[test_only]
    public fun destroy_receipt_for_testing(
        receipt: IncidentClosureReceipt,
    ) {
        let IncidentClosureReceipt {
            id,

            closure_id: _,

            case_sequence: _,
            snapshot_sequence: _,
            audit_digest: _,

            closure_sequence: _,
            finalized_epoch: _,

            status: _,
        } = receipt;

        id.delete();
    }

    #[test_only]
    public fun tamper_closure_id_for_testing(
        receipt: &mut IncidentClosureReceipt,
        closure_id: vector<u8>,
    ) {
        receipt.closure_id = closure_id;
    }
}
