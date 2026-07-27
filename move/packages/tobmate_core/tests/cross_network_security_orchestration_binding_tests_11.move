#[test_only]
module tobmate_core::cross_network_security_orchestration_binding_tests_11 {

    use tobmate_core::cross_network_security;
    use tobmate_core::cross_network_execution_receipt;
    use tobmate_core::cross_network_recovery_control;
    use tobmate_core::cross_network_recovery_authorization;
    use tobmate_core::cross_network_remediation;

    use tobmate_core::cross_network_security_orchestrator;
    use tobmate_core::cross_network_security_orchestration_binding;

    use tobmate_core::cross_network_security_telemetry;
    use tobmate_core::cross_network_anomaly_scoring;
    use tobmate_core::cross_network_incident_severity;
    use tobmate_core::cross_network_security_snapshot;
    use tobmate_core::cross_network_security_response_policy;
    use tobmate_core::cross_network_incident_containment;

    #[test]
    fun test_11_full_orchestration_evidence_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut orchestration =
            cross_network_security_orchestrator::
                new_state_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_orchestrator::
            set_open_state_for_testing(
                &mut orchestration,
                1,
            );


        let binding =
            cross_network_security::new_binding(
                b"network-a",
                b"domain-a",
                b"network-b",
                b"domain-b",
            );

        let intent_binding =
            cross_network_security::new_intent_finality_binding(
                &binding,
                b"intent-7b-001",
                b"finality-7b-001",
            );

        let mut record =
            cross_network_security::new_terminal_finality_record(
                &binding,
                &intent_binding,
            );

        cross_network_security::mark_finality_confirmed(
            &mut record,
            &binding,
            &intent_binding,
        );

