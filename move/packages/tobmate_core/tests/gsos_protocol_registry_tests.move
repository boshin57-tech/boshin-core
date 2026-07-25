#[test_only]
module tobmate_core::gsos_protocol_registry_tests;

use sui::test_scenario;

use tobmate_core::access_control;
use tobmate_core::gsos_protocol_registry;


/* ============================================================
   Helpers
   ============================================================ */

const ADMIN: address = @0xA11CE;


/* ============================================================
   Test 01 — Create Registry
   ============================================================ */

#[test]
fun test_01_create_registry() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        let access =
            access_control::new_for_testing(ctx);

        let (registry, admin_cap) =
            gsos_protocol_registry::create(
                &access,
                ctx,
            );

        assert!(
            gsos_protocol_registry::version(&registry) == 1,
            1,
        );

        assert!(
            !gsos_protocol_registry::is_paused(&registry),
            2,
        );

        assert!(
            gsos_protocol_registry::next_protocol_id(&registry) == 1,
            3,
        );

        assert!(
            gsos_protocol_registry::total_registered(&registry) == 0,
            4,
        );

        assert!(
            gsos_protocol_registry::total_deprecated(&registry) == 0,
            5,
        );

        assert!(
            gsos_protocol_registry::active_protocol_count(&registry) == 0,
            6,
        );
        access_control::destroy_for_testing(access);
        gsos_protocol_registry::destroy_for_testing(registry);

        gsos_protocol_registry::destroy_admin_cap_for_testing(
            admin_cap,
        );
    };

    test_scenario::end(scenario);
}


/* ============================================================
   Test 02 — Register Protocol
   ============================================================ */

#[test]
fun test_02_register_protocol() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        let access =
            access_control::new_for_testing(ctx);

        let (mut registry, admin_cap) =
            gsos_protocol_registry::create(
                &access,
                ctx,
            );

        let protocol_id =
            gsos_protocol_registry::register_protocol(
                &access,
                &mut registry,
                &admin_cap,
                gsos_protocol_registry::family_gsap(),
                b"GSAP Core",
                1,
                0,
                0,
                b"spec-hash-001",
                b"compat-hash-001",
                ctx,
            );

        assert!(protocol_id == 1, 10);

        assert!(
            gsos_protocol_registry::protocol_exists(
                &registry,
                protocol_id,
            ),
            11,
        );

        assert!(
            gsos_protocol_registry::is_protocol_active(
                &registry,
                protocol_id,
            ),
            12,
        );

        assert!(
            gsos_protocol_registry::total_registered(
                &registry,
            ) == 1,
            13,
        );

        assert!(
            gsos_protocol_registry::active_protocol_count(
                &registry,
            ) == 1,
            14,
        );

        assert!(
            gsos_protocol_registry::next_protocol_id(
                &registry,
            ) == 2,
            15,
        );
        access_control::destroy_for_testing(access);
        gsos_protocol_registry::destroy_for_testing(registry);
        gsos_protocol_registry::destroy_admin_cap_for_testing(admin_cap);
    };

    test_scenario::end(scenario);
}


/* ============================================================
   Test 03 — Deprecate Protocol
   ============================================================ */

#[test]
fun test_03_deprecate_protocol() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        let access =
            access_control::new_for_testing(ctx);

        let (mut registry, admin_cap) =
            gsos_protocol_registry::create(
                &access,
                ctx,
            );

        let protocol_id =
            gsos_protocol_registry::register_protocol(
                &access,
                &mut registry,
                &admin_cap,
                gsos_protocol_registry::family_entry(),
                b"GSOS Entry",
                1,
                0,
                0,
                b"spec-entry-001",
                b"compat-entry-001",
                ctx,
            );

        gsos_protocol_registry::deprecate_protocol(
            &access,
            &mut registry,
            &admin_cap,
            protocol_id,
            ctx,
        );

        assert!(
            gsos_protocol_registry::is_protocol_deprecated(
                &registry,
                protocol_id,
            ),
            20,
        );

        assert!(
            gsos_protocol_registry::total_deprecated(
                &registry,
            ) == 1,
            21,
        );

        assert!(
            gsos_protocol_registry::active_protocol_count(
                &registry,
            ) == 0,
            22,
        );
        access_control::destroy_for_testing(access);
        gsos_protocol_registry::destroy_for_testing(registry);
        gsos_protocol_registry::destroy_admin_cap_for_testing(admin_cap);
    };

    test_scenario::end(scenario);
}


