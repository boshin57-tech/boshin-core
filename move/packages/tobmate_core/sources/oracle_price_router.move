module tobmate_core::oracle_price_router;

use std::string;
use sui::object::ID;

use tobmate_core::oracle::{
    Self,
    OracleRegistry,
};

use tobmate_core::oracle_feed::{
    Self,
    OracleFeedStore,
};

/* ============================================================
   Error codes
   ============================================================ */

const E_PROTOCOL_PAUSED: u64 = 301;
const E_INVALID_FEED_STORE: u64 = 302;
const E_FEED_NOT_FOUND: u64 = 303;
const E_FEED_PAUSED: u64 = 304;
const E_CANONICAL_PRICE_NOT_READY: u64 = 305;
const E_PRICE_NOT_AVAILABLE: u64 = 306;
const E_PRICE_STALE: u64 = 307;
const E_INVALID_TIMESTAMP: u64 = 308;
const E_SYMBOL_NOT_FOUND: u64 = 309;
const E_ZERO_MAX_AGE: u64 = 310;

/* ============================================================
   Price quote
   ============================================================ */

/// Validated canonical price returned to consuming protocols.
///
/// This value is safe for DEX, Lending, Treasury and other trusted
/// protocol modules only after all registry, feed and freshness
/// checks have completed.
public struct PriceQuote has copy, drop, store {
    registry_id: ID,
    feed_id: u64,
    round: u64,
    price: u64,
    confidence_bps: u64,
    observed_at_ms: u64,
    queried_at_ms: u64,
    age_ms: u64,
    effective_max_age_ms: u64,
}

/* ============================================================
   Public routing API
   ============================================================ */

/// Returns a canonical price using the feed heartbeat as the
/// maximum permitted age.
public fun get_price(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
    feed_id: u64,
    queried_at_ms: u64,
): PriceQuote {
    assert_common_state(
        registry,
        store,
        feed_id,
    );

    let heartbeat_ms =
        oracle_feed::feed_heartbeat_ms(store, feed_id);

    build_validated_quote(
        registry,
        store,
        feed_id,
        queried_at_ms,
        heartbeat_ms,
    )
}

/// Returns a canonical price with a caller-defined freshness limit.
///
/// The effective permitted age is the smaller of:
/// - the registered feed heartbeat; and
/// - max_age_ms supplied by the consuming protocol.
public fun get_price_with_max_age(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
    feed_id: u64,
    queried_at_ms: u64,
    max_age_ms: u64,
): PriceQuote {
    assert!(max_age_ms > 0, E_ZERO_MAX_AGE);

    assert_common_state(
        registry,
        store,
        feed_id,
    );

    let heartbeat_ms =
        oracle_feed::feed_heartbeat_ms(store, feed_id);

    let effective_max_age_ms =
        if (max_age_ms < heartbeat_ms) {
            max_age_ms
        } else {
            heartbeat_ms
        };

    build_validated_quote(
        registry,
        store,
        feed_id,
        queried_at_ms,
        effective_max_age_ms,
    )
}

/// Resolves a UTF-8 feed symbol and returns its canonical price.
public fun get_price_by_symbol(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
    symbol: vector<u8>,
    queried_at_ms: u64,
): PriceQuote {
    let symbol_string = string::utf8(symbol);

    assert!(
        oracle_feed::feed_symbol_exists(
            store,
            &symbol_string,
        ),
        E_SYMBOL_NOT_FOUND,
    );

    let feed_id =
        oracle_feed::feed_id_by_symbol(
            store,
            &symbol_string,
        );

    get_price(
        registry,
        store,
        feed_id,
        queried_at_ms,
    )
}

/// Resolves a UTF-8 feed symbol and applies a consumer-specific
/// maximum permitted price age.
public fun get_price_by_symbol_with_max_age(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
    symbol: vector<u8>,
    queried_at_ms: u64,
    max_age_ms: u64,
): PriceQuote {
    assert!(max_age_ms > 0, E_ZERO_MAX_AGE);

    let symbol_string = string::utf8(symbol);

    assert!(
        oracle_feed::feed_symbol_exists(
            store,
            &symbol_string,
        ),
        E_SYMBOL_NOT_FOUND,
    );

    let feed_id =
        oracle_feed::feed_id_by_symbol(
            store,
            &symbol_string,
        );

    get_price_with_max_age(
        registry,
        store,
        feed_id,
        queried_at_ms,
        max_age_ms,
    )
}

