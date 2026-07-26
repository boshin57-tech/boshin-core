module tobmate_core::cross_network_risk_limit {

    use sui::object;
    use sui::tx_context;

    use tobmate_core::cross_network_policy;


    // ============================================================
    // Errors
    // ============================================================

    const E_EPOCH_VOLUME_LIMIT: u64 = 1209101;
    const E_OPERATOR_EPOCH_LIMIT: u64 = 1209102;
    const E_RISK_TX_COUNT_LIMIT: u64 = 1209103;
    const E_ZERO_AMOUNT: u64 = 1209104;


    // ============================================================
    // Usage State
    // ============================================================

    public struct RiskLimitUsage has key, store {
        id: object::UID,

        current_epoch: u64,

        epoch_total_volume: u64,
        epoch_transaction_count: u64,

        operators: vector<address>,
        operator_volumes: vector<u64>,
        operator_transaction_counts: vector<u64>,

        version: u64,
    }


    public fun new_risk_limit_usage(
        current_epoch: u64,
        ctx: &mut tx_context::TxContext,
    ): RiskLimitUsage {

        RiskLimitUsage {
            id: object::new(ctx),

            current_epoch,

            epoch_total_volume: 0,
            epoch_transaction_count: 0,

            operators: vector[],
            operator_volumes: vector[],
            operator_transaction_counts: vector[],

            version: 1,
        }
    }


    // ============================================================
    // Operator Lookup
    // ============================================================

    fun operator_index(
        usage: &RiskLimitUsage,
        operator: address,
    ): (bool, u64) {

        let mut i = 0;
        let length =
            vector::length(
                &usage.operators,
            );

        while (i < length) {
            if (
                *vector::borrow(
                    &usage.operators,
                    i,
                ) == operator
            ) {
                return (true, i)
            };

            i = i + 1;
        };

        (false, 0)
    }


    // ============================================================
    // Epoch Rollover
    //
    // A new epoch clears all prior usage counters.
    // ============================================================

    public fun rollover_if_needed(
        usage: &mut RiskLimitUsage,
        current_epoch: u64,
    ) {

        if (usage.current_epoch != current_epoch) {

            usage.current_epoch =
                current_epoch;

            usage.epoch_total_volume = 0;
            usage.epoch_transaction_count = 0;

            usage.operators = vector[];
            usage.operator_volumes = vector[];
            usage.operator_transaction_counts = vector[];

            usage.version =
                usage.version + 1;
        };
    }


    // ============================================================
    // Risk-based transaction count ceilings
    //
    // LOW      : 1000 tx / epoch
    // MEDIUM   : 500
    // HIGH     : 100
    // CRITICAL : 10
    // ============================================================

    public fun risk_transaction_count_limit(
        risk_tier: u8,
    ): u64 {

        if (
            risk_tier
                == cross_network_policy::risk_low()
        ) {
            1000
        } else if (
            risk_tier
                == cross_network_policy::risk_medium()
        ) {
            500
        } else if (
            risk_tier
                == cross_network_policy::risk_high()
        ) {
            100
        } else {
            10
        }
    }


    // ============================================================
    // Record Protected Usage
    //
    // Enforcement order:
    //
    // 1. amount > 0
    // 2. policy enabled + per-transaction limit
    // 3. epoch rollover
    // 4. epoch total volume limit
    // 5. operator epoch volume limit
    // 6. risk-tier transaction-count limit
    // 7. state update
    // ============================================================

    public fun record_usage(
        usage: &mut RiskLimitUsage,
        policy: &cross_network_policy::CrossNetworkPolicy,
        operator: address,
        amount: u64,
        current_epoch: u64,
    ) {

        assert!(
            amount > 0,
            E_ZERO_AMOUNT,
        );

        cross_network_policy::assert_policy_allows_amount(
            policy,
            amount,
        );

        rollover_if_needed(
            usage,
            current_epoch,
        );


        // --------------------------------------------------------
        // Epoch total volume
        // --------------------------------------------------------

        let new_epoch_total =
            usage.epoch_total_volume + amount;

        assert!(
            new_epoch_total
                <= cross_network_policy::
                    epoch_volume_limit(policy),
            E_EPOCH_VOLUME_LIMIT,
        );


        // --------------------------------------------------------
        // Risk transaction count
        // --------------------------------------------------------

        let new_tx_count =
            usage.epoch_transaction_count + 1;

        let risk_tx_limit =
            risk_transaction_count_limit(
                cross_network_policy::
                    policy_risk_tier(policy),
            );

        assert!(
            new_tx_count <= risk_tx_limit,
            E_RISK_TX_COUNT_LIMIT,
        );


        // --------------------------------------------------------
        // Operator accounting
        // --------------------------------------------------------

        let (found, index) =
            operator_index(
                usage,
                operator,
            );

        if (found) {

            let old_operator_volume =
                *vector::borrow(
                    &usage.operator_volumes,
                    index,
                );

            let new_operator_volume =
                old_operator_volume + amount;

            assert!(
                new_operator_volume
                    <= cross_network_policy::
                        operator_epoch_limit(policy),
                E_OPERATOR_EPOCH_LIMIT,
            );

            *vector::borrow_mut(
                &mut usage.operator_volumes,
                index,
            ) = new_operator_volume;

            let old_count =
                *vector::borrow(
                    &usage.operator_transaction_counts,
                    index,
                );

            *vector::borrow_mut(
                &mut usage.operator_transaction_counts,
                index,
            ) = old_count + 1;

        } else {

            assert!(
                amount
                    <= cross_network_policy::
                        operator_epoch_limit(policy),
                E_OPERATOR_EPOCH_LIMIT,
            );

            vector::push_back(
                &mut usage.operators,
                operator,
            );

            vector::push_back(
                &mut usage.operator_volumes,
                amount,
            );

            vector::push_back(
                &mut usage.operator_transaction_counts,
                1,
            );
        };


        // --------------------------------------------------------
        // Final aggregate update
        // --------------------------------------------------------

        usage.epoch_total_volume =
            new_epoch_total;

        usage.epoch_transaction_count =
            new_tx_count;
    }


    // ============================================================
    // Read Accessors
    // ============================================================

    public fun usage_epoch(
        usage: &RiskLimitUsage,
    ): u64 {
        usage.current_epoch
    }


    public fun epoch_total_volume(
        usage: &RiskLimitUsage,
    ): u64 {
        usage.epoch_total_volume
    }


    public fun epoch_transaction_count(
        usage: &RiskLimitUsage,
    ): u64 {
        usage.epoch_transaction_count
    }


    public fun operator_count(
        usage: &RiskLimitUsage,
    ): u64 {
        vector::length(
            &usage.operators,
        )
    }


    public fun operator_volume(
        usage: &RiskLimitUsage,
        operator: address,
    ): u64 {

        let (found, index) =
            operator_index(
                usage,
                operator,
            );

        if (found) {
            *vector::borrow(
                &usage.operator_volumes,
                index,
            )
        } else {
            0
        }
    }


    public fun operator_transaction_count(
        usage: &RiskLimitUsage,
        operator: address,
    ): u64 {

        let (found, index) =
            operator_index(
                usage,
                operator,
            );

        if (found) {
            *vector::borrow(
                &usage.operator_transaction_counts,
                index,
            )
        } else {
            0
        }
    }


    public fun usage_version(
        usage: &RiskLimitUsage,
    ): u64 {
        usage.version
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_risk_limit_usage_for_testing(
        usage: RiskLimitUsage,
    ) {

        let RiskLimitUsage {
            id,
            current_epoch: _,
            epoch_total_volume: _,
            epoch_transaction_count: _,
            operators: _,
            operator_volumes: _,
            operator_transaction_counts: _,
            version: _,
        } = usage;

        object::delete(id);
    }
}
