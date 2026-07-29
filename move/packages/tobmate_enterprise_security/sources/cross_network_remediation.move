module tobmate_enterprise_security::cross_network_remediation {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_enterprise_security::cross_network_recovery_control;
    use tobmate_enterprise_security::cross_network_recovery_authorization;


    // ============================================================
    // Errors
    // ============================================================

    const E_AUTH_NOT_CONSUMED: u64 = 1207201;
    const E_ZERO_REMEDIATION_AMOUNT: u64 = 1207202;
    const E_AMOUNT_EXCEEDS_AUTHORIZATION: u64 = 1207203;
    const E_CASE_ID_MISMATCH: u64 = 1207204;
    const E_EMPTY_REMEDIATION_TYPE: u64 = 1207205;


    // ============================================================
    // Remediation ID Material
    // ============================================================

    public struct RemediationIdMaterial has drop, store {
        authorization_id: vector<u8>,
        case_id: vector<u8>,
        remediation_type: vector<u8>,
        remediation_amount: u64,
        sequence: u64,
        recorded_epoch: u64,
    }


    // ============================================================
    // Immutable Remediation Record
    // ============================================================

    public struct RemediationRecord has key, store {
        id: object::UID,

        remediation_id: vector<u8>,
        authorization_id: vector<u8>,
        case_id: vector<u8>,

        remediation_type: vector<u8>,
        remediation_amount: u64,

        sequence: u64,
        recorded_epoch: u64,
    }


    // ============================================================
    // Registry
    // ============================================================

    public struct RemediationRegistry has key, store {
        id: object::UID,

        total_records: u64,
        next_sequence: u64,
        version: u64,
    }


    public fun new_remediation_registry(
        ctx: &mut tx_context::TxContext,
    ): RemediationRegistry {

        RemediationRegistry {
            id: object::new(ctx),
            total_records: 0,
            next_sequence: 1,
            version: 1,
        }
    }


    // ============================================================
    // Deterministic Remediation ID
    // ============================================================

    public fun calculate_remediation_id(
        authorization_id: vector<u8>,
        case_id: vector<u8>,
        remediation_type: vector<u8>,
        remediation_amount: u64,
        sequence: u64,
        recorded_epoch: u64,
    ): vector<u8> {

        let material = RemediationIdMaterial {
            authorization_id,
            case_id,
            remediation_type,
            remediation_amount,
            sequence,
            recorded_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Create Remediation Record
    //
    // Authorization must already be consumed.
    // ============================================================

    public fun create_remediation_record(
        registry: &mut RemediationRegistry,
        authorization:
            &cross_network_recovery_authorization::RecoveryAuthorization,
        case: &cross_network_recovery_control::RecoveryCase,
        remediation_type: vector<u8>,
        remediation_amount: u64,
        ctx: &mut tx_context::TxContext,
    ): RemediationRecord {

        assert!(
            cross_network_recovery_authorization::
                is_authorization_consumed(
                    authorization,
                ),
            E_AUTH_NOT_CONSUMED,
        );

        assert!(
            vector::length(&remediation_type) > 0,
            E_EMPTY_REMEDIATION_TYPE,
        );

        assert!(
            remediation_amount > 0,
            E_ZERO_REMEDIATION_AMOUNT,
        );

        assert!(
            remediation_amount
                <= cross_network_recovery_authorization::
                    authorized_amount(
                        authorization,
                    ),
            E_AMOUNT_EXCEEDS_AUTHORIZATION,
        );

        let auth_case_id =
            cross_network_recovery_authorization::
                authorization_case_id(
                    authorization,
                );

        let case_id_ref =
            cross_network_recovery_control::case_id(
                case,
            );

        assert!(
            auth_case_id == case_id_ref,
            E_CASE_ID_MISMATCH,
        );

        let authorization_id =
            *cross_network_recovery_authorization::
                authorization_id(
                    authorization,
                );

        let case_id =
            *case_id_ref;

        let sequence =
            registry.next_sequence;

        let recorded_epoch =
            tx_context::epoch(ctx);

        let remediation_id =
            calculate_remediation_id(
                copy authorization_id,
                copy case_id,
                copy remediation_type,
                remediation_amount,
                sequence,
                recorded_epoch,
            );

        registry.total_records =
            registry.total_records + 1;

        registry.next_sequence =
            registry.next_sequence + 1;

        RemediationRecord {
            id: object::new(ctx),

            remediation_id,
            authorization_id,
            case_id,

            remediation_type,
            remediation_amount,

            sequence,
            recorded_epoch,
        }
    }


    // ============================================================
    // Audit Validation
    // ============================================================

    public fun assert_remediation_binding(
        record: &RemediationRecord,
        authorization:
            &cross_network_recovery_authorization::RecoveryAuthorization,
        case: &cross_network_recovery_control::RecoveryCase,
    ) {

        let authorization_id_ref =
            cross_network_recovery_authorization::
                authorization_id(
                    authorization,
                );

        assert!(
            &record.authorization_id
                == authorization_id_ref,
            E_CASE_ID_MISMATCH,
        );

        let case_id_ref =
            cross_network_recovery_control::case_id(
                case,
            );

        assert!(
            &record.case_id == case_id_ref,
            E_CASE_ID_MISMATCH,
        );

        let auth_case_id =
            cross_network_recovery_authorization::
                authorization_case_id(
                    authorization,
                );

        assert!(
            auth_case_id == case_id_ref,
            E_CASE_ID_MISMATCH,
        );
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun remediation_id(
        record: &RemediationRecord,
    ): &vector<u8> {
        &record.remediation_id
    }


    public fun remediation_authorization_id(
        record: &RemediationRecord,
    ): &vector<u8> {
        &record.authorization_id
    }


    public fun remediation_case_id(
        record: &RemediationRecord,
    ): &vector<u8> {
        &record.case_id
    }


    public fun remediation_type(
        record: &RemediationRecord,
    ): &vector<u8> {
        &record.remediation_type
    }


    public fun remediation_amount(
        record: &RemediationRecord,
    ): u64 {
        record.remediation_amount
    }


    public fun remediation_sequence(
        record: &RemediationRecord,
    ): u64 {
        record.sequence
    }


    public fun remediation_recorded_epoch(
        record: &RemediationRecord,
    ): u64 {
        record.recorded_epoch
    }


    public fun total_remediation_records(
        registry: &RemediationRegistry,
    ): u64 {
        registry.total_records
    }


    // ============================================================
    // Test-only cleanup
    // ============================================================

    #[test_only]
    public fun destroy_remediation_record_for_testing(
        record: RemediationRecord,
    ) {

        let RemediationRecord {
            id,
            remediation_id: _,
            authorization_id: _,
            case_id: _,
            remediation_type: _,
            remediation_amount: _,
            sequence: _,
            recorded_epoch: _,
        } = record;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_remediation_registry_for_testing(
        registry: RemediationRegistry,
    ) {

        let RemediationRegistry {
            id,
            total_records: _,
            next_sequence: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
