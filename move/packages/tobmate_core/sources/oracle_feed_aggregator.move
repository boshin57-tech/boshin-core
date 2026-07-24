module tobmate_core::oracle_feed_aggregator;

use tobmate_core::oracle::{
    OracleRegistry,
};
use tobmate_core::oracle_feed::{
    OracleFeedStore,
};
use tobmate_core::oracle_aggregator::{
    OracleAggregator,
};

/* ============================================================
   Abort codes
   ============================================================ */

const E_PROTOCOL_PAUSED: u64 = 201;
const E_INVALID_FEED_STORE: u64 = 202;
const E_FEED_NOT_FOUND: u64 = 203;
const E_FEED_PAUSED: u64 = 204;
const E_INVALID_ROUND: u64 = 205;
const E_INSUFFICIENT_RAW_OBSERVATIONS: u64 = 206;
const E_INSUFFICIENT_VALID_OBSERVATIONS: u64 = 207;
const E_VECTOR_LENGTH_MISMATCH: u64 = 208;
const E_ZERO_MEDIAN: u64 = 209;
const E_INVALID_TIMESTAMP: u64 = 210;

/* ============================================================
   Result model
   ============================================================ */

/// Result returned after one feed aggregation round.
///
/// This is a transient value. Canonical state is persisted in:
/// - OracleAggregator
/// - OracleFeedStore
public struct FeedAggregationResult has copy, drop, store {
    feed_id: u64,
    round: u64,

    raw_observation_count: u64,
    active_observation_count: u64,
    accepted_observation_count: u64,
    rejected_observation_count: u64,

    raw_median_price: u64,
    median_price: u64,
    weighted_median_price: u64,

    confidence_bps: u64,
    timestamp_ms: u64,
}

/* ============================================================
   Feed integration
   ============================================================ */

