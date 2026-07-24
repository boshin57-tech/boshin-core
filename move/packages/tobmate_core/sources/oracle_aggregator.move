module tobmate_core::oracle_aggregator;

use sui::event;
use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

/* ============================================================
   Error codes
   ============================================================ */

const E_PROTOCOL_PAUSED: u64 = 1;
const E_INVALID_MIN_OBSERVATIONS: u64 = 2;
const E_INVALID_MAX_DEVIATION: u64 = 3;
const E_OBSERVATION_LENGTH_MISMATCH: u64 = 4;
const E_INSUFFICIENT_OBSERVATIONS: u64 = 5;
const E_ZERO_PRICE: u64 = 6;
const E_ZERO_WEIGHT: u64 = 7;
const E_ZERO_TOTAL_WEIGHT: u64 = 8;
const E_EXCESSIVE_DEVIATION: u64 = 9;
const E_DUPLICATE_PAUSE_STATE: u64 = 10;
const E_INVALID_VERSION: u64 = 11;

/* ============================================================
   Constants
   ============================================================ */

const BASIS_POINT_DENOMINATOR: u64 = 10_000;
const MAX_ALLOWED_DEVIATION_BPS: u64 = 10_000;

/* ============================================================
   Objects
   ============================================================ */

public struct OracleAggregatorAdminCap has key, store {
    id: UID,
}

public struct OracleAggregator has key {
    id: UID,

    version: u64,
    paused: bool,

    min_observations: u64,
    max_deviation_bps: u64,

    next_round_id: u64,

    latest_round_id: u64,
    latest_median_price: u64,
    latest_weighted_median_price: u64,
    latest_observation_count: u64,
    latest_timestamp_ms: u64,
}

/* ============================================================
   Events
   ============================================================ */

public struct OracleAggregatorCreated has copy, drop {
    aggregator_id: address,
    administrator: address,
    min_observations: u64,
    max_deviation_bps: u64,
}

public struct AggregationPolicyUpdated has copy, drop {
    aggregator_id: address,
    min_observations: u64,
    max_deviation_bps: u64,
}

public struct AggregationRoundCompleted has copy, drop {
    aggregator_id: address,
    round_id: u64,
    observation_count: u64,
    median_price: u64,
    weighted_median_price: u64,
    deviation_bps: u64,
    timestamp_ms: u64,
}

public struct OracleAggregatorPauseUpdated has copy, drop {
    aggregator_id: address,
    paused: bool,
}

public struct OracleAggregatorVersionUpdated has copy, drop {
    aggregator_id: address,
    previous_version: u64,
    new_version: u64,
}

/* ============================================================
   Initialization
   ============================================================ */

public fun create_aggregator(
    min_observations: u64,
    max_deviation_bps: u64,
    ctx: &mut TxContext,
): OracleAggregatorAdminCap {
    assert!(
        min_observations > 0,
        E_INVALID_MIN_OBSERVATIONS,
    );

    assert!(
        max_deviation_bps <= MAX_ALLOWED_DEVIATION_BPS,
        E_INVALID_MAX_DEVIATION,
    );

    let administrator = tx_context::sender(ctx);

    let aggregator = OracleAggregator {
        id: object::new(ctx),

        version: 1,
        paused: false,

        min_observations,
        max_deviation_bps,

        next_round_id: 1,

        latest_round_id: 0,
        latest_median_price: 0,
        latest_weighted_median_price: 0,
        latest_observation_count: 0,
        latest_timestamp_ms: 0,
    };

    let aggregator_id = object::uid_to_address(&aggregator.id);

    transfer::share_object(aggregator);

    event::emit(OracleAggregatorCreated {
        aggregator_id,
        administrator,
        min_observations,
        max_deviation_bps,
    });

    OracleAggregatorAdminCap {
        id: object::new(ctx),
    }
}

/* ============================================================
   Administration
   ============================================================ */

public fun update_policy(
    _: &OracleAggregatorAdminCap,
    aggregator: &mut OracleAggregator,
    min_observations: u64,
    max_deviation_bps: u64,
) {
    assert!(
        min_observations > 0,
        E_INVALID_MIN_OBSERVATIONS,
    );

    assert!(
        max_deviation_bps <= MAX_ALLOWED_DEVIATION_BPS,
        E_INVALID_MAX_DEVIATION,
    );

    aggregator.min_observations = min_observations;
    aggregator.max_deviation_bps = max_deviation_bps;

    event::emit(AggregationPolicyUpdated {
        aggregator_id: object::uid_to_address(&aggregator.id),
        min_observations,
        max_deviation_bps,
    });
}

