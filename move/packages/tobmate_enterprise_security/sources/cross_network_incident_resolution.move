module tobmate_enterprise_security::cross_network_incident_resolution {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_enterprise_security::cross_network_emergency_control;
    use tobmate_enterprise_security::cross_network_governance_authorization;


    // ============================================================
    // Errors
    // ============================================================

    const E_NO_ACTIVE_INCIDENT: u64 = 1208201;
    const E_INCIDENT_CODE_MISMATCH: u64 = 1208202;
    const E_EMPTY_EVIDENCE: u64 = 1208203;
    const E_RESOLUTION_NOT_APPROVED: u64 = 1208204;
    const E_RESOLUTION_ALREADY_APPROVED: u64 = 1208205;
    const E_RESOLUTION_ALREADY_CONSUMED: u64 = 1208206;


    // ============================================================
    // Resolution Status
    // ============================================================

    const RESOLUTION_PENDING: u8 = 0;
    const RESOLUTION_APPROVED: u8 = 1;
    const RESOLUTION_CONSUMED: u8 = 2;


    // ============================================================
    // Resolution ID Material
    // ============================================================

    public struct ResolutionIdMaterial has drop, store {
        incident_code: vector<u8>,
        evidence_hash: vector<u8>,
        sequence: u64,
        resolved_epoch: u64,
    }


    // ============================================================
    // Resolution Record
    // ============================================================

    public struct IncidentResolutionRecord has key, store {
        id: object::UID,

        resolution_id: vector<u8>,
        incident_code: vector<u8>,
        evidence_hash: vector<u8>,

        sequence: u64,
        resolved_epoch: u64,

        status: u8,
    }


    public struct IncidentResolutionRegistry has key, store {
        id: object::UID,

        total_resolutions: u64,
        next_sequence: u64,
        version: u64,
    }


    public fun new_resolution_registry(
        ctx: &mut tx_context::TxContext,
    ): IncidentResolutionRegistry {

        IncidentResolutionRegistry {
            id: object::new(ctx),
            total_resolutions: 0,
            next_sequence: 1,
            version: 1,
        }
    }


    public fun calculate_resolution_id(
        incident_code: vector<u8>,
        evidence_hash: vector<u8>,
        sequence: u64,
        resolved_epoch: u64,
    ): vector<u8> {

        let material = ResolutionIdMaterial {
            incident_code,
            evidence_hash,
            sequence,
            resolved_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Create Resolution
    // ============================================================

    public fun create_resolution(
        registry: &mut IncidentResolutionRegistry,
        emergency:
            &cross_network_emergency_control::EmergencyControlRegistry,
        incident_code: vector<u8>,
        resolution_evidence: vector<u8>,
        ctx: &mut tx_context::TxContext,
    ): IncidentResolutionRecord {

        assert!(
            cross_network_emergency_control::
                is_incident_active(emergency),
            E_NO_ACTIVE_INCIDENT,
        );

        assert!(
            cross_network_emergency_control::
                incident_code(emergency)
                == &incident_code,
            E_INCIDENT_CODE_MISMATCH,
        );

        assert!(
            vector::length(&resolution_evidence) > 0,
            E_EMPTY_EVIDENCE,
        );

        let evidence_hash =
            hash::blake2b256(
                &resolution_evidence,
            );

        let sequence =
            registry.next_sequence;

        let resolved_epoch =
            tx_context::epoch(ctx);

        let resolution_id =
            calculate_resolution_id(
                copy incident_code,
                copy evidence_hash,
                sequence,
                resolved_epoch,
            );

        registry.total_resolutions =
            registry.total_resolutions + 1;

        registry.next_sequence =
            registry.next_sequence + 1;

        IncidentResolutionRecord {
            id: object::new(ctx),

            resolution_id,
            incident_code,
            evidence_hash,

            sequence,
            resolved_epoch,

            status: RESOLUTION_PENDING,
        }
    }


    public fun approve_resolution(
        record: &mut IncidentResolutionRecord,
    ) {

        assert!(
            record.status == RESOLUTION_PENDING,
            E_RESOLUTION_ALREADY_APPROVED,
        );

        record.status = RESOLUTION_APPROVED;
    }


    // ============================================================
    // Controlled Incident Close
    //
    // Requires:
    // - active incident
    // - approved resolution
    // - matching incident code
    // - governance INCIDENT_OFF authorization
    // ============================================================

    public fun close_incident(
        record: &mut IncidentResolutionRecord,
        authorization:
            &mut cross_network_governance_authorization::
                GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::
                EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert!(
            record.status == RESOLUTION_APPROVED,
            E_RESOLUTION_NOT_APPROVED,
        );

        assert!(
            cross_network_emergency_control::
                is_incident_active(emergency),
            E_NO_ACTIVE_INCIDENT,
        );

        assert!(
            cross_network_emergency_control::
                incident_code(emergency)
                == &record.incident_code,
            E_INCIDENT_CODE_MISMATCH,
        );

        cross_network_governance_authorization::
            execute_incident_off(
                authorization,
                emergency,
                current_epoch,
            );

        record.status = RESOLUTION_CONSUMED;
    }


    // ============================================================
    // Controlled Global Unpause
    //
    // Incident resolution must already be consumed before the
    // global execution pause can be removed.
    // ============================================================

    public fun controlled_global_unpause(
        record: &IncidentResolutionRecord,
        authorization:
            &mut cross_network_governance_authorization::
                GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::
                EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert!(
            record.status == RESOLUTION_CONSUMED,
            E_RESOLUTION_ALREADY_CONSUMED,
        );

        cross_network_governance_authorization::
            execute_global_pause_off(
                authorization,
                emergency,
                current_epoch,
            );
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun resolution_id(
        record: &IncidentResolutionRecord,
    ): &vector<u8> {
        &record.resolution_id
    }


    public fun resolution_evidence_hash(
        record: &IncidentResolutionRecord,
    ): &vector<u8> {
        &record.evidence_hash
    }


    public fun resolution_status(
        record: &IncidentResolutionRecord,
    ): u8 {
        record.status
    }


    public fun resolution_pending_status(): u8 {
        RESOLUTION_PENDING
    }


    public fun resolution_approved_status(): u8 {
        RESOLUTION_APPROVED
    }


    public fun resolution_consumed_status(): u8 {
        RESOLUTION_CONSUMED
    }


    public fun total_resolutions(
        registry: &IncidentResolutionRegistry,
    ): u64 {
        registry.total_resolutions
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_resolution_for_testing(
        record: IncidentResolutionRecord,
    ) {

        let IncidentResolutionRecord {
            id,
            resolution_id: _,
            incident_code: _,
            evidence_hash: _,
            sequence: _,
            resolved_epoch: _,
            status: _,
        } = record;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_resolution_registry_for_testing(
        registry: IncidentResolutionRegistry,
    ) {

        let IncidentResolutionRegistry {
            id,
            total_resolutions: _,
            next_sequence: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
