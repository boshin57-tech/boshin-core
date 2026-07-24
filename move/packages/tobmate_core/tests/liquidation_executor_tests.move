#[test_only]
module tobmate_core::liquidation_executor_tests;

use sui::test_scenario;

use tobmate_core::liquidation_executor;

use sui::coin;
use sui::object;
use sui::sui::SUI;

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::collateral_manager::{
    Self as collateral_manager,
    CollateralManager,
    CollateralManagerAdminCap,
};

use tobmate_core::lending_pool::{
    Self as lending_pool,
    LendingAdminCap,
    LendingPool,
};

use tobmate_core::liquidation_engine::{
    Self as liquidation_engine,
    LiquidationEngine,
};

use tobmate_core::oracle_price_router;

const ADMIN: address = @0xA;

/* ============================================================
   Test 1 — Executor Initial State
   ============================================================ */

#[test]
fun test_01_executor_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let executor =
        liquidation_executor::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        liquidation_executor::version(
            &executor,
        ) == 1,
        1,
    );

    assert!(
        !liquidation_executor::is_paused(
            &executor,
        ),
        2,
    );

    assert!(
        liquidation_executor::next_execution_id(
            &executor,
        ) == 1,
        3,
    );

    assert!(
        liquidation_executor::total_executions(
            &executor,
        ) == 0,
        4,
    );

    assert!(
        liquidation_executor::total_repaid_principal(
            &executor,
        ) == 0,
        5,
    );

    assert!(
        liquidation_executor::total_collateral_seized(
            &executor,
        ) == 0,
        6,
    );

    assert!(
        liquidation_executor::execution_count(
            &executor,
        ) == 0,
        7,
    );

    liquidation_executor::destroy_for_testing(
        executor,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 2 — Pause Lifecycle
   ============================================================ */

#[test]
fun test_02_pause_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut executor =
        liquidation_executor::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        liquidation_executor::admin_cap_for_testing(
            &executor,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    liquidation_executor::set_paused(
        &mut executor,
        &cap,
        true,
    );

    assert!(
        liquidation_executor::is_paused(
            &executor,
        ),
        10,
    );

    liquidation_executor::set_paused(
        &mut executor,
        &cap,
        false,
    );

    assert!(
        !liquidation_executor::is_paused(
            &executor,
        ),
        11,
    );

    liquidation_executor::destroy_admin_cap_for_testing(
        cap,
    );

    liquidation_executor::destroy_for_testing(
        executor,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Stage 6D-2 Integration Fixture
   ============================================================ */

const BORROWER: address = @0xB;
const LIQUIDATOR: address = @0xC;

const COLLATERAL_TYPE_SUI: u8 = 1;
const ASSET_KEY: vector<u8> = b"SUI";
const ORACLE_SYMBOL: vector<u8> = b"SUI_USD";
const ORACLE_FEED_ID: u64 = 1;

const ASSET_DECIMALS: u8 = 9;

const MAX_LTV_BPS: u64 = 8_000;
const LIQ_THRESHOLD_BPS: u64 = 8_500;
const LIQ_BONUS_BPS: u64 = 500;

const CLOSE_FACTOR_BPS: u64 = 5_000;

const COLLATERAL_AMOUNT: u64 = 1_000_000_000;
const SUPPLY_AMOUNT: u64 = 5_000;
const BORROW_AMOUNT: u64 = 1_500;

fun setup_liquidation_fixture(
    scenario: &mut test_scenario::Scenario,
): (
    AccessControl,
    CollateralManagerAdminCap,
    LendingAdminCap,
    LendingPool,
    CollateralManager,
    LiquidationEngine,
    liquidation_executor::LiquidationExecutor,
    u64,
    u64,
) {
    let access =
        access_control::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let collateral_cap =
        collateral_manager::new_admin_cap_for_testing(
            test_scenario::ctx(scenario),
        );

    let lending_cap =
        lending_pool::new_admin_cap_for_testing(
            test_scenario::ctx(scenario),
        );

    let mut collateral =
        collateral_manager::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let mut pool =
        lending_pool::new_for_testing(
            1_000,
            500,
            test_scenario::ctx(scenario),
        );

    let mut engine =
        liquidation_engine::new_for_testing(
            LIQ_THRESHOLD_BPS,
            CLOSE_FACTOR_BPS,
            LIQ_BONUS_BPS,
            test_scenario::ctx(scenario),
        );

    let executor =
        liquidation_executor::new_for_testing(
            test_scenario::ctx(scenario),
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
            test_scenario::ctx(scenario),
        );

    collateral_manager::set_policy_active(
        &collateral_cap,
        &mut collateral,
        policy_id,
        true,
        test_scenario::ctx(scenario),
    );

    let primary_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            BORROWER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(scenario),
        );

    let secondary_position_id =
        collateral_manager::open_position(
            &access,
            &mut collateral,
            policy_id,
            BORROWER,
            COLLATERAL_AMOUNT,
            test_scenario::ctx(scenario),
        );

    let supply_coin =
        coin::mint_for_testing<SUI>(
            SUPPLY_AMOUNT,
            test_scenario::ctx(scenario),
        );

    lending_pool::supply(
        &access,
        &mut pool,
        supply_coin,
        test_scenario::ctx(scenario),
    );

    let healthy_quote =
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
        lending_pool::borrow(
            &lending_cap,
            &collateral_cap,
            &access,
            &mut pool,
            &mut collateral,
            primary_position_id,
            BORROW_AMOUNT,
            &healthy_quote,
            test_scenario::ctx(scenario),
        );

    coin::burn_for_testing(borrowed);

    (
        access,
        collateral_cap,
        lending_cap,
        pool,
        collateral,
        engine,
        executor,
        primary_position_id,
        secondary_position_id,
    )
}

/* ============================================================
   Test 3 — Healthy Position Must Reject Liquidation
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::liquidation_executor,
)]
fun test_03_healthy_position_rejected() {
    let mut scenario =
        test_scenario::begin(BORROWER);

    let (
        access,
        collateral_cap,
        _lending_cap,
        mut pool,
        mut collateral,
        mut engine,
        mut executor,
        primary_position_id,
        _secondary_position_id,
    ) = setup_liquidation_fixture(
        &mut scenario,
    );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let payment =
        coin::mint_for_testing<SUI>(
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let healthy_quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            2,
            2_000,
            40,
            20_000,
            20_000,
            60_000,
        );

    liquidation_executor::execute_liquidation(
        &mut executor,
        &mut engine,
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        primary_position_id,
        payment,
        &healthy_quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

/* ============================================================
   Test 4 — Position Link Mismatch
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::liquidation_executor,
)]
fun test_04_position_link_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(BORROWER);

    let (
        access,
        collateral_cap,
        _lending_cap,
        mut pool,
        mut collateral,
        mut engine,
        mut executor,
        _primary_position_id,
        secondary_position_id,
    ) = setup_liquidation_fixture(
        &mut scenario,
    );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let payment =
        coin::mint_for_testing<SUI>(
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let liquidatable_quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            2,
            1_500,
            40,
            20_000,
            20_000,
            60_000,
        );

    liquidation_executor::execute_liquidation(
        &mut executor,
        &mut engine,
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        secondary_position_id,
        payment,
        &liquidatable_quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

/* ============================================================
   Test 5 — Close Factor Protection
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::liquidation_executor,
)]
fun test_05_close_factor_exceeded_rejected() {
    let mut scenario =
        test_scenario::begin(BORROWER);

    let (
        access,
        collateral_cap,
        _lending_cap,
        mut pool,
        mut collateral,
        mut engine,
        mut executor,
        primary_position_id,
        _secondary_position_id,
    ) = setup_liquidation_fixture(
        &mut scenario,
    );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let payment =
        coin::mint_for_testing<SUI>(
            800,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let liquidatable_quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            2,
            1_500,
            40,
            20_000,
            20_000,
            60_000,
        );

    liquidation_executor::execute_liquidation(
        &mut executor,
        &mut engine,
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        primary_position_id,
        payment,
        &liquidatable_quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    abort 999
}

/* ============================================================
   Test 6 — Successful Atomic Liquidation
   ============================================================ */

#[test]
fun test_06_successful_liquidation() {
    let mut scenario =
        test_scenario::begin(BORROWER);

    let (
        access,
        collateral_cap,
        _lending_cap,
        mut pool,
        mut collateral,
        mut engine,
        mut executor,
        primary_position_id,
        _secondary_position_id,
    ) = setup_liquidation_fixture(
        &mut scenario,
    );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let payment =
        coin::mint_for_testing<SUI>(
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let liquidatable_quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            2,
            1_500,
            40,
            20_000,
            20_000,
            60_000,
        );

    liquidation_executor::execute_liquidation(
        &mut executor,
        &mut engine,
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        primary_position_id,
        payment,
        &liquidatable_quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    assert!(
        liquidation_executor::total_executions(
            &executor,
        ) == 1,
        60,
    );

    assert!(
        liquidation_executor::total_repaid_principal(
            &executor,
        ) == 500,
        61,
    );

    assert!(
        liquidation_executor::total_collateral_seized(
            &executor,
        ) == 350_000_000,
        62,
    );

    assert!(
        liquidation_executor::execution_count(
            &executor,
        ) == 1,
        63,
    );

    assert!(
        liquidation_executor::execution_repay_amount(
            &executor,
            0,
        ) == 500,
        64,
    );

    assert!(
        liquidation_executor::execution_collateral_seized(
            &executor,
            0,
        ) == 350_000_000,
        65,
    );

    assert!(
        liquidation_executor::execution_health_factor_bps(
            &executor,
            0,
        ) < 10_000,
        66,
    );

    liquidation_executor::destroy_for_testing(
        executor,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    lending_pool::destroy_admin_cap_for_testing(
        _lending_cap,
    );

    collateral_manager::destroy_for_testing(
        collateral,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        collateral_cap,
    );

    liquidation_engine::destroy_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 7 — Debt / Collateral Conservation
   ============================================================ */

#[test]
fun test_07_liquidation_conservation() {
    let mut scenario =
        test_scenario::begin(BORROWER);

    let (
        access,
        collateral_cap,
        _lending_cap,
        mut pool,
        mut collateral,
        mut engine,
        mut executor,
        primary_position_id,
        _secondary_position_id,
    ) = setup_liquidation_fixture(
        &mut scenario,
    );

    let debt_before =
        lending_pool::borrow_position_principal_debt(
            &pool,
            1,
        );

    let collateral_before =
        collateral_manager::position_collateral_units(
            &collateral,
            primary_position_id,
        );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let payment =
        coin::mint_for_testing<SUI>(
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let liquidatable_quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            2,
            1_500,
            40,
            20_000,
            20_000,
            60_000,
        );

    liquidation_executor::execute_liquidation(
        &mut executor,
        &mut engine,
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        primary_position_id,
        payment,
        &liquidatable_quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    let debt_after =
        lending_pool::borrow_position_principal_debt(
            &pool,
            1,
        );

    let collateral_after =
        collateral_manager::position_collateral_units(
            &collateral,
            primary_position_id,
        );

    let seized =
        liquidation_executor::execution_collateral_seized(
            &executor,
            0,
        );

    assert!(
        debt_before == 1_500,
        70,
    );

    assert!(
        debt_after == 1_000,
        71,
    );

    assert!(
        debt_before - debt_after == 500,
        72,
    );

    assert!(
        collateral_before
            - collateral_after
            == seized,
        73,
    );

    assert!(
        collateral_before
            == collateral_after + seized,
        74,
    );

    assert!(
        collateral_after
            == 650_000_000,
        75,
    );

    assert!(
        collateral_manager::position_debt_value(
            &collateral,
            primary_position_id,
        ) == debt_after,
        76,
    );

    assert!(
        liquidation_executor::execution_debt_before(
            &executor,
            0,
        ) == debt_before,
        77,
    );

    assert!(
        liquidation_executor::execution_debt_after(
            &executor,
            0,
        ) == debt_after,
        78,
    );

    assert!(
        liquidation_executor::execution_collateral_before(
            &executor,
            0,
        ) == collateral_before,
        79,
    );

    assert!(
        liquidation_executor::execution_collateral_after(
            &executor,
            0,
        ) == collateral_after,
        80,
    );

    liquidation_executor::destroy_for_testing(
        executor,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    lending_pool::destroy_admin_cap_for_testing(
        _lending_cap,
    );

    collateral_manager::destroy_for_testing(
        collateral,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        collateral_cap,
    );

    liquidation_engine::destroy_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}

/* ============================================================
   Test 8 — Liquidator Claim Ownership
   ============================================================ */

#[test]
fun test_08_liquidator_claim_created() {
    let mut scenario =
        test_scenario::begin(BORROWER);

    let (
        access,
        collateral_cap,
        lending_cap,
        mut pool,
        mut collateral,
        mut engine,
        mut executor,
        primary_position_id,
        _secondary_position_id,
    ) = setup_liquidation_fixture(
        &mut scenario,
    );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let payment =
        coin::mint_for_testing<SUI>(
            500,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let liquidatable_quote =
        oracle_price_router::new_quote_for_testing(
            object::id_from_address(@0xCAFE),
            ORACLE_FEED_ID,
            2,
            1_500,
            40,
            20_000,
            20_000,
            60_000,
        );

    liquidation_executor::execute_liquidation(
        &mut executor,
        &mut engine,
        &collateral_cap,
        &access,
        &mut pool,
        &mut collateral,
        1,
        primary_position_id,
        payment,
        &liquidatable_quote,
        test_scenario::ctx(
            &mut scenario,
        ),
    );

    test_scenario::next_tx(
        &mut scenario,
        LIQUIDATOR,
    );

    let claim =
        test_scenario::take_from_sender<
            liquidation_executor::LiquidatorClaim
        >(
            &scenario,
        );

    assert!(
        liquidation_executor::claim_execution_id(
            &claim,
        ) == 1,
        90,
    );

    assert!(
        liquidation_executor::claim_collateral_position_id(
            &claim,
        ) == primary_position_id,
        91,
    );

    assert!(
        liquidation_executor::claim_liquidator(
            &claim,
        ) == LIQUIDATOR,
        92,
    );

    assert!(
        liquidation_executor::claim_seized_units(
            &claim,
        ) == 350_000_000,
        93,
    );

    assert!(
        !liquidation_executor::claim_is_claimed(
            &claim,
        ),
        94,
    );

    liquidation_executor::destroy_claim_for_testing(
        claim,
    );

    liquidation_executor::destroy_for_testing(
        executor,
    );

    let drained =
        lending_pool::drain_for_testing(
            &mut pool,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    coin::burn_for_testing(drained);

    lending_pool::destroy_empty_for_testing(
        pool,
    );

    lending_pool::destroy_admin_cap_for_testing(
        lending_cap,
    );

    collateral_manager::destroy_for_testing(
        collateral,
    );

    collateral_manager::destroy_admin_cap_for_testing(
        collateral_cap,
    );

    liquidation_engine::destroy_for_testing(
        engine,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
