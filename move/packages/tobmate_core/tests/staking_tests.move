#[test_only]
module tobmate_core::staking_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::staking;

const ADMIN: address = @0xAD;
const OTHER: address = @0xCAFE;


/* ============================================================
   Test 01 — Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        staking::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(
        staking::version(&registry) == 1,
        1,
    );

    assert!(
        !staking::is_paused(&registry),
        2,
    );

    assert!(
        staking::pool_count(&registry) == 0,
        3,
    );

    assert!(
        staking::position_count(&registry) == 0,
        4,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 0,
        5,
    );

    staking::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Pool Registration
   ============================================================ */

#[test]
fun test_02_pool_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    assert!(pool_id == 1, 10);

    assert!(
        staking::pool_count(
            &registry,
        ) == 1,
        11,
    );

    assert!(
        staking::pool_reward_rate_bps(
            &registry,
            pool_id,
        ) == 800,
        12,
    );

    assert!(
        staking::pool_minimum_stake(
            &registry,
            pool_id,
        ) == 1_000,
        13,
    );

    assert!(
        staking::pool_lock_epochs(
            &registry,
            pool_id,
        ) == 10,
        14,
    );

    assert!(
        staking::pool_cooldown_epochs(
            &registry,
            pool_id,
        ) == 3,
        15,
    );

    assert!(
        !staking::pool_is_active(
            &registry,
            pool_id,
        ),
        16,
    );

    staking::destroy_admin_cap_for_testing(
        cap,
    );

    staking::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Pool Activation
   ============================================================ */

#[test]
fun test_03_pool_activation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    assert!(
        staking::pool_is_active(
            &registry,
            pool_id,
        ),
        20,
    );

    staking::destroy_admin_cap_for_testing(
        cap,
    );

    staking::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Pause Lifecycle
   ============================================================ */

#[test]
fun test_04_pause_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(
                &mut scenario,
            ),
        );

    staking::set_paused(
        &mut registry,
        &cap,
        true,
    );

    assert!(
        staking::is_paused(
            &registry,
        ),
        30,
    );

    staking::set_paused(
        &mut registry,
        &cap,
        false,
    );

    assert!(
        !staking::is_paused(
            &registry,
        ),
        31,
    );

    staking::destroy_admin_cap_for_testing(
        cap,
    );

    staking::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Invalid Reward Rate Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::staking,
)]
fun test_05_invalid_reward_rate_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    staking::register_pool(
        &access,
        &mut registry,
        &cap,
        b"INVALID-RATE",
        10_001,
        1_000,
        10,
        3,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06 — Zero Minimum Stake Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::staking,
)]
fun test_06_zero_minimum_stake_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    staking::register_pool(
        &access,
        &mut registry,
        &cap,
        b"ZERO-MINIMUM",
        800,
        0,
        10,
        3,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Duplicate Pool State Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::staking,
)]
fun test_07_duplicate_pool_state_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    abort 999
}


