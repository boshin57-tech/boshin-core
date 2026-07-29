#[test_only]
module tobmate_integration_tests::gsos_control_plane_e2e_tests;

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

use tobmate_gsos::gsos_avatar_identity_binding::{
    Self as avatar_binding,
};

use tobmate_gsos::gsos_agent_authority::{
    Self as agent_authority,
};

use tobmate_gsos::gsos_capability_registry::{
    Self as capability,
};

use tobmate_gsos::gsos_spatial_event_anchor::{
    Self as event_anchor,
};

use tobmate_foundation::protocol_governance::{
    Self as governance,
};

use tobmate_gsos::gsos_governance_executor::{
    Self as gsos_executor,
};

const ADMIN: address = @0xA11CE;


/* ============================================================
   Stage 11 Part 11
   Full GSOS Control-Plane E2E Fixture
   ============================================================ */

public struct FullControlPlaneFixture {
    tmid_obj: tmid::TMID,

    identities: identity_binding::GSOSIdentityRegistry,
    identity_admin: identity_binding::GSOSIdentityAdminCap,

    spatial_registry: spatial::GSAPSpatialRegistry,

    protocols: protocol_registry::GSOSProtocolRegistry,
    protocol_admin: protocol_registry::GSOSProtocolAdminCap,

    worlds: world_space::GSOSWorldSpaceRegistry,
    world_admin: world_space::GSOSWorldSpaceAdminCap,

    entry_registry: entry_auth::GSOSEntryAuthorizationRegistry,
    entry_admin: entry_auth::GSOSEntryAuthorizationAdminCap,

    avatars: avatar_binding::GSOSAvatarBindingRegistry,
    avatar_admin: avatar_binding::GSOSAvatarBindingAdminCap,

    authorities: agent_authority::GSOSAgentAuthorityRegistry,
    authority_admin: agent_authority::GSOSAgentAuthorityAdminCap,

    capabilities: capability::GSOSCapabilityRegistry,
    capability_admin: capability::GSOSCapabilityAdminCap,

    event_registry: event_anchor::GSOSSpatialEventAnchorRegistry,
    event_admin: event_anchor::GSOSSpatialEventAnchorAdminCap,

    principal_id: u64,
    agent_id: u64,
    delegate_agent_id: u64,
    avatar_identity_id: u64,

    root_space_id: u64,
    world_id: u64,
    binding_id: u64,

    entry_protocol_id: u64,
    avatar_protocol_id: u64,
    agent_protocol_id: u64,
    capability_protocol_id: u64,
    event_protocol_id: u64,

    policy_id: u64,
    grant_id: u64,

    avatar_id: u64,

    authority_id: u64,
    delegation_id: u64,

    capability_id: u64,
    authority_assignment_id: u64,
    delegation_assignment_id: u64,
}

