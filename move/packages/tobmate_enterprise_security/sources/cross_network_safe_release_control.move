module tobmate_enterprise_security::cross_network_safe_release_control {

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    use tobmate_enterprise_security::cross_network_security_response_policy;
    use tobmate_enterprise_security::cross_network_security_snapshot;
    use tobmate_enterprise_security::cross_network_incident_containment;

    const PROTOCOL_VERSION: u64 = 1;

    // ============================================================
    // Errors
    // ============================================================

    const E_NOT_RECOVERY_ELIGIBLE: u64 = 1;
    const E_STALE_DECISION: u64 = 2;
    const E_NO_ACTIVE_CONTAINMENT: u64 = 3;
    const E_RECOVERY_PAUSED: u64 = 4;
    const E_INVALID_VERSION: u64 = 5;

    // ============================================================
    // Recovery Actions
    //
    // Release order:
    // execution -> network -> domain -> operator
    // ============================================================

    const RECOVERY_NONE: u8 = 0;
    const RECOVERY_EXECUTION_RESUME: u8 = 1;
    const RECOVERY_NETWORK_RELEASE: u8 = 2;
    const RECOVERY_DOMAIN_RELEASE: u8 = 3;
    const RECOVERY_OPERATOR_RELEASE: u8 = 4;

    public struct RecoveryState has key, store {
        id: UID,

        protocol_version: u64,
        version: u64,
        paused: bool,

        last_snapshot_sequence: u64,

        recovery_count: u64,
        execution_resume_count: u64,
        network_release_count: u64,
        domain_release_count: u64,
        operator_release_count: u64,
    }

    public struct RecoveryReceipt has key, store {
        id: UID,

        protocol_version: u64,

        snapshot_sequence: u64,
        response_policy_version: u64,

        action: u8,

        recovery_count_after: u64,
    }

    public fun new_state(
        ctx: &mut TxContext,
    ): RecoveryState {

        RecoveryState {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            version: 1,
            paused: false,

            last_snapshot_sequence: 0,

            recovery_count: 0,
            execution_resume_count: 0,
            network_release_count: 0,
            domain_release_count: 0,
            operator_release_count: 0,
        }
    }

    // ============================================================
    // Select next safest release action
    // ============================================================

    fun next_recovery_action(
        containment:
            &cross_network_incident_containment::
                ContainmentState,
    ): u8 {

        if (
            cross_network_incident_containment::
                execution_paused(containment)
        ) {
            RECOVERY_EXECUTION_RESUME

        } else if (
            cross_network_incident_containment::
                network_quarantined(containment)
        ) {
            RECOVERY_NETWORK_RELEASE

        } else if (
            cross_network_incident_containment::
                domain_quarantined(containment)
        ) {
            RECOVERY_DOMAIN_RELEASE

        } else if (
            cross_network_incident_containment::
                operator_quarantined(containment)
        ) {
            RECOVERY_OPERATOR_RELEASE

        } else {
            RECOVERY_NONE
        }
    }

    // ============================================================
    // Execute one recovery step
    // ============================================================

    public fun execute_next_release(
        recovery: &mut RecoveryState,

        containment:
            &mut cross_network_incident_containment::
                ContainmentState,

        decision:
            &cross_network_security_response_policy::
                ResponseDecision,

        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        ctx: &mut TxContext,
    ): RecoveryReceipt {

        assert!(
            !recovery.paused,
            E_RECOVERY_PAUSED,
        );

        let snapshot_sequence =
            cross_network_security_snapshot::
                snapshot_sequence(snapshot);

        assert!(
            snapshot_sequence >
                recovery.last_snapshot_sequence,
            E_STALE_DECISION,
        );

        assert!(
            snapshot_sequence >
                cross_network_incident_containment::
                    last_snapshot_sequence(containment),
            E_STALE_DECISION,
        );

        assert!(
            cross_network_security_response_policy::
                decision_snapshot_sequence(decision)
                == snapshot_sequence,
            E_STALE_DECISION,
        );

        assert!(
            cross_network_security_response_policy::
                recovery_eligible(decision),
            E_NOT_RECOVERY_ELIGIBLE,
        );

        let action =
            next_recovery_action(containment);

        assert!(
            action != RECOVERY_NONE,
            E_NO_ACTIVE_CONTAINMENT,
        );

        if (action == RECOVERY_EXECUTION_RESUME) {

            cross_network_incident_containment::
                release_execution_pause(containment);

            recovery.execution_resume_count =
                recovery.execution_resume_count + 1;

        } else if (action == RECOVERY_NETWORK_RELEASE) {

            cross_network_incident_containment::
                release_network_quarantine(containment);

            recovery.network_release_count =
                recovery.network_release_count + 1;

        } else if (action == RECOVERY_DOMAIN_RELEASE) {

            cross_network_incident_containment::
                release_domain_quarantine(containment);

            recovery.domain_release_count =
                recovery.domain_release_count + 1;

        } else if (action == RECOVERY_OPERATOR_RELEASE) {

            cross_network_incident_containment::
                release_operator_quarantine(containment);

            recovery.operator_release_count =
                recovery.operator_release_count + 1;
        };

        recovery.recovery_count =
            recovery.recovery_count + 1;

        recovery.last_snapshot_sequence =
            snapshot_sequence;

        RecoveryReceipt {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,

            snapshot_sequence,

            response_policy_version:
                cross_network_security_response_policy::
                    decision_policy_version(decision),

            action,

            recovery_count_after:
                recovery.recovery_count,
        }
    }

    // ============================================================
    // Administration
    // ============================================================

    public fun set_paused(
        recovery: &mut RecoveryState,
        paused: bool,
    ) {
        recovery.paused = paused;
    }

    public fun set_version(
        recovery: &mut RecoveryState,
        new_version: u64,
    ) {
        assert!(
            new_version > recovery.version,
            E_INVALID_VERSION,
        );

        recovery.version = new_version;
    }

    // ============================================================
    // Getters
    // ============================================================

    public fun protocol_version(
        recovery: &RecoveryState,
    ): u64 {
        recovery.protocol_version
    }

    public fun version(
        recovery: &RecoveryState,
    ): u64 {
        recovery.version
    }

    public fun is_paused(
        recovery: &RecoveryState,
    ): bool {
        recovery.paused
    }

    public fun last_snapshot_sequence(
        recovery: &RecoveryState,
    ): u64 {
        recovery.last_snapshot_sequence
    }

    public fun recovery_count(
        recovery: &RecoveryState,
    ): u64 {
        recovery.recovery_count
    }

    public fun execution_resume_count(
        recovery: &RecoveryState,
    ): u64 {
        recovery.execution_resume_count
    }

    public(package) fun network_release_count(
        recovery: &RecoveryState,
    ): u64 {
        recovery.network_release_count
    }

    public(package) fun domain_release_count(
        recovery: &RecoveryState,
    ): u64 {
        recovery.domain_release_count
    }

    public fun operator_release_count(
        recovery: &RecoveryState,
    ): u64 {
        recovery.operator_release_count
    }

    public fun recovery_none(): u8 {
        RECOVERY_NONE
    }

    public fun recovery_execution_resume(): u8 {
        RECOVERY_EXECUTION_RESUME
    }

    public fun recovery_network_release(): u8 {
        RECOVERY_NETWORK_RELEASE
    }

    public fun recovery_domain_release(): u8 {
        RECOVERY_DOMAIN_RELEASE
    }

    public fun recovery_operator_release(): u8 {
        RECOVERY_OPERATOR_RELEASE
    }

    public fun receipt_snapshot_sequence(
        receipt: &RecoveryReceipt,
    ): u64 {
        receipt.snapshot_sequence
    }

    public fun receipt_policy_version(
        receipt: &RecoveryReceipt,
    ): u64 {
        receipt.response_policy_version
    }

    public fun receipt_action(
        receipt: &RecoveryReceipt,
    ): u8 {
        receipt.action
    }

    public fun receipt_recovery_count_after(
        receipt: &RecoveryReceipt,
    ): u64 {
        receipt.recovery_count_after
    }

    // ============================================================
    // Testing
    // ============================================================

    #[test_only]
    public fun set_last_snapshot_sequence_for_testing(
        recovery: &mut RecoveryState,
        sequence: u64,
    ) {
        recovery.last_snapshot_sequence = sequence;
    }

    #[test_only]
    public fun assert_fresh_sequence_for_testing(
        recovery: &RecoveryState,
        containment:
            &cross_network_incident_containment::
                ContainmentState,
        sequence: u64,
    ) {
        assert!(
            sequence > recovery.last_snapshot_sequence,
            E_STALE_DECISION,
        );

        assert!(
            sequence >
                cross_network_incident_containment::
                    last_snapshot_sequence(containment),
            E_STALE_DECISION,
        );
    }

    #[test_only]
    public fun new_state_for_testing(
        ctx: &mut TxContext,
    ): RecoveryState {
        new_state(ctx)
    }

    #[test_only]
    public fun destroy_state_for_testing(
        recovery: RecoveryState,
    ) {
        let RecoveryState {
            id,

            protocol_version: _,
            version: _,
            paused: _,

            last_snapshot_sequence: _,

            recovery_count: _,
            execution_resume_count: _,
            network_release_count: _,
            domain_release_count: _,
            operator_release_count: _,
        } = recovery;

        object::delete(id);
    }

    #[test_only]
    public fun destroy_receipt_for_testing(
        receipt: RecoveryReceipt,
    ) {
        let RecoveryReceipt {
            id,

            protocol_version: _,

            snapshot_sequence: _,
            response_policy_version: _,

            action: _,

            recovery_count_after: _,
        } = receipt;

        object::delete(id);
    }
}