        let mut replay_registry =
            cross_network_security::new_replay_protection_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let receipt =
            cross_network_execution_receipt::execute_and_anchor(
                &mut replay_registry,
                &mut record,
                &binding,
                &intent_binding,
                b"external-7b-001",
                b"confirmation-7b-001",
                b"proof-7b-001",
                1,
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case_registry =
            cross_network_recovery_control::new_recovery_case_registry(
                sui::test_scenario::ctx(&mut scenario),
            );

        let mut case =
            cross_network_recovery_control::open_recovery_case(
                &mut case_registry,
                &receipt,
                b"recovery-approved",
                10000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_recovery_control::begin_case_review(
            &mut case,
            &receipt,
        );

        cross_network_recovery_control::approve_recovery_case(
            &mut case,
            &receipt,
        );


        cross_network_security_orchestration_binding::
            bind_recovery_case(
                &mut orchestration,
                &case,
            );

        assert!(
            cross_network_recovery_control::
                case_status(&case)
                ==
                cross_network_recovery_control::
                    case_approved_status(),
            73001,
        );

        let mut auth_registry =
            cross_network_recovery_authorization::
                new_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_recovery_authorization::issue_authorization(
                &mut auth_registry,
                &case,
                8000,
                sui::test_scenario::ctx(&mut scenario),
            );

        cross_network_security_orchestration_binding::
            bind_pending_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );


        assert!(
            cross_network_recovery_authorization::
                authorization_status(&authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_pending_status(),
            73019,
        );

        cross_network_recovery_authorization::
            consume_authorization(
                &mut authorization,
                &case,
            );

        assert!(
            cross_network_recovery_authorization::
                authorization_status(&authorization)
                ==
                cross_network_recovery_authorization::
                    authorization_consumed_status(),
            73020,
        );

        cross_network_security_orchestration_binding::
            confirm_consumed_authorization(
                &mut orchestration,
                &case,
                &authorization,
            );

        assert!(
            cross_network_security_orchestrator::
                authorization_complete(&orchestration),
            73021,
        );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_authorized(),
            73021,
        );

        assert!(
            cross_network_recovery_authorization::
                authorized_amount(&authorization) == 8000,
            71001,
        );


        let mut remediation_registry =
            cross_network_remediation::
                new_remediation_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let remediation =
            cross_network_remediation::
                create_remediation_record(
                    &mut remediation_registry,
                    &authorization,
                    &case,
                    b"security-remediation",
                    8000,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_orchestration_binding::
            bind_remediation_record(
                &mut orchestration,
                &case,
                &authorization,
                &remediation,
            );

        cross_network_security_orchestration_binding::
            assert_full_binding(
                &case,
                &authorization,
                &remediation,
            );


        // ========================================================
        // Begin recovery only after remediation evidence.
        // ========================================================

        cross_network_security_orchestrator::
            begin_recovery(
                &mut orchestration,
            );

        assert!(
            cross_network_security_orchestrator::
                recovery_started(&orchestration),
            73110,
        );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_recovering(),
            73111,
        );

        // ========================================================
        // Build a fresh clean post-incident security snapshot.
        // ========================================================

        let mut telemetry =
            cross_network_security_telemetry::
                new_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let anomaly =
            cross_network_anomaly_scoring::
                new_default_policy_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let incident_policy =
            cross_network_incident_severity::
                new_default_policy_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let incident_state =
            cross_network_incident_severity::
                new_state_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let response_policy =
            cross_network_security_response_policy::
                new_default_policy_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let containment =
            cross_network_incident_containment::
                new_state_for_testing(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_security_telemetry::
            record_execution_attempt(
                &mut telemetry,
                b"network-13a",
                b"domain-13a",
                b"operator-13a",
            );

        cross_network_security_telemetry::
            record_execution_success(
                &mut telemetry,
                b"network-13a",
                b"domain-13a",
                b"operator-13a",
            );

        let snapshot =
            cross_network_security_snapshot::
                capture(
                    &telemetry,
                    &anomaly,
                    &incident_policy,
                    &incident_state,
                    2,
                    b"network-13a",
                    b"domain-13a",
                    b"operator-13a",
                    sui::test_scenario::ctx(&mut scenario),
                );

        let decision =
            cross_network_security_response_policy::
                evaluate(
                    &response_policy,
                    &snapshot,
                );

        assert!(
            cross_network_security_response_policy::
                recovery_eligible(&decision),
            73112,
        );

        cross_network_security_orchestrator::
            verify_post_incident(
                &mut orchestration,
                &containment,
                &snapshot,
                &decision,
            );

        assert!(
            cross_network_security_orchestrator::
                post_incident_verified(&orchestration),
            73113,
        );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_verified(),
            73114,
        );

        cross_network_security_orchestrator::
            close_case(
                &mut orchestration,
            );

        assert!(
            cross_network_security_orchestrator::
                status(&orchestration)
                ==
                cross_network_security_orchestrator::
                    status_closed(),
            73115,
        );

        assert!(
            cross_network_security_orchestrator::
                close_count(&orchestration) == 1,
            73116,
        );

        cross_network_security_snapshot::
            destroy_for_testing(snapshot);

        cross_network_incident_containment::
            destroy_state_for_testing(containment);

        cross_network_security_response_policy::
            destroy_policy_for_testing(response_policy);

        cross_network_anomaly_scoring::
            destroy_policy_for_testing(anomaly);

        cross_network_incident_severity::
            destroy_policy_for_testing(incident_policy);

        cross_network_incident_severity::
            destroy_state_for_testing(incident_state);

        cross_network_security_telemetry::
            destroy_for_testing(telemetry);

        assert!(
            cross_network_remediation::
                remediation_case_id(&remediation)
                ==
                cross_network_recovery_control::
                    case_id(&case),
            73040,
        );

        assert!(
            cross_network_remediation::
                remediation_authorization_id(&remediation)
                ==
                cross_network_recovery_authorization::
                    authorization_id(&authorization),
            73041,
        );

        assert!(
            cross_network_security_orchestrator::
                remediation_complete(&orchestration),
            73042,
        );

        cross_network_remediation::
            destroy_remediation_record_for_testing(
                remediation,
            );

        cross_network_remediation::
            destroy_remediation_registry_for_testing(
                remediation_registry,
            );

        cross_network_recovery_authorization::
            destroy_authorization_for_testing(
                authorization,
            );

        cross_network_recovery_authorization::
            destroy_authorization_registry_for_testing(
                auth_registry,
            );

        cross_network_recovery_control::
            destroy_recovery_case_for_testing(case);

        cross_network_recovery_control::
            destroy_recovery_registry_for_testing(
                case_registry,
            );

        cross_network_execution_receipt::
            destroy_receipt_for_testing(receipt);

        cross_network_security::
            destroy_replay_registry_for_testing(
                replay_registry,
            );

        cross_network_security_orchestrator::
            destroy_state_for_testing(orchestration);

        sui::test_scenario::end(scenario);
    }
}
