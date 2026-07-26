module tobmate_core::cross_network_recovery_authorization {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_core::cross_network_recovery_control;


    // ============================================================
    // Errors
    // ============================================================

    const E_CASE_NOT_APPROVED: u64 = 1207101;
    const E_ZERO_AUTHORIZED_AMOUNT: u64 = 1207102;
    const E_AMOUNT_EXCEEDS_CASE: u64 = 1207103;
    const E_AUTH_ALREADY_CONSUMED: u64 = 1207104;
    const E_CASE_ID_MISMATCH: u64 = 1207105;


    // ============================================================
    // Authorization Status
    // ============================================================

    const AUTH_PENDING: u8 = 0;
    const AUTH_CONSUMED: u8 = 1;


    // ============================================================
    // Authorization ID Material
    // ============================================================

    public struct AuthorizationIdMaterial has drop, store {
        case_id: vector<u8>,
        authorized_amount: u64,
        sequence: u64,
        issued_epoch: u64,
    }


    // ============================================================
    // Recovery Authorization
    // ============================================================

    public struct RecoveryAuthorization has key, store {
        id: object::UID,

        authorization_id: vector<u8>,
        case_id: vector<u8>,

        authorized_amount: u64,

        sequence: u64,
        issued_epoch: u64,

        status: u8,
    }


    // ============================================================
    // Authorization Registry
    // ============================================================

    public struct RecoveryAuthorizationRegistry has key, store {
        id: object::UID,

        total_authorizations: u64,
        next_sequence: u64,
        version: u64,
    }


    public fun new_authorization_registry(
        ctx: &mut tx_context::TxContext,
    ): RecoveryAuthorizationRegistry {

        RecoveryAuthorizationRegistry {
            id: object::new(ctx),
            total_authorizations: 0,
            next_sequence: 1,
            version: 1,
        }
    }


    // ============================================================
    // Deterministic Authorization ID
    // ============================================================

    public fun calculate_authorization_id(
        case_id: vector<u8>,
        authorized_amount: u64,
        sequence: u64,
        issued_epoch: u64,
    ): vector<u8> {

        let material = AuthorizationIdMaterial {
            case_id,
            authorized_amount,
            sequence,
            issued_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Issue Authorization
    //
    // Only APPROVED recovery cases may issue authorization.
    // ============================================================

    public fun issue_authorization(
        registry: &mut RecoveryAuthorizationRegistry,
        case: &cross_network_recovery_control::RecoveryCase,
        authorized_amount: u64,
        ctx: &mut tx_context::TxContext,
    ): RecoveryAuthorization {

        assert!(
            cross_network_recovery_control::case_status(case)
                == cross_network_recovery_control::
                    case_approved_status(),
            E_CASE_NOT_APPROVED,
        );

        assert!(
            authorized_amount > 0,
            E_ZERO_AUTHORIZED_AMOUNT,
        );

        assert!(
            authorized_amount
                <= cross_network_recovery_control::
                    case_requested_amount(case),
            E_AMOUNT_EXCEEDS_CASE,
        );

        let case_id_ref =
            cross_network_recovery_control::case_id(case);

        let case_id =
            *case_id_ref;

        let sequence =
            registry.next_sequence;

        let issued_epoch =
            tx_context::epoch(ctx);

        let authorization_id =
            calculate_authorization_id(
                copy case_id,
                authorized_amount,
                sequence,
                issued_epoch,
            );

        registry.total_authorizations =
            registry.total_authorizations + 1;

        registry.next_sequence =
            registry.next_sequence + 1;

        RecoveryAuthorization {
            id: object::new(ctx),

            authorization_id,
            case_id,

            authorized_amount,
            sequence,
            issued_epoch,

            status: AUTH_PENDING,
        }
    }


    // ============================================================
    // Case Binding
    // ============================================================

    public fun assert_authorization_case_binding(
        authorization: &RecoveryAuthorization,
        case: &cross_network_recovery_control::RecoveryCase,
    ) {

        let case_id_ref =
            cross_network_recovery_control::case_id(case);

        assert!(
            &authorization.case_id == case_id_ref,
            E_CASE_ID_MISMATCH,
        );

        assert!(
            cross_network_recovery_control::case_status(case)
                == cross_network_recovery_control::
                    case_approved_status(),
            E_CASE_NOT_APPROVED,
        );
    }


    // ============================================================
    // Consume Once
    //
    // Part 7-C compensation/remediation must call this before
    // producing compensation evidence.
    // ============================================================

    public fun consume_authorization(
        authorization: &mut RecoveryAuthorization,
        case: &cross_network_recovery_control::RecoveryCase,
    ) {

        assert_authorization_case_binding(
            authorization,
            case,
        );

        assert!(
            authorization.status == AUTH_PENDING,
            E_AUTH_ALREADY_CONSUMED,
        );

        authorization.status = AUTH_CONSUMED;
    }


    public fun is_authorization_consumed(
        authorization: &RecoveryAuthorization,
    ): bool {
        authorization.status == AUTH_CONSUMED
    }


    public fun authorization_id(
        authorization: &RecoveryAuthorization,
    ): &vector<u8> {
        &authorization.authorization_id
    }


    public fun authorization_case_id(
        authorization: &RecoveryAuthorization,
    ): &vector<u8> {
        &authorization.case_id
    }


    public fun authorized_amount(
        authorization: &RecoveryAuthorization,
    ): u64 {
        authorization.authorized_amount
    }


    public fun authorization_status(
        authorization: &RecoveryAuthorization,
    ): u8 {
        authorization.status
    }


    public fun authorization_pending_status(): u8 {
        AUTH_PENDING
    }


    public fun authorization_consumed_status(): u8 {
        AUTH_CONSUMED
    }


    public fun total_authorizations(
        registry: &RecoveryAuthorizationRegistry,
    ): u64 {
        registry.total_authorizations
    }


    #[test_only]
    public fun destroy_authorization_for_testing(
        authorization: RecoveryAuthorization,
    ) {

        let RecoveryAuthorization {
            id,
            authorization_id: _,
            case_id: _,
            authorized_amount: _,
            sequence: _,
            issued_epoch: _,
            status: _,
        } = authorization;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_authorization_registry_for_testing(
        registry: RecoveryAuthorizationRegistry,
    ) {

        let RecoveryAuthorizationRegistry {
            id,
            total_authorizations: _,
            next_sequence: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
