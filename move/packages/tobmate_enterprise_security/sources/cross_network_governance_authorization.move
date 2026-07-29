module tobmate_enterprise_security::cross_network_governance_authorization {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_enterprise_security::cross_network_emergency_control;


    // ============================================================
    // Error Codes
    // ============================================================

    const E_INVALID_ACTION_TYPE: u64 = 1208101;
    const E_AUTH_ALREADY_CONSUMED: u64 = 1208102;
    const E_AUTH_EXPIRED: u64 = 1208103;
    const E_ACTION_MISMATCH: u64 = 1208104;
    const E_OPERATOR_TARGET_MISMATCH: u64 = 1208105;
    const E_INCIDENT_CODE_MISMATCH: u64 = 1208106;
    const E_INVALID_EXPIRY: u64 = 1208107;


    // ============================================================
    // Governance Action Types
    // ============================================================

    const ACTION_GLOBAL_PAUSE_ON: u8 = 1;
    const ACTION_GLOBAL_PAUSE_OFF: u8 = 2;

    const ACTION_RECOVERY_FREEZE_ON: u8 = 3;
    const ACTION_RECOVERY_FREEZE_OFF: u8 = 4;

    const ACTION_INCIDENT_ON: u8 = 5;
    const ACTION_INCIDENT_OFF: u8 = 6;

    const ACTION_OPERATOR_SUSPEND: u8 = 7;
    const ACTION_OPERATOR_RESTORE: u8 = 8;


    // ============================================================
    // Authorization ID Material
    // ============================================================

    public struct GovernanceAuthorizationIdMaterial has drop, store {
        action_type: u8,
        operator_target: address,
        incident_code: vector<u8>,

        sequence: u64,
        issued_epoch: u64,
        expiry_epoch: u64,
    }


    // ============================================================
    // Governance Authorization
    // ============================================================

    public struct GovernanceAuthorization has key, store {
        id: object::UID,

        authorization_id: vector<u8>,

        action_type: u8,
        operator_target: address,
        incident_code: vector<u8>,

        sequence: u64,
        issued_epoch: u64,
        expiry_epoch: u64,

        consumed: bool,
    }


    // ============================================================
    // Authorization Registry
    // ============================================================

    public struct GovernanceAuthorizationRegistry has key, store {
        id: object::UID,

        total_authorizations: u64,
        next_sequence: u64,
        version: u64,
    }


    public fun new_governance_authorization_registry(
        ctx: &mut tx_context::TxContext,
    ): GovernanceAuthorizationRegistry {

        GovernanceAuthorizationRegistry {
            id: object::new(ctx),
            total_authorizations: 0,
            next_sequence: 1,
            version: 1,
        }
    }


    // ============================================================
    // Action Validation
    // ============================================================

    fun assert_valid_action_type(
        action_type: u8,
    ) {

        assert!(
            action_type >= ACTION_GLOBAL_PAUSE_ON
                && action_type <= ACTION_OPERATOR_RESTORE,
            E_INVALID_ACTION_TYPE,
        );
    }


    // ============================================================
    // Deterministic Authorization ID
    // ============================================================

    public fun calculate_governance_authorization_id(
        action_type: u8,
        operator_target: address,
        incident_code: vector<u8>,
        sequence: u64,
        issued_epoch: u64,
        expiry_epoch: u64,
    ): vector<u8> {

        assert_valid_action_type(action_type);

        let material = GovernanceAuthorizationIdMaterial {
            action_type,
            operator_target,
            incident_code,
            sequence,
            issued_epoch,
            expiry_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Issue Governance Authorization
    // ============================================================

    public fun issue_governance_authorization(
        registry: &mut GovernanceAuthorizationRegistry,
        action_type: u8,
        operator_target: address,
        incident_code: vector<u8>,
        expiry_epoch: u64,
        ctx: &mut tx_context::TxContext,
    ): GovernanceAuthorization {

        assert_valid_action_type(action_type);

        let issued_epoch =
            tx_context::epoch(ctx);

        assert!(
            expiry_epoch >= issued_epoch,
            E_INVALID_EXPIRY,
        );

        let sequence =
            registry.next_sequence;

        let authorization_id =
            calculate_governance_authorization_id(
                action_type,
                operator_target,
                copy incident_code,
                sequence,
                issued_epoch,
                expiry_epoch,
            );

        registry.total_authorizations =
            registry.total_authorizations + 1;

        registry.next_sequence =
            registry.next_sequence + 1;

        GovernanceAuthorization {
            id: object::new(ctx),

            authorization_id,

            action_type,
            operator_target,
            incident_code,

            sequence,
            issued_epoch,
            expiry_epoch,

            consumed: false,
        }
    }


    // ============================================================
    // Authorization Guard
    // ============================================================

    fun assert_authorization_valid(
        authorization: &GovernanceAuthorization,
        expected_action_type: u8,
        current_epoch: u64,
    ) {

        assert!(
            !authorization.consumed,
            E_AUTH_ALREADY_CONSUMED,
        );

        assert!(
            current_epoch <= authorization.expiry_epoch,
            E_AUTH_EXPIRED,
        );

        assert!(
            authorization.action_type == expected_action_type,
            E_ACTION_MISMATCH,
        );
    }


    // ============================================================
    // Consume Authorization
    // ============================================================

    fun consume_authorization(
        authorization: &mut GovernanceAuthorization,
    ) {

        assert!(
            !authorization.consumed,
            E_AUTH_ALREADY_CONSUMED,
        );

        authorization.consumed = true;
    }


    // ============================================================
    // Global Pause ON
    // ============================================================

    public fun execute_global_pause_on(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_GLOBAL_PAUSE_ON,
            current_epoch,
        );

        cross_network_emergency_control::
            activate_global_pause(
                emergency,
            );

        consume_authorization(
            authorization,
        );
    }


    // ============================================================
    // Global Pause OFF
    // ============================================================

    public fun execute_global_pause_off(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_GLOBAL_PAUSE_OFF,
            current_epoch,
        );

        cross_network_emergency_control::
            deactivate_global_pause(
                emergency,
            );

        consume_authorization(
            authorization,
        );
    }


    // ============================================================
    // Recovery Freeze ON / OFF
    // ============================================================

    public fun execute_recovery_freeze_on(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_RECOVERY_FREEZE_ON,
            current_epoch,
        );

        cross_network_emergency_control::
            activate_recovery_freeze(
                emergency,
            );

        consume_authorization(
            authorization,
        );
    }


    public fun execute_recovery_freeze_off(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_RECOVERY_FREEZE_OFF,
            current_epoch,
        );

        cross_network_emergency_control::
            deactivate_recovery_freeze(
                emergency,
            );

        consume_authorization(
            authorization,
        );
    }


    // ============================================================
    // Incident ON / OFF
    // ============================================================

    public fun execute_incident_on(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        incident_code: vector<u8>,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_INCIDENT_ON,
            current_epoch,
        );

        assert!(
            authorization.incident_code == incident_code,
            E_INCIDENT_CODE_MISMATCH,
        );

        cross_network_emergency_control::
            activate_incident_mode(
                emergency,
                incident_code,
            );

        consume_authorization(
            authorization,
        );
    }


    public fun execute_incident_off(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_INCIDENT_OFF,
            current_epoch,
        );

        cross_network_emergency_control::
            deactivate_incident_mode(
                emergency,
            );

        consume_authorization(
            authorization,
        );
    }


    // ============================================================
    // Operator Suspend / Restore
    // ============================================================

    public fun execute_operator_suspend(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        operator: address,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_OPERATOR_SUSPEND,
            current_epoch,
        );

        assert!(
            authorization.operator_target == operator,
            E_OPERATOR_TARGET_MISMATCH,
        );

        cross_network_emergency_control::
            suspend_operator(
                emergency,
                operator,
            );

        consume_authorization(
            authorization,
        );
    }


    public fun execute_operator_restore(
        authorization: &mut GovernanceAuthorization,
        emergency:
            &mut cross_network_emergency_control::EmergencyControlRegistry,
        operator: address,
        current_epoch: u64,
    ) {

        assert_authorization_valid(
            authorization,
            ACTION_OPERATOR_RESTORE,
            current_epoch,
        );

        assert!(
            authorization.operator_target == operator,
            E_OPERATOR_TARGET_MISMATCH,
        );

        cross_network_emergency_control::
            restore_operator(
                emergency,
                operator,
            );

        consume_authorization(
            authorization,
        );
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun is_consumed(
        authorization: &GovernanceAuthorization,
    ): bool {
        authorization.consumed
    }


    public fun governance_action_type(
        authorization: &GovernanceAuthorization,
    ): u8 {
        authorization.action_type
    }


    public fun governance_authorization_id(
        authorization: &GovernanceAuthorization,
    ): &vector<u8> {
        &authorization.authorization_id
    }


    public fun governance_operator_target(
        authorization: &GovernanceAuthorization,
    ): address {
        authorization.operator_target
    }


    public fun governance_expiry_epoch(
        authorization: &GovernanceAuthorization,
    ): u64 {
        authorization.expiry_epoch
    }


    public fun total_governance_authorizations(
        registry: &GovernanceAuthorizationRegistry,
    ): u64 {
        registry.total_authorizations
    }


    public fun action_global_pause_on(): u8 {
        ACTION_GLOBAL_PAUSE_ON
    }


    public fun action_global_pause_off(): u8 {
        ACTION_GLOBAL_PAUSE_OFF
    }


    public fun action_recovery_freeze_on(): u8 {
        ACTION_RECOVERY_FREEZE_ON
    }


    public fun action_recovery_freeze_off(): u8 {
        ACTION_RECOVERY_FREEZE_OFF
    }


    public fun action_incident_on(): u8 {
        ACTION_INCIDENT_ON
    }


    public fun action_incident_off(): u8 {
        ACTION_INCIDENT_OFF
    }


    public fun action_operator_suspend(): u8 {
        ACTION_OPERATOR_SUSPEND
    }


    public fun action_operator_restore(): u8 {
        ACTION_OPERATOR_RESTORE
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_governance_authorization_for_testing(
        authorization: GovernanceAuthorization,
    ) {

        let GovernanceAuthorization {
            id,
            authorization_id: _,
            action_type: _,
            operator_target: _,
            incident_code: _,
            sequence: _,
            issued_epoch: _,
            expiry_epoch: _,
            consumed: _,
        } = authorization;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_governance_registry_for_testing(
        registry: GovernanceAuthorizationRegistry,
    ) {

        let GovernanceAuthorizationRegistry {
            id,
            total_authorizations: _,
            next_sequence: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
