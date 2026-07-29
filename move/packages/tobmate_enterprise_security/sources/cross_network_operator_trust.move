module tobmate_enterprise_security::cross_network_operator_trust {

    use sui::object;
    use sui::tx_context;


    // ============================================================
    // Errors
    // ============================================================

    const E_INVALID_TRUST_LEVEL: u64 = 1210001;
    const E_EMPTY_ATTESTATION: u64 = 1210002;
    const E_INVALID_EXPIRY: u64 = 1210003;
    const E_OPERATOR_INACTIVE: u64 = 1210004;
    const E_ATTESTATION_EXPIRED: u64 = 1210005;
    const E_TRUST_LEVEL_TOO_LOW: u64 = 1210006;
    const E_ALREADY_SUSPENDED: u64 = 1210007;
    const E_NOT_SUSPENDED: u64 = 1210008;
    const E_EMPTY_SUSPENSION_REASON: u64 = 1210009;


    // ============================================================
    // Trust Levels
    // ============================================================

    const TRUST_UNVERIFIED: u8 = 0;
    const TRUST_VERIFIED: u8 = 1;
    const TRUST_TRUSTED: u8 = 2;
    const TRUST_INSTITUTIONAL: u8 = 3;


    // ============================================================
    // Operator Trust Record
    // ============================================================

    public struct OperatorTrustRecord has key, store {
        id: object::UID,

        operator: address,

        trust_level: u8,
        active: bool,

        attestation_hash: vector<u8>,
        attestation_expiry_epoch: u64,

        suspension_reason: vector<u8>,

        version: u64,
    }


    // ============================================================
    // Registry
    // ============================================================

    public struct OperatorTrustRegistry has key, store {
        id: object::UID,

        total_records: u64,
        version: u64,
    }


    public fun new_operator_trust_registry(
        ctx: &mut tx_context::TxContext,
    ): OperatorTrustRegistry {

        OperatorTrustRegistry {
            id: object::new(ctx),
            total_records: 0,
            version: 1,
        }
    }


    // ============================================================
    // Trust Level Validation
    // ============================================================

    fun assert_valid_trust_level(
        trust_level: u8,
    ) {

        assert!(
            trust_level <= TRUST_INSTITUTIONAL,
            E_INVALID_TRUST_LEVEL,
        );
    }


    // ============================================================
    // Register Operator
    // ============================================================

    public fun register_operator(
        registry: &mut OperatorTrustRegistry,

        operator: address,
        trust_level: u8,

        attestation_hash: vector<u8>,
        attestation_expiry_epoch: u64,

        current_epoch: u64,

        ctx: &mut tx_context::TxContext,
    ): OperatorTrustRecord {

        assert_valid_trust_level(
            trust_level,
        );

        assert!(
            vector::length(&attestation_hash) > 0,
            E_EMPTY_ATTESTATION,
        );

        assert!(
            attestation_expiry_epoch >= current_epoch,
            E_INVALID_EXPIRY,
        );

        registry.total_records =
            registry.total_records + 1;

        OperatorTrustRecord {
            id: object::new(ctx),

            operator,

            trust_level,
            active: true,

            attestation_hash,
            attestation_expiry_epoch,

            suspension_reason: vector[],

            version: 1,
        }
    }


    // ============================================================
    // Trust Update
    // ============================================================

    public fun set_trust_level(
        record: &mut OperatorTrustRecord,
        trust_level: u8,
    ) {

        assert_valid_trust_level(
            trust_level,
        );

        record.trust_level =
            trust_level;

        record.version =
            record.version + 1;
    }


    // ============================================================
    // Attestation Refresh
    // ============================================================

    public fun refresh_attestation(
        record: &mut OperatorTrustRecord,
        attestation_hash: vector<u8>,
        attestation_expiry_epoch: u64,
        current_epoch: u64,
    ) {

        assert!(
            vector::length(&attestation_hash) > 0,
            E_EMPTY_ATTESTATION,
        );

        assert!(
            attestation_expiry_epoch >= current_epoch,
            E_INVALID_EXPIRY,
        );

        record.attestation_hash =
            attestation_hash;

        record.attestation_expiry_epoch =
            attestation_expiry_epoch;

        record.version =
            record.version + 1;
    }


    // ============================================================
    // Suspension
    // ============================================================

    public fun suspend_operator(
        record: &mut OperatorTrustRecord,
        reason: vector<u8>,
    ) {

        assert!(
            record.active,
            E_ALREADY_SUSPENDED,
        );

        assert!(
            vector::length(&reason) > 0,
            E_EMPTY_SUSPENSION_REASON,
        );

        record.active = false;
        record.suspension_reason = reason;

        record.version =
            record.version + 1;
    }


    public fun restore_operator(
        record: &mut OperatorTrustRecord,
    ) {

        assert!(
            !record.active,
            E_NOT_SUSPENDED,
        );

        record.active = true;
        record.suspension_reason = vector[];

        record.version =
            record.version + 1;
    }


    // ============================================================
    // Execution Eligibility
    //
    // Operator must:
    //
    // 1. be active
    // 2. have non-expired attestation
    // 3. meet minimum trust level
    // ============================================================

    public fun assert_operator_eligible(
        record: &OperatorTrustRecord,
        minimum_trust_level: u8,
        current_epoch: u64,
    ) {

        assert_valid_trust_level(
            minimum_trust_level,
        );

        assert!(
            record.active,
            E_OPERATOR_INACTIVE,
        );

        assert!(
            current_epoch
                <= record.attestation_expiry_epoch,
            E_ATTESTATION_EXPIRED,
        );

        assert!(
            record.trust_level
                >= minimum_trust_level,
            E_TRUST_LEVEL_TOO_LOW,
        );
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun operator_address(
        record: &OperatorTrustRecord,
    ): address {
        record.operator
    }


    public fun operator_trust_level(
        record: &OperatorTrustRecord,
    ): u8 {
        record.trust_level
    }


    public fun operator_active(
        record: &OperatorTrustRecord,
    ): bool {
        record.active
    }


    public fun operator_attestation_hash(
        record: &OperatorTrustRecord,
    ): &vector<u8> {
        &record.attestation_hash
    }


    public fun operator_attestation_expiry(
        record: &OperatorTrustRecord,
    ): u64 {
        record.attestation_expiry_epoch
    }


    public fun operator_suspension_reason(
        record: &OperatorTrustRecord,
    ): &vector<u8> {
        &record.suspension_reason
    }


    public fun operator_trust_version(
        record: &OperatorTrustRecord,
    ): u64 {
        record.version
    }


    public fun total_operator_records(
        registry: &OperatorTrustRegistry,
    ): u64 {
        registry.total_records
    }


    public fun trust_unverified(): u8 {
        TRUST_UNVERIFIED
    }


    public fun trust_verified(): u8 {
        TRUST_VERIFIED
    }


    public fun trust_trusted(): u8 {
        TRUST_TRUSTED
    }


    public fun trust_institutional(): u8 {
        TRUST_INSTITUTIONAL
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_operator_trust_for_testing(
        record: OperatorTrustRecord,
    ) {

        let OperatorTrustRecord {
            id,
            operator: _,
            trust_level: _,
            active: _,
            attestation_hash: _,
            attestation_expiry_epoch: _,
            suspension_reason: _,
            version: _,
        } = record;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_operator_trust_registry_for_testing(
        registry: OperatorTrustRegistry,
    ) {

        let OperatorTrustRegistry {
            id,
            total_records: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