/* ============================================================
   Test 08 — Non-Increasing Version Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::staking,
)]
fun test_08_non_increasing_version_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_version(
        &mut registry,
        &cap,
        1,
    );

    abort 999
}


/* ============================================================
   Test 09 — Stake Succeeds
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_09_stake_succeeds() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let stake_coin =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            stake_coin,
            test_scenario::ctx(&mut scenario),
        );

    assert!(position_id == 1, 90);

    assert!(
        staking::position_owner(
            &registry,
            position_id,
        ) == ADMIN,
        91,
    );

    assert!(
        staking::position_pool_id(
            &registry,
            position_id,
        ) == pool_id,
        92,
    );

    assert!(
        staking::position_principal(
            &registry,
            position_id,
        ) == 5_000,
        93,
    );

    assert!(
        staking::position_is_active(
            &registry,
            position_id,
        ),
        94,
    );

    assert!(
        staking::principal_custody_balance(
            &registry,
        ) == 5_000,
        95,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 5_000,
        96,
    );

    assert!(
        staking::position_count(
            &registry,
        ) == 1,
        97,
    );

    assert!(
        staking::active_position_count(
            &registry,
        ) == 1,
        98,
    );

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    abort 0
}


/* ============================================================
   Test 10 — Inactive Pool Blocks Stake
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::staking,
)]
fun test_10_inactive_pool_blocks_stake() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(&mut scenario),
        );

    let stake_coin =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    staking::stake(
        &access,
        &mut registry,
        pool_id,
        stake_coin,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Below Minimum Stake Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::staking,
)]
fun test_11_below_minimum_stake_rejected() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let stake_coin =
        coin::mint_for_testing<SUI>(
            999,
            test_scenario::ctx(&mut scenario),
        );

    staking::stake(
        &access,
        &mut registry,
        pool_id,
        stake_coin,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Multiple Stakes Preserve Accounting
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_12_multiple_stakes_preserve_accounting() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            10,
            3,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let coin_a =
        coin::mint_for_testing<SUI>(
            2_000,
            test_scenario::ctx(&mut scenario),
        );

    staking::stake(
        &access,
        &mut registry,
        pool_id,
        coin_a,
        test_scenario::ctx(&mut scenario),
    );

    let coin_b =
        coin::mint_for_testing<SUI>(
            3_000,
            test_scenario::ctx(&mut scenario),
        );

    staking::stake(
        &access,
        &mut registry,
        pool_id,
        coin_b,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::principal_custody_balance(
            &registry,
        ) == 5_000,
        120,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 5_000,
        121,
    );

    assert!(
        staking::position_count(
            &registry,
        ) == 2,
        122,
    );

    assert!(
        staking::active_position_count(
            &registry,
        ) == 2,
        123,
    );

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    abort 0
}


/* ============================================================
   Test 13 — Unstake Before Lock Expiry Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::staking,
)]
fun test_13_unstake_before_lock_expiry_rejected() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            2,
            0,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            1_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(withdrawn);

    abort 999
}


/* ============================================================
   Test 14 — Partial Unstake After Lock
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_14_partial_unstake_after_lock() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            2,
            0,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            2_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&withdrawn) == 2_000,
        140,
    );

    assert!(
        staking::position_principal(
            &registry,
            position_id,
        ) == 3_000,
        141,
    );

    assert!(
        staking::position_is_active(
            &registry,
            position_id,
        ),
        142,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 3_000,
        143,
    );

    assert!(
        staking::principal_custody_balance(
            &registry,
        ) == 3_000,
        144,
    );

    assert!(
        staking::active_position_count(
            &registry,
        ) == 1,
        145,
    );

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    coin::burn_for_testing(withdrawn);

    abort 0
}


/* ============================================================
   Test 15 — Full Unstake Closes Position
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_15_full_unstake_closes_position() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            1,
            0,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    scenario.next_epoch(ADMIN);

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&withdrawn) == 5_000,
        150,
    );

    assert!(
        staking::position_principal(
            &registry,
            position_id,
        ) == 0,
        151,
    );

    assert!(
        !staking::position_is_active(
            &registry,
            position_id,
        ),
        152,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 0,
        153,
    );

    assert!(
        staking::principal_custody_balance(
            &registry,
        ) == 0,
        154,
    );

    assert!(
        staking::active_position_count(
            &registry,
        ) == 0,
        155,
    );

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    coin::burn_for_testing(withdrawn);

    abort 0
}


/* ============================================================
   Test 16 — Non Owner Cannot Unstake
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::staking,
)]
fun test_16_non_owner_unstake_rejected() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    scenario.next_tx(OTHER);

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            1_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(withdrawn);

    abort 999
}


/* ============================================================
   Test 17 — Cooldown Requires Unstake Request
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::staking,
)]
fun test_17_cooldown_requires_request() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"COOLDOWN-POOL",
            800,
            1_000,
            0,
            2,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            1_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(withdrawn);

    abort 999
}


/* ============================================================
   Test 18 — Cooldown Blocks Immediate Unstake
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::staking,
)]
fun test_18_cooldown_blocks_immediate_unstake() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"COOLDOWN-POOL",
            800,
            1_000,
            0,
            2,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    staking::request_unstake(
        &access,
        &mut registry,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            1_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(withdrawn);

    abort 999
}


/* ============================================================
   Test 19 — Unstake After Cooldown Succeeds
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_19_unstake_after_cooldown_succeeds() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"COOLDOWN-POOL",
            800,
            1_000,
            0,
            2,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    staking::request_unstake(
        &access,
        &mut registry,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::position_unstake_requested(
            &registry,
            position_id,
        ),
        190,
    );

    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            2_000,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        coin::value(&withdrawn) == 2_000,
        191,
    );

    assert!(
        staking::position_principal(
            &registry,
            position_id,
        ) == 3_000,
        192,
    );

    assert!(
        staking::principal_custody_balance(
            &registry,
        ) == 3_000,
        193,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 3_000,
        194,
    );

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    coin::burn_for_testing(withdrawn);

    abort 0
}


/* ============================================================
   Test 20 — Duplicate Unstake Request Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::staking,
)]
fun test_20_duplicate_unstake_request_rejected() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"COOLDOWN-POOL",
            800,
            1_000,
            0,
            2,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    staking::request_unstake(
        &access,
        &mut registry,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    staking::request_unstake(
        &access,
        &mut registry,
        position_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 21 — Partial Then Full Unstake Preserves Accounting
   ============================================================ */

