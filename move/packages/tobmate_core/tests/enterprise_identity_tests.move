#[test_only]
module tobmate_core::enterprise_identity_tests;

use sui::test_scenario;

use tobmate_core::access_control;
use tobmate_core::enterprise_identity;
use tobmate_core::tmid;


/* ============================================================
   Test Addresses
   ============================================================ */

const ADMIN: address = @0xA11CE;
const USER: address = @0xB0B;
const PROVIDER: address = @0xC0FFEE;
const ATTACKER: address = @0xBAD;


/* ============================================================
   Test Helpers
   ============================================================ */

fun provider_key(): vector<u8> {
    b"provider-au-001"
}

fun jurisdiction(): vector<u8> {
    b"AU"
}

fun credential_hash(): vector<u8> {
    b"credential-hash-001"
}


/* ============================================================
   Test 01
   Registry Initial State
   ============================================================ */

#[test]
fun test_01_initial_state() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let registry =
        enterprise_identity::new_for_testing(ctx);

    assert!(
        enterprise_identity::version(&registry) == 1,
        1,
    );

    assert!(
        !enterprise_identity::is_paused(&registry),
        2,
    );

    assert!(
        enterprise_identity::total_providers(&registry) == 0,
        3,
    );

    assert!(
        enterprise_identity::active_provider_count(&registry) == 0,
        4,
    );

    assert!(
        enterprise_identity::total_credentials(&registry) == 0,
        5,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Provider Registration
   ============================================================ */

#[test]
fun test_02_provider_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    assert!(provider_id == 1, 10);

    assert!(
        enterprise_identity::total_providers(&registry) == 1,
        11,
    );

    assert!(
        enterprise_identity::active_provider_count(&registry) == 1,
        12,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   Provider Suspension / Reactivation
   ============================================================ */

#[test]
fun test_03_provider_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    enterprise_identity::set_provider_active(
        &access,
        &mut registry,
        &admin_cap,
        provider_id,
        false,
        ctx,
    );

    assert!(
        enterprise_identity::active_provider_count(&registry) == 0,
        20,
    );

    enterprise_identity::set_provider_active(
        &access,
        &mut registry,
        &admin_cap,
        provider_id,
        true,
        ctx,
    );

    assert!(
        enterprise_identity::active_provider_count(&registry) == 1,
        21,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Registry Pause / Version
   ============================================================ */

#[test]
fun test_04_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    enterprise_identity::set_paused(
        &admin_cap,
        &mut registry,
        true,
        ctx,
    );

    assert!(
        enterprise_identity::is_paused(&registry),
        30,
    );

    enterprise_identity::set_paused(
        &admin_cap,
        &mut registry,
        false,
        ctx,
    );

    enterprise_identity::set_version(
        &admin_cap,
        &mut registry,
        2,
        ctx,
    );

    assert!(
        enterprise_identity::version(&registry) == 2,
        31,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05
   TMID Controller Creates Credential Request
   ============================================================ */

#[test]
fun test_05_controller_creates_request() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    assert!(
        enterprise_identity::request_status(&request)
            == enterprise_identity::request_pending(),
        40,
    );

    assert!(
        enterprise_identity::request_provider_id(&request)
            == provider_id,
        41,
    );

    assert!(
        enterprise_identity::request_tmid_id(&request)
            == tmid::tmid_id(&tmid_obj),
        42,
    );

    assert!(
        enterprise_identity::request_controller(&request)
            == USER,
        43,
    );

    enterprise_identity::destroy_request_for_testing(
        request,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06
   Non-Controller Cannot Create Request
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::enterprise_identity,
)]
fun test_06_non_controller_request_rejected() {
    let mut scenario =
        test_scenario::begin(ATTACKER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    enterprise_identity::destroy_request_for_testing(
        request,
    );

    abort 999
}


/* ============================================================
   Test 07
   Controller Cancels Pending Request
   ============================================================ */

#[test]
fun test_07_controller_cancels_request() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    enterprise_identity::cancel_credential_request(
        &access,
        &registry,
        &mut request,
        ctx,
    );

    assert!(
        enterprise_identity::request_status(&request)
            == enterprise_identity::request_cancelled(),
        50,
    );

    enterprise_identity::destroy_request_for_testing(
        request,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08
   Non-Controller Cannot Cancel Request
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_core::enterprise_identity,
)]
fun test_08_non_controller_cancel_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTACKER,
    );

    enterprise_identity::cancel_credential_request(
        &access,
        &registry,
        &mut request,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Suspended Provider Cannot Receive New Request
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::enterprise_identity,
)]
fun test_09_suspended_provider_request_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    enterprise_identity::set_provider_active(
        &access,
        &mut registry,
        &admin_cap,
        provider_id,
        false,
        ctx,
    );

    let request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    enterprise_identity::destroy_request_for_testing(
        request,
    );

    abort 999
}


/* ============================================================
   Test 10
   Provider Attestation Succeeds
   ============================================================ */

