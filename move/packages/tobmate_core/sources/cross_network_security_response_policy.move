module tobmate_core::cross_network_security_response_policy {

    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    use tobmate_core::cross_network_security_snapshot;
    use tobmate_core::cross_network_incident_severity;

    // ============================================================
    // Protocol
    // ============================================================

    const PROTOCOL_VERSION: u64 = 1;
    const BPS_DENOMINATOR: u64 = 10_000;

    // ============================================================
    // Errors
    // ============================================================

    const E_INVALID_THRESHOLD: u64 = 1;
    const E_INVALID_THRESHOLD_ORDER: u64 = 2;
    const E_INVALID_REPEAT_THRESHOLD: u64 = 3;
    const E_POLICY_PAUSED: u64 = 4;
    const E_INVALID_VERSION: u64 = 5;

    // ============================================================
    // Response Actions
    // ============================================================

    const ACTION_NONE: u8 = 0;
    const ACTION_MONITOR: u8 = 1;
    const ACTION_RESTRICT: u8 = 2;
    const ACTION_QUARANTINE_OPERATOR: u8 = 3;
    const ACTION_QUARANTINE_DOMAIN: u8 = 4;
    const ACTION_QUARANTINE_NETWORK: u8 = 5;
    const ACTION_PAUSE_EXECUTION: u8 = 6;
    const ACTION_RECOVERY_ELIGIBLE: u8 = 7;

    // ============================================================
    // Response Policy
    //
    // This object determines response eligibility only.
    // It does NOT itself execute containment.
    // ============================================================

    public struct SecurityResponsePolicy has key, store {
        id: UID,

        protocol_version: u64,
        version: u64,
        paused: bool,

        warning_score_threshold_bps: u64,
        critical_score_threshold_bps: u64,

        critical_repeat_threshold: u64,

        allow_operator_quarantine: bool,
        allow_domain_quarantine: bool,
        allow_network_quarantine: bool,
        allow_execution_pause: bool,
        allow_automatic_recovery: bool,
    }

    // ============================================================
    // Deterministic Decision
    // ============================================================

    public struct ResponseDecision has copy, drop, store {
        policy_version: u64,

        snapshot_sequence: u64,

        anomaly_score_bps: u64,
        severity: u8,
        critical_count: u64,

        action: u8,

        operator_quarantine_eligible: bool,
        domain_quarantine_eligible: bool,
        network_quarantine_eligible: bool,
        execution_pause_eligible: bool,
        recovery_eligible: bool,
    }

    // ============================================================
    // Creation
    // ============================================================

    public fun create(
        warning_score_threshold_bps: u64,
        critical_score_threshold_bps: u64,
        critical_repeat_threshold: u64,

        allow_operator_quarantine: bool,
        allow_domain_quarantine: bool,
        allow_network_quarantine: bool,
        allow_execution_pause: bool,
        allow_automatic_recovery: bool,

        ctx: &mut TxContext,
    ): SecurityResponsePolicy {

        assert!(
            warning_score_threshold_bps <= BPS_DENOMINATOR,
            E_INVALID_THRESHOLD,
        );

        assert!(
            critical_score_threshold_bps <= BPS_DENOMINATOR,
            E_INVALID_THRESHOLD,
        );

        assert!(
            warning_score_threshold_bps
                < critical_score_threshold_bps,
            E_INVALID_THRESHOLD_ORDER,
        );

        assert!(
            critical_repeat_threshold > 0,
            E_INVALID_REPEAT_THRESHOLD,
        );

        SecurityResponsePolicy {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            version: 1,
            paused: false,

            warning_score_threshold_bps,
            critical_score_threshold_bps,

            critical_repeat_threshold,

            allow_operator_quarantine,
            allow_domain_quarantine,
            allow_network_quarantine,
            allow_execution_pause,
            allow_automatic_recovery,
        }
    }

    #[test_only]
    public fun new_default_policy_for_testing(
        ctx: &mut TxContext,
    ): SecurityResponsePolicy {

        create(
            2_000,
            7_000,
            2,

            true,
            true,
            true,
            true,
            true,

            ctx,
        )
    }

    // ============================================================
    // Decision Engine
    // ============================================================

    public fun evaluate(
        policy: &SecurityResponsePolicy,
        snapshot:
            &cross_network_security_snapshot::SecuritySnapshot,
    ): ResponseDecision {

        assert!(!policy.paused, E_POLICY_PAUSED);

        let score =
            cross_network_security_snapshot::
                composite_anomaly_score_bps(snapshot);

        let severity =
            cross_network_security_snapshot::
                current_severity(snapshot);

        let critical_count =
            cross_network_security_snapshot::
                incident_critical_count(snapshot);

        let is_critical =
            severity ==
                cross_network_incident_severity::
                    severity_critical();

        let is_warning =
            severity ==
                cross_network_incident_severity::
                    severity_warning();

        let is_watch =
            severity ==
                cross_network_incident_severity::
                    severity_watch();

        let repeated_critical =
            is_critical
                && critical_count
                    >= policy.critical_repeat_threshold;

        let operator_quarantine_eligible =
            is_critical
                && score
                    >= policy.critical_score_threshold_bps
                && policy.allow_operator_quarantine;

        let domain_quarantine_eligible =
            repeated_critical
                && policy.allow_domain_quarantine;

        let network_quarantine_eligible =
            repeated_critical
                && policy.allow_network_quarantine;

        let execution_pause_eligible =
            repeated_critical
                && score
                    >= policy.critical_score_threshold_bps
                && policy.allow_execution_pause;

        let recovery_eligible =
            !is_critical
                && score
                    < policy.warning_score_threshold_bps
                && policy.allow_automatic_recovery;

        let action =
            if (execution_pause_eligible) {
                ACTION_PAUSE_EXECUTION
            } else if (network_quarantine_eligible) {
                ACTION_QUARANTINE_NETWORK
            } else if (domain_quarantine_eligible) {
                ACTION_QUARANTINE_DOMAIN
            } else if (operator_quarantine_eligible) {
                ACTION_QUARANTINE_OPERATOR
            } else if (
                is_warning
                    || score
                        >= policy.warning_score_threshold_bps
            ) {
                ACTION_RESTRICT
            } else if (is_watch) {
                ACTION_MONITOR
            } else if (recovery_eligible) {
                ACTION_RECOVERY_ELIGIBLE
            } else {
                ACTION_NONE
            };

        ResponseDecision {
            policy_version: policy.version,

            snapshot_sequence:
                cross_network_security_snapshot::
                    snapshot_sequence(snapshot),

            anomaly_score_bps: score,
            severity,
            critical_count,

            action,

            operator_quarantine_eligible,
            domain_quarantine_eligible,
            network_quarantine_eligible,
            execution_pause_eligible,
            recovery_eligible,
        }
    }

    // ============================================================
    // Policy Administration
    // ============================================================

    public fun set_thresholds(
        policy: &mut SecurityResponsePolicy,
        warning_score_threshold_bps: u64,
        critical_score_threshold_bps: u64,
        critical_repeat_threshold: u64,
    ) {

        assert!(
            warning_score_threshold_bps <= BPS_DENOMINATOR,
            E_INVALID_THRESHOLD,
        );

        assert!(
            critical_score_threshold_bps <= BPS_DENOMINATOR,
            E_INVALID_THRESHOLD,
        );

        assert!(
            warning_score_threshold_bps
                < critical_score_threshold_bps,
            E_INVALID_THRESHOLD_ORDER,
        );

        assert!(
            critical_repeat_threshold > 0,
            E_INVALID_REPEAT_THRESHOLD,
        );

        policy.warning_score_threshold_bps =
            warning_score_threshold_bps;

        policy.critical_score_threshold_bps =
            critical_score_threshold_bps;

        policy.critical_repeat_threshold =
            critical_repeat_threshold;
    }

    public fun set_capabilities(
        policy: &mut SecurityResponsePolicy,

        allow_operator_quarantine: bool,
        allow_domain_quarantine: bool,
        allow_network_quarantine: bool,
        allow_execution_pause: bool,
        allow_automatic_recovery: bool,
    ) {

        policy.allow_operator_quarantine =
            allow_operator_quarantine;

        policy.allow_domain_quarantine =
            allow_domain_quarantine;

        policy.allow_network_quarantine =
            allow_network_quarantine;

        policy.allow_execution_pause =
            allow_execution_pause;

        policy.allow_automatic_recovery =
            allow_automatic_recovery;
    }

    public fun set_paused(
        policy: &mut SecurityResponsePolicy,
        paused: bool,
    ) {
        policy.paused = paused;
    }

    public fun set_version(
        policy: &mut SecurityResponsePolicy,
        new_version: u64,
    ) {
        assert!(
            new_version > policy.version,
            E_INVALID_VERSION,
        );

        policy.version = new_version;
    }

    // ============================================================
    // Policy Getters
    // ============================================================

    public fun protocol_version(
        policy: &SecurityResponsePolicy,
    ): u64 {
        policy.protocol_version
    }

    public fun version(
        policy: &SecurityResponsePolicy,
    ): u64 {
        policy.version
    }

    public fun is_paused(
        policy: &SecurityResponsePolicy,
    ): bool {
        policy.paused
    }

    public fun warning_score_threshold_bps(
        policy: &SecurityResponsePolicy,
    ): u64 {
        policy.warning_score_threshold_bps
    }

    public fun critical_score_threshold_bps(
        policy: &SecurityResponsePolicy,
    ): u64 {
        policy.critical_score_threshold_bps
    }

    public fun critical_repeat_threshold(
        policy: &SecurityResponsePolicy,
    ): u64 {
        policy.critical_repeat_threshold
    }

    public fun allow_operator_quarantine(
        policy: &SecurityResponsePolicy,
    ): bool {
        policy.allow_operator_quarantine
    }

    public fun allow_domain_quarantine(
        policy: &SecurityResponsePolicy,
    ): bool {
        policy.allow_domain_quarantine
    }

    public fun allow_network_quarantine(
        policy: &SecurityResponsePolicy,
    ): bool {
        policy.allow_network_quarantine
    }

    public fun allow_execution_pause(
        policy: &SecurityResponsePolicy,
    ): bool {
        policy.allow_execution_pause
    }

    public fun allow_automatic_recovery(
        policy: &SecurityResponsePolicy,
    ): bool {
        policy.allow_automatic_recovery
    }

    // ============================================================
    // Decision Getters
    // ============================================================

    public fun decision_policy_version(
        decision: &ResponseDecision,
    ): u64 {
        decision.policy_version
    }

    public fun decision_snapshot_sequence(
        decision: &ResponseDecision,
    ): u64 {
        decision.snapshot_sequence
    }

    public fun decision_anomaly_score_bps(
        decision: &ResponseDecision,
    ): u64 {
        decision.anomaly_score_bps
    }

    public fun decision_severity(
        decision: &ResponseDecision,
    ): u8 {
        decision.severity
    }

    public fun decision_critical_count(
        decision: &ResponseDecision,
    ): u64 {
        decision.critical_count
    }

    public fun decision_action(
        decision: &ResponseDecision,
    ): u8 {
        decision.action
    }

    public fun operator_quarantine_eligible(
        decision: &ResponseDecision,
    ): bool {
        decision.operator_quarantine_eligible
    }

    public fun domain_quarantine_eligible(
        decision: &ResponseDecision,
    ): bool {
        decision.domain_quarantine_eligible
    }

    public fun network_quarantine_eligible(
        decision: &ResponseDecision,
    ): bool {
        decision.network_quarantine_eligible
    }

    public fun execution_pause_eligible(
        decision: &ResponseDecision,
    ): bool {
        decision.execution_pause_eligible
    }

    public fun recovery_eligible(
        decision: &ResponseDecision,
    ): bool {
        decision.recovery_eligible
    }

    // ============================================================
    // Action Getters
    // ============================================================

    public fun action_none(): u8 {
        ACTION_NONE
    }

    public fun action_monitor(): u8 {
        ACTION_MONITOR
    }

    public fun action_restrict(): u8 {
        ACTION_RESTRICT
    }

    public fun action_quarantine_operator(): u8 {
        ACTION_QUARANTINE_OPERATOR
    }

    public fun action_quarantine_domain(): u8 {
        ACTION_QUARANTINE_DOMAIN
    }

    public fun action_quarantine_network(): u8 {
        ACTION_QUARANTINE_NETWORK
    }

    public fun action_pause_execution(): u8 {
        ACTION_PAUSE_EXECUTION
    }

    public fun action_recovery_eligible(): u8 {
        ACTION_RECOVERY_ELIGIBLE
    }

    // ============================================================
    // Testing
    // ============================================================

    #[test_only]
    public fun destroy_policy_for_testing(
        policy: SecurityResponsePolicy,
    ) {
        let SecurityResponsePolicy {
            id,

            protocol_version: _,
            version: _,
            paused: _,

            warning_score_threshold_bps: _,
            critical_score_threshold_bps: _,

            critical_repeat_threshold: _,

            allow_operator_quarantine: _,
            allow_domain_quarantine: _,
            allow_network_quarantine: _,
            allow_execution_pause: _,
            allow_automatic_recovery: _,
        } = policy;

        object::delete(id);
    }
}
