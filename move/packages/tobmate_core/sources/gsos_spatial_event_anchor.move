module tobmate_core::gsos_spatial_event_anchor;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::gsos_identity_binding::{
    Self as identity_binding,
    GSOSIdentityRegistry,
};

use tobmate_core::gsos_protocol_registry::{
    Self as protocol_registry,
    GSOSProtocolRegistry,
};

use tobmate_core::gsos_world_space_registry::{
    Self as world_space,
    GSOSWorldSpaceRegistry,
};

use tobmate_core::gsos_agent_authority::{
    Self as agent_authority,
    GSOSAgentAuthorityRegistry,
};

use tobmate_core::gsos_avatar_identity_binding::{
    Self as avatar_binding,
    GSOSAvatarBindingRegistry,
};


/* ============================================================
   Stage 11 Part 9
   GSOS Spatial Event Anchoring
   Blockchain Control Plane
   ============================================================ */

const REGISTRY_VERSION: u64 = 1;


/* ============================================================
   Event Types
   ============================================================ */

const EVENT_ENTRY: u8 = 1;
const EVENT_EXIT: u8 = 2;
const EVENT_PRESENCE: u8 = 3;
const EVENT_INTERACTION: u8 = 4;
const EVENT_EXECUTION: u8 = 5;
const EVENT_ASSET: u8 = 6;
const EVENT_GOVERNANCE: u8 = 7;


/* ============================================================
   Actor Kinds
   ============================================================ */

const ACTOR_IDENTITY: u8 = 1;
const ACTOR_AVATAR: u8 = 2;
const ACTOR_AUTHORITY: u8 = 3;
const ACTOR_DELEGATION: u8 = 4;
const ACTOR_SYSTEM: u8 = 5;


/* ============================================================
   Anchor Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_INVALIDATED: u8 = 2;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_EVENT_TYPE: u64 = 2;
const E_INVALID_ACTOR_KIND: u64 = 3;
const E_INVALID_WORLD_ID: u64 = 4;
const E_INVALID_SPACE_BINDING_ID: u64 = 5;
const E_WORLD_SPACE_MISMATCH: u64 = 6;
const E_INVALID_EVENT_PROTOCOL: u64 = 7;
const E_EMPTY_PAYLOAD_HASH: u64 = 8;
const E_EMPTY_METADATA_HASH: u64 = 9;
const E_INVALID_ACTOR_REFERENCE: u64 = 10;
const E_ACTOR_SCOPE_MISMATCH: u64 = 11;
const E_DUPLICATE_EVENT_ANCHOR: u64 = 12;
const E_ANCHOR_NOT_FOUND: u64 = 13;
const E_ALREADY_INVALIDATED: u64 = 14;
const E_STATE_UNCHANGED: u64 = 15;
const E_VERSION_UNCHANGED: u64 = 16;
const E_ADMIN_CAP_MISMATCH: u64 = 17;


/* ============================================================
   Registry
   ============================================================ */

public struct GSOSSpatialEventAnchorRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_event_id: u64,

    anchors: vector<SpatialEventAnchor>,

    total_anchored: u64,
    total_invalidated: u64,
    active_anchor_count: u64,
}


/* ============================================================
   Administrative Capability
   ============================================================ */

public struct GSOSSpatialEventAnchorAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Spatial Event Anchor

   The original payload is NOT stored on-chain.

   payload_hash:
     cryptographic commitment to the original event payload.

   metadata_hash:
     cryptographic commitment to external metadata / telemetry.

   source_timestamp:
     source-system timestamp supplied by GSOS.

   anchored_epoch:
     blockchain epoch when the anchor was committed.
   ============================================================ */

public struct SpatialEventAnchor has store {
    event_id: u64,

    event_type: u8,

    world_id: u64,
    space_binding_id: u64,

    actor_kind: u8,
    actor_reference_id: u64,

    event_protocol_id: u64,

