module tobmate_enterprise_security::cross_network_remediation_execution_binding {

    use tobmate_enterprise_security::cross_network_remediation;
    use tobmate_enterprise_security::cross_network_remediation_execution_governance;
    use tobmate_enterprise_security::cross_network_security_orchestrator;


    // ============================================================
    // Errors
    // ============================================================

    const E_REMEDIATION_NOT_BOUND: u64 = 1207501;
    const E_EXECUTION_NOT_COMPLETED: u64 = 1207502;


    // ============================================================
    // Confirm actual remediation execution evidence
    // ============================================================

    public fun confirm_execution(
        state:
            &mut cross_network_security_orchestrator::
                SecurityOrchestrationState,

        governance:
            &cross_network_remediation_execution_governance::
                RemediationExecutionGovernance,

        remediation:
            &cross_network_remediation::
                RemediationRecord,

        receipt:
            &cross_network_remediation_execution_governance::
                RemediationExecutionReceipt,
    ) {

        assert!(
            cross_network_security_orchestrator::
                status(state)
                ==
            cross_network_security_orchestrator::
                status_remediating(),
            E_REMEDIATION_NOT_BOUND,
        );

        assert!(
            cross_network_remediation_execution_governance::
                status(governance)
                ==
            cross_network_remediation_execution_governance::
                status_completed(),
            E_EXECUTION_NOT_COMPLETED,
        );

        cross_network_remediation_execution_governance::
            assert_execution_binding(
                receipt,
                remediation,
            );

        cross_network_security_orchestrator::
            confirm_remediation_execution(
                state,
            );
    }
}