#[test]
#[expected_failure(abort_code = 0)]
fun test_21_partial_then_full_unstake_preserves_accounting() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    let first =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            2_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(first);

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    assert!(
        staking::position_principal(
            &registry,
            position_id,
        ) == 3_000,
        210,
    );

    let second =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            3_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(second);

    staking::assert_principal_accounting_invariant(
        &registry,
    );

    assert!(
        staking::principal_custody_balance(
            &registry,
        ) == 0,
        211,
    );

    assert!(
        staking::total_principal_staked(
            &registry,
        ) == 0,
        212,
    );

    assert!(
        staking::active_position_count(
            &registry,
        ) == 0,
        213,
    );

    abort 0
}


/* ============================================================
   Test 22 — Closed Position Cannot Unstake Again
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::staking,
)]
fun test_22_closed_position_cannot_unstake_again() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        staking::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let cap =
        staking::new_admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let pool_id =
        staking::register_pool(
            &access,
            &mut registry,
            &cap,
            b"SUI-STAKING",
            800,
            1_000,
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    staking::set_pool_active(
        &access,
        &mut registry,
        &cap,
        pool_id,
        true,
    );

    let principal =
        coin::mint_for_testing<SUI>(
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    let position_id =
        staking::stake(
            &access,
            &mut registry,
            pool_id,
            principal,
            test_scenario::ctx(&mut scenario),
        );

    let withdrawn =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            5_000,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(withdrawn);

    let second =
        staking::unstake(
            &access,
            &mut registry,
            position_id,
            1,
            test_scenario::ctx(&mut scenario),
        );

    coin::burn_for_testing(second);

    abort 999
}


/* ============================================================
   Stage 8C Part 2 — Reward Accounting Integration
   ============================================================ */

/* Test 23 — Reward Position Link Succeeds */

#[test]
#[expected_failure(abort_code = 0)]
fun test_23_reward_position_link_succeeds() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::position_reward_position_linked(
            &registry, position_id,
        ),
        230,
    );

    assert!(
        staking::position_reward_position_id(
            &registry, position_id,
        ) == 7001,
        231,
    );

    staking::assert_reward_accounting_invariant(&registry);

    abort 0
}


/* Test 24 — Duplicate Reward Link Rejected */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::staking,
)]
fun test_24_duplicate_reward_link_rejected() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7002,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 25 — Reward Accrual Updates Position */

#[test]
#[expected_failure(abort_code = 0)]
fun test_25_reward_accrual_updates_position() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry,
        position_id,
        400,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::position_pending_reward(
            &registry, position_id,
        ) == 400,
        250,
    );

    assert!(
        staking::position_total_reward_accrued(
            &registry, position_id,
        ) == 400,
        251,
    );

    assert!(
        staking::position_total_reward_claimed(
            &registry, position_id,
        ) == 0,
        252,
    );

    abort 0
}


/* Test 26 — Reward Accrual Updates Global Accounting */

#[test]
#[expected_failure(abort_code = 0)]
fun test_26_reward_accrual_updates_global_accounting() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry,
        position_id,
        600,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::total_reward_accrued(&registry) == 600,
        260,
    );
    assert!(
        staking::total_reward_pending(&registry) == 600,
        261,
    );
    assert!(
        staking::total_reward_claimed(&registry) == 0,
        262,
    );

    staking::assert_reward_accounting_invariant(&registry);

    abort 0
}


/* Test 27 — Reward Claim Reduces Pending */

