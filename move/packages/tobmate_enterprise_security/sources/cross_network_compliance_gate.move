module tobmate_enterprise_security::cross_network_compliance_gate {

    use sui::object;
    use sui::tx_context;

    use tobmate_enterprise_security::cross_network_operator_trust;
    use tobmate_enterprise_security::cross_network_compliance_binding;


    // ============================================================
    // Errors
    // ============================================================

    const E_GATE_DISABLED: u64 = 1210201;


    // ============================================================
    // Compliance Gate Policy
    // ============================================================

    public struct ComplianceGatePolicy has key, store {
        id: object::UID,

        enabled: bool,

        minimum_trust_level: u8,
        minimum_compliance_profile: u8,

        total_checks: u64,
        total_allowed: u64,

        version: u64,
    }


    // ============================================================
    // Constructor
    // ============================================================

    public fun new_compliance_gate_policy(
        minimum_trust_level: u8,
        minimum_compliance_profile: u8,
        ctx: &mut tx_context::TxContext,
    ): ComplianceGatePolicy {

        ComplianceGatePolicy {
            id: object::new(ctx),

            enabled: true,

            minimum_trust_level,
            minimum_compliance_profile,

            total_checks: 0,
            total_allowed: 0,

            version: 1,
        }
    }


    // ============================================================
    // Enable / Disable
    // ============================================================

    public fun disable_gate(
        gate: &mut ComplianceGatePolicy,
    ) {

        gate.enabled = false;
        gate.version = gate.version + 1;
    }


    public fun enable_gate(
        gate: &mut ComplianceGatePolicy,
    ) {

        gate.enabled = true;
        gate.version = gate.version + 1;
    }


    // ============================================================
    // Minimum Requirements Update
    // ============================================================

    public fun set_minimum_requirements(
        gate: &mut ComplianceGatePolicy,
        minimum_trust_level: u8,
        minimum_compliance_profile: u8,
    ) {

        gate.minimum_trust_level =
            minimum_trust_level;

        gate.minimum_compliance_profile =
            minimum_compliance_profile;

        gate.version =
            gate.version + 1;
    }


    // ============================================================
    // Compliance Execution Gate
    //
    // Both checks MUST succeed:
    //
    // 1. Operator trust eligibility
    // 2. Compliance binding validity
    // ============================================================

    public fun assert_execution_compliant(
        gate: &mut ComplianceGatePolicy,

        trust_record:
            &cross_network_operator_trust::OperatorTrustRecord,

        binding:
            &cross_network_compliance_binding::ComplianceBinding,

        network_id: &vector<u8>,
        domain: &vector<u8>,

        current_epoch: u64,
    ) {

        assert!(
            gate.enabled,
            E_GATE_DISABLED,
        );

        gate.total_checks =
            gate.total_checks + 1;


        // --------------------------------------------------------
        // Operator Trust Layer
        // --------------------------------------------------------

        cross_network_operator_trust::
            assert_operator_eligible(
                trust_record,
                gate.minimum_trust_level,
                current_epoch,
            );


        // --------------------------------------------------------
        // Compliance Binding Layer
        // --------------------------------------------------------

        cross_network_compliance_binding::
            assert_compliance_valid(
                binding,
                trust_record,
                network_id,
                domain,
                gate.minimum_compliance_profile,
                current_epoch,
            );


        // --------------------------------------------------------
        // Gate success accounting
        // --------------------------------------------------------

        gate.total_allowed =
            gate.total_allowed + 1;
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun gate_enabled(
        gate: &ComplianceGatePolicy,
    ): bool {
        gate.enabled
    }


    public fun minimum_trust_level(
        gate: &ComplianceGatePolicy,
    ): u8 {
        gate.minimum_trust_level
    }


    public fun minimum_compliance_profile(
        gate: &ComplianceGatePolicy,
    ): u8 {
        gate.minimum_compliance_profile
    }


    public fun total_checks(
        gate: &ComplianceGatePolicy,
    ): u64 {
        gate.total_checks
    }


    public fun total_allowed(
        gate: &ComplianceGatePolicy,
    ): u64 {
        gate.total_allowed
    }


    public fun gate_version(
        gate: &ComplianceGatePolicy,
    ): u64 {
        gate.version
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_compliance_gate_for_testing(
        gate: ComplianceGatePolicy,
    ) {

        let ComplianceGatePolicy {
            id,
            enabled: _,
            minimum_trust_level: _,
            minimum_compliance_profile: _,
            total_checks: _,
            total_allowed: _,
            version: _,
        } = gate;

        object::delete(id);
    }
}
