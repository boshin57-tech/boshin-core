module tobmate_core::regulated_asset_registry;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::institution_registry::{
    Self as institution_registry,
    InstitutionRegistry,
};


/* ============================================================
   Stage 12 Part 4-A
   Regulated Asset Registry

   Supported institutional asset classes:
   - ETF / regulated fund instrument
   - CBDC
   - regulated stable asset
   - tokenized security
   - tokenized bond
   - institutional commodity instrument
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Asset Classes
   ============================================================ */

const ASSET_ETF: u8 = 1;
const ASSET_CBDC: u8 = 2;
const ASSET_REGULATED_STABLE: u8 = 3;
const ASSET_SECURITY_TOKEN: u8 = 4;
const ASSET_BOND: u8 = 5;
const ASSET_COMMODITY_INSTRUMENT: u8 = 6;


/* ============================================================
   Asset Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_RETIRED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_INVALID_ASSET_CLASS: u64 = 2;
const E_EMPTY_ASSET_KEY: u64 = 3;
const E_EMPTY_SYMBOL: u64 = 4;
const E_EMPTY_JURISDICTION: u64 = 5;
const E_DUPLICATE_ASSET: u64 = 6;
const E_ASSET_NOT_FOUND: u64 = 7;
const E_ASSET_NOT_ACTIVE: u64 = 8;
const E_INVALID_STATUS_TRANSITION: u64 = 9;
const E_VERSION_NOT_INCREASING: u64 = 10;
const E_ADMIN_CAP_MISMATCH: u64 = 11;
const E_ISSUER_INACTIVE: u64 = 12;


/* ============================================================
   Registry
   ============================================================ */

public struct RegulatedAssetRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_asset_id: u64,

    assets: vector<RegulatedAssetRecord>,

    total_assets: u64,
    active_asset_count: u64,
    suspended_asset_count: u64,
    retired_asset_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct RegulatedAssetAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   Asset Record
   ============================================================ */

public struct RegulatedAssetRecord has store {
    asset_id: u64,

    asset_key: vector<u8>,
    symbol: vector<u8>,

    asset_class: u8,

    issuer_institution_id: u64,
    issuer_authority: address,

    jurisdiction: vector<u8>,

    status: u8,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct RegulatedAssetRegistered has copy, drop {
    registry_id: ID,
    asset_id: u64,
    asset_class: u8,
    issuer_institution_id: u64,
    issuer_authority: address,
    created_epoch: u64,
}

public struct RegulatedAssetStatusChanged has copy, drop {
    registry_id: ID,
    asset_id: u64,
    previous_status: u8,
    new_status: u8,
    changed_by: address,
}

public struct RegulatedAssetPauseChanged has copy, drop {
    registry_id: ID,
    paused: bool,
    changed_by: address,
}

public struct RegulatedAssetVersionChanged has copy, drop {
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
): (
    RegulatedAssetRegistry,
    RegulatedAssetAdminCap,
) {
    let registry =
        RegulatedAssetRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_asset_id:
                1,

            assets:
                vector[],

            total_assets:
                0,

            active_asset_count:
                0,

            suspended_asset_count:
                0,

            retired_asset_count:
                0,
        };

    let admin_cap =
        RegulatedAssetAdminCap {
            id: object::new(ctx),
            registry_id: object::id(&registry),
        };

    (
        registry,
        admin_cap,
    )
}


/* ============================================================
   Guards
   ============================================================ */

public fun assert_operational(
    access: &AccessControl,
    registry: &RegulatedAssetRegistry,
) {
    access_control::assert_not_paused(
        access,
    );

    assert!(
        !registry.paused,
        E_REGISTRY_PAUSED,
    );
}

fun assert_admin(
    registry: &RegulatedAssetRegistry,
    admin_cap: &RegulatedAssetAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}