fun setup_full_control_plane(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
): FullControlPlaneFixture {
    let ctx =
        test_scenario::ctx(scenario);

    /*
     * TMID root identity.
     */
    let tmid_obj =
        tmid::new_for_testing(
            ADMIN,
            1,
            ctx,
        );

    /*
     * Identity registry.
     */
    let mut identities =
        identity_binding::new_for_testing(
            ctx,
        );

    let identity_admin =
        identity_binding::admin_cap_for_testing(
            &identities,
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

    let delegate_agent_id =
        identity_binding::create_binding(
            access,
            &mut identities,
            &tmid_obj,
            identity_binding::identity_agent(),
            b"agent:delegate",
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

    /*
     * GSAP spatial registry.
     */
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

    /*
     * GSOS protocol registry.
     */
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
            b"capability-spec",
            b"capability-compat",
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

    /*
     * World / Space control plane.
     */
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

    /*
     * Entry Authorization control plane.
     */
    let (mut entry_registry, entry_admin) =
        entry_auth::create(
            access,
            ctx,
        );

    let policy_id =
        entry_auth::create_policy(
            access,
            &mut entry_registry,
            &entry_admin,
            &worlds,
            &protocols,
            world_id,
            binding_id,
            entry_protocol_id,
            entry_auth::policy_public(),
            ctx,
        );

    let grant_id =
        entry_auth::create_grant(
            access,
            &mut entry_registry,
            &entry_admin,
            &identities,
            policy_id,
            principal_id,
            0,
            100,
            ctx,
        );

    /*
     * Avatar binding control plane.
     */
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

    /*
     * AI Agent Authority control plane.
     */
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

    let delegation_id =
        agent_authority::create_delegation(
            access,
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
            ctx,
        );

    /*
     * Capability control plane.
     */
    let (mut capabilities, capability_admin) =
        capability::create(
            access,
            ctx,
        );

    let capability_id =
        capability::register_capability(
            access,
            &mut capabilities,
            &capability_admin,
            &protocols,
            capability::capability_execute(),
            b"GSOS_EXECUTE",
            capability_protocol_id,
            ctx,
        );

    let authority_assignment_id =
        capability::assign_to_authority(
            access,
            &mut capabilities,
            &capability_admin,
            &authorities,
            &worlds,
            capability_id,
            authority_id,
            world_id,
            binding_id,
            0,
            100,
            0,
            ctx,
        );

    let delegation_assignment_id =
        capability::assign_to_delegation(
            access,
            &mut capabilities,
            &capability_admin,
            &authorities,
            &worlds,
            capability_id,
            delegation_id,
            world_id,
            binding_id,
            0,
            50,
            0,
            ctx,
        );

    /*
     * Spatial Event Anchoring control plane.
     */
    let (event_registry, event_admin) =
        event_anchor::create(
            access,
            ctx,
        );

    FullControlPlaneFixture {
        tmid_obj,

        identities,
        identity_admin,

        spatial_registry,

        protocols,
        protocol_admin,

        worlds,
        world_admin,

        entry_registry,
        entry_admin,

        avatars,
        avatar_admin,

        authorities,
        authority_admin,

        capabilities,
        capability_admin,

        event_registry,
        event_admin,

        principal_id,
        agent_id,
        delegate_agent_id,
        avatar_identity_id,

        root_space_id,
        world_id,
        binding_id,

        entry_protocol_id,
        avatar_protocol_id,
        agent_protocol_id,
        capability_protocol_id,
        event_protocol_id,

        policy_id,
        grant_id,

        avatar_id,

        authority_id,
        delegation_id,

        capability_id,
        authority_assignment_id,
        delegation_assignment_id,
    }
}


/* ============================================================
   Fixture Cleanup
   ============================================================ */

fun destroy_full_fixture(
    fixture: FullControlPlaneFixture,
) {
    let FullControlPlaneFixture {
        tmid_obj,

        identities,
        identity_admin,

        spatial_registry,

        protocols,
        protocol_admin,

        worlds,
        world_admin,

        entry_registry,
        entry_admin,

        avatars,
        avatar_admin,

        authorities,
        authority_admin,

        capabilities,
        capability_admin,

        event_registry,
        event_admin,

        principal_id: _,
        agent_id: _,
        delegate_agent_id: _,
        avatar_identity_id: _,

        root_space_id: _,
        world_id: _,
        binding_id: _,

        entry_protocol_id: _,
        avatar_protocol_id: _,
        agent_protocol_id: _,
        capability_protocol_id: _,
        event_protocol_id: _,

        policy_id: _,
        grant_id: _,

        avatar_id: _,

        authority_id: _,
        delegation_id: _,

        capability_id: _,
        authority_assignment_id: _,
        delegation_assignment_id: _,
    } = fixture;

    tmid::destroy_for_testing(tmid_obj);

    identity_binding::destroy_for_testing(
        identities,
    );

    identity_binding::destroy_admin_cap_for_testing(
        identity_admin,
    );

    spatial::destroy_for_testing(
        spatial_registry,
    );

    protocol_registry::destroy_for_testing(
        protocols,
    );

    protocol_registry::destroy_admin_cap_for_testing(
        protocol_admin,
    );

    world_space::destroy_for_testing(
        worlds,
    );

    world_space::destroy_admin_cap_for_testing(
        world_admin,
    );

    entry_auth::destroy_for_testing(
        entry_registry,
    );

    entry_auth::destroy_admin_cap_for_testing(
        entry_admin,
    );

    avatar_binding::destroy_for_testing(
        avatars,
    );

    avatar_binding::destroy_admin_cap_for_testing(
        avatar_admin,
    );

    agent_authority::destroy_for_testing(
        authorities,
    );

    agent_authority::destroy_admin_cap_for_testing(
        authority_admin,
    );

    capability::destroy_for_testing(
        capabilities,
    );

    capability::destroy_admin_cap_for_testing(
        capability_admin,
    );

    event_anchor::destroy_for_testing(
        event_registry,
    );

    event_anchor::destroy_admin_cap_for_testing(
        event_admin,
    );
}


/* ============================================================
   Test 01
   Full Identity → Entry Authorization Flow
   ============================================================ */

#[test]
fun test_01_full_identity_entry_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    assert!(
        identity_binding::binding_status(
            &fixture.identities,
            fixture.principal_id,
        ) == identity_binding::status_active(),
        101,
    );

    assert!(
        world_space::world_status(
            &fixture.worlds,
            fixture.world_id,
        ) == world_space::status_active(),
        102,
    );

    assert!(
        world_space::binding_status(
            &fixture.worlds,
            fixture.binding_id,
        ) == world_space::status_active(),
        103,
    );

    assert!(
        entry_auth::policy_status(
            &fixture.entry_registry,
            fixture.policy_id,
        ) == entry_auth::status_active(),
        104,
    );

    assert!(
        entry_auth::grant_status(
            &fixture.entry_registry,
            fixture.grant_id,
        ) == entry_auth::status_active(),
        105,
    );

    assert!(
        entry_auth::is_entry_authorized(
            &fixture.entry_registry,
            &fixture.identities,
            fixture.policy_id,
            fixture.principal_id,
            25,
        ),
        106,
    );

    destroy_full_fixture(fixture);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02
   Avatar-Bound World / Space Flow
   ============================================================ */

#[test]
fun test_02_avatar_bound_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    assert!(
        avatar_binding::avatar_status(
            &fixture.avatars,
            fixture.avatar_id,
        ) == avatar_binding::status_active(),
        201,
    );

    assert!(
        avatar_binding::avatar_identity_binding_id(
            &fixture.avatars,
            fixture.avatar_id,
        ) == fixture.avatar_identity_id,
        202,
    );

    assert!(
        avatar_binding::avatar_world_id(
            &fixture.avatars,
            fixture.avatar_id,
        ) == fixture.world_id,
        203,
    );

    assert!(
        avatar_binding::avatar_space_binding_id(
            &fixture.avatars,
            fixture.avatar_id,
        ) == fixture.binding_id,
        204,
    );

    destroy_full_fixture(fixture);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03
   Agent Authority → Capability Assignment Flow
   ============================================================ */

#[test]
fun test_03_agent_authority_capability_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    assert!(
        agent_authority::authority_status(
            &fixture.authorities,
            fixture.authority_id,
        ) == agent_authority::status_active(),
        301,
    );

    assert!(
        agent_authority::is_authority_valid(
            &fixture.authorities,
            fixture.authority_id,
            25,
        ),
        302,
    );

    assert!(
        capability::capability_status(
            &fixture.capabilities,
            fixture.capability_id,
        ) == capability::status_active(),
        303,
    );

    assert!(
        capability::assignment_status(
            &fixture.capabilities,
            fixture.authority_assignment_id,
        ) == capability::status_active(),
        304,
    );

    assert!(
        capability::is_assignment_valid(
            &fixture.capabilities,
            &fixture.authorities,
            fixture.authority_assignment_id,
            25,
        ),
        305,
    );

    destroy_full_fixture(fixture);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04
   Delegated Agent → Capability Flow
   ============================================================ */

#[test]
fun test_04_delegated_agent_capability_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    assert!(
        agent_authority::delegation_status(
            &fixture.authorities,
            fixture.delegation_id,
        ) == agent_authority::status_active(),
        401,
    );

    assert!(
        agent_authority::is_delegation_valid(
            &fixture.authorities,
            fixture.delegation_id,
            25,
        ),
        402,
    );

    assert!(
        capability::assignment_status(
            &fixture.capabilities,
            fixture.delegation_assignment_id,
        ) == capability::status_active(),
        403,
    );

    assert!(
        capability::is_assignment_valid(
            &fixture.capabilities,
            &fixture.authorities,
            fixture.delegation_assignment_id,
            25,
        ),
        404,
    );

    destroy_full_fixture(fixture);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05
   Authorized Spatial Event Anchor Flow
   ============================================================ */

#[test]
fun test_05_authorized_spatial_event_anchor_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    assert!(
        capability::is_assignment_valid(
            &fixture.capabilities,
            &fixture.authorities,
            fixture.authority_assignment_id,
            25,
        ),
        501,
    );

    /*
     * Use an independent mutable Event Anchor Registry.
     *
     * Move does not permit mutably borrowing one field of
     * `fixture` while simultaneously borrowing other fields
     * from the same fixture.
     */
    let (
        mut event_registry,
        event_admin,
    ) = event_anchor::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let event_id =
        event_anchor::anchor_event(
            &access,
            &mut event_registry,
            &event_admin,

            &fixture.identities,
            &fixture.avatars,
            &fixture.authorities,

            &fixture.worlds,
            &fixture.protocols,

            event_anchor::event_execution(),

            fixture.world_id,
            fixture.binding_id,

            event_anchor::actor_authority(),
            fixture.authority_id,

            fixture.event_protocol_id,

            b"e2e-execution-payload",
            b"e2e-execution-metadata",

            5000,
            25,

            test_scenario::ctx(&mut scenario),
        );

    assert!(event_id == 1, 502);

    assert!(
        event_anchor::anchor_status(
            &event_registry,
            event_id,
        ) == event_anchor::status_active(),
        503,
    );

    assert!(
        event_anchor::verify_anchor(
            &event_registry,
            event_id,
            &b"e2e-execution-payload",
            &b"e2e-execution-metadata",
            5000,
        ),
        504,
    );

    event_anchor::destroy_for_testing(
        event_registry,
    );

    event_anchor::destroy_admin_cap_for_testing(
        event_admin,
    );

    destroy_full_fixture(fixture);

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06
   Revoked Identity Breaks Entry Authorization
   ============================================================ */

#[test]
fun test_06_revoked_identity_breaks_entry_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    /*
     * Independent identity registry avoids mutable aliasing
     * against fields stored inside FullControlPlaneFixture.
     */
    let mut identities =
        identity_binding::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let identity_admin =
        identity_binding::admin_cap_for_testing(
            &identities,
            test_scenario::ctx(&mut scenario),
        );

    let principal_id =
        identity_binding::create_binding(
            &access,
            &mut identities,
            &fixture.tmid_obj,
            identity_binding::identity_user(),
            b"hardening:revoked-user",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(&mut scenario),
        );

    let (mut entries, entry_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut entries,
            &entry_admin,
            &fixture.worlds,
            &fixture.protocols,
            fixture.world_id,
            fixture.binding_id,
            fixture.entry_protocol_id,
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    entry_auth::create_grant(
        &access,
        &mut entries,
        &entry_admin,
        &identities,
        policy_id,
        principal_id,
        0,
        100,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        entry_auth::is_entry_authorized(
            &entries,
            &identities,
            policy_id,
            principal_id,
            25,
        ),
        601,
    );

    identity_binding::revoke_binding(
        &access,
        &mut identities,
        &identity_admin,
        principal_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        identity_binding::binding_status(
            &identities,
            principal_id,
        ) == identity_binding::status_revoked(),
        602,
    );

    assert!(
        !entry_auth::is_entry_authorized(
            &entries,
            &identities,
            policy_id,
            principal_id,
            25,
        ),
        603,
    );

    entry_auth::destroy_for_testing(entries);
    entry_auth::destroy_admin_cap_for_testing(entry_admin);

    identity_binding::destroy_for_testing(identities);
    identity_binding::destroy_admin_cap_for_testing(identity_admin);

    destroy_full_fixture(fixture);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07
   Suspended World Breaks Operational State
   ============================================================ */

#[test]
fun test_07_suspended_world_breaks_downstream_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    /*
     * Independent world registry avoids mutable aliasing
     * against the integrated fixture.
     */
    let (mut worlds, world_admin) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut worlds,
            &world_admin,
            &fixture.spatial_registry,
            &fixture.protocols,
            fixture.root_space_id,
            fixture.entry_protocol_id,
            world_space::world_presence_protocol_id(
                &fixture.worlds,
                fixture.world_id,
            ),
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_world_status(
        &access,
        &mut worlds,
        &world_admin,
        world_id,
        world_space::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        world_space::world_status(
            &worlds,
            world_id,
        ) == world_space::status_suspended(),
        701,
    );

    assert!(
        world_space::world_status(
            &worlds,
            world_id,
        ) != world_space::status_active(),
        702,
    );

    world_space::destroy_for_testing(worlds);
    world_space::destroy_admin_cap_for_testing(world_admin);

    destroy_full_fixture(fixture);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 08
   Deprecated Event Protocol Breaks Event Anchoring
   ============================================================ */

#[test]
#[expected_failure]
fun test_08_deprecated_protocol_breaks_event_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    /*
     * Independent protocol registry allows mutation without
     * aliasing fixture fields.
     */
    let (mut protocols, protocol_admin) =
        protocol_registry::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let event_protocol_id =
        protocol_registry::register_protocol(
            &access,
            &mut protocols,
            &protocol_admin,
            protocol_registry::family_event(),
            b"EVENT-HARDENING",
            1,
            0,
            0,
            b"event-hardening-spec",
            b"event-hardening-compat",
            test_scenario::ctx(&mut scenario),
        );

    protocol_registry::deprecate_protocol(
        &access,
        &mut protocols,
        &protocol_admin,
        event_protocol_id,
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        protocol_registry::is_protocol_deprecated(
            &protocols,
            event_protocol_id,
        ),
        801,
    );

    let (mut events, event_admin) =
        event_anchor::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    /*
     * Must abort because event_protocol_id is deprecated.
     */
    event_anchor::anchor_event(
        &access,
        &mut events,
        &event_admin,

        &fixture.identities,
        &fixture.avatars,
        &fixture.authorities,

        &fixture.worlds,
        &protocols,

        event_anchor::event_execution(),

        fixture.world_id,
        fixture.binding_id,

        event_anchor::actor_authority(),
        fixture.authority_id,

        event_protocol_id,

        b"deprecated-protocol-payload",
        b"deprecated-protocol-meta",

        8000,
        25,

        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09
   Expired Entry Grant Rejected
   ============================================================ */

#[test]
fun test_09_expired_entry_grant_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    /*
     * POLICY_PUBLIC bypasses grant evaluation by design.
     * Therefore use an identity-restricted policy here so
     * grant validity is part of the authorization decision.
     */
    let (mut entries, entry_admin) =
        entry_auth::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let policy_id =
        entry_auth::create_policy(
            &access,
            &mut entries,
            &entry_admin,
            &fixture.worlds,
            &fixture.protocols,
            fixture.world_id,
            fixture.binding_id,
            fixture.entry_protocol_id,
            entry_auth::policy_identity(),
            test_scenario::ctx(&mut scenario),
        );

    let grant_id =
        entry_auth::create_grant(
            &access,
            &mut entries,
            &entry_admin,
            &fixture.identities,
            policy_id,
            fixture.principal_id,
            0,
            100,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        entry_auth::grant_status(
            &entries,
            grant_id,
        ) == entry_auth::status_active(),
        901,
    );

    assert!(
        entry_auth::is_entry_authorized(
            &entries,
            &fixture.identities,
            policy_id,
            fixture.principal_id,
            50,
        ),
        902,
    );

    /*
     * valid_until_epoch = 100.
     * At epoch 101 the grant must no longer authorize entry.
     */
    assert!(
        !entry_auth::is_entry_authorized(
            &entries,
            &fixture.identities,
            policy_id,
            fixture.principal_id,
            101,
        ),
        903,
    );

    entry_auth::destroy_for_testing(entries);
    entry_auth::destroy_admin_cap_for_testing(entry_admin);

    destroy_full_fixture(fixture);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 10
   Expired Delegation Rejected
   ============================================================ */

#[test]
fun test_10_expired_delegation_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    assert!(
        agent_authority::is_delegation_valid(
            &fixture.authorities,
            fixture.delegation_id,
            25,
        ),
        1001,
    );

    assert!(
        !agent_authority::is_delegation_valid(
            &fixture.authorities,
            fixture.delegation_id,
            51,
        ),
        1002,
    );

    assert!(
        !capability::is_assignment_valid(
            &fixture.capabilities,
            &fixture.authorities,
            fixture.delegation_assignment_id,
            51,
        ),
        1003,
    );

    destroy_full_fixture(fixture);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Governance Execution Helper
   ============================================================ */

fun prepare_governance_execution(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
    governance_registry: &mut governance::GovernanceRegistry,
    governance_cap: &governance::GovernanceAdminCap,

    action_type: u64,
    target_id: sui::object::ID,
    payload: vector<u8>,
): (
    u64,
    governance::ExecutionAuthorization,
) {
    let proposal_id =
        governance::submit_proposal(
            access,
            governance_registry,
            action_type,
            b"gsos_control_plane_e2e",
            target_id,
            payload,
            test_scenario::ctx(scenario),
        );

    test_scenario::next_epoch(
        scenario,
        ADMIN,
    );

    governance::open_voting(
        governance_registry,
        governance_cap,
        proposal_id,
        1_000,
        test_scenario::ctx(scenario),
    );

    governance::cast_vote(
        governance_registry,
        proposal_id,
        governance::vote_for(),
        700,
        test_scenario::ctx(scenario),
    );

    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);

    governance::finalize_vote(
        governance_registry,
        proposal_id,
        test_scenario::ctx(scenario),
    );

    governance::queue_proposal(
        governance_registry,
        governance_cap,
        proposal_id,
        test_scenario::ctx(scenario),
    );

    governance::authorize_execution(
        governance_registry,
        governance_cap,
        proposal_id,
        ADMIN,
        test_scenario::ctx(scenario),
    );

    test_scenario::next_epoch(scenario, ADMIN);
    test_scenario::next_epoch(scenario, ADMIN);

    let authorization =
        test_scenario::take_from_sender<
            governance::ExecutionAuthorization
        >(
            scenario,
        );

    (
        proposal_id,
        authorization,
    )
}


/* ============================================================
   Test 11
   Revoked Capability Assignment Rejected
   ============================================================ */

#[test]
fun test_11_revoked_capability_assignment_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    /*
     * Create a local Capability Registry so mutation does not
     * alias fields inside the integrated fixture.
     */
    let (mut capabilities, capability_admin) =
        capability::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let capability_id =
        capability::register_capability(
            &access,
            &mut capabilities,
            &capability_admin,
            &fixture.protocols,
            capability::capability_execute(),
            b"HARDENING_EXECUTE",
            fixture.capability_protocol_id,
            test_scenario::ctx(&mut scenario),
        );

    let assignment_id =
        capability::assign_to_authority(
            &access,
            &mut capabilities,
            &capability_admin,
            &fixture.authorities,
            &fixture.worlds,

            capability_id,
            fixture.authority_id,

            fixture.world_id,
            fixture.binding_id,

            0,
            100,
            0,

            test_scenario::ctx(&mut scenario),
        );

    assert!(
        capability::is_assignment_valid(
            &capabilities,
            &fixture.authorities,
            assignment_id,
            25,
        ),
        1101,
    );

    capability::set_assignment_status(
        &access,
        &mut capabilities,
        &capability_admin,
        assignment_id,
        capability::status_revoked(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        capability::assignment_status(
            &capabilities,
            assignment_id,
        ) == capability::status_revoked(),
        1102,
    );

    assert!(
        !capability::is_assignment_valid(
            &capabilities,
            &fixture.authorities,
            assignment_id,
            25,
        ),
        1103,
    );

    capability::destroy_for_testing(capabilities);
    capability::destroy_admin_cap_for_testing(
        capability_admin,
    );

    destroy_full_fixture(fixture);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 12
   Governance-Controlled Protocol Pause
   ============================================================ */

#[test]
fun test_12_governance_pause_control_flow() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_governance_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,

        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload,
    );

    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,

        &protocol_admin,
        &mut protocols,

        proposal_id,
        true,

        test_scenario::ctx(&mut scenario),
    );

    assert!(
        protocol_registry::is_paused(
            &protocols,
        ),
        1201,
    );

    assert!(
        governance::proposal_status(
            &governance_registry,
            proposal_id,
        ) == governance::status_executed(),
        1202,
    );

    assert!(
        governance::authorization_consumed(
            &authorization,
        ),
        1203,
    );

    governance::destroy_execution_authorization_for_testing(
        authorization,
    );

    protocol_registry::destroy_for_testing(
        protocols,
    );

    protocol_registry::destroy_admin_cap_for_testing(
        protocol_admin,
    );

    governance::destroy_admin_cap_for_testing(
        governance_cap,
    );

    governance::destroy_for_testing(
        governance_registry,
    );

    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 13
   Emergency Mode Blocks GSOS Governance Execution
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 28,
    location = tobmate_foundation::protocol_governance,
)]
fun test_13_emergency_mode_blocks_governance_execution() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_registry =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap =
        governance::admin_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let emergency_cap =
        governance::emergency_cap_for_testing(
            &governance_registry,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_id,
        mut authorization,
    ) = prepare_governance_execution(
        &mut scenario,
        &access,
        &mut governance_registry,
        &governance_cap,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload,
    );

    governance::activate_emergency(
        &mut governance_registry,
        &emergency_cap,
        test_scenario::ctx(&mut scenario),
    );

    /*
     * Authorization already exists, but emergency mode
     * must still block execution.
     */
    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_registry,
        &mut authorization,
        &protocol_admin,
        &mut protocols,
        proposal_id,
        true,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 14
   Cross-Governance Authorization Isolation
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 33,
    location = tobmate_foundation::protocol_governance,
)]
fun test_14_cross_registry_authorization_isolation() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_a =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap_a =
        governance::admin_cap_for_testing(
            &governance_a,
            test_scenario::ctx(&mut scenario),
        );

    let mut governance_b =
        governance::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let governance_cap_b =
        governance::admin_cap_for_testing(
            &governance_b,
            test_scenario::ctx(&mut scenario),
        );

    let (
        mut protocols,
        protocol_admin,
    ) = protocol_registry::create(
        &access,
        test_scenario::ctx(&mut scenario),
    );

    let target_id =
        protocol_registry::registry_id(
            &protocols,
        );

    let payload_a =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_a,
        mut authorization_a,
    ) = prepare_governance_execution(
        &mut scenario,
        &access,
        &mut governance_a,
        &governance_cap_a,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload_a,
    );

    let payload_b =
        gsos_executor::payload_bool_for_testing(
            true,
        );

    let (
        proposal_b,
        authorization_b,
    ) = prepare_governance_execution(
        &mut scenario,
        &access,
        &mut governance_b,
        &governance_cap_b,
        gsos_executor::action_protocol_set_paused(),
        target_id,
        payload_b,
    );

    assert!(
        proposal_a == proposal_b,
        1401,
    );

    /*
     * Authorization from Governance A is intentionally
     * presented to Governance B.
     */
    gsos_executor::execute_protocol_set_paused(
        &access,
        &mut governance_b,
        &mut authorization_a,
        &protocol_admin,
        &mut protocols,
        proposal_b,
        true,
        test_scenario::ctx(&mut scenario),
    );

    governance::destroy_execution_authorization_for_testing(
        authorization_b,
    );

    abort 999
}


