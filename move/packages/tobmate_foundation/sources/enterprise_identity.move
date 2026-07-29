module tobmate_foundation::enterprise_identity;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_foundation::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_foundation::tmid::{
    Self as tmid,
    TMID,
};


/* ============================================================
   Stage 12 Part 1-A
   Enterprise Identity / KYC-AML Control
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Provider Types
   ============================================================ */

const PROVIDER_KYC: u8 = 1;
const PROVIDER_AML: u8 = 2;
const PROVIDER_FULL_COMPLIANCE: u8 = 3;


/* ============================================================
   AML Status
   ============================================================ */

const AML_CLEAR: u8 = 1;
const AML_REVIEW: u8 = 2;
const AML_BLOCKED: u8 = 3;


/* ============================================================
   Credential Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_REVOKED: u8 = 2;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_PROVIDER_TYPE: u64 = 2;
const E_EMPTY_PROVIDER_KEY: u64 = 3;
const E_EMPTY_JURISDICTION: u64 = 4;
const E_DUPLICATE_PROVIDER: u64 = 5;
const E_PROVIDER_NOT_FOUND: u64 = 6;
const E_PROVIDER_INACTIVE: u64 = 7;
const E_STATE_UNCHANGED: u64 = 8;
const E_TMID_NOT_ACTIVE: u64 = 9;
const E_NOT_TMID_CONTROLLER: u64 = 10;
const E_EMPTY_CREDENTIAL_HASH: u64 = 11;
const E_INVALID_KYC_LEVEL: u64 = 12;
const E_INVALID_AML_STATUS: u64 = 13;
const E_INVALID_EXPIRY: u64 = 14;
const E_DUPLICATE_ACTIVE_CREDENTIAL: u64 = 15;
const E_CREDENTIAL_NOT_FOUND: u64 = 16;
const E_CREDENTIAL_ALREADY_REVOKED: u64 = 17;
const E_CREDENTIAL_EXPIRED: u64 = 18;
const E_AML_NOT_CLEAR: u64 = 19;
const E_VERSION_NOT_INCREASING: u64 = 20;
const E_ADMIN_CAP_MISMATCH: u64 = 21;
const E_PROVIDER_AUTHORITY_MISMATCH: u64 = 22;
const E_JURISDICTION_MISMATCH: u64 = 23;


/* ============================================================
   Registry
   ============================================================ */

public struct EnterpriseIdentityRegistry has key {
    id: UID,
    version: u64,
    paused: bool,

    next_provider_id: u64,
    next_credential_id: u64,

    providers: vector<ComplianceProvider>,
    credentials: vector<ComplianceCredential>,

    total_providers: u64,
    active_provider_count: u64,

    total_credentials: u64,
    active_credential_count: u64,
    revoked_credential_count: u64,
}


/* ============================================================
   Capabilities
   ============================================================ */

public struct EnterpriseIdentityAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Provider
   ============================================================ */

public struct ComplianceProvider has store {
    provider_id: u64,
    provider_key: vector<u8>,
    authority: address,
    provider_type: u8,
    jurisdiction: vector<u8>,
    active: bool,
    version: u64,
    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Credential
   ============================================================ */

public struct ComplianceCredential has store {
    credential_id: u64,

    tmid_id: ID,
    controller: address,

    provider_id: u64,
    credential_hash: vector<u8>,

    kyc_level: u8,
    aml_status: u8,
    jurisdiction: vector<u8>,

    issued_epoch: u64,
    expires_epoch: u64,

