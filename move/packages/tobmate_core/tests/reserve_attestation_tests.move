#[test_only]
module tobmate_core::reserve_attestation_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::gold_reserve::{
    Self as gold_reserve,
};

use tobmate_core::custodian_registry::{
    Self as custodian_registry,
};

use tobmate_core::reserve_attestation::{
    Self as reserve_attestation,
};


const ADMIN: address = @0xA11CE;
const CUSTODIAN: address = @0xC057;
const ATTESTOR: address = @0xA77E57;


/* ============================================================
   Test 01
   Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        reserve_attestation::version(&registry) == 1,
        1,
    );

    assert!(
        !reserve_attestation::is_paused(&registry),
        2,
    );

    assert!(
        reserve_attestation::total_attestors(&registry) == 0,
        3,
    );

    assert!(
        reserve_attestation::active_attestor_count(
            &registry,
        ) == 0,
        4,
    );

    assert!(
        reserve_attestation::total_attestations(&registry) == 0,
        5,
    );

    assert!(
        reserve_attestation::active_attestation_count(
            &registry,
        ) == 0,
        6,
    );

    reserve_attestation::destroy_for_testing(registry);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Attestor Registration
   ============================================================ */

#[test]
fun test_02_attestor_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        reserve_attestation::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut registry,
            &admin_cap,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        attestor_id == 1,
        10,
    );

    assert!(
        reserve_attestation::total_attestors(
            &registry,
        ) == 1,
        11,
    );

    assert!(
        reserve_attestation::active_attestor_count(
            &registry,
        ) == 1,
        12,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        admin_cap,
    );

    reserve_attestation::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   Duplicate Attestor Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::reserve_attestation,
)]
fun test_03_duplicate_attestor_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        reserve_attestation::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    reserve_attestation::register_attestor(
        &access,
        &mut registry,
        &admin_cap,
        b"ATTESTOR-001",
        ATTESTOR,
        test_scenario::ctx(&mut scenario),
    );

    reserve_attestation::register_attestor(
        &access,
        &mut registry,
        &admin_cap,
        b"ATTESTOR-001",
        @0xBEEF,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04
   Attestor Lifecycle
   ============================================================ */

#[test]
fun test_04_attestor_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        reserve_attestation::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut registry,
            &admin_cap,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    reserve_attestation::set_attestor_active(
        &access,
        &mut registry,
        &admin_cap,
        attestor_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        reserve_attestation::active_attestor_count(
            &registry,
        ) == 0,
        20,
    );

    reserve_attestation::set_attestor_active(
        &access,
        &mut registry,
        &admin_cap,
        attestor_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        reserve_attestation::active_attestor_count(
            &registry,
        ) == 1,
        21,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        admin_cap,
    );

    reserve_attestation::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05
   Pause / Version
   ============================================================ */

#[test]
fun test_05_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        reserve_attestation::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    reserve_attestation::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        reserve_attestation::is_paused(
            &registry,
        ),
        30,
    );

    reserve_attestation::set_version(
        &admin_cap,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        reserve_attestation::version(
            &registry,
        ) == 2,
        31,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        admin_cap,
    );

    reserve_attestation::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06
   Reserve Attestation Succeeds
   ============================================================ */

#[test]
fun test_06_reserve_attestation_succeeds() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    let attestation_id =
        reserve_attestation::create_attestation(
            &access,
            &mut attestation_registry,
            &custodian_registry_obj,
            &reserve,
            custodian_id,
            attestor_id,
            b"RESERVE-ATTESTATION-HASH-001",
            1000000,
            10,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        attestation_id == 1,
        40,
    );

    assert!(
        reserve_attestation::total_attestations(
            &attestation_registry,
        ) == 1,
        41,
    );

    assert!(
        reserve_attestation::active_attestation_count(
            &attestation_registry,
        ) == 1,
        42,
    );

    assert!(
        reserve_attestation::attestation_status(
            &attestation_registry,
            attestation_id,
        ) == reserve_attestation::status_active(),
        43,
    );

    assert!(
        reserve_attestation::attestation_reserve_id(
            &attestation_registry,
            attestation_id,
        ) == gold_reserve::reserve_id(&reserve),
        44,
    );

    assert!(
        reserve_attestation::attestation_custodian_id(
            &attestation_registry,
            attestation_id,
        ) == custodian_id,
        45,
    );

    assert!(
        reserve_attestation::attestation_attested_weight_mg(
            &attestation_registry,
            attestation_id,
        ) == 1000000,
        46,
    );

    reserve_attestation::assert_attestation_valid(
        &attestation_registry,
        attestation_id,
        1,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        attestation_admin,
    );

    reserve_attestation::destroy_for_testing(
        attestation_registry,
    );

    gold_reserve::destroy_reserve_for_testing(
        reserve,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        custodian_admin,
    );

    custodian_registry::destroy_for_testing(
        custodian_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Unauthorized Attestor Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::reserve_attestation,
)]
fun test_07_unauthorized_attestor_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        @0xBAD,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"BAD-AUTHORITY",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08
   Inactive Attestor Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::reserve_attestation,
)]
fun test_08_inactive_attestor_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    reserve_attestation::set_attestor_active(
        &access,
        &mut attestation_registry,
        &attestation_admin,
        attestor_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"INACTIVE-ATTESTOR",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Inactive Custodian Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::custodian_registry,
)]
fun test_09_inactive_custodian_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    custodian_registry::set_custodian_active(
        &access,
        &mut custodian_registry_obj,
        &custodian_admin,
        custodian_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"INACTIVE-CUSTODIAN",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Reserve / Custodian Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::reserve_attestation,
)]
fun test_10_reserve_custodian_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            @0xDEAD,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"CUSTODIAN-MISMATCH",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11
   Suspended Reserve Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::reserve_attestation,
)]
fun test_11_suspended_reserve_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    gold_reserve::suspend_for_testing(
        &mut reserve,
    );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"SUSPENDED-RESERVE",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Zero Attested Weight Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_core::reserve_attestation,
)]
fun test_12_zero_weight_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"ZERO-WEIGHT",
        0,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13
   Weight Above Reserve Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 20,
    location = tobmate_core::reserve_attestation,
)]
fun test_13_excess_weight_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"EXCESS-WEIGHT",
        1000001,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14
   Invalid Expiry Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::reserve_attestation,
)]
fun test_14_invalid_expiry_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"BAD-EXPIRY",
        1000000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 15
   Duplicate Active Attestation Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::reserve_attestation,
)]
fun test_15_duplicate_active_attestation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"ATTESTATION-ONE",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"ATTESTATION-TWO",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 16
   Attestation Revocation
   ============================================================ */

