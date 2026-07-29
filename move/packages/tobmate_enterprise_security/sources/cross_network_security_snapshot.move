module tobmate_enterprise_security::cross_network_security_snapshot {

    use std::vector;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    use tobmate_enterprise_security::cross_network_security_telemetry;
    use tobmate_enterprise_security::cross_network_anomaly_scoring;
    use tobmate_enterprise_security::cross_network_incident_severity;

    const PROTOCOL_VERSION: u64 = 1;

    // ============================================================
    // Security Snapshot
    //
    // Observation / audit state only.
    // This object grants no execution, governance, recovery,
    // compliance, emergency, or remediation authority.
    // ============================================================

    public struct SecuritySnapshot has key, store {
        id: UID,

        protocol_version: u64,
        snapshot_sequence: u64,

        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,

        // Source versions
        telemetry_version: u64,
        anomaly_policy_version: u64,
        incident_policy_version: u64,

        // Global telemetry
        total_attempts: u64,
        total_successes: u64,
        total_failures: u64,
        total_rejections: u64,

        total_rate_violations: u64,
        total_risk_violations: u64,
        total_compliance_violations: u64,
        total_operator_trust_violations: u64,
        total_security_violations: u64,

        // Scoped execution counters
        network_attempts: u64,
        network_failures: u64,
        network_rejections: u64,

        domain_attempts: u64,
        domain_failures: u64,
        domain_rejections: u64,

        operator_attempts: u64,
        operator_failures: u64,
        operator_rejections: u64,

        // Scoped violation counters
        network_rate_violations: u64,
        network_risk_violations: u64,
        network_compliance_violations: u64,
        network_operator_trust_violations: u64,

        domain_rate_violations: u64,
        domain_risk_violations: u64,
        domain_compliance_violations: u64,
        domain_operator_trust_violations: u64,

        operator_rate_violations: u64,
        operator_risk_violations: u64,
        operator_compliance_violations: u64,
        operator_operator_trust_violations: u64,

        // Deterministic anomaly scores
        network_anomaly_score_bps: u64,
        domain_anomaly_score_bps: u64,
        operator_anomaly_score_bps: u64,
        composite_anomaly_score_bps: u64,

        // Incident state
        current_severity: u8,
        previous_severity: u8,
        last_incident_score_bps: u64,

        incident_evaluation_count: u64,
        incident_escalation_count: u64,
        incident_deescalation_count: u64,
        incident_unchanged_count: u64,
        incident_critical_count: u64,
    }

    // ============================================================
    // Capture
    // ============================================================

    public fun capture(
        telemetry:
            &cross_network_security_telemetry::
                CrossNetworkSecurityTelemetry,

        anomaly_policy:
            &cross_network_anomaly_scoring::
                AnomalyScoringPolicy,

        incident_policy:
            &cross_network_incident_severity::
                IncidentThresholdPolicy,

        incident_state:
            &cross_network_incident_severity::
                IncidentSeverityState,

        snapshot_sequence: u64,

        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,

        ctx: &mut TxContext,
    ): SecuritySnapshot {

        let network_counters =
            cross_network_security_telemetry::
                network_counters(
                    telemetry,
                    network_id,
                );

        let domain_counters =
            cross_network_security_telemetry::
                domain_counters(
                    telemetry,
                    domain_id,
                );

        let operator_counters =
            cross_network_security_telemetry::
                operator_counters(
                    telemetry,
                    operator_id,
                );

        let network_score =
            cross_network_anomaly_scoring::
                score_counters(
                    anomaly_policy,
                    &network_counters,
                );

        let domain_score =
            cross_network_anomaly_scoring::
                score_counters(
                    anomaly_policy,
                    &domain_counters,
                );

        let operator_score =
            cross_network_anomaly_scoring::
                score_counters(
                    anomaly_policy,
                    &operator_counters,
                );

        let composite_score =
            cross_network_anomaly_scoring::
                composite_score_bps(
                    &network_score,
                    &domain_score,
                    &operator_score,
                );

        SecuritySnapshot {
            id: object::new(ctx),

            protocol_version: PROTOCOL_VERSION,
            snapshot_sequence,

            network_id,
            domain_id,
            operator_id,

            telemetry_version:
                cross_network_security_telemetry::
                    version(telemetry),

            anomaly_policy_version:
                cross_network_anomaly_scoring::
                    version(anomaly_policy),

            incident_policy_version:
                cross_network_incident_severity::
                    version(incident_policy),

            total_attempts:
                cross_network_security_telemetry::
                    total_attempts(telemetry),

            total_successes:
                cross_network_security_telemetry::
                    total_successes(telemetry),

            total_failures:
                cross_network_security_telemetry::
                    total_failures(telemetry),

            total_rejections:
                cross_network_security_telemetry::
                    total_rejections(telemetry),

            total_rate_violations:
                cross_network_security_telemetry::
                    total_rate_violations(telemetry),

            total_risk_violations:
                cross_network_security_telemetry::
                    total_risk_violations(telemetry),

            total_compliance_violations:
                cross_network_security_telemetry::
                    total_compliance_violations(telemetry),

            total_operator_trust_violations:
                cross_network_security_telemetry::
                    total_operator_trust_violations(telemetry),

            total_security_violations:
                cross_network_security_telemetry::
                    total_security_violations(telemetry),

            network_attempts:
                cross_network_security_telemetry::
                    counter_attempts(&network_counters),

            network_failures:
                cross_network_security_telemetry::
                    counter_failures(&network_counters),

            network_rejections:
                cross_network_security_telemetry::
                    counter_rejections(&network_counters),

            domain_attempts:
                cross_network_security_telemetry::
                    counter_attempts(&domain_counters),

            domain_failures:
                cross_network_security_telemetry::
                    counter_failures(&domain_counters),

            domain_rejections:
                cross_network_security_telemetry::
                    counter_rejections(&domain_counters),

            operator_attempts:
                cross_network_security_telemetry::
                    counter_attempts(&operator_counters),

            operator_failures:
                cross_network_security_telemetry::
                    counter_failures(&operator_counters),

            operator_rejections:
                cross_network_security_telemetry::
                    counter_rejections(&operator_counters),

            network_rate_violations:
                cross_network_security_telemetry::
                    counter_rate_violations(
                        &network_counters,
                    ),

            network_risk_violations:
                cross_network_security_telemetry::
                    counter_risk_violations(
                        &network_counters,
                    ),

            network_compliance_violations:
                cross_network_security_telemetry::
                    counter_compliance_violations(
                        &network_counters,
                    ),

            network_operator_trust_violations:
                cross_network_security_telemetry::
                    counter_operator_trust_violations(
                        &network_counters,
                    ),

            domain_rate_violations:
                cross_network_security_telemetry::
                    counter_rate_violations(
                        &domain_counters,
                    ),

            domain_risk_violations:
                cross_network_security_telemetry::
                    counter_risk_violations(
                        &domain_counters,
                    ),

            domain_compliance_violations:
                cross_network_security_telemetry::
                    counter_compliance_violations(
                        &domain_counters,
                    ),

            domain_operator_trust_violations:
                cross_network_security_telemetry::
                    counter_operator_trust_violations(
                        &domain_counters,
                    ),

            operator_rate_violations:
                cross_network_security_telemetry::
                    counter_rate_violations(
                        &operator_counters,
                    ),

            operator_risk_violations:
                cross_network_security_telemetry::
                    counter_risk_violations(
                        &operator_counters,
                    ),

            operator_compliance_violations:
                cross_network_security_telemetry::
                    counter_compliance_violations(
                        &operator_counters,
                    ),

            operator_operator_trust_violations:
                cross_network_security_telemetry::
                    counter_operator_trust_violations(
                        &operator_counters,
                    ),

            network_anomaly_score_bps:
                cross_network_anomaly_scoring::
                    final_score_bps(
                        &network_score,
                    ),

            domain_anomaly_score_bps:
                cross_network_anomaly_scoring::
                    final_score_bps(
                        &domain_score,
                    ),

            operator_anomaly_score_bps:
                cross_network_anomaly_scoring::
                    final_score_bps(
                        &operator_score,
                    ),

            composite_anomaly_score_bps:
                composite_score,

            current_severity:
                cross_network_incident_severity::
                    current_severity(
                        incident_state,
                    ),

            previous_severity:
                cross_network_incident_severity::
                    previous_severity(
                        incident_state,
                    ),

            last_incident_score_bps:
                cross_network_incident_severity::
                    last_score_bps(
                        incident_state,
                    ),

            incident_evaluation_count:
                cross_network_incident_severity::
                    evaluation_count(
                        incident_state,
                    ),

            incident_escalation_count:
                cross_network_incident_severity::
                    escalation_count(
                        incident_state,
                    ),

            incident_deescalation_count:
                cross_network_incident_severity::
                    deescalation_count(
                        incident_state,
                    ),

            incident_unchanged_count:
                cross_network_incident_severity::
                    unchanged_count(
                        incident_state,
                    ),

            incident_critical_count:
                cross_network_incident_severity::
                    critical_count(
                        incident_state,
                    ),
        }
    }

    // ============================================================
    // Core Getters
    // ============================================================

    public fun protocol_version(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.protocol_version
    }

    public fun snapshot_sequence(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.snapshot_sequence
    }

    public fun network_id(
        snapshot: &SecuritySnapshot,
    ): &vector<u8> {
        &snapshot.network_id
    }

    public fun domain_id(
        snapshot: &SecuritySnapshot,
    ): &vector<u8> {
        &snapshot.domain_id
    }

    public fun operator_id(
        snapshot: &SecuritySnapshot,
    ): &vector<u8> {
        &snapshot.operator_id
    }

    public fun telemetry_version(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.telemetry_version
    }

    public fun anomaly_policy_version(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.anomaly_policy_version
    }

    public fun incident_policy_version(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.incident_policy_version
    }

    public fun total_attempts(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.total_attempts
    }

    public fun total_failures(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.total_failures
    }

    public fun total_rejections(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.total_rejections
    }

    public fun total_security_violations(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.total_security_violations
    }

    public fun network_attempts(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.network_attempts
    }

    public fun domain_attempts(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.domain_attempts
    }

    public fun operator_attempts(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.operator_attempts
    }

    public fun network_anomaly_score_bps(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.network_anomaly_score_bps
    }

    public fun domain_anomaly_score_bps(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.domain_anomaly_score_bps
    }

    public fun operator_anomaly_score_bps(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.operator_anomaly_score_bps
    }

    public fun composite_anomaly_score_bps(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.composite_anomaly_score_bps
    }

    public fun current_severity(
        snapshot: &SecuritySnapshot,
    ): u8 {
        snapshot.current_severity
    }

    public fun previous_severity(
        snapshot: &SecuritySnapshot,
    ): u8 {
        snapshot.previous_severity
    }

    public fun incident_evaluation_count(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.incident_evaluation_count
    }

    public fun incident_escalation_count(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.incident_escalation_count
    }

    public fun incident_deescalation_count(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.incident_deescalation_count
    }

    public fun incident_critical_count(
        snapshot: &SecuritySnapshot,
    ): u64 {
        snapshot.incident_critical_count
    }

    // ============================================================
    // Testing
    // ============================================================

    #[test_only]
    public fun destroy_for_testing(
        snapshot: SecuritySnapshot,
    ) {
        let SecuritySnapshot {
            id,

            protocol_version: _,
            snapshot_sequence: _,

            network_id: _,
            domain_id: _,
            operator_id: _,

            telemetry_version: _,
            anomaly_policy_version: _,
            incident_policy_version: _,

            total_attempts: _,
            total_successes: _,
            total_failures: _,
            total_rejections: _,

            total_rate_violations: _,
            total_risk_violations: _,
            total_compliance_violations: _,
            total_operator_trust_violations: _,
            total_security_violations: _,

            network_attempts: _,
            network_failures: _,
            network_rejections: _,

            domain_attempts: _,
            domain_failures: _,
            domain_rejections: _,

            operator_attempts: _,
            operator_failures: _,
            operator_rejections: _,

            network_rate_violations: _,
            network_risk_violations: _,
            network_compliance_violations: _,
            network_operator_trust_violations: _,

            domain_rate_violations: _,
            domain_risk_violations: _,
            domain_compliance_violations: _,
            domain_operator_trust_violations: _,

            operator_rate_violations: _,
            operator_risk_violations: _,
            operator_compliance_violations: _,
            operator_operator_trust_violations: _,

            network_anomaly_score_bps: _,
            domain_anomaly_score_bps: _,
            operator_anomaly_score_bps: _,
            composite_anomaly_score_bps: _,

            current_severity: _,
            previous_severity: _,
            last_incident_score_bps: _,

            incident_evaluation_count: _,
            incident_escalation_count: _,
            incident_deescalation_count: _,
            incident_unchanged_count: _,
            incident_critical_count: _,
        } = snapshot;

        object::delete(id);
    }
}
