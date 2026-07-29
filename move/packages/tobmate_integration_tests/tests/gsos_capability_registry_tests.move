#[test_only]
module tobmate_integration_tests::gsos_capability_registry_tests;

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

use tobmate_gsos::gsos_agent_authority::{
    Self as agent_authority,
};

use tobmate_gsos::gsos_capability_registry::{
    Self as capability,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Integrated Fixture
   ============================================================ */

fun setup_capability_control_plane(
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

    let capability_protocol_id =
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
            capability_protocol_id,
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
            agent_authority::authority_delegate(),
            0,
            100,
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
        authority_id,
        world_id,
        binding_id,
        capability_protocol_id,
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
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    assert!(capability::version(&registry) == 1, 1);
    assert!(!capability::is_paused(&registry), 2);
    assert!(capability::total_capabilities(&registry) == 0, 3);
    assert!(capability::total_assignments(&registry) == 0, 4);

    access_control::destroy_for_testing(access);
    capability::destroy_for_testing(registry);
    capability::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Register Capability
   ============================================================ */

#[test]
fun test_02_register_capability() {
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
        _authority_id,
        _world_id,
        _binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_read(),
            b"READ",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(capability_id == 1, 10);
    assert!(
        capability::capability_status(
            &registry,
            capability_id,
        ) == capability::status_active(),
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
    access_control::destroy_for_testing(access);
    capability::destroy_for_testing(registry);
    capability::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Assign To Authority
   ============================================================ */

#[test]
fun test_03_assign_to_authority() {
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
        authority_id,
        world_id,
        binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_execute(),
            b"EXECUTE",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    let assignment_id =
        capability::assign_to_authority(
            &access,
            &mut registry,
            &admin_cap,
            &authorities,
            &worlds,
            capability_id,
            authority_id,
            world_id,
            binding_id,
            0,
            50,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(assignment_id == 1, 20);

    assert!(
        capability::is_assignment_valid(
            &registry,
            &authorities,
            assignment_id,
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
    agent_authority::destroy_for_testing(authorities);
    agent_authority::destroy_admin_cap_for_testing(authority_admin);
    access_control::destroy_for_testing(access);
    capability::destroy_for_testing(registry);
    capability::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Capability Lifecycle
   ============================================================ */

#[test]
fun test_04_capability_status_lifecycle() {
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
        _authority_id,
        _world_id,
        _binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_read(),
            b"READ",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    capability::set_capability_status(
        &access,
        &mut registry,
        &admin_cap,
        capability_id,
        capability::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        capability::active_capability_count(
            &registry,
        ) == 0,
        30,
    );

    capability::set_capability_status(
        &access,
        &mut registry,
        &admin_cap,
        capability_id,
        capability::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        capability::active_capability_count(
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
    agent_authority::destroy_for_testing(authorities);
    agent_authority::destroy_admin_cap_for_testing(authority_admin);
    access_control::destroy_for_testing(access);
    capability::destroy_for_testing(registry);
    capability::destroy_admin_cap_for_testing(admin_cap);

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
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    capability::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        capability::is_paused(&registry),
        40,
    );

    capability::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        false,
        test_scenario::ctx(&mut scenario),
    );

    capability::set_version(
        &access,
        &mut registry,
        &admin_cap,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        capability::version(&registry) == 2,
        41,
    );

    access_control::destroy_for_testing(access);
    capability::destroy_for_testing(registry);
    capability::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Assign To Delegation
   ============================================================ */

#[test]
fun test_06_assign_to_delegation() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        mut authorities,
        authority_admin,
        authority_id,
        world_id,
        binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
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

    let delegation_id =
        agent_authority::create_delegation(
            &access,
            &mut authorities,
            &authority_admin,
            &identities,
            authority_id,
            delegate_agent_id,
            world_id,
            binding_id,
            agent_authority::authority_execute(),
            0,
            50,
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_execute(),
            b"EXECUTE",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    let assignment_id =
        capability::assign_to_delegation(
            &access,
            &mut registry,
            &admin_cap,
            &authorities,
            &worlds,
            capability_id,
            delegation_id,
            world_id,
            binding_id,
            0,
            40,
            0,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        capability::is_assignment_valid(
            &registry,
            &authorities,
            assignment_id,
            20,
        ),
        50,
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
    access_control::destroy_for_testing(access);
    capability::destroy_for_testing(registry);
    capability::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07 — Duplicate Capability Rejected
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 5,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_07_duplicate_capability_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        _worlds,
        _world_admin,
        _authorities,
        _authority_admin,
        _authority_id,
        _world_id,
        _binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    capability::register_capability(
        &access,
        &mut registry,
        &admin_cap,
        &protocols,
        capability::capability_read(),
        b"READ",
        capability_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    capability::register_capability(
        &access,
        &mut registry,
        &admin_cap,
        &protocols,
        capability::capability_read(),
        b"READ-2",
        capability_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Assignment Exceeds Authority
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 10,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_08_assignment_exceeds_authority_rejected() {
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
        mut protocols,
        protocol_admin,
        worlds,
        world_admin,
        mut authorities,
        authority_admin,
        _authority_id,
        world_id,
        binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    /*
       Create a second canonical AGENT identity so the
       duplicate-authority guard does not interfere.
    */
    let low_agent_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:observe-only",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    /*
       Register a second valid AGENT protocol version.
    */
    let low_agent_protocol_id =
        protocol_registry::register_protocol(
            &access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_agent(),
            b"AGENT-OBSERVE",
            2,
            0,
            0,
            b"agent-observe-spec",
            b"agent-observe-compat",
            test_scenario::ctx(&mut scenario),
        );

    /*
       principal identity is binding #1 from the fixture.
       Create an OBSERVE-only authority.
    */
    let low_authority_id =
        agent_authority::create_authority(
            &access,
            &mut authorities,
            &authority_admin,
            &identities,
            &worlds,
            &protocols,
            low_agent_id,
            1,
            world_id,
            binding_id,
            low_agent_protocol_id,
            agent_authority::authority_observe(),
            0,
            100,
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    /*
       CONTROL requires DELEGATE authority.
       OBSERVE authority must therefore be rejected.
    */
    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_control(),
            b"CONTROL",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    capability::assign_to_authority(
        &access,
        &mut registry,
        &admin_cap,
        &authorities,
        &worlds,
        capability_id,
        low_authority_id,
        world_id,
        binding_id,
        0,
        50,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09 — Assignment Scope Mismatch
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_09_assignment_scope_mismatch_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        authority_id,
        world_id,
        _binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_read(),
            b"READ",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    capability::assign_to_authority(
        &access,
        &mut registry,
        &admin_cap,
        &authorities,
        &worlds,
        capability_id,
        authority_id,
        world_id,
        999,
        0,
        50,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Invalid Assignment Validity
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 11,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_10_invalid_assignment_validity_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        authorities,
        _authority_admin,
        authority_id,
        world_id,
        binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_execute(),
            b"EXECUTE",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    capability::assign_to_authority(
        &access,
        &mut registry,
        &admin_cap,
        &authorities,
        &worlds,
        capability_id,
        authority_id,
        world_id,
        binding_id,
        20,
        10,
        0,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Revoked Capability Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 15,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_11_revoked_capability_cannot_reactivate() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        _worlds,
        _world_admin,
        _authorities,
        _authority_admin,
        _authority_id,
        _world_id,
        _binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut registry,
            &admin_cap,
            &protocols,
            capability::capability_read(),
            b"READ",
            capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    capability::set_capability_status(
        &access,
        &mut registry,
        &admin_cap,
        capability_id,
        capability::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    capability::set_capability_status(
        &access,
        &mut registry,
        &admin_cap,
        capability_id,
        capability::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Admin Cap Mismatch
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 17,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_12_admin_cap_mismatch_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (mut registry_a, _admin_a) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let (_registry_b, admin_b) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    capability::set_paused(
        &access,
        &mut registry_a,
        &admin_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Paused Registry Blocks Registration
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_gsos::gsos_capability_registry
)]
fun test_13_paused_registry_blocks_registration() {
    let mut scenario = test_scenario::begin(ADMIN);

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
        _worlds,
        _world_admin,
        _authorities,
        _authority_admin,
        _authority_id,
        _world_id,
        _binding_id,
        capability_protocol_id,
    ) = setup_capability_control_plane(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    capability::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    capability::register_capability(
        &access,
        &mut registry,
        &admin_cap,
        &protocols,
        capability::capability_read(),
        b"READ",
        capability_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
