module tobmate_enterprise_security::cross_network_compliance_binding {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;

    use tobmate_enterprise_security::cross_network_operator_trust;


    // ============================================================
    // Errors
    // ============================================================

    const E_EMPTY_NETWORK: u64 = 1210101;
    const E_EMPTY_DOMAIN: u64 = 1210102;
    const E_EMPTY_ATTESTATION: u64 = 1210103;

    const E_INVALID_PROFILE: u64 = 1210104;
    const E_INVALID_VALIDITY_RANGE: u64 = 1210105;

    const E_OPERATOR_MISMATCH: u64 = 1210106;
    const E_NETWORK_MISMATCH: u64 = 1210107;
    const E_DOMAIN_MISMATCH: u64 = 1210108;
    const E_ATTESTATION_MISMATCH: u64 = 1210109;

    const E_BINDING_NOT_YET_VALID: u64 = 1210110;
    const E_BINDING_EXPIRED: u64 = 1210111;
    const E_PROFILE_TOO_LOW: u64 = 1210112;


    // ============================================================
    // Compliance Profiles
    // ============================================================

    const PROFILE_BASIC: u8 = 1;
    const PROFILE_REGULATED: u8 = 2;
    const PROFILE_INSTITUTIONAL: u8 = 3;


    // ============================================================
    // Hash Material
    // ============================================================

    public struct ComplianceBindingMaterial has drop, store {
        operator: address,

        network_id: vector<u8>,
        domain: vector<u8>,

        attestation_hash: vector<u8>,

        compliance_profile: u8,

        valid_from_epoch: u64,
        valid_until_epoch: u64,
    }


    // ============================================================
    // Compliance Binding
    // ============================================================

    public struct ComplianceBinding has key, store {
        id: object::UID,

        binding_hash: vector<u8>,

        operator: address,

        network_id: vector<u8>,
        domain: vector<u8>,

        attestation_hash: vector<u8>,

        compliance_profile: u8,

        valid_from_epoch: u64,
        valid_until_epoch: u64,

        version: u64,
    }


    // ============================================================
    // Profile Validation
    // ============================================================

    fun assert_valid_profile(
        profile: u8,
    ) {

        assert!(
            profile >= PROFILE_BASIC
                && profile <= PROFILE_INSTITUTIONAL,
            E_INVALID_PROFILE,
        );
    }


    // ============================================================
    // Deterministic Binding Hash
    // ============================================================