fun assert_valid_asset_class(
    asset_class: u8,
) {
    assert!(
        asset_class == ASSET_ETF
            || asset_class == ASSET_CBDC
            || asset_class == ASSET_REGULATED_STABLE
            || asset_class == ASSET_SECURITY_TOKEN
            || asset_class == ASSET_BOND
            || asset_class == ASSET_COMMODITY_INSTRUMENT,
        E_INVALID_ASSET_CLASS,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun asset_index(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.assets,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.assets,
                i,
            );

        if (
            record.asset_id == asset_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_ASSET_NOT_FOUND
}

fun asset_key_exists(
    registry: &RegulatedAssetRegistry,
    asset_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &registry.assets,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.assets,
                i,
            );

        if (
            record.asset_key == *asset_key
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   Asset Registration
   ============================================================ */

public fun register_asset(
    access: &AccessControl,

    registry: &mut RegulatedAssetRegistry,
    admin_cap: &RegulatedAssetAdminCap,

    institution_registry_obj: &InstitutionRegistry,

    asset_key: vector<u8>,
    symbol: vector<u8>,

    asset_class: u8,
    issuer_institution_id: u64,

    jurisdiction: vector<u8>,

    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        registry,
    );

    assert_admin(
        registry,
        admin_cap,
    );

    assert_valid_asset_class(
        asset_class,
    );

    institution_registry::assert_institution_active(
        institution_registry_obj,
        issuer_institution_id,
    );

    assert!(
        vector::length(&asset_key) > 0,
        E_EMPTY_ASSET_KEY,
    );

    assert!(
        vector::length(&symbol) > 0,
        E_EMPTY_SYMBOL,
    );

    assert!(
        vector::length(&jurisdiction) > 0,
        E_EMPTY_JURISDICTION,
    );

    assert!(
        !asset_key_exists(
            registry,
            &asset_key,
        ),
        E_DUPLICATE_ASSET,
    );

    let issuer_authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            issuer_institution_id,
        );

    let asset_id =
        registry.next_asset_id;

    registry.next_asset_id =
        asset_id + 1;

    vector::push_back(
        &mut registry.assets,

        RegulatedAssetRecord {
            asset_id,

            asset_key,
            symbol,

            asset_class,

            issuer_institution_id,
            issuer_authority,

            jurisdiction,

            status:
                STATUS_ACTIVE,

            version:
                1,

            created_epoch:
                tx_context::epoch(ctx),

            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    registry.total_assets =
        registry.total_assets + 1;

    registry.active_asset_count =
        registry.active_asset_count + 1;

    event::emit(
        RegulatedAssetRegistered {
            registry_id:
                object::id(registry),

            asset_id,
            asset_class,

            issuer_institution_id,
            issuer_authority,

            created_epoch:
                tx_context::epoch(ctx),
        },
    );

    asset_id
}


/* ============================================================
   Status Transition
   ============================================================ */

public fun set_asset_status(
    access: &AccessControl,

    registry: &mut RegulatedAssetRegistry,
    admin_cap: &RegulatedAssetAdminCap,

    asset_id: u64,
    new_status: u8,

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
        asset_index(
            registry,
            asset_id,
        );

    let record =
        vector::borrow_mut(
            &mut registry.assets,
            index,
        );

    let previous_status =
        record.status;

    assert!(
        new_status == STATUS_ACTIVE
            || new_status == STATUS_SUSPENDED
            || new_status == STATUS_RETIRED,
        E_INVALID_STATUS_TRANSITION,
    );

    assert!(
        previous_status != new_status,
        E_INVALID_STATUS_TRANSITION,
    );

    assert!(
        previous_status != STATUS_RETIRED,
        E_INVALID_STATUS_TRANSITION,
    );

    if (previous_status == STATUS_ACTIVE) {
        registry.active_asset_count =
            registry.active_asset_count - 1;
    } else {
        registry.suspended_asset_count =
            registry.suspended_asset_count - 1;
    };

    if (new_status == STATUS_ACTIVE) {
        registry.active_asset_count =
            registry.active_asset_count + 1;
    } else if (new_status == STATUS_SUSPENDED) {
        registry.suspended_asset_count =
            registry.suspended_asset_count + 1;
    } else {
        registry.retired_asset_count =
            registry.retired_asset_count + 1;
    };

    record.status =
        new_status;

    record.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        RegulatedAssetStatusChanged {
            registry_id:
                object::id(registry),

            asset_id,
            previous_status,
            new_status,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Asset Validation / Read API
   ============================================================ */

public fun assert_asset_active(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
) {
    let index =
        asset_index(
            registry,
            asset_id,
        );

    let record =
        vector::borrow(
            &registry.assets,
            index,
        );

    assert!(
        record.status == STATUS_ACTIVE,
        E_ASSET_NOT_ACTIVE,
    );
}

public fun asset_status(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
): u8 {
    let index =
        asset_index(
            registry,
            asset_id,
        );

    vector::borrow(
        &registry.assets,
        index,
    ).status
}

public fun asset_class(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
): u8 {
    let index =
        asset_index(
            registry,
            asset_id,
        );

    vector::borrow(
        &registry.assets,
        index,
    ).asset_class
}

public fun asset_issuer_institution_id(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
): u64 {
    let index =
        asset_index(
            registry,
            asset_id,
        );

    vector::borrow(
        &registry.assets,
        index,
    ).issuer_institution_id
}

public fun asset_issuer_authority(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
): address {
    let index =
        asset_index(
            registry,
            asset_id,
        );

    vector::borrow(
        &registry.assets,
        index,
    ).issuer_authority
}

public fun asset_jurisdiction(
    registry: &RegulatedAssetRegistry,
    asset_id: u64,
): vector<u8> {
    let index =
        asset_index(
            registry,
            asset_id,
        );

    vector::borrow(
        &registry.assets,
        index,
    ).jurisdiction
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &RegulatedAssetAdminCap,
    registry: &mut RegulatedAssetRegistry,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        registry.paused != paused,
        E_INVALID_STATUS_TRANSITION,
    );

    registry.paused =
        paused;

    event::emit(
        RegulatedAssetPauseChanged {
            registry_id:
                object::id(registry),

            paused,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}

public fun set_version(
    admin_cap: &RegulatedAssetAdminCap,
    registry: &mut RegulatedAssetRegistry,
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
        RegulatedAssetVersionChanged {
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
   Registry Read API
   ============================================================ */

public fun registry_id(
    registry: &RegulatedAssetRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &RegulatedAssetRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &RegulatedAssetRegistry,
): bool {
    registry.paused
}

public fun total_assets(
    registry: &RegulatedAssetRegistry,
): u64 {
    registry.total_assets
}

public fun active_asset_count(
    registry: &RegulatedAssetRegistry,
): u64 {
    registry.active_asset_count
}

public fun suspended_asset_count(
    registry: &RegulatedAssetRegistry,
): u64 {
    registry.suspended_asset_count
}

public fun retired_asset_count(
    registry: &RegulatedAssetRegistry,
): u64 {
    registry.retired_asset_count
}


/* ============================================================
   Asset Class API
   ============================================================ */

public fun asset_etf(): u8 {
    ASSET_ETF
}

public fun asset_cbdc(): u8 {
    ASSET_CBDC
}

public fun asset_regulated_stable(): u8 {
    ASSET_REGULATED_STABLE
}

public fun asset_security_token(): u8 {
    ASSET_SECURITY_TOKEN
}

public fun asset_bond(): u8 {
    ASSET_BOND
}

public fun asset_commodity_instrument(): u8 {
    ASSET_COMMODITY_INSTRUMENT
}


/* ============================================================
   Status API
   ============================================================ */

public fun status_active(): u8 {
    STATUS_ACTIVE
}

public fun status_suspended(): u8 {
    STATUS_SUSPENDED
}

public fun status_retired(): u8 {
    STATUS_RETIRED
}


/* ============================================================
   Test Support
   ============================================================ */

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): RegulatedAssetRegistry {
    RegulatedAssetRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_asset_id:
            1,

        assets:
            vector[],

        total_assets:
            0,

        active_asset_count:
            0,

        suspended_asset_count:
            0,

        retired_asset_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &RegulatedAssetRegistry,
    ctx: &mut TxContext,
): RegulatedAssetAdminCap {
    RegulatedAssetAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: RegulatedAssetRegistry,
) {
    let RegulatedAssetRegistry {
        id,

        version: _,
        paused: _,

        next_asset_id: _,

        assets,

        total_assets: _,
        active_asset_count: _,
        suspended_asset_count: _,
        retired_asset_count: _,
    } = registry;

    let mut assets =
        assets;

    while (
        !vector::is_empty(
            &assets,
        )
    ) {
        let record =
            vector::pop_back(
                &mut assets,
            );

        let RegulatedAssetRecord {
            asset_id: _,

            asset_key: _,
            symbol: _,

            asset_class: _,

            issuer_institution_id: _,
            issuer_authority: _,

            jurisdiction: _,

            status: _,
            version: _,

            created_epoch: _,
            updated_epoch: _,
        } = record;
    };

    vector::destroy_empty(
        assets,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: RegulatedAssetAdminCap,
) {
    let RegulatedAssetAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