#[test]
fun test_16_attestation_revocation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    let attestation_id =
        reserve_attestation::create_attestation(
            &access,
            &mut attestation_registry,
            &custodian_registry_obj,
            &reserve,
            custodian_id,
            attestor_id,
            b"ATTESTATION-REVOKE",
            1000000,
            10,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    reserve_attestation::revoke_attestation(
        &access,
        &mut attestation_registry,
        &attestation_admin,
        attestation_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        reserve_attestation::attestation_status(
            &attestation_registry,
            attestation_id,
        ) == reserve_attestation::status_revoked(),
        60,
    );

    assert!(
        reserve_attestation::active_attestation_count(
            &attestation_registry,
        ) == 0,
        61,
    );

    assert!(
        reserve_attestation::revoked_attestation_count(
            &attestation_registry,
        ) == 1,
        62,
    );

    reserve_attestation::destroy_admin_cap_for_testing(
        attestation_admin,
    );

    reserve_attestation::destroy_for_testing(
        attestation_registry,
    );

    gold_reserve::destroy_reserve_for_testing(
        reserve,
    );

    custodian_registry::destroy_admin_cap_for_testing(
        custodian_admin,
    );

    custodian_registry::destroy_for_testing(
        custodian_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 17
   Expired Attestation Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::reserve_attestation,
)]
fun test_17_expired_attestation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    let attestation_id =
        reserve_attestation::create_attestation(
            &access,
            &mut attestation_registry,
            &custodian_registry_obj,
            &reserve,
            custodian_id,
            attestor_id,
            b"EXPIRY-TEST",
            1000000,
            10,
            test_scenario::ctx(&mut scenario),
        );

    reserve_attestation::assert_attestation_valid(
        &attestation_registry,
        attestation_id,
        10,
    );

    abort 999
}


/* ============================================================
   Test 18
   Paused Registry Blocks Attestation
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::reserve_attestation,
)]
fun test_18_paused_registry_blocks_attestation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut custodian_registry_obj =
        custodian_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let custodian_admin =
        custodian_registry::admin_cap_for_testing(
            &custodian_registry_obj,
            test_scenario::ctx(&mut scenario),
        );

    let custodian_id =
        custodian_registry::register_custodian(
            &access,
            &mut custodian_registry_obj,
            &custodian_admin,
            b"CUSTODIAN-AU-001",
            CUSTODIAN,
            custodian_registry::custodian_vault(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let reserve =
        gold_reserve::new_reserve_for_testing(
            CUSTODIAN,
            1000000,
            9999,
            test_scenario::ctx(&mut scenario),
        );

    let mut attestation_registry =
        reserve_attestation::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let attestation_admin =
        reserve_attestation::admin_cap_for_testing(
            &attestation_registry,
            test_scenario::ctx(&mut scenario),
        );

    let attestor_id =
        reserve_attestation::register_attestor(
            &access,
            &mut attestation_registry,
            &attestation_admin,
            b"ATTESTOR-001",
            ATTESTOR,
            test_scenario::ctx(&mut scenario),
        );

    reserve_attestation::set_paused(
        &attestation_admin,
        &mut attestation_registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ATTESTOR,
    );

    reserve_attestation::create_attestation(
        &access,
        &mut attestation_registry,
        &custodian_registry_obj,
        &reserve,
        custodian_id,
        attestor_id,
        b"PAUSED-REGISTRY",
        1000000,
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