    status: u8,
    version: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct EnterpriseProviderRegistered has copy, drop {
    registry_id: ID,
    provider_id: u64,
    authority: address,
    provider_type: u8,
    created_epoch: u64,
}

public struct EnterpriseProviderStatusChanged has copy, drop {
    registry_id: ID,
    provider_id: u64,
    active: bool,
    changed_by: address,
}

public struct EnterpriseCredentialIssued has copy, drop {
    registry_id: ID,
    credential_id: u64,
    provider_id: u64,
    tmid_id: ID,
    controller: address,
    kyc_level: u8,
    aml_status: u8,
    expires_epoch: u64,
}

public struct EnterpriseCredentialRevoked has copy, drop {
    registry_id: ID,
    credential_id: u64,
    revoked_by: address,
    revoked_epoch: u64,
}

public struct EnterpriseIdentityPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct EnterpriseIdentityVersionChanged has copy, drop {
    registry_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (EnterpriseIdentityRegistry, EnterpriseIdentityAdminCap) {
    let registry = EnterpriseIdentityRegistry {
        id: object::new(ctx),
        version: PROTOCOL_VERSION,
        paused: false,

        next_provider_id: 1,
        next_credential_id: 1,

        providers: vector[],
        credentials: vector[],

        total_providers: 0,
        active_provider_count: 0,

        total_credentials: 0,
        active_credential_count: 0,
        revoked_credential_count: 0,
    };

    let registry_id = object::id(&registry);

    let admin_cap = EnterpriseIdentityAdminCap {
        id: object::new(ctx),
        registry_id,
    };

    (registry, admin_cap)
}


/* ============================================================
   Guards
   ============================================================ */

public fun assert_operational(
    access: &AccessControl,
    registry: &EnterpriseIdentityRegistry,
) {
    access_control::assert_not_paused(access);
    assert!(!registry.paused, E_REGISTRY_PAUSED);
}

fun assert_admin(
    registry: &EnterpriseIdentityRegistry,
    admin_cap: &EnterpriseIdentityAdminCap,
) {
    assert!(
        admin_cap.registry_id == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_provider_type(provider_type: u8) {
    assert!(
        provider_type == PROVIDER_KYC
            || provider_type == PROVIDER_AML
            || provider_type == PROVIDER_FULL_COMPLIANCE,
        E_INVALID_PROVIDER_TYPE,
    );
}

fun assert_aml_status(aml_status: u8) {
    assert!(
        aml_status == AML_CLEAR
            || aml_status == AML_REVIEW
            || aml_status == AML_BLOCKED,
        E_INVALID_AML_STATUS,
    );
}


/* ============================================================
   Provider Lookup
   ============================================================ */

fun provider_index(
    registry: &EnterpriseIdentityRegistry,
    provider_id: u64,
): u64 {
    let length = vector::length(&registry.providers);
    let mut i = 0;

    while (i < length) {
        if (vector::borrow(&registry.providers, i).provider_id == provider_id) {
            return i
        };
        i = i + 1;
    };

    abort E_PROVIDER_NOT_FOUND
}

fun contains_provider_key(
    registry: &EnterpriseIdentityRegistry,
    provider_key: &vector<u8>,
): bool {
    let length = vector::length(&registry.providers);
    let mut i = 0;

    while (i < length) {
        if (vector::borrow(&registry.providers, i).provider_key == *provider_key) {
            return true
        };
        i = i + 1;
    };

    false
}


/* ============================================================
   Provider Lifecycle
   ============================================================ */

public fun register_provider(
    access: &AccessControl,
    registry: &mut EnterpriseIdentityRegistry,
    admin_cap: &EnterpriseIdentityAdminCap,

    provider_key: vector<u8>,
    authority: address,
    provider_type: u8,
    jurisdiction: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    assert_operational(access, registry);
    assert_admin(registry, admin_cap);
    assert_provider_type(provider_type);

    assert!(vector::length(&provider_key) > 0, E_EMPTY_PROVIDER_KEY);
    assert!(vector::length(&jurisdiction) > 0, E_EMPTY_JURISDICTION);
    assert!(!contains_provider_key(registry, &provider_key), E_DUPLICATE_PROVIDER);

    let provider_id = registry.next_provider_id;
    registry.next_provider_id = provider_id + 1;

    vector::push_back(
        &mut registry.providers,
        ComplianceProvider {
            provider_id,
            provider_key,
            authority,
            provider_type,
            jurisdiction,
            active: true,
            version: 1,
            created_epoch: tx_context::epoch(ctx),
            updated_epoch: tx_context::epoch(ctx),
        },
    );

    registry.total_providers = registry.total_providers + 1;
    registry.active_provider_count = registry.active_provider_count + 1;

    event::emit(EnterpriseProviderRegistered {
        registry_id: object::id(registry),
        provider_id,
        authority,
        provider_type,
        created_epoch: tx_context::epoch(ctx),
    });

    provider_id
}

public fun set_provider_active(
    access: &AccessControl,
    registry: &mut EnterpriseIdentityRegistry,
    admin_cap: &EnterpriseIdentityAdminCap,
    provider_id: u64,
    active: bool,
    ctx: &mut TxContext,
) {
    assert_operational(access, registry);
    assert_admin(registry, admin_cap);

    let index = provider_index(registry, provider_id);
    let provider = vector::borrow_mut(&mut registry.providers, index);

    assert!(provider.active != active, E_STATE_UNCHANGED);

    if (active) {
        registry.active_provider_count = registry.active_provider_count + 1;
    } else {
        registry.active_provider_count = registry.active_provider_count - 1;
    };

    provider.active = active;
    provider.updated_epoch = tx_context::epoch(ctx);

    event::emit(EnterpriseProviderStatusChanged {
        registry_id: object::id(registry),
        provider_id,
        active,
        changed_by: tx_context::sender(ctx),
    });
}


/* ============================================================
   Credential Helpers
   ============================================================ */

fun credential_index(
    registry: &EnterpriseIdentityRegistry,
    credential_id: u64,
): u64 {
    let length = vector::length(&registry.credentials);
    let mut i = 0;

    while (i < length) {
        if (
            vector::borrow(&registry.credentials, i).credential_id
                == credential_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_CREDENTIAL_NOT_FOUND
}

fun has_active_credential(
    registry: &EnterpriseIdentityRegistry,
    tmid_id: ID,
    provider_id: u64,
): bool {
    let length = vector::length(&registry.credentials);
    let mut i = 0;

    while (i < length) {
        let credential =
            vector::borrow(&registry.credentials, i);

        if (
            credential.tmid_id == tmid_id
                && credential.provider_id == provider_id
                && credential.status == STATUS_ACTIVE
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Credential Lifecycle
   ============================================================ */

public fun issue_credential(
    access: &AccessControl,
    registry: &mut EnterpriseIdentityRegistry,
    tmid_obj: &TMID,

    provider_id: u64,
    credential_hash: vector<u8>,
    kyc_level: u8,
    aml_status: u8,
    jurisdiction: vector<u8>,
    expires_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    assert_operational(access, registry);

    assert!(
        tmid::is_active(tmid_obj),
        E_TMID_NOT_ACTIVE,
    );

    assert!(
        vector::length(&credential_hash) > 0,
        E_EMPTY_CREDENTIAL_HASH,
    );

    assert!(
        kyc_level > 0,
        E_INVALID_KYC_LEVEL,
    );

    assert_aml_status(
        aml_status,
    );

    assert!(
        vector::length(&jurisdiction) > 0,
        E_EMPTY_JURISDICTION,
    );

    assert!(
        expires_epoch > tx_context::epoch(ctx),
        E_INVALID_EXPIRY,
    );

    let p_index =
        provider_index(
            registry,
            provider_id,
        );

    let provider =
        vector::borrow(
            &registry.providers,
            p_index,
        );

    assert!(
        provider.active,
        E_PROVIDER_INACTIVE,
    );

    assert!(
        provider.authority
            == tx_context::sender(ctx),
        E_PROVIDER_AUTHORITY_MISMATCH,
    );

    assert!(
        provider.jurisdiction
            == jurisdiction,
        E_JURISDICTION_MISMATCH,
    );

    let tmid_id =
        tmid::tmid_id(
            tmid_obj,
        );

    assert!(
        !has_active_credential(
            registry,
            tmid_id,
            provider_id,
        ),
        E_DUPLICATE_ACTIVE_CREDENTIAL,
    );

    let credential_id =
        registry.next_credential_id;

    registry.next_credential_id =
        credential_id + 1;

    let controller =
        tmid::controller(
            tmid_obj,
        );

    vector::push_back(
        &mut registry.credentials,
        ComplianceCredential {
            credential_id,
            tmid_id,
            controller,
            provider_id,
            credential_hash,
            kyc_level,
            aml_status,
            jurisdiction,
            issued_epoch:
                tx_context::epoch(ctx),
            expires_epoch,
            status: STATUS_ACTIVE,
            version: 1,
            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_credentials =
        registry.total_credentials + 1;

    registry.active_credential_count =
        registry.active_credential_count + 1;

    event::emit(
        EnterpriseCredentialIssued {
            registry_id:
                object::id(registry),
            credential_id,
            provider_id,
            tmid_id,
            controller,
            kyc_level,
            aml_status,
            expires_epoch,
        },
    );

    credential_id
}


/* ============================================================
   Credential Revocation
   ============================================================ */

public fun revoke_credential(
    access: &AccessControl,
    registry: &mut EnterpriseIdentityRegistry,
    admin_cap: &EnterpriseIdentityAdminCap,
    credential_id: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert_admin(
        registry,
        admin_cap,
    );

    let index =
        credential_index(
            registry,
            credential_id,
        );

    let credential =
        vector::borrow_mut(
            &mut registry.credentials,
            index,
        );

    assert!(
        credential.status == STATUS_ACTIVE,
        E_CREDENTIAL_ALREADY_REVOKED,
    );

    credential.status =
        STATUS_REVOKED;

    credential.updated_epoch =
        tx_context::epoch(ctx);

    registry.active_credential_count =
        registry.active_credential_count - 1;

    registry.revoked_credential_count =
        registry.revoked_credential_count + 1;

    event::emit(
        EnterpriseCredentialRevoked {
            registry_id:
                object::id(registry),
            credential_id,
            revoked_by:
                tx_context::sender(ctx),
            revoked_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Enterprise Eligibility
   ============================================================ */

public fun assert_credential_eligible(
    registry: &EnterpriseIdentityRegistry,
    credential_id: u64,
    current_epoch: u64,
) {
    let index =
        credential_index(
            registry,
            credential_id,
        );

    let credential =
        vector::borrow(
            &registry.credentials,
            index,
        );

    assert!(
        credential.status == STATUS_ACTIVE,
        E_CREDENTIAL_ALREADY_REVOKED,
    );

    assert!(
        current_epoch < credential.expires_epoch,
        E_CREDENTIAL_EXPIRED,
    );

    assert!(
        credential.aml_status == AML_CLEAR,
        E_AML_NOT_CLEAR,
    );

    let p_index =
        provider_index(
            registry,
            credential.provider_id,
        );

    let provider =
        vector::borrow(
            &registry.providers,
            p_index,
        );

    assert!(
        provider.active,
        E_PROVIDER_INACTIVE,
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &EnterpriseIdentityAdminCap,
    registry: &mut EnterpriseIdentityRegistry,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        registry.paused != paused,
        E_STATE_UNCHANGED,
    );

    registry.paused = paused;

    event::emit(
        EnterpriseIdentityPauseChanged {
            registry_id:
                object::id(registry),
            paused,
            changed_by:
                tx_context::sender(ctx),
        },
    );
}

public fun set_version(
    admin_cap: &EnterpriseIdentityAdminCap,
    registry: &mut EnterpriseIdentityRegistry,
    new_version: u64,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_version > registry.version,
        E_VERSION_NOT_INCREASING,
    );

    let previous_version =
        registry.version;

    registry.version =
        new_version;

    event::emit(
        EnterpriseIdentityVersionChanged {
            registry_id:
                object::id(registry),
            previous_version,
            new_version,
            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &EnterpriseIdentityRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &EnterpriseIdentityRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &EnterpriseIdentityRegistry,
): bool {
    registry.paused
}

public(package) fun total_providers(
    registry: &EnterpriseIdentityRegistry,
): u64 {
    registry.total_providers
}

public fun active_provider_count(
    registry: &EnterpriseIdentityRegistry,
): u64 {
    registry.active_provider_count
}

public(package) fun total_credentials(
    registry: &EnterpriseIdentityRegistry,
): u64 {
    registry.total_credentials
}

public fun active_credential_count(
    registry: &EnterpriseIdentityRegistry,
): u64 {
    registry.active_credential_count
}

public fun revoked_credential_count(
    registry: &EnterpriseIdentityRegistry,
): u64 {
    registry.revoked_credential_count
}

public(package) fun credential_status(
    registry: &EnterpriseIdentityRegistry,
    credential_id: u64,
): u8 {
    let index =
        credential_index(
            registry,
            credential_id,
        );

    vector::borrow(
        &registry.credentials,
        index,
    ).status
}

public(package) fun credential_tmid_id(
    registry: &EnterpriseIdentityRegistry,
    credential_id: u64,
): ID {
    let index =
        credential_index(
            registry,
            credential_id,
        );

    vector::borrow(
        &registry.credentials,
        index,
    ).tmid_id
}


/* ============================================================
   External Constants
   ============================================================ */

public fun provider_kyc(): u8 {
    PROVIDER_KYC
}

public fun provider_aml(): u8 {
    PROVIDER_AML
}

public fun provider_full_compliance(): u8 {
    PROVIDER_FULL_COMPLIANCE
}

public fun aml_clear(): u8 {
    AML_CLEAR
}

public fun aml_review(): u8 {
    AML_REVIEW
}

public fun aml_blocked(): u8 {
    AML_BLOCKED
}

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_revoked(): u8 {
    STATUS_REVOKED
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): EnterpriseIdentityRegistry {
    EnterpriseIdentityRegistry {
        id: object::new(ctx),
        version: PROTOCOL_VERSION,
        paused: false,

        next_provider_id: 1,
        next_credential_id: 1,

        providers: vector[],
        credentials: vector[],

        total_providers: 0,
        active_provider_count: 0,

        total_credentials: 0,
        active_credential_count: 0,
        revoked_credential_count: 0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &EnterpriseIdentityRegistry,
    ctx: &mut TxContext,
): EnterpriseIdentityAdminCap {
    EnterpriseIdentityAdminCap {
        id: object::new(ctx),
        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: EnterpriseIdentityRegistry,
) {
    let EnterpriseIdentityRegistry {
        id,
        version: _,
        paused: _,

        next_provider_id: _,
        next_credential_id: _,

        providers,
        credentials,

        total_providers: _,
        active_provider_count: _,

        total_credentials: _,
        active_credential_count: _,
        revoked_credential_count: _,
    } = registry;

    let mut providers = providers;

    while (!vector::is_empty(&providers)) {
        let provider =
            vector::pop_back(
                &mut providers,
            );

        let ComplianceProvider {
            provider_id: _,
            provider_key: _,
            authority: _,
            provider_type: _,
            jurisdiction: _,
            active: _,
            version: _,
            created_epoch: _,
            updated_epoch: _,
        } = provider;
    };

    vector::destroy_empty(providers);

    let mut credentials = credentials;

    while (!vector::is_empty(&credentials)) {
        let credential =
            vector::pop_back(
                &mut credentials,
            );

        let ComplianceCredential {
            credential_id: _,

            tmid_id: _,
            controller: _,

            provider_id: _,
            credential_hash: _,

            kyc_level: _,
            aml_status: _,
            jurisdiction: _,

            issued_epoch: _,
            expires_epoch: _,

            status: _,
            version: _,
            updated_epoch: _,
        } = credential;
    };

    vector::destroy_empty(credentials);

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: EnterpriseIdentityAdminCap,
) {
    let EnterpriseIdentityAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(id);
}


/* ============================================================
   Stage 12 Part 1-B
   Two-Party Compliance Authorization

   TMID Controller:
       creates credential request

   Compliance Provider:
       verifies request and issues attestation
   ============================================================ */


/* ============================================================
   Request Status
   ============================================================ */

const REQUEST_PENDING: u8 = 1;
const REQUEST_ATTESTED: u8 = 2;
const REQUEST_CANCELLED: u8 = 3;


/* ============================================================
   Request Errors
   ============================================================ */

const E_REQUEST_NOT_FOUND: u64 = 24;
const E_REQUEST_NOT_PENDING: u64 = 25;
const E_REQUEST_PROVIDER_MISMATCH: u64 = 26;
const E_REQUEST_TMID_MISMATCH: u64 = 27;
const E_REQUEST_CONTROLLER_MISMATCH: u64 = 28;


/* ============================================================
   Credential Request
   ============================================================ */

public struct CredentialRequest has key, store {
    id: UID,

    registry_id: ID,

    tmid_id: ID,
    controller: address,

    provider_id: u64,

    jurisdiction: vector<u8>,

    status: u8,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Request Events
   ============================================================ */

public struct EnterpriseCredentialRequested has copy, drop {
    registry_id: ID,
    request_id: ID,
    tmid_id: ID,
    controller: address,
    provider_id: u64,
    created_epoch: u64,
}

public struct EnterpriseCredentialRequestCancelled has copy, drop {
    registry_id: ID,
    request_id: ID,
    controller: address,
    cancelled_epoch: u64,
}

public struct EnterpriseCredentialRequestAttested has copy, drop {
    registry_id: ID,
    request_id: ID,
    credential_id: u64,
    provider_id: u64,
    tmid_id: ID,
    attested_by: address,
    attested_epoch: u64,
}


/* ============================================================
   Controller Request Creation
   ============================================================ */

public fun create_credential_request(
    access: &AccessControl,
    registry: &EnterpriseIdentityRegistry,
    tmid_obj: &TMID,

    provider_id: u64,
    jurisdiction: vector<u8>,

    ctx: &mut TxContext,
): CredentialRequest {
    assert_operational(
        access,
        registry,
    );

    assert!(
        tmid::is_active(tmid_obj),
        E_TMID_NOT_ACTIVE,
    );

    let controller =
        tmid::controller(
            tmid_obj,
        );

    assert!(
        controller == tx_context::sender(ctx),
        E_NOT_TMID_CONTROLLER,
    );

    assert!(
        vector::length(&jurisdiction) > 0,
        E_EMPTY_JURISDICTION,
    );

    let p_index =
        provider_index(
            registry,
            provider_id,
        );

    let provider =
        vector::borrow(
            &registry.providers,
            p_index,
        );

    assert!(
        provider.active,
        E_PROVIDER_INACTIVE,
    );

    assert!(
        provider.jurisdiction == jurisdiction,
        E_JURISDICTION_MISMATCH,
    );

    let tmid_id =
        tmid::tmid_id(
            tmid_obj,
        );

    let request =
        CredentialRequest {
            id: object::new(ctx),

            registry_id:
                object::id(registry),

            tmid_id,
            controller,

            provider_id,
            jurisdiction,

            status:
                REQUEST_PENDING,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        };

    event::emit(
        EnterpriseCredentialRequested {
            registry_id:
                object::id(registry),

            request_id:
                object::id(&request),

            tmid_id,
            controller,
            provider_id,

            created_epoch:
                tx_context::epoch(ctx),
        },
    );

    request
}


/* ============================================================
   Controller Request Cancellation
   ============================================================ */

public fun cancel_credential_request(
    access: &AccessControl,
    registry: &EnterpriseIdentityRegistry,
    request: &mut CredentialRequest,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        request.registry_id
            == object::id(registry),
        E_REQUEST_NOT_FOUND,
    );

    assert!(
        request.controller
            == tx_context::sender(ctx),
        E_REQUEST_CONTROLLER_MISMATCH,
    );

    assert!(
        request.status == REQUEST_PENDING,
        E_REQUEST_NOT_PENDING,
    );

    request.status =
        REQUEST_CANCELLED;

    request.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        EnterpriseCredentialRequestCancelled {
            registry_id:
                object::id(registry),

            request_id:
                object::id(request),

            controller:
                request.controller,

            cancelled_epoch:
                tx_context::epoch(ctx),
        },
    );
}


/* ============================================================
   Provider Attestation
   ============================================================ */

public fun attest_credential_request(
    access: &AccessControl,
    registry: &mut EnterpriseIdentityRegistry,
    request: &mut CredentialRequest,
    tmid_obj: &TMID,

    credential_hash: vector<u8>,
    kyc_level: u8,
    aml_status: u8,
    expires_epoch: u64,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert!(
        request.registry_id == object::id(registry),
        E_REQUEST_NOT_FOUND,
    );

    assert!(
        request.status == REQUEST_PENDING,
        E_REQUEST_NOT_PENDING,
    );

    assert!(
        tmid::is_active(tmid_obj),
        E_TMID_NOT_ACTIVE,
    );

    let actual_tmid_id =
        tmid::tmid_id(
            tmid_obj,
        );

    assert!(
        request.tmid_id == actual_tmid_id,
        E_REQUEST_TMID_MISMATCH,
    );

    let actual_controller =
        tmid::controller(
            tmid_obj,
        );

    assert!(
        request.controller == actual_controller,
        E_REQUEST_CONTROLLER_MISMATCH,
    );

    assert!(
        vector::length(&credential_hash) > 0,
        E_EMPTY_CREDENTIAL_HASH,
    );

    assert!(
        kyc_level > 0,
        E_INVALID_KYC_LEVEL,
    );

    assert_aml_status(
        aml_status,
    );

    assert!(
        expires_epoch > tx_context::epoch(ctx),
        E_INVALID_EXPIRY,
    );

    let p_index =
        provider_index(
            registry,
            request.provider_id,
        );

    let provider =
        vector::borrow(
            &registry.providers,
            p_index,
        );

    assert!(
        provider.active,
        E_PROVIDER_INACTIVE,
    );

    assert!(
        provider.authority == tx_context::sender(ctx),
        E_PROVIDER_AUTHORITY_MISMATCH,
    );

    assert!(
        provider.provider_id == request.provider_id,
        E_REQUEST_PROVIDER_MISMATCH,
    );

    assert!(
        provider.jurisdiction == request.jurisdiction,
        E_JURISDICTION_MISMATCH,
    );

    assert!(
        !has_active_credential(
            registry,
            actual_tmid_id,
            request.provider_id,
        ),
        E_DUPLICATE_ACTIVE_CREDENTIAL,
    );

    let credential_id =
        registry.next_credential_id;

    registry.next_credential_id =
        credential_id + 1;

    vector::push_back(
        &mut registry.credentials,
        ComplianceCredential {
            credential_id,

            tmid_id:
                actual_tmid_id,

            controller:
                actual_controller,

            provider_id:
                request.provider_id,

            credential_hash,

            kyc_level,
            aml_status,

            jurisdiction:
                request.jurisdiction,

            issued_epoch:
                tx_context::epoch(ctx),

            expires_epoch,

            status:
                STATUS_ACTIVE,

            version:
                1,

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_credentials =
        registry.total_credentials + 1;

    registry.active_credential_count =
        registry.active_credential_count + 1;

    request.status =
        REQUEST_ATTESTED;

    request.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        EnterpriseCredentialIssued {
            registry_id:
                object::id(registry),

            credential_id,

            provider_id:
                request.provider_id,

            tmid_id:
                actual_tmid_id,

            controller:
                actual_controller,

            kyc_level,
            aml_status,
            expires_epoch,
        },
    );

    event::emit(
        EnterpriseCredentialRequestAttested {
            registry_id:
                object::id(registry),

            request_id:
                object::id(request),

            credential_id,

            provider_id:
                request.provider_id,

            tmid_id:
                actual_tmid_id,

            attested_by:
                tx_context::sender(ctx),

            attested_epoch:
                tx_context::epoch(ctx),
        },
    );

    credential_id
}


/* ============================================================
   Request Read API
   ============================================================ */

public(package) fun request_status(
    request: &CredentialRequest,
): u8 {
    request.status
}

public(package) fun request_tmid_id(
    request: &CredentialRequest,
): ID {
    request.tmid_id
}

public(package) fun request_controller(
    request: &CredentialRequest,
): address {
    request.controller
}

public(package) fun request_provider_id(
    request: &CredentialRequest,
): u64 {
    request.provider_id
}

public(package) fun request_registry_id(
    request: &CredentialRequest,
): ID {
    request.registry_id
}

public fun request_pending(): u8 {
    REQUEST_PENDING
}

public fun request_attested(): u8 {
    REQUEST_ATTESTED
}

public fun request_cancelled(): u8 {
    REQUEST_CANCELLED
}


/* ============================================================
   Request Test Support
   ============================================================ */

#[test_only]
public fun destroy_request_for_testing(
    request: CredentialRequest,
) {
    let CredentialRequest {
        id,

        registry_id: _,

        tmid_id: _,
        controller: _,

        provider_id: _,

        jurisdiction: _,

        status: _,

        created_epoch: _,
        updated_epoch: _,
    } = request;

    object::delete(id);
}
