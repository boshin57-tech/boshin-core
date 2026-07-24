#[test_only]
module tobmate_core::collateral_manager_tests;

use sui::test_scenario::{Self as test_scenario};
use sui::object;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::collateral_manager::{
    Self as collateral_manager,
};

use tobmate_core::oracle_price_router::{
    Self as oracle_price_router,
};

const ADMIN: address = @0xAD;
const OWNER: address = @0xBEEF;

const ASSET_KEY: vector<u8> =
    b"SUI";

const ORACLE_SYMBOL: vector<u8> =
    b"SUI_USD";

const ORACLE_FEED_ID: u64 = 1;

const COLLATERAL_TYPE_SUI: u8 = 1;

const ASSET_DECIMALS: u8 = 9;

const MAX_LTV_BPS: u64 = 7_000;

const LIQ_THRESHOLD_BPS: u64 = 8_000;

const LIQ_BONUS_BPS: u64 = 500;

const INITIAL_COLLATERAL: u64 =
    1_000_000_000;

const ADDITIONAL_COLLATERAL: u64 =
    500_000_000;

#[test]
fun initial_state_is_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        collateral_manager::version(
            &manager,
        ) == 1,
        100,
    );

    assert!(
        !collateral_manager::is_paused(
            &manager,
        ),
        101,
    );

    assert!(
        collateral_manager::policy_count(
            &manager,
        ) == 0,
        102,
    );

    assert!(
        collateral_manager::position_count(
            &manager,
        ) == 0,
        103,
    );

    assert!(
        collateral_manager::total_collateral_units(
            &manager,
        ) == 0,
        104,
    );

    assert!(
        collateral_manager::total_debt_value(
            &manager,
        ) == 0,
        105,
    );

    collateral_manager::assert_accounting_invariant(
        &manager,
    );

    collateral_manager::destroy_for_testing(
        manager,
    );

    test_scenario::end(scenario);
}