#[test]
fun test_10_provider_attestation_succeeds() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        PROVIDER,
    );

    let credential_id =
        enterprise_identity::attest_credential_request(
            &access,
            &mut registry,
            &mut request,
            &tmid_obj,
            credential_hash(),
            2,
            enterprise_identity::aml_clear(),
            10,
            test_scenario::ctx(&mut scenario),
        );

    assert!(credential_id == 1, 60);

    assert!(
        enterprise_identity::request_status(&request)
            == enterprise_identity::request_attested(),
        61,
    );

    assert!(
        enterprise_identity::total_credentials(&registry) == 1,
        62,
    );

    assert!(
        enterprise_identity::active_credential_count(&registry) == 1,
        63,
    );

    assert!(
        enterprise_identity::credential_status(
            &registry,
            credential_id,
        ) == enterprise_identity::status_active(),
        64,
    );

    assert!(
        enterprise_identity::credential_tmid_id(
            &registry,
            credential_id,
        ) == tmid::tmid_id(&tmid_obj),
        65,
    );

    enterprise_identity::assert_credential_eligible(
        &registry,
        credential_id,
        1,
    );

    enterprise_identity::destroy_request_for_testing(
        request,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 11
   Unauthorized Provider Cannot Attest
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 22,
    location = tobmate_core::enterprise_identity,
)]
fun test_11_unauthorized_provider_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        ATTACKER,
    );

    enterprise_identity::attest_credential_request(
        &access,
        &mut registry,
        &mut request,
        &tmid_obj,
        credential_hash(),
        2,
        enterprise_identity::aml_clear(),
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12
   Attested Request Cannot Be Replayed
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 25,
    location = tobmate_core::enterprise_identity,
)]
fun test_12_attestation_replay_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        PROVIDER,
    );

    enterprise_identity::attest_credential_request(
        &access,
        &mut registry,
        &mut request,
        &tmid_obj,
        credential_hash(),
        2,
        enterprise_identity::aml_clear(),
        10,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_identity::attest_credential_request(
        &access,
        &mut registry,
        &mut request,
        &tmid_obj,
        b"second-hash",
        2,
        enterprise_identity::aml_clear(),
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13
   Duplicate Active Credential Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::enterprise_identity,
)]
fun test_13_duplicate_active_credential_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request_a =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    let mut request_b =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        PROVIDER,
    );

    enterprise_identity::attest_credential_request(
        &access,
        &mut registry,
        &mut request_a,
        &tmid_obj,
        b"credential-a",
        2,
        enterprise_identity::aml_clear(),
        10,
        test_scenario::ctx(&mut scenario),
    );

    enterprise_identity::attest_credential_request(
        &access,
        &mut registry,
        &mut request_b,
        &tmid_obj,
        b"credential-b",
        2,
        enterprise_identity::aml_clear(),
        10,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14
   Credential Revocation Accounting
   ============================================================ */

#[test]
fun test_14_credential_revocation() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        PROVIDER,
    );

    let credential_id =
        enterprise_identity::attest_credential_request(
            &access,
            &mut registry,
            &mut request,
            &tmid_obj,
            credential_hash(),
            2,
            enterprise_identity::aml_clear(),
            10,
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        ADMIN,
    );

    enterprise_identity::revoke_credential(
        &access,
        &mut registry,
        &admin_cap,
        credential_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        enterprise_identity::credential_status(
            &registry,
            credential_id,
        ) == enterprise_identity::status_revoked(),
        70,
    );

    assert!(
        enterprise_identity::active_credential_count(&registry) == 0,
        71,
    );

    assert!(
        enterprise_identity::revoked_credential_count(&registry) == 1,
        72,
    );

    enterprise_identity::destroy_request_for_testing(
        request,
    );

    enterprise_identity::destroy_admin_cap_for_testing(
        admin_cap,
    );

    enterprise_identity::destroy_for_testing(
        registry,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 15
   AML Blocked Credential Is Not Eligible
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 19,
    location = tobmate_core::enterprise_identity,
)]
fun test_15_aml_blocked_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        PROVIDER,
    );

    let credential_id =
        enterprise_identity::attest_credential_request(
            &access,
            &mut registry,
            &mut request,
            &tmid_obj,
            credential_hash(),
            2,
            enterprise_identity::aml_blocked(),
            10,
            test_scenario::ctx(&mut scenario),
        );

    enterprise_identity::assert_credential_eligible(
        &registry,
        credential_id,
        1,
    );

    abort 999
}


/* ============================================================
   Test 16
   Expired Credential Is Not Eligible
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 18,
    location = tobmate_core::enterprise_identity,
)]
fun test_16_expired_credential_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let ctx =
        test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            ctx,
        );

    let mut registry =
        enterprise_identity::new_for_testing(ctx);

    let admin_cap =
        enterprise_identity::admin_cap_for_testing(
            &registry,
            ctx,
        );

    let provider_id =
        enterprise_identity::register_provider(
            &access,
            &mut registry,
            &admin_cap,
            provider_key(),
            PROVIDER,
            enterprise_identity::provider_full_compliance(),
            jurisdiction(),
            ctx,
        );

    let mut request =
        enterprise_identity::create_credential_request(
            &access,
            &registry,
            &tmid_obj,
            provider_id,
            jurisdiction(),
            ctx,
        );

    test_scenario::next_tx(
        &mut scenario,
        PROVIDER,
    );

    let credential_id =
        enterprise_identity::attest_credential_request(
            &access,
            &mut registry,
            &mut request,
            &tmid_obj,
            credential_hash(),
            2,
            enterprise_identity::aml_clear(),
            10,
            test_scenario::ctx(&mut scenario),
        );

    enterprise_identity::assert_credential_eligible(
        &registry,
        credential_id,
        10,
    );

    abort 999
}
