#[test_only]
module tobmate_integration_tests::gsos_world_space_registry_tests;

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


const ADMIN: address = @0xA11CE;


/* ============================================================
   Helper — Create Canonical GSAP World Space
   ============================================================ */

fun setup_gsap_world(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
): (
    tmid::TMID,
    identity_binding::GSOSIdentityRegistry,
    spatial::GSAPSpatialRegistry,
    u64,
) {
    let tmid_obj =
        tmid::new_for_testing(
            ADMIN,
            1,
            test_scenario::ctx(scenario),
        );

    let mut identity_registry =
        identity_binding::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let identity_id =
        identity_binding::create_binding(
            access,
            &mut identity_registry,
            &tmid_obj,
            identity_binding::identity_user(),
            b"world-admin",
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            test_scenario::ctx(scenario),
        );

    let mut spatial_registry =
        spatial::new_for_testing(
            test_scenario::ctx(scenario),
        );

    let root_space_id =
        spatial::register_space(
            access,
            &mut spatial_registry,
            &identity_registry,
            identity_id,
            b"gsap://earth/au/qld/bundaberg/tobmate-world",
            b"earth/au/qld/bundaberg",
            b"tobmate-world",
            spatial::space_world(),
            0,
            test_scenario::ctx(scenario),
        );

    (
        tmid_obj,
        identity_registry,
        spatial_registry,
        root_space_id,
    )
}


/* ============================================================
   Helper — Create Protocol Set
   ============================================================ */

fun setup_protocols(
    scenario: &mut test_scenario::Scenario,
    access: &access_control::AccessControl,
): (
    protocol_registry::GSOSProtocolRegistry,
    protocol_registry::GSOSProtocolAdminCap,
    u64,
    u64,
    u64,
) {
    let ctx = test_scenario::ctx(scenario);

    let (mut protocols, admin_cap) =
        protocol_registry::create(
            access,
            ctx,
        );

    let entry_id =
        protocol_registry::register_protocol(
            access,
            &mut protocols,
            &admin_cap,
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
            &admin_cap,
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
            &admin_cap,
            protocol_registry::family_capability(),
            b"CAPABILITY",
            1,
            0,
            0,
            b"capability-spec",
            b"capability-compat",
            ctx,
        );

    (
        protocols,
        admin_cap,
        entry_id,
        presence_id,
        capability_id,
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
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    assert!(world_space::version(&registry) == 1, 1);
    assert!(!world_space::is_paused(&registry), 2);
    assert!(world_space::total_worlds(&registry) == 0, 3);
    assert!(world_space::total_space_bindings(&registry) == 0, 4);

    access_control::destroy_for_testing(access);
    world_space::destroy_for_testing(registry);
    world_space::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Register World
   ============================================================ */

#[test]
fun test_02_register_world() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(world_id == 1, 10);
    assert!(
        world_space::world_status(
            &registry,
            world_id,
        ) == world_space::status_active(),
        11,
    );
    assert!(
        world_space::active_world_count(
            &registry,
        ) == 1,
        12,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    access_control::destroy_for_testing(access);
    world_space::destroy_for_testing(registry);
    world_space::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Bind Space
   ============================================================ */

#[test]
fun test_03_bind_space() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        protocol_admin,
        entry_id,
        presence_id,
        capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        world_space::bind_space(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            world_id,
            root_space_id,
            entry_id,
            presence_id,
            capability_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(binding_id == 1, 20);
    assert!(
        world_space::binding_world_id(
            &registry,
            binding_id,
        ) == world_id,
        21,
    );
    assert!(
        world_space::binding_status(
            &registry,
            binding_id,
        ) == world_space::status_active(),
        22,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    access_control::destroy_for_testing(access);
    world_space::destroy_for_testing(registry);
    world_space::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — World Suspend / Reactivate
   ============================================================ */

#[test]
fun test_04_world_status_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_world_status(
        &access,
        &mut registry,
        &admin_cap,
        world_id,
        world_space::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        world_space::active_world_count(&registry) == 0,
        30,
    );

    world_space::set_world_status(
        &access,
        &mut registry,
        &admin_cap,
        world_id,
        world_space::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        world_space::active_world_count(&registry) == 1,
        31,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    access_control::destroy_for_testing(access);
    world_space::destroy_for_testing(registry);
    world_space::destroy_admin_cap_for_testing(admin_cap);

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
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    assert!(world_space::is_paused(&registry), 40);

    world_space::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        false,
        test_scenario::ctx(&mut scenario),
    );

    world_space::set_version(
        &access,
        &mut registry,
        &admin_cap,
        2,
        test_scenario::ctx(&mut scenario),
    );

    assert!(world_space::version(&registry) == 2, 41);

    access_control::destroy_for_testing(access);
    world_space::destroy_for_testing(registry);
    world_space::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Duplicate World Root Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 6, location = tobmate_gsos::gsos_world_space_registry)]
fun test_06_duplicate_world_root_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    world_space::register_world(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        root_space_id,
        entry_id,
        presence_id,
        test_scenario::ctx(&mut scenario),
    );

    world_space::register_world(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        root_space_id,
        entry_id,
        presence_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 07 — Duplicate Space Binding Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 7, location = tobmate_gsos::gsos_world_space_registry)]
fun test_07_duplicate_space_binding_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    world_space::bind_space(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        world_id,
        root_space_id,
        entry_id,
        presence_id,
        capability_id,
        test_scenario::ctx(&mut scenario),
    );

    world_space::bind_space(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        world_id,
        root_space_id,
        entry_id,
        presence_id,
        capability_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 08 — Wrong ENTRY Family Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 3, location = tobmate_gsos::gsos_world_space_registry)]
fun test_08_wrong_entry_protocol_family_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        _entry_id,
        presence_id,
        capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    world_space::register_world(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        root_space_id,
        capability_id,
        presence_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 09 — Wrong CAPABILITY Family Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 3, location = tobmate_gsos::gsos_world_space_registry)]