    payload_hash: vector<u8>,
    metadata_hash: vector<u8>,

    source_timestamp: u64,

    anchored_epoch: u64,
    updated_epoch: u64,

    status: u8,
}


/* ============================================================
   Events
   ============================================================ */

public struct SpatialEventAnchored has copy, drop {
    registry_id: ID,

    event_id: u64,
    event_type: u8,

    world_id: u64,
    space_binding_id: u64,

    actor_kind: u8,
    actor_reference_id: u64,

    event_protocol_id: u64,

    source_timestamp: u64,
    anchored_epoch: u64,

    anchored_by: address,
}

public struct SpatialEventAnchorInvalidated has copy, drop {
    registry_id: ID,
    event_id: u64,

    invalidated_by: address,
    invalidated_epoch: u64,
}

public struct SpatialEventAnchorPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct SpatialEventAnchorVersionChanged has copy, drop {
    registry_id: ID,

    previous_version: u64,
    new_version: u64,

    changed_by: address,
}


/* ============================================================
   Registry Creation
   ============================================================ */

public fun create(
    access: &AccessControl,
    ctx: &mut TxContext,
): (
    GSOSSpatialEventAnchorRegistry,
    GSOSSpatialEventAnchorAdminCap,
) {
    access_control::assert_not_paused(access);

    let registry = GSOSSpatialEventAnchorRegistry {
        id: object::new(ctx),

        version: REGISTRY_VERSION,
        paused: false,

        next_event_id: 1,

        anchors: vector[],

        total_anchored: 0,
        total_invalidated: 0,
        active_anchor_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = GSOSSpatialEventAnchorAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Core Validation
   ============================================================ */

fun assert_registry_not_paused(
    registry: &GSOSSpatialEventAnchorRegistry,
) {
    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &GSOSSpatialEventAnchorRegistry,
    admin_cap: &GSOSSpatialEventAnchorAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_event_type(
    event_type: u8,
) {
    assert!(
        event_type >= EVENT_ENTRY
            && event_type <= EVENT_GOVERNANCE,
        E_INVALID_EVENT_TYPE,
    );
}

fun assert_valid_actor_kind(
    actor_kind: u8,
) {
    assert!(
        actor_kind >= ACTOR_IDENTITY
            && actor_kind <= ACTOR_SYSTEM,
        E_INVALID_ACTOR_KIND,
    );
}


/* ============================================================
   World / Space Validation
   ============================================================ */

fun assert_world_space(
    worlds: &GSOSWorldSpaceRegistry,
    world_id: u64,
    space_binding_id: u64,
) {
    assert!(
        world_id != 0,
        E_INVALID_WORLD_ID,
    );

    assert!(
        world_space::world_status(
            worlds,
            world_id,
        ) == world_space::status_active(),
        E_INVALID_WORLD_ID,
    );

    if (space_binding_id == 0) {
        return
    };

    assert!(
        world_space::binding_status(
            worlds,
            space_binding_id,
        ) == world_space::status_active(),
        E_INVALID_SPACE_BINDING_ID,
    );

    assert!(
        world_space::binding_world_id(
            worlds,
            space_binding_id,
        ) == world_id,
        E_WORLD_SPACE_MISMATCH,
    );
}


/* ============================================================
   EVENT Protocol Validation
   ============================================================ */

fun assert_event_protocol(
    protocols: &GSOSProtocolRegistry,
    event_protocol_id: u64,
) {
    assert!(
        event_protocol_id != 0,
        E_INVALID_EVENT_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_exists(
            protocols,
            event_protocol_id,
        ),
        E_INVALID_EVENT_PROTOCOL,
    );

    assert!(
        protocol_registry::is_protocol_active(
            protocols,
            event_protocol_id,
        ),
        E_INVALID_EVENT_PROTOCOL,
    );

    assert!(
        protocol_registry::protocol_family(
            protocols,
            event_protocol_id,
        ) == protocol_registry::family_event(),
        E_INVALID_EVENT_PROTOCOL,
    );
}


/* ============================================================
   Actor Validation
   ============================================================ */

fun assert_actor_reference(
    identities: &GSOSIdentityRegistry,
    avatars: &GSOSAvatarBindingRegistry,
    authorities: &GSOSAgentAuthorityRegistry,

    actor_kind: u8,
    actor_reference_id: u64,

    world_id: u64,
    space_binding_id: u64,

    current_epoch: u64,
) {
    if (actor_kind == ACTOR_SYSTEM) {
        assert!(
            actor_reference_id == 0,
            E_INVALID_ACTOR_REFERENCE,
        );

        return
    };

    assert!(
        actor_reference_id != 0,
        E_INVALID_ACTOR_REFERENCE,
    );

    if (actor_kind == ACTOR_IDENTITY) {
        assert!(
            identity_binding::binding_exists(
                identities,
                actor_reference_id,
            ),
            E_INVALID_ACTOR_REFERENCE,
        );

        assert!(
            identity_binding::binding_status(
                identities,
                actor_reference_id,
            ) == identity_binding::status_active(),
            E_INVALID_ACTOR_REFERENCE,
        );

        return
    };

    if (actor_kind == ACTOR_AVATAR) {
        assert!(
            avatar_binding::avatar_status(
                avatars,
                actor_reference_id,
            ) == avatar_binding::status_active(),
            E_INVALID_ACTOR_REFERENCE,
        );

        assert!(
            avatar_binding::avatar_world_id(
                avatars,
                actor_reference_id,
            ) == world_id,
            E_ACTOR_SCOPE_MISMATCH,
        );

        assert!(
            avatar_binding::avatar_space_binding_id(
                avatars,
                actor_reference_id,
            ) == space_binding_id,
            E_ACTOR_SCOPE_MISMATCH,
        );

        return
    };

    if (actor_kind == ACTOR_AUTHORITY) {
        assert!(
            agent_authority::authority_status(
                authorities,
                actor_reference_id,
            ) == agent_authority::status_active(),
            E_INVALID_ACTOR_REFERENCE,
        );

        assert!(
            agent_authority::is_authority_valid(
                authorities,
                actor_reference_id,
                current_epoch,
            ),
            E_INVALID_ACTOR_REFERENCE,
        );

        assert!(
            agent_authority::authority_world_id(
                authorities,
                actor_reference_id,
            ) == world_id,
            E_ACTOR_SCOPE_MISMATCH,
        );

        let authority_space =
            agent_authority::authority_space_binding_id(
                authorities,
                actor_reference_id,
            );

        if (authority_space != 0) {
            assert!(
                authority_space == space_binding_id,
                E_ACTOR_SCOPE_MISMATCH,
            );
        };

        return
    };

    assert!(
        agent_authority::delegation_status(
            authorities,
            actor_reference_id,
        ) == agent_authority::status_active(),
        E_INVALID_ACTOR_REFERENCE,
    );

    assert!(
        agent_authority::is_delegation_valid(
            authorities,
            actor_reference_id,
            current_epoch,
        ),
        E_INVALID_ACTOR_REFERENCE,
    );

    assert!(
        agent_authority::delegation_world_id(
            authorities,
            actor_reference_id,
        ) == world_id,
        E_ACTOR_SCOPE_MISMATCH,
    );

    let delegation_space =
        agent_authority::delegation_space_binding_id(
            authorities,
            actor_reference_id,
        );

    if (delegation_space != 0) {
        assert!(
            delegation_space == space_binding_id,
            E_ACTOR_SCOPE_MISMATCH,
        );
    };
}


/* ============================================================
   Anchor Lookup
   ============================================================ */

fun anchor_index(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u64 {
    let length =
        vector::length(&registry.anchors);

    let mut i = 0;

    while (i < length) {
        let anchor =
            vector::borrow(
                &registry.anchors,
                i,
            );

        if (anchor.event_id == event_id) {
            return i
        };

        i = i + 1;
    };

    abort E_ANCHOR_NOT_FOUND
}

fun borrow_anchor_internal(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): &SpatialEventAnchor {
    let index =
        anchor_index(
            registry,
            event_id,
        );

    vector::borrow(
        &registry.anchors,
        index,
    )
}


/* ============================================================
   Duplicate Anchor Guard

   Same payload + metadata + world/space + actor + timestamp
   may not be anchored twice while active.
   ============================================================ */

fun assert_no_duplicate_active_anchor(
    registry: &GSOSSpatialEventAnchorRegistry,

    event_type: u8,

    world_id: u64,
    space_binding_id: u64,

    actor_kind: u8,
    actor_reference_id: u64,

    event_protocol_id: u64,

    payload_hash: &vector<u8>,
    metadata_hash: &vector<u8>,

    source_timestamp: u64,
) {
    let length =
        vector::length(&registry.anchors);

    let mut i = 0;

    while (i < length) {
        let anchor =
            vector::borrow(
                &registry.anchors,
                i,
            );

        let duplicate =
            anchor.status == STATUS_ACTIVE
                && anchor.event_type == event_type
                && anchor.world_id == world_id
                && anchor.space_binding_id == space_binding_id
                && anchor.actor_kind == actor_kind
                && anchor.actor_reference_id
                    == actor_reference_id
                && anchor.event_protocol_id
                    == event_protocol_id
                && &anchor.payload_hash == payload_hash
                && &anchor.metadata_hash == metadata_hash
                && anchor.source_timestamp
                    == source_timestamp;

        assert!(
            !duplicate,
            E_DUPLICATE_EVENT_ANCHOR,
        );

        i = i + 1;
    };
}


/* ============================================================
   Anchor Spatial Event
   ============================================================ */

public fun anchor_event(
    access: &AccessControl,
    registry: &mut GSOSSpatialEventAnchorRegistry,
    admin_cap: &GSOSSpatialEventAnchorAdminCap,

    identities: &GSOSIdentityRegistry,
    avatars: &GSOSAvatarBindingRegistry,
    authorities: &GSOSAgentAuthorityRegistry,

    worlds: &GSOSWorldSpaceRegistry,
    protocols: &GSOSProtocolRegistry,

    event_type: u8,

    world_id: u64,
    space_binding_id: u64,

    actor_kind: u8,
    actor_reference_id: u64,

    event_protocol_id: u64,

    payload_hash: vector<u8>,
    metadata_hash: vector<u8>,

    source_timestamp: u64,

    current_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    assert_valid_event_type(
        event_type,
    );

    assert_valid_actor_kind(
        actor_kind,
    );

    assert_world_space(
        worlds,
        world_id,
        space_binding_id,
    );

    assert_event_protocol(
        protocols,
        event_protocol_id,
    );

    assert!(
        !vector::is_empty(&payload_hash),
        E_EMPTY_PAYLOAD_HASH,
    );

    assert!(
        !vector::is_empty(&metadata_hash),
        E_EMPTY_METADATA_HASH,
    );

    assert_actor_reference(
        identities,
        avatars,
        authorities,

        actor_kind,
        actor_reference_id,

        world_id,
        space_binding_id,

        current_epoch,
    );

    assert_no_duplicate_active_anchor(
        registry,

        event_type,

        world_id,
        space_binding_id,

        actor_kind,
        actor_reference_id,

        event_protocol_id,

        &payload_hash,
        &metadata_hash,

        source_timestamp,
    );

    let event_id =
        registry.next_event_id;

    let anchored_epoch =
        tx_context::epoch(ctx);

    vector::push_back(
        &mut registry.anchors,
        SpatialEventAnchor {
            event_id,

            event_type,

            world_id,
            space_binding_id,

            actor_kind,
            actor_reference_id,

            event_protocol_id,

            payload_hash,
            metadata_hash,

            source_timestamp,

            anchored_epoch,
            updated_epoch: anchored_epoch,

            status: STATUS_ACTIVE,
        },
    );

    registry.next_event_id =
        event_id + 1;

    registry.total_anchored =
        registry.total_anchored + 1;

    registry.active_anchor_count =
        registry.active_anchor_count + 1;

    event::emit(SpatialEventAnchored {
        registry_id: object::id(registry),

        event_id,
        event_type,

        world_id,
        space_binding_id,

        actor_kind,
        actor_reference_id,

        event_protocol_id,

        source_timestamp,
        anchored_epoch,

        anchored_by: tx_context::sender(ctx),
    });

    event_id
}


/* ============================================================
   Registry Read API
   ============================================================ */

public fun version(
    registry: &GSOSSpatialEventAnchorRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &GSOSSpatialEventAnchorRegistry,
): bool {
    registry.paused
}

public fun total_anchored(
    registry: &GSOSSpatialEventAnchorRegistry,
): u64 {
    registry.total_anchored
}

public fun total_invalidated(
    registry: &GSOSSpatialEventAnchorRegistry,
): u64 {
    registry.total_invalidated
}

public fun active_anchor_count(
    registry: &GSOSSpatialEventAnchorRegistry,
): u64 {
    registry.active_anchor_count
}


/* ============================================================
   Anchor Read API
   ============================================================ */

public fun anchor_event_type(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u8 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).event_type
}

public fun anchor_world_id(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u64 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).world_id
}

public fun anchor_space_binding_id(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u64 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).space_binding_id
}

public fun anchor_actor_kind(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u8 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).actor_kind
}

