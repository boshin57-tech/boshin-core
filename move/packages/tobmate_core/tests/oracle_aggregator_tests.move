#[test_only]
module tobmate_core::oracle_aggregator_tests;

use sui::test_scenario;
use sui::transfer;

use tobmate_core::oracle_aggregator;

const ADMIN: address = @0xA11CE;
const PUBLISHER: address = @0xB0B;

#[test]
fun odd_observation_median_is_correct() {
    let prices = vector[
        250_000_000,
        249_000_000,
        251_000_000,
    ];

    assert!(
        oracle_aggregator::calculate_median(prices)
            == 250_000_000,
        0,
    );
}

#[test]
fun even_observation_median_is_correct() {
    let prices = vector[
        240,
        100,
        300,
        200,
    ];

    assert!(
        oracle_aggregator::calculate_median(prices)
            == 220,
        0,
    );
}

#[test]
fun weighted_median_respects_publisher_weight() {
    let prices = vector[
        249_000_000,
        250_000_000,
        260_000_000,
    ];

    let weights = vector[
        10,
        70,
        20,
    ];

    assert!(
        oracle_aggregator::calculate_weighted_median(
            prices,
            weights,
        ) == 250_000_000,
        0,
    );
}

#[test]
fun weighted_median_can_differ_from_normal_median() {
    let prices = vector[
        100,
        200,
        300,
    ];

    let weights = vector[
        80,
        10,
        10,
    ];

    assert!(
        oracle_aggregator::calculate_median(
            vector[100, 200, 300],
        ) == 200,
        0,
    );

    assert!(
        oracle_aggregator::calculate_weighted_median(
            prices,
            weights,
        ) == 100,
        1,
    );
}

#[test]
fun weighted_median_sorts_price_weight_pairs() {
    let prices = vector[
        300,
        100,
        200,
    ];

    let weights = vector[
        10,
        60,
        30,
    ];

    assert!(
        oracle_aggregator::calculate_weighted_median(
            prices,
            weights,
        ) == 100,
        0,
    );
}

#[test]
fun deviation_basis_points_are_correct() {
    assert!(
        oracle_aggregator::calculate_deviation_bps(
            100_000,
            101_000,
        ) == 100,
        0,
    );

    assert!(
        oracle_aggregator::basis_point_denominator()
            == 10_000,
        1,
    );
}

#[test]
fun aggregator_initial_state_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    {
        let admin_cap =
            oracle_aggregator::create_aggregator(
                3,
                500,
                scenario.ctx(),
            );

        transfer::public_transfer(
            admin_cap,
            ADMIN,
        );
    };

    scenario.next_tx(ADMIN);

    {
        let aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        assert!(
            oracle_aggregator::version(&aggregator) == 1,
            0,
        );

        assert!(
            !oracle_aggregator::paused(&aggregator),
            1,
        );

        assert!(
            oracle_aggregator::min_observations(
                &aggregator,
            ) == 3,
            2,
        );

        assert!(
            oracle_aggregator::max_deviation_bps(
                &aggregator,
            ) == 500,
            3,
        );

        assert!(
            oracle_aggregator::latest_round_id(
                &aggregator,
            ) == 0,
            4,
        );

        test_scenario::return_shared(aggregator);
    };

    scenario.end();
}

#[test]
fun aggregation_round_updates_latest_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    {
        let admin_cap =
            oracle_aggregator::create_aggregator(
                3,
                1_000,
                scenario.ctx(),
            );

        transfer::public_transfer(
            admin_cap,
            ADMIN,
        );
    };

    scenario.next_tx(PUBLISHER);

    {
        let mut aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        oracle_aggregator::aggregate_round(
            &mut aggregator,
            vector[
                249_000_000,
                250_000_000,
                251_000_000,
            ],
            vector[
                20,
                60,
                20,
            ],
            10_000,
        );

        assert!(
            oracle_aggregator::latest_round_id(
                &aggregator,
            ) == 1,
            0,
        );

        assert!(
            oracle_aggregator::latest_median_price(
                &aggregator,
            ) == 250_000_000,
            1,
        );

        assert!(
            oracle_aggregator::
                latest_weighted_median_price(
                    &aggregator,
                ) == 250_000_000,
            2,
        );

        assert!(
            oracle_aggregator::
                latest_observation_count(
                    &aggregator,
                ) == 3,
            3,
        );

        assert!(
            oracle_aggregator::latest_timestamp_ms(
                &aggregator,
            ) == 10_000,
            4,
        );

        test_scenario::return_shared(aggregator);
    };

    scenario.end();
}