fun test_09_wrong_capability_protocol_family_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    world_space::bind_space(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        world_id,
        root_space_id,
        entry_id,
        presence_id,
        presence_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 10 — Suspended World Blocks Binding
   ============================================================ */

#[test]
#[expected_failure(abort_code = 8, location = tobmate_gsos::gsos_world_space_registry)]
fun test_10_suspended_world_blocks_binding() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_world_status(
        &access,
        &mut registry,
        &admin_cap,
        world_id,
        world_space::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    world_space::bind_space(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        world_id,
        root_space_id,
        entry_id,
        presence_id,
        capability_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 11 — Admin Cap Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 12, location = tobmate_gsos::gsos_world_space_registry)]
fun test_11_admin_cap_mismatch_rejected() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry_a, _admin_a) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let (_registry_b, admin_b) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    world_space::register_world(
        &access,
        &mut registry_a,
        &admin_b,
        &spatial_registry,
        &protocols,
        root_space_id,
        entry_id,
        presence_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 12 — Deprecated World Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(abort_code = 9, location = tobmate_gsos::gsos_world_space_registry)]
fun test_12_deprecated_world_cannot_reactivate() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_world_status(
        &access,
        &mut registry,
        &admin_cap,
        world_id,
        world_space::status_deprecated(),
        test_scenario::ctx(&mut scenario),
    );

    world_space::set_world_status(
        &access,
        &mut registry,
        &admin_cap,
        world_id,
        world_space::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 13 — Space Binding Suspend / Reactivate
   ============================================================ */

#[test]
fun test_13_space_binding_status_lifecycle() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        tmid_obj,
        identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        protocol_admin,
        entry_id,
        presence_id,
        capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        world_space::bind_space(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            world_id,
            root_space_id,
            entry_id,
            presence_id,
            capability_id,
            test_scenario::ctx(&mut scenario),
        );

    assert!(
        world_space::active_space_binding_count(
            &registry,
        ) == 1,
        130,
    );

    world_space::set_space_binding_status(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        world_space::status_suspended(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        world_space::binding_status(
            &registry,
            binding_id,
        ) == world_space::status_suspended(),
        131,
    );

    assert!(
        world_space::active_space_binding_count(
            &registry,
        ) == 0,
        132,
    );

    world_space::set_space_binding_status(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        world_space::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    assert!(
        world_space::binding_status(
            &registry,
            binding_id,
        ) == world_space::status_active(),
        133,
    );

    assert!(
        world_space::active_space_binding_count(
            &registry,
        ) == 1,
        134,
    );

    tmid::destroy_for_testing(tmid_obj);
    identity_binding::destroy_for_testing(identity_registry);
    spatial::destroy_for_testing(spatial_registry);
    protocol_registry::destroy_for_testing(protocols);
    protocol_registry::destroy_admin_cap_for_testing(protocol_admin);
    access_control::destroy_for_testing(access);
    world_space::destroy_for_testing(registry);
    world_space::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}


/* ============================================================
   Test 14 — Deprecated Space Binding Cannot Reactivate
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 9,
    location = tobmate_gsos::gsos_world_space_registry
)]
fun test_14_deprecated_binding_cannot_reactivate() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    let world_id =
        world_space::register_world(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            root_space_id,
            entry_id,
            presence_id,
            test_scenario::ctx(&mut scenario),
        );

    let binding_id =
        world_space::bind_space(
            &access,
            &mut registry,
            &admin_cap,
            &spatial_registry,
            &protocols,
            world_id,
            root_space_id,
            entry_id,
            presence_id,
            capability_id,
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_space_binding_status(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        world_space::status_deprecated(),
        test_scenario::ctx(&mut scenario),
    );

    world_space::set_space_binding_status(
        &access,
        &mut registry,
        &admin_cap,
        binding_id,
        world_space::status_active(),
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}


/* ============================================================
   Test 15 — Paused Registry Blocks World Registration
   ============================================================ */

#[test]
#[expected_failure(
    abort_code = 1,
    location = tobmate_gsos::gsos_world_space_registry
)]
fun test_15_paused_registry_blocks_world_registration() {
    let mut scenario =
        test_scenario::begin(ADMIN);

    let access =
        access_control::new_for_testing(
            test_scenario::ctx(&mut scenario),
        );

    let (
        _tmid_obj,
        _identity_registry,
        spatial_registry,
        root_space_id,
    ) = setup_gsap_world(
        &mut scenario,
        &access,
    );

    let (
        protocols,
        _protocol_admin,
        entry_id,
        presence_id,
        _capability_id,
    ) = setup_protocols(
        &mut scenario,
        &access,
    );

    let (mut registry, admin_cap) =
        world_space::create(
            &access,
            test_scenario::ctx(&mut scenario),
        );

    world_space::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        test_scenario::ctx(&mut scenario),
    );

    world_space::register_world(
        &access,
        &mut registry,
        &admin_cap,
        &spatial_registry,
        &protocols,
        root_space_id,
        entry_id,
        presence_id,
        test_scenario::ctx(&mut scenario),
    );

    abort 999
}