public fun anchor_actor_reference_id(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u64 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).actor_reference_id
}

public fun anchor_event_protocol_id(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u64 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).event_protocol_id
}

public fun anchor_payload_hash(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): &vector<u8> {
    &borrow_anchor_internal(
        registry,
        event_id,
    ).payload_hash
}

public fun anchor_metadata_hash(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): &vector<u8> {
    &borrow_anchor_internal(
        registry,
        event_id,
    ).metadata_hash
}

public fun anchor_source_timestamp(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u64 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).source_timestamp
}

public fun anchor_status(
    registry: &GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): u8 {
    borrow_anchor_internal(
        registry,
        event_id,
    ).status
}


/* ============================================================
   Constant Accessors
   ============================================================ */

public fun event_entry(): u8 {
    EVENT_ENTRY
}

public fun event_exit(): u8 {
    EVENT_EXIT
}

public fun event_presence(): u8 {
    EVENT_PRESENCE
}

public fun event_interaction(): u8 {
    EVENT_INTERACTION
}

public fun event_execution(): u8 {
    EVENT_EXECUTION
}

public fun event_asset(): u8 {
    EVENT_ASSET
}

public fun event_governance(): u8 {
    EVENT_GOVERNANCE
}

public fun actor_identity(): u8 {
    ACTOR_IDENTITY
}

