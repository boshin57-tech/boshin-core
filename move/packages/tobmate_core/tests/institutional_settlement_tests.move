#[test_only]
module tobmate_core::institutional_settlement_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::institution_registry::{
    Self as institution_registry,
};

use tobmate_core::institutional_settlement::{
    Self as settlement,
};


/* ============================================================
   Addresses
   ============================================================ */

const ADMIN: address = @0xA11CE;
const BANK: address = @0xB001;
const OTHER_BANK: address = @0xB002;
const BENEFICIARY: address = @0xC001;


/* ============================================================
   Helpers
   ============================================================ */

fun setup_institution(
    scenario: &mut test_scenario::Scenario,
): (
    access_control::AccessControl,
    institution_registry::InstitutionRegistry,
    institution_registry::InstitutionAdminCap,
    u64,
) {
    let access =
        access_control::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let mut institution_registry_obj =
        institution_registry::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let institution_admin =
        institution_registry::admin_cap_for_testing(
            &institution_registry_obj,
            test_scenario::ctx(scenario),
        );

    let institution_id =
        institution_registry::register_institution(
            &access,
            &mut institution_registry_obj,
            &institution_admin,

            b"BANK-001",
            BANK,

            institution_registry::institution_bank(),
            b"AU",

            test_scenario::ctx(scenario),
        );

    (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    )
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
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        settlement::version(&registry) == 1,
        10,
    );

    assert!(
        !settlement::is_paused(&registry),
        11,
    );

    assert!(
        settlement::total_settlements(&registry) == 0,
        12,
    );

    assert!(
        settlement::pending_count(&registry) == 0,
        13,
    );

    assert!(
        settlement::confirmed_count(&registry) == 0,
        14,
    );

    assert!(
        settlement::finalized_count(&registry) == 0,
        15,
    );

    assert!(
        settlement::cancelled_count(&registry) == 0,
        16,
    );

    settlement::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 02
   Settlement Creation
   ============================================================ */

#[test]
fun test_02_settlement_creation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,

            &institution_registry_obj,

            institution_id,
            settlement::settlement_fiat_deposit(),

            b"AUD",
            100000,

            BENEFICIARY,
            b"BANK-REF-001",

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        settlement_id == 1,
        20,
    );

    assert!(
        settlement::settlement_status(
            &registry,
            settlement_id,
        ) == settlement::status_pending(),
        21,
    );

    assert!(
        settlement::settlement_institution_id(
            &registry,
            settlement_id,
        ) == institution_id,
        22,
    );

    assert!(
        settlement::settlement_amount(
            &registry,
            settlement_id,
        ) == 100000,
        23,
    );

    assert!(
        settlement::total_settlements(
            &registry,
        ) == 1,
        24,
    );

    assert!(
        settlement::pending_count(
            &registry,
        ) == 1,
        25,
    );

    settlement::destroy_for_testing(
        registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
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
   Duplicate External Reference Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::institutional_settlement,
)]
fun test_03_duplicate_external_reference_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    settlement::create_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        institution_id,
        settlement::settlement_fiat_deposit(),
        b"AUD",
        100000,
        BENEFICIARY,
        b"DUPLICATE-REF",
        test_scenario::ctx(&mut scenario),
    );

    settlement::create_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        institution_id,
        settlement::settlement_fiat_deposit(),
        b"AUD",
        200000,
        BENEFICIARY,
        b"DUPLICATE-REF",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04
   Zero Amount Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_core::institutional_settlement,
)]
fun test_04_zero_amount_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    settlement::create_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        institution_id,
        settlement::settlement_fiat_deposit(),
        b"AUD",
        0,
        BENEFICIARY,
        b"ZERO-AMOUNT",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05
   Invalid Settlement Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::institutional_settlement,
)]
fun test_05_invalid_settlement_type_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    settlement::create_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        institution_id,
        99,
        b"AUD",
        100000,
        BENEFICIARY,
        b"INVALID-TYPE",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06
   Authorized Institution Confirmation
   ============================================================ */

