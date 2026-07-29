#[test_only]
module tobmate_foundation::institution_registry_tests;

use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::institution_registry::{
    Self as institution_registry,
};


/* ============================================================
   Test Addresses
   ============================================================ */

const ADMIN: address = @0xA11CE;
const BANK: address = @0xB001;
const TRUST: address = @0xB002;
const BROKER: address = @0xB003;


/* ============================================================
   Helpers
   ============================================================ */

fun institution_key(): vector<u8> {
    b"TOBMATE-BANK-001"
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
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        institution_registry::version(
            &registry,
        ) == 1,
        10,
    );

    assert!(
        !institution_registry::is_paused(
            &registry,
        ),
        11,
    );

    assert!(
        institution_registry::total_institutions(
            &registry,
        ) == 0,
        12,
    );

    assert!(
        institution_registry::active_institution_count(
            &registry,
        ) == 0,
        13,
    );

    institution_registry::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 02
   Bank Registration
   ============================================================ */

#[test]
fun test_02_bank_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let institution_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,

            institution_key(),
            BANK,

            institution_registry::institution_bank(),
            jurisdiction(),

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        institution_id == 1,
        20,
    );

    assert!(
        institution_registry::institution_authority(
            &registry,
            institution_id,
        ) == BANK,
        21,
    );

    assert!(
        institution_registry::institution_type(
            &registry,
            institution_id,
        ) == institution_registry::institution_bank(),
        22,
    );

    assert!(
        institution_registry::institution_jurisdiction(
            &registry,
            institution_id,
        ) == jurisdiction(),
        23,
    );

    assert!(
        institution_registry::institution_is_active(
            &registry,
            institution_id,
        ),
        24,
    );

    assert!(
        institution_registry::total_institutions(
            &registry,
        ) == 1,
        25,
    );

    assert!(
        institution_registry::active_institution_count(
            &registry,
        ) == 1,
        26,
    );

    institution_registry::assert_institution_active(
        &registry,
        institution_id,
    );

    institution_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    institution_registry::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 03
   Duplicate Institution Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_foundation::institution_registry,
)]
fun test_03_duplicate_institution_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::register_institution(
        &access,
        &mut registry,
        &admin_cap,
        institution_key(),
        BANK,
        institution_registry::institution_bank(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    institution_registry::register_institution(
        &access,
        &mut registry,
        &admin_cap,
        institution_key(),
        TRUST,
        institution_registry::institution_trust(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04
   Invalid Institution Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_foundation::institution_registry,
)]
fun test_04_invalid_institution_type_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::register_institution(
        &access,
        &mut registry,
        &admin_cap,
        b"INVALID-INSTITUTION",
        BANK,
        99,
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Institution Lifecycle
   ============================================================ */

#[test]
fun test_05_institution_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let institution_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,
            institution_key(),
            BANK,
            institution_registry::institution_bank(),
            jurisdiction(),
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_institution_active(
        &access,
        &mut registry,
        &admin_cap,
        institution_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        !institution_registry::institution_is_active(
            &registry,
            institution_id,
        ),
        50,
    );

    assert!(
        institution_registry::active_institution_count(
            &registry,
        ) == 0,
        51,
    );

    institution_registry::set_institution_active(
        &access,
        &mut registry,
        &admin_cap,
        institution_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institution_registry::institution_is_active(
            &registry,
            institution_id,
        ),
        52,
    );

    assert!(
        institution_registry::active_institution_count(
            &registry,
        ) == 1,
        53,
    );

    institution_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    institution_registry::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 06
   Pause and Version
   ============================================================ */

#[test]
fun test_06_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institution_registry::is_paused(
            &registry,
        ),
        60,
    );

    institution_registry::set_version(
        &admin_cap,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institution_registry::version(
            &registry,
        ) == 2,
        61,
    );

    institution_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    institution_registry::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 07
   Paused Registry Blocks Registration
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_foundation::institution_registry,
)]
fun test_07_paused_registry_blocks_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    institution_registry::register_institution(
        &access,
        &mut registry,
        &admin_cap,
        institution_key(),
        BANK,
        institution_registry::institution_bank(),
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
    abort_code = 9,
    location = tobmate_foundation::institution_registry,
)]
fun test_08_non_increasing_version_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_version(
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
    abort_code = 10,
    location = tobmate_foundation::institution_registry,
)]
fun test_09_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry_a =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_b =
        institution_registry::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::register_institution(
        &access,
        &mut registry_a,
        &admin_b,
        institution_key(),
        BANK,
        institution_registry::institution_bank(),
        jurisdiction(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Inactive Institution Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_foundation::institution_registry,
)]
fun test_10_inactive_institution_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let institution_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,
            institution_key(),
            BANK,
            institution_registry::institution_bank(),
            jurisdiction(),
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_institution_active(
        &access,
        &mut registry,
        &admin_cap,
        institution_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    institution_registry::assert_institution_active(
        &registry,
        institution_id,
    );

    abort 999
}


/* ============================================================
   Test 11
   Duplicate Status Transition Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_foundation::institution_registry,
)]
fun test_11_duplicate_status_transition_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let institution_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,
            institution_key(),
            BANK,
            institution_registry::institution_bank(),
            jurisdiction(),
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_institution_active(
        &access,
        &mut registry,
        &admin_cap,
        institution_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    institution_registry::set_institution_active(
        &access,
        &mut registry,
        &admin_cap,
        institution_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Multi-Institution Accounting Invariant
   ============================================================ */

#[test]
fun test_12_multi_institution_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        institution_registry::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        institution_registry::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let bank_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,
            b"BANK-001",
            BANK,
            institution_registry::institution_bank(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let trust_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,
            b"TRUST-001",
            TRUST,
            institution_registry::institution_trust(),
            b"SG",
            test_scenario::ctx(&mut scenario),
        );

    let broker_id =
        institution_registry::register_institution(
            &access,
            &mut registry,
            &admin_cap,
            b"BROKER-001",
            BROKER,
            institution_registry::institution_broker_dealer(),
            b"US",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        bank_id == 1
            && trust_id == 2
            && broker_id == 3,
        120,
    );

    assert!(
        institution_registry::total_institutions(
            &registry,
        ) == 3,
        121,
    );

    assert!(
        institution_registry::active_institution_count(
            &registry,
        ) == 3,
        122,
    );

    institution_registry::set_institution_active(
        &access,
        &mut registry,
        &admin_cap,
        trust_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        institution_registry::total_institutions(
            &registry,
        ) == 3,
        123,
    );

    assert!(
        institution_registry::active_institution_count(
            &registry,
        ) == 2,
        124,
    );

    institution_registry::assert_institution_active(
        &registry,
        bank_id,
    );

    institution_registry::assert_institution_active(
        &registry,
        broker_id,
    );

    institution_registry::destroy_admin_cap_for_testing(
        admin_cap,
    );

    institution_registry::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}
