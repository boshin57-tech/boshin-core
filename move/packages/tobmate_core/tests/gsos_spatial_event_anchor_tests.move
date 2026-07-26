#[test_only]
module tobmate_core::gsos_spatial_event_anchor_tests;

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

use tobmate_core::gsos_protocol_registry::{
    Self as protocol_registry,
};

use tobmate_core::gsos_world_space_registry::{
    Self as world_space,
};

use tobmate_core::gsos_agent_authority::{
    Self as agent_authority,
};

use tobmate_core::gsos_avatar_identity_binding::{
    Self as avatar_binding,
};

use tobmate_core::gsos_spatial_event_anchor::{
    Self as event_anchor,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Integrated Fixture
   ============================================================ */

fun setup_event_control_plane(
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
    agent_authority::GSOSAgentAuthorityRegistry,
    agent_authority::GSOSAgentAuthorityAdminCap,
    avatar_binding::GSOSAvatarBindingRegistry,
    avatar_binding::GSOSAvatarBindingAdminCap,
    u64,
    u64,
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

    let principal_id =
        identity_binding::create_binding(
            access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_user(),
            b"principal:user",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            ctx,
        );

    let agent_id =
        identity_binding::create_binding(
            access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:primary",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
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
            principal_id,
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

    let entry_id =
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

    let presence_id =
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

    let capability_id =
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

    let agent_protocol_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_agent(),
            b"AGENT",
            1,
            0,
            0,
            b"agent-spec",
            b"agent-compat",
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

    let event_protocol_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_event(),
            b"EVENT",
            1,
            0,
            0,
            b"event-spec",
            b"event-compat",
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
            entry_id,
            presence_id,
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
            entry_id,
            presence_id,
            capability_id,
            ctx,
        );

    let (mut authorities, authority_admin) =
        agent_authority::create(
            access,
            ctx,
        );

    let authority_id =
        agent_authority::create_authority(
            access,
            &mut authorities,
            &authority_admin,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_authority::authority_execute(),
            0,
            100,
            ctx,
        );

    let (mut avatars, avatar_admin) =
        avatar_binding::create(
            access,
            ctx,
        );

    let avatar_id =
        avatar_binding::bind_avatar(
            access,
            &mut avatars,
            &avatar_admin,
            &identities,
            &worlds,
            &protocols,
            avatar_identity_id,
            world_id,
            binding_id,
            avatar_protocol_id,
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
        authorities,
        authority_admin,
        avatars,
        avatar_admin,
        principal_id,
        authority_id,
        avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
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
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    assert!(event_anchor::version(&registry) == 1, 1);
    assert!(!event_anchor::is_paused(&registry), 2);
    assert!(event_anchor::total_anchored(&registry) == 0, 3);

    access_control::destroy_for_testing(access);
    event_anchor::destroy_for_testing(registry);
    event_anchor::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Anchor Identity Event
   ============================================================ */

#[test]
fun test_02_anchor_identity_event() {
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
        authorities,
        authority_admin,
        avatars,
        avatar_admin,
        principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let event_id =
        event_anchor::anchor_event(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &avatars,
            &authorities,
            &worlds,
            &protocols,
            event_anchor::event_interaction(),
            world_id,
            binding_id,
            event_anchor::actor_identity(),
            principal_id,
            event_protocol_id,
            b"payload-hash-1",
            b"metadata-hash-1",
            1000,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(event_id == 1, 10);

    assert!(
        event_anchor::verify_anchor(
            &registry,
            event_id,
            &b"payload-hash-1",
            &b"metadata-hash-1",
            1000,
        ),
        11,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    agent_authority::destroy_for_testing(authorities);
    agent_authority::destroy_admin_cap_for_testing(authority_admin);
    avatar_binding::destroy_for_testing(avatars);
    avatar_binding::destroy_admin_cap_for_testing(avatar_admin);
    access_control::destroy_for_testing(access);
    event_anchor::destroy_for_testing(registry);
    event_anchor::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Anchor Avatar Event
   ============================================================ */

#[test]
fun test_03_anchor_avatar_event() {
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
        authorities,
        authority_admin,
        avatars,
        avatar_admin,
        _principal_id,
        _authority_id,
        avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let event_id =
        event_anchor::anchor_event(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &avatars,
            &authorities,
            &worlds,
            &protocols,
            event_anchor::event_presence(),
            world_id,
            binding_id,
            event_anchor::actor_avatar(),
            avatar_id,
            event_protocol_id,
            b"avatar-payload",
            b"avatar-meta",
            2000,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(event_id == 1, 20);

    assert!(
        event_anchor::anchor_actor_kind(
            &registry,
            event_id,
        ) == event_anchor::actor_avatar(),
        21,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    agent_authority::destroy_for_testing(authorities);
    agent_authority::destroy_admin_cap_for_testing(authority_admin);
    avatar_binding::destroy_for_testing(avatars);
    avatar_binding::destroy_admin_cap_for_testing(avatar_admin);
    access_control::destroy_for_testing(access);
    event_anchor::destroy_for_testing(registry);
    event_anchor::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Anchor Authority Event
   ============================================================ */

#[test]
fun test_04_anchor_authority_event() {
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
        authorities,
        authority_admin,
        avatars,
        avatar_admin,
        _principal_id,
        authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let event_id =
        event_anchor::anchor_event(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &avatars,
            &authorities,
            &worlds,
            &protocols,
            event_anchor::event_execution(),
            world_id,
            binding_id,
            event_anchor::actor_authority(),
            authority_id,
            event_protocol_id,
            b"authority-payload",
            b"authority-meta",
            3000,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(event_id == 1, 30);

    assert!(
        event_anchor::anchor_actor_reference_id(
            &registry,
            event_id,
        ) == authority_id,
        31,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    agent_authority::destroy_for_testing(authorities);
    agent_authority::destroy_admin_cap_for_testing(authority_admin);
    avatar_binding::destroy_for_testing(avatars);
    avatar_binding::destroy_admin_cap_for_testing(avatar_admin);
    access_control::destroy_for_testing(access);
    event_anchor::destroy_for_testing(registry);
    event_anchor::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Invalidate Anchor
   ============================================================ */

#[test]
fun test_05_invalidate_anchor() {
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
        authorities,
        authority_admin,
        avatars,
        avatar_admin,
        _principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let event_id =
        event_anchor::anchor_event(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &avatars,
            &authorities,
            &worlds,
            &protocols,
            event_anchor::event_governance(),
            world_id,
            binding_id,
            event_anchor::actor_system(),
            0,
            event_protocol_id,
            b"governance-payload",
            b"governance-meta",
            4000,
            0,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::invalidate_anchor(
        &access,
        &mut registry,
        &admin_cap,
        event_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        event_anchor::anchor_status(
            &registry,
            event_id,
        ) == event_anchor::status_invalidated(),
        40,
    );

    assert!(
        event_anchor::active_anchor_count(
            &registry,
        ) == 0,
        41,
    );

    assert!(
        event_anchor::total_invalidated(
            &registry,
        ) == 1,
        42,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identities);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);
    agent_authority::destroy_for_testing(authorities);
    agent_authority::destroy_admin_cap_for_testing(authority_admin);
    avatar_binding::destroy_for_testing(avatars);
    avatar_binding::destroy_admin_cap_for_testing(avatar_admin);
    access_control::destroy_for_testing(access);
    event_anchor::destroy_for_testing(registry);
    event_anchor::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Duplicate Anchor Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 12,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_06_duplicate_anchor_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_interaction(),
        world_id,
        binding_id,
        event_anchor::actor_identity(),
        principal_id,
        event_protocol_id,
        b"dup-payload",
        b"dup-meta",
        5000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_interaction(),
        world_id,
        binding_id,
        event_anchor::actor_identity(),
        principal_id,
        event_protocol_id,
        b"dup-payload",
        b"dup-meta",
        5000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Wrong Event Protocol Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 7,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_07_wrong_event_protocol_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        _event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let wrong_protocol_id =
        world_space::binding_entry_protocol_id(
            &worlds,
            binding_id,
        );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_entry(),
        world_id,
        binding_id,
        event_anchor::actor_identity(),
        principal_id,
        wrong_protocol_id,
        b"payload",
        b"meta",
        6000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Empty Payload Hash Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 8,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_08_empty_payload_hash_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_presence(),
        world_id,
        binding_id,
        event_anchor::actor_identity(),
        principal_id,
        event_protocol_id,
        b"",
        b"meta",
        7000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09 — Avatar Scope Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_09_avatar_scope_mismatch_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        _principal_id,
        _authority_id,
        avatar_id,
        world_id,
        _binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_presence(),
        world_id,
        0,
        event_anchor::actor_avatar(),
        avatar_id,
        event_protocol_id,
        b"payload",
        b"meta",
        8000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Invalid Actor Reference Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_10_invalid_actor_reference_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        _principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_interaction(),
        world_id,
        binding_id,
        event_anchor::actor_identity(),
        999,
        event_protocol_id,
        b"payload",
        b"meta",
        9000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Double Invalidation Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 14,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_11_double_invalidation_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let event_id =
        event_anchor::anchor_event(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &avatars,
            &authorities,
            &worlds,
            &protocols,
            event_anchor::event_interaction(),
            world_id,
            binding_id,
            event_anchor::actor_identity(),
            principal_id,
            event_protocol_id,
            b"payload-double",
            b"meta-double",
            10000,
            0,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::invalidate_anchor(
        &access,
        &mut registry,
        &admin_cap,
        event_id,
        test_scenario::ctx(&mut scenario),
    );

    event_anchor::invalidate_anchor(
        &access,
        &mut registry,
        &admin_cap,
        event_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Admin Cap Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_12_admin_cap_mismatch_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry_a, _admin_a) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let (_registry_b, admin_b) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::set_paused(
        &access,
        &mut registry_a,
        &admin_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Paused Registry Blocks Anchoring
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::gsos_spatial_event_anchor
)]
fun test_13_paused_registry_blocks_anchoring() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        avatars,
        _avatar_admin,
        principal_id,
        _authority_id,
        _avatar_id,
        world_id,
        binding_id,
        event_protocol_id,
    ) = setup_event_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    event_anchor::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    event_anchor::anchor_event(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &avatars,
        &authorities,
        &worlds,
        &protocols,
        event_anchor::event_entry(),
        world_id,
        binding_id,
        event_anchor::actor_identity(),
        principal_id,
        event_protocol_id,
        b"paused-payload",
        b"paused-meta",
        11000,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
