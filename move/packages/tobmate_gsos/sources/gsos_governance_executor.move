module tobmate_gsos::gsos_governance_executor;

use sui::object::ID;
use sui::tx_context::TxContext;

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_foundation::protocol_governance::{
    Self as governance,
    ExecutionAuthorization,
    GovernanceRegistry,
};

use tobmate_gsos::gsos_identity_binding::{
    Self as identity_binding,
    GSOSIdentityRegistry,
    GSOSIdentityAdminCap,
};

use tobmate_gsos::gsap_spatial_registry::{
    Self as spatial,
    GSAPSpatialRegistry,
    GSAPSpatialAdminCap,
};

use tobmate_gsos::gsos_protocol_registry::{
    Self as protocol_registry,
    GSOSProtocolRegistry,
    GSOSProtocolAdminCap,
};

use tobmate_gsos::gsos_world_space_registry::{
    Self as world_space,
    GSOSWorldSpaceRegistry,
    GSOSWorldSpaceAdminCap,
};

use tobmate_gsos::gsos_entry_authorization::{
    Self as entry_auth,
    GSOSEntryAuthorizationRegistry,
    GSOSEntryAuthorizationAdminCap,
};

use tobmate_gsos::gsos_avatar_identity_binding::{
    Self as avatar_binding,
    GSOSAvatarBindingRegistry,
    GSOSAvatarBindingAdminCap,
};

use tobmate_gsos::gsos_agent_authority::{
    Self as agent_authority,
    GSOSAgentAuthorityRegistry,
    GSOSAgentAuthorityAdminCap,
};

use tobmate_gsos::gsos_capability_registry::{
    Self as capability,
    GSOSCapabilityRegistry,
    GSOSCapabilityAdminCap,
};

use tobmate_gsos::gsos_spatial_event_anchor::{
    Self as event_anchor,
    GSOSSpatialEventAnchorRegistry,
    GSOSSpatialEventAnchorAdminCap,
};


/* ============================================================
   Stage 11 Part 10
   GSOS Governance / Integration Security Executor
   ============================================================ */


/* ============================================================
   Action Types
   ============================================================ */

const ACTION_IDENTITY_SET_PAUSED: u64 = 1001;
const ACTION_IDENTITY_SET_VERSION: u64 = 1002;

const ACTION_GSAP_SET_PAUSED: u64 = 1101;
const ACTION_GSAP_SET_VERSION: u64 = 1102;

const ACTION_PROTOCOL_SET_PAUSED: u64 = 1201;
const ACTION_PROTOCOL_SET_VERSION: u64 = 1202;

const ACTION_WORLD_SPACE_SET_PAUSED: u64 = 1301;
const ACTION_WORLD_SPACE_SET_VERSION: u64 = 1302;

const ACTION_ENTRY_AUTH_SET_PAUSED: u64 = 1401;
const ACTION_ENTRY_AUTH_SET_VERSION: u64 = 1402;

const ACTION_AVATAR_SET_PAUSED: u64 = 1501;
const ACTION_AVATAR_SET_VERSION: u64 = 1502;

const ACTION_AGENT_AUTH_SET_PAUSED: u64 = 1601;
const ACTION_AGENT_AUTH_SET_VERSION: u64 = 1602;

const ACTION_CAPABILITY_SET_PAUSED: u64 = 1701;
const ACTION_CAPABILITY_SET_VERSION: u64 = 1702;

const ACTION_EVENT_ANCHOR_SET_PAUSED: u64 = 1801;
const ACTION_EVENT_ANCHOR_SET_VERSION: u64 = 1802;


/* ============================================================
   Canonical Payload Encoding
   ============================================================ */

fun append_u64_le(
    bytes: &mut vector<u8>,
    value: u64,
) {
    vector::push_back(bytes, (value & 0xff) as u8);
    vector::push_back(bytes, ((value >> 8) & 0xff) as u8);
    vector::push_back(bytes, ((value >> 16) & 0xff) as u8);
    vector::push_back(bytes, ((value >> 24) & 0xff) as u8);
    vector::push_back(bytes, ((value >> 32) & 0xff) as u8);
    vector::push_back(bytes, ((value >> 40) & 0xff) as u8);
    vector::push_back(bytes, ((value >> 48) & 0xff) as u8);
    vector::push_back(bytes, ((value >> 56) & 0xff) as u8);
}

