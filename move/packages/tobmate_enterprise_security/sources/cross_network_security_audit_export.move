module tobmate_enterprise_security::cross_network_security_audit_export {

    use std::bcs;
    use sui::hash;
    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    use tobmate_enterprise_security::cross_network_security_snapshot;

    const PROTOCOL_VERSION: u64 = 1;

    const E_DIGEST_MISMATCH: u64 = 1;
    const E_INVALID_EXPORT_SEQUENCE: u64 = 2;

    // ============================================================
    // Deterministic Audit Digest Material
    //
    // The exact field order is part of the digest contract.
    // ============================================================

    public struct AuditDigestMaterial has drop, store {
        protocol_version: u64,
        export_sequence: u64,
        snapshot_sequence: u64,

        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,

        telemetry_version: u64,
        anomaly_policy_version: u64,
        incident_policy_version: u64,

        total_attempts: u64,
        total_failures: u64,
        total_rejections: u64,
        total_security_violations: u64,

        network_anomaly_score_bps: u64,
        domain_anomaly_score_bps: u64,
        operator_anomaly_score_bps: u64,
        composite_anomaly_score_bps: u64,

        current_severity: u8,
        previous_severity: u8,

        incident_evaluation_count: u64,
        incident_escalation_count: u64,
        incident_deescalation_count: u64,
        incident_critical_count: u64,
    }

    // ============================================================
    // Audit Export Record
    //
    // Observation/evidence only.
    // No execution or governance authority.
    // ============================================================

    public struct AuditExportRecord has key, store {
        id: UID,

        protocol_version: u64,
        export_sequence: u64,
        snapshot_sequence: u64,

        network_id: vector<u8>,
        domain_id: vector<u8>,
        operator_id: vector<u8>,

        telemetry_version: u64,
        anomaly_policy_version: u64,
        incident_policy_version: u64,

        composite_anomaly_score_bps: u64,
        current_severity: u8,

        audit_digest: vector<u8>,
    }

    // ============================================================
    // Material Construction
    // ============================================================

    public fun build_material(
        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export_sequence: u64,
    ): AuditDigestMaterial {

        assert!(
            export_sequence > 0,
            E_INVALID_EXPORT_SEQUENCE,
        );

        AuditDigestMaterial {
            protocol_version:
                PROTOCOL_VERSION,

            export_sequence,

            snapshot_sequence:
                cross_network_security_snapshot::
                    snapshot_sequence(snapshot),

            network_id:
                *cross_network_security_snapshot::
                    network_id(snapshot),

            domain_id:
                *cross_network_security_snapshot::
                    domain_id(snapshot),

            operator_id:
                *cross_network_security_snapshot::
                    operator_id(snapshot),

            telemetry_version:
                cross_network_security_snapshot::
                    telemetry_version(snapshot),

            anomaly_policy_version:
                cross_network_security_snapshot::
                    anomaly_policy_version(snapshot),

            incident_policy_version:
                cross_network_security_snapshot::
                    incident_policy_version(snapshot),

            total_attempts:
                cross_network_security_snapshot::
                    total_attempts(snapshot),

            total_failures:
                cross_network_security_snapshot::
                    total_failures(snapshot),

            total_rejections:
                cross_network_security_snapshot::
                    total_rejections(snapshot),

            total_security_violations:
                cross_network_security_snapshot::
                    total_security_violations(snapshot),

            network_anomaly_score_bps:
                cross_network_security_snapshot::
                    network_anomaly_score_bps(snapshot),

            domain_anomaly_score_bps:
                cross_network_security_snapshot::
                    domain_anomaly_score_bps(snapshot),

            operator_anomaly_score_bps:
                cross_network_security_snapshot::
                    operator_anomaly_score_bps(snapshot),

            composite_anomaly_score_bps:
                cross_network_security_snapshot::
                    composite_anomaly_score_bps(snapshot),

            current_severity:
                cross_network_security_snapshot::
                    current_severity(snapshot),

            previous_severity:
                cross_network_security_snapshot::
                    previous_severity(snapshot),

            incident_evaluation_count:
                cross_network_security_snapshot::
                    incident_evaluation_count(snapshot),

            incident_escalation_count:
                cross_network_security_snapshot::
                    incident_escalation_count(snapshot),

            incident_deescalation_count:
                cross_network_security_snapshot::
                    incident_deescalation_count(snapshot),

            incident_critical_count:
                cross_network_security_snapshot::
                    incident_critical_count(snapshot),
        }
    }

    // ============================================================
    // Deterministic Digest
    // ============================================================

    public fun digest_material(
        material: &AuditDigestMaterial,
    ): vector<u8> {

        hash::blake2b256(
            &bcs::to_bytes(material),
        )
    }

    public fun snapshot_digest(
        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export_sequence: u64,
    ): vector<u8> {

        let material =
            build_material(
                snapshot,
                export_sequence,
            );

        digest_material(&material)
    }

    // ============================================================
    // Export Record
    // ============================================================

    public fun create_export(
        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export_sequence: u64,

        ctx: &mut TxContext,
    ): AuditExportRecord {

        let digest =
            snapshot_digest(
                snapshot,
                export_sequence,
            );

        AuditExportRecord {
            id: object::new(ctx),

            protocol_version:
                PROTOCOL_VERSION,

            export_sequence,

            snapshot_sequence:
                cross_network_security_snapshot::
                    snapshot_sequence(snapshot),

            network_id:
                *cross_network_security_snapshot::
                    network_id(snapshot),

            domain_id:
                *cross_network_security_snapshot::
                    domain_id(snapshot),

            operator_id:
                *cross_network_security_snapshot::
                    operator_id(snapshot),

            telemetry_version:
                cross_network_security_snapshot::
                    telemetry_version(snapshot),

            anomaly_policy_version:
                cross_network_security_snapshot::
                    anomaly_policy_version(snapshot),

            incident_policy_version:
                cross_network_security_snapshot::
                    incident_policy_version(snapshot),

            composite_anomaly_score_bps:
                cross_network_security_snapshot::
                    composite_anomaly_score_bps(snapshot),

            current_severity:
                cross_network_security_snapshot::
                    current_severity(snapshot),

            audit_digest:
                digest,
        }
    }

    // ============================================================
    // Digest Verification
    // ============================================================

    public fun verify_export(
        record: &AuditExportRecord,

        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,
    ) {

        let expected =
            snapshot_digest(
                snapshot,
                record.export_sequence,
            );

        assert!(
            expected == record.audit_digest,
            E_DIGEST_MISMATCH,
        );
    }

    public fun export_matches_snapshot(
        record: &AuditExportRecord,

        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,
    ): bool {

        let expected =
            snapshot_digest(
                snapshot,
                record.export_sequence,
            );

        expected == record.audit_digest
    }

    // ============================================================
    // Getters
    // ============================================================

    public fun protocol_version(
        record: &AuditExportRecord,
    ): u64 {
        record.protocol_version
    }

    public fun export_sequence(
        record: &AuditExportRecord,
    ): u64 {
        record.export_sequence
    }

    public fun snapshot_sequence(
        record: &AuditExportRecord,
    ): u64 {
        record.snapshot_sequence
    }

    public fun network_id(
        record: &AuditExportRecord,
    ): &vector<u8> {
        &record.network_id
    }

    public fun domain_id(
        record: &AuditExportRecord,
    ): &vector<u8> {
        &record.domain_id
    }

    public fun operator_id(
        record: &AuditExportRecord,
    ): &vector<u8> {
        &record.operator_id
    }

    public fun telemetry_version(
        record: &AuditExportRecord,
    ): u64 {
        record.telemetry_version
    }

    public fun anomaly_policy_version(
        record: &AuditExportRecord,
    ): u64 {
        record.anomaly_policy_version
    }

    public fun incident_policy_version(
        record: &AuditExportRecord,
    ): u64 {
        record.incident_policy_version
    }

    public fun composite_anomaly_score_bps(
        record: &AuditExportRecord,
    ): u64 {
        record.composite_anomaly_score_bps
    }

    public fun current_severity(
        record: &AuditExportRecord,
    ): u8 {
        record.current_severity
    }

    public fun audit_digest(
        record: &AuditExportRecord,
    ): &vector<u8> {
        &record.audit_digest
    }

    // ============================================================
    // Test Helpers
    // ============================================================

    #[test_only]
    public fun destroy_for_testing(
        record: AuditExportRecord,
    ) {

        let AuditExportRecord {
            id,

            protocol_version: _,
            export_sequence: _,
            snapshot_sequence: _,

            network_id: _,
            domain_id: _,
            operator_id: _,

            telemetry_version: _,
            anomaly_policy_version: _,
            incident_policy_version: _,

            composite_anomaly_score_bps: _,
            current_severity: _,

            audit_digest: _,
        } = record;

        object::delete(id);
    }

    #[test_only]
    public fun tamper_digest_for_testing(
        record: &mut AuditExportRecord,
        digest: vector<u8>,
    ) {
        record.audit_digest = digest;
    }
}