public fun set_paused(
    _: &OracleAggregatorAdminCap,
    aggregator: &mut OracleAggregator,
    paused: bool,
) {
    assert!(
        aggregator.paused != paused,
        E_DUPLICATE_PAUSE_STATE,
    );

    aggregator.paused = paused;

    event::emit(OracleAggregatorPauseUpdated {
        aggregator_id: object::uid_to_address(&aggregator.id),
        paused,
    });
}

public fun update_version(
    _: &OracleAggregatorAdminCap,
    aggregator: &mut OracleAggregator,
    new_version: u64,
) {
    assert!(
        new_version > aggregator.version,
        E_INVALID_VERSION,
    );

    let previous_version = aggregator.version;
    aggregator.version = new_version;

    event::emit(OracleAggregatorVersionUpdated {
        aggregator_id: object::uid_to_address(&aggregator.id),
        previous_version,
        new_version,
    });
}

/* ============================================================
   Aggregation
   ============================================================ */

public fun aggregate_round(
    aggregator: &mut OracleAggregator,
    prices: vector<u64>,
    weights: vector<u64>,
    timestamp_ms: u64,
) {
    assert!(
        !aggregator.paused,
        E_PROTOCOL_PAUSED,
    );

    let observation_count = vector::length(&prices);

    assert!(
        observation_count == vector::length(&weights),
        E_OBSERVATION_LENGTH_MISMATCH,
    );

    assert!(
        observation_count >= aggregator.min_observations,
        E_INSUFFICIENT_OBSERVATIONS,
    );

    validate_prices_and_weights(
        &prices,
        &weights,
    );

    let median_prices =
        copy_u64_vector(&prices);

    let median_price =
        calculate_median(median_prices);

    let weighted_median_price =
        calculate_weighted_median(
            prices,
            weights,
        );

    let deviation_bps =
        calculate_deviation_bps(
            median_price,
            weighted_median_price,
        );

    assert!(
        deviation_bps <= aggregator.max_deviation_bps,
        E_EXCESSIVE_DEVIATION,
    );

    let round_id = aggregator.next_round_id;

    aggregator.next_round_id =
        round_id + 1;

    aggregator.latest_round_id =
        round_id;

    aggregator.latest_median_price =
        median_price;

    aggregator.latest_weighted_median_price =
        weighted_median_price;

    aggregator.latest_observation_count =
        observation_count;

    aggregator.latest_timestamp_ms =
        timestamp_ms;

    event::emit(AggregationRoundCompleted {
        aggregator_id:
            object::uid_to_address(&aggregator.id),

        round_id,
        observation_count,
        median_price,
        weighted_median_price,
        deviation_bps,
        timestamp_ms,
    });
}

fun copy_u64_vector(
    source: &vector<u64>,
): vector<u64> {
    let mut result = vector[];
    let mut index = 0;
    let count = vector::length(source);

    while (index < count) {
        vector::push_back(
            &mut result,
            *vector::borrow(source, index),
        );

        index = index + 1;
    };

    result
}

/* ============================================================
   Pure calculation functions
   ============================================================ */

public fun calculate_median(
    mut prices: vector<u64>,
): u64 {
    let count = vector::length(&prices);

    assert!(
        count > 0,
        E_INSUFFICIENT_OBSERVATIONS,
    );

    validate_prices(&prices);

    sort_prices(&mut prices);

    if (count % 2 == 1) {
        *vector::borrow(
            &prices,
            count / 2,
        )
    } else {
        let left =
            *vector::borrow(
                &prices,
                (count / 2) - 1,
            );

        let right =
            *vector::borrow(
                &prices,
                count / 2,
            );

        (((left as u128) + (right as u128)) / 2) as u64
    }
}

