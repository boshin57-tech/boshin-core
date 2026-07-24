#[test_only]
module tobmate_core::oracle_tests;

use sui::test_scenario;
use sui::transfer;
use tobmate_core::oracle;

const ADMIN: address = @0xA11CE;
const PUBLISHER_ONE: address = @0xB0B;
const PUBLISHER_TWO: address = @0xCAFE;

/* ============================================================
   Test 1
   Registry initial state
   ============================================================ */

#[test]
fun registry_initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());

        assert!(
            oracle::protocol_version() == 1,
            0,
        );

        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        assert!(
            oracle::registry_version(&registry) == 1,
            1,
        );

        assert!(
            !oracle::is_paused(&registry),
            2,
        );

        assert!(
            oracle::active_publisher_count(&registry) == 0,
            3,
        );

        assert!(
            oracle::total_publisher_count(&registry) == 0,
            4,
        );

        assert!(
            oracle::admin_registry_id(&admin_cap)
                == oracle::registry_id(&registry),
            5,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 2
   Publisher registration
   ============================================================ */

#[test]
fun publisher_registration_updates_registry() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            100,
            scenario.ctx(),
        );

        assert!(
            oracle::publisher_cap_id(&publisher_cap) == 1,
            10,
        );

        assert!(
            oracle::publisher_cap_registry_id(&publisher_cap)
                == oracle::registry_id(&registry),
            11,
        );

        assert!(
            oracle::publisher_exists(&registry, 1),
            12,
        );

        assert!(
            oracle::publisher_address(&registry, 1)
                == PUBLISHER_ONE,
            13,
        );

        assert!(
            oracle::publisher_weight(&registry, 1) == 100,
            14,
        );

        assert!(
            oracle::publisher_is_active(&registry, 1),
            15,
        );

        assert!(
            oracle::active_publisher_count(&registry) == 1,
            16,
        );

        assert!(
            oracle::total_publisher_count(&registry) == 1,
            17,
        );

        transfer::public_transfer(publisher_cap, PUBLISHER_ONE);

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 3
   Publisher IDs are monotonic
   ============================================================ */

#[test]
fun publisher_ids_are_monotonic() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap_one = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            100,
            scenario.ctx(),
        );

        let publisher_cap_two = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_TWO,
            200,
            scenario.ctx(),
        );

        assert!(
            oracle::publisher_cap_id(&publisher_cap_one) == 1,
            20,
        );

        assert!(
            oracle::publisher_cap_id(&publisher_cap_two) == 2,
            21,
        );

        assert!(
            oracle::active_publisher_count(&registry) == 2,
            22,
        );

        assert!(
            oracle::total_publisher_count(&registry) == 2,
            23,
        );

        transfer::public_transfer(
            publisher_cap_one,
            PUBLISHER_ONE,
        );

        transfer::public_transfer(
            publisher_cap_two,
            PUBLISHER_TWO,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 4
   Publisher status lifecycle
   ============================================================ */

#[test]
fun publisher_status_can_be_updated() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            100,
            scenario.ctx(),
        );

        oracle::set_publisher_status(
            &mut registry,
            &admin_cap,
            1,
            false,
        );

        assert!(
            !oracle::publisher_is_active(&registry, 1),
            30,
        );

        assert!(
            oracle::active_publisher_count(&registry) == 0,
            31,
        );

        oracle::set_publisher_status(
            &mut registry,
            &admin_cap,
            1,
            true,
        );

        assert!(
            oracle::publisher_is_active(&registry, 1),
            32,
        );

        assert!(
            oracle::active_publisher_count(&registry) == 1,
            33,
        );

        assert!(
            oracle::total_publisher_count(&registry) == 1,
            34,
        );

        transfer::public_transfer(publisher_cap, PUBLISHER_ONE);

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 5
   Publisher weight update
   ============================================================ */

#[test]
fun publisher_weight_can_be_updated() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            100,
            scenario.ctx(),
        );

        oracle::set_publisher_weight(
            &mut registry,
            &admin_cap,
            1,
            250,
        );

        assert!(
            oracle::publisher_weight(&registry, 1) == 250,
            40,
        );

        transfer::public_transfer(publisher_cap, PUBLISHER_ONE);

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 6
   Protocol pause lifecycle
   ============================================================ */

#[test]
fun protocol_pause_can_be_updated() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle::set_protocol_paused(
            &mut registry,
            &admin_cap,
            true,
        );

        assert!(
            oracle::is_paused(&registry),
            50,
        );

        oracle::set_protocol_paused(
            &mut registry,
            &admin_cap,
            false,
        );

        assert!(
            !oracle::is_paused(&registry),
            51,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 7
   Protocol version update
   ============================================================ */

#[test]
fun protocol_version_can_be_upgraded() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle::update_version(
            &mut registry,
            &admin_cap,
            1,
            2,
        );

        assert!(
            oracle::registry_version(&registry) == 2,
            60,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 8
   Publisher capability validation
   ============================================================ */

#[test]
fun active_publisher_capability_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            100,
            scenario.ctx(),
        );

        transfer::public_transfer(publisher_cap, PUBLISHER_ONE);

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.next_tx(PUBLISHER_ONE);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let publisher_cap =
            scenario.take_from_sender<oracle::OraclePublisherCap>();

        oracle::assert_valid_publisher(
            &registry,
            &publisher_cap,
            PUBLISHER_ONE,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(publisher_cap);
    };

    scenario.end();
}

/* ============================================================
   Failure Test 1
   Zero publisher weight
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::oracle
)]
fun zero_publisher_weight_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            0,
            scenario.ctx(),
        );

        transfer::public_transfer(publisher_cap, PUBLISHER_ONE);

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Failure Test 2
   Registration while protocol paused
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::oracle
)]
fun paused_protocol_blocks_publisher_registration() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle::set_protocol_paused(
            &mut registry,
            &admin_cap,
            true,
        );

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER_ONE,
            100,
            scenario.ctx(),
        );

        transfer::public_transfer(publisher_cap, PUBLISHER_ONE);

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Failure Test 3
   Non-increasing version
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::oracle
)]
fun non_increasing_version_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let admin_cap = oracle::create_registry(scenario.ctx());
        transfer::public_transfer(admin_cap, ADMIN);
    };

    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle::update_version(
            &mut registry,
            &admin_cap,
            1,
            1,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}