/// Collects observations for one feed round, resolves publisher
/// weights from OracleRegistry, removes invalid/stale/outlier values,
/// executes the OracleAggregator, and publishes the resulting
/// weighted median as the feed's canonical price.
public fun aggregate_feed_round(
    registry: &OracleRegistry,
    store: &mut OracleFeedStore,
    aggregator: &mut OracleAggregator,
    feed_id: u64,
    round: u64,
    timestamp_ms: u64,
): FeedAggregationResult {
    assert!(
        !tobmate_core::oracle::is_paused(registry),
        E_PROTOCOL_PAUSED,
    );

    assert!(
        tobmate_core::oracle_feed::store_registry_id(store)
            == tobmate_core::oracle::registry_id(registry),
        E_INVALID_FEED_STORE,
    );

    assert!(
        tobmate_core::oracle_feed::feed_exists(store, feed_id),
        E_FEED_NOT_FOUND,
    );

    assert!(
        !tobmate_core::oracle_feed::feed_is_paused(
            store,
            feed_id,
        ),
        E_FEED_PAUSED,
    );

    assert!(round > 0, E_INVALID_ROUND);
    assert!(timestamp_ms > 0, E_INVALID_TIMESTAMP);

    let (
        publisher_ids,
        raw_prices,
        confidence_values,
        observation_timestamps,
    ) = tobmate_core::oracle_feed::round_observation_snapshot(
        store,
        feed_id,
        round,
    );

    let raw_observation_count =
        vector::length(&raw_prices);

    assert!(
        raw_observation_count
            == vector::length(&publisher_ids)
            && raw_observation_count
                == vector::length(&confidence_values)
            && raw_observation_count
                == vector::length(&observation_timestamps),
        E_VECTOR_LENGTH_MISMATCH,
    );

    assert!(
        raw_observation_count
            >= tobmate_core::oracle_aggregator::min_observations(
                aggregator,
            ),
        E_INSUFFICIENT_RAW_OBSERVATIONS,
    );

    let heartbeat_ms =
        tobmate_core::oracle_feed::feed_heartbeat_ms(
            store,
            feed_id,
        );

    let (
        active_prices,
        active_weights,
        active_confidences,
    ) = collect_active_observations(
        registry,
        publisher_ids,
        raw_prices,
        confidence_values,
        observation_timestamps,
        timestamp_ms,
        heartbeat_ms,
    );

    let active_observation_count =
        vector::length(&active_prices);

    assert!(
        active_observation_count
            >= tobmate_core::oracle_aggregator::min_observations(
                aggregator,
            ),
        E_INSUFFICIENT_VALID_OBSERVATIONS,
    );

    let raw_median_price =
        tobmate_core::oracle_aggregator::calculate_median(
            copy active_prices,
        );

    assert!(raw_median_price > 0, E_ZERO_MEDIAN);

    let (
        accepted_prices,
        accepted_weights,
        accepted_confidences,
    ) = filter_outliers(
        active_prices,
        active_weights,
        active_confidences,
        raw_median_price,
        tobmate_core::oracle_aggregator::max_deviation_bps(
            aggregator,
        ),
    );

    let accepted_observation_count =
        vector::length(&accepted_prices);

    assert!(
        accepted_observation_count
            >= tobmate_core::oracle_aggregator::min_observations(
                aggregator,
            ),
        E_INSUFFICIENT_VALID_OBSERVATIONS,
    );

    let median_price =
        tobmate_core::oracle_aggregator::calculate_median(
            copy accepted_prices,
        );

    let weighted_median_price =
        tobmate_core::oracle_aggregator::calculate_weighted_median(
            copy accepted_prices,
            copy accepted_weights,
        );

    let canonical_confidence_bps =
        calculate_weighted_confidence(
            &accepted_confidences,
            &accepted_weights,
        );

    // Persist the aggregation round in the aggregator.
    tobmate_core::oracle_aggregator::aggregate_round(
        aggregator,
        accepted_prices,
        accepted_weights,
        timestamp_ms,
    );

    // Weighted median is the canonical feed price because publisher
    // weights originate from the governed OracleRegistry.
    tobmate_core::oracle_feed::update_canonical_price(
        store,
        feed_id,
        round,
        weighted_median_price,
        canonical_confidence_bps,
        timestamp_ms,
    );

    FeedAggregationResult {
        feed_id,
        round,

        raw_observation_count,
        active_observation_count,
        accepted_observation_count,
        rejected_observation_count:
            raw_observation_count - accepted_observation_count,

        raw_median_price,
        median_price,
        weighted_median_price,

        confidence_bps: canonical_confidence_bps,
        timestamp_ms,
    }
}

/* ============================================================
   Observation Collector and Weight Resolver
   ============================================================ */

fun collect_active_observations(
    registry: &OracleRegistry,
    publisher_ids: vector<u64>,
    prices: vector<u64>,
    confidence_values: vector<u64>,
    observation_timestamps: vector<u64>,
    aggregation_timestamp_ms: u64,
    heartbeat_ms: u64,
): (
    vector<u64>,
    vector<u64>,
    vector<u64>,
) {
    let length = vector::length(&prices);

    assert!(
        length == vector::length(&publisher_ids)
            && length == vector::length(&confidence_values)
            && length == vector::length(&observation_timestamps),
        E_VECTOR_LENGTH_MISMATCH,
    );

    let mut accepted_prices = vector[];
    let mut accepted_weights = vector[];
    let mut accepted_confidences = vector[];

    let mut index = 0;

    while (index < length) {
        let publisher_id =
            *vector::borrow(&publisher_ids, index);

        let price =
            *vector::borrow(&prices, index);

        let confidence_bps =
            *vector::borrow(&confidence_values, index);

        let observed_at_ms =
            *vector::borrow(&observation_timestamps, index);

        let publisher_exists =
            tobmate_core::oracle::publisher_exists(
                registry,
                publisher_id,
            );

        let publisher_active =
            publisher_exists
                && tobmate_core::oracle::publisher_is_active(
                    registry,
                    publisher_id,
                );

        let timestamp_valid =
            observed_at_ms <= aggregation_timestamp_ms;

        let fresh =
            timestamp_valid
                && aggregation_timestamp_ms - observed_at_ms
                    <= heartbeat_ms;

        if (publisher_active && fresh) {
            let weight =
                tobmate_core::oracle::publisher_weight(
                    registry,
                    publisher_id,
                );

            vector::push_back(
                &mut accepted_prices,
                price,
            );

            vector::push_back(
                &mut accepted_weights,
                weight,
            );

            vector::push_back(
                &mut accepted_confidences,
                confidence_bps,
            );
        };

        index = index + 1;
    };

    (
        accepted_prices,
        accepted_weights,
        accepted_confidences,
    )
}

