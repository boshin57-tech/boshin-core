module tobmate_core::cross_network_incident_severity {

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    // ============================================================
    // Protocol
    // ============================================================

    const PROTOCOL_VERSION: u64 = 1;
    const MAX_SCORE_BPS: u64 = 10_000;

    // ============================================================
    // Severity
    // ============================================================

    const SEVERITY_NORMAL: u8 = 0;
    const SEVERITY_WATCH: u8 = 1;
    const SEVERITY_WARNING: u8 = 2;
    const SEVERITY_CRITICAL: u8 = 3;

    // ============================================================
    // Errors
    // ============================================================

    const E_INVALID_THRESHOLD_ORDER: u64 = 1;
    const E_INVALID_THRESHOLD: u64 = 2;
    const E_INVALID_VERSION: u64 = 3;
    const E_STATE_UNCHANGED: u64 = 4;
    const E_PAUSED: u64 = 5;
    const E_SCORE_ABOVE_MAX: u64 = 6;

    // ============================================================
    // Threshold Policy
    //
    // Default:
    // 0      - 1999  NORMAL
    // 2000   - 3999  WATCH
    // 4000   - 6999  WARNING
    // 7000   - 10000 CRITICAL
    // ============================================================

    public struct IncidentThresholdPolicy has key, store {
        id: UID,
        version: u64,
        paused: bool,

        watch_threshold_bps: u64,
        warning_threshold_bps: u64,
        critical_threshold_bps: u64,
    }

    // ============================================================
    // Incident State
    // ============================================================

    public struct IncidentSeverityState has key, store {
        id: UID,

        current_severity: u8,
        previous_severity: u8,

        last_score_bps: u64,

        evaluation_count: u64,
        escalation_count: u64,
        deescalation_count: u64,
        unchanged_count: u64,
        critical_count: u64,
    }

    // ============================================================
    // Construction
    // ============================================================

    public fun new_default_policy(
        ctx: &mut TxContext,
    ): IncidentThresholdPolicy {

        IncidentThresholdPolicy {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,
            paused: false,

            watch_threshold_bps: 2_000,
            warning_threshold_bps: 4_000,
            critical_threshold_bps: 7_000,
        }
    }

    public fun new_policy(
        watch_threshold_bps: u64,
        warning_threshold_bps: u64,
        critical_threshold_bps: u64,
        ctx: &mut TxContext,
    ): IncidentThresholdPolicy {

        assert_valid_thresholds(
            watch_threshold_bps,
            warning_threshold_bps,
            critical_threshold_bps,
        );

        IncidentThresholdPolicy {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,
            paused: false,

            watch_threshold_bps,
            warning_threshold_bps,
            critical_threshold_bps,
        }
    }

    public fun new_state(
        ctx: &mut TxContext,
    ): IncidentSeverityState {

        IncidentSeverityState {
            id: object::new(ctx),

            current_severity: SEVERITY_NORMAL,
            previous_severity: SEVERITY_NORMAL,

            last_score_bps: 0,

            evaluation_count: 0,
            escalation_count: 0,
            deescalation_count: 0,
            unchanged_count: 0,
            critical_count: 0,
        }
    }

    // ============================================================
    // Validation
    // ============================================================

    fun assert_valid_thresholds(
        watch_threshold_bps: u64,
        warning_threshold_bps: u64,
        critical_threshold_bps: u64,
    ) {
        assert!(
            watch_threshold_bps <= MAX_SCORE_BPS,
            E_INVALID_THRESHOLD,
        );

        assert!(
            warning_threshold_bps <= MAX_SCORE_BPS,
            E_INVALID_THRESHOLD,
        );

        assert!(
            critical_threshold_bps <= MAX_SCORE_BPS,
            E_INVALID_THRESHOLD,
        );

        assert!(
            watch_threshold_bps
                < warning_threshold_bps,
            E_INVALID_THRESHOLD_ORDER,
        );

        assert!(
            warning_threshold_bps
                < critical_threshold_bps,
            E_INVALID_THRESHOLD_ORDER,
        );
    }

    // ============================================================
    // Severity Classification
    // ============================================================

    public fun classify_score(
        policy: &IncidentThresholdPolicy,
        score_bps: u64,
    ): u8 {

        assert!(!policy.paused, E_PAUSED);
        assert!(score_bps <= MAX_SCORE_BPS, E_SCORE_ABOVE_MAX);

        if (score_bps >= policy.critical_threshold_bps) {
            SEVERITY_CRITICAL
        } else if (score_bps >= policy.warning_threshold_bps) {
            SEVERITY_WARNING
        } else if (score_bps >= policy.watch_threshold_bps) {
            SEVERITY_WATCH
        } else {
            SEVERITY_NORMAL
        }
    }

    // ============================================================
    // Evaluation
    // ============================================================

    public fun evaluate(
        policy: &IncidentThresholdPolicy,
        state: &mut IncidentSeverityState,
        score_bps: u64,
    ): u8 {

        let new_severity =
            classify_score(
                policy,
                score_bps,
            );

        let old_severity =
            state.current_severity;

        state.previous_severity =
            old_severity;

        state.current_severity =
            new_severity;

        state.last_score_bps =
            score_bps;

        state.evaluation_count =
            state.evaluation_count + 1;

        if (new_severity > old_severity) {
            state.escalation_count =
                state.escalation_count + 1;
        } else if (new_severity < old_severity) {
            state.deescalation_count =
                state.deescalation_count + 1;
        } else {
            state.unchanged_count =
                state.unchanged_count + 1;
        };

        if (new_severity == SEVERITY_CRITICAL) {
            state.critical_count =
                state.critical_count + 1;
        };

        new_severity
    }

    // ============================================================
    // Policy Administration
    // ============================================================

    public fun set_thresholds(
        policy: &mut IncidentThresholdPolicy,
        watch_threshold_bps: u64,
        warning_threshold_bps: u64,
        critical_threshold_bps: u64,
    ) {

        assert_valid_thresholds(
            watch_threshold_bps,
            warning_threshold_bps,
            critical_threshold_bps,
        );

        policy.watch_threshold_bps =
            watch_threshold_bps;

        policy.warning_threshold_bps =
            warning_threshold_bps;

        policy.critical_threshold_bps =
            critical_threshold_bps;
    }

    public fun set_paused(
        policy: &mut IncidentThresholdPolicy,
        paused: bool,
    ) {

        assert!(
            policy.paused != paused,
            E_STATE_UNCHANGED,
        );

        policy.paused = paused;
    }

    public fun set_version(
        policy: &mut IncidentThresholdPolicy,
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

    public fun version(
        policy: &IncidentThresholdPolicy,
    ): u64 {
        policy.version
    }

    public fun is_paused(
        policy: &IncidentThresholdPolicy,
    ): bool {
        policy.paused
    }

    public fun watch_threshold_bps(
        policy: &IncidentThresholdPolicy,
    ): u64 {
        policy.watch_threshold_bps
    }

    public fun warning_threshold_bps(
        policy: &IncidentThresholdPolicy,
    ): u64 {
        policy.warning_threshold_bps
    }

    public fun critical_threshold_bps(
        policy: &IncidentThresholdPolicy,
    ): u64 {
        policy.critical_threshold_bps
    }

    // ============================================================
    // State Getters
    // ============================================================

    public fun current_severity(
        state: &IncidentSeverityState,
    ): u8 {
        state.current_severity
    }

    public fun previous_severity(
        state: &IncidentSeverityState,
    ): u8 {
        state.previous_severity
    }

    public fun last_score_bps(
        state: &IncidentSeverityState,
    ): u64 {
        state.last_score_bps
    }

    public fun evaluation_count(
        state: &IncidentSeverityState,
    ): u64 {
        state.evaluation_count
    }

    public fun escalation_count(
        state: &IncidentSeverityState,
    ): u64 {
        state.escalation_count
    }

    public fun deescalation_count(
        state: &IncidentSeverityState,
    ): u64 {
        state.deescalation_count
    }

    public fun unchanged_count(
        state: &IncidentSeverityState,
    ): u64 {
        state.unchanged_count
    }

    public fun critical_count(
        state: &IncidentSeverityState,
    ): u64 {
        state.critical_count
    }

    // ============================================================
    // Severity Constants
    // ============================================================

    public fun severity_normal(): u8 {
        SEVERITY_NORMAL
    }

    public fun severity_watch(): u8 {
        SEVERITY_WATCH
    }

    public fun severity_warning(): u8 {
        SEVERITY_WARNING
    }

    public fun severity_critical(): u8 {
        SEVERITY_CRITICAL
    }

    public fun max_score_bps(): u64 {
        MAX_SCORE_BPS
    }

    // ============================================================
    // Testing Helpers
    // ============================================================

    #[test_only]
    public fun new_default_policy_for_testing(
        ctx: &mut TxContext,
    ): IncidentThresholdPolicy {
        new_default_policy(ctx)
    }

    #[test_only]
    public fun new_state_for_testing(
        ctx: &mut TxContext,
    ): IncidentSeverityState {
        new_state(ctx)
    }

    #[test_only]
    public fun destroy_policy_for_testing(
        policy: IncidentThresholdPolicy,
    ) {

        let IncidentThresholdPolicy {
            id,
            version: _,
            paused: _,
            watch_threshold_bps: _,
            warning_threshold_bps: _,
            critical_threshold_bps: _,
        } = policy;

        object::delete(id);
    }

    #[test_only]
    public fun destroy_state_for_testing(
        state: IncidentSeverityState,
    ) {

        let IncidentSeverityState {
            id,

            current_severity: _,
            previous_severity: _,

            last_score_bps: _,

            evaluation_count: _,
            escalation_count: _,
            deescalation_count: _,
            unchanged_count: _,
            critical_count: _,
        } = state;

        object::delete(id);
    }
}
