#[test_only]
module tobmate_foundation::custodian_registry_tests;

use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::custodian_registry::{
    Self as custodian_registry,
};


const ADMIN: address = @0xA11CE;
const CUSTODIAN: address = @0xC057;


/* ============================================================
   Helpers
   ============================================================ */

fun custodian_key(): vector<u8> {
    b"TOBMATE-CUSTODIAN-001"
}

fun jurisdiction(): vector<u8> {
    b"AU"
}


/* ============================================================
   Test 01
   Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        custodian_registry::version(
            &registry,
        ) == 1,
        1,
    );

    assert!(
        !custodian_registry::is_paused(
            &registry,
        ),
        2,
    );

    assert!(
        custodian_registry::total_custodians(
            &registry,
        ) == 0,
        3,
    );

    assert!(
        custodian_registry::active_custodian_count(
            &registry,
        ) == 0,
        4,
    );

    custodian_registry::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Custodian Registration
   ============================================================ */

#[test]
fun test_02_custodian_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,

            custodian_key(),
            CUSTODIAN,

            custodian_registry::custodian_vault(),
            jurisdiction(),

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        custodian_id == 1,
        10,
    );

    assert!(
        custodian_registry::total_custodians(
            &registry,
        ) == 1,
        11,
    );

    assert!(
        custodian_registry::active_custodian_count(
            &registry,
        ) == 1,
        12,
    );

    assert!(
        custodian_registry::custodian_is_active(
            &registry,
            custodian_id,
        ),
        13,
    );

    assert!(
        custodian_registry::custodian_authority(
            &registry,
            custodian_id,
        ) == CUSTODIAN,
        14,
    );

    assert!(
        custodian_registry::custodian_jurisdiction(
            &registry,
            custodian_id,
        ) == jurisdiction(),
        15,
    );

    custodian_registry::assert_custodian_active(
        &registry,
        custodian_id,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    custodian_registry::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   Duplicate Custodian Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_foundation::custodian_registry,
)]
fun test_03_duplicate_custodian_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::register_custodian(
        &access,
        &mut registry,
        &admin_cap,
        custodian_key(),
        CUSTODIAN,
        custodian_registry::custodian_vault(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    custodian_registry::register_custodian(
        &access,
        &mut registry,
        &admin_cap,
        custodian_key(),
        @0xBEEF,
        custodian_registry::custodian_bank(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04
   Invalid Custodian Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_foundation::custodian_registry,
)]
fun test_04_invalid_custodian_type_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::register_custodian(
        &access,
        &mut registry,
        &admin_cap,
        custodian_key(),
        CUSTODIAN,
        99,
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Suspend / Reactivate Lifecycle
   ============================================================ */

#[test]
fun test_05_custodian_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,
            custodian_key(),
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            jurisdiction(),
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_custodian_active(
        &access,
        &mut registry,
        &admin_cap,
        custodian_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        !custodian_registry::custodian_is_active(
            &registry,
            custodian_id,
        ),
        20,
    );

    assert!(
        custodian_registry::active_custodian_count(
            &registry,
        ) == 0,
        21,
    );

    custodian_registry::set_custodian_active(
        &access,
        &mut registry,
        &admin_cap,
        custodian_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        custodian_registry::custodian_is_active(
            &registry,
            custodian_id,
        ),
        22,
    );

    assert!(
        custodian_registry::active_custodian_count(
            &registry,
        ) == 1,
        23,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    custodian_registry::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06
   Registry Pause / Version
   ============================================================ */

#[test]
fun test_06_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        custodian_registry::is_paused(
            &registry,
        ),
        30,
    );

    custodian_registry::set_version(
        &admin_cap,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        custodian_registry::version(
            &registry,
        ) == 2,
        31,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    custodian_registry::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Paused Registry Blocks Registration
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_foundation::custodian_registry,
)]
fun test_07_paused_registry_blocks_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    custodian_registry::register_custodian(
        &access,
        &mut registry,
        &admin_cap,
        custodian_key(),
        CUSTODIAN,
        custodian_registry::custodian_vault(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08
   Non-Increasing Version Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_foundation::custodian_registry,
)]
fun test_08_non_increasing_version_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_version(
        &admin_cap,
        &mut registry,
        1,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Wrong Admin Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_foundation::custodian_registry,
)]
fun test_09_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry_a =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        custodian_registry::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::register_custodian(
        &access,
        &mut registry_a,
        &admin_b,
        custodian_key(),
        CUSTODIAN,
        custodian_registry::custodian_vault(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Inactive Custodian Assertion Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_foundation::custodian_registry,
)]
fun test_10_inactive_custodian_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,
            custodian_key(),
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            jurisdiction(),
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_custodian_active(
        &access,
        &mut registry,
        &admin_cap,
        custodian_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    custodian_registry::assert_custodian_active(
        &registry,
        custodian_id,
    );

    abort 999
}


/* ============================================================
   Test 11
   Duplicate Status Change Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_foundation::custodian_registry,
)]
fun test_11_duplicate_status_change_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,
            custodian_key(),
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            jurisdiction(),
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_custodian_active(
        &access,
        &mut registry,
        &admin_cap,
        custodian_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    custodian_registry::set_custodian_active(
        &access,
        &mut registry,
        &admin_cap,
        custodian_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Multi-Custodian Accounting Invariant
   ============================================================ */

#[test]
fun test_12_multi_custodian_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        custodian_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let id_1 =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,
            b"CUSTODIAN-001",
            @0x101,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let id_2 =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,
            b"CUSTODIAN-002",
            @0x102,
            custodian_registry::custodian_bank(),
            b"SG",
            test_scenario::ctx(&mut scenario),
        );

    let id_3 =
        custodian_registry::register_custodian(
            &access,
            &mut registry,
            &admin_cap,
            b"CUSTODIAN-003",
            @0x103,
            custodian_registry::custodian_institutional(),
            b"US",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        id_1 == 1
            && id_2 == 2
            && id_3 == 3,
        40,
    );

    assert!(
        custodian_registry::total_custodians(
            &registry,
        ) == 3,
        41,
    );

    assert!(
        custodian_registry::active_custodian_count(
            &registry,
        ) == 3,
        42,
    );

    custodian_registry::set_custodian_active(
        &access,
        &mut registry,
        &admin_cap,
        id_2,
        false,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        custodian_registry::total_custodians(
            &registry,
        ) == 3,
        43,
    );

    assert!(
        custodian_registry::active_custodian_count(
            &registry,
        ) == 2,
        44,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    custodian_registry::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
