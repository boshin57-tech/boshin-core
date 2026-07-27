module tobmate_core::cross_network_incident_containment {

    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    use tobmate_core::cross_network_security_response_policy;

    // ============================================================
    // Protocol
    // ============================================================

    const PROTOCOL_VERSION: u64 = 1;

    // ============================================================
    // Errors
    // ============================================================

    const E_DECISION_NOT_ELIGIBLE: u64 = 1;
    const E_DUPLICATE_CONTAINMENT: u64 = 2;
    const E_STALE_DECISION: u64 = 3;
    const E_INVALID_SCOPE: u64 = 4;
    const E_EXECUTOR_PAUSED: u64 = 5;
    const E_INVALID_VERSION: u64 = 6;

    // ============================================================
    // Scope Types
    // ============================================================

    const SCOPE_NONE: u8 = 0;
    const SCOPE_OPERATOR: u8 = 1;
    const SCOPE_DOMAIN: u8 = 2;
    const SCOPE_NETWORK: u8 = 3;
    const SCOPE_EXECUTION: u8 = 4;

    // ============================================================
    // Containment State
    // ============================================================

    public struct ContainmentState has key, store {
        id: UID,

        protocol_version: u64,
        version: u64,
        paused: bool,

        last_snapshot_sequence: u64,

        operator_quarantined: bool,
        domain_quarantined: bool,
        network_quarantined: bool,
        execution_paused: bool,

        operator_id: vector<u8>,
        domain_id: vector<u8>,
        network_id: vector<u8>,

        containment_count: u64,
        escalation_count: u64,
    }

    // ============================================================
    // Containment Receipt
    // ============================================================

    public struct ContainmentReceipt has key, store {
        id: UID,

        protocol_version: u64,

        snapshot_sequence: u64,
        policy_version: u64,

        action: u8,
        scope_type: u8,

        operator_id: vector<u8>,
        domain_id: vector<u8>,
        network_id: vector<u8>,

        containment_count_after: u64,
        escalation_count_after: u64,
    }

    // ============================================================
    // Construction
    // ============================================================

    public fun new_state(
        ctx: &mut TxContext,
    ): ContainmentState {

        ContainmentState {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            version: 1,
            paused: false,

            last_snapshot_sequence: 0,

            operator_quarantined: false,
            domain_quarantined: false,
            network_quarantined: false,
            execution_paused: false,

            operator_id: vector[],
            domain_id: vector[],
            network_id: vector[],

            containment_count: 0,
            escalation_count: 0,
        }
    }

    // ============================================================
    // Internal Helpers
    // ============================================================

    fun assert_fresh_decision(
        state: &ContainmentState,
        decision:
            &cross_network_security_response_policy::
                ResponseDecision,
    ) {
        let snapshot_sequence =
            cross_network_security_response_policy::
                decision_snapshot_sequence(decision);

        assert!(
            snapshot_sequence > state.last_snapshot_sequence,
            E_STALE_DECISION,
        );
    }

    fun action_to_scope(
        action: u8,
    ): u8 {

        if (
            action ==
                cross_network_security_response_policy::
                    action_quarantine_operator()
        ) {
            SCOPE_OPERATOR

        } else if (
            action ==
                cross_network_security_response_policy::
                    action_quarantine_domain()
        ) {
            SCOPE_DOMAIN

        } else if (
            action ==
                cross_network_security_response_policy::
                    action_quarantine_network()
        ) {
            SCOPE_NETWORK

        } else if (
            action ==
                cross_network_security_response_policy::
                    action_pause_execution()
        ) {
            SCOPE_EXECUTION

        } else {
            SCOPE_NONE
        }
    }

    // ============================================================
    // Execute Containment
    // ============================================================

    public fun execute(
        state: &mut ContainmentState,

        decision:
            &cross_network_security_response_policy::
                ResponseDecision,

        operator_id: vector<u8>,
        domain_id: vector<u8>,
        network_id: vector<u8>,

        ctx: &mut TxContext,
    ): ContainmentReceipt {

        assert!(!state.paused, E_EXECUTOR_PAUSED);

        assert_fresh_decision(
            state,
            decision,
        );

        let action =
            cross_network_security_response_policy::
                decision_action(decision);

        let snapshot_sequence =
            cross_network_security_response_policy::
                decision_snapshot_sequence(decision);

        let policy_version =
            cross_network_security_response_policy::
                decision_policy_version(decision);

        let scope_type =
            action_to_scope(action);

        assert!(
            scope_type != SCOPE_NONE,
            E_DECISION_NOT_ELIGIBLE,
        );

        if (scope_type == SCOPE_OPERATOR) {

            assert!(
                cross_network_security_response_policy::
                    operator_quarantine_eligible(decision),
                E_DECISION_NOT_ELIGIBLE,
            );

            assert!(
                !state.operator_quarantined,
                E_DUPLICATE_CONTAINMENT,
            );

            state.operator_quarantined = true;
            state.operator_id = operator_id;

        } else if (scope_type == SCOPE_DOMAIN) {

            assert!(
                cross_network_security_response_policy::
                    domain_quarantine_eligible(decision),
                E_DECISION_NOT_ELIGIBLE,
            );

            assert!(
                !state.domain_quarantined,
                E_DUPLICATE_CONTAINMENT,
            );

            state.domain_quarantined = true;
            state.domain_id = domain_id;

        } else if (scope_type == SCOPE_NETWORK) {

            assert!(
                cross_network_security_response_policy::
                    network_quarantine_eligible(decision),
                E_DECISION_NOT_ELIGIBLE,
            );

            assert!(
                !state.network_quarantined,
                E_DUPLICATE_CONTAINMENT,
            );

            state.network_quarantined = true;
            state.network_id = network_id;

        } else if (scope_type == SCOPE_EXECUTION) {

            assert!(
                cross_network_security_response_policy::
                    execution_pause_eligible(decision),
                E_DECISION_NOT_ELIGIBLE,
            );

            assert!(
                !state.execution_paused,
                E_DUPLICATE_CONTAINMENT,
            );

            state.execution_paused = true;

        } else {
            abort E_INVALID_SCOPE
        };

        let previous_count =
            state.containment_count;

        state.containment_count =
            state.containment_count + 1;

        if (previous_count > 0) {
            state.escalation_count =
                state.escalation_count + 1;
        };

        state.last_snapshot_sequence =
            snapshot_sequence;

        ContainmentReceipt {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,

            snapshot_sequence,
            policy_version,

            action,
            scope_type,

            operator_id,
            domain_id,
            network_id,

            containment_count_after:
                state.containment_count,

            escalation_count_after:
                state.escalation_count,
        }
    }

    // ============================================================
    // State Administration
    // ============================================================

    public fun set_paused(
        state: &mut ContainmentState,
        paused: bool,
    ) {
        state.paused = paused;
    }

    public fun set_version(
        state: &mut ContainmentState,
        new_version: u64,
    ) {
        assert!(
            new_version > state.version,
            E_INVALID_VERSION,
        );

        state.version = new_version;
    }

    // ============================================================
    // State Getters
    // ============================================================

    public fun protocol_version(
        state: &ContainmentState,
    ): u64 {
        state.protocol_version
    }

    public fun version(
        state: &ContainmentState,
    ): u64 {
        state.version
    }

    public fun is_paused(
        state: &ContainmentState,
    ): bool {
        state.paused
    }

    public fun last_snapshot_sequence(
        state: &ContainmentState,
    ): u64 {
        state.last_snapshot_sequence
    }

    public fun operator_quarantined(
        state: &ContainmentState,
    ): bool {
        state.operator_quarantined
    }

    public fun domain_quarantined(
        state: &ContainmentState,
    ): bool {
        state.domain_quarantined
    }

    public fun network_quarantined(
        state: &ContainmentState,
    ): bool {
        state.network_quarantined
    }

    public fun execution_paused(
        state: &ContainmentState,
    ): bool {
        state.execution_paused
    }

    public fun operator_id(
        state: &ContainmentState,
    ): &vector<u8> {
        &state.operator_id
    }

    public fun domain_id(
        state: &ContainmentState,
    ): &vector<u8> {
        &state.domain_id
    }

    public fun network_id(
        state: &ContainmentState,
    ): &vector<u8> {
        &state.network_id
    }

    public fun containment_count(
        state: &ContainmentState,
    ): u64 {
        state.containment_count
    }

    public fun escalation_count(
        state: &ContainmentState,
    ): u64 {
        state.escalation_count
    }

    // ============================================================
    // Scope Getters
    // ============================================================

    public fun scope_none(): u8 {
        SCOPE_NONE
    }

    public fun scope_operator(): u8 {
        SCOPE_OPERATOR
    }

    public fun scope_domain(): u8 {
        SCOPE_DOMAIN
    }

    public fun scope_network(): u8 {
        SCOPE_NETWORK
    }

    public fun scope_execution(): u8 {
        SCOPE_EXECUTION
    }

    // ============================================================
    // Receipt Getters
    // ============================================================

    public fun receipt_snapshot_sequence(
        receipt: &ContainmentReceipt,
    ): u64 {
        receipt.snapshot_sequence
    }

    public fun receipt_policy_version(
        receipt: &ContainmentReceipt,
    ): u64 {
        receipt.policy_version
    }

    public fun receipt_action(
        receipt: &ContainmentReceipt,
    ): u8 {
        receipt.action
    }

    public fun receipt_scope_type(
        receipt: &ContainmentReceipt,
    ): u8 {
        receipt.scope_type
    }

    public fun receipt_containment_count_after(
        receipt: &ContainmentReceipt,
    ): u64 {
        receipt.containment_count_after
    }

    public fun receipt_escalation_count_after(
        receipt: &ContainmentReceipt,
    ): u64 {
        receipt.escalation_count_after
    }

    // ============================================================
    // Test Helpers
    // ============================================================

    #[test_only]
    public fun set_execution_paused_for_testing(
        state: &mut ContainmentState,
        paused: bool,
    ) {
        state.execution_paused = paused;
    }

    #[test_only]
    public fun set_network_quarantined_for_testing(
        state: &mut ContainmentState,
        network_id: vector<u8>,
    ) {
        state.network_quarantined = true;
        state.network_id = network_id;
    }

    #[test_only]
    public fun set_domain_quarantined_for_testing(
        state: &mut ContainmentState,
        domain_id: vector<u8>,
    ) {
        state.domain_quarantined = true;
        state.domain_id = domain_id;
    }

    #[test_only]
    public fun set_operator_quarantined_for_testing(
        state: &mut ContainmentState,
        operator_id: vector<u8>,
    ) {
        state.operator_quarantined = true;
        state.operator_id = operator_id;
    }

    #[test_only]
    public fun set_last_snapshot_sequence_for_testing(
        state: &mut ContainmentState,
        sequence: u64,
    ) {
        state.last_snapshot_sequence = sequence;
    }

    #[test_only]
    public fun new_state_for_testing(
        ctx: &mut TxContext,
    ): ContainmentState {
        new_state(ctx)
    }

    #[test_only]
    public fun destroy_state_for_testing(
        state: ContainmentState,
    ) {
        let ContainmentState {
            id,

            protocol_version: _,
            version: _,
            paused: _,

            last_snapshot_sequence: _,

            operator_quarantined: _,
            domain_quarantined: _,
            network_quarantined: _,
            execution_paused: _,

            operator_id: _,
            domain_id: _,
            network_id: _,

            containment_count: _,
            escalation_count: _,
        } = state;

        object::delete(id);
    }

    #[test_only]
    public fun destroy_receipt_for_testing(
        receipt: ContainmentReceipt,
    ) {
        let ContainmentReceipt {
            id,

            protocol_version: _,

            snapshot_sequence: _,
            policy_version: _,

            action: _,
            scope_type: _,

            operator_id: _,
            domain_id: _,
            network_id: _,

            containment_count_after: _,
            escalation_count_after: _,
        } = receipt;

        object::delete(id);
    }


    // ============================================================
    // Package Recovery Hooks
    //
    // Only package modules may release containment.
    // Public callers cannot directly clear containment state.
    // ============================================================

    public(package) fun release_execution_pause(
        state: &mut ContainmentState,
    ) {
        state.execution_paused = false;
    }

    public(package) fun release_network_quarantine(
        state: &mut ContainmentState,
    ) {
        state.network_quarantined = false;
        state.network_id = vector[];
    }

    public(package) fun release_domain_quarantine(
        state: &mut ContainmentState,
    ) {
        state.domain_quarantined = false;
        state.domain_id = vector[];
    }

    public(package) fun release_operator_quarantine(
        state: &mut ContainmentState,
    ) {
        state.operator_quarantined = false;
        state.operator_id = vector[];
    }
}
