#[test_only]
module tobmate_core::lp_reward_distributor_tests;

use sui::coin;
use sui::object;
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::lp_reward_distributor::{
    Self as lp_reward_distributor,
};

const ADMIN: address = @0xAD;
const OWNER: address = @0xA11CE;
const OTHER_OWNER: address = @0xB0B;
const FUNDER: address = @0xF00D;

const FUND_AMOUNT: u64 = 1_000_000;
const FIRST_REWARD: u64 = 250_000;
const SECOND_REWARD: u64 = 150_000;

const E_DISTRIBUTOR_PAUSED: u64 = 1;
const E_ZERO_FUNDING: u64 = 2;
const E_ZERO_LIQUIDITY_WEIGHT: u64 = 3;
const E_INSUFFICIENT_UNALLOCATED_REWARDS: u64 = 7;
const E_NOT_POSITION_OWNER: u64 = 8;
const E_NO_PENDING_REWARD: u64 = 9;
const E_DUPLICATE_EXTERNAL_POSITION: u64 = 10;

fun destroy_empty_fixture(
    access: tobmate_core::access_control::AccessControl,
    distributor:
        tobmate_core::lp_reward_distributor::LPRewardDistributor,
    admin_cap:
        tobmate_core::lp_reward_distributor::LPRewardAdminCap,
) {
    access_control::destroy_for_testing(access);

    lp_reward_distributor::destroy_admin_cap_for_testing(
        admin_cap,
    );

    lp_reward_distributor::destroy_for_testing(
        distributor,
    );
}

#[test]
fun initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        lp_reward_distributor::version(&distributor) == 1,
        100,
    );

    assert!(
        !lp_reward_distributor::is_paused(&distributor),
        101,
    );

    assert!(
        lp_reward_distributor::reward_balance(
            &distributor,
        ) == 0,
        102,
    );

    assert!(
        lp_reward_distributor::position_count(
            &distributor,
        ) == 0,
        103,
    );

    assert!(
        lp_reward_distributor::total_funded(
            &distributor,
        ) == 0,
        104,
    );

    assert!(
        lp_reward_distributor::total_accrued(
            &distributor,
        ) == 0,
        105,
    );

    assert!(
        lp_reward_distributor::total_pending(
            &distributor,
        ) == 0,
        106,
    );

    assert!(
        lp_reward_distributor::total_claimed(
            &distributor,
        ) == 0,
        107,
    );

    assert!(
        lp_reward_distributor::next_position_id_for_testing(
            &distributor,
        ) == 1,
        108,
    );

    assert!(
        lp_reward_distributor::funding_count_for_testing(
            &distributor,
        ) == 0,
        109,
    );

    assert!(
        lp_reward_distributor::accrual_count_for_testing(
            &distributor,
        ) == 0,
        110,
    );

    assert!(
        lp_reward_distributor::claim_count_for_testing(
            &distributor,
        ) == 0,
        111,
    );

    lp_reward_distributor::assert_accounting_invariant(
        &distributor,
    );

    let empty_coin =
        lp_reward_distributor::drain_for_testing(
            &mut distributor,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(empty_coin) == 0,
        112,
    );

    destroy_empty_fixture(
        access,
        distributor,
        admin_cap,
    );

    test_scenario::end(scenario);
}

#[test]
fun funding_preserves_accounting() {
    let mut scenario = test_scenario::begin(FUNDER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        lp_reward_distributor::reward_balance(
            &distributor,
        ) == FUND_AMOUNT,
        200,
    );

    assert!(
        lp_reward_distributor::total_funded(
            &distributor,
        ) == FUND_AMOUNT,
        201,
    );

    assert!(
        lp_reward_distributor::funding_count_for_testing(
            &distributor,
        ) == 1,
        202,
    );

    lp_reward_distributor::assert_accounting_invariant(
        &distributor,
    );

    let remaining =
        lp_reward_distributor::drain_for_testing(
            &mut distributor,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(remaining)
            == FUND_AMOUNT,
        203,
    );

    destroy_empty_fixture(
        access,
        distributor,
        admin_cap,
    );

    test_scenario::end(scenario);
}

