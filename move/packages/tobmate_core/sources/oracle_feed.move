module tobmate_core::oracle_feed;

use std::string::{Self, String};
use std::vector;
use sui::clock::{Self, Clock};
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::oracle::{
    OracleAdminCap,
    OraclePublisherCap,
    OracleRegistry,
};

/* ============================================================
   Error codes
   ============================================================ */

const E_NOT_ADMIN: u64 = 101;
const E_PROTOCOL_PAUSED: u64 = 102;
const E_FEED_ALREADY_EXISTS: u64 = 103;
const E_FEED_NOT_FOUND: u64 = 104;
const E_FEED_PAUSED: u64 = 105;
const E_INVALID_DECIMALS: u64 = 106;
const E_INVALID_HEARTBEAT: u64 = 107;
const E_INVALID_PRICE_RANGE: u64 = 108;
const E_ZERO_PRICE: u64 = 109;
const E_PRICE_OUT_OF_RANGE: u64 = 110;
const E_INVALID_CONFIDENCE: u64 = 111;
const E_FUTURE_TIMESTAMP: u64 = 112;
const E_STALE_OBSERVATION: u64 = 113;
const E_DUPLICATE_ROUND: u64 = 114;
const E_INVALID_ROUND: u64 = 115;
const E_INVALID_FEED_STORE: u64 = 116;

/* ============================================================
   Constants
   ============================================================ */

const MAX_DECIMALS: u8 = 18;
const MAX_CONFIDENCE_BPS: u64 = 10_000;

/* ============================================================
   Core objects
   ============================================================ */

/// Shared storage for oracle feed definitions and observations.
public struct OracleFeedStore has key {
    id: UID,
    registry_id: ID,
    next_feed_id: u64,
    feed_count: u64,
    observation_count: u64,
    feeds: vector<FeedPolicy>,
    observations: vector<Observation>,
}

/// Feed configuration.
///
/// Symbol examples:
/// - XAU_USD
/// - GOLDPEG_USD
/// - SUI_USD
public struct FeedPolicy has copy, drop, store {
    feed_id: u64,
    symbol: String,
    decimals: u8,
    heartbeat_ms: u64,
    min_price: u64,
    max_price: u64,
    paused: bool,
    latest_round: u64,
    latest_price: u64,
    latest_confidence_bps: u64,
    latest_timestamp_ms: u64,
    observation_count: u64,
}

/// One publisher observation for one feed and one round.
public struct Observation has copy, drop, store {
    feed_id: u64,
    publisher_id: u64,
    round: u64,
    price: u64,
    confidence_bps: u64,
    timestamp_ms: u64,
}

/* ============================================================
   Creation
   ============================================================ */

/// Creates a shared feed store associated with one OracleRegistry.
public fun create_feed_store(
    registry: &OracleRegistry,
    admin_cap: &OracleAdminCap,
    ctx: &mut TxContext,
) {
    assert!(
        oracle_admin_registry_id(admin_cap)
            == tobmate_core::oracle::registry_id(registry),
        E_NOT_ADMIN,
    );

    let store = OracleFeedStore {
        id: object::new(ctx),
        registry_id: tobmate_core::oracle::registry_id(registry),
        next_feed_id: 1,
        feed_count: 0,
        observation_count: 0,
        feeds: vector[],
        observations: vector[],
    };

    transfer::share_object(store);
}

/* ============================================================
   Feed administration
   ============================================================ */

