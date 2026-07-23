#[test_only]
module tobmate_core::marketplace_tests;

use tobmate_core::marketplace;

const E_UNEXPECTED_RESULT: u64 = 1;

#[test]
fun zero_fee_returns_zero() {
    assert!(
        marketplace::calculate_marketplace_fee(1_000_000, 0) == 0,
        E_UNEXPECTED_RESULT,
    );
}

#[test]
fun one_percent_fee_is_correct() {
    assert!(
        marketplace::calculate_marketplace_fee(1_000_000, 100) == 10_000,
        E_UNEXPECTED_RESULT,
    );
}

#[test]
fun two_point_five_percent_fee_is_correct() {
    assert!(
        marketplace::calculate_marketplace_fee(1_000_000, 250) == 25_000,
        E_UNEXPECTED_RESULT,
    );
}

#[test]
fun maximum_marketplace_fee_is_correct() {
    let max_fee_bps = marketplace::max_marketplace_fee_bps();

    assert!(max_fee_bps == 1_000, E_UNEXPECTED_RESULT);

    assert!(
        marketplace::calculate_marketplace_fee(
            1_000_000,
            max_fee_bps,
        ) == 100_000,
        E_UNEXPECTED_RESULT,
    );
}

#[test]
fun basis_point_denominator_is_correct() {
    assert!(
        marketplace::bps_denominator() == 10_000,
        E_UNEXPECTED_RESULT,
    );
}

#[test]
fun fee_calculation_rounds_down_safely() {
    assert!(
        marketplace::calculate_marketplace_fee(999, 25) == 2,
        E_UNEXPECTED_RESULT,
    );
}
