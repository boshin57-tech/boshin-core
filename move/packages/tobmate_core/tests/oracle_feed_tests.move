#[test_only]
module tobmate_core::oracle_feed_tests;

use sui::clock;
use sui::test_scenario;
use sui::transfer;

use tobmate_core::oracle;
use tobmate_core::oracle_feed;

const ADMIN: address = @0xA11CE;
const PUBLISHER: address = @0xB0B;

const XAU_USD: vector<u8> = b"XAU_USD";

const HEARTBEAT_MS: u64 = 60_000;
const MIN_PRICE: u64 = 100_000_000;
const MAX_PRICE: u64 = 1_000_000_000;
const VALID_PRICE: u64 = 250_000_000;

/* ============================================================
   Setup helper
   ============================================================ */

fun initialize_registry_and_store(
    scenario: &mut test_scenario::Scenario,
) {
    let admin_cap = oracle::create_registry(scenario.ctx());
    transfer::public_transfer(admin_cap, ADMIN);

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle_feed::create_feed_store(
            &registry,
            &admin_cap,
            scenario.ctx(),
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };
}

fun register_default_feed(
    scenario: &mut test_scenario::Scenario,
): u64 {
    scenario.next_tx(ADMIN);

    let registry =
        scenario.take_shared<oracle::OracleRegistry>();

    let mut store =
        scenario.take_shared<oracle_feed::OracleFeedStore>();

    let admin_cap =
        scenario.take_from_sender<oracle::OracleAdminCap>();

    let feed_id = oracle_feed::register_feed(
        &registry,
        &mut store,
        &admin_cap,
        XAU_USD,
        8,
        HEARTBEAT_MS,
        MIN_PRICE,
        MAX_PRICE,
    );

    test_scenario::return_shared(registry);
    test_scenario::return_shared(store);
    scenario.return_to_sender(admin_cap);

    feed_id
}

fun register_default_publisher(
    scenario: &mut test_scenario::Scenario,
) {
    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        let publisher_cap = oracle::register_publisher(
            &mut registry,
            &admin_cap,
            PUBLISHER,
            100,
            scenario.ctx(),
        );

        transfer::public_transfer(
            publisher_cap,
            PUBLISHER,
        );

        test_scenario::return_shared(registry);
        scenario.return_to_sender(admin_cap);
    };
}

/* ============================================================
   Test 1
   Initial FeedStore
   ============================================================ */

#[test]
fun feed_store_initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        assert!(
            oracle_feed::store_registry_id(&store)
                == oracle::registry_id(&registry),
            0,
        );

        assert!(
            oracle_feed::feed_count(&store) == 0,
            1,
        );

        assert!(
            oracle_feed::observation_count(&store) == 0,
            2,
        );

        test_scenario::return_shared(registry);
        test_scenario::return_shared(store);
    };

    scenario.end();
}

/* ============================================================
   Test 2
   Feed registration
   ============================================================ */

#[test]
fun feed_registration_updates_store() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);

    let feed_id = register_default_feed(&mut scenario);

    scenario.next_tx(ADMIN);

    {
        let store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        assert!(feed_id == 1, 10);
        assert!(oracle_feed::feed_count(&store) == 1, 11);
        assert!(oracle_feed::feed_exists(&store, 1), 12);
        assert!(oracle_feed::feed_decimals(&store, 1) == 8, 13);

        assert!(
            oracle_feed::feed_heartbeat_ms(&store, 1)
                == HEARTBEAT_MS,
            14,
        );

        assert!(
            oracle_feed::feed_min_price(&store, 1)
                == MIN_PRICE,
            15,
        );

        assert!(
            oracle_feed::feed_max_price(&store, 1)
                == MAX_PRICE,
            16,
        );

        assert!(
            !oracle_feed::feed_is_paused(&store, 1),
            17,
        );

        test_scenario::return_shared(store);
    };

    scenario.end();
}

/* ============================================================
   Test 3
   Feed policy update
   ============================================================ */