/// Registers a new oracle feed.
public fun register_feed(
    registry: &OracleRegistry,
    store: &mut OracleFeedStore,
    admin_cap: &OracleAdminCap,
    symbol: vector<u8>,
    decimals: u8,
    heartbeat_ms: u64,
    min_price: u64,
    max_price: u64,
): u64 {
    assert_store_matches_registry(registry, store);
    assert_admin(registry, admin_cap);
    assert!(!tobmate_core::oracle::is_paused(registry), E_PROTOCOL_PAUSED);

    assert!(decimals <= MAX_DECIMALS, E_INVALID_DECIMALS);
    assert!(heartbeat_ms > 0, E_INVALID_HEARTBEAT);
    assert!(
        min_price > 0 && max_price >= min_price,
        E_INVALID_PRICE_RANGE,
    );

    let symbol_string = string::utf8(symbol);

    assert!(
        !feed_symbol_exists(store, &symbol_string),
        E_FEED_ALREADY_EXISTS,
    );

    let feed_id = store.next_feed_id;

    vector::push_back(
        &mut store.feeds,
        FeedPolicy {
            feed_id,
            symbol: symbol_string,
            decimals,
            heartbeat_ms,
            min_price,
            max_price,
            paused: false,
            latest_round: 0,
            latest_price: 0,
            latest_confidence_bps: 0,
            latest_timestamp_ms: 0,
            observation_count: 0,
        },
    );

    store.next_feed_id = feed_id + 1;
    store.feed_count = store.feed_count + 1;

    feed_id
}

/// Pauses or resumes one feed.
public fun set_feed_paused(
    registry: &OracleRegistry,
    store: &mut OracleFeedStore,
    admin_cap: &OracleAdminCap,
    feed_id: u64,
    paused: bool,
) {
    assert_store_matches_registry(registry, store);
    assert_admin(registry, admin_cap);

    let index = find_feed_index(store, feed_id);
    let feed = vector::borrow_mut(&mut store.feeds, index);

    feed.paused = paused;
}

/// Updates heartbeat and price bounds.
public fun update_feed_policy(
    registry: &OracleRegistry,
    store: &mut OracleFeedStore,
    admin_cap: &OracleAdminCap,
    feed_id: u64,
    heartbeat_ms: u64,
    min_price: u64,
    max_price: u64,
) {
    assert_store_matches_registry(registry, store);
    assert_admin(registry, admin_cap);

    assert!(heartbeat_ms > 0, E_INVALID_HEARTBEAT);
    assert!(
        min_price > 0 && max_price >= min_price,
        E_INVALID_PRICE_RANGE,
    );

    let index = find_feed_index(store, feed_id);
    let feed = vector::borrow_mut(&mut store.feeds, index);

    feed.heartbeat_ms = heartbeat_ms;
    feed.min_price = min_price;
    feed.max_price = max_price;
}

/* ============================================================
   Observation submission
   ============================================================ */

/// Submits one publisher observation.
///
/// Stage 2 stores the latest accepted value directly.
/// Stage 3 will aggregate multiple publisher observations before
/// publishing the canonical median price.
public fun submit_observation(
    registry: &OracleRegistry,
    store: &mut OracleFeedStore,
    publisher_cap: &OraclePublisherCap,
    feed_id: u64,
    round: u64,
    price: u64,
    confidence_bps: u64,
    observed_at_ms: u64,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert_store_matches_registry(registry, store);

    let sender = tx_context::sender(ctx);

    tobmate_core::oracle::assert_valid_publisher(
        registry,
        publisher_cap,
        sender,
    );

    assert!(round > 0, E_INVALID_ROUND);
    assert!(price > 0, E_ZERO_PRICE);
    assert!(
        confidence_bps <= MAX_CONFIDENCE_BPS,
        E_INVALID_CONFIDENCE,
    );

    let publisher_id = publisher_cap_id(publisher_cap);
    let current_time_ms = clock::timestamp_ms(clock);

    assert!(
        observed_at_ms <= current_time_ms,
        E_FUTURE_TIMESTAMP,
    );

    /*
       Read-only validation scope.

       The immutable FeedPolicy borrow ends before the Store is
       mutated or passed to observation_exists.
    */
    {
        let feed_index = find_feed_index(store, feed_id);
        let feed = vector::borrow(&store.feeds, feed_index);

        assert!(!feed.paused, E_FEED_PAUSED);

        assert!(
            price >= feed.min_price
                && price <= feed.max_price,
            E_PRICE_OUT_OF_RANGE,
        );

        assert!(
            current_time_ms - observed_at_ms
                <= feed.heartbeat_ms,
            E_STALE_OBSERVATION,
        );
    };

    /*
       Duplicate validation occurs with no outstanding mutable
       or immutable borrow of store.feeds.
    */
    assert!(
        !observation_exists(
            store,
            feed_id,
            publisher_id,
            round,
        ),
        E_DUPLICATE_ROUND,
    );

    vector::push_back(
        &mut store.observations,
        Observation {
            feed_id,
            publisher_id,
            round,
            price,
            confidence_bps,
            timestamp_ms: observed_at_ms,
        },
    );

    /*
       State update begins only after all Store-wide validation
       has completed.
    */
    {
        let feed_index = find_feed_index(store, feed_id);
        let feed =
            vector::borrow_mut(&mut store.feeds, feed_index);

        if (round >= feed.latest_round) {
            feed.latest_round = round;
            feed.latest_price = price;
            feed.latest_confidence_bps = confidence_bps;
            feed.latest_timestamp_ms = observed_at_ms;
        };

        feed.observation_count =
            feed.observation_count + 1;
    };

    store.observation_count =
        store.observation_count + 1;
}

