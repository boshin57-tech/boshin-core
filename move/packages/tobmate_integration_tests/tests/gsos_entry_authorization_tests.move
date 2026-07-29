#[test_only]
module tobmate_integration_tests::gsos_entry_authorization_tests;

use sui::test_scenario;

use tobmate_foundation::access_control::{
    Self as access_control,
};

use tobmate_foundation::tmid;

use tobmate_gsos::gsos_identity_binding::{
    Self as identity_binding,
};

use tobmate_gsos::gsap_spatial_registry::{
    Self as spatial,
};

use tobmate_gsos::gsos_protocol_registry::{
    Self as protocol_registry,
};

use tobmate_gsos::gsos_world_space_registry::{
    Self as world_space,
};

use tobmate_gsos::gsos_entry_authorization::{
    Self as entry_auth,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Integrated Fixture
   ============================================================ */

fun setup_control_plane(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
): (
    tmid::TMID,
    identity_binding::GSOSIdentityRegistry,
    spatial::GSAPSpatialRegistry,
    protocol_registry::GSOSProtocolRegistry,
    protocol_registry::GSOSProtocolAdminCap,
    world_space::GSOSWorldSpaceRegistry,
    world_space::GSOSWorldSpaceAdminCap,
    u64,
    u64,
    u64,
) {
    let ctx = test_scenario::ctx(scenario);

    let tmid_obj =
        tmid::new_for_testing(
            ADMIN,
            1,
            ctx,
        );

    let mut identities =
        identity_binding::new_for_testing(
            ctx,
        );

    let identity_id =
        identity_binding::create_binding(
            access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_user(),
            b"entry-user",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            ctx,
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            ctx,
        );

    let root_space_id =
        spatial::register_space(
            access,
            &mut spatial_registry,
            &identities,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            b"earth/au/qld/bundaberg",
            b"tobmate-world",
            spatial::space_world(),
            0,
            ctx,
        );

    let (mut protocols, protocol_admin) =
        protocol_registry::create(
            access,
            ctx,
        );

    let entry_protocol_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_entry(),
            b"ENTRY",
            1,
            0,
            0,
            b"entry-spec",
            b"entry-compat",
            ctx,
        );

    let presence_protocol_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_presence(),
            b"PRESENCE",
            1,
            0,
            0,
            b"presence-spec",
            b"presence-compat",
            ctx,
        );

    let capability_protocol_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_capability(),
            b"CAPABILITY",
            1,
            0,
            0,
            b"cap-spec",
            b"cap-compat",
            ctx,
        );

    let (mut worlds, world_admin) =
        world_space::create(
            access,
            ctx,
        );

    let world_id =
        world_space::register_world(
            access,
            &mut worlds,
            &world_admin,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_protocol_id,
            presence_protocol_id,
            ctx,
        );

    let binding_id =
        world_space::bind_space(
            access,
            &mut worlds,
            &world_admin,
            &spatial_registry,
            &protocols,
            world_id,
            root_space_id,
            entry_protocol_id,
            presence_protocol_id,
            capability_protocol_id,
            ctx,
        );

    (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        identity_id,
        world_id,
        binding_id,
    )
}


/* ============================================================
   Test 01 — Create Registry
   ============================================================ */

#[test]
fun test_01_create_registry() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (registry, admin_cap) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    assert!(entry_auth::version(&registry) == 1, 1);
    assert!(!entry_auth::is_paused(&registry), 2);
    assert!(entry_auth::total_policies(&registry) == 0, 3);
    assert!(entry_auth::total_grants(&registry) == 0, 4);

    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(registry);
    entry_auth::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — PUBLIC World Policy
   ============================================================ */

#[test]
fun test_02_public_world_policy_authorizes() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_public(),
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        entry_auth::is_entry_authorized(
            &auth,
            &identities,
            policy_id,
            identity_id,
            0,
        ),
        10,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Restricted Policy + Grant
   ============================================================ */