/* ============================================================
   Test 04 — Version Lookup
   ============================================================ */

#[test]
fun test_04_active_version_lookup() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        let access =
            access_control::new_for_testing(ctx);

        let (mut registry, admin_cap) =
            gsos_protocol_registry::create(
                &access,
                ctx,
            );

        let protocol_id =
            gsos_protocol_registry::register_protocol(
                &access,
                &mut registry,
                &admin_cap,
                gsos_protocol_registry::family_presence(),
                b"Presence Protocol",
                2,
                1,
                3,
                b"spec-presence-213",
                b"compat-presence-213",
                ctx,
            );

        assert!(
            gsos_protocol_registry::is_active_version(
                &registry,
                gsos_protocol_registry::family_presence(),
                2,
                1,
                3,
            ),
            30,
        );

        assert!(
            gsos_protocol_registry::active_protocol_id_by_version(
                &registry,
                gsos_protocol_registry::family_presence(),
                2,
                1,
                3,
            ) == protocol_id,
            31,
        );
        access_control::destroy_for_testing(access);
        gsos_protocol_registry::destroy_for_testing(registry);
        gsos_protocol_registry::destroy_admin_cap_for_testing(admin_cap);
    };

    test_scenario::end(scenario);
}


/* ============================================================
   Test 05 — Pause / Unpause
   ============================================================ */

#[test]
fun test_05_pause_unpause() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        let access =
            access_control::new_for_testing(ctx);

        let (mut registry, admin_cap) =
            gsos_protocol_registry::create(
                &access,
                ctx,
            );

        gsos_protocol_registry::set_paused(
            &access,
            &mut registry,
            &admin_cap,
            true,
            ctx,
        );

        assert!(
            gsos_protocol_registry::is_paused(&registry),
            40,
        );

        gsos_protocol_registry::set_paused(
            &access,
            &mut registry,
            &admin_cap,
            false,
            ctx,
        );

        assert!(
            !gsos_protocol_registry::is_paused(&registry),
            41,
        );
        access_control::destroy_for_testing(access);
        gsos_protocol_registry::destroy_for_testing(registry);
        gsos_protocol_registry::destroy_admin_cap_for_testing(admin_cap);
    };

    test_scenario::end(scenario);
}


/* ============================================================
   Test 06 — Registry Version
   ============================================================ */

#[test]
fun test_06_registry_version() {
    let mut scenario = test_scenario::begin(ADMIN);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        let access =
            access_control::new_for_testing(ctx);

        let (mut registry, admin_cap) =
            gsos_protocol_registry::create(
                &access,
                ctx,
            );

        gsos_protocol_registry::set_version(
            &access,
            &mut registry,
            &admin_cap,
            2,
            ctx,
        );

        assert!(
            gsos_protocol_registry::version(&registry) == 2,
            50,
        );
        access_control::destroy_for_testing(access);
        gsos_protocol_registry::destroy_for_testing(registry);
        gsos_protocol_registry::destroy_admin_cap_for_testing(admin_cap);
    };

    test_scenario::end(scenario);
}


/* ============================================================
   Test 07 — Duplicate Active Version Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 6, location = tobmate_core::gsos_protocol_registry)]
fun test_07_duplicate_active_version_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::register_protocol(
        &access,
        &mut registry,
        &admin_cap,
        gsos_protocol_registry::family_gsap(),
        b"GSAP Core",
        1,
        0,
        0,
        b"spec-gsap-100-a",
        b"compat-gsap-100-a",
        ctx,
    );

    gsos_protocol_registry::register_protocol(
        &access,
        &mut registry,
        &admin_cap,
        gsos_protocol_registry::family_gsap(),
        b"GSAP Duplicate",
        1,
        0,
        0,
        b"spec-gsap-100-b",
        b"compat-gsap-100-b",
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 08 — Invalid Family Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 2, location = tobmate_core::gsos_protocol_registry)]
fun test_08_invalid_family_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::register_protocol(
        &access,
        &mut registry,
        &admin_cap,
        99,
        b"Invalid Protocol",
        1,
        0,
        0,
        b"spec-invalid-family",
        b"compat-invalid-family",
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 09 — Already Deprecated Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 8, location = tobmate_core::gsos_protocol_registry)]
fun test_09_already_deprecated_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    let protocol_id =
        gsos_protocol_registry::register_protocol(
            &access,
            &mut registry,
            &admin_cap,
            gsos_protocol_registry::family_entry(),
            b"GSOS Entry",
            1,
            0,
            0,
            b"spec-entry-100",
            b"compat-entry-100",
            ctx,
        );

    gsos_protocol_registry::deprecate_protocol(
        &access,
        &mut registry,
        &admin_cap,
        protocol_id,
        ctx,
    );

    gsos_protocol_registry::deprecate_protocol(
        &access,
        &mut registry,
        &admin_cap,
        protocol_id,
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 10 — Paused Registry Blocks Registration
   ============================================================ */

