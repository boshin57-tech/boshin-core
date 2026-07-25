#[test_only]
module tobmate_core::gsap_spatial_registry_tests;

use sui::test_scenario;

use tobmate_core::access_control::{
    Self as access_control,
};

use tobmate_core::tmid;

use tobmate_core::gsos_identity_binding::{
    Self as identity_binding,
};

use tobmate_core::gsap_spatial_registry::{
    Self as spatial,
};

const USER: address = @0xCAFE;
const OTHER: address = @0xBEEF;


/* ============================================================
   Test 01 — Active Identity Can Register World
   ============================================================ */

#[test]
fun test_01_active_identity_can_register_world() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:world-owner",
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let space_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/tobmate-main-world",
            b"earth/au/qld/bundaberg",
            b"tobmate-main-world",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        space_id == 1,
        100,
    );

    assert!(
        spatial::space_status(
            &spatial_registry,
            space_id,
        ) == spatial::status_active(),
        101,
    );

    assert!(
        spatial::space_controller_binding_id(
            &spatial_registry,
            space_id,
        ) == identity_id,
        102,
    );

    assert!(
        spatial::active_space_count(
            &spatial_registry,
        ) == 1,
        103,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    identity_binding::destroy_for_testing(
        identity_registry,
    );

    spatial::destroy_for_testing(
        spatial_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Non-controller Cannot Register Space
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_02_non_controller_space_registration_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Binding must be created by its real controller first.
     */
    test_scenario::next_tx(
        &mut scenario,
        USER,
    );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:space-owner",
            b"gsap://earth/au/qld/bundaberg/world-02",
            test_scenario::ctx(&mut scenario),
        );

    test_scenario::next_tx(
        &mut scenario,
        OTHER,
    );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-02",
        b"earth/au/qld/bundaberg",
        b"world-02",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 03 — Inactive Identity Binding Cannot Register Space
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_03_inactive_identity_binding_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_admin =
        identity_binding::admin_cap_for_testing(
            &identity_registry,
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:inactive-binding",
            b"gsap://earth/au/qld/bundaberg/world-03",
            test_scenario::ctx(&mut scenario),
        );

    identity_binding::revoke_binding(
        &access,
        &mut identity_registry,
        &identity_admin,
        identity_id,
        test_scenario::ctx(&mut scenario),
    );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-03",
        b"earth/au/qld/bundaberg",
        b"world-03",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 04 — Duplicate Active GSAP Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_04_duplicate_active_gsap_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:duplicate-space",
            b"gsap://earth/au/qld/bundaberg/world-04",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-04",
        b"earth/au/qld/bundaberg",
        b"world-04",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-04",
        b"earth/au/qld/bundaberg",
        b"world-04-duplicate",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 05 — Empty GSAP Address Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 2,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_05_empty_gsap_address_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:empty-gsap",
            b"gsap://earth/au/qld/bundaberg/world-05",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"",
        b"earth/au/qld/bundaberg",
        b"world-05",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 06 — Invalid Space Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_06_invalid_space_type_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:invalid-space-type",
            b"gsap://earth/au/qld/bundaberg/world-06",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-06",
        b"earth/au/qld/bundaberg",
        b"world-06",
        99,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Deactivate Lifecycle Preserves Accounting
   ============================================================ */

#[test]
fun test_07_deactivate_lifecycle_preserves_accounting() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:deactivate-space",
            b"gsap://earth/au/qld/bundaberg/world-07",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    let space_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-07",
            b"earth/au/qld/bundaberg",
            b"world-07",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        space_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        spatial::space_status(
            &spatial_registry,
            space_id,
        ) == spatial::status_inactive(),
        700,
    );

    assert!(
        spatial::total_registered(
            &spatial_registry,
        ) == 1,
        701,
    );

    assert!(
        spatial::total_deactivated(
            &spatial_registry,
        ) == 1,
        702,
    );

    assert!(
        spatial::active_space_count(
            &spatial_registry,
        ) == 0,
        703,
    );

    spatial::destroy_admin_cap_for_testing(
        spatial_admin,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    identity_binding::destroy_for_testing(
        identity_registry,
    );

    spatial::destroy_for_testing(
        spatial_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08 — Inactive GSAP Address Can Be Registered Again
   ============================================================ */

#[test]
fun test_08_inactive_gsap_can_be_registered_again() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:gsap-reuse",
            b"gsap://earth/au/qld/bundaberg/world-08",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    let first_space =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-08",
            b"earth/au/qld/bundaberg",
            b"world-08",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        first_space,
        test_scenario::ctx(&mut scenario),
    );

    let second_space =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-08",
            b"earth/au/qld/bundaberg",
            b"world-08-rebound",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        second_space == 2,
        800,
    );

    assert!(
        spatial::space_status(
            &spatial_registry,
            first_space,
        ) == spatial::status_inactive(),
        801,
    );

    assert!(
        spatial::space_status(
            &spatial_registry,
            second_space,
        ) == spatial::status_active(),
        802,
    );

    assert!(
        spatial::total_registered(
            &spatial_registry,
        ) == 2,
        803,
    );

    assert!(
        spatial::total_deactivated(
            &spatial_registry,
        ) == 1,
        804,
    );

    assert!(
        spatial::active_space_count(
            &spatial_registry,
        ) == 1,
        805,
    );

    spatial::destroy_admin_cap_for_testing(
        spatial_admin,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    identity_binding::destroy_for_testing(
        identity_registry,
    );

    spatial::destroy_for_testing(
        spatial_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 09 — Region Can Be Registered Under World
   ============================================================ */

#[test]
fun test_09_region_under_world_succeeds() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:hierarchy-09",
            b"gsap://earth/au/qld/bundaberg/hierarchy-09",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-09",
            b"earth/au/qld/bundaberg",
            b"world-09",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    let region_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-09/region-1",
            b"earth/au/qld/bundaberg",
            b"world-09",
            spatial::space_region(),
            world_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        spatial::space_parent_id(
            &spatial_registry,
            region_id,
        ) == world_id,
        900,
    );

    assert!(
        spatial::space_type(
            &spatial_registry,
            region_id,
        ) == spatial::space_region(),
        901,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 10 — Room Can Be Registered Under Region
   ============================================================ */

#[test]
fun test_10_room_under_region_succeeds() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:hierarchy-10",
            b"gsap://earth/au/qld/bundaberg/hierarchy-10",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-10",
            b"earth/au/qld/bundaberg",
            b"world-10",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    let region_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-10/region-1",
            b"earth/au/qld/bundaberg",
            b"world-10",
            spatial::space_region(),
            world_id,
            test_scenario::ctx(&mut scenario),
        );

    let room_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-10/region-1/room-1",
            b"earth/au/qld/bundaberg",
            b"world-10",
            spatial::space_room(),
            region_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        spatial::space_parent_id(
            &spatial_registry,
            room_id,
        ) == region_id,
        1000,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 11 — Non-root Space Requires Parent
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_11_non_root_without_parent_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:no-parent-11",
            b"gsap://earth/au/qld/bundaberg/no-parent-11",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/orphan-room-11",
        b"earth/au/qld/bundaberg",
        b"orphan-11",
        spatial::space_room(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Inactive Parent Rejects New Child
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_12_inactive_parent_rejects_child() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:inactive-parent-12",
            b"gsap://earth/au/qld/bundaberg/inactive-parent-12",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-12",
            b"earth/au/qld/bundaberg",
            b"world-12",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        world_id,
        test_scenario::ctx(&mut scenario),
    );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-12/region-1",
        b"earth/au/qld/bundaberg",
        b"world-12",
        spatial::space_region(),
        world_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Parent Cannot Deactivate With Active Child
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_13_parent_with_active_child_cannot_deactivate() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:child-guard-13",
            b"gsap://earth/au/qld/bundaberg/child-guard-13",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-13",
            b"earth/au/qld/bundaberg",
            b"world-13",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-13/region-1",
        b"earth/au/qld/bundaberg",
        b"world-13",
        spatial::space_region(),
        world_id,
        test_scenario::ctx(&mut scenario),
    );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        world_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14 — Child Then Parent Deactivation Succeeds
   ============================================================ */