#[test]
fun test_06_authorized_confirmation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_admin =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"CONFIRM-001",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        BANK,
    );

    settlement::confirm_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        settlement_id,
        institution_id,
        b"BANK-CONFIRM-HASH-001",
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::settlement_status(
            &registry,
            settlement_id,
        ) == settlement::status_confirmed(),
        60,
    );

    assert!(
        settlement::pending_count(
            &registry,
        ) == 0,
        61,
    );

    assert!(
        settlement::confirmed_count(
            &registry,
        ) == 1,
        62,
    );

    settlement::destroy_admin_cap_for_testing(
        settlement_admin,
    );

    settlement::destroy_for_testing(
        registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 07
   Unauthorized Confirmer Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::institutional_settlement,
)]
fun test_07_unauthorized_confirmer_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"CONFIRM-002",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        OTHER_BANK,
    );

    settlement::confirm_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        settlement_id,
        institution_id,
        b"UNAUTHORIZED-CONFIRM",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08
   Institution Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::institutional_settlement,
)]
fun test_08_institution_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        mut institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let second_institution_id =
        institution_registry::register_institution(
            &access,
            &mut institution_registry_obj,
            &institution_admin,
            b"BANK-002",
            OTHER_BANK,
            institution_registry::institution_bank(),
            b"AU",
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"CONFIRM-003",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        OTHER_BANK,
    );

    settlement::confirm_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        settlement_id,
        second_institution_id,
        b"MISMATCH-CONFIRM",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Inactive Institution Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::institution_registry,
)]
fun test_09_inactive_institution_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        mut institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"CONFIRM-004",
            test_scenario::ctx(&mut scenario),
        );

    institution_registry::set_institution_active(
        &access,
        &mut institution_registry_obj,
        &institution_admin,
        institution_id,
        false,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        BANK,
    );

    settlement::confirm_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        settlement_id,
        institution_id,
        b"INACTIVE-INSTITUTION",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10
   Finalize Before Confirmation Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_core::institutional_settlement,
)]
fun test_10_finalize_before_confirmation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"FINALIZE-BEFORE-CONFIRM",
            test_scenario::ctx(&mut scenario),
        );

    settlement::finalize_settlement(
        &access,
        &mut registry,
        &admin_cap,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11
   Successful Finalization
   ============================================================ */

#[test]
fun test_11_successful_finalization() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100000,
            BENEFICIARY,
            b"FINALIZE-001",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        BANK,
    );

    settlement::confirm_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        settlement_id,
        institution_id,
        b"FINALIZE-CONFIRM",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    settlement::finalize_settlement(
        &access,
        &mut registry,
        &admin_cap,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::settlement_status(
            &registry,
            settlement_id,
        ) == settlement::status_finalized(),
        110,
    );

    assert!(
        settlement::confirmed_count(&registry) == 0,
        111,
    );

    assert!(
        settlement::finalized_count(&registry) == 1,
        112,
    );

    settlement::destroy_admin_cap_for_testing(
        admin_cap,
    );

    settlement::destroy_for_testing(
        registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 12
   Cancel Pending Settlement
   ============================================================ */

#[test]
fun test_12_cancel_pending() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_withdrawal(),
            b"AUD",
            50000,
            BENEFICIARY,
            b"CANCEL-PENDING",
            test_scenario::ctx(&mut scenario),
        );

    settlement::cancel_settlement(
        &access,
        &mut registry,
        &admin_cap,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::settlement_status(
            &registry,
            settlement_id,
        ) == settlement::status_cancelled(),
        120,
    );

    assert!(
        settlement::pending_count(&registry) == 0,
        121,
    );

    assert!(
        settlement::cancelled_count(&registry) == 1,
        122,
    );

    settlement::destroy_admin_cap_for_testing(
        admin_cap,
    );

    settlement::destroy_for_testing(
        registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 13
   Cancel Confirmed Settlement
   ============================================================ */

#[test]
fun test_13_cancel_confirmed() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_asset_purchase(),
            b"GOLD",
            25000,
            BENEFICIARY,
            b"CANCEL-CONFIRMED",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        BANK,
    );

    settlement::confirm_settlement(
        &access,
        &mut registry,
        &institution_registry_obj,
        settlement_id,
        institution_id,
        b"CANCEL-CONFIRM-HASH",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    settlement::cancel_settlement(
        &access,
        &mut registry,
        &admin_cap,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::settlement_status(
            &registry,
            settlement_id,
        ) == settlement::status_cancelled(),
        130,
    );

    assert!(
        settlement::confirmed_count(&registry) == 0,
        131,
    );

    assert!(
        settlement::cancelled_count(&registry) == 1,
        132,
    );

    settlement::destroy_admin_cap_for_testing(
        admin_cap,
    );

    settlement::destroy_for_testing(
        registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 14
   Terminal Replay Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::institutional_settlement,
)]
fun test_14_terminal_replay_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        _institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let settlement_id =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_asset_redemption(),
            b"GOLD",
            25000,
            BENEFICIARY,
            b"TERMINAL-REPLAY",
            test_scenario::ctx(&mut scenario),
        );

    settlement::cancel_settlement(
        &access,
        &mut registry,
        &admin_cap,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    settlement::cancel_settlement(
        &access,
        &mut registry,
        &admin_cap,
        settlement_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 15
   Pause / Version
   ============================================================ */

#[test]
fun test_15_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    settlement::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::is_paused(&registry),
        150,
    );

    settlement::set_version(
        &admin_cap,
        &mut registry,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::version(&registry) == 2,
        151,
    );

    settlement::destroy_admin_cap_for_testing(
        admin_cap,
    );

    settlement::destroy_for_testing(
        registry,
    );

    test_scenario::end(
        scenario,
    );
}