#[test]
fun test_03_restricted_policy_with_grant_authorizes() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    let grant_id =
        entry_auth::create_grant(
            &access,
            &mut auth,
            &auth_admin,
            &identities,
            policy_id,
            identity_id,
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(grant_id == 1, 20);

    assert!(
        entry_auth::is_entry_authorized(
            &auth,
            &identities,
            policy_id,
            identity_id,
            0,
        ),
        21,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Space-Level Policy
   ============================================================ */

#[test]
fun test_04_space_policy_authorizes() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        identity_id,
        world_id,
        binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            binding_id,
            world_space::binding_entry_protocol_id(
                &worlds,
                binding_id,
            ),
            entry_auth::policy_public(),
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        entry_auth::policy_space_binding_id(
            &auth,
            policy_id,
        ) == binding_id,
        30,
    );

    assert!(
        entry_auth::is_entry_authorized(
            &auth,
            &identities,
            policy_id,
            identity_id,
            0,
        ),
        31,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Restricted Policy Without Grant Denied
   ============================================================ */

#[test]
fun test_05_restricted_policy_without_grant_denied() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_allowlist(),
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        !entry_auth::is_entry_authorized(
            &auth,
            &identities,
            policy_id,
            identity_id,
            0,
        ),
        40,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Policy Suspend / Reactivate
   ============================================================ */

#[test]
fun test_06_policy_status_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        _identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_public(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_policy_status(
        &access,
        &mut auth,
        &auth_admin,
        policy_id,
        entry_auth::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::active_policy_count(&auth) == 0,
        50,
    );

    entry_auth::set_policy_status(
        &access,
        &mut auth,
        &auth_admin,
        policy_id,
        entry_auth::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::active_policy_count(&auth) == 1,
        51,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07 — Grant Suspend / Reactivate
   ============================================================ */

#[test]
fun test_07_grant_status_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    let grant_id =
        entry_auth::create_grant(
            &access,
            &mut auth,
            &auth_admin,
            &identities,
            policy_id,
            identity_id,
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_grant_status(
        &access,
        &mut auth,
        &auth_admin,
        grant_id,
        entry_auth::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::active_grant_count(&auth) == 0,
        60,
    );

    entry_auth::set_grant_status(
        &access,
        &mut auth,
        &auth_admin,
        grant_id,
        entry_auth::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::active_grant_count(&auth) == 1,
        61,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08 — Pause / Version
   ============================================================ */

#[test]
fun test_08_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_paused(
        &access,
        &mut auth,
        &auth_admin,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::is_paused(&auth),
        70,
    );

    entry_auth::set_paused(
        &access,
        &mut auth,
        &auth_admin,
        false,
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::set_version(
        &access,
        &mut auth,
        &auth_admin,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::version(&auth) == 2,
        71,
    );

    access_control::destroy_for_testing(access);
    entry_auth::destroy_for_testing(auth);
    entry_auth::destroy_admin_cap_for_testing(auth_admin);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 09 — Duplicate Active Policy Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_09_duplicate_active_policy_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        _identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let entry_protocol_id =
        world_space::world_entry_protocol_id(
            &worlds,
            world_id,
        );

    entry_auth::create_policy(
        &access,
        &mut auth,
        &auth_admin,
        &worlds,
        &protocols,
        world_id,
        0,
        entry_protocol_id,
        entry_auth::policy_public(),
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::create_policy(
        &access,
        &mut auth,
        &auth_admin,
        &worlds,
        &protocols,
        world_id,
        0,
        entry_protocol_id,
        entry_auth::policy_public(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Duplicate Active Grant Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_10_duplicate_active_grant_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::create_grant(
        &access,
        &mut auth,
        &auth_admin,
        &identities,
        policy_id,
        identity_id,
        0,
        0,
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::create_grant(
        &access,
        &mut auth,
        &auth_admin,
        &identities,
        policy_id,
        identity_id,
        0,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Wrong Entry Protocol Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_11_wrong_entry_protocol_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        _identity_id,
        world_id,
        binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let wrong_protocol_id =
        world_space::binding_capability_protocol_id(
            &worlds,
            binding_id,
        );

    entry_auth::create_policy(
        &access,
        &mut auth,
        &auth_admin,
        &worlds,
        &protocols,
        world_id,
        0,
        wrong_protocol_id,
        entry_auth::policy_public(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Invalid Validity Range Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_12_invalid_validity_range_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::create_grant(
        &access,
        &mut auth,
        &auth_admin,
        &identities,
        policy_id,
        identity_id,
        10,
        5,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Grant Not Yet Valid
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_13_grant_not_yet_valid() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::create_grant(
        &access,
        &mut auth,
        &auth_admin,
        &identities,
        policy_id,
        identity_id,
        10,
        20,
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::assert_entry_authorized(
        &auth,
        &identities,
        policy_id,
        identity_id,
        5,
    );

    abort 999
}


/* ============================================================
   Test 14 — Grant Expired
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_14_grant_expired() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::create_grant(
        &access,
        &mut auth,
        &auth_admin,
        &identities,
        policy_id,
        identity_id,
        1,
        10,
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::assert_entry_authorized(
        &auth,
        &identities,
        policy_id,
        identity_id,
        11,
    );

    abort 999
}


/* ============================================================
   Test 15 — Revoked Policy Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_15_revoked_policy_cannot_reactivate() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        _identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_public(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_policy_status(
        &access,
        &mut auth,
        &auth_admin,
        policy_id,
        entry_auth::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::set_policy_status(
        &access,
        &mut auth,
        &auth_admin,
        policy_id,
        entry_auth::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 16 — Revoked Grant Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_16_revoked_grant_cannot_reactivate() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    let grant_id =
        entry_auth::create_grant(
            &access,
            &mut auth,
            &auth_admin,
            &identities,
            policy_id,
            identity_id,
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_grant_status(
        &access,
        &mut auth,
        &auth_admin,
        grant_id,
        entry_auth::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::set_grant_status(
        &access,
        &mut auth,
        &auth_admin,
        grant_id,
        entry_auth::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 17 — Admin Cap Mismatch
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 19,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_17_admin_cap_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut auth_a, _admin_a) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let (_auth_b, admin_b) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_paused(
        &access,
        &mut auth_a,
        &admin_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 18 — Paused Registry Denies Authorization
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_gsos::gsos_entry_authorization
)]
fun test_18_paused_registry_denies_authorization() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        identity_id,
        world_id,
        _binding_id,
    ) = setup_control_plane(
        &mut scenario,
        &access,
    );

    let (mut auth, auth_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut auth,
            &auth_admin,
            &worlds,
            &protocols,
            world_id,
            0,
            world_space::world_entry_protocol_id(
                &worlds,
                world_id,
            ),
            entry_auth::policy_public(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::set_paused(
        &access,
        &mut auth,
        &auth_admin,
        true,
        test_scenario::ctx(&mut scenario),
    );

    entry_auth::assert_entry_authorized(
        &auth,
        &identities,
        policy_id,
        identity_id,
        0,
    );

    abort 999
}