public fun actor_avatar(): u8 {
    ACTOR_AVATAR
}

public fun actor_authority(): u8 {
    ACTOR_AUTHORITY
}

public fun actor_delegation(): u8 {
    ACTOR_DELEGATION
}

public fun actor_system(): u8 {
    ACTOR_SYSTEM
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_invalidated(): u8 {
    STATUS_INVALIDATED
}


/* ============================================================
   Anchor Verification Helper
   ============================================================ */

public fun verify_anchor(
    registry: &GSOSSpatialEventAnchorRegistry,

    event_id: u64,

    payload_hash: &vector<u8>,
    metadata_hash: &vector<u8>,

    source_timestamp: u64,
): bool {
    if (registry.paused) {
        return false
    };

    let anchor =
        borrow_anchor_internal(
            registry,
            event_id,
        );

    anchor.status == STATUS_ACTIVE
        && &anchor.payload_hash == payload_hash
        && &anchor.metadata_hash == metadata_hash
        && anchor.source_timestamp == source_timestamp
}


/* ============================================================
   Mutable Anchor Lookup
   ============================================================ */

fun borrow_anchor_internal_mut(
    registry: &mut GSOSSpatialEventAnchorRegistry,
    event_id: u64,
): &mut SpatialEventAnchor {
    let index =
        anchor_index(
            registry,
            event_id,
        );

    vector::borrow_mut(
        &mut registry.anchors,
        index,
    )
}


/* ============================================================
   Invalidate Anchor
   ============================================================ */

public fun invalidate_anchor(
    access: &AccessControl,
    registry: &mut GSOSSpatialEventAnchorRegistry,
    admin_cap: &GSOSSpatialEventAnchorAdminCap,

    event_id: u64,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_registry_not_paused(registry);
    assert_admin(registry, admin_cap);

    let current_epoch =
        tx_context::epoch(ctx);

    {
        let anchor =
            borrow_anchor_internal_mut(
                registry,
                event_id,
            );

        assert!(
            anchor.status != STATUS_INVALIDATED,
            E_ALREADY_INVALIDATED,
        );

        anchor.status =
            STATUS_INVALIDATED;

        anchor.updated_epoch =
            current_epoch;
    };

    registry.total_invalidated =
        registry.total_invalidated + 1;

    registry.active_anchor_count =
        registry.active_anchor_count - 1;

    event::emit(SpatialEventAnchorInvalidated {
        registry_id: object::id(registry),
        event_id,

        invalidated_by:
            tx_context::sender(ctx),

        invalidated_epoch:
            current_epoch,
    });
}


/* ============================================================
   Pause Control
   ============================================================ */

public fun set_paused(
    access: &AccessControl,
    registry: &mut GSOSSpatialEventAnchorRegistry,
    admin_cap: &GSOSSpatialEventAnchorAdminCap,

    paused: bool,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_admin(registry, admin_cap);

    assert!(
        registry.paused != paused,
        E_STATE_UNCHANGED,
    );

    registry.paused = paused;

    event::emit(SpatialEventAnchorPauseChanged {
        registry_id: object::id(registry),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Registry Version Control
   ============================================================ */

public fun set_version(
    access: &AccessControl,
    registry: &mut GSOSSpatialEventAnchorRegistry,
    admin_cap: &GSOSSpatialEventAnchorAdminCap,

    new_version: u64,

    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access);
    assert_admin(registry, admin_cap);

    assert!(
        registry.version != new_version,
        E_VERSION_UNCHANGED,
    );

    let previous_version =
        registry.version;

    registry.version =
        new_version;

    event::emit(SpatialEventAnchorVersionChanged {
        registry_id: object::id(registry),

        previous_version,
        new_version,

        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Test Fixtures
   ============================================================ */

#[test_only]
public fun destroy_for_testing(
    registry: GSOSSpatialEventAnchorRegistry,
) {
    let GSOSSpatialEventAnchorRegistry {
        id,
        version: _,
        paused: _,
        next_event_id: _,
        anchors,
        total_anchored: _,
        total_invalidated: _,
        active_anchor_count: _,
    } = registry;

    let mut anchors = anchors;

    while (!vector::is_empty(&anchors)) {
        let anchor =
            vector::pop_back(&mut anchors);

        let SpatialEventAnchor {
            event_id: _,
            event_type: _,
            world_id: _,
            space_binding_id: _,
            actor_kind: _,
            actor_reference_id: _,
            event_protocol_id: _,
            payload_hash: _,
            metadata_hash: _,
            source_timestamp: _,
            anchored_epoch: _,
            updated_epoch: _,
            status: _,
        } = anchor;
    };

    vector::destroy_empty(anchors);
    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GSOSSpatialEventAnchorAdminCap,
) {
    let GSOSSpatialEventAnchorAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}