/* ============================================================
   Internal validation
   ============================================================ */

fun assert_admin(
    registry: &OracleRegistry,
    admin_cap: &OracleAdminCap,
) {
    assert!(
        oracle_admin_registry_id(admin_cap)
            == tobmate_core::oracle::registry_id(registry),
        E_NOT_ADMIN,
    );
}

fun assert_store_matches_registry(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
) {
    assert!(
        store.registry_id
            == tobmate_core::oracle::registry_id(registry),
        E_INVALID_FEED_STORE,
    );
}

fun oracle_admin_registry_id(
    admin_cap: &OracleAdminCap,
): ID {
    tobmate_core::oracle::admin_registry_id(admin_cap)
}

fun publisher_cap_id(
    publisher_cap: &OraclePublisherCap,
): u64 {
    tobmate_core::oracle::publisher_cap_id(publisher_cap)
}

fun feed_symbol_exists(
    store: &OracleFeedStore,
    symbol: &String,
): bool {
    let length = vector::length(&store.feeds);
    let mut index = 0;

    while (index < length) {
        let feed = vector::borrow(&store.feeds, index);

        if (&feed.symbol == symbol) {
            return true
        };

        index = index + 1;
    };

    false
}

fun find_feed_index(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let length = vector::length(&store.feeds);
    let mut index = 0;

    while (index < length) {
        let feed = vector::borrow(&store.feeds, index);

        if (feed.feed_id == feed_id) {
            return index
        };

        index = index + 1;
    };

    abort E_FEED_NOT_FOUND
}

fun observation_exists(
    store: &OracleFeedStore,
    feed_id: u64,
    publisher_id: u64,
    round: u64,
): bool {
    let length = vector::length(&store.observations);
    let mut index = 0;

    while (index < length) {
        let observation =
            vector::borrow(&store.observations, index);

        if (
            observation.feed_id == feed_id
                && observation.publisher_id == publisher_id
                && observation.round == round
        ) {
            return true
        };

        index = index + 1;
    };

    false
}

/* ============================================================
   Read-only API
   ============================================================ */

public fun store_registry_id(
    store: &OracleFeedStore,
): ID {
    store.registry_id
}

public fun feed_count(
    store: &OracleFeedStore,
): u64 {
    store.feed_count
}

public fun observation_count(
    store: &OracleFeedStore,
): u64 {
    store.observation_count
}

public fun feed_exists(
    store: &OracleFeedStore,
    feed_id: u64,
): bool {
    let length = vector::length(&store.feeds);
    let mut index = 0;

    while (index < length) {
        let feed = vector::borrow(&store.feeds, index);

        if (feed.feed_id == feed_id) {
            return true
        };

        index = index + 1;
    };

    false
}

public fun feed_decimals(
    store: &OracleFeedStore,
    feed_id: u64,
): u8 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).decimals
}

