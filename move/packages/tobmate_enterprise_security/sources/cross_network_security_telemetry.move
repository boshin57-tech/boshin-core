module tobmate_enterprise_security::cross_network_security_telemetry {

    use std::vector;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    const PROTOCOL_VERSION: u64 = 1;

    const E_PAUSED: u64 = 1;
    const E_INVALID_VERSION: u64 = 2;
    const E_STATE_UNCHANGED: u64 = 3;
    const E_METRIC_NOT_FOUND: u64 = 4;
    const E_ACCOUNTING_INVARIANT: u64 = 5;

    const VIOLATION_RATE: u8 = 1;
    const VIOLATION_RISK: u8 = 2;
    const VIOLATION_COMPLIANCE: u8 = 3;
    const VIOLATION_OPERATOR_TRUST: u8 = 4;

    // ============================================================
    // Observation-only counters.
    // This module grants no execution or governance authority.
    // ============================================================

    public struct TelemetryCounters has copy, drop, store {
        attempts: u64,
        successes: u64,
        failures: u64,
        rejections: u64,
        rate_violations: u64,
        risk_violations: u64,
        compliance_violations: u64,
        operator_trust_violations: u64,
    }

    public struct ScopedTelemetryMetric has drop, store {
        scope_id: vector<u8>,
        counters: TelemetryCounters,
    }

    public struct CrossNetworkSecurityTelemetry has key, store {
        id: UID,
        version: u64,
        paused: bool,
        global: TelemetryCounters,
        network_metrics: vector<ScopedTelemetryMetric>,
        domain_metrics: vector<ScopedTelemetryMetric>,
        operator_metrics: vector<ScopedTelemetryMetric>,
    }

    public struct TelemetryCreated has copy, drop {
        version: u64,
    }

    public struct ExecutionAttemptRecorded has copy, drop {
        total_attempts: u64,
    }

    public struct ExecutionSuccessRecorded has copy, drop {
        total_successes: u64,
    }

    public struct ExecutionFailureRecorded has copy, drop {
        total_failures: u64,
    }

    public struct ExecutionRejectionRecorded has copy, drop {
        total_rejections: u64,
    }

    public struct SecurityViolationRecorded has copy, drop {
        violation_type: u8,
        total_violations_of_type: u64,
    }

    public struct TelemetryPauseChanged has copy, drop {
        paused: bool,
    }

    public struct TelemetryVersionChanged has copy, drop {
        version: u64,
    }

    public fun new(
        ctx: &mut TxContext,
    ): CrossNetworkSecurityTelemetry {
        let telemetry = CrossNetworkSecurityTelemetry {
            id: object::new(ctx),
            version: PROTOCOL_VERSION,
            paused: false,
            global: empty_counters(),
            network_metrics: vector[],
            domain_metrics: vector[],
            operator_metrics: vector[],
        };

        event::emit(TelemetryCreated {
            version: PROTOCOL_VERSION,
        });

        telemetry
    }

    fun empty_counters(): TelemetryCounters {
        TelemetryCounters {
            attempts: 0,
            successes: 0,
            failures: 0,
            rejections: 0,
            rate_violations: 0,
            risk_violations: 0,
            compliance_violations: 0,
            operator_trust_violations: 0,
        }
    }

    public fun assert_operational(
        telemetry: &CrossNetworkSecurityTelemetry,
    ) {
        assert!(!telemetry.paused, E_PAUSED);
    }

    fun find_metric_index(
        metrics: &vector<ScopedTelemetryMetric>,
        scope_id: &vector<u8>,
    ): (bool, u64) {
        let mut i = 0;
        let len = vector::length(metrics);

        while (i < len) {
            let metric = vector::borrow(metrics, i);

            if (&metric.scope_id == scope_id) {
                return (true, i)
            };

            i = i + 1;
        };

        (false, 0)
    }

    fun ensure_metric(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ): u64 {
        let (exists, index) =
            find_metric_index(metrics, &scope_id);

        if (exists) {
            return index
        };

        vector::push_back(
            metrics,
            ScopedTelemetryMetric {
                scope_id,
                counters: empty_counters(),
            },
        );

        vector::length(metrics) - 1
    }

    fun increment_attempt(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.attempts =
            metric.counters.attempts + 1;
    }

    fun increment_success(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.successes =
            metric.counters.successes + 1;
    }

    fun increment_failure(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.failures =
            metric.counters.failures + 1;
    }

    fun increment_rejection(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.rejections =
            metric.counters.rejections + 1;
    }

    fun increment_rate_violation(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.rate_violations =
            metric.counters.rate_violations + 1;
    }

    fun increment_risk_violation(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.risk_violations =
            metric.counters.risk_violations + 1;
    }

    fun increment_compliance_violation(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.compliance_violations =
            metric.counters.compliance_violations + 1;
    }

    fun increment_operator_trust_violation(
        metrics: &mut vector<ScopedTelemetryMetric>,
        scope_id: vector<u8>,
    ) {
        let index = ensure_metric(metrics, scope_id);
        let metric = vector::borrow_mut(metrics, index);
        metric.counters.operator_trust_violations =
            metric.counters.operator_trust_violations + 1;
    }

    public fun record_execution_attempt(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.attempts =
            telemetry.global.attempts + 1;

        increment_attempt(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_attempt(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_attempt(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        event::emit(ExecutionAttemptRecorded {
            total_attempts: telemetry.global.attempts,
        });
    }

    public fun record_execution_success(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.successes =
            telemetry.global.successes + 1;

        increment_success(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_success(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_success(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        assert_accounting_invariant(telemetry);

        event::emit(ExecutionSuccessRecorded {
            total_successes: telemetry.global.successes,
        });
    }

    public fun record_execution_failure(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.failures =
            telemetry.global.failures + 1;

        increment_failure(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_failure(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_failure(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        assert_accounting_invariant(telemetry);

        event::emit(ExecutionFailureRecorded {
            total_failures: telemetry.global.failures,
        });
    }

    public fun record_execution_rejection(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.rejections =
            telemetry.global.rejections + 1;

        increment_rejection(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_rejection(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_rejection(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        assert_accounting_invariant(telemetry);

        event::emit(ExecutionRejectionRecorded {
            total_rejections: telemetry.global.rejections,
        });
    }

    public fun record_rate_violation(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.rate_violations =
            telemetry.global.rate_violations + 1;

        increment_rate_violation(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_rate_violation(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_rate_violation(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        event::emit(SecurityViolationRecorded {
            violation_type: VIOLATION_RATE,
            total_violations_of_type:
                telemetry.global.rate_violations,
        });
    }

    public fun record_risk_violation(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.risk_violations =
            telemetry.global.risk_violations + 1;

        increment_risk_violation(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_risk_violation(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_risk_violation(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        event::emit(SecurityViolationRecorded {
            violation_type: VIOLATION_RISK,
            total_violations_of_type:
                telemetry.global.risk_violations,
        });
    }

    public fun record_compliance_violation(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.compliance_violations =
            telemetry.global.compliance_violations + 1;

        increment_compliance_violation(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_compliance_violation(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_compliance_violation(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        event::emit(SecurityViolationRecorded {
            violation_type: VIOLATION_COMPLIANCE,
            total_violations_of_type:
                telemetry.global.compliance_violations,
        });
    }

    public fun record_operator_trust_violation(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,
    ) {
        assert_operational(telemetry);

        telemetry.global.operator_trust_violations =
            telemetry.global.operator_trust_violations + 1;

        increment_operator_trust_violation(
            &mut telemetry.network_metrics,
            network_id,
        );
        increment_operator_trust_violation(
            &mut telemetry.domain_metrics,
            domain_id,
        );
        increment_operator_trust_violation(
            &mut telemetry.operator_metrics,
            operator_id,
        );

        event::emit(SecurityViolationRecorded {
            violation_type: VIOLATION_OPERATOR_TRUST,
            total_violations_of_type:
                telemetry.global.operator_trust_violations,
        });
    }

    public fun assert_accounting_invariant(
        telemetry: &CrossNetworkSecurityTelemetry,
    ) {
        assert!(
            telemetry.global.successes
                + telemetry.global.failures
                + telemetry.global.rejections
                <= telemetry.global.attempts,
            E_ACCOUNTING_INVARIANT,
        );
    }

    public fun set_paused(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        paused: bool,
    ) {
        assert!(
            telemetry.paused != paused,
            E_STATE_UNCHANGED,
        );

        telemetry.paused = paused;

        event::emit(TelemetryPauseChanged {
            paused,
        });
    }

    public fun set_version(
        telemetry: &mut CrossNetworkSecurityTelemetry,
        new_version: u64,
    ) {
        assert!(
            new_version > telemetry.version,
            E_INVALID_VERSION,
        );

        telemetry.version = new_version;

        event::emit(TelemetryVersionChanged {
            version: new_version,
        });
    }

    public fun version(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.version
    }

    public fun is_paused(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): bool {
        telemetry.paused
    }

    public fun total_attempts(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.attempts
    }

    public fun total_successes(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.successes
    }

    public fun total_failures(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.failures
    }

    public fun total_rejections(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.rejections
    }

    public fun total_rate_violations(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.rate_violations
    }

    public fun total_risk_violations(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.risk_violations
    }

    public fun total_compliance_violations(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.compliance_violations
    }

    public fun total_operator_trust_violations(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.operator_trust_violations
    }

    public fun total_security_violations(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        telemetry.global.rate_violations
            + telemetry.global.risk_violations
            + telemetry.global.compliance_violations
            + telemetry.global.operator_trust_violations
    }

    public fun network_metric_count(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        vector::length(&telemetry.network_metrics)
    }

    public fun domain_metric_count(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        vector::length(&telemetry.domain_metrics)
    }

    public fun operator_metric_count(
        telemetry: &CrossNetworkSecurityTelemetry,
    ): u64 {
        vector::length(&telemetry.operator_metrics)
    }

    fun scoped_counters(
        metrics: &vector<ScopedTelemetryMetric>,
        scope_id: &vector<u8>,
    ): TelemetryCounters {
        let (exists, index) =
            find_metric_index(metrics, scope_id);

        assert!(exists, E_METRIC_NOT_FOUND);

        vector::borrow(metrics, index).counters
    }

    public fun network_counters(
        telemetry: &CrossNetworkSecurityTelemetry,
        network_id: vector<u8>,
    ): TelemetryCounters {
        scoped_counters(
            &telemetry.network_metrics,
            &network_id,
        )
    }

    public fun domain_counters(
        telemetry: &CrossNetworkSecurityTelemetry,
        domain_id: vector<u8>,
    ): TelemetryCounters {
        scoped_counters(
            &telemetry.domain_metrics,
            &domain_id,
        )
    }

    public fun operator_counters(
        telemetry: &CrossNetworkSecurityTelemetry,
        operator_id: vector<u8>,
    ): TelemetryCounters {
        scoped_counters(
            &telemetry.operator_metrics,
            &operator_id,
        )
    }

    public fun counter_attempts(
        counters: &TelemetryCounters,
    ): u64 {
        counters.attempts
    }

    public(package) fun counter_successes(
        counters: &TelemetryCounters,
    ): u64 {
        counters.successes
    }

    public fun counter_failures(
        counters: &TelemetryCounters,
    ): u64 {
        counters.failures
    }

    public fun counter_rejections(
        counters: &TelemetryCounters,
    ): u64 {
        counters.rejections
    }

    public fun counter_rate_violations(
        counters: &TelemetryCounters,
    ): u64 {
        counters.rate_violations
    }

    public fun counter_risk_violations(
        counters: &TelemetryCounters,
    ): u64 {
        counters.risk_violations
    }

    public fun counter_compliance_violations(
        counters: &TelemetryCounters,
    ): u64 {
        counters.compliance_violations
    }

    public fun counter_operator_trust_violations(
        counters: &TelemetryCounters,
    ): u64 {
        counters.operator_trust_violations
    }

    public fun violation_rate(): u8 {
        VIOLATION_RATE
    }

    public fun violation_risk(): u8 {
        VIOLATION_RISK
    }

    public fun violation_compliance(): u8 {
        VIOLATION_COMPLIANCE
    }

    public fun violation_operator_trust(): u8 {
        VIOLATION_OPERATOR_TRUST
    }

    #[test_only]
    public fun new_for_testing(
        ctx: &mut TxContext,
    ): CrossNetworkSecurityTelemetry {
        new(ctx)
    }

    #[test_only]
    public fun destroy_for_testing(
        telemetry: CrossNetworkSecurityTelemetry,
    ) {
        let CrossNetworkSecurityTelemetry {
            id,
            version: _,
            paused: _,
            global: _,
            network_metrics: _,
            domain_metrics: _,
            operator_metrics: _,
        } = telemetry;

        object::delete(id);
    }
}
