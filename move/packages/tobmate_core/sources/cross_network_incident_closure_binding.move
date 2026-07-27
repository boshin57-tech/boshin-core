module tobmate_core::cross_network_incident_closure_binding {

    use tobmate_core::cross_network_security_snapshot;
    use tobmate_core::cross_network_security_audit_export;
    use tobmate_core::cross_network_incident_closure_governance;
    use tobmate_core::cross_network_security_orchestrator;


    // ============================================================
    // Errors
    // ============================================================

    const E_EXPORT_SNAPSHOT_MISMATCH: u64 = 1207701;
    const E_RECEIPT_SNAPSHOT_MISMATCH: u64 = 1207702;
    const E_AUDIT_DIGEST_MISMATCH: u64 = 1207703;
    const E_RECEIPT_NOT_FINALIZED: u64 = 1207704;


    // ============================================================
    // Audit Export / Snapshot Binding
    // ============================================================

    public fun assert_export_snapshot_binding(
        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export:
            &cross_network_security_audit_export::
                AuditExportRecord,
    ) {

        assert!(
            cross_network_security_audit_export::
                snapshot_sequence(export)
                ==
            cross_network_security_snapshot::
                snapshot_sequence(snapshot),
            E_EXPORT_SNAPSHOT_MISMATCH,
        );

        cross_network_security_audit_export::
            verify_export(
                export,
                snapshot,
            );
    }


    // ============================================================
    // Closure Receipt / Audit Export Binding
    // ============================================================

    public fun assert_receipt_export_binding(
        receipt:
            &cross_network_incident_closure_governance::
                IncidentClosureReceipt,

        export:
            &cross_network_security_audit_export::
                AuditExportRecord,
    ) {

        assert!(
            cross_network_incident_closure_governance::
                receipt_status(receipt)
                ==
            cross_network_incident_closure_governance::
                status_finalized(),
            E_RECEIPT_NOT_FINALIZED,
        );

        assert!(
            cross_network_incident_closure_governance::
                receipt_snapshot_sequence(receipt)
                ==
            cross_network_security_audit_export::
                snapshot_sequence(export),
            E_RECEIPT_SNAPSHOT_MISMATCH,
        );

        assert!(
            *cross_network_incident_closure_governance::
                receipt_audit_digest(receipt)
                ==
            *cross_network_security_audit_export::
                audit_digest(export),
            E_AUDIT_DIGEST_MISMATCH,
        );
    }


    // ============================================================
    // Full Closure Evidence Binding
    // ============================================================

    public fun assert_full_closure_binding(
        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export:
            &cross_network_security_audit_export::
                AuditExportRecord,

        receipt:
            &cross_network_incident_closure_governance::
                IncidentClosureReceipt,
    ) {

        assert_export_snapshot_binding(
            snapshot,
            export,
        );

        cross_network_incident_closure_governance::
            verify_receipt(
                receipt,
            );

        assert_receipt_export_binding(
            receipt,
            export,
        );
    }


    // ============================================================
    // Confirm Closure Evidence Into Orchestrator
    // ============================================================

    public fun confirm_closure(
        state:
            &mut cross_network_security_orchestrator::
                SecurityOrchestrationState,

        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export:
            &cross_network_security_audit_export::
                AuditExportRecord,

        receipt:
            &cross_network_incident_closure_governance::
                IncidentClosureReceipt,
    ) {

        assert_full_closure_binding(
            snapshot,
            export,
            receipt,
        );

        cross_network_security_orchestrator::
            confirm_closure_evidence(
                state,
                *cross_network_incident_closure_governance::
                    closure_id(receipt),
            );
    }


    // ============================================================
    // Boolean Inspection Helpers
    // ============================================================

    public fun export_snapshot_bound(
        snapshot:
            &cross_network_security_snapshot::
                SecuritySnapshot,

        export:
            &cross_network_security_audit_export::
                AuditExportRecord,
    ): bool {

        cross_network_security_audit_export::
            snapshot_sequence(export)
            ==
        cross_network_security_snapshot::
            snapshot_sequence(snapshot)
        &&
        cross_network_security_audit_export::
            export_matches_snapshot(
                export,
                snapshot,
            )
    }


    public fun receipt_export_bound(
        receipt:
            &cross_network_incident_closure_governance::
                IncidentClosureReceipt,

        export:
            &cross_network_security_audit_export::
                AuditExportRecord,
    ): bool {

        cross_network_incident_closure_governance::
            receipt_status(receipt)
            ==
        cross_network_incident_closure_governance::
            status_finalized()
        &&
        cross_network_incident_closure_governance::
            receipt_snapshot_sequence(receipt)
            ==
        cross_network_security_audit_export::
            snapshot_sequence(export)
        &&
        *cross_network_incident_closure_governance::
            receipt_audit_digest(receipt)
            ==
        *cross_network_security_audit_export::
            audit_digest(export)
    }
}
