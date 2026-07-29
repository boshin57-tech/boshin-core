#[test_only]
module tobmate_finance::risk_controller_tests;

use sui::coin;
use sui::object;
use sui::sui::SUI;
use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_finance::bad_debt_settlement;

use tobmate_finance::collateral_manager::{
    Self as collateral_manager,
};

use tobmate_finance::insurance_fund;

use tobmate_finance::lending_pool::{
    Self as lending_pool,
};

use tobmate_finance::oracle_price_router::{
    Self as oracle_price_router,
};

use tobmate_finance::recovery_mode;

use tobmate_finance::risk_controller;

use tobmate_finance::treasury;

const OWNER: address = @0xBEEF;

const RESERVE_FACTOR_BPS: u64 = 1_000;
const BASE_BORROW_RATE_BPS: u64 = 500;

const SUPPLY_AMOUNT: u64 = 10_000;
const BORROW_AMOUNT: u64 = 1_000;

const COLLATERAL_TYPE_SUI: u8 = 1;
const ASSET_KEY: vector<u8> = b"SUI";
const ORACLE_SYMBOL: vector<u8> = b"SUI_USD";
const ORACLE_FEED_ID: u64 = 1;
const ASSET_DECIMALS: u8 = 9;

const MAX_LTV_BPS: u64 = 7_000;
const LIQ_THRESHOLD_BPS: u64 = 8_000;
const LIQ_BONUS_BPS: u64 = 500;

const COLLATERAL_AMOUNT: u64 = 1_000_000_000;


/* ============================================================
   Test 01 — Normal Mode Borrow Allowed
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_01_normal_mode_borrow_allowed() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(&mut scenario),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    let supply =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply,
        test_scenario::ctx(&mut scenario),
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

    let borrowed =
        risk_controller::borrow(
            &recovery,
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            position_id,
            BORROW_AMOUNT,
            &quote,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&borrowed) == BORROW_AMOUNT,
        10,
    );

    assert!(
        lending_pool::outstanding_borrow_principal(
            &pool,
        ) == BORROW_AMOUNT,
        11,
    );

    assert!(
        collateral_manager::position_debt_value(
            &collateral,
            position_id,
        ) == BORROW_AMOUNT,
        12,
    );

    abort 0
}


/* ============================================================
   Test 02 — Recovery Mode Borrow Blocked
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_finance::recovery_mode,
)]
fun test_02_recovery_mode_borrow_blocked() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut debt_registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut recovery =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    /*
       Create uncovered bad debt:
       debt = 1,000
       absorption capacity = 0
    */

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        1,
        1,
        OWNER,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_activate(
        &mut recovery,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    assert!(
        recovery_mode::is_recovery_mode(
            &recovery,
        ),
        20,
    );

    /*
       The Recovery guard executes before the underlying
       LendingPool borrow validation.
    */

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

    let _borrowed =
        risk_controller::borrow(
            &recovery,
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            1,
            BORROW_AMOUNT,
            &quote,
            test_scenario::ctx(&mut scenario),
        );

    abort 999
}


/* ============================================================
   Test 03 — Normal Mode Collateral Withdrawal Allowed
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_03_normal_mode_withdrawal_allowed() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let recovery =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(&mut scenario),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    risk_controller::withdraw_collateral(
        &recovery,
        &access,
        &mut collateral,
        position_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        collateral_manager::position_collateral_units(
            &collateral,
            position_id,
        ) == 900_000_000,
        30,
    );

    abort 0
}


/* ============================================================
   Test 04 — Recovery Mode Collateral Withdrawal Blocked
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_finance::recovery_mode,
)]
fun test_04_recovery_mode_withdrawal_blocked() {
    let mut scenario =
        test_scenario::begin(OWNER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            RESERVE_FACTOR_BPS,
            BASE_BORROW_RATE_BPS,
            test_scenario::ctx(&mut scenario),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut debt_registry =
        bad_debt_settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let insurance =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut recovery =
        recovery_mode::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        collateral_manager::register_policy(
            &collateral_cap,
            &mut collateral,
            COLLATERAL_TYPE_SUI,
            ASSET_KEY,
            ORACLE_SYMBOL,
            ORACLE_FEED_ID,
            ASSET_DECIMALS,
            MAX_LTV_BPS,
            LIQ_THRESHOLD_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(&mut scenario),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            OWNER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    bad_debt_settlement::record_bad_debt(
        &access,
        &mut debt_registry,
        &mut pool,
        1,
        1,
        OWNER,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    recovery_mode::evaluate_and_activate(
        &mut recovery,
        &pool,
        &insurance,
        &protocol_treasury,
    );

    risk_controller::withdraw_collateral(
        &recovery,
        &access,
        &mut collateral,
        position_id,
        100_000_000,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
