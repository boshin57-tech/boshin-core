module tobmate_enterprise_security::cross_network_security_orchestrator {

    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    use tobmate_enterprise_security::cross_network_security_snapshot;
    use tobmate_enterprise_security::cross_network_security_response_policy;
    use tobmate_enterprise_security::cross_network_incident_containment;

    const PROTOCOL_VERSION: u64 = 1;

    // ============================================================
    // Errors
    // ============================================================

    const E_NO_ACTIVE_CONTAINMENT: u64 = 1;
    const E_STALE_SNAPSHOT: u64 = 2;
    const E_CASE_ALREADY_OPEN: u64 = 3;
    const E_NO_OPEN_CASE: u64 = 4;
    const E_NOT_AUTHORIZED: u64 = 5;
    const E_REMEDIATION_NOT_COMPLETE: u64 = 6;
    const E_ALREADY_CLOSED: u64 = 7;
    const E_INVALID_VERSION: u64 = 8;

    // ============================================================
    // Lifecycle Status
    // ============================================================

    const STATUS_NONE: u8 = 0;
    const STATUS_OPEN: u8 = 1;
    const STATUS_AUTHORIZED: u8 = 2;
    const STATUS_REMEDIATING: u8 = 3;
    const STATUS_REMEDIATED: u8 = 4;
    const STATUS_RECOVERING: u8 = 5;
    const STATUS_VERIFIED: u8 = 6;
    const STATUS_CLOSED: u8 = 7;

    // ============================================================
    // Orchestration State
    // ============================================================

    public struct SecurityOrchestrationState has key, store {
        id: UID,

        protocol_version: u64,
        version: u64,
        paused: bool,

        status: u8,

        case_sequence: u64,
        source_snapshot_sequence: u64,
        last_snapshot_sequence: u64,

        recovery_case_id: vector<u8>,
        authorization_id: vector<u8>,
        remediation_id: vector<u8>,

        containment_required: bool,
        authorization_complete: bool,
        remediation_complete: bool,
        recovery_started: bool,
        post_incident_verified: bool,
        closure_evidence_confirmed: bool,
        closure_id: vector<u8>,

        open_count: u64,
        authorization_count: u64,
        remediation_count: u64,
        recovery_count: u64,
        verification_count: u64,
        close_count: u64,
    }

    public fun new_state(
        ctx: &mut TxContext,
    ): SecurityOrchestrationState {

        SecurityOrchestrationState {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            version: 1,
            paused: false,

            status: STATUS_NONE,

            case_sequence: 0,
            source_snapshot_sequence: 0,
            last_snapshot_sequence: 0,

            recovery_case_id: vector[],
            authorization_id: vector[],
            remediation_id: vector[],

            containment_required: false,
            authorization_complete: false,
            remediation_complete: false,
            recovery_started: false,
            post_incident_verified: false,
            closure_evidence_confirmed: false,
            closure_id: vector[],

            open_count: 0,
            authorization_count: 0,
            remediation_count: 0,
            recovery_count: 0,
            verification_count: 0,
            close_count: 0,
        }
    }

    // ============================================================
    // Active Containment Check
    // ============================================================

    fun has_active_containment(
        containment:
            &cross_network_incident_containment::
                ContainmentState,
    ): bool {

        cross_network_incident_containment::
            execution_paused(containment)
        ||
        cross_network_incident_containment::
            network_quarantined(containment)
        ||
        cross_network_incident_containment::
            domain_quarantined(containment)
        ||
        cross_network_incident_containment::
            operator_quarantined(containment)
    }

    // ============================================================
    // Open Security Recovery Case
    // ============================================================

    public fun open_case(
        state: &mut SecurityOrchestrationState,

        containment:
            &cross_network_incident_containment::
                ContainmentState,

        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        recovery_case_id: vector<u8>,
    ) {

        assert!(
            state.status == STATUS_NONE
                || state.status == STATUS_CLOSED,
            E_CASE_ALREADY_OPEN,
        );

        assert!(
            has_active_containment(containment),
            E_NO_ACTIVE_CONTAINMENT,
        );

        let snapshot_sequence =
            cross_network_security_snapshot::
                snapshot_sequence(snapshot);

        assert!(
            snapshot_sequence > state.last_snapshot_sequence,
            E_STALE_SNAPSHOT,
        );

        state.case_sequence =
            state.case_sequence + 1;

        state.source_snapshot_sequence =
            snapshot_sequence;

        state.last_snapshot_sequence =
            snapshot_sequence;

        state.recovery_case_id =
            recovery_case_id;

        state.authorization_id = vector[];
        state.remediation_id = vector[];

        state.containment_required = true;
        state.authorization_complete = false;
        state.remediation_complete = false;
        state.recovery_started = false;
        state.post_incident_verified = false;
        state.closure_evidence_confirmed = false;
        state.closure_id = vector[];

        state.status = STATUS_OPEN;

        state.open_count =
            state.open_count + 1;
    }

    // ============================================================
    // Authorization Binding
    // ============================================================

    public fun mark_authorized(
        state: &mut SecurityOrchestrationState,
        authorization_id: vector<u8>,
    ) {

        assert!(
            state.status == STATUS_OPEN,
            E_NO_OPEN_CASE,
        );

        state.authorization_id =
            authorization_id;

        state.authorization_complete = true;
        state.status = STATUS_AUTHORIZED;

        state.authorization_count =
            state.authorization_count + 1;
    }

    // ============================================================
    // Remediation Lifecycle
    // ============================================================

    public fun begin_remediation(
        state: &mut SecurityOrchestrationState,
        remediation_id: vector<u8>,
    ) {

        assert!(
            state.authorization_complete,
            E_NOT_AUTHORIZED,
        );

        state.remediation_id =
            remediation_id;

        state.status = STATUS_REMEDIATING;
    }

    public fun complete_remediation(
        state: &mut SecurityOrchestrationState,
    ) {

        assert!(
            state.status == STATUS_REMEDIATING,
            E_NOT_AUTHORIZED,
        );

        state.remediation_complete = true;
        state.status = STATUS_REMEDIATED;

        state.remediation_count =
            state.remediation_count + 1;
    }

    // ============================================================
    // Recovery Start
    // ============================================================

    public fun begin_recovery(
        state: &mut SecurityOrchestrationState,
    ) {

        assert!(
            state.remediation_complete,
            E_REMEDIATION_NOT_COMPLETE,
        );

        state.recovery_started = true;
        state.status = STATUS_RECOVERING;

        state.recovery_count =
            state.recovery_count + 1;
    }

    // ============================================================
    // Post-Incident Verification
    // ============================================================

    public fun verify_post_incident(
        state: &mut SecurityOrchestrationState,

        containment:
            &cross_network_incident_containment::
                ContainmentState,

        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        decision:
            &cross_network_security_response_policy::
                ResponseDecision,
    ) {

        assert!(
            state.recovery_started,
            E_REMEDIATION_NOT_COMPLETE,
        );

        let snapshot_sequence =
            cross_network_security_snapshot::
                snapshot_sequence(snapshot);

        assert!(
            snapshot_sequence > state.last_snapshot_sequence,
            E_STALE_SNAPSHOT,
        );

        assert!(
            cross_network_security_response_policy::
                decision_snapshot_sequence(decision)
                == snapshot_sequence,
            E_STALE_SNAPSHOT,
        );

        assert!(
            cross_network_security_response_policy::
                recovery_eligible(decision),
            E_NOT_AUTHORIZED,
        );

        assert!(
            !has_active_containment(containment),
            E_NO_ACTIVE_CONTAINMENT,
        );

        state.last_snapshot_sequence =
            snapshot_sequence;

        state.post_incident_verified = true;
        state.status = STATUS_VERIFIED;

        state.verification_count =
            state.verification_count + 1;
    }

    // ============================================================
    // Close Case
    // ============================================================

    public fun close_case(
        state: &mut SecurityOrchestrationState,
    ) {

        assert!(
            state.status != STATUS_CLOSED,
            E_ALREADY_CLOSED,
        );

        assert!(
            state.post_incident_verified,
            E_REMEDIATION_NOT_COMPLETE,
        );

        assert!(
            state.closure_evidence_confirmed,
            E_REMEDIATION_NOT_COMPLETE,
        );

        assert!(
            vector::length(&state.closure_id) > 0,
            E_REMEDIATION_NOT_COMPLETE,
        );

        state.status = STATUS_CLOSED;

        state.close_count =
            state.close_count + 1;
    }

    // ============================================================
    // Closure Evidence Confirmation
    // ============================================================

    public(package) fun confirm_closure_evidence(
        state: &mut SecurityOrchestrationState,
        closure_id: vector<u8>,
    ) {
        assert!(
            state.status == STATUS_VERIFIED,
            E_REMEDIATION_NOT_COMPLETE,
        );

        assert!(
            state.post_incident_verified,
            E_REMEDIATION_NOT_COMPLETE,
        );

        assert!(
            !state.closure_evidence_confirmed,
            E_ALREADY_CLOSED,
        );

        state.closure_evidence_confirmed = true;
        state.closure_id = closure_id;
    }


    // ============================================================
    // External Evidence Binding
    // ============================================================

    public(package) fun bind_recovery_case_id(
        state: &mut SecurityOrchestrationState,
        recovery_case_id: vector<u8>,
    ) {
        assert!(
            state.status == STATUS_OPEN,
            E_NO_OPEN_CASE,
        );

        state.recovery_case_id =
            recovery_case_id;
    }

    public(package) fun bind_authorization_id(
        state: &mut SecurityOrchestrationState,
        authorization_id: vector<u8>,
    ) {
        assert!(
            state.status == STATUS_OPEN,
            E_NO_OPEN_CASE,
        );

        state.authorization_id =
            authorization_id;
    }

    public(package) fun confirm_authorization_consumed(
        state: &mut SecurityOrchestrationState,
    ) {
        assert!(
            state.status == STATUS_OPEN,
            E_NO_OPEN_CASE,
        );

        state.authorization_complete = true;
        state.status = STATUS_AUTHORIZED;

        state.authorization_count =
            state.authorization_count + 1;
    }

    public(package) fun bind_remediation_id(
        state: &mut SecurityOrchestrationState,
        remediation_id: vector<u8>,
    ) {
        assert!(
            state.authorization_complete,
            E_NOT_AUTHORIZED,
        );

        state.remediation_id =
            remediation_id;

        // Binding a RemediationRecord proves the remediation
        // instruction exists, but does NOT prove execution.
        state.remediation_complete = false;
        state.status = STATUS_REMEDIATING;
    }

    public(package) fun confirm_remediation_execution(
        state: &mut SecurityOrchestrationState,
    ) {
        assert!(
            state.status == STATUS_REMEDIATING,
            E_NOT_AUTHORIZED,
        );

        state.remediation_complete = true;
        state.status = STATUS_REMEDIATED;

        state.remediation_count =
            state.remediation_count + 1;
    }


    // ============================================================
    // Administration
    // ============================================================

    public fun set_paused(
        state: &mut SecurityOrchestrationState,
        paused: bool,
    ) {
        state.paused = paused;
    }

    public fun set_version(
        state: &mut SecurityOrchestrationState,
        new_version: u64,
    ) {
        assert!(
            new_version > state.version,
            E_INVALID_VERSION,
        );

        state.version = new_version;
    }

    // ============================================================
    // Getters
    // ============================================================

    public fun status(
        state: &SecurityOrchestrationState,
    ): u8 {
        state.status
    }

    public fun case_sequence(
        state: &SecurityOrchestrationState,
    ): u64 {
        state.case_sequence
    }

    public fun source_snapshot_sequence(
        state: &SecurityOrchestrationState,
    ): u64 {
        state.source_snapshot_sequence
    }

    public fun last_snapshot_sequence(
        state: &SecurityOrchestrationState,
    ): u64 {
        state.last_snapshot_sequence
    }

    public fun authorization_complete(
        state: &SecurityOrchestrationState,
    ): bool {
        state.authorization_complete
    }

    public fun remediation_complete(
        state: &SecurityOrchestrationState,
    ): bool {
        state.remediation_complete
    }

    public fun recovery_started(
        state: &SecurityOrchestrationState,
    ): bool {
        state.recovery_started
    }

    public fun post_incident_verified(
        state: &SecurityOrchestrationState,
    ): bool {
        state.post_incident_verified
    }

    public fun open_count(
        state: &SecurityOrchestrationState,
    ): u64 {
        state.open_count
    }

    public fun close_count(
        state: &SecurityOrchestrationState,
    ): u64 {
        state.close_count
    }

    public fun closure_evidence_confirmed(
        state: &SecurityOrchestrationState,
    ): bool {
        state.closure_evidence_confirmed
    }

    public fun closure_id(
        state: &SecurityOrchestrationState,
    ): &vector<u8> {
        &state.closure_id
    }


    public fun status_none(): u8 { STATUS_NONE }
    public fun status_open(): u8 { STATUS_OPEN }
    public fun status_authorized(): u8 { STATUS_AUTHORIZED }
    public fun status_remediating(): u8 { STATUS_REMEDIATING }
    public fun status_remediated(): u8 { STATUS_REMEDIATED }
    public fun status_recovering(): u8 { STATUS_RECOVERING }
    public fun status_verified(): u8 { STATUS_VERIFIED }
    public fun status_closed(): u8 { STATUS_CLOSED }

    // ============================================================
    // Test Helpers
    // ============================================================

    #[test_only]
    public fun set_open_state_for_testing(
        state: &mut SecurityOrchestrationState,
        snapshot_sequence: u64,
    ) {
        state.status = STATUS_OPEN;
        state.case_sequence = state.case_sequence + 1;
        state.source_snapshot_sequence = snapshot_sequence;
        state.last_snapshot_sequence = snapshot_sequence;
        state.containment_required = true;
        state.authorization_complete = false;
        state.remediation_complete = false;
        state.recovery_started = false;
        state.post_incident_verified = false;
        state.closure_evidence_confirmed = false;
        state.closure_id = vector[];
        state.open_count = state.open_count + 1;
    }

    #[test_only]
    public fun set_verified_state_for_testing(
        state: &mut SecurityOrchestrationState,
        case_sequence: u64,
        snapshot_sequence: u64,
    ) {
        state.status = STATUS_VERIFIED;

        state.case_sequence = case_sequence;
        state.source_snapshot_sequence = snapshot_sequence;
        state.last_snapshot_sequence = snapshot_sequence;

        state.containment_required = false;
        state.authorization_complete = true;
        state.remediation_complete = true;
        state.recovery_started = true;
        state.post_incident_verified = true;
        state.closure_evidence_confirmed = false;
        state.closure_id = vector[];
    }

    #[test_only]
    public fun new_state_for_testing(
        ctx: &mut TxContext,
    ): SecurityOrchestrationState {
        new_state(ctx)
    }

    #[test_only]
    public fun destroy_state_for_testing(
        state: SecurityOrchestrationState,
    ) {
        let SecurityOrchestrationState {
            id,

            protocol_version: _,
            version: _,
            paused: _,

            status: _,

            case_sequence: _,
            source_snapshot_sequence: _,
            last_snapshot_sequence: _,

            recovery_case_id: _,
            authorization_id: _,
            remediation_id: _,

            containment_required: _,
            authorization_complete: _,
            remediation_complete: _,
            recovery_started: _,
            post_incident_verified: _,
            closure_evidence_confirmed: _,
            closure_id: _,

            open_count: _,
            authorization_count: _,
            remediation_count: _,
            recovery_count: _,
            verification_count: _,
            close_count: _,
        } = state;

        object::delete(id);
    }
}