#[test]
fun aggregation_policy_can_be_updated() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    {
        let admin_cap =
            oracle_aggregator::create_aggregator(
                3,
                500,
                scenario.ctx(),
            );

        transfer::public_transfer(
            admin_cap,
            ADMIN,
        );
    };

    scenario.next_tx(ADMIN);

    {
        let admin_cap =
            scenario.take_from_sender<
                oracle_aggregator::OracleAggregatorAdminCap
            >();

        let mut aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        oracle_aggregator::update_policy(
            &admin_cap,
            &mut aggregator,
            5,
            250,
        );

        assert!(
            oracle_aggregator::min_observations(
                &aggregator,
            ) == 5,
            0,
        );

        assert!(
            oracle_aggregator::max_deviation_bps(
                &aggregator,
            ) == 250,
            1,
        );

        test_scenario::return_shared(aggregator);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

#[test]
fun aggregator_pause_lifecycle_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    {
        let admin_cap =
            oracle_aggregator::create_aggregator(
                3,
                500,
                scenario.ctx(),
            );

        transfer::public_transfer(
            admin_cap,
            ADMIN,
        );
    };

    scenario.next_tx(ADMIN);

    {
        let admin_cap =
            scenario.take_from_sender<
                oracle_aggregator::OracleAggregatorAdminCap
            >();

        let mut aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        oracle_aggregator::set_paused(
            &admin_cap,
            &mut aggregator,
            true,
        );

        assert!(
            oracle_aggregator::paused(&aggregator),
            0,
        );

        oracle_aggregator::set_paused(
            &admin_cap,
            &mut aggregator,
            false,
        );

        assert!(
            !oracle_aggregator::paused(&aggregator),
            1,
        );

        test_scenario::return_shared(aggregator);
        scenario.return_to_sender(admin_cap);
    };

    scenario.end();
}

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::oracle_aggregator,
)]
fun insufficient_observations_abort() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    {
        let admin_cap =
            oracle_aggregator::create_aggregator(
                3,
                500,
                scenario.ctx(),
            );

        transfer::public_transfer(
            admin_cap,
            ADMIN,
        );
    };

    scenario.next_tx(PUBLISHER);

    {
        let mut aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        oracle_aggregator::aggregate_round(
            &mut aggregator,
            vector[100, 101],
            vector[50, 50],
            10_000,
        );

        test_scenario::return_shared(aggregator);
    };

    scenario.end();
}

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::oracle_aggregator,
)]
fun price_weight_length_mismatch_aborts() {
    oracle_aggregator::calculate_weighted_median(
        vector[100, 101, 102],
        vector[50, 50],
    );
}

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::oracle_aggregator,
)]
fun zero_price_aborts() {
    oracle_aggregator::calculate_median(
        vector[100, 0, 102],
    );
}

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::oracle_aggregator,
)]
fun zero_weight_aborts() {
    oracle_aggregator::calculate_weighted_median(
        vector[100, 101, 102],
        vector[10, 0, 20],
    );
}

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::oracle_aggregator,
)]
fun paused_aggregator_blocks_round() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    {
        let admin_cap =
            oracle_aggregator::create_aggregator(
                3,
                500,
                scenario.ctx(),
            );

        transfer::public_transfer(
            admin_cap,
            ADMIN,
        );
    };

    scenario.next_tx(ADMIN);

    {
        let admin_cap =
            scenario.take_from_sender<
                oracle_aggregator::OracleAggregatorAdminCap
            >();

        let mut aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        oracle_aggregator::set_paused(
            &admin_cap,
            &mut aggregator,
            true,
        );

        test_scenario::return_shared(aggregator);
        scenario.return_to_sender(admin_cap);
    };

    scenario.next_tx(PUBLISHER);

    {
        let mut aggregator =
            scenario.take_shared<
                oracle_aggregator::OracleAggregator
            >();

        oracle_aggregator::aggregate_round(
            &mut aggregator,
            vector[100, 101, 102],
            vector[10, 70, 20],
            10_000,
        );

        test_scenario::return_shared(aggregator);
    };

    scenario.end();
}