/* ============================================================
   Test 15
   Full GSOS Control-Plane Final Invariant Snapshot
   ============================================================ */

#[test]
fun test_15_full_control_plane_invariant_snapshot() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let fixture =
        setup_full_control_plane(
            &mut scenario,
            &access,
        );

    /*
     * Identity invariant.
     */
    assert!(
        identity_binding::binding_status(
            &fixture.identities,
            fixture.principal_id,
        ) == identity_binding::status_active(),
        1501,
    );

    /*
     * GSAP / world invariant.
     */
    assert!(
        world_space::world_status(
            &fixture.worlds,
            fixture.world_id,
        ) == world_space::status_active(),
        1502,
    );

    assert!(
        world_space::binding_status(
            &fixture.worlds,
            fixture.binding_id,
        ) == world_space::status_active(),
        1503,
    );

    /*
     * Protocol invariants.
     */
    assert!(
        protocol_registry::is_protocol_active(
            &fixture.protocols,
            fixture.entry_protocol_id,
        ),
        1504,
    );

    assert!(
        protocol_registry::is_protocol_active(
            &fixture.protocols,
            fixture.avatar_protocol_id,
        ),
        1505,
    );

    assert!(
        protocol_registry::is_protocol_active(
            &fixture.protocols,
            fixture.agent_protocol_id,
        ),
        1506,
    );

    assert!(
        protocol_registry::is_protocol_active(
            &fixture.protocols,
            fixture.capability_protocol_id,
        ),
        1507,
    );

    assert!(
        protocol_registry::is_protocol_active(
            &fixture.protocols,
            fixture.event_protocol_id,
        ),
        1508,
    );

    /*
     * Entry authorization invariant.
     */
    assert!(
        entry_auth::is_entry_authorized(
            &fixture.entry_registry,
            &fixture.identities,
            fixture.policy_id,
            fixture.principal_id,
            25,
        ),
        1509,
    );

    /*
     * Avatar invariant.
     */
    assert!(
        avatar_binding::avatar_status(
            &fixture.avatars,
            fixture.avatar_id,
        ) == avatar_binding::status_active(),
        1510,
    );

    /*
     * Agent authority invariants.
     */
    assert!(
        agent_authority::is_authority_valid(
            &fixture.authorities,
            fixture.authority_id,
            25,
        ),
        1511,
    );

    assert!(
        agent_authority::is_delegation_valid(
            &fixture.authorities,
            fixture.delegation_id,
            25,
        ),
        1512,
    );

    /*
     * Capability invariants.
     */
    assert!(
        capability::is_assignment_valid(
            &fixture.capabilities,
            &fixture.authorities,
            fixture.authority_assignment_id,
            25,
        ),
        1513,
    );

    assert!(
        capability::is_assignment_valid(
            &fixture.capabilities,
            &fixture.authorities,
            fixture.delegation_assignment_id,
            25,
        ),
        1514,
    );

    /*
     * Registry operational invariants.
     */
    assert!(
        !identity_binding::is_paused(
            &fixture.identities,
        ),
        1515,
    );

    assert!(
        !spatial::is_paused(
            &fixture.spatial_registry,
        ),
        1516,
    );

    assert!(
        !protocol_registry::is_paused(
            &fixture.protocols,
        ),
        1517,
    );

    assert!(
        !world_space::is_paused(
            &fixture.worlds,
        ),
        1518,
    );

    assert!(
        !entry_auth::is_paused(
            &fixture.entry_registry,
        ),
        1519,
    );

    assert!(
        !avatar_binding::is_paused(
            &fixture.avatars,
        ),
        1520,
    );

    assert!(
        !agent_authority::is_paused(
            &fixture.authorities,
        ),
        1521,
    );

    assert!(
        !capability::is_paused(
            &fixture.capabilities,
        ),
        1522,
    );

    assert!(
        !event_anchor::is_paused(
            &fixture.event_registry,
        ),
        1523,
    );

    destroy_full_fixture(fixture);
    access_control::destroy_for_testing(access);

    test_scenario::end(scenario);
}