fun payload_bool(
    value: bool,
): vector<u8> {
    vector[
        if (value) {
            1
        } else {
            0
        }
    ]
}

fun payload_u64(
    value: u64,
): vector<u8> {
    let mut bytes = vector[];

    append_u64_le(
        &mut bytes,
        value,
    );

    bytes
}


/* ============================================================
   Governance Security Gate
   ============================================================ */

fun assert_governed_execution(
    access: &AccessControl,
    governance_registry: &GovernanceRegistry,
    authorization: &ExecutionAuthorization,

    proposal_id: u64,
    action_type: u64,
    target_object_id: ID,
    payload: &vector<u8>,

    ctx: &TxContext,
) {
    access_control::assert_not_paused(
        access,
    );

    governance::assert_not_emergency(
        governance_registry,
    );

    governance::assert_proposal_execution_allowed(
        governance_registry,
        proposal_id,
    );

    governance::assert_authorization_registry(
        governance_registry,
        authorization,
    );

    governance::assert_execution_authorized(
        authorization,
        proposal_id,
        action_type,
        target_object_id,
        payload,
        ctx,
    );
}


/* ============================================================
   Identity Registry
   ============================================================ */

public fun execute_identity_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSIdentityAdminCap,
    registry: &mut GSOSIdentityRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        identity_binding::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_IDENTITY_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    identity_binding::set_paused(
        admin_cap,
        registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_IDENTITY_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_identity_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSIdentityAdminCap,
    registry: &mut GSOSIdentityRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        identity_binding::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_IDENTITY_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    identity_binding::set_version(
        admin_cap,
        registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_IDENTITY_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   GSAP Spatial Registry
   ============================================================ */

public fun execute_gsap_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSAPSpatialAdminCap,
    registry: &mut GSAPSpatialRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        spatial::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_GSAP_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    spatial::set_paused(
        admin_cap,
        registry,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_GSAP_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_gsap_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSAPSpatialAdminCap,
    registry: &mut GSAPSpatialRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        spatial::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_GSAP_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    spatial::set_version(
        admin_cap,
        registry,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_GSAP_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   GSOS Protocol Registry
   ============================================================ */

public fun execute_protocol_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSProtocolAdminCap,
    registry: &mut GSOSProtocolRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        protocol_registry::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_PROTOCOL_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    protocol_registry::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_PROTOCOL_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_protocol_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSProtocolAdminCap,
    registry: &mut GSOSProtocolRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        protocol_registry::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_PROTOCOL_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    protocol_registry::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_PROTOCOL_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   World / Space Registry
   ============================================================ */

public fun execute_world_space_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSWorldSpaceAdminCap,
    registry: &mut GSOSWorldSpaceRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        world_space::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_WORLD_SPACE_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    world_space::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_WORLD_SPACE_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_world_space_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSWorldSpaceAdminCap,
    registry: &mut GSOSWorldSpaceRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        world_space::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_WORLD_SPACE_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    world_space::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_WORLD_SPACE_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Entry Authorization Registry
   ============================================================ */

public fun execute_entry_auth_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSEntryAuthorizationAdminCap,
    registry: &mut GSOSEntryAuthorizationRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        entry_auth::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ENTRY_AUTH_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    entry_auth::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ENTRY_AUTH_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_entry_auth_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSEntryAuthorizationAdminCap,
    registry: &mut GSOSEntryAuthorizationRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        entry_auth::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ENTRY_AUTH_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    entry_auth::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_ENTRY_AUTH_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Avatar Binding Registry
   ============================================================ */

public fun execute_avatar_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSAvatarBindingAdminCap,
    registry: &mut GSOSAvatarBindingRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        avatar_binding::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AVATAR_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    avatar_binding::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AVATAR_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_avatar_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSAvatarBindingAdminCap,
    registry: &mut GSOSAvatarBindingRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        avatar_binding::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AVATAR_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    avatar_binding::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AVATAR_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Agent Authority Registry
   ============================================================ */

public fun execute_agent_auth_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSAgentAuthorityAdminCap,
    registry: &mut GSOSAgentAuthorityRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        agent_authority::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AGENT_AUTH_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    agent_authority::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AGENT_AUTH_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_agent_auth_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSAgentAuthorityAdminCap,
    registry: &mut GSOSAgentAuthorityRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        agent_authority::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AGENT_AUTH_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    agent_authority::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_AGENT_AUTH_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Capability Registry
   ============================================================ */

public fun execute_capability_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSCapabilityAdminCap,
    registry: &mut GSOSCapabilityRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        capability::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CAPABILITY_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    capability::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CAPABILITY_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_capability_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSCapabilityAdminCap,
    registry: &mut GSOSCapabilityRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        capability::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CAPABILITY_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    capability::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_CAPABILITY_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Spatial Event Anchor Registry
   ============================================================ */

public fun execute_event_anchor_set_paused(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSSpatialEventAnchorAdminCap,
    registry: &mut GSOSSpatialEventAnchorRegistry,

    proposal_id: u64,
    paused: bool,

    ctx: &mut TxContext,
) {
    let target_id =
        event_anchor::registry_id(
            registry,
        );

    let payload =
        payload_bool(
            paused,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_EVENT_ANCHOR_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );

    event_anchor::set_paused(
        access,
        registry,
        admin_cap,
        paused,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_EVENT_ANCHOR_SET_PAUSED,
        target_id,
        &payload,
        ctx,
    );
}

public fun execute_event_anchor_set_version(
    access: &AccessControl,
    governance_registry: &mut GovernanceRegistry,
    authorization: &mut ExecutionAuthorization,

    admin_cap: &GSOSSpatialEventAnchorAdminCap,
    registry: &mut GSOSSpatialEventAnchorRegistry,

    proposal_id: u64,
    new_version: u64,

    ctx: &mut TxContext,
) {
    let target_id =
        event_anchor::registry_id(
            registry,
        );

    let payload =
        payload_u64(
            new_version,
        );

    assert_governed_execution(
        access,
        governance_registry,
        authorization,
        proposal_id,
        ACTION_EVENT_ANCHOR_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );

    event_anchor::set_version(
        access,
        registry,
        admin_cap,
        new_version,
        ctx,
    );

    governance::mark_executed(
        governance_registry,
        authorization,
        proposal_id,
        ACTION_EVENT_ANCHOR_SET_VERSION,
        target_id,
        &payload,
        ctx,
    );
}


/* ============================================================
   Action Type Read API
   ============================================================ */

public fun action_identity_set_paused(): u64 {
    ACTION_IDENTITY_SET_PAUSED
}

public fun action_identity_set_version(): u64 {
    ACTION_IDENTITY_SET_VERSION
}

public fun action_gsap_set_paused(): u64 {
    ACTION_GSAP_SET_PAUSED
}

public fun action_gsap_set_version(): u64 {
    ACTION_GSAP_SET_VERSION
}

public fun action_protocol_set_paused(): u64 {
    ACTION_PROTOCOL_SET_PAUSED
}

public fun action_protocol_set_version(): u64 {
    ACTION_PROTOCOL_SET_VERSION
}

public fun action_world_space_set_paused(): u64 {
    ACTION_WORLD_SPACE_SET_PAUSED
}

public fun action_world_space_set_version(): u64 {
    ACTION_WORLD_SPACE_SET_VERSION
}

public fun action_entry_auth_set_paused(): u64 {
    ACTION_ENTRY_AUTH_SET_PAUSED
}

public fun action_entry_auth_set_version(): u64 {
    ACTION_ENTRY_AUTH_SET_VERSION
}

public fun action_avatar_set_paused(): u64 {
    ACTION_AVATAR_SET_PAUSED
}

public fun action_avatar_set_version(): u64 {
    ACTION_AVATAR_SET_VERSION
}

public fun action_agent_auth_set_paused(): u64 {
    ACTION_AGENT_AUTH_SET_PAUSED
}

public fun action_agent_auth_set_version(): u64 {
    ACTION_AGENT_AUTH_SET_VERSION
}

public fun action_capability_set_paused(): u64 {
    ACTION_CAPABILITY_SET_PAUSED
}

public fun action_capability_set_version(): u64 {
    ACTION_CAPABILITY_SET_VERSION
}

public fun action_event_anchor_set_paused(): u64 {
    ACTION_EVENT_ANCHOR_SET_PAUSED
}

public fun action_event_anchor_set_version(): u64 {
    ACTION_EVENT_ANCHOR_SET_VERSION
}


/* ============================================================
   Test Payload Helpers
   ============================================================ */

#[test_only]
public fun payload_bool_for_testing(
    value: bool,
): vector<u8> {
    payload_bool(value)
}

#[test_only]
public fun payload_u64_for_testing(
    value: u64,
): vector<u8> {
    payload_u64(value)
}