#[test]
#[expected_failure(abort_code = 1, location = tobmate_core::gsos_protocol_registry)]
fun test_10_paused_registry_blocks_registration() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        true,
        ctx,
    );

    gsos_protocol_registry::register_protocol(
        &access,
        &mut registry,
        &admin_cap,
        gsos_protocol_registry::family_avatar(),
        b"Avatar Protocol",
        1,
        0,
        0,
        b"spec-avatar-100",
        b"compat-avatar-100",
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 11 — Admin Cap Mismatch Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 11, location = tobmate_core::gsos_protocol_registry)]
fun test_11_admin_cap_mismatch_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry_a, _admin_cap_a) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    let (_registry_b, admin_cap_b) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::register_protocol(
        &access,
        &mut registry_a,
        &admin_cap_b,
        gsos_protocol_registry::family_agent(),
        b"Agent Protocol",
        1,
        0,
        0,
        b"spec-agent-100",
        b"compat-agent-100",
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 12 — Unchanged Pause State Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 9, location = tobmate_core::gsos_protocol_registry)]
fun test_12_unchanged_pause_state_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::set_paused(
        &access,
        &mut registry,
        &admin_cap,
        false,
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 13 — Unchanged Registry Version Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 10, location = tobmate_core::gsos_protocol_registry)]
fun test_13_unchanged_registry_version_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::set_version(
        &access,
        &mut registry,
        &admin_cap,
        1,
        ctx,
    );

    abort 999
}


/* ============================================================
   Test 14 — Missing Protocol Lookup Rejected
   ============================================================ */

#[test]
#[expected_failure(abort_code = 7, location = tobmate_core::gsos_protocol_registry)]
fun test_14_missing_protocol_lookup_rejected() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (registry, _admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    gsos_protocol_registry::protocol_status(
        &registry,
        999,
    );

    abort 999
}


/* ============================================================
   Test 15 — Deprecated Version Can Be Re-Registered
   ============================================================ */

#[test]
fun test_15_deprecated_version_can_be_reregistered() {
    let mut scenario = test_scenario::begin(ADMIN);

    let ctx = test_scenario::ctx(&mut scenario);

    let access =
        access_control::new_for_testing(ctx);

    let (mut registry, admin_cap) =
        gsos_protocol_registry::create(
            &access,
            ctx,
        );

    let first_id =
        gsos_protocol_registry::register_protocol(
            &access,
            &mut registry,
            &admin_cap,
            gsos_protocol_registry::family_gsap(),
            b"GSAP Core Original",
            1,
            0,
            0,
            b"spec-gsap-original",
            b"compat-gsap-original",
            ctx,
        );

    gsos_protocol_registry::deprecate_protocol(
        &access,
        &mut registry,
        &admin_cap,
        first_id,
        ctx,
    );

    let second_id =
        gsos_protocol_registry::register_protocol(
            &access,
            &mut registry,
            &admin_cap,
            gsos_protocol_registry::family_gsap(),
            b"GSAP Core Replacement",
            1,
            0,
            0,
            b"spec-gsap-replacement",
            b"compat-gsap-replacement",
            ctx,
        );

    assert!(second_id == 2, 150);

    assert!(
        gsos_protocol_registry::is_protocol_deprecated(
            &registry,
            first_id,
        ),
        151,
    );

    assert!(
        gsos_protocol_registry::is_protocol_active(
            &registry,
            second_id,
        ),
        152,
    );

    assert!(
        gsos_protocol_registry::active_protocol_count(
            &registry,
        ) == 1,
        153,
    );

    assert!(
        gsos_protocol_registry::total_registered(
            &registry,
        ) == 2,
        154,
    );

    assert!(
        gsos_protocol_registry::total_deprecated(
            &registry,
        ) == 1,
        155,
    );

    access_control::destroy_for_testing(access);
    gsos_protocol_registry::destroy_for_testing(registry);
    gsos_protocol_registry::destroy_admin_cap_for_testing(admin_cap);

    test_scenario::end(scenario);
}
