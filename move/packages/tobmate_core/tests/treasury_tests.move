#[test_only]
module tobmate_core::treasury_tests;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::treasury::{
    Self as treasury,
    ProtocolTreasury,
    TreasuryAdminCap,
};

const ADMIN: address = @0xAD;
const DEPOSITOR: address = @0xD3;
const RECIPIENT: address = @0xBEEF;

const DEPOSIT_AMOUNT: u64 = 1_000_000_000;
const WITHDRAW_AMOUNT: u64 = 400_000_000;

/// Confirms that a newly created Treasury starts in a valid empty state.
#[test]
fun treasury_initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);
    let ctx = test_scenario::ctx(&mut scenario);

    let treasury =
        treasury::new_for_testing(ctx);

    assert!(treasury::version(&treasury) == 1, 100);
    assert!(!treasury::is_paused(&treasury), 101);
    assert!(treasury::balance(&treasury) == 0, 102);
    assert!(treasury::total_deposited(&treasury) == 0, 103);
    assert!(treasury::total_withdrawn(&treasury) == 0, 104);
    assert!(treasury::deposit_count(&treasury) == 0, 105);
    assert!(treasury::withdrawal_count(&treasury) == 0, 106);

    treasury::assert_accounting_invariant(&treasury);
    treasury::destroy_empty_for_testing(treasury);

    test_scenario::end(scenario);
}

/// Deposits actual test SUI, performs an administrator withdrawal,
/// and verifies the accounting invariant after both operations.
#[test]
fun deposit_and_withdraw_preserve_accounting() {
    let mut scenario = test_scenario::begin(DEPOSITOR);

    let access_control =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            DEPOSIT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access_control,
        &mut protocol_treasury,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == DEPOSIT_AMOUNT,
        200,
    );

    assert!(
        treasury::total_deposited(&protocol_treasury)
            == DEPOSIT_AMOUNT,
        201,
    );

    assert!(
        treasury::total_withdrawn(&protocol_treasury) == 0,
        202,
    );

    assert!(
        treasury::deposit_count(&protocol_treasury) == 1,
        203,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    treasury::withdraw(
        &admin_cap,
        &access_control,
        &mut protocol_treasury,
        WITHDRAW_AMOUNT,
        RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::balance(&protocol_treasury)
            == DEPOSIT_AMOUNT - WITHDRAW_AMOUNT,
        204,
    );

    assert!(
        treasury::total_deposited(&protocol_treasury)
            == DEPOSIT_AMOUNT,
        205,
    );

    assert!(
        treasury::total_withdrawn(&protocol_treasury)
            == WITHDRAW_AMOUNT,
        206,
    );

    assert!(
        treasury::withdrawal_count(&protocol_treasury) == 1,
        207,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    // Withdraw the remaining balance so the Treasury can be destroyed.
    treasury::withdraw(
        &admin_cap,
        &access_control,
        &mut protocol_treasury,
        DEPOSIT_AMOUNT - WITHDRAW_AMOUNT,
        RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::balance(&protocol_treasury) == 0,
        208,
    );

    assert!(
        treasury::total_withdrawn(&protocol_treasury)
            == DEPOSIT_AMOUNT,
        209,
    );

    treasury::assert_accounting_invariant(
        &protocol_treasury,
    );

    // Two withdrawal Coin<SUI> objects were transferred to RECIPIENT.
    test_scenario::next_tx(&mut scenario, RECIPIENT);

    let withdrawn_coin_one =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    let withdrawn_coin_two =
        test_scenario::take_from_sender<Coin<SUI>>(
            &scenario,
        );

    let value_one =
        coin::burn_for_testing(withdrawn_coin_one);

    let value_two =
        coin::burn_for_testing(withdrawn_coin_two);

    assert!(
        value_one + value_two == DEPOSIT_AMOUNT,
        210,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    treasury::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(
        access_control,
    );

    test_scenario::end(scenario);
}

/// Treasury-local pause must block deposits.
#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::treasury,
)]
fun deposit_aborts_when_treasury_is_paused() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access_control =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    treasury::set_paused(
        &admin_cap,
        &mut protocol_treasury,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let payment =
        coin::mint_for_testing<SUI>(
            DEPOSIT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access_control,
        &mut protocol_treasury,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// Withdrawal greater than the Treasury balance must abort.
#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::treasury,
)]
fun withdrawal_above_balance_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access_control =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            WITHDRAW_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access_control,
        &mut protocol_treasury,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    treasury::withdraw(
        &admin_cap,
        &access_control,
        &mut protocol_treasury,
        WITHDRAW_AMOUNT + 1,
        RECIPIENT,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// A zero-valued Coin cannot be deposited.
#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::treasury,
)]
fun zero_value_deposit_aborts() {
    let mut scenario = test_scenario::begin(DEPOSITOR);

    let access_control =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            0,
            test_scenario::ctx(&mut scenario),
        );

    treasury::deposit(
        &access_control,
        &mut protocol_treasury,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// Duplicate Treasury pause state changes must abort.
#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::treasury,
)]
fun duplicate_pause_state_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let admin_cap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    treasury::set_paused(
        &admin_cap,
        &mut protocol_treasury,
        true,
        test_scenario::ctx(&mut scenario),
    );

    treasury::set_paused(
        &admin_cap,
        &mut protocol_treasury,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// Treasury version can be upgraded by TreasuryAdminCap.
#[test]
fun treasury_version_update_succeeds() {
    let mut scenario = test_scenario::begin(ADMIN);

    let admin_cap: TreasuryAdminCap =
        treasury::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut protocol_treasury: ProtocolTreasury =
        treasury::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    treasury::set_version(
        &admin_cap,
        &mut protocol_treasury,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        treasury::version(&protocol_treasury) == 2,
        300,
    );

    treasury::destroy_empty_for_testing(
        protocol_treasury,
    );

    treasury::destroy_admin_cap_for_testing(
        admin_cap,
    );

    test_scenario::end(scenario);
}
