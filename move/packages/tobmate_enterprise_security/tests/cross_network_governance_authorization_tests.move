#[test_only]
module tobmate_enterprise_security::cross_network_governance_authorization_tests {

    use tobmate_enterprise_security::cross_network_emergency_control;
    use tobmate_enterprise_security::cross_network_governance_authorization;


    #[test]
    fun test_01_global_pause_authorized() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let action =
            cross_network_governance_authorization::
                action_global_pause_on();

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    action,
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_global_pause_on(
                &mut authorization,
                &mut emergency,
                0,
            );

        assert!(
            cross_network_emergency_control::
                is_global_paused(&emergency),
            81101,
        );

        assert!(
            cross_network_governance_authorization::
                is_consumed(&authorization),
            81102,
        );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                authorization,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1208104)]
    fun test_02_wrong_action_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let action =
            cross_network_governance_authorization::
                action_global_pause_on();

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    action,
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_recovery_freeze_on(
                &mut authorization,
                &mut emergency,
                0,
            );

        abort 81200
    }


    #[test]
    #[expected_failure(abort_code = 1208103)]
    fun test_03_expired_authorization_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let action =
            cross_network_governance_authorization::
                action_global_pause_on();

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    action,
                    @0x0,
                    b"",
                    1,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_global_pause_on(
                &mut authorization,
                &mut emergency,
                2,
            );

        abort 81300
    }

    #[test]
    #[expected_failure(abort_code = 1208102)]
    fun test_04_double_consume_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_global_pause_on(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_global_pause_on(
                &mut authorization,
                &mut emergency,
                0,
            );

        cross_network_governance_authorization::
            execute_global_pause_on(
                &mut authorization,
                &mut emergency,
                0,
            );

        abort 81400
    }


    #[test]
    #[expected_failure(abort_code = 1208105)]
    fun test_05_operator_target_mismatch_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_operator_suspend(),
                    @0xB,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_operator_suspend(
                &mut authorization,
                &mut emergency,
                @0xC,
                0,
            );

        abort 81500
    }


    #[test]
    #[expected_failure(abort_code = 1208106)]
    fun test_06_incident_code_mismatch_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut authorization =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_incident_on(),
                    @0x0,
                    b"incident-a",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_incident_on(
                &mut authorization,
                &mut emergency,
                b"incident-b",
                0,
            );

        abort 81600
    }

    #[test]
    fun test_07_operator_suspend_restore_authorized() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let operator = @0xB;

        let mut suspend_auth =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_operator_suspend(),
                    operator,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_operator_suspend(
                &mut suspend_auth,
                &mut emergency,
                operator,
                0,
            );

        assert!(
            cross_network_emergency_control::
                is_operator_suspended(
                    &emergency,
                    operator,
                ),
            81701,
        );

        let mut restore_auth =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_operator_restore(),
                    operator,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_operator_restore(
                &mut restore_auth,
                &mut emergency,
                operator,
                0,
            );

        assert!(
            !cross_network_emergency_control::
                is_operator_suspended(
                    &emergency,
                    operator,
                ),
            81702,
        );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                suspend_auth,
            );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                restore_auth,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_08_incident_on_off_authorized() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut incident_on =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_incident_on(),
                    @0x0,
                    b"incident-8b-008",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_incident_on(
                &mut incident_on,
                &mut emergency,
                b"incident-8b-008",
                0,
            );

        assert!(
            cross_network_emergency_control::
                is_incident_active(
                    &emergency,
                ),
            81801,
        );

        let mut incident_off =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_incident_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_incident_off(
                &mut incident_off,
                &mut emergency,
                0,
            );

        assert!(
            !cross_network_emergency_control::
                is_incident_active(
                    &emergency,
                ),
            81802,
        );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                incident_on,
            );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                incident_off,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }

    #[test]
    fun test_09_recovery_freeze_on_off_authorized() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut emergency =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let mut freeze_on =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_recovery_freeze_on(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_recovery_freeze_on(
                &mut freeze_on,
                &mut emergency,
                0,
            );

        assert!(
            cross_network_emergency_control::
                is_recovery_frozen(
                    &emergency,
                ),
            81901,
        );

        let mut freeze_off =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    cross_network_governance_authorization::
                        action_recovery_freeze_off(),
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_governance_authorization::
            execute_recovery_freeze_off(
                &mut freeze_off,
                &mut emergency,
                0,
            );

        assert!(
            !cross_network_emergency_control::
                is_recovery_frozen(
                    &emergency,
                ),
            81902,
        );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                freeze_on,
            );

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                freeze_off,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                emergency,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_10_registry_count_and_deterministic_id() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_governance_authorization::
                new_governance_authorization_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let action =
            cross_network_governance_authorization::
                action_global_pause_on();

        let auth =
            cross_network_governance_authorization::
                issue_governance_authorization(
                    &mut registry,
                    action,
                    @0x0,
                    b"",
                    10,
                    sui::test_scenario::ctx(&mut scenario),
                );

        assert!(
            cross_network_governance_authorization::
                total_governance_authorizations(
                    &registry,
                ) == 1,
            811001,
        );

        let id_a =
            cross_network_governance_authorization::
                calculate_governance_authorization_id(
                    action,
                    @0x0,
                    b"",
                    1,
                    0,
                    10,
                );

        let id_b =
            cross_network_governance_authorization::
                calculate_governance_authorization_id(
                    action,
                    @0x0,
                    b"",
                    1,
                    0,
                    10,
                );

        assert!(id_a == id_b, 811002);

        cross_network_governance_authorization::
            destroy_governance_authorization_for_testing(
                auth,
            );

        cross_network_governance_authorization::
            destroy_governance_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }
}
