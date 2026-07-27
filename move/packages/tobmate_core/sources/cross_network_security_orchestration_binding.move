module tobmate_core::cross_network_security_orchestration_binding {

    use tobmate_core::cross_network_recovery_control;
    use tobmate_core::cross_network_recovery_authorization;
    use tobmate_core::cross_network_remediation;
    use tobmate_core::cross_network_security_orchestrator;

    const E_CASE_NOT_APPROVED: u64 = 1;
    const E_AUTH_CASE_MISMATCH: u64 = 2;
    const E_AUTH_NOT_PENDING: u64 = 3;
    const E_AUTH_NOT_CONSUMED: u64 = 4;
    const E_REMEDIATION_CASE_MISMATCH: u64 = 5;
    const E_REMEDIATION_AUTH_MISMATCH: u64 = 6;
    const E_INVALID_REMEDIATION_AMOUNT: u64 = 7;

    // ============================================================
    // Bind approved RecoveryCase into orchestration lifecycle.
    // ============================================================

    public fun bind_recovery_case(
        state:
            &mut cross_network_security_orchestrator::
                SecurityOrchestrationState,

        case:
            &cross_network_recovery_control::
                RecoveryCase,
    ) {

        assert!(
            cross_network_recovery_control::
                case_status(case)
                ==
                cross_network_recovery_control::
                    case_approved_status(),
            E_CASE_NOT_APPROVED,
        );

        let case_id =
            *cross_network_recovery_control::
                case_id(case);

        cross_network_security_orchestrator::
            bind_recovery_case_id(
                state,
                case_id,
            );
    }

    // ============================================================
    // Bind newly issued PENDING authorization.
    // ============================================================

    public fun bind_pending_authorization(
        state:
            &mut cross_network_security_orchestrator::
                SecurityOrchestrationState,

        case:
            &cross_network_recovery_control::
                RecoveryCase,

        authorization:
            &cross_network_recovery_authorization::
                RecoveryAuthorization,
    ) {

        cross_network_recovery_authorization::
            assert_authorization_case_binding(
                authorization,
                case,
            );

        assert!(
            cross_network_recovery_authorization::
                authorization_status(authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_pending_status(),
            E_AUTH_NOT_PENDING,
        );

        assert!(
            cross_network_recovery_authorization::
                authorization_case_id(authorization)
                ==
                cross_network_recovery_control::
                    case_id(case),
            E_AUTH_CASE_MISMATCH,
        );

        let authorization_id =
            *cross_network_recovery_authorization::
                authorization_id(authorization);

        cross_network_security_orchestrator::
            bind_authorization_id(
                state,
                authorization_id,
            );
    }

    // ============================================================
    // Confirm authorization consumption.
    // This is the prerequisite for remediation evidence.
    // ============================================================

    public fun confirm_consumed_authorization(
        state:
            &mut cross_network_security_orchestrator::
                SecurityOrchestrationState,

        case:
            &cross_network_recovery_control::
                RecoveryCase,

        authorization:
            &cross_network_recovery_authorization::
                RecoveryAuthorization,
    ) {

        cross_network_recovery_authorization::
            assert_authorization_case_binding(
                authorization,
                case,
            );

        assert!(
            cross_network_recovery_authorization::
                is_authorization_consumed(
                    authorization,
                ),
            E_AUTH_NOT_CONSUMED,
        );

        assert!(
            cross_network_recovery_authorization::
                authorization_case_id(authorization)
                ==
                cross_network_recovery_control::
                    case_id(case),
            E_AUTH_CASE_MISMATCH,
        );

        cross_network_security_orchestrator::
            confirm_authorization_consumed(
                state,
            );
    }

    // ============================================================
    // Bind remediation evidence.
    //
    // Required:
    // - authorization already CONSUMED
    // - remediation case_id == RecoveryCase case_id
    // - remediation authorization_id == RecoveryAuthorization id
    // - remediation amount > 0
    // - remediation amount <= authorized amount
    // ============================================================

    public fun bind_remediation_record(
        state:
            &mut cross_network_security_orchestrator::
                SecurityOrchestrationState,

        case:
            &cross_network_recovery_control::
                RecoveryCase,

        authorization:
            &cross_network_recovery_authorization::
                RecoveryAuthorization,

        record:
            &cross_network_remediation::
                RemediationRecord,
    ) {

        assert!(
            cross_network_recovery_authorization::
                is_authorization_consumed(
                    authorization,
                ),
            E_AUTH_NOT_CONSUMED,
        );

        cross_network_remediation::
            assert_remediation_binding(
                record,
                authorization,
                case,
            );

        assert!(
            cross_network_remediation::
                remediation_case_id(record)
                ==
                cross_network_recovery_control::
                    case_id(case),
            E_REMEDIATION_CASE_MISMATCH,
        );

        assert!(
            cross_network_remediation::
                remediation_authorization_id(record)
                ==
                cross_network_recovery_authorization::
                    authorization_id(authorization),
            E_REMEDIATION_AUTH_MISMATCH,
        );

        let remediation_amount =
            cross_network_remediation::
                remediation_amount(record);

        assert!(
            remediation_amount > 0,
            E_INVALID_REMEDIATION_AMOUNT,
        );

        assert!(
            remediation_amount
                <= cross_network_recovery_authorization::
                    authorized_amount(authorization),
            E_INVALID_REMEDIATION_AMOUNT,
        );

        let remediation_id =
            *cross_network_remediation::
                remediation_id(record);

        cross_network_security_orchestrator::
            bind_remediation_id(
                state,
                remediation_id,
            );
    }

    // ============================================================
    // Full evidence validation without state mutation.
    // Useful for audit / post-incident verification.
    // ============================================================

    public fun assert_full_binding(
        case:
            &cross_network_recovery_control::
                RecoveryCase,

        authorization:
            &cross_network_recovery_authorization::
                RecoveryAuthorization,

        record:
            &cross_network_remediation::
                RemediationRecord,
    ) {

        assert!(
            cross_network_recovery_control::
                case_status(case)
                ==
                cross_network_recovery_control::
                    case_approved_status(),
            E_CASE_NOT_APPROVED,
        );

        assert!(
            cross_network_recovery_authorization::
                authorization_case_id(authorization)
                ==
                cross_network_recovery_control::
                    case_id(case),
            E_AUTH_CASE_MISMATCH,
        );

        assert!(
            cross_network_recovery_authorization::
                is_authorization_consumed(
                    authorization,
                ),
            E_AUTH_NOT_CONSUMED,
        );

        cross_network_remediation::
            assert_remediation_binding(
                record,
                authorization,
                case,
            );

        assert!(
            cross_network_remediation::
                remediation_case_id(record)
                ==
                cross_network_recovery_control::
                    case_id(case),
            E_REMEDIATION_CASE_MISMATCH,
        );

        assert!(
            cross_network_remediation::
                remediation_authorization_id(record)
                ==
                cross_network_recovery_authorization::
                    authorization_id(authorization),
            E_REMEDIATION_AUTH_MISMATCH,
        );
    }
}