#[test]
fun position_registration_updates_state() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        object::id_from_address(@0x101);

    let position_id =
        lp_reward_distributor::register_position(
            &admin_cap,
            &access,
            &mut distributor,
            OWNER,
            pool_id,
            b"pool-one-position",
            10_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(position_id == 1, 300);

    assert!(
        lp_reward_distributor::position_count(
            &distributor,
        ) == 1,
        301,
    );

    assert!(
        lp_reward_distributor::next_position_id_for_testing(
            &distributor,
        ) == 2,
        302,
    );

    assert!(
        lp_reward_distributor::position_owner(
            &distributor,
            position_id,
        ) == OWNER,
        303,
    );

    assert!(
        lp_reward_distributor::position_pending_reward(
            &distributor,
            position_id,
        ) == 0,
        304,
    );

    lp_reward_distributor::assert_accounting_invariant(
        &distributor,
    );

    let empty_coin =
        lp_reward_distributor::drain_for_testing(
            &mut distributor,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(empty_coin);

    destroy_empty_fixture(
        access,
        distributor,
        admin_cap,
    );

    test_scenario::end(scenario);
}

#[test]
fun reward_accrual_updates_position_and_totals() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        lp_reward_distributor::register_position(
            &admin_cap,
            &access,
            &mut distributor,
            OWNER,
            object::id_from_address(@0x102),
            b"accrual-position",
            50_000,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::accrue_reward(
        &admin_cap,
        &access,
        &mut distributor,
        position_id,
        FIRST_REWARD,
        test_scenario::ctx(&mut scenario),
    );

    lp_reward_distributor::accrue_reward(
        &admin_cap,
        &access,
        &mut distributor,
        position_id,
        SECOND_REWARD,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        lp_reward_distributor::position_pending_reward(
            &distributor,
            position_id,
        ) == FIRST_REWARD + SECOND_REWARD,
        400,
    );

    assert!(
        lp_reward_distributor::position_total_accrued(
            &distributor,
            position_id,
        ) == FIRST_REWARD + SECOND_REWARD,
        401,
    );

    assert!(
        lp_reward_distributor::total_accrued(
            &distributor,
        ) == FIRST_REWARD + SECOND_REWARD,
        402,
    );

    assert!(
        lp_reward_distributor::total_pending(
            &distributor,
        ) == FIRST_REWARD + SECOND_REWARD,
        403,
    );

    assert!(
        lp_reward_distributor::accrual_count_for_testing(
            &distributor,
        ) == 2,
        404,
    );

    lp_reward_distributor::assert_accounting_invariant(
        &distributor,
    );

    test_scenario::next_tx(
        &mut scenario,
        OWNER,
    );

    lp_reward_distributor::claim_reward(
        &access,
        &mut distributor,
        position_id,
        test_scenario::ctx(&mut scenario),
    );


    let remaining =
        lp_reward_distributor::drain_for_testing(
            &mut distributor,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(remaining)
            == FUND_AMOUNT
                - FIRST_REWARD
                - SECOND_REWARD,
        406,
    );

    destroy_empty_fixture(
        access,
        distributor,
        admin_cap,
    );

    test_scenario::end(scenario);
}

#[test]
fun owner_can_claim_accrued_reward() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        lp_reward_distributor::register_position(
            &admin_cap,
            &access,
            &mut distributor,
            OWNER,
            object::id_from_address(@0x103),
            b"claim-position",
            25_000,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::accrue_reward(
        &admin_cap,
        &access,
        &mut distributor,
        position_id,
        FIRST_REWARD,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        OWNER,
    );

    lp_reward_distributor::claim_reward(
        &access,
        &mut distributor,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        lp_reward_distributor::reward_balance(
            &distributor,
        ) == FUND_AMOUNT - FIRST_REWARD,
        500,
    );

    assert!(
        lp_reward_distributor::position_pending_reward(
            &distributor,
            position_id,
        ) == 0,
        501,
    );

    assert!(
        lp_reward_distributor::position_total_claimed(
            &distributor,
            position_id,
        ) == FIRST_REWARD,
        502,
    );

    assert!(
        lp_reward_distributor::total_pending(
            &distributor,
        ) == 0,
        503,
    );

    assert!(
        lp_reward_distributor::total_claimed(
            &distributor,
        ) == FIRST_REWARD,
        504,
    );

    assert!(
        lp_reward_distributor::claim_count_for_testing(
            &distributor,
        ) == 1,
        505,
    );

    lp_reward_distributor::assert_accounting_invariant(
        &distributor,
    );


    let remaining =
        lp_reward_distributor::drain_for_testing(
            &mut distributor,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(remaining)
            == FUND_AMOUNT - FIRST_REWARD,
        507,
    );

    destroy_empty_fixture(
        access,
        distributor,
        admin_cap,
    );

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = E_ZERO_FUNDING,
    location = tobmate_core::lp_reward_distributor
)]
fun zero_value_funding_aborts() {
    let mut scenario = test_scenario::begin(FUNDER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let zero_payment =
        coin::mint_for_testing<SUI>(
            0,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        zero_payment,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = E_ZERO_LIQUIDITY_WEIGHT,
    location = tobmate_core::lp_reward_distributor
)]
fun zero_liquidity_weight_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::register_position(
        &admin_cap,
        &access,
        &mut distributor,
        OWNER,
        object::id_from_address(@0x104),
        b"zero-weight",
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = E_DUPLICATE_EXTERNAL_POSITION,
    location = tobmate_core::lp_reward_distributor
)]
fun duplicate_external_position_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        object::id_from_address(@0x105);

    lp_reward_distributor::register_position(
        &admin_cap,
        &access,
        &mut distributor,
        OWNER,
        pool_id,
        b"duplicate-reference",
        10_000,
        test_scenario::ctx(&mut scenario),
    );

    lp_reward_distributor::register_position(
        &admin_cap,
        &access,
        &mut distributor,
        OTHER_OWNER,
        pool_id,
        b"duplicate-reference",
        20_000,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = E_INSUFFICIENT_UNALLOCATED_REWARDS,
    location = tobmate_core::lp_reward_distributor
)]
fun accrual_above_available_funds_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            FIRST_REWARD,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        lp_reward_distributor::register_position(
            &admin_cap,
            &access,
            &mut distributor,
            OWNER,
            object::id_from_address(@0x106),
            b"over-accrual",
            10_000,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::accrue_reward(
        &admin_cap,
        &access,
        &mut distributor,
        position_id,
        FIRST_REWARD + 1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = E_NOT_POSITION_OWNER,
    location = tobmate_core::lp_reward_distributor
)]
fun non_owner_cannot_claim_reward() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    let position_id =
        lp_reward_distributor::register_position(
            &admin_cap,
            &access,
            &mut distributor,
            OWNER,
            object::id_from_address(@0x107),
            b"owner-protected",
            10_000,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::accrue_reward(
        &admin_cap,
        &access,
        &mut distributor,
        position_id,
        FIRST_REWARD,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        OTHER_OWNER,
    );

    lp_reward_distributor::claim_reward(
        &access,
        &mut distributor,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = E_NO_PENDING_REWARD,
    location = tobmate_core::lp_reward_distributor
)]
fun claim_without_pending_reward_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        lp_reward_distributor::register_position(
            &admin_cap,
            &access,
            &mut distributor,
            OWNER,
            object::id_from_address(@0x108),
            b"no-pending-reward",
            10_000,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        OWNER,
    );

    lp_reward_distributor::claim_reward(
        &access,
        &mut distributor,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = E_DISTRIBUTOR_PAUSED,
    location = tobmate_core::lp_reward_distributor
)]
fun paused_distributor_blocks_funding() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        lp_reward_distributor::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut distributor =
        lp_reward_distributor::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::set_paused(
        &admin_cap,
        &mut distributor,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let funding =
        coin::mint_for_testing<SUI>(
            FUND_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    lp_reward_distributor::fund(
        &access,
        &mut distributor,
        funding,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