/* ============================================================
   Test 16
   Multi-Settlement Accounting Invariant
   ============================================================ */

#[test]
fun test_16_multi_settlement_accounting() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let (
        access,
        institution_registry_obj,
        institution_admin,
        institution_id,
    ) =
        setup_institution(
            &mut scenario,
        );

    let mut registry =
        settlement::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        settlement::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let s1 =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_deposit(),
            b"AUD",
            100,
            BENEFICIARY,
            b"MULTI-001",
            test_scenario::ctx(&mut scenario),
        );

    let s2 =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_fiat_withdrawal(),
            b"AUD",
            200,
            BENEFICIARY,
            b"MULTI-002",
            test_scenario::ctx(&mut scenario),
        );

    let s3 =
        settlement::create_settlement(
            &access,
            &mut registry,
            &institution_registry_obj,
            institution_id,
            settlement::settlement_institution_transfer(),
            b"AUD",
            300,
            BENEFICIARY,
            b"MULTI-003",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        settlement::total_settlements(&registry) == 3,
        160,
    );

    assert!(
        settlement::pending_count(&registry) == 3,
        161,
    );

    settlement::cancel_settlement(
        &access,
        &mut registry,
        &admin_cap,
        s2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        settlement::pending_count(&registry) == 2,
        162,
    );

    assert!(
        settlement::cancelled_count(&registry) == 1,
        163,
    );

    assert!(
        settlement::settlement_status(
            &registry,
            s1,
        ) == settlement::status_pending(),
        164,
    );

    assert!(
        settlement::settlement_status(
            &registry,
            s3,
        ) == settlement::status_pending(),
        165,
    );

    settlement::destroy_admin_cap_for_testing(
        admin_cap,
    );

    settlement::destroy_for_testing(
        registry,
    );

    institution_registry::destroy_admin_cap_for_testing(
        institution_admin,
    );

    institution_registry::destroy_for_testing(
        institution_registry_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(
        scenario,
    );
}
