#[test_only]
module tobmate_integration_tests::gsos_identity_binding_tests;

use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::tmid;

use tobmate_gsos::gsos_identity_binding::{
    Self as binding,
};

const ADMIN: address = @0xAD;
const USER: address = @0xCAFE;
const OTHER: address = @0xBEEF;


/* ============================================================
   Test 01 — Active TMID Binding Succeeds
   ============================================================ */

#[test]
fun test_01_active_tmid_binding_succeeds() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:primary",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        binding_id == 1,
        100,
    );

    assert!(
        binding::binding_count(
            &registry,
        ) == 1,
        101,
    );

    assert!(
        binding::active_binding_count(
            &registry,
        ) == 1,
        102,
    );

    assert!(
        binding::binding_status(
            &registry,
            binding_id,
        ) == binding::status_active(),
        103,
    );

    assert!(
        binding::binding_tmid_id(
            &registry,
            binding_id,
        ) == tmid::tmid_id(&tmid_obj),
        104,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Non-controller Cannot Bind TMID
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_02_non_controller_binding_rejected() {
    let mut scenario =
        test_scenario::begin(OTHER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:unauthorized",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 03 — Suspended TMID Cannot Bind
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_03_suspended_tmid_binding_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        tmid::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    tmid::suspend(
        &admin_cap,
        &access,
        &mut tmid_obj,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:suspended",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04 — Revoked TMID Cannot Bind
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_04_revoked_tmid_binding_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        tmid::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    tmid::revoke(
        &admin_cap,
        &access,
        &mut tmid_obj,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:revoked",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05 — Duplicate Active Identity Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_05_duplicate_active_identity_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_a =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let tmid_b =
        tmid::new_for_testing(
            USER,
            2,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_a,
        binding::identity_user(),
        b"user:duplicate",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_b,
        binding::identity_user(),
        b"user:duplicate",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06 — Empty Identity Key Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_06_empty_identity_key_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Empty GSAP Reference Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 4,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_07_empty_gsap_reference_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:no-gsap",
        b"",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Revoke Lifecycle Preserves Accounting
   ============================================================ */

#[test]
fun test_08_revoke_lifecycle_preserves_accounting() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        binding::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:revoke",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    binding::revoke_binding(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        binding::binding_status(
            &registry,
            binding_id,
        ) == binding::status_revoked(),
        800,
    );

    assert!(
        binding::total_created(
            &registry,
        ) == 1,
        801,
    );

    assert!(
        binding::total_revoked(
            &registry,
        ) == 1,
        802,
    );

    assert!(
        binding::active_binding_count(
            &registry,
        ) == 0,
        803,
    );

    binding::destroy_admin_cap_for_testing(
        admin_cap,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 09 — Global Pause Blocks Binding
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_foundation::access_control,
)]
fun test_09_global_pause_blocks_binding() {
    let mut scenario =
        test_scenario::begin(USER);

    let mut access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let access_cap =
        access_control::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    access_control::set_paused(
        &access_cap,
        &mut access,
        true,
        test_scenario::ctx(&mut scenario),
    );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:global-paused",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Local Registry Pause Blocks Binding
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_10_local_pause_blocks_binding() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        binding::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    binding::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:local-paused",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Duplicate Revoke Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_11_duplicate_revoke_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        binding::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:double-revoke",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    binding::revoke_binding(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        test_scenario::ctx(&mut scenario),
    );

    binding::revoke_binding(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Wrong Admin Cap Rejected
   ============================================================ */

#[test]
#[expected_failure]
fun test_12_wrong_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry_a =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let wrong_cap =
        binding::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry_a,
            &tmid_obj,
            binding::identity_user(),
            b"user:wrong-admin",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    binding::revoke_binding(
        &access,
        &mut registry_a,
        &wrong_cap,
        binding_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Revoked Identity Can Be Rebound
   ============================================================ */

#[test]
fun test_13_revoked_identity_can_be_rebound() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        binding::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let first_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:rebind",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    binding::revoke_binding(
        &access,
        &mut registry,
        &admin_cap,
        first_id,
        test_scenario::ctx(&mut scenario),
    );

    let second_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:rebind",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        second_id == 2,
        1300,
    );

    assert!(
        binding::binding_status(
            &registry,
            first_id,
        ) == binding::status_revoked(),
        1301,
    );

    assert!(
        binding::binding_status(
            &registry,
            second_id,
        ) == binding::status_active(),
        1302,
    );

    assert!(
        binding::total_created(
            &registry,
        ) == 2,
        1303,
    );

    assert!(
        binding::total_revoked(
            &registry,
        ) == 1,
        1304,
    );

    assert!(
        binding::active_binding_count(
            &registry,
        ) == 1,
        1305,
    );

    binding::destroy_admin_cap_for_testing(
        admin_cap,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 14 — Old Controller Cannot Bind After Controller Change
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_14_old_controller_rejected_after_controller_change() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        tmid::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    tmid::change_controller(
        &admin_cap,
        &access,
        &mut tmid_obj,
        OTHER,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:stale-controller",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Stage 11 Part 1-E
   Identity Type / Final Hardening
   ============================================================ */


/* Test 15 — Invalid Identity Type Rejected */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_15_invalid_identity_type_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        99,
        b"invalid:type",
        b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 16 — Agent Identity Binding Succeeds
   ============================================================ */

#[test]
fun test_16_agent_identity_binding_succeeds() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_agent(),
            b"agent:tobmate-ai-001",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        binding::binding_identity_type(
            &registry,
            binding_id,
        ) == binding::identity_agent(),
        1600,
    );

    assert!(
        binding::binding_status(
            &registry,
            binding_id,
        ) == binding::status_active(),
        1601,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 17 — Avatar Identity Binding Succeeds
   ============================================================ */

#[test]
fun test_17_avatar_identity_binding_succeeds() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_avatar(),
            b"avatar:gsos-001",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        binding::binding_identity_type(
            &registry,
            binding_id,
        ) == binding::identity_avatar(),
        1700,
    );

    assert!(
        binding::binding_tmid_controller(
            &registry,
            binding_id,
        ) == USER,
        1701,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 18 — Identity Types Remain Isolated Per TMID
   ============================================================ */

#[test]
fun test_18_identity_types_remain_isolated_per_tmid() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let user_binding =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"shared-key",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    let agent_binding =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_agent(),
            b"shared-key",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    let avatar_binding =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_avatar(),
            b"shared-key",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        user_binding == 1,
        1800,
    );

    assert!(
        agent_binding == 2,
        1801,
    );

    assert!(
        avatar_binding == 3,
        1802,
    );

    assert!(
        binding::active_binding_count(
            &registry,
        ) == 3,
        1803,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 19 — Local Unpause Restores Binding
   ============================================================ */

#[test]
fun test_19_local_unpause_restores_binding() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        binding::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    binding::set_paused(
        &admin_cap,
        &mut registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    binding::set_paused(
        &admin_cap,
        &mut registry,
        false,
        test_scenario::ctx(&mut scenario),
    );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:after-unpause",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        binding_id == 1,
        1900,
    );

    assert!(
        binding::binding_status(
            &registry,
            binding_id,
        ) == binding::status_active(),
        1901,
    );

    binding::destroy_admin_cap_for_testing(
        admin_cap,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 20 — Multi-binding Accounting Invariant
   ============================================================ */

#[test]
fun test_20_multi_binding_accounting_invariant() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let admin_cap =
        binding::admin_cap_for_testing(
            &registry,
            test_scenario::ctx(&mut scenario),
        );

    let user_binding =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:20",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    let agent_binding =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_agent(),
            b"agent:20",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    let avatar_binding =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_avatar(),
            b"avatar:20",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    binding::revoke_binding(
        &access,
        &mut registry,
        &admin_cap,
        agent_binding,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        binding::binding_count(
            &registry,
        ) == 3,
        2000,
    );

    assert!(
        binding::total_created(
            &registry,
        ) == 3,
        2001,
    );

    assert!(
        binding::total_revoked(
            &registry,
        ) == 1,
        2002,
    );

    assert!(
        binding::active_binding_count(
            &registry,
        ) == 2,
        2003,
    );

    assert!(
        binding::binding_status(
            &registry,
            user_binding,
        ) == binding::status_active(),
        2004,
    );

    assert!(
        binding::binding_status(
            &registry,
            agent_binding,
        ) == binding::status_revoked(),
        2005,
    );

    assert!(
        binding::binding_status(
            &registry,
            avatar_binding,
        ) == binding::status_active(),
        2006,
    );

    binding::destroy_admin_cap_for_testing(
        admin_cap,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Stage 11 Phone Verification Security
   ============================================================ */


/* Test 21 — Unverified TMID Cannot Create GSOS Identity */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_21_unverified_tmid_binding_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_unverified_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:unverified-phone",
        b"gsap://earth/au/qld/bundaberg/phone-test-21",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* Test 22 — Phone Verification Enables GSOS Identity */

#[test]
fun test_22_phone_verification_enables_binding() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_admin =
        tmid::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut tmid_obj =
        tmid::new_unverified_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        !tmid::is_phone_verified(
            &tmid_obj,
        ),
        2200,
    );

    tmid::set_phone_verified(
        &tmid_admin,
        &access,
        &mut tmid_obj,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        tmid::is_phone_verified(
            &tmid_obj,
        ),
        2201,
    );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        binding::create_binding(
            &access,
            &mut registry,
            &tmid_obj,
            binding::identity_user(),
            b"user:phone-verified",
            b"gsap://earth/au/qld/bundaberg/phone-test-22",
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        binding::binding_status(
            &registry,
            binding_id,
        ) == binding::status_active(),
        2202,
    );

    tmid::destroy_admin_cap_for_testing(
        tmid_admin,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    binding::destroy_for_testing(
        registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* Test 23 — Verification Removal Blocks New Identity */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_gsos::gsos_identity_binding,
)]
fun test_23_verification_removal_blocks_new_binding() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_admin =
        tmid::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        tmid::is_phone_verified(
            &tmid_obj,
        ),
        2300,
    );

    tmid::set_phone_verified(
        &tmid_admin,
        &access,
        &mut tmid_obj,
        false,
        test_scenario::ctx(&mut scenario),
    );

    let mut registry =
        binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    binding::create_binding(
        &access,
        &mut registry,
        &tmid_obj,
        binding::identity_user(),
        b"user:verification-removed",
        b"gsap://earth/au/qld/bundaberg/phone-test-23",
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
