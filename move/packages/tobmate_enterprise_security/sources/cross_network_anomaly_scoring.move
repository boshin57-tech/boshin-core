module tobmate_enterprise_security::cross_network_anomaly_scoring {

    use std::vector;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    use tobmate_enterprise_security::cross_network_security_telemetry;

    // ============================================================
    // Protocol
    // ============================================================

    const PROTOCOL_VERSION: u64 = 1;
    const BPS_DENOMINATOR: u64 = 10_000;
    const MAX_SCORE_BPS: u64 = 10_000;

    // ============================================================
    // Errors
    // ============================================================

    const E_INVALID_WEIGHT_TOTAL: u64 = 1;
    const E_INVALID_WEIGHT: u64 = 2;
    const E_INVALID_VERSION: u64 = 3;
    const E_STATE_UNCHANGED: u64 = 4;
    const E_PAUSED: u64 = 5;

    // ============================================================
    // Deterministic scoring policy
    //
    // All weights are basis points and must sum to 10,000.
    // No floating point, ML model, oracle, timestamp, randomness,
    // or external AI decision is used by this module.
    // ============================================================

    public struct AnomalyScoringPolicy has key, store {
        id: UID,
        version: u64,
        paused: bool,

        failure_weight_bps: u64,
        rejection_weight_bps: u64,
        rate_violation_weight_bps: u64,
        risk_violation_weight_bps: u64,
        compliance_violation_weight_bps: u64,
        operator_trust_violation_weight_bps: u64,
    }

    public struct AnomalyScoreBreakdown has copy, drop, store {
        failure_pressure_bps: u64,
        rejection_pressure_bps: u64,
        rate_violation_pressure_bps: u64,
        risk_violation_pressure_bps: u64,
        compliance_violation_pressure_bps: u64,
        operator_trust_violation_pressure_bps: u64,

        final_score_bps: u64,
    }

    // ============================================================
    // Construction
    // ============================================================

    public fun new_default_policy(
        ctx: &mut TxContext,
    ): AnomalyScoringPolicy {

        // Initial security weighting:
        //
        // failure       10%
        // rejection     10%
        // rate          15%
        // risk          20%
        // compliance    25%
        // operator      20%
        //
        // total        100%

        AnomalyScoringPolicy {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,
            paused: false,

            failure_weight_bps: 1_000,
            rejection_weight_bps: 1_000,
            rate_violation_weight_bps: 1_500,
            risk_violation_weight_bps: 2_000,
            compliance_violation_weight_bps: 2_500,
            operator_trust_violation_weight_bps: 2_000,
        }
    }

    public fun new_policy(
        failure_weight_bps: u64,
        rejection_weight_bps: u64,
        rate_violation_weight_bps: u64,
        risk_violation_weight_bps: u64,
        compliance_violation_weight_bps: u64,
        operator_trust_violation_weight_bps: u64,
        ctx: &mut TxContext,
    ): AnomalyScoringPolicy {

        assert_valid_weights(
            failure_weight_bps,
            rejection_weight_bps,
            rate_violation_weight_bps,
            risk_violation_weight_bps,
            compliance_violation_weight_bps,
            operator_trust_violation_weight_bps,
        );

        AnomalyScoringPolicy {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,
            paused: false,

            failure_weight_bps,
            rejection_weight_bps,
            rate_violation_weight_bps,
            risk_violation_weight_bps,
            compliance_violation_weight_bps,
            operator_trust_violation_weight_bps,
        }
    }

    fun assert_valid_weights(
        failure_weight_bps: u64,
        rejection_weight_bps: u64,
        rate_violation_weight_bps: u64,
        risk_violation_weight_bps: u64,
        compliance_violation_weight_bps: u64,
        operator_trust_violation_weight_bps: u64,
    ) {
        assert!(
            failure_weight_bps <= BPS_DENOMINATOR,
            E_INVALID_WEIGHT,
        );

        assert!(
            rejection_weight_bps <= BPS_DENOMINATOR,
            E_INVALID_WEIGHT,
        );

        assert!(
            rate_violation_weight_bps <= BPS_DENOMINATOR,
            E_INVALID_WEIGHT,
        );

        assert!(
            risk_violation_weight_bps <= BPS_DENOMINATOR,
            E_INVALID_WEIGHT,
        );

        assert!(
            compliance_violation_weight_bps <= BPS_DENOMINATOR,
            E_INVALID_WEIGHT,
        );

        assert!(
            operator_trust_violation_weight_bps
                <= BPS_DENOMINATOR,
            E_INVALID_WEIGHT,
        );

        let total =
            failure_weight_bps
            + rejection_weight_bps
            + rate_violation_weight_bps
            + risk_violation_weight_bps
            + compliance_violation_weight_bps
            + operator_trust_violation_weight_bps;

        assert!(
            total == BPS_DENOMINATOR,
            E_INVALID_WEIGHT_TOTAL,
        );
    }

    // ============================================================
    // Pressure calculation
    // ============================================================

    fun capped_pressure_bps(
        count: u64,
        attempts: u64,
    ): u64 {

        if (count == 0) {
            return 0
        };

        // A violation with no matching execution-attempt history
        // is conservatively treated as maximum pressure.
        if (attempts == 0) {
            return MAX_SCORE_BPS
        };

        let pressure =
            (count * BPS_DENOMINATOR) / attempts;

        if (pressure > MAX_SCORE_BPS) {
            MAX_SCORE_BPS
        } else {
            pressure
        }
    }

    // ============================================================
    // Core deterministic scoring
    // ============================================================

    public fun score_counters(
        policy: &AnomalyScoringPolicy,
        counters:
            &cross_network_security_telemetry::TelemetryCounters,
    ): AnomalyScoreBreakdown {

        assert!(!policy.paused, E_PAUSED);

        let attempts =
            cross_network_security_telemetry::
                counter_attempts(counters);

        let failure_pressure_bps =
            capped_pressure_bps(
                cross_network_security_telemetry::
                    counter_failures(counters),
                attempts,
            );

        let rejection_pressure_bps =
            capped_pressure_bps(
                cross_network_security_telemetry::
                    counter_rejections(counters),
                attempts,
            );

        let rate_violation_pressure_bps =
            capped_pressure_bps(
                cross_network_security_telemetry::
                    counter_rate_violations(counters),
                attempts,
            );

        let risk_violation_pressure_bps =
            capped_pressure_bps(
                cross_network_security_telemetry::
                    counter_risk_violations(counters),
                attempts,
            );

        let compliance_violation_pressure_bps =
            capped_pressure_bps(
                cross_network_security_telemetry::
                    counter_compliance_violations(counters),
                attempts,
            );

        let operator_trust_violation_pressure_bps =
            capped_pressure_bps(
                cross_network_security_telemetry::
                    counter_operator_trust_violations(counters),
                attempts,
            );

        let weighted_sum =
            failure_pressure_bps
                * policy.failure_weight_bps
            + rejection_pressure_bps
                * policy.rejection_weight_bps
            + rate_violation_pressure_bps
                * policy.rate_violation_weight_bps
            + risk_violation_pressure_bps
                * policy.risk_violation_weight_bps
            + compliance_violation_pressure_bps
                * policy.compliance_violation_weight_bps
            + operator_trust_violation_pressure_bps
                * policy.operator_trust_violation_weight_bps;

        let final_score_bps =
            weighted_sum / BPS_DENOMINATOR;

        AnomalyScoreBreakdown {
            failure_pressure_bps,
            rejection_pressure_bps,
            rate_violation_pressure_bps,
            risk_violation_pressure_bps,
            compliance_violation_pressure_bps,
            operator_trust_violation_pressure_bps,
            final_score_bps,
        }
    }

    // ============================================================
    // Scoped scoring
    // ============================================================

    public fun score_network(
        policy: &AnomalyScoringPolicy,
        telemetry:
            &cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
    ): AnomalyScoreBreakdown {

        let counters =
            cross_network_security_telemetry::
                network_counters(
                    telemetry,
                    network_id,
                );

        score_counters(policy, &counters)
    }

    public fun score_domain(
        policy: &AnomalyScoringPolicy,
        telemetry:
            &cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,
        domain_id: vector<u8>,
    ): AnomalyScoreBreakdown {

        let counters =
            cross_network_security_telemetry::
                domain_counters(
                    telemetry,
                    domain_id,
                );

        score_counters(policy, &counters)
    }

    public fun score_operator(
        policy: &AnomalyScoringPolicy,
        telemetry:
            &cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,
        operator_id: vector<u8>,
    ): AnomalyScoreBreakdown {

        let counters =
            cross_network_security_telemetry::
                operator_counters(
                    telemetry,
                    operator_id,
                );

        score_counters(policy, &counters)
    }

    // ============================================================
    // Composite score
    //
    // Conservative aggregation:
    // composite = maximum(network, domain, operator)
    //
    // This prevents a highly anomalous operator/domain from being
    // diluted by healthier scopes.
    // ============================================================

    public fun composite_score_bps(
        network_score: &AnomalyScoreBreakdown,
        domain_score: &AnomalyScoreBreakdown,
        operator_score: &AnomalyScoreBreakdown,
    ): u64 {

        let mut max_score = network_score.final_score_bps;

        if (domain_score.final_score_bps > max_score) {
            max_score = domain_score.final_score_bps;
        };

        if (operator_score.final_score_bps > max_score) {
            max_score = operator_score.final_score_bps;
        };

        max_score
    }

    public fun score_composite(
        policy: &AnomalyScoringPolicy,
        telemetry:
            &cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ): u64 {

        let network =
            score_network(
                policy,
                telemetry,
                network_id,
            );

        let domain =
            score_domain(
                policy,
                telemetry,
                domain_id,
            );

        let operator =
            score_operator(
                policy,
                telemetry,
                operator_id,
            );

        composite_score_bps(
            &network,
            &domain,
            &operator,
        )
    }

    // ============================================================
    // Policy administration
    // ============================================================

    public fun set_weights(
        policy: &mut AnomalyScoringPolicy,

        failure_weight_bps: u64,
        rejection_weight_bps: u64,
        rate_violation_weight_bps: u64,
        risk_violation_weight_bps: u64,
        compliance_violation_weight_bps: u64,
        operator_trust_violation_weight_bps: u64,
    ) {

        assert_valid_weights(
            failure_weight_bps,
            rejection_weight_bps,
            rate_violation_weight_bps,
            risk_violation_weight_bps,
            compliance_violation_weight_bps,
            operator_trust_violation_weight_bps,
        );

        policy.failure_weight_bps =
            failure_weight_bps;

        policy.rejection_weight_bps =
            rejection_weight_bps;

        policy.rate_violation_weight_bps =
            rate_violation_weight_bps;

        policy.risk_violation_weight_bps =
            risk_violation_weight_bps;

        policy.compliance_violation_weight_bps =
            compliance_violation_weight_bps;

        policy.operator_trust_violation_weight_bps =
            operator_trust_violation_weight_bps;
    }

    public fun set_paused(
        policy: &mut AnomalyScoringPolicy,
        paused: bool,
    ) {
        assert!(
            policy.paused != paused,
            E_STATE_UNCHANGED,
        );

        policy.paused = paused;
    }

    public fun set_version(
        policy: &mut AnomalyScoringPolicy,
        new_version: u64,
    ) {
        assert!(
            new_version > policy.version,
            E_INVALID_VERSION,
        );

        policy.version = new_version;
    }

    // ============================================================
    // Policy getters
    // ============================================================

    public fun version(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.version
    }

    public fun is_paused(
        policy: &AnomalyScoringPolicy,
    ): bool {
        policy.paused
    }

    public fun failure_weight_bps(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.failure_weight_bps
    }

    public fun rejection_weight_bps(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.rejection_weight_bps
    }

    public fun rate_violation_weight_bps(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.rate_violation_weight_bps
    }

    public fun risk_violation_weight_bps(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.risk_violation_weight_bps
    }

    public fun compliance_violation_weight_bps(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.compliance_violation_weight_bps
    }

    public fun operator_trust_violation_weight_bps(
        policy: &AnomalyScoringPolicy,
    ): u64 {
        policy.operator_trust_violation_weight_bps
    }

    // ============================================================
    // Score getters
    // ============================================================

    public fun final_score_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.final_score_bps
    }

    public fun failure_pressure_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.failure_pressure_bps
    }

    public fun rejection_pressure_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.rejection_pressure_bps
    }

    public fun rate_violation_pressure_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.rate_violation_pressure_bps
    }

    public fun risk_violation_pressure_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.risk_violation_pressure_bps
    }

    public fun compliance_violation_pressure_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.compliance_violation_pressure_bps
    }

    public fun operator_trust_violation_pressure_bps(
        score: &AnomalyScoreBreakdown,
    ): u64 {
        score.operator_trust_violation_pressure_bps
    }

    public fun max_score_bps(): u64 {
        MAX_SCORE_BPS
    }

    // ============================================================
    // Testing
    // ============================================================

    #[test_only]
    public fun new_default_policy_for_testing(
        ctx: &mut TxContext,
    ): AnomalyScoringPolicy {
        new_default_policy(ctx)
    }

    #[test_only]
    public fun destroy_policy_for_testing(
        policy: AnomalyScoringPolicy,
    ) {
        let AnomalyScoringPolicy {
            id,
            version: _,
            paused: _,
            failure_weight_bps: _,
            rejection_weight_bps: _,
            rate_violation_weight_bps: _,
            risk_violation_weight_bps: _,
            compliance_violation_weight_bps: _,
            operator_trust_violation_weight_bps: _,
        } = policy;

        object::delete(id);
    }
}
