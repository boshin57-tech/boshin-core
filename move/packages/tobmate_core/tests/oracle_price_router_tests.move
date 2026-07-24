#[test_only]
module tobmate_core::oracle_price_router_tests;

use sui::clock;
use sui::test_scenario;
use sui::transfer;

use tobmate_core::oracle;
use tobmate_core::oracle_feed;
use tobmate_core::oracle_price_router;

const ADMIN: address = @0xA11CE;
const PUBLISHER: address = @0xB0B;

const XAU_USD: vector<u8> = b"XAU_USD";
const BTC_USD: vector<u8> = b"BTC_USD";
const UNKNOWN: vector<u8> = b"UNKNOWN";

const HEARTBEAT_MS: u64 = 60_000;

const MIN_PRICE: u64 = 100_000_000;
const MAX_PRICE: u64 = 1_000_000_000;

const CANONICAL_PRICE: u64 = 250_000_000;
const CANONICAL_CONFIDENCE: u64 = 40;
const CANONICAL_TIMESTAMP: u64 = 10_000;
const QUERY_TIMESTAMP: u64 = 20_000;

/* ============================================================
   Fixtures
   ============================================================ */
fun initialize_default_feed(
    scenario: &mut test_scenario::Scenario,
): u64 {
    initialize_registry_and_store(scenario);

    register_feed(
        scenario,
        XAU_USD,
    )
}

fun initialize_canonical_feed(
    scenario: &mut test_scenario::Scenario,
): u64 {
    let feed_id =
        initialize_default_feed(scenario);

    publish_canonical_price(
        scenario,
        feed_id,
        1,
        CANONICAL_PRICE,
        CANONICAL_CONFIDENCE,
        CANONICAL_TIMESTAMP,
    );

    feed_id
}

fun register_publisher(
    scenario: &mut test_scenario::Scenario,
) {
    scenario.next_tx(ADMIN);

    {
        let mut registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let admin_cap =
            scenario.take_from_sender<
                oracle::OracleAdminCap
            >();

        let publisher_cap =
            oracle::register_publisher(
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

        test_scenario::return_shared(
            registry,
        );

        scenario.return_to_sender(
            admin_cap,
        );
    };
}

fun submit_new_observation(
    scenario: &mut test_scenario::Scenario,
    feed_id: u64,
) {
    scenario.next_tx(PUBLISHER);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let mut store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let publisher_cap =
            scenario.take_from_sender<
                oracle::OraclePublisherCap
            >();

        let mut test_clock =
            clock::create_for_testing(
                scenario.ctx(),
            );

        clock::increment_for_testing(
            &mut test_clock,
            30_000,
        );

        oracle_feed::submit_observation(
            &registry,
            &mut store,
            &publisher_cap,
            feed_id,
            2,
            255_000_000,
            45,
            30_000,
            &test_clock,
            scenario.ctx(),
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );

        scenario.return_to_sender(
            publisher_cap,
        );

        clock::destroy_for_testing(
            test_clock,
        );
    };
}

/* ============================================================
   Test 1
   Canonical state initially unavailable
   ============================================================ */

