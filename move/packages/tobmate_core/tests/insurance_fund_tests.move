#[test_only]
module tobmate_core::insurance_fund_tests;

use sui::coin;
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::insurance_fund::{
    Self as insurance_fund,
};

const ADMIN: address = @0xAD;
const CLAIMANT: address = @0xCA11;

const DEPOSIT_AMOUNT: u64 = 1_000_000_000;
const CLAIM_AMOUNT: u64 = 400_000_000;
const APPROVED_AMOUNT: u64 = 300_000_000;

#[test]
fun insurance_fund_initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    let fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(insurance_fund::version(&fund) == 1, 100);
    assert!(!insurance_fund::is_paused(&fund), 101);
    assert!(insurance_fund::fund_balance(&fund) == 0, 102);
    assert!(insurance_fund::claim_count(&fund) == 0, 103);
    assert!(insurance_fund::total_paid(&fund) == 0, 104);

    insurance_fund::assert_accounting_invariant(&fund);
    insurance_fund::destroy_for_testing(fund);

    test_scenario::end(scenario);
}

#[test]
fun deposit_preserves_accounting() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            DEPOSIT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut fund,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        insurance_fund::fund_balance(&fund)
            == DEPOSIT_AMOUNT,
        200,
    );

    assert!(
        insurance_fund::total_deposited(&fund)
            == DEPOSIT_AMOUNT,
        201,
    );

    insurance_fund::assert_accounting_invariant(&fund);

    let remaining =
        insurance_fund::drain_for_testing(
            &mut fund,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(remaining)
            == DEPOSIT_AMOUNT,
        202,
    );

    insurance_fund::destroy_for_testing(fund);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun claim_approval_and_payment_succeeds() {
    let mut scenario = test_scenario::begin(CLAIMANT);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            DEPOSIT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::deposit(
        &access,
        &mut fund,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    let claim_id =
        insurance_fund::submit_claim(
            &access,
            &mut fund,
            CLAIM_AMOUNT,
            1,
            b"claim-evidence-hash",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        insurance_fund::claim_status(
            &fund,
            claim_id,
        ) == insurance_fund::status_submitted(),
        300,
    );

    insurance_fund::review_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        insurance_fund::claim_status(
            &fund,
            claim_id,
        ) == insurance_fund::status_reviewed(),
        301,
    );

    insurance_fund::approve_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        APPROVED_AMOUNT,
        1001,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        insurance_fund::claim_status(
            &fund,
            claim_id,
        ) == insurance_fund::status_approved(),
        302,
    );

    insurance_fund::pay_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        insurance_fund::claim_status(
            &fund,
            claim_id,
        ) == insurance_fund::status_paid(),
        303,
    );

    assert!(
        insurance_fund::fund_balance(&fund)
            == DEPOSIT_AMOUNT - APPROVED_AMOUNT,
        304,
    );

    assert!(
        insurance_fund::total_paid(&fund)
            == APPROVED_AMOUNT,
        305,
    );

    assert!(
        insurance_fund::paid_claim_count(&fund) == 1,
        306,
    );

    insurance_fund::assert_accounting_invariant(&fund);

    let remaining =
        insurance_fund::drain_for_testing(
            &mut fund,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::burn_for_testing(remaining)
            == DEPOSIT_AMOUNT - APPROVED_AMOUNT,
        307,
    );

    insurance_fund::destroy_for_testing(fund);

    insurance_fund::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
fun reviewed_claim_can_be_rejected() {
    let mut scenario = test_scenario::begin(CLAIMANT);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let claim_id =
        insurance_fund::submit_claim(
            &access,
            &mut fund,
            CLAIM_AMOUNT,
            2,
            b"rejection-evidence",
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::review_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::reject_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        2001,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        insurance_fund::claim_status(
            &fund,
            claim_id,
        ) == insurance_fund::status_rejected(),
        400,
    );

    assert!(
        insurance_fund::total_rejected(&fund)
            == CLAIM_AMOUNT,
        401,
    );

    assert!(
        insurance_fund::rejected_claim_count(&fund) == 1,
        402,
    );

    insurance_fund::destroy_for_testing(fund);

    insurance_fund::destroy_admin_cap_for_testing(
        admin_cap,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::insurance_fund
)]
fun approval_above_requested_amount_aborts() {
    let mut scenario = test_scenario::begin(CLAIMANT);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let claim_id =
        insurance_fund::submit_claim(
            &access,
            &mut fund,
            CLAIM_AMOUNT,
            3,
            b"invalid-approval",
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::review_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::approve_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        CLAIM_AMOUNT + 1,
        3001,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::insurance_fund
)]
fun insufficient_fund_balance_blocks_payment() {
    let mut scenario = test_scenario::begin(CLAIMANT);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let claim_id =
        insurance_fund::submit_claim(
            &access,
            &mut fund,
            CLAIM_AMOUNT,
            4,
            b"insufficient-balance",
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::review_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::approve_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        APPROVED_AMOUNT,
        4001,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::pay_claim(
        &admin_cap,
        &access,
        &mut fund,
        claim_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::insurance_fund
)]
fun paused_fund_blocks_claim_submission() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        insurance_fund::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fund =
        insurance_fund::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    insurance_fund::set_paused(
        &admin_cap,
        &mut fund,
        true,
        test_scenario::ctx(&mut scenario),
    );

    insurance_fund::submit_claim(
        &access,
        &mut fund,
        CLAIM_AMOUNT,
        5,
        b"paused-claim",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