#[test]
fun policy_registration_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(policy_id == 1, 200);

    assert!(
        collateral_manager::policy_count(
            &manager,
        ) == 1,
        201,
    );

    assert!(
        collateral_manager::policy_oracle_feed_id(
            &manager,
            policy_id,
        ) == ORACLE_FEED_ID,
        202,
    );

    assert!(
        collateral_manager::policy_max_ltv_bps(
            &manager,
            policy_id,
        ) == MAX_LTV_BPS,
        203,
    );

    collateral_manager::destroy_for_testing(
        manager,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        cap,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::collateral_manager,
)]
fun duplicate_policy_aborts() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::register_policy(
        &cap,
        &mut manager,
        COLLATERAL_TYPE_SUI,
        ASSET_KEY,
        ORACLE_SYMBOL,
        ORACLE_FEED_ID,
        ASSET_DECIMALS,
        MAX_LTV_BPS,
        LIQ_THRESHOLD_BPS,
        LIQ_BONUS_BPS,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    collateral_manager::register_policy(
        &cap,
        &mut manager,
        COLLATERAL_TYPE_SUI,
        ASSET_KEY,
        ORACLE_SYMBOL,
        ORACLE_FEED_ID,
        ASSET_DECIMALS,
        MAX_LTV_BPS,
        LIQ_THRESHOLD_BPS,
        LIQ_BONUS_BPS,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::collateral_manager,
)]
fun inactive_policy_blocks_position_open() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::open_position(
        &access,
        &mut manager,
        policy_id,
        OWNER,
        INITIAL_COLLATERAL,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
fun position_open_and_deposit_succeeds() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &cap,
        &mut manager,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut manager,
            policy_id,
            OWNER,
            INITIAL_COLLATERAL,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::deposit_collateral(
        &access,
        &mut manager,
        position_id,
        ADDITIONAL_COLLATERAL,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        collateral_manager::position_collateral_units(
            &manager,
            position_id,
        )
            ==
            INITIAL_COLLATERAL
                + ADDITIONAL_COLLATERAL,
        300,
    );

    assert!(
        collateral_manager::position_owner(
            &manager,
            position_id,
        ) == OWNER,
        301,
    );

    assert!(
        collateral_manager::position_is_active(
            &manager,
            position_id,
        ),
        302,
    );

    assert!(
        collateral_manager::total_collateral_units(
            &manager,
        )
            ==
            INITIAL_COLLATERAL
                + ADDITIONAL_COLLATERAL,
        303,
    );

    collateral_manager::assert_accounting_invariant(
        &manager,
    );

    collateral_manager::destroy_for_testing(
        manager,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::collateral_manager,
)]
fun withdrawal_above_collateral_aborts() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &cap,
        &mut manager,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut manager,
            policy_id,
            OWNER,
            INITIAL_COLLATERAL,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::withdraw_collateral(
        &access,
        &mut manager,
        position_id,
        INITIAL_COLLATERAL + 1,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
fun collateral_value_and_borrow_capacity_are_correct() {
    let collateral_value =
        collateral_manager::collateral_value_from_price(
            1_000_000_000,
            9,
            2_000,
        );

    assert!(
        collateral_value == 2_000,
        400,
    );

    let borrow_capacity =
        collateral_manager::borrow_capacity_from_value(
            collateral_value,
            7_000,
        );

    assert!(
        borrow_capacity == 1_400,
        401,
    );

    let liquidation_value =
        collateral_manager::liquidation_value_from_value(
            collateral_value,
            8_000,
        );

    assert!(
        liquidation_value == 1_600,
        402,
    );
}

#[test]
fun health_factor_calculation_is_correct() {
    let health_factor =
        collateral_manager::health_factor_from_values(
            2_000,
            1_600,
            8_000,
        );

    assert!(
        health_factor == 1_000_000,
        500,
    );

    let safer_health_factor =
        collateral_manager::health_factor_from_values(
            2_000,
            800,
            8_000,
        );

    assert!(
        safer_health_factor == 2_000_000,
        501,
    );
}

#[test]
#[expected_failure(
    abort_code = 19,
    location = tobmate_core::collateral_manager,
)]
fun oracle_feed_mismatch_aborts() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &cap,
        &mut manager,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut manager,
            policy_id,
            OWNER,
            INITIAL_COLLATERAL,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID + 1,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    collateral_manager::position_borrow_capacity_with_quote(
        &manager,
        position_id,
        &quote,
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 18,
    location = tobmate_core::collateral_manager,
)]
fun debt_above_capacity_aborts() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &cap,
        &mut manager,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut manager,
            policy_id,
            OWNER,
            INITIAL_COLLATERAL,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    // 1 SUI at price 2,000 with 70% LTV
    // gives capacity 1,400.
    collateral_manager::set_position_debt_value_with_quote(
        &cap,
        &access,
        &mut manager,
        position_id,
        1_401,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 20,
    location = tobmate_core::collateral_manager,
)]
fun unsafe_withdrawal_aborts() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &cap,
        &mut manager,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut manager,
            policy_id,
            OWNER,
            INITIAL_COLLATERAL,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    collateral_manager::set_position_debt_value_with_quote(
        &cap,
        &access,
        &mut manager,
        position_id,
        1_000,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    // After withdrawing 500,000,000 units,
    // remaining collateral is 0.5 SUI.
    // Value = 1,000 and max borrow capacity = 700.
    // Existing debt = 1,000, therefore withdrawal must abort.
    collateral_manager::withdraw_collateral_with_quote(
        &access,
        &mut manager,
        position_id,
        500_000_000,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

#[test]
fun liquidation_eligibility_is_correct() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut manager =
        collateral_manager::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let policy_id =
        collateral_manager::register_policy(
            &cap,
            &mut manager,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    collateral_manager::set_policy_active(
        &cap,
        &mut manager,
        policy_id,
        true,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut manager,
            policy_id,
            OWNER,
            INITIAL_COLLATERAL,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            1,
            2_000,
            40,
            10_000,
            10_000,
            60_000,
        );

    collateral_manager::set_position_debt_value_with_quote(
        &cap,
        &access,
        &mut manager,
        position_id,
        1_000,
        &quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        !collateral_manager::is_position_liquidatable(
            &manager,
            position_id,
            2_000,
        ),
        600,
    );

    assert!(
        collateral_manager::is_position_liquidatable(
            &manager,
            position_id,
            1_000,
        ),
        601,
    );

    collateral_manager::destroy_for_testing(
        manager,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        cap,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
