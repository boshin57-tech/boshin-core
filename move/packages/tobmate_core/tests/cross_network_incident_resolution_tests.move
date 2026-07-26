#[test_only]
module tobmate_core::cross_network_incident_resolution_tests {

    use tobmate_core::cross_network_emergency_control;
    use tobmate_core::cross_network_governance_authorization;
    use tobmate_core::cross_network_incident_resolution;


    #[test]
    fun test_01_create_resolution_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-001",
            );

        let mut registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut registry,
                    &emergency,
                    b"incident-8c-001",
                    b"verified-resolution-evidence",
                    sui::test_scenario::ctx(&mut scenario),
                );

        assert!(
            cross_network_incident_resolution::
                resolution_status(&resolution)
                == cross_network_incident_resolution::
                    resolution_pending_status(),
            82101,
        );

        assert!(
            cross_network_incident_resolution::
                total_resolutions(&registry) == 1,
            82102,
        );

        cross_network_incident_resolution::
            destroy_resolution_for_testing(
                resolution,
            );

        cross_network_incident_resolution::
            destroy_resolution_registry_for_testing(
                registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1208201)]
    fun test_02_no_active_incident_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let _resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut registry,
                    &emergency,
                    b"incident-8c-002",
                    b"evidence",
                    sui::test_scenario::ctx(&mut scenario),
                );

        abort 82200
    }


    #[test]
    #[expected_failure(abort_code = 1208202)]
    fun test_03_wrong_incident_code_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-003-a",
            );

        let mut registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let _resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut registry,
                    &emergency,
                    b"incident-8c-003-b",
                    b"evidence",
                    sui::test_scenario::ctx(&mut scenario),
                );

        abort 82300
    }

    #[test]
    #[expected_failure(abort_code = 1208203)]
    fun test_04_empty_evidence_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-004",
            );

        let mut registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let _resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut registry,
                    &emergency,
                    b"incident-8c-004",
                    b"",
                    sui::test_scenario::ctx(&mut scenario),
                );

        abort 82400
    }


    #[test]
    fun test_05_approve_resolution_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-005",
            );

        let mut registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut registry,
                    &emergency,
                    b"incident-8c-005",
                    b"verified-resolution-evidence-005",
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            approve_resolution(
                &mut resolution,
            );

        assert!(
            cross_network_incident_resolution::
                resolution_status(&resolution)
                == cross_network_incident_resolution::
                    resolution_approved_status(),
            82501,
        );

        cross_network_incident_resolution::
            destroy_resolution_for_testing(
                resolution,
            );

        cross_network_incident_resolution::
            destroy_resolution_registry_for_testing(
                registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1208205)]
    fun test_06_double_approve_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-006",
            );

        let mut registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut registry,
                    &emergency,
                    b"incident-8c-006",
                    b"verified-resolution-evidence-006",
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            approve_resolution(
                &mut resolution,
            );

        cross_network_incident_resolution::
            approve_resolution(
                &mut resolution,
            );

        abort 82600
    }

    #[test]
    #[expected_failure(abort_code = 1208204)]
    fun test_07_unapproved_resolution_close_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-007",
            );

        let mut resolution_registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut resolution_registry,
                    &emergency,
                    b"incident-8c-007",
                    b"resolution-evidence-007",
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut governance_registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut governance_registry,
                    cross_network_governance_authorization::
                        action_incident_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            close_incident(
                &mut resolution,
                &mut authorization,
                &mut emergency,
                0,
            );

        abort 82700
    }


    #[test]
    fun test_08_approved_resolution_closes_incident() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-008",
            );

        let mut resolution_registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut resolution_registry,
                    &emergency,
                    b"incident-8c-008",
                    b"resolution-evidence-008",
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            approve_resolution(
                &mut resolution,
            );

        let mut governance_registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut governance_registry,
                    cross_network_governance_authorization::
                        action_incident_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            close_incident(
                &mut resolution,
                &mut authorization,
                &mut emergency,
                0,
            );

        assert!(
            !cross_network_emergency_control::
                is_incident_active(
                    &emergency,
                ),
            82801,
        );

        assert!(
            cross_network_incident_resolution::
                resolution_status(
                    &resolution,
                )
                == cross_network_incident_resolution::
                    resolution_consumed_status(),
            82802,
        );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                authorization,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                governance_registry,
            );

        cross_network_incident_resolution::
            destroy_resolution_for_testing(
                resolution,
            );

        cross_network_incident_resolution::
            destroy_resolution_registry_for_testing(
                resolution_registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }

    #[test]
    fun test_09_controlled_global_unpause_success() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_global_pause(
                &mut emergency,
            );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-009",
            );

        let mut resolution_registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut resolution_registry,
                    &emergency,
                    b"incident-8c-009",
                    b"resolution-evidence-009",
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            approve_resolution(
                &mut resolution,
            );

        let mut governance_registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut incident_off_auth =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut governance_registry,
                    cross_network_governance_authorization::
                        action_incident_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            close_incident(
                &mut resolution,
                &mut incident_off_auth,
                &mut emergency,
                0,
            );

        let mut unpause_auth =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut governance_registry,
                    cross_network_governance_authorization::
                        action_global_pause_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            controlled_global_unpause(
                &resolution,
                &mut unpause_auth,
                &mut emergency,
                0,
            );

        assert!(
            !cross_network_emergency_control::
                is_global_paused(
                    &emergency,
                ),
            82901,
        );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                incident_off_auth,
            );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                unpause_auth,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                governance_registry,
            );

        cross_network_incident_resolution::
            destroy_resolution_for_testing(
                resolution,
            );

        cross_network_incident_resolution::
            destroy_resolution_registry_for_testing(
                resolution_registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1208206)]
    fun test_10_unconsumed_resolution_unpause_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_global_pause(
                &mut emergency,
            );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut emergency,
                b"incident-8c-010",
            );

        let mut resolution_registry =
            cross_network_incident_resolution::
                new_resolution_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut resolution =
            cross_network_incident_resolution::
                create_resolution(
                    &mut resolution_registry,
                    &emergency,
                    b"incident-8c-010",
                    b"resolution-evidence-010",
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            approve_resolution(
                &mut resolution,
            );

        let mut governance_registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut unpause_auth =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut governance_registry,
                    cross_network_governance_authorization::
                        action_global_pause_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_incident_resolution::
            controlled_global_unpause(
                &resolution,
                &mut unpause_auth,
                &mut emergency,
                0,
            );

        abort 821000
    }
}
