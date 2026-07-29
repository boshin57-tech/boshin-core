module tobmate_enterprise_security::cross_network_rate_limit {

    use sui::object;
    use sui::tx_context;

    use tobmate_enterprise_security::cross_network_policy;


    // ============================================================
    // Errors
    // ============================================================

    const E_GLOBAL_RATE_LIMIT: u64 = 1209201;
    const E_OPERATOR_RATE_LIMIT: u64 = 1209202;


    // ============================================================
    // Rate-Limit State
    //
    // window_id is supplied by the execution/control layer.
    // A changed window_id resets all request counters.
    // ============================================================

    public struct RateLimitState has key, store {
        id: object::UID,

        current_window_id: u64,

        total_requests: u64,

        operators: vector<address>,
        operator_requests: vector<u64>,

        version: u64,
    }


    public fun new_rate_limit_state(
        window_id: u64,
        ctx: &mut tx_context::TxContext,
    ): RateLimitState {

        RateLimitState {
            id: object::new(ctx),

            current_window_id: window_id,

            total_requests: 0,

            operators: vector[],
            operator_requests: vector[],

            version: 1,
        }
    }


    // ============================================================
    // Operator Lookup
    // ============================================================

    fun operator_index(
        state: &RateLimitState,
        operator: address,
    ): (bool, u64) {

        let mut i = 0;

        let length =
            vector::length(
                &state.operators,
            );

        while (i < length) {

            if (
                *vector::borrow(
                    &state.operators,
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
    // Window Rollover
    // ============================================================

    public fun rollover_window_if_needed(
        state: &mut RateLimitState,
        window_id: u64,
    ) {

        if (
            state.current_window_id
                != window_id
        ) {

            state.current_window_id =
                window_id;

            state.total_requests = 0;

            state.operators = vector[];
            state.operator_requests = vector[];

            state.version =
                state.version + 1;
        };
    }


    // ============================================================
    // Risk-tier Global Base Quota
    //
    // LOW      = 100
    // MEDIUM   = 50
    // HIGH     = 20
    // CRITICAL = 5
    // ============================================================

    public fun global_base_limit(
        risk_tier: u8,
    ): u64 {

        if (
            risk_tier
                == cross_network_policy::risk_low()
        ) {
            100
        } else if (
            risk_tier
                == cross_network_policy::risk_medium()
        ) {
            50
        } else if (
            risk_tier
                == cross_network_policy::risk_high()
        ) {
            20
        } else {
            5
        }
    }


    // ============================================================
    // Global Burst Allowance
    // ============================================================

    public fun global_burst_allowance(
        risk_tier: u8,
    ): u64 {

        if (
            risk_tier
                == cross_network_policy::risk_low()
        ) {
            20
        } else if (
            risk_tier
                == cross_network_policy::risk_medium()
        ) {
            10
        } else if (
            risk_tier
                == cross_network_policy::risk_high()
        ) {
            5
        } else {
            1
        }
    }


    // ============================================================
    // Operator Base Quota
    //
    // LOW      = 50
    // MEDIUM   = 25
    // HIGH     = 10
    // CRITICAL = 3
    // ============================================================

    public fun operator_base_limit(
        risk_tier: u8,
    ): u64 {

        if (
            risk_tier
                == cross_network_policy::risk_low()
        ) {
            50
        } else if (
            risk_tier
                == cross_network_policy::risk_medium()
        ) {
            25
        } else if (
            risk_tier
                == cross_network_policy::risk_high()
        ) {
            10
        } else {
            3
        }
    }


    // ============================================================
    // Operator Burst Allowance
    // ============================================================

    public fun operator_burst_allowance(
        risk_tier: u8,
    ): u64 {

        if (
            risk_tier
                == cross_network_policy::risk_low()
        ) {
            10
        } else if (
            risk_tier
                == cross_network_policy::risk_medium()
        ) {
            5
        } else if (
            risk_tier
                == cross_network_policy::risk_high()
        ) {
            2
        } else {
            1
        }
    }


    // ============================================================
    // Consume Request
    //
    // Enforcement:
    //
    // 1. policy must be enabled
    // 2. window rollover
    // 3. global base + burst quota
    // 4. operator base + burst quota
    // 5. accounting update
    //
    // This prevents high-frequency low-value requests from
    // bypassing the amount/volume controls in Part 9-B.
    // ============================================================

    public fun consume_request(
        state: &mut RateLimitState,
        policy: &cross_network_policy::CrossNetworkPolicy,
        operator: address,
        window_id: u64,
    ) {

        // Reuse Part 9-A policy enabled enforcement.
        cross_network_policy::
            assert_policy_allows_amount(
                policy,
                0,
            );

        rollover_window_if_needed(
            state,
            window_id,
        );

        let risk_tier =
            cross_network_policy::
                policy_risk_tier(
                    policy,
                );


        // --------------------------------------------------------
        // Global quota + burst
        // --------------------------------------------------------

        let global_limit =
            global_base_limit(risk_tier)
                + global_burst_allowance(
                    risk_tier,
                );

        let new_total =
            state.total_requests + 1;

        assert!(
            new_total <= global_limit,
            E_GLOBAL_RATE_LIMIT,
        );


        // --------------------------------------------------------
        // Operator quota + burst
        // --------------------------------------------------------

        let operator_limit =
            operator_base_limit(risk_tier)
                + operator_burst_allowance(
                    risk_tier,
                );

        let (found, index) =
            operator_index(
                state,
                operator,
            );

        if (found) {

            let old_requests =
                *vector::borrow(
                    &state.operator_requests,
                    index,
                );

            let new_requests =
                old_requests + 1;

            assert!(
                new_requests <= operator_limit,
                E_OPERATOR_RATE_LIMIT,
            );

            *vector::borrow_mut(
                &mut state.operator_requests,
                index,
            ) = new_requests;

        } else {

            assert!(
                1 <= operator_limit,
                E_OPERATOR_RATE_LIMIT,
            );

            vector::push_back(
                &mut state.operators,
                operator,
            );

            vector::push_back(
                &mut state.operator_requests,
                1,
            );
        };


        state.total_requests =
            new_total;
    }


    // ============================================================
    // Read Accessors
    // ============================================================

    public(package) fun current_window_id(
        state: &RateLimitState,
    ): u64 {
        state.current_window_id
    }


    public(package) fun total_requests(
        state: &RateLimitState,
    ): u64 {
        state.total_requests
    }


    public fun operator_count(
        state: &RateLimitState,
    ): u64 {
        vector::length(
            &state.operators,
        )
    }


    public fun operator_request_count(
        state: &RateLimitState,
        operator: address,
    ): u64 {

        let (found, index) =
            operator_index(
                state,
                operator,
            );

        if (found) {
            *vector::borrow(
                &state.operator_requests,
                index,
            )
        } else {
            0
        }
    }


    public fun rate_limit_version(
        state: &RateLimitState,
    ): u64 {
        state.version
    }


    // ============================================================
    // Test-only Cleanup
    // ============================================================

    #[test_only]
    public fun destroy_rate_limit_state_for_testing(
        state: RateLimitState,
    ) {

        let RateLimitState {
            id,
            current_window_id: _,
            total_requests: _,
            operators: _,
            operator_requests: _,
            version: _,
        } = state;

        object::delete(id);
    }
}
