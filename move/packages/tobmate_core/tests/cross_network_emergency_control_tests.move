#[test_only]
module tobmate_core::cross_network_emergency_control_tests {

    use tobmate_core::cross_network_emergency_control;


    #[test]
    fun test_01_global_pause_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        assert!(
            !cross_network_emergency_control::
                is_global_paused(&registry),
            8101,
        );

        cross_network_emergency_control::
            activate_global_pause(
                &mut registry,
            );

        assert!(
            cross_network_emergency_control::
                is_global_paused(&registry),
            8102,
        );

        cross_network_emergency_control::
            deactivate_global_pause(
                &mut registry,
            );

        assert!(
            !cross_network_emergency_control::
                is_global_paused(&registry),
            8103,
        );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_02_recovery_freeze_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_recovery_freeze(
                &mut registry,
            );

        assert!(
            cross_network_emergency_control::
                is_recovery_frozen(&registry),
            8201,
        );

        cross_network_emergency_control::
            deactivate_recovery_freeze(
                &mut registry,
            );

        assert!(
            !cross_network_emergency_control::
                is_recovery_frozen(&registry),
            8202,
        );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    fun test_03_incident_mode_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut registry,
                b"bridge-finality-incident",
            );

        assert!(
            cross_network_emergency_control::
                is_incident_active(&registry),
            8301,
        );

        assert!(
            cross_network_emergency_control::
                incident_code(&registry)
                == &b"bridge-finality-incident",
            8302,
        );

        cross_network_emergency_control::
            deactivate_incident_mode(
                &mut registry,
            );

        assert!(
            !cross_network_emergency_control::
                is_incident_active(&registry),
            8303,
        );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }

    #[test]
    fun test_04_operator_suspension_lifecycle() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let operator = @0xB;

        cross_network_emergency_control::
            suspend_operator(
                &mut registry,
                operator,
            );

        assert!(
            cross_network_emergency_control::
                is_operator_suspended(
                    &registry,
                    operator,
                ),
            8401,
        );

        assert!(
            cross_network_emergency_control::
                suspended_operator_count(
                    &registry,
                ) == 1,
            8402,
        );

        cross_network_emergency_control::
            restore_operator(
                &mut registry,
                operator,
            );

        assert!(
            !cross_network_emergency_control::
                is_operator_suspended(
                    &registry,
                    operator,
                ),
            8403,
        );

        assert!(
            cross_network_emergency_control::
                suspended_operator_count(
                    &registry,
                ) == 0,
            8404,
        );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1208009)]
    fun test_05_global_pause_blocks_execution() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_global_pause(
                &mut registry,
            );

        cross_network_emergency_control::
            assert_execution_allowed(
                &registry,
                @0xB,
            );

        abort 8500
    }


    #[test]
    #[expected_failure(abort_code = 1208012)]
    fun test_06_incident_mode_blocks_execution() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_incident_mode(
                &mut registry,
                b"critical-cross-network-incident",
            );

        cross_network_emergency_control::
            assert_execution_allowed(
                &registry,
                @0xB,
            );

        abort 8600
    }

    #[test]
    #[expected_failure(abort_code = 1208011)]
    fun test_07_suspended_operator_blocks_execution() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        let operator = @0xB;

        cross_network_emergency_control::
            suspend_operator(
                &mut registry,
                operator,
            );

        cross_network_emergency_control::
            assert_execution_allowed(
                &registry,
                operator,
            );

        abort 8700
    }


    #[test]
    #[expected_failure(abort_code = 1208010)]
    fun test_08_recovery_freeze_blocks_recovery() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_recovery_freeze(
                &mut registry,
            );

        cross_network_emergency_control::
            assert_recovery_allowed(
                &registry,
            );

        abort 8800
    }

    #[test]
    fun test_09_normal_state_allows_execution_and_recovery() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            assert_execution_allowed(
                &registry,
                @0xB,
            );

        cross_network_emergency_control::
            assert_recovery_allowed(
                &registry,
            );

        cross_network_emergency_control::
            destroy_emergency_registry_for_testing(
                registry,
            );

        sui::test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 1208001)]
    fun test_10_duplicate_global_pause_rejected() {
        let mut scenario =
            sui::test_scenario::begin(@0xA);

        let mut registry =
            cross_network_emergency_control::
                new_emergency_control_registry(
                    sui::test_scenario::ctx(&mut scenario),
                );

        cross_network_emergency_control::
            activate_global_pause(
                &mut registry,
            );

        cross_network_emergency_control::
            activate_global_pause(
                &mut registry,
            );

        abort 81000
    }
}