public fun feed_heartbeat_ms(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).heartbeat_ms
}

public fun feed_min_price(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).min_price
}

public fun feed_max_price(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).max_price
}

public fun feed_is_paused(
    store: &OracleFeedStore,
    feed_id: u64,
): bool {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).paused
}

public fun latest_round(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).latest_round
}

public fun latest_price(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).latest_price
}

public fun latest_confidence_bps(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).latest_confidence_bps
}

public fun latest_timestamp_ms(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).latest_timestamp_ms
}

public fun feed_observation_count(
    store: &OracleFeedStore,
    feed_id: u64,
): u64 {
    let index = find_feed_index(store, feed_id);
    vector::borrow(&store.feeds, index).observation_count
}

/* TOBMATE_ORACLE_STAGE_2B2_FEED_INTEGRATION_API */

/* ============================================================
   Stage 2B-2 package integration API
   ============================================================ */

/// Returns all observations belonging to one feed and one round.
///
/// The vectors use the same positional index:
/// - publisher_ids[i]
/// - prices[i]
/// - confidence_bps_values[i]
/// - timestamps_ms[i]
///
/// This API is package-scoped because raw observations must only be
/// consumed by trusted Oracle protocol modules.
public(package) fun round_observation_snapshot(
    store: &OracleFeedStore,
    feed_id: u64,
    round: u64,
): (
    vector<u64>,
    vector<u64>,
    vector<u64>,
    vector<u64>,
) {
    assert!(round > 0, E_INVALID_ROUND);

    // Also validates that the feed exists.
    let _feed_index = find_feed_index(store, feed_id);

    let mut publisher_ids = vector[];
    let mut prices = vector[];
    let mut confidence_bps_values = vector[];
    let mut timestamps_ms = vector[];

    let length = vector::length(&store.observations);
    let mut index = 0;

    while (index < length) {
        let observation =
            vector::borrow(&store.observations, index);

        if (
            observation.feed_id == feed_id
                && observation.round == round
        ) {
            vector::push_back(
                &mut publisher_ids,
                observation.publisher_id,
            );

            vector::push_back(
                &mut prices,
                observation.price,
            );

            vector::push_back(
                &mut confidence_bps_values,
                observation.confidence_bps,
            );

            vector::push_back(
                &mut timestamps_ms,
                observation.timestamp_ms,
            );
        };

        index = index + 1;
    };

    (
        publisher_ids,
        prices,
        confidence_bps_values,
        timestamps_ms,
    )
}

/// Publishes the final canonical result produced by the trusted
/// Oracle aggregation integration module.
///
/// Raw publisher submission updates remain stored for auditability,
/// while this function replaces the feed's latest public value with
/// the final aggregated price.
public(package) fun update_canonical_price(
    store: &mut OracleFeedStore,
    feed_id: u64,
    round: u64,
    canonical_price: u64,
    confidence_bps: u64,
    timestamp_ms: u64,
) {
    assert!(round > 0, E_INVALID_ROUND);
    assert!(canonical_price > 0, E_ZERO_PRICE);

    assert!(
        confidence_bps <= MAX_CONFIDENCE_BPS,
        E_INVALID_CONFIDENCE,
    );

    let feed_index = find_feed_index(store, feed_id);
    let feed = vector::borrow_mut(
        &mut store.feeds,
        feed_index,
    );

    assert!(!feed.paused, E_FEED_PAUSED);

    assert!(
        canonical_price >= feed.min_price
            && canonical_price <= feed.max_price,
        E_PRICE_OUT_OF_RANGE,
    );

    assert!(
        round >= feed.latest_round,
        E_INVALID_ROUND,
    );

    assert!(
        timestamp_ms >= feed.latest_timestamp_ms,
        E_INVALID_ROUND,
    );

    feed.latest_round = round;
    feed.latest_price = canonical_price;
    feed.latest_confidence_bps = confidence_bps;
    feed.latest_timestamp_ms = timestamp_ms;
}

}
