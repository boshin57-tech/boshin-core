#[test_only]
module tobmate_core::fee_vault_tests;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as test_scenario};

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::fee_vault::{
    Self as fee_vault,
};

const ADMIN: address = @0xAD;
const PAYER: address = @0xFEE;

const MARKETPLACE_AMOUNT: u64 = 300_000_000;
const MINT_AMOUNT: u64 = 200_000_000;
const RELEASE_AMOUNT: u64 = 400_000_000;

/// FeeVault starts empty and solvent.
#[test]
fun fee_vault_initial_state_is_valid() {
    let mut scenario = test_scenario::begin(ADMIN);

    let vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(fee_vault::version(&vault) == 1, 100);
    assert!(!fee_vault::is_paused(&vault), 101);
    assert!(fee_vault::pending_balance(&vault) == 0, 102);
    assert!(fee_vault::total_collected(&vault) == 0, 103);
    assert!(fee_vault::total_released(&vault) == 0, 104);

    fee_vault::assert_accounting_invariant(&vault);
    fee_vault::destroy_empty_for_testing(vault);

    test_scenario::end(scenario);
}

/// Collects multiple fee categories and verifies category accounting.
#[test]
fun fee_collection_tracks_categories() {
    let mut scenario = test_scenario::begin(PAYER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let marketplace_payment =
        coin::mint_for_testing<SUI>(
            MARKETPLACE_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::collect_fee(
        &access,
        &mut vault,
        fee_vault::fee_marketplace(),
        marketplace_payment,
        test_scenario::ctx(&mut scenario),
    );

    let mint_payment =
        coin::mint_for_testing<SUI>(
            MINT_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::collect_fee(
        &access,
        &mut vault,
        fee_vault::fee_mint(),
        mint_payment,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == MARKETPLACE_AMOUNT + MINT_AMOUNT,
        200,
    );

    assert!(
        fee_vault::marketplace_fees(&vault)
            == MARKETPLACE_AMOUNT,
        201,
    );

    assert!(
        fee_vault::mint_fees(&vault)
            == MINT_AMOUNT,
        202,
    );

    assert!(
        fee_vault::collection_count(&vault) == 2,
        203,
    );

    fee_vault::assert_accounting_invariant(&vault);

    let released =
        fee_vault::release_fees(
            &collector_cap,
            &access,
            &mut vault,
            RELEASE_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&released) == RELEASE_AMOUNT,
        204,
    );

    assert!(
        fee_vault::pending_balance(&vault)
            == MARKETPLACE_AMOUNT
                + MINT_AMOUNT
                - RELEASE_AMOUNT,
        205,
    );

    assert!(
        fee_vault::total_released(&vault)
            == RELEASE_AMOUNT,
        206,
    );

    let released_value =
        coin::burn_for_testing(released);

    assert!(released_value == RELEASE_AMOUNT, 207);

    let remaining =
        fee_vault::release_all(
            &collector_cap,
            &access,
            &mut vault,
            test_scenario::ctx(&mut scenario),
        );

    let remaining_value =
        coin::burn_for_testing(remaining);

    assert!(
        remaining_value
            == MARKETPLACE_AMOUNT
                + MINT_AMOUNT
                - RELEASE_AMOUNT,
        208,
    );

    assert!(fee_vault::pending_balance(&vault) == 0, 209);

    fee_vault::assert_accounting_invariant(&vault);

    fee_vault::destroy_empty_for_testing(vault);
    fee_vault::destroy_collector_cap_for_testing(
        collector_cap,
    );
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}

/// Invalid fee category must abort.
#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::fee_vault,
)]
fun invalid_fee_category_aborts() {
    let mut scenario = test_scenario::begin(PAYER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let payment =
        coin::mint_for_testing<SUI>(
            MARKETPLACE_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::collect_fee(
        &access,
        &mut vault,
        99,
        payment,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// FeeVault-local pause blocks collection.
#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::fee_vault,
)]
fun paused_fee_vault_blocks_collection() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        fee_vault::new_admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::set_paused(
        &admin_cap,
        &mut vault,
        true,
        test_scenario::ctx(&mut scenario),
    );

    let payment =
        coin::mint_for_testing<SUI>(
            MARKETPLACE_AMOUNT,
            test_scenario::ctx(&mut scenario),
        );

    fee_vault::collect_fee(
        &access,
        &mut vault,
        fee_vault::fee_marketplace(),
        payment,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}

/// Release above pending balance must abort.
#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::fee_vault,
)]
fun release_above_pending_balance_aborts() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let collector_cap =
        fee_vault::new_collector_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut vault =
        fee_vault::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let released = fee_vault::release_fees(
        &collector_cap,
        &access,
        &mut vault,
        1,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(released);

    abort 999
}