/* ============================================================
   Outlier filtering
   ============================================================ */

fun filter_outliers(
    prices: vector<u64>,
    weights: vector<u64>,
    confidence_values: vector<u64>,
    reference_median: u64,
    max_deviation_bps: u64,
): (
    vector<u64>,
    vector<u64>,
    vector<u64>,
) {
    let length = vector::length(&prices);

    assert!(
        length == vector::length(&weights)
            && length == vector::length(&confidence_values),
        E_VECTOR_LENGTH_MISMATCH,
    );

    let mut accepted_prices = vector[];
    let mut accepted_weights = vector[];
    let mut accepted_confidences = vector[];

    let mut index = 0;

    while (index < length) {
        let price = *vector::borrow(&prices, index);

        let deviation_bps =
            tobmate_core::oracle_aggregator::calculate_deviation_bps(
                price,
                reference_median,
            );

        if (deviation_bps <= max_deviation_bps) {
            vector::push_back(
                &mut accepted_prices,
                price,
            );

            vector::push_back(
                &mut accepted_weights,
                *vector::borrow(&weights, index),
            );

            vector::push_back(
                &mut accepted_confidences,
                *vector::borrow(&confidence_values, index),
            );
        };

        index = index + 1;
    };

    (
        accepted_prices,
        accepted_weights,
        accepted_confidences,
    )
}

/* ============================================================
   Confidence aggregation
   ============================================================ */

fun calculate_weighted_confidence(
    confidence_values: &vector<u64>,
    weights: &vector<u64>,
): u64 {
    let length = vector::length(confidence_values);

    assert!(
        length == vector::length(weights),
        E_VECTOR_LENGTH_MISMATCH,
    );

    let mut weighted_total: u128 = 0;
    let mut total_weight: u128 = 0;
    let mut index = 0;

    while (index < length) {
        let confidence =
            *vector::borrow(confidence_values, index);

        let weight =
            *vector::borrow(weights, index);

        weighted_total =
            weighted_total
                + (confidence as u128) * (weight as u128);

        total_weight =
            total_weight + (weight as u128);

        index = index + 1;
    };

    if (total_weight == 0) {
        0
    } else {
        (weighted_total / total_weight) as u64
    }
}

/* ============================================================
   Result getters
   ============================================================ */

public fun result_feed_id(
    result: &FeedAggregationResult,
): u64 {
    result.feed_id
}

public fun result_round(
    result: &FeedAggregationResult,
): u64 {
    result.round
}

public fun result_raw_observation_count(
    result: &FeedAggregationResult,
): u64 {
    result.raw_observation_count
}

public fun result_active_observation_count(
    result: &FeedAggregationResult,
): u64 {
    result.active_observation_count
}

public fun result_accepted_observation_count(
    result: &FeedAggregationResult,
): u64 {
    result.accepted_observation_count
}

public fun result_rejected_observation_count(
    result: &FeedAggregationResult,
): u64 {
    result.rejected_observation_count
}

public fun result_raw_median_price(
    result: &FeedAggregationResult,
): u64 {
    result.raw_median_price
}

public fun result_median_price(
    result: &FeedAggregationResult,
): u64 {
    result.median_price
}

public fun result_weighted_median_price(
    result: &FeedAggregationResult,
): u64 {
    result.weighted_median_price
}

public fun result_confidence_bps(
    result: &FeedAggregationResult,
): u64 {
    result.confidence_bps
}

public fun result_timestamp_ms(
    result: &FeedAggregationResult,
): u64 {
    result.timestamp_ms
}