#[test]
fun canonical_state_initially_unavailable() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_default_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        assert!(
            !oracle_feed::canonical_price_is_ready(
                &store,
                feed_id,
            ),
            1,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 2
   Canonical state enabled after publication
   ============================================================ */

#[test]
fun canonical_publication_enables_router_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        assert!(
            oracle_feed::canonical_price_is_ready(
                &store,
                feed_id,
            ),
            2,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 3
   Feed ID quote success
   ============================================================ */

#[test]
fun get_price_by_feed_id_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_price(
                &quote,
            ) == CANONICAL_PRICE,
            3,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 4
   Symbol resolution success
   ============================================================ */

#[test]
fun get_price_by_symbol_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    initialize_canonical_feed(
        &mut scenario,
    );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price_by_symbol(
                &registry,
                &store,
                XAU_USD,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_feed_id(
                &quote,
            ) == 1,
            4,
        );

        assert!(
            oracle_price_router::quote_price(
                &quote,
            ) == CANONICAL_PRICE,
            5,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 5
   Registry ID getter
   ============================================================ */

#[test]
fun quote_registry_id_matches_registry() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_registry_id(
                &quote,
            ) == oracle::registry_id(
                &registry,
            ),
            6,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}
fun initialize_registry_and_store(
    scenario: &mut test_scenario::Scenario,
) {
    let admin_cap =
        oracle::create_registry(scenario.ctx());

    transfer::public_transfer(
        admin_cap,
        ADMIN,
    );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let admin_cap =
            scenario.take_from_sender<
                oracle::OracleAdminCap
            >();

        oracle_feed::create_feed_store(
            &registry,
            &admin_cap,
            scenario.ctx(),
        );

        test_scenario::return_shared(registry);

        scenario.return_to_sender(
            admin_cap,
        );
    };
}

fun register_feed(
    scenario: &mut test_scenario::Scenario,
    symbol: vector<u8>,
): u64 {

    scenario.next_tx(ADMIN);

    let registry =
        scenario.take_shared<
            oracle::OracleRegistry
        >();

    let mut store =
        scenario.take_shared<
            oracle_feed::OracleFeedStore
        >();

    let admin_cap =
        scenario.take_from_sender<
            oracle::OracleAdminCap
        >();

    let feed_id =
        oracle_feed::register_feed(
            &registry,
            &mut store,
            &admin_cap,
            symbol,
            8,
            HEARTBEAT_MS,
            MIN_PRICE,
            MAX_PRICE,
        );

    test_scenario::return_shared(
        registry,
    );

    test_scenario::return_shared(
        store,
    );

    scenario.return_to_sender(
        admin_cap,
    );

    feed_id
}

fun publish_canonical_price(
    scenario: &mut test_scenario::Scenario,
    feed_id: u64,
    round: u64,
    price: u64,
    confidence_bps: u64,
    timestamp_ms: u64,
) {

    scenario.next_tx(ADMIN);

    {
        let mut store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        oracle_feed::update_canonical_price(
            &mut store,
            feed_id,
            round,
            price,
            confidence_bps,
            timestamp_ms,
        );

        test_scenario::return_shared(
            store,
        );
    };
}
/* ============================================================
   Test 6
   Quote feed ID is correct
   ============================================================ */

#[test]
fun quote_feed_id_is_correct() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_feed_id(
                &quote,
            ) == feed_id,
            7,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 7
   Quote round is correct
   ============================================================ */

#[test]
fun quote_round_is_correct() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_round(
                &quote,
            ) == 1,
            8,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 8
   Quote confidence is correct
   ============================================================ */

#[test]
fun quote_confidence_is_correct() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_confidence_bps(
                &quote,
            ) == CANONICAL_CONFIDENCE,
            9,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 9
   Quote timestamps are correct
   ============================================================ */

#[test]
fun quote_timestamps_are_correct() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_observed_at_ms(
                &quote,
            ) == CANONICAL_TIMESTAMP,
            10,
        );

        assert!(
            oracle_price_router::quote_queried_at_ms(
                &quote,
            ) == QUERY_TIMESTAMP,
            11,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 10
   Quote age is calculated correctly
   ============================================================ */

#[test]
fun quote_age_is_calculated_correctly() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::quote_age_ms(
                &quote,
            ) ==
                QUERY_TIMESTAMP -
                CANONICAL_TIMESTAMP,
            12,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Part 4 — Freshness and effective max-age routing
   ============================================================ */

/* ============================================================
   Test 11
   Default route uses registered feed heartbeat
   ============================================================ */

#[test]
fun default_route_uses_feed_heartbeat() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let heartbeat_ms =
            oracle_feed::feed_heartbeat_ms(
                &store,
                feed_id,
            );

        let quote =
            oracle_price_router::get_price(
                &registry,
                &store,
                feed_id,
                QUERY_TIMESTAMP,
            );

        assert!(
            oracle_price_router::
                quote_effective_max_age_ms(
                    &quote,
                ) == heartbeat_ms,
            13,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 12
   Consumer max age can narrow freshness limit
   ============================================================ */

#[test]
fun custom_max_age_is_applied() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let heartbeat_ms =
            oracle_feed::feed_heartbeat_ms(
                &store,
                feed_id,
            );

        let price_age_ms =
            QUERY_TIMESTAMP -
                CANONICAL_TIMESTAMP;

        assert!(
            price_age_ms > 0,
            14,
        );

        assert!(
            price_age_ms <= heartbeat_ms,
            15,
        );

        let quote =
            oracle_price_router::
                get_price_with_max_age(
                    &registry,
                    &store,
                    feed_id,
                    QUERY_TIMESTAMP,
                    price_age_ms,
                );

        assert!(
            oracle_price_router::
                quote_effective_max_age_ms(
                    &quote,
                ) == price_age_ms,
            16,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 13
   Heartbeat remains upper freshness limit
   ============================================================ */

#[test]
fun heartbeat_caps_larger_custom_max_age() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let heartbeat_ms =
            oracle_feed::feed_heartbeat_ms(
                &store,
                feed_id,
            );

        let quote =
            oracle_price_router::
                get_price_with_max_age(
                    &registry,
                    &store,
                    feed_id,
                    QUERY_TIMESTAMP,
                    heartbeat_ms + 1,
                );

        assert!(
            oracle_price_router::
                quote_effective_max_age_ms(
                    &quote,
                ) == heartbeat_ms,
            17,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 14
   Symbol route supports custom max age
   ============================================================ */

#[test]
fun symbol_route_supports_custom_max_age() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let price_age_ms =
            QUERY_TIMESTAMP -
                CANONICAL_TIMESTAMP;

        let quote =
            oracle_price_router::
                get_price_by_symbol_with_max_age(
                    &registry,
                    &store,
                    XAU_USD,
                    QUERY_TIMESTAMP,
                    price_age_ms,
                );

        assert!(
            oracle_price_router::quote_feed_id(
                &quote,
            ) == feed_id,
            18,
        );

        assert!(
            oracle_price_router::
                quote_effective_max_age_ms(
                    &quote,
                ) == price_age_ms,
            19,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}

/* ============================================================
   Test 15
   Price is valid exactly at custom freshness boundary
   ============================================================ */

#[test]
fun price_is_valid_at_exact_max_age_boundary() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let feed_id =
        initialize_canonical_feed(
            &mut scenario,
        );

    scenario.next_tx(ADMIN);

    {
        let registry =
            scenario.take_shared<
                oracle::OracleRegistry
            >();

        let store =
            scenario.take_shared<
                oracle_feed::OracleFeedStore
            >();

        let exact_max_age_ms =
            QUERY_TIMESTAMP -
                CANONICAL_TIMESTAMP;

        let quote =
            oracle_price_router::
                get_price_with_max_age(
                    &registry,
                    &store,
                    feed_id,
                    QUERY_TIMESTAMP,
                    exact_max_age_ms,
                );

        assert!(
            oracle_price_router::quote_age_ms(
                &quote,
            ) == exact_max_age_ms,
            20,
        );

        assert!(
            oracle_price_router::
                quote_effective_max_age_ms(
                    &quote,
                ) == exact_max_age_ms,
            21,
        );

        test_scenario::return_shared(
            registry,
        );

        test_scenario::return_shared(
            store,
        );
    };

    scenario.end();
}
