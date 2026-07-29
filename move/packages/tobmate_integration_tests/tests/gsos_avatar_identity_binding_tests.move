#[test_only]
module tobmate_integration_tests::gsos_avatar_identity_binding_tests;

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

use tobmate_gsos::gsos_avatar_identity_binding::{
    Self as avatar_binding,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Integrated Fixture
   ============================================================ */

fun setup_avatar_control_plane(
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

    let avatar_identity_id =
        identity_binding::create_binding(
            access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_avatar(),
            b"avatar:primary",
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
            avatar_identity_id,
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

    let avatar_protocol_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_avatar(),
            b"AVATAR",
            1,
            0,
            0,
            b"avatar-spec",
            b"avatar-compat",
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
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
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    assert!(avatar_binding::version(&registry) == 1, 1);
    assert!(!avatar_binding::is_paused(&registry), 2);
    assert!(avatar_binding::total_created(&registry) == 0, 3);
    assert!(avatar_binding::active_avatar_count(&registry) == 0, 4);

    access_control::destroy_for_testing(access);
    avatar_binding::destroy_for_testing(registry);
    avatar_binding::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Bind Avatar
   ============================================================ */

#[test]
fun test_02_bind_avatar() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let avatar_id =
        avatar_binding::bind_avatar(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            avatar_identity_id,
            world_id,
            binding_id,
            avatar_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(avatar_id == 1, 10);

    assert!(
        avatar_binding::avatar_status(
            &registry,
            avatar_id,
        ) == avatar_binding::status_active(),
        11,
    );

    assert!(
        avatar_binding::avatar_identity_binding_id(
            &registry,
            avatar_id,
        ) == avatar_identity_id,
        12,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    avatar_binding::destroy_for_testing(registry);
    avatar_binding::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Avatar Status Lifecycle
   ============================================================ */

#[test]
fun test_03_avatar_status_lifecycle() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let avatar_id =
        avatar_binding::bind_avatar(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            avatar_identity_id,
            world_id,
            binding_id,
            avatar_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::set_avatar_status(
        &access,
        &mut registry,
        &admin_cap,
        avatar_id,
        avatar_binding::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        avatar_binding::active_avatar_count(
            &registry,
        ) == 0,
        20,
    );

    avatar_binding::set_avatar_status(
        &access,
        &mut registry,
        &admin_cap,
        avatar_id,
        avatar_binding::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        avatar_binding::active_avatar_count(
            &registry,
        ) == 1,
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
    avatar_binding::destroy_for_testing(registry);
    avatar_binding::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Pause / Version
   ============================================================ */

#[test]
fun test_04_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        avatar_binding::is_paused(&registry),
        30,
    );

    avatar_binding::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        false,
        test_scenario::ctx(&mut scenario),
    );

    avatar_binding::set_version(
        &access,
        &mut registry,
        &admin_cap,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        avatar_binding::version(&registry) == 2,
        31,
    );

    access_control::destroy_for_testing(access);
    avatar_binding::destroy_for_testing(registry);
    avatar_binding::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Revoke Avatar
   ============================================================ */

#[test]
fun test_05_revoke_avatar() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let avatar_id =
        avatar_binding::bind_avatar(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            avatar_identity_id,
            world_id,
            binding_id,
            avatar_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::set_avatar_status(
        &access,
        &mut registry,
        &admin_cap,
        avatar_id,
        avatar_binding::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        avatar_binding::avatar_status(
            &registry,
            avatar_id,
        ) == avatar_binding::status_revoked(),
        40,
    );

    assert!(
        avatar_binding::total_revoked(
            &registry,
        ) == 1,
        41,
    );

    assert!(
        avatar_binding::active_avatar_count(
            &registry,
        ) == 0,
        42,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    access_control::destroy_for_testing(access);
    avatar_binding::destroy_for_testing(registry);
    avatar_binding::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Duplicate Active Avatar Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_06_duplicate_active_avatar_rejected() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::bind_avatar(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    avatar_binding::bind_avatar(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Non-Avatar Identity Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 3,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_07_non_avatar_identity_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let ctx = test_scenario::ctx(&mut scenario);

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

    let user_identity_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_user(),
            b"user:not-avatar",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            ctx,
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            ctx,
        );

    let root_space_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identities,
            user_identity_id,
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            b"earth/au/qld/bundaberg",
            b"tobmate-world",
            spatial::space_world(),
            0,
            ctx,
        );

    let (mut protocols, protocol_admin) =
        protocol_registry::create(
            &access,
            ctx,
        );

    let entry_id =
        protocol_registry::register_protocol(
            &access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_entry(),
            b"ENTRY",
            1, 0, 0,
            b"entry-spec",
            b"entry-compat",
            ctx,
        );

    let presence_id =
        protocol_registry::register_protocol(
            &access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_presence(),
            b"PRESENCE",
            1, 0, 0,
            b"presence-spec",
            b"presence-compat",
            ctx,
        );

    let capability_id =
        protocol_registry::register_protocol(
            &access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_capability(),
            b"CAPABILITY",
            1, 0, 0,
            b"cap-spec",
            b"cap-compat",
            ctx,
        );

    let avatar_protocol_id =
        protocol_registry::register_protocol(
            &access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_avatar(),
            b"AVATAR",
            1, 0, 0,
            b"avatar-spec",
            b"avatar-compat",
            ctx,
        );

    let (mut worlds, world_admin) =
        world_space::create(
            &access,
            ctx,
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut worlds,
            &world_admin,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            ctx,
        );

    let binding_id =
        world_space::bind_space(
            &access,
            &mut worlds,
            &world_admin,
            &spatial_registry,
            &protocols,
            world_id,
            root_space_id,
            entry_id,
            presence_id,
            capability_id,
            ctx,
        );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            ctx,
        );

    avatar_binding::bind_avatar(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        user_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 08 — World / Space Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 6,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_08_world_space_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        identities,
        mut spatial_registry,
        protocols,
        _protocol_admin,
        mut worlds,
        world_admin,
        avatar_identity_id,
        first_world_id,
        first_binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let ctx =
        test_scenario::ctx(&mut scenario);

    /*
       Create a second canonical GSAP root space.
    */
    let second_root_space_id =
        spatial::register_space(
            &access,
            &mut spatial_registry,
            &identities,
            avatar_identity_id,
            b"gsap://earth/au/qld/bundaberg/tobmate-world-2",
            b"earth/au/qld/bundaberg",
            b"tobmate-world-2",
            spatial::space_world(),
            0,
            ctx,
        );

    /*
       Reuse the first world's protocol bindings.
       Read them before taking &mut worlds.
    */
    let entry_protocol_id =
        world_space::world_entry_protocol_id(
            &worlds,
            first_world_id,
        );

    let presence_protocol_id =
        world_space::world_presence_protocol_id(
            &worlds,
            first_world_id,
        );

    /*
       Register a second GSOS World.
    */
    let second_world_id =
        world_space::register_world(
            &access,
            &mut worlds,
            &world_admin,
            &spatial_registry,
            &protocols,
            second_root_space_id,
            entry_protocol_id,
            presence_protocol_id,
            ctx,
        );

    /*
       first_binding_id belongs to first_world_id.

       Supplying second_world_id with first_binding_id
       must therefore fail with E_WORLD_SPACE_MISMATCH.
    */
    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            ctx,
        );

    avatar_binding::bind_avatar(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        avatar_identity_id,
        second_world_id,
        first_binding_id,
        avatar_protocol_id,
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 09 — Wrong Protocol Family Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_09_wrong_avatar_protocol_rejected() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        _avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let wrong_protocol_id =
        world_space::binding_entry_protocol_id(
            &worlds,
            binding_id,
        );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::bind_avatar(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        avatar_identity_id,
        world_id,
        binding_id,
        wrong_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Revoked Avatar Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_10_revoked_avatar_cannot_reactivate() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let avatar_id =
        avatar_binding::bind_avatar(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            avatar_identity_id,
            world_id,
            binding_id,
            avatar_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::set_avatar_status(
        &access,
        &mut registry,
        &admin_cap,
        avatar_id,
        avatar_binding::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    avatar_binding::set_avatar_status(
        &access,
        &mut registry,
        &admin_cap,
        avatar_id,
        avatar_binding::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Admin Cap Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 13,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_11_admin_cap_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry_a, _admin_a) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let (_registry_b, admin_b) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::set_paused(
        &access,
        &mut registry_a,
        &admin_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Paused Registry Blocks Binding
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_gsos::gsos_avatar_identity_binding
)]
fun test_12_paused_registry_blocks_binding() {
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
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
    ) = setup_avatar_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        avatar_binding::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    avatar_binding::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    avatar_binding::bind_avatar(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        avatar_identity_id,
        world_id,
        binding_id,
        avatar_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