    public fun calculate_binding_hash(
        operator: address,

        network_id: vector<u8>,
        domain: vector<u8>,

        attestation_hash: vector<u8>,

        compliance_profile: u8,

        valid_from_epoch: u64,
        valid_until_epoch: u64,
    ): vector<u8> {

        assert_valid_profile(
            compliance_profile,
        );

        let material = ComplianceBindingMaterial {
            operator,

            network_id,
            domain,

            attestation_hash,

            compliance_profile,

            valid_from_epoch,
            valid_until_epoch,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Create Binding
    // ============================================================

    public fun create_compliance_binding(
        trust_record:
            &cross_network_operator_trust::OperatorTrustRecord,

        network_id: vector<u8>,
        domain: vector<u8>,

        compliance_profile: u8,

        valid_from_epoch: u64,
        valid_until_epoch: u64,

        ctx: &mut tx_context::TxContext,
    ): ComplianceBinding {

        assert!(
            vector::length(&network_id) > 0,
            E_EMPTY_NETWORK,
        );

        assert!(
            vector::length(&domain) > 0,
            E_EMPTY_DOMAIN,
        );

        assert_valid_profile(
            compliance_profile,
        );

        assert!(
            valid_until_epoch >= valid_from_epoch,
            E_INVALID_VALIDITY_RANGE,
        );

        let operator =
            cross_network_operator_trust::
                operator_address(
                    trust_record,
                );

        let attestation_hash =
            *cross_network_operator_trust::
                operator_attestation_hash(
                    trust_record,
                );

        assert!(
            vector::length(&attestation_hash) > 0,
            E_EMPTY_ATTESTATION,
        );

        let binding_hash =
            calculate_binding_hash(
                operator,

                copy network_id,
                copy domain,

                copy attestation_hash,

                compliance_profile,

                valid_from_epoch,
                valid_until_epoch,
            );

        ComplianceBinding {
            id: object::new(ctx),

            binding_hash,

            operator,

            network_id,
            domain,

            attestation_hash,

            compliance_profile,

            valid_from_epoch,
            valid_until_epoch,

            version: 1,
        }
    }


    // ============================================================
    // Exact Context Binding
    // ============================================================

    public fun assert_binding_context(
        binding: &ComplianceBinding,

        trust_record:
            &cross_network_operator_trust::OperatorTrustRecord,

        network_id: &vector<u8>,
        domain: &vector<u8>,
    ) {

        assert!(
            binding.operator
                == cross_network_operator_trust::
                    operator_address(
                        trust_record,
                    ),
            E_OPERATOR_MISMATCH,
        );

        assert!(
            &binding.network_id == network_id,
            E_NETWORK_MISMATCH,
        );

        assert!(
            &binding.domain == domain,
            E_DOMAIN_MISMATCH,
        );

        assert!(
            &binding.attestation_hash
                == cross_network_operator_trust::
                    operator_attestation_hash(
                        trust_record,
                    ),
            E_ATTESTATION_MISMATCH,
        );
    }


    // ============================================================
    // Validity + Compliance Profile Guard
    // ============================================================

    public fun assert_compliance_valid(
        binding: &ComplianceBinding,

        trust_record:
            &cross_network_operator_trust::OperatorTrustRecord,

        network_id: &vector<u8>,
        domain: &vector<u8>,

        minimum_profile: u8,

        current_epoch: u64,
    ) {

        assert_valid_profile(
            minimum_profile,
        );

        assert_binding_context(
            binding,
            trust_record,
            network_id,
            domain,
        );

        assert!(
            current_epoch >= binding.valid_from_epoch,
            E_BINDING_NOT_YET_VALID,
        );

        assert!(
            current_epoch <= binding.valid_until_epoch,
            E_BINDING_EXPIRED,
        );

        assert!(
            binding.compliance_profile
                >= minimum_profile,
            E_PROFILE_TOO_LOW,
        );
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun binding_hash(
        binding: &ComplianceBinding,
    ): &vector<u8> {
        &binding.binding_hash
    }


    public fun binding_operator(
        binding: &ComplianceBinding,
    ): address {
        binding.operator
    }


    public fun binding_network_id(
        binding: &ComplianceBinding,
    ): &vector<u8> {
        &binding.network_id
    }


    public fun binding_domain(
        binding: &ComplianceBinding,
    ): &vector<u8> {
        &binding.domain
    }


    public fun binding_attestation_hash(
        binding: &ComplianceBinding,
    ): &vector<u8> {
        &binding.attestation_hash
    }


    public fun binding_profile(
        binding: &ComplianceBinding,
    ): u8 {
        binding.compliance_profile
    }


    public(package) fun binding_valid_from(
        binding: &ComplianceBinding,
    ): u64 {
        binding.valid_from_epoch
    }


    public(package) fun binding_valid_until(
        binding: &ComplianceBinding,
    ): u64 {
        binding.valid_until_epoch
    }


    public fun binding_version(
        binding: &ComplianceBinding,
    ): u64 {
        binding.version
    }


    public fun profile_basic(): u8 {
        PROFILE_BASIC
    }


    public fun profile_regulated(): u8 {
        PROFILE_REGULATED
    }


    public fun profile_institutional(): u8 {
        PROFILE_INSTITUTIONAL
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_compliance_binding_for_testing(
        binding: ComplianceBinding,
    ) {

        let ComplianceBinding {
            id,
            binding_hash: _,
            operator: _,
            network_id: _,
            domain: _,
            attestation_hash: _,
            compliance_profile: _,
            valid_from_epoch: _,
            valid_until_epoch: _,
            version: _,
        } = binding;

        object::delete(id);
    }
}
