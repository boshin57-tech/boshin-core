module tobmate_enterprise_security::cross_network_execution_guard {

    use tobmate_enterprise_security::cross_network_security;


    // ============================================================
    // Atomic Cross-Network Execution
    //
    // Security order:
    //
    // 1. validate network/domain/intent/finality context
    // 2. require CONFIRMED finality
    // 3. consume external reference
    // 4. consume confirmation hash
    // 5. consume proof fingerprint
    // 6. mark terminal record EXECUTED
    //
    // Move transaction atomicity guarantees that if any step
    // aborts, all earlier mutations in this call are rolled back.
    // ============================================================

    public fun execute_once(
        registry:
            &mut cross_network_security::ReplayProtectionRegistry,

        record:
            &mut cross_network_security::TerminalFinalityRecord,

        binding:
            &cross_network_security::CrossNetworkBinding,

        intent_binding:
            &cross_network_security::IntentFinalityBinding,

        external_reference: vector<u8>,
        confirmation_hash: vector<u8>,
        proof_fingerprint: vector<u8>,
    ) {

        // --------------------------------------------------------
        // Context / finality validation
        // --------------------------------------------------------

        cross_network_security::assert_execution_context(
            record,
            binding,
            intent_binding,
        );


        // --------------------------------------------------------
        // Replay consumption
        // --------------------------------------------------------

        cross_network_security::consume_external_reference(
            registry,
            intent_binding,
            external_reference,
        );

        cross_network_security::consume_confirmation_hash(
            registry,
            intent_binding,
            confirmation_hash,
        );

        cross_network_security::consume_proof(
            registry,
            intent_binding,
            proof_fingerprint,
        );


        // --------------------------------------------------------
        // Terminal execution
        // --------------------------------------------------------

        cross_network_security::mark_finality_executed(
            record,
            binding,
            intent_binding,
        );
    }


    // ============================================================
    // Execution Readiness
    // ============================================================

    public fun assert_ready(
        record:
            &cross_network_security::TerminalFinalityRecord,

        binding:
            &cross_network_security::CrossNetworkBinding,

        intent_binding:
            &cross_network_security::IntentFinalityBinding,
    ) {

        cross_network_security::assert_execution_context(
            record,
            binding,
            intent_binding,
        );
    }


    // ============================================================
    // Post-Execution Verification
    // ============================================================

    public fun is_execution_complete(
        registry:
            &cross_network_security::ReplayProtectionRegistry,

        record:
            &cross_network_security::TerminalFinalityRecord,

        external_reference: vector<u8>,
        confirmation_hash: vector<u8>,
        proof_fingerprint: vector<u8>,
    ): bool {

        cross_network_security::is_executed(record)

            && cross_network_security::is_external_reference_consumed(
                registry,
                external_reference,
            )

            && cross_network_security::is_confirmation_hash_consumed(
                registry,
                confirmation_hash,
            )

            && cross_network_security::is_proof_consumed(
                registry,
                proof_fingerprint,
            )
    }
}