/* ============================================================
   Internal validation
   ============================================================ */

fun assert_common_state(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
    feed_id: u64,
) {
    assert!(
        oracle_feed::store_registry_id(store)
            == oracle::registry_id(registry),
        E_INVALID_FEED_STORE,
    );

    assert!(
        !oracle::is_paused(registry),
        E_PROTOCOL_PAUSED,
    );

    assert!(
        oracle_feed::feed_exists(store, feed_id),
        E_FEED_NOT_FOUND,
    );

    assert!(
        !oracle_feed::feed_is_paused(store, feed_id),
        E_FEED_PAUSED,
    );

    assert!(
        oracle_feed::canonical_price_is_ready(
            store,
            feed_id,
        ),
        E_CANONICAL_PRICE_NOT_READY,
    );
}

fun build_validated_quote(
    registry: &OracleRegistry,
    store: &OracleFeedStore,
    feed_id: u64,
    queried_at_ms: u64,
    effective_max_age_ms: u64,
): PriceQuote {
    let round =
        oracle_feed::latest_round(store, feed_id);

    let price =
        oracle_feed::latest_price(store, feed_id);

    let confidence_bps =
        oracle_feed::latest_confidence_bps(
            store,
            feed_id,
        );

    let observed_at_ms =
        oracle_feed::latest_timestamp_ms(
            store,
            feed_id,
        );

    assert!(
        round > 0 && price > 0,
        E_PRICE_NOT_AVAILABLE,
    );

    assert!(
        queried_at_ms >= observed_at_ms,
        E_INVALID_TIMESTAMP,
    );

    let age_ms =
        queried_at_ms - observed_at_ms;

    assert!(
        age_ms <= effective_max_age_ms,
        E_PRICE_STALE,
    );

    PriceQuote {
        registry_id: oracle::registry_id(registry),
        feed_id,
        round,
        price,
        confidence_bps,
        observed_at_ms,
        queried_at_ms,
        age_ms,
        effective_max_age_ms,
    }
}

/* ============================================================
   Stage 5D — Test-only PriceQuote fixture
   ============================================================ */

/// Constructs a PriceQuote exclusively for Move unit tests.
///
/// Production callers must obtain quotes through get_price or
/// get_price_by_symbol. This helper cannot be published into the
/// production bytecode because it is marked test-only.
#[test_only]
public fun new_quote_for_testing(
    registry_id: ID,
    feed_id: u64,
    round: u64,
    price: u64,
    confidence_bps: u64,
    observed_at_ms: u64,
    queried_at_ms: u64,
    effective_max_age_ms: u64,
): PriceQuote {
    let age_ms =
        if (queried_at_ms >= observed_at_ms) {
            queried_at_ms - observed_at_ms
        } else {
            0
        };

    PriceQuote {
        registry_id,
        feed_id,
        round,
        price,
        confidence_bps,
        observed_at_ms,
        queried_at_ms,
        age_ms,
        effective_max_age_ms,
    }
}

/* ============================================================
   Quote getters
   ============================================================ */

public fun quote_registry_id(
    quote: &PriceQuote,
): ID {
    quote.registry_id
}

public fun quote_feed_id(
    quote: &PriceQuote,
): u64 {
    quote.feed_id
}

public fun quote_round(
    quote: &PriceQuote,
): u64 {
    quote.round
}

public fun quote_price(
    quote: &PriceQuote,
): u64 {
    quote.price
}

public fun quote_confidence_bps(
    quote: &PriceQuote,
): u64 {
    quote.confidence_bps
}

public fun quote_observed_at_ms(
    quote: &PriceQuote,
): u64 {
    quote.observed_at_ms
}

public fun quote_queried_at_ms(
    quote: &PriceQuote,
): u64 {
    quote.queried_at_ms
}

public fun quote_age_ms(
    quote: &PriceQuote,
): u64 {
    quote.age_ms
}

public fun quote_effective_max_age_ms(
    quote: &PriceQuote,
): u64 {
    quote.effective_max_age_ms
}