#[test]
fun test_14_child_then_parent_deactivation_succeeds() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:child-guard-14",
            b"gsap://earth/au/qld/bundaberg/child-guard-14",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-14",
            b"earth/au/qld/bundaberg",
            b"world-14",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    let region_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-14/region-1",
            b"earth/au/qld/bundaberg",
            b"world-14",
            spatial::space_region(),
            world_id,
            test_scenario::ctx(&mut scenario),
        );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        region_id,
        test_scenario::ctx(&mut scenario),
    );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        world_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        spatial::space_status(
            &spatial_registry,
            region_id,
        ) == spatial::status_inactive(),
        1400,
    );

    assert!(
        spatial::space_status(
            &spatial_registry,
            world_id,
        ) == spatial::status_inactive(),
        1401,
    );

    assert!(
        spatial::total_deactivated(
            &spatial_registry,
        ) == 2,
        1402,
    );

    assert!(
        spatial::active_space_count(
            &spatial_registry,
        ) == 0,
        1403,
    );

    spatial::destroy_admin_cap_for_testing(
        spatial_admin,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    identity_binding::destroy_for_testing(
        identity_registry,
    );

    spatial::destroy_for_testing(
        spatial_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}


/* ============================================================
   Test 15 — Cell Can Be Registered Under Room
   ============================================================ */

#[test]
fun test_15_cell_under_room_succeeds() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:cell-15",
            b"gsap://earth/au/qld/bundaberg/cell-15",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-15",
            b"earth/au/qld/bundaberg",
            b"world-15",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    let region_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-15/region-1",
            b"earth/au/qld/bundaberg",
            b"world-15",
            spatial::space_region(),
            world_id,
            test_scenario::ctx(&mut scenario),
        );

    let room_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-15/region-1/room-1",
            b"earth/au/qld/bundaberg",
            b"world-15",
            spatial::space_room(),
            region_id,
            test_scenario::ctx(&mut scenario),
        );

    let cell_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-15/region-1/room-1/cell-a1",
            b"earth/au/qld/bundaberg",
            b"world-15",
            spatial::space_cell(),
            room_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        spatial::space_parent_id(
            &spatial_registry,
            cell_id,
        ) == room_id,
        1500,
    );

    assert!(
        spatial::space_type(
            &spatial_registry,
            cell_id,
        ) == spatial::space_cell(),
        1501,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 16 — Invalid Parent Type Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_16_invalid_parent_type_rejected() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:invalid-parent-16",
            b"gsap://earth/au/qld/bundaberg/invalid-parent-16",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-16",
            b"earth/au/qld/bundaberg",
            b"world-16",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    let region_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-16/region-1",
            b"earth/au/qld/bundaberg",
            b"world-16",
            spatial::space_region(),
            world_id,
            test_scenario::ctx(&mut scenario),
        );

    let room_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-16/region-1/room-1",
            b"earth/au/qld/bundaberg",
            b"world-16",
            spatial::space_room(),
            region_id,
            test_scenario::ctx(&mut scenario),
        );

    /*
     * REGION cannot be created under ROOM.
     */
    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-16/invalid-region",
        b"earth/au/qld/bundaberg",
        b"world-16",
        spatial::space_region(),
        room_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 17 — Global Pause Blocks Spatial Registration
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::access_control,
)]
fun test_17_global_pause_blocks_spatial_registration() {
    let mut scenario =
        test_scenario::begin(USER);

    let mut access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let access_admin =
        access_control::admin_cap_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let tmid_obj =
        tmid::new_for_testing(
            USER,
            1,
            test_scenario::ctx(&mut scenario),
        );

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:global-pause-17",
            b"gsap://earth/au/qld/bundaberg/global-pause-17",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    access_control::set_paused(
        &access_admin,
        &mut access,
        true,
        test_scenario::ctx(&mut scenario),
    );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-17",
        b"earth/au/qld/bundaberg",
        b"world-17",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 18 — Local Spatial Pause Blocks Registration
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_18_local_pause_blocks_spatial_registration() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:local-pause-18",
            b"gsap://earth/au/qld/bundaberg/local-pause-18",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    spatial::set_paused(
        &spatial_admin,
        &mut spatial_registry,
        true,
        test_scenario::ctx(&mut scenario),
    );

    spatial::register_space(
        &access,
        &mut spatial_registry,
        &identity_registry,
        identity_id,
        b"gsap://earth/au/qld/bundaberg/world-18",
        b"earth/au/qld/bundaberg",
        b"world-18",
        spatial::space_world(),
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 19 — Wrong Spatial Admin Cap Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_core::gsap_spatial_registry,
)]
fun test_19_wrong_spatial_admin_cap_rejected() {
    let mut scenario =
        test_scenario::begin(USER);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut registry_a =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let registry_b =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let wrong_cap =
        spatial::admin_cap_for_testing(
            &registry_b,
            test_scenario::ctx(&mut scenario),
        );

    spatial::set_paused(
        &wrong_cap,
        &mut registry_a,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 20 — Multi-Space Accounting Invariant
   ============================================================ */

#[test]
fun test_20_multi_space_accounting_invariant() {
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

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            &access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:accounting-20",
            b"gsap://earth/au/qld/bundaberg/accounting-20",
            test_scenario::ctx(&mut scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let spatial_admin =
        spatial::admin_cap_for_testing(
            &spatial_registry,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-20",
            b"earth/au/qld/bundaberg",
            b"world-20",
            spatial::space_world(),
            0,
            test_scenario::ctx(&mut scenario),
        );

    let region_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-20/region-1",
            b"earth/au/qld/bundaberg",
            b"world-20",
            spatial::space_region(),
            world_id,
            test_scenario::ctx(&mut scenario),
        );

    let room_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/world-20/region-1/room-1",
            b"earth/au/qld/bundaberg",
            b"world-20",
            spatial::space_room(),
            region_id,
            test_scenario::ctx(&mut scenario),
        );

    spatial::deactivate_space(
        &access,
        &mut spatial_registry,
        &spatial_admin,
        room_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        spatial::space_count(
            &spatial_registry,
        ) == 3,
        2000,
    );

    assert!(
        spatial::total_registered(
            &spatial_registry,
        ) == 3,
        2001,
    );

    assert!(
        spatial::total_deactivated(
            &spatial_registry,
        ) == 1,
        2002,
    );

    assert!(
        spatial::active_space_count(
            &spatial_registry,
        ) == 2,
        2003,
    );

    spatial::destroy_admin_cap_for_testing(
        spatial_admin,
    );

    tmid::destroy_for_testing(
        tmid_obj,
    );

    identity_binding::destroy_for_testing(
        identity_registry,
    );

    spatial::destroy_for_testing(
        spatial_registry,
    );

    access_control::destroy_for_testing(
        access,
    );

    test_scenario::end(scenario);
}