public fun calculate_weighted_median(
    mut prices: vector<u64>,
    mut weights: vector<u64>,
): u64 {
    let count = vector::length(&prices);

    assert!(
        count > 0,
        E_INSUFFICIENT_OBSERVATIONS,
    );

    assert!(
        count == vector::length(&weights),
        E_OBSERVATION_LENGTH_MISMATCH,
    );

    validate_prices_and_weights(
        &prices,
        &weights,
    );

    sort_price_weight_pairs(
        &mut prices,
        &mut weights,
    );

    let mut total_weight: u128 = 0;
    let mut index = 0;

    while (index < count) {
        total_weight =
            total_weight +
            (*vector::borrow(&weights, index) as u128);

        index = index + 1;
    };

    assert!(
        total_weight > 0,
        E_ZERO_TOTAL_WEIGHT,
    );

    let mut cumulative_weight: u128 = 0;
    let mut weighted_index = 0;

    while (weighted_index < count) {
        cumulative_weight =
            cumulative_weight +
            (*vector::borrow(
                &weights,
                weighted_index,
            ) as u128);

        if (
            cumulative_weight * 2
                >= total_weight
        ) {
            return *vector::borrow(
                &prices,
                weighted_index,
            )
        };

        weighted_index =
            weighted_index + 1;
    };

    *vector::borrow(
        &prices,
        count - 1,
    )
}

public fun calculate_deviation_bps(
    first_price: u64,
    second_price: u64,
): u64 {
    assert!(
        first_price > 0,
        E_ZERO_PRICE,
    );

    assert!(
        second_price > 0,
        E_ZERO_PRICE,
    );

    let difference =
        if (first_price >= second_price) {
            first_price - second_price
        } else {
            second_price - first_price
        };

    (
        (
            (difference as u128)
                * (BASIS_POINT_DENOMINATOR as u128)
        ) / (first_price as u128)
    ) as u64
}

/* ============================================================
   Internal validation
   ============================================================ */

fun validate_prices(
    prices: &vector<u64>,
) {
    let mut index = 0;
    let count = vector::length(prices);

    while (index < count) {
        assert!(
            *vector::borrow(prices, index) > 0,
            E_ZERO_PRICE,
        );

        index = index + 1;
    };
}

fun validate_prices_and_weights(
    prices: &vector<u64>,
    weights: &vector<u64>,
) {
    assert!(
        vector::length(prices)
            == vector::length(weights),
        E_OBSERVATION_LENGTH_MISMATCH,
    );

    let mut index = 0;
    let count = vector::length(prices);

    while (index < count) {
        assert!(
            *vector::borrow(prices, index) > 0,
            E_ZERO_PRICE,
        );

        assert!(
            *vector::borrow(weights, index) > 0,
            E_ZERO_WEIGHT,
        );

        index = index + 1;
    };
}

/* ============================================================
   Sorting
   ============================================================ */

fun sort_prices(
    prices: &mut vector<u64>,
) {
    let count = vector::length(prices);
    let mut index = 1;

    while (index < count) {
        let mut cursor = index;

        while (
            cursor > 0
                && *vector::borrow(
                    prices,
                    cursor - 1,
                )
                > *vector::borrow(
                    prices,
                    cursor,
                )
        ) {
            vector::swap(
                prices,
                cursor - 1,
                cursor,
            );

            cursor = cursor - 1;
        };

        index = index + 1;
    };
}

fun sort_price_weight_pairs(
    prices: &mut vector<u64>,
    weights: &mut vector<u64>,
) {
    let count = vector::length(prices);
    let mut index = 1;

    while (index < count) {
        let mut cursor = index;

        while (
            cursor > 0
                && *vector::borrow(
                    prices,
                    cursor - 1,
                )
                > *vector::borrow(
                    prices,
                    cursor,
                )
        ) {
            vector::swap(
                prices,
                cursor - 1,
                cursor,
            );

            vector::swap(
                weights,
                cursor - 1,
                cursor,
            );

            cursor = cursor - 1;
        };

        index = index + 1;
    };
}

/* ============================================================
   Read-only accessors
   ============================================================ */

public fun version(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.version
}

public fun paused(
    aggregator: &OracleAggregator,
): bool {
    aggregator.paused
}

public fun min_observations(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.min_observations
}

public fun max_deviation_bps(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.max_deviation_bps
}

public fun latest_round_id(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.latest_round_id
}

public fun latest_median_price(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.latest_median_price
}

public fun latest_weighted_median_price(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.latest_weighted_median_price
}

public fun latest_observation_count(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.latest_observation_count
}

public fun latest_timestamp_ms(
    aggregator: &OracleAggregator,
): u64 {
    aggregator.latest_timestamp_ms
}

public fun basis_point_denominator(): u64 {
    BASIS_POINT_DENOMINATOR
}