#[test]
fun feed_policy_can_be_updated() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);
    register_default_feed(&mut scenario);

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let mut store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle_feed::update_feed_policy(
            &registry,
            &mut store,
            &admin_cap,
            1,
            120_000,
            150_000_000,
            900_000_000,
        );

        assert!(
            oracle_feed::feed_heartbeat_ms(&store, 1)
                == 120_000,
            20,
        );

        assert!(
            oracle_feed::feed_min_price(&store, 1)
                == 150_000_000,
            21,
        );

        assert!(
            oracle_feed::feed_max_price(&store, 1)
                == 900_000_000,
            22,
        );

        test_scenario::return_shared(registry);
        test_scenario::return_shared(store);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 4
   Feed pause lifecycle
   ============================================================ */

#[test]
fun feed_pause_can_be_updated() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);
    register_default_feed(&mut scenario);

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let mut store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle_feed::set_feed_paused(
            &registry,
            &mut store,
            &admin_cap,
            1,
            true,
        );

        assert!(
            oracle_feed::feed_is_paused(&store, 1),
            30,
        );

        oracle_feed::set_feed_paused(
            &registry,
            &mut store,
            &admin_cap,
            1,
            false,
        );

        assert!(
            !oracle_feed::feed_is_paused(&store, 1),
            31,
        );

        test_scenario::return_shared(registry);
        test_scenario::return_shared(store);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Test 5
   Observation submission
   ============================================================ */

#[test]
fun valid_observation_updates_latest_price() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);
    register_default_feed(&mut scenario);
    register_default_publisher(&mut scenario);

    scenario.next_tx(PUBLISHER);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let mut store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        let publisher_cap =
            scenario.take_from_sender<oracle::OraclePublisherCap>();

        let mut clock =
            clock::create_for_testing(scenario.ctx());

        clock::increment_for_testing(
            &mut clock,
            10_000,
        );

        oracle_feed::submit_observation(
            &registry,
            &mut store,
            &publisher_cap,
            1,
            1,
            VALID_PRICE,
            50,
            10_000,
            &clock,
            scenario.ctx(),
        );

        assert!(
            oracle_feed::latest_round(&store, 1) == 1,
            40,
        );

        assert!(
            oracle_feed::latest_price(&store, 1)
                == VALID_PRICE,
            41,
        );

        assert!(
            oracle_feed::latest_confidence_bps(&store, 1)
                == 50,
            42,
        );

        assert!(
            oracle_feed::latest_timestamp_ms(&store, 1)
                == 10_000,
            43,
        );

        assert!(
            oracle_feed::feed_observation_count(&store, 1)
                == 1,
            44,
        );

        assert!(
            oracle_feed::observation_count(&store) == 1,
            45,
        );

        test_scenario::return_shared(registry);
        test_scenario::return_shared(store);
        scenario.return_to_sender(publisher_cap);

        clock::destroy_for_testing(clock);
    };

    scenario.end();
}

/* ============================================================
   Failure Test 1
   Duplicate feed symbol
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 103,
    location = tobmate_core::oracle_feed
)]
fun duplicate_feed_symbol_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);
    register_default_feed(&mut scenario);

    register_default_feed(&mut scenario);

    scenario.end();
}

/* ============================================================
   Failure Test 2
   Invalid decimals
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 106,
    location = tobmate_core::oracle_feed
)]
fun decimals_above_eighteen_abort() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let mut store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle_feed::register_feed(
            &registry,
            &mut store,
            &admin_cap,
            b"INVALID",
            19,
            HEARTBEAT_MS,
            MIN_PRICE,
            MAX_PRICE,
        );

        test_scenario::return_shared(registry);
        test_scenario::return_shared(store);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

/* ============================================================
   Failure Test 3
   Invalid heartbeat
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 107,
    location = tobmate_core::oracle_feed
)]
fun zero_heartbeat_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    initialize_registry_and_store(&mut scenario);

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<oracle::OracleRegistry>();

        let mut store =
            scenario.take_shared<oracle_feed::OracleFeedStore>();

        let admin_cap =
            scenario.take_from_sender<oracle::OracleAdminCap>();

        oracle_feed::register_feed(
            &registry,
            &mut store,
            &admin_cap,
            b"INVALID",
            8,
            0,
            MIN_PRICE,
            MAX_PRICE,
        );

        test_scenario::return_shared(registry);
        test_scenario::return_shared(store);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}
