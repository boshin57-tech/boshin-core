module tobmate_enterprise_security::cross_network_policy {

    use std::bcs;
    use sui::hash;
    use sui::object;
    use sui::tx_context;


    // ============================================================
    // Errors
    // ============================================================

    const E_EMPTY_NETWORK: u64 = 1209001;
    const E_EMPTY_DOMAIN: u64 = 1209002;
    const E_INVALID_RISK_TIER: u64 = 1209003;
    const E_ZERO_TRANSACTION_LIMIT: u64 = 1209004;
    const E_ZERO_EPOCH_LIMIT: u64 = 1209005;
    const E_ZERO_OPERATOR_LIMIT: u64 = 1209006;
    const E_POLICY_DISABLED: u64 = 1209007;
    const E_AMOUNT_LIMIT_EXCEEDED: u64 = 1209008;


    // ============================================================
    // Risk Tiers
    // ============================================================

    const RISK_LOW: u8 = 1;
    const RISK_MEDIUM: u8 = 2;
    const RISK_HIGH: u8 = 3;
    const RISK_CRITICAL: u8 = 4;


    // ============================================================
    // Policy ID Material
    // ============================================================

    public struct PolicyIdMaterial has drop, store {
        network_id: vector<u8>,
        domain: vector<u8>,
        version: u64,
    }


    // ============================================================
    // Cross-Network Policy
    // ============================================================

    public struct CrossNetworkPolicy has key, store {
        id: object::UID,

        policy_id: vector<u8>,

        network_id: vector<u8>,
        domain: vector<u8>,

        enabled: bool,
        risk_tier: u8,

        max_transaction_amount: u64,
        epoch_volume_limit: u64,
        operator_epoch_limit: u64,

        version: u64,
    }


    // ============================================================
    // Policy Registry
    // ============================================================

    public struct PolicyRegistry has key, store {
        id: object::UID,

        total_policies: u64,
        version: u64,
    }


    public fun new_policy_registry(
        ctx: &mut tx_context::TxContext,
    ): PolicyRegistry {

        PolicyRegistry {
            id: object::new(ctx),
            total_policies: 0,
            version: 1,
        }
    }


    // ============================================================
    // Policy ID
    // ============================================================

    public(package) fun calculate_policy_id(
        network_id: vector<u8>,
        domain: vector<u8>,
        version: u64,
    ): vector<u8> {

        let material = PolicyIdMaterial {
            network_id,
            domain,
            version,
        };

        hash::blake2b256(
            &bcs::to_bytes(&material),
        )
    }


    // ============================================================
    // Create Policy
    // ============================================================

    public fun create_policy(
        registry: &mut PolicyRegistry,

        network_id: vector<u8>,
        domain: vector<u8>,

        risk_tier: u8,

        max_transaction_amount: u64,
        epoch_volume_limit: u64,
        operator_epoch_limit: u64,

        ctx: &mut tx_context::TxContext,
    ): CrossNetworkPolicy {

        assert!(
            vector::length(&network_id) > 0,
            E_EMPTY_NETWORK,
        );

        assert!(
            vector::length(&domain) > 0,
            E_EMPTY_DOMAIN,
        );

        assert!(
            risk_tier >= RISK_LOW
                && risk_tier <= RISK_CRITICAL,
            E_INVALID_RISK_TIER,
        );

        assert!(
            max_transaction_amount > 0,
            E_ZERO_TRANSACTION_LIMIT,
        );

        assert!(
            epoch_volume_limit > 0,
            E_ZERO_EPOCH_LIMIT,
        );

        assert!(
            operator_epoch_limit > 0,
            E_ZERO_OPERATOR_LIMIT,
        );

        let version = 1;

        let policy_id =
            calculate_policy_id(
                copy network_id,
                copy domain,
                version,
            );

        registry.total_policies =
            registry.total_policies + 1;

        CrossNetworkPolicy {
            id: object::new(ctx),

            policy_id,

            network_id,
            domain,

            enabled: true,
            risk_tier,

            max_transaction_amount,
            epoch_volume_limit,
            operator_epoch_limit,

            version,
        }
    }


    // ============================================================
    // Policy Enable / Disable
    // ============================================================

    public fun disable_policy(
        policy: &mut CrossNetworkPolicy,
    ) {
        policy.enabled = false;
    }


    public fun enable_policy(
        policy: &mut CrossNetworkPolicy,
    ) {
        policy.enabled = true;
    }


    // ============================================================
    // Risk Tier Update
    // ============================================================

    public fun set_risk_tier(
        policy: &mut CrossNetworkPolicy,
        risk_tier: u8,
    ) {

        assert!(
            risk_tier >= RISK_LOW
                && risk_tier <= RISK_CRITICAL,
            E_INVALID_RISK_TIER,
        );

        policy.risk_tier = risk_tier;
        policy.version = policy.version + 1;
    }


    // ============================================================
    // Limit Update
    // ============================================================

    public fun set_limits(
        policy: &mut CrossNetworkPolicy,
        max_transaction_amount: u64,
        epoch_volume_limit: u64,
        operator_epoch_limit: u64,
    ) {

        assert!(
            max_transaction_amount > 0,
            E_ZERO_TRANSACTION_LIMIT,
        );

        assert!(
            epoch_volume_limit > 0,
            E_ZERO_EPOCH_LIMIT,
        );

        assert!(
            operator_epoch_limit > 0,
            E_ZERO_OPERATOR_LIMIT,
        );

        policy.max_transaction_amount =
            max_transaction_amount;

        policy.epoch_volume_limit =
            epoch_volume_limit;

        policy.operator_epoch_limit =
            operator_epoch_limit;

        policy.version =
            policy.version + 1;
    }


    // ============================================================
    // Execution Policy Guard
    // ============================================================

    public(package) fun assert_policy_allows_amount(
        policy: &CrossNetworkPolicy,
        amount: u64,
    ) {

        assert!(
            policy.enabled,
            E_POLICY_DISABLED,
        );

        assert!(
            amount <= policy.max_transaction_amount,
            E_AMOUNT_LIMIT_EXCEEDED,
        );
    }


    // ============================================================
    // Accessors
    // ============================================================

    public fun policy_id(
        policy: &CrossNetworkPolicy,
    ): &vector<u8> {
        &policy.policy_id
    }


    public fun policy_network_id(
        policy: &CrossNetworkPolicy,
    ): &vector<u8> {
        &policy.network_id
    }


    public fun policy_domain(
        policy: &CrossNetworkPolicy,
    ): &vector<u8> {
        &policy.domain
    }


    public fun policy_enabled(
        policy: &CrossNetworkPolicy,
    ): bool {
        policy.enabled
    }


    public fun policy_risk_tier(
        policy: &CrossNetworkPolicy,
    ): u8 {
        policy.risk_tier
    }


    public fun max_transaction_amount(
        policy: &CrossNetworkPolicy,
    ): u64 {
        policy.max_transaction_amount
    }


    public fun epoch_volume_limit(
        policy: &CrossNetworkPolicy,
    ): u64 {
        policy.epoch_volume_limit
    }


    public fun operator_epoch_limit(
        policy: &CrossNetworkPolicy,
    ): u64 {
        policy.operator_epoch_limit
    }


    public fun policy_version(
        policy: &CrossNetworkPolicy,
    ): u64 {
        policy.version
    }


    public(package) fun total_policies(
        registry: &PolicyRegistry,
    ): u64 {
        registry.total_policies
    }


    public fun risk_low(): u8 {
        RISK_LOW
    }


    public fun risk_medium(): u8 {
        RISK_MEDIUM
    }


    public fun risk_high(): u8 {
        RISK_HIGH
    }


    public fun risk_critical(): u8 {
        RISK_CRITICAL
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_policy_for_testing(
        policy: CrossNetworkPolicy,
    ) {

        let CrossNetworkPolicy {
            id,
            policy_id: _,
            network_id: _,
            domain: _,
            enabled: _,
            risk_tier: _,
            max_transaction_amount: _,
            epoch_volume_limit: _,
            operator_epoch_limit: _,
            version: _,
        } = policy;

        object::delete(id);
    }


    #[test_only]
    public fun destroy_policy_registry_for_testing(
        registry: PolicyRegistry,
    ) {

        let PolicyRegistry {
            id,
            total_policies: _,
            version: _,
        } = registry;

        object::delete(id);
    }
}