#[test]
#[expected_failure(abort_code = 0)]
fun test_27_reward_claim_reduces_pending() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry,
        position_id,
        1_000,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_claim(
        &mut registry,
        position_id,
        400,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::position_pending_reward(
            &registry, position_id,
        ) == 600,
        270,
    );

    assert!(
        staking::position_total_reward_claimed(
            &registry, position_id,
        ) == 400,
        271,
    );

    assert!(
        staking::total_reward_accrued(&registry) == 1_000,
        272,
    );

    assert!(
        staking::total_reward_pending(&registry) == 600,
        273,
    );

    assert!(
        staking::total_reward_claimed(&registry) == 400,
        274,
    );

    staking::assert_reward_accounting_invariant(&registry);

    abort 0
}


/* Test 28 — Claim Above Pending Reward Rejected */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::staking,
)]
fun test_28_claim_above_pending_reward_rejected() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry,
        position_id,
        500,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_claim(
        &mut registry,
        position_id,
        501,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 29 — Multiple Accruals And Claims Preserve Invariant */

#[test]
#[expected_failure(abort_code = 0)]
fun test_29_multiple_accruals_and_claims_preserve_invariant() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry, position_id, 300,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry, position_id, 700,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_claim(
        &mut registry, position_id, 250,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_claim(
        &mut registry, position_id, 350,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        staking::position_total_reward_accrued(
            &registry, position_id,
        ) == 1_000,
        290,
    );

    assert!(
        staking::position_pending_reward(
            &registry, position_id,
        ) == 400,
        291,
    );

    assert!(
        staking::position_total_reward_claimed(
            &registry, position_id,
        ) == 600,
        292,
    );

    assert!(staking::total_reward_accrued(&registry) == 1_000, 293);
    assert!(staking::total_reward_pending(&registry) == 400, 294);
    assert!(staking::total_reward_claimed(&registry) == 600, 295);

    staking::assert_reward_accounting_invariant(&registry);

    abort 0
}


/* Test 30 — Reward Accounting Survives Full Unstake */

#[test]
#[expected_failure(abort_code = 0)]
fun test_30_reward_accounting_survives_full_unstake() {
    use sui::coin;
    use sui::sui::SUI;

    let mut scenario = test_scenario::begin(ADMIN);
    let access = access_control::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let mut registry = staking::new_for_testing(
        test_scenario::ctx(&mut scenario),
    );
    let cap = staking::new_admin_cap_for_testing(
        &registry,
        test_scenario::ctx(&mut scenario),
    );

    let pool_id = staking::register_pool(
        &access, &mut registry, &cap,
        b"SUI-STAKING",
        800, 1_000, 0, 0,
        test_scenario::ctx(&mut scenario),
    );

    staking::set_pool_active(
        &access, &mut registry, &cap,
        pool_id, true,
    );

    let principal = coin::mint_for_testing<SUI>(
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    let position_id = staking::stake(
        &access, &mut registry,
        pool_id, principal,
        test_scenario::ctx(&mut scenario),
    );

    staking::link_reward_position(
        &mut registry,
        position_id,
        7001,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_accrual(
        &mut registry, position_id, 900,
        test_scenario::ctx(&mut scenario),
    );

    staking::record_reward_claim(
        &mut registry, position_id, 300,
        test_scenario::ctx(&mut scenario),
    );

    let withdrawn = staking::unstake(
        &access,
        &mut registry,
        position_id,
        5_000,
        test_scenario::ctx(&mut scenario),
    );

    coin::burn_for_testing(withdrawn);

    assert!(
        !staking::position_is_active(
            &registry, position_id,
        ),
        300,
    );

    assert!(
        staking::position_pending_reward(
            &registry, position_id,
        ) == 600,
        301,
    );

    assert!(
        staking::position_total_reward_accrued(
            &registry, position_id,
        ) == 900,
        302,
    );

    assert!(
        staking::position_total_reward_claimed(
            &registry, position_id,
        ) == 300,
        303,
    );

    assert!(staking::total_reward_accrued(&registry) == 900, 304);
    assert!(staking::total_reward_pending(&registry) == 600, 305);
    assert!(staking::total_reward_claimed(&registry) == 300, 306);

    staking::assert_principal_accounting_invariant(&registry);
    staking::assert_reward_accounting_invariant(&registry);

    abort 0
}
