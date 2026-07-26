module tobmate_core::cross_network_emergency_control {

    use sui::object;
    use sui::tx_context;


    // ============================================================
    // Errors
    // ============================================================

    const E_ALREADY_PAUSED: u64 = 1208001;
    const E_NOT_PAUSED: u64 = 1208002;

    const E_RECOVERY_ALREADY_FROZEN: u64 = 1208003;
    const E_RECOVERY_NOT_FROZEN: u64 = 1208004;

    const E_INCIDENT_ALREADY_ACTIVE: u64 = 1208005;
    const E_INCIDENT_NOT_ACTIVE: u64 = 1208006;

    const E_OPERATOR_ALREADY_SUSPENDED: u64 = 1208007;
    const E_OPERATOR_NOT_SUSPENDED: u64 = 1208008;

    const E_EXECUTION_PAUSED: u64 = 1208009;
    const E_RECOVERY_FROZEN: u64 = 1208010;
    const E_OPERATOR_SUSPENDED: u64 = 1208011;
    const E_INCIDENT_MODE_ACTIVE: u64 = 1208012;


    // ============================================================
    // Emergency Control Registry
    //
    // Stage 8-B will add governance authorization around mutation.
    // ============================================================

    public struct EmergencyControlRegistry has key, store {
        id: object::UID,

        global_pause: bool,
        recovery_freeze: bool,
        incident_mode: bool,

        suspended_operators: vector<address>,

        incident_code: vector<u8>,

        version: u64,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_emergency_control_registry(
        ctx: &mut tx_context::TxContext,
    ): EmergencyControlRegistry {

        EmergencyControlRegistry {
            id: object::new(ctx),

            global_pause: false,
            recovery_freeze: false,
            incident_mode: false,

            suspended_operators: vector[],

            incident_code: vector[],

            version: 1,
        }
    }


    // ============================================================
    // Operator Membership
    // ============================================================

    fun operator_index(
        registry: &EmergencyControlRegistry,
        operator: address,
    ): (bool, u64) {

        let mut i = 0;
        let length =
            vector::length(
                &registry.suspended_operators,
            );

        while (i < length) {
            if (
                *vector::borrow(
                    &registry.suspended_operators,
                    i,
                ) == operator
            ) {
                return (true, i)
            };

            i = i + 1;
        };

        (false, 0)
    }


    public fun is_operator_suspended(
        registry: &EmergencyControlRegistry,
        operator: address,
    ): bool {

        let (found, _) =
            operator_index(
                registry,
                operator,
            );

        found
    }


    // ============================================================
    // Global Pause
    // ============================================================

    public fun activate_global_pause(
        registry: &mut EmergencyControlRegistry,
    ) {

        assert!(
            !registry.global_pause,
            E_ALREADY_PAUSED,
        );

        registry.global_pause = true;
    }


    public fun deactivate_global_pause(
        registry: &mut EmergencyControlRegistry,
    ) {

        assert!(
            registry.global_pause,
            E_NOT_PAUSED,
        );

        registry.global_pause = false;
    }


    // ============================================================
    // Recovery Freeze
    // ============================================================

    public fun activate_recovery_freeze(
        registry: &mut EmergencyControlRegistry,
    ) {

        assert!(
            !registry.recovery_freeze,
            E_RECOVERY_ALREADY_FROZEN,
        );

        registry.recovery_freeze = true;
    }


    public fun deactivate_recovery_freeze(
        registry: &mut EmergencyControlRegistry,
    ) {

        assert!(
            registry.recovery_freeze,
            E_RECOVERY_NOT_FROZEN,
        );

        registry.recovery_freeze = false;
    }


    // ============================================================
    // Incident Mode
    // ============================================================

    public fun activate_incident_mode(
        registry: &mut EmergencyControlRegistry,
        incident_code: vector<u8>,
    ) {

        assert!(
            !registry.incident_mode,
            E_INCIDENT_ALREADY_ACTIVE,
        );

        registry.incident_mode = true;
        registry.incident_code = incident_code;
    }


    public fun deactivate_incident_mode(
        registry: &mut EmergencyControlRegistry,
    ) {

        assert!(
            registry.incident_mode,
            E_INCIDENT_NOT_ACTIVE,
        );

        registry.incident_mode = false;
        registry.incident_code = vector[];
    }


    // ============================================================
    // Operator Suspension
    // ============================================================

    public fun suspend_operator(
        registry: &mut EmergencyControlRegistry,
        operator: address,
    ) {

        let (found, _) =
            operator_index(
                registry,
                operator,
            );

        assert!(
            !found,
            E_OPERATOR_ALREADY_SUSPENDED,
        );

        vector::push_back(
            &mut registry.suspended_operators,
            operator,
        );
    }


    public fun restore_operator(
        registry: &mut EmergencyControlRegistry,
        operator: address,
    ) {

        let (found, index) =
            operator_index(
                registry,
                operator,
            );

        assert!(
            found,
            E_OPERATOR_NOT_SUSPENDED,
        );

        vector::remove(
            &mut registry.suspended_operators,
            index,
        );
    }


    // ============================================================
    // Execution Guard
    //
    // Cross-network execution is blocked by:
    //
    // global pause
    // incident mode
    // suspended operator
    // ============================================================

    public fun assert_execution_allowed(
        registry: &EmergencyControlRegistry,
        operator: address,
    ) {

        assert!(
            !registry.global_pause,
            E_EXECUTION_PAUSED,
        );

        assert!(
            !registry.incident_mode,
            E_INCIDENT_MODE_ACTIVE,
        );

        assert!(
            !is_operator_suspended(
                registry,
                operator,
            ),
            E_OPERATOR_SUSPENDED,
        );
    }


    // ============================================================
    // Recovery Guard
    //
    // Recovery/remediation may be frozen independently from
    // ordinary cross-network execution.
    // ============================================================

    public fun assert_recovery_allowed(
        registry: &EmergencyControlRegistry,
    ) {

        assert!(
            !registry.recovery_freeze,
            E_RECOVERY_FROZEN,
        );
    }


    // ============================================================
    // Status Accessors
    // ============================================================

    public fun is_global_paused(
        registry: &EmergencyControlRegistry,
    ): bool {
        registry.global_pause
    }


    public fun is_recovery_frozen(
        registry: &EmergencyControlRegistry,
    ): bool {
        registry.recovery_freeze
    }


    public fun is_incident_active(
        registry: &EmergencyControlRegistry,
    ): bool {
        registry.incident_mode
    }


    public fun incident_code(
        registry: &EmergencyControlRegistry,
    ): &vector<u8> {
        &registry.incident_code
    }


    public fun suspended_operator_count(
        registry: &EmergencyControlRegistry,
    ): u64 {
        vector::length(
            &registry.suspended_operators,
        )
    }


    public fun emergency_version(
        registry: &EmergencyControlRegistry,
    ): u64 {
        registry.version
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_emergency_registry_for_testing(
        registry: EmergencyControlRegistry,
    ) {

        let EmergencyControlRegistry {
            id,
            global_pause: _,
            recovery_freeze: _,
            incident_mode: _,
            suspended_operators: _,
            incident_code: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
