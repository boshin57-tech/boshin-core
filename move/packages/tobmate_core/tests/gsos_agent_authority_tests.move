#[test_only]
module tobmate_core::gsos_agent_authority_tests;

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
    Self as agent_auth,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Integrated Fixture
   ============================================================ */

fun setup_agent_control_plane(
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
            1, 0, 0,
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
            1, 0, 0,
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
            1, 0, 0,
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
            1, 0, 0,
            b"agent-spec",
            b"agent-compat",
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

    (
        tmid_obj,
        identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
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
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    assert!(agent_auth::version(&registry) == 1, 1);
    assert!(!agent_auth::is_paused(&registry), 2);
    assert!(agent_auth::total_authorities(&registry) == 0, 3);
    assert!(agent_auth::total_delegations(&registry) == 0, 4);

    access_control::destroy_for_testing(access);
    agent_auth::destroy_for_testing(registry);
    agent_auth::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Create Authority
   ============================================================ */

#[test]
fun test_02_create_authority() {
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
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_delegate(),
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(authority_id == 1, 10);

    assert!(
        agent_auth::authority_status(
            &registry,
            authority_id,
        ) == agent_auth::status_active(),
        11,
    );

    assert!(
        agent_auth::is_authority_valid(
            &registry,
            authority_id,
            0,
        ),
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
    agent_auth::destroy_for_testing(registry);
    agent_auth::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Create Delegation
   ============================================================ */

#[test]
fun test_03_create_delegation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        mut identities,
        spatial_registry,
        protocols,
        protocol_admin,
        worlds,
        world_admin,
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let delegate_agent_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:delegate",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_delegate(),
            0,
            100,
            test_scenario::ctx(&mut scenario),
        );

    let delegation_id =
        agent_auth::create_delegation(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            authority_id,
            delegate_agent_id,
            world_id,
            binding_id,
            agent_auth::authority_execute(),
            0,
            50,
            test_scenario::ctx(&mut scenario),
        );

    assert!(delegation_id == 1, 20);

    assert!(
        agent_auth::is_delegation_valid(
            &registry,
            delegation_id,
            25,
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
    agent_auth::destroy_for_testing(registry);
    agent_auth::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Authority Lifecycle
   ============================================================ */

#[test]
fun test_04_authority_status_lifecycle() {
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
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_execute(),
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::set_authority_status(
        &access,
        &mut registry,
        &admin_cap,
        authority_id,
        agent_auth::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        agent_auth::active_authority_count(
            &registry,
        ) == 0,
        30,
    );

    agent_auth::set_authority_status(
        &access,
        &mut registry,
        &admin_cap,
        authority_id,
        agent_auth::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        agent_auth::active_authority_count(
            &registry,
        ) == 1,
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
    agent_auth::destroy_for_testing(registry);
    agent_auth::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Pause / Version
   ============================================================ */

#[test]
fun test_05_pause_and_version() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        agent_auth::is_paused(&registry),
        40,
    );

    agent_auth::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        false,
        test_scenario::ctx(&mut scenario),
    );

    agent_auth::set_version(
        &access,
        &mut registry,
        &admin_cap,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        agent_auth::version(&registry) == 2,
        41,
    );

    access_control::destroy_for_testing(access);
    agent_auth::destroy_for_testing(registry);
    agent_auth::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Duplicate Active Authority Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_core::gsos_agent_authority
)]
fun test_06_duplicate_active_authority_rejected() {
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
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::create_authority(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        agent_id,
        principal_id,
        world_id,
        binding_id,
        agent_protocol_id,
        agent_auth::authority_execute(),
        0,
        0,
        test_scenario::ctx(&mut scenario),
    );

    agent_auth::create_authority(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        agent_id,
        principal_id,
        world_id,
        binding_id,
        agent_protocol_id,
        agent_auth::authority_execute(),
        0,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Delegation Authority Ceiling
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 16,
    location = tobmate_core::gsos_agent_authority
)]
fun test_07_delegation_exceeds_authority_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        mut identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let delegate_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:delegate",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_interact(),
            0,
            100,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::create_delegation(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        authority_id,
        delegate_id,
        world_id,
        binding_id,
        agent_auth::authority_execute(),
        0,
        50,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Delegation Scope Expansion
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_core::gsos_agent_authority
)]
fun test_08_delegation_scope_expansion_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        mut identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let delegate_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:delegate",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_delegate(),
            0,
            100,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::create_delegation(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        authority_id,
        delegate_id,
        world_id + 1,
        binding_id,
        agent_auth::authority_execute(),
        0,
        50,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09 — Delegation Validity Expansion
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 18,
    location = tobmate_core::gsos_agent_authority
)]
fun test_09_delegation_validity_expansion_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        mut identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let delegate_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:delegate",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_delegate(),
            10,
            100,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::create_delegation(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        authority_id,
        delegate_id,
        world_id,
        binding_id,
        agent_auth::authority_execute(),
        0,
        120,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Duplicate Active Delegation
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_core::gsos_agent_authority
)]
fun test_10_duplicate_active_delegation_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        mut identities,
        _spatial_registry,
        protocols,
        _protocol_admin,
        worlds,
        _world_admin,
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let delegate_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:delegate",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_delegate(),
            0,
            100,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::create_delegation(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        authority_id,
        delegate_id,
        world_id,
        binding_id,
        agent_auth::authority_execute(),
        0,
        50,
        test_scenario::ctx(&mut scenario),
    );

    agent_auth::create_delegation(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        authority_id,
        delegate_id,
        world_id,
        binding_id,
        agent_auth::authority_execute(),
        0,
        50,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Revoked Authority Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 20,
    location = tobmate_core::gsos_agent_authority
)]
fun test_11_revoked_authority_cannot_reactivate() {
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
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let authority_id =
        agent_auth::create_authority(
            &access,
            &mut registry,
            &admin_cap,
            &identities,
            &worlds,
            &protocols,
            agent_id,
            principal_id,
            world_id,
            binding_id,
            agent_protocol_id,
            agent_auth::authority_execute(),
            0,
            0,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::set_authority_status(
        &access,
        &mut registry,
        &admin_cap,
        authority_id,
        agent_auth::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    agent_auth::set_authority_status(
        &access,
        &mut registry,
        &admin_cap,
        authority_id,
        agent_auth::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Admin Cap Mismatch
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 22,
    location = tobmate_core::gsos_agent_authority
)]
fun test_12_admin_cap_mismatch_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry_a, _admin_a) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let (_registry_b, admin_b) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::set_paused(
        &access,
        &mut registry_a,
        &admin_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Paused Registry Blocks Authority Creation
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_core::gsos_agent_authority
)]
fun test_13_paused_registry_blocks_authority_creation() {
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
        principal_id,
        agent_id,
        world_id,
        binding_id,
        agent_protocol_id,
    ) = setup_agent_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        agent_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    agent_auth::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    agent_auth::create_authority(
        &access,
        &mut registry,
        &admin_cap,
        &identities,
        &worlds,
        &protocols,
        agent_id,
        principal_id,
        world_id,
        binding_id,
        agent_protocol_id,
        agent_auth::authority_execute(),
        0,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
