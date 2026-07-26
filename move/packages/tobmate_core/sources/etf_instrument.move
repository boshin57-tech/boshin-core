module tobmate_core::etf_instrument;

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

use tobmate_core::regulated_asset_registry::{
    Self as regulated_asset,
    RegulatedAssetRegistry,
};


/* ============================================================
   Stage 12 Part 4-B
   ETF / Fund Instrument Control Plane
   ============================================================ */

const PROTOCOL_VERSION: u64 = 1;


/* ============================================================
   Instrument Status
   ============================================================ */

const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_RETIRED: u8 = 3;


/* ============================================================
   Errors
   ============================================================ */

const E_REGISTRY_PAUSED: u64 = 1;
const E_NOT_ETF_ASSET: u64 = 2;
const E_DUPLICATE_INSTRUMENT: u64 = 3;
const E_ZERO_CREATION_UNIT: u64 = 4;
const E_INSTRUMENT_NOT_FOUND: u64 = 5;
const E_INSTRUMENT_NOT_ACTIVE: u64 = 6;
const E_ISSUER_MISMATCH: u64 = 7;
const E_ISSUER_AUTHORITY_MISMATCH: u64 = 8;
const E_INVALID_STATUS_TRANSITION: u64 = 9;
const E_VERSION_NOT_INCREASING: u64 = 10;
const E_ADMIN_CAP_MISMATCH: u64 = 11;
const E_ZERO_ISSUE_UNITS: u64 = 12;
const E_ZERO_REDEEM_UNITS: u64 = 13;
const E_REDEEM_EXCEEDS_OUTSTANDING: u64 = 14;
const E_CREATION_UNIT_MISMATCH: u64 = 15;


/* ============================================================
   Registry
   ============================================================ */

public struct ETFInstrumentRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_instrument_id: u64,

    instruments: vector<ETFInstrument>,

    total_instruments: u64,
    active_instrument_count: u64,
    suspended_instrument_count: u64,
    retired_instrument_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct ETFInstrumentAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   ETF Instrument
   ============================================================ */

public struct ETFInstrument has store {
    instrument_id: u64,

    regulated_asset_id: u64,

    issuer_institution_id: u64,
    issuer_authority: address,

    creation_unit_size: u64,

    total_issued_units: u64,
    total_redeemed_units: u64,
    outstanding_units: u64,

    status: u8,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct ETFInstrumentCreated has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    regulated_asset_id: u64,
    issuer_institution_id: u64,
    creation_unit_size: u64,
}

public struct ETFInstrumentStatusChanged has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    previous_status: u8,
    new_status: u8,
    changed_by: address,
}

public struct ETFUnitsIssued has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    issued_units: u64,
    outstanding_units: u64,
    issued_by: address,
}

public struct ETFUnitsRedeemed has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    redeemed_units: u64,
    outstanding_units: u64,
    redeemed_by: address,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    ETFInstrumentRegistry,
    ETFInstrumentAdminCap,
) {
    let registry =
        ETFInstrumentRegistry {
            id: object::new(ctx),

            version:
                PROTOCOL_VERSION,

            paused:
                false,

            next_instrument_id:
                1,

            instruments:
                vector[],

            total_instruments:
                0,

            active_instrument_count:
                0,

            suspended_instrument_count:
                0,

            retired_instrument_count:
                0,
        };

    let admin_cap =
        ETFInstrumentAdminCap {
            id: object::new(ctx),

            registry_id:
                object::id(&registry),
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
    registry: &ETFInstrumentRegistry,
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
    registry: &ETFInstrumentRegistry,
    admin_cap: &ETFInstrumentAdminCap,
) {
    assert!(
        admin_cap.registry_id
            == object::id(registry),
        E_ADMIN_CAP_MISMATCH,
    );
}


/* ============================================================
   Lookup
   ============================================================ */

fun instrument_index(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let length =
        vector::length(
            &registry.instruments,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.instruments,
                i,
            );

        if (
            record.instrument_id
                == instrument_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_INSTRUMENT_NOT_FOUND
}

fun instrument_exists_for_asset(
    registry: &ETFInstrumentRegistry,
    regulated_asset_id: u64,
): bool {
    let length =
        vector::length(
            &registry.instruments,
        );

    let mut i = 0;

    while (i < length) {
        let record =
            vector::borrow(
                &registry.instruments,
                i,
            );

        if (
            record.regulated_asset_id
                == regulated_asset_id
        ) {
            return true
        };

        i = i + 1;
    };

    false
}


/* ============================================================
   ETF Instrument Registration
   ============================================================ */

public fun register_instrument(
    access: &AccessControl,

    registry: &mut ETFInstrumentRegistry,
    admin_cap: &ETFInstrumentAdminCap,

    institution_registry_obj: &InstitutionRegistry,
    regulated_asset_registry_obj: &RegulatedAssetRegistry,

    regulated_asset_id: u64,
    issuer_institution_id: u64,

    creation_unit_size: u64,

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

    regulated_asset::assert_asset_active(
        regulated_asset_registry_obj,
        regulated_asset_id,
    );

    assert!(
        regulated_asset::asset_class(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == regulated_asset::asset_etf(),
        E_NOT_ETF_ASSET,
    );

    institution_registry::assert_institution_active(
        institution_registry_obj,
        issuer_institution_id,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == issuer_institution_id,
        E_ISSUER_MISMATCH,
    );

    assert!(
        creation_unit_size > 0,
        E_ZERO_CREATION_UNIT,
    );

    assert!(
        !instrument_exists_for_asset(
            registry,
            regulated_asset_id,
        ),
        E_DUPLICATE_INSTRUMENT,
    );

    let issuer_authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            issuer_institution_id,
        );

    let instrument_id =
        registry.next_instrument_id;

    registry.next_instrument_id =
        instrument_id + 1;

    vector::push_back(
        &mut registry.instruments,

        ETFInstrument {
            instrument_id,
            regulated_asset_id,

            issuer_institution_id,
            issuer_authority,

            creation_unit_size,

            total_issued_units:
                0,

            total_redeemed_units:
                0,

            outstanding_units:
                0,

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

    registry.total_instruments =
        registry.total_instruments + 1;

    registry.active_instrument_count =
        registry.active_instrument_count + 1;

    event::emit(
        ETFInstrumentCreated {
            registry_id:
                object::id(registry),

            instrument_id,
            regulated_asset_id,
            issuer_institution_id,
            creation_unit_size,
        },
    );

    instrument_id
}


/* ============================================================
   Instrument Guards
   ============================================================ */

public fun assert_instrument_active(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
) {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    let instrument =
        vector::borrow(
            &registry.instruments,
            index,
        );

    assert!(
        instrument.status == STATUS_ACTIVE,
        E_INSTRUMENT_NOT_ACTIVE,
    );
}

fun assert_issuer_authority(
    institution_registry_obj: &InstitutionRegistry,
    issuer_institution_id: u64,
    expected_authority: address,
    ctx: &TxContext,
) {
    institution_registry::assert_institution_active(
        institution_registry_obj,
        issuer_institution_id,
    );

    let authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            issuer_institution_id,
        );

    assert!(
        authority == expected_authority,
        E_ISSUER_AUTHORITY_MISMATCH,
    );

    assert!(
        authority == tx_context::sender(ctx),
        E_ISSUER_AUTHORITY_MISMATCH,
    );
}


/* ============================================================
   ETF Unit Issuance
   ============================================================ */

public fun issue_units(
    access: &AccessControl,

    registry: &mut ETFInstrumentRegistry,

    institution_registry_obj: &InstitutionRegistry,
    regulated_asset_registry_obj: &RegulatedAssetRegistry,

    instrument_id: u64,
    issue_units: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        issue_units > 0,
        E_ZERO_ISSUE_UNITS,
    );

    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    let (
        regulated_asset_id,
        issuer_institution_id,
        issuer_authority,
        creation_unit_size,
        status,
    ) = {
        let instrument =
            vector::borrow(
                &registry.instruments,
                index,
            );

        (
            instrument.regulated_asset_id,
            instrument.issuer_institution_id,
            instrument.issuer_authority,
            instrument.creation_unit_size,
            instrument.status,
        )
    };

    assert!(
        status == STATUS_ACTIVE,
        E_INSTRUMENT_NOT_ACTIVE,
    );

    regulated_asset::assert_asset_active(
        regulated_asset_registry_obj,
        regulated_asset_id,
    );

    assert!(
        regulated_asset::asset_class(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == regulated_asset::asset_etf(),
        E_NOT_ETF_ASSET,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == issuer_institution_id,
        E_ISSUER_MISMATCH,
    );

    assert_issuer_authority(
        institution_registry_obj,
        issuer_institution_id,
        issuer_authority,
        ctx,
    );

    assert!(
        issue_units % creation_unit_size == 0,
        E_CREATION_UNIT_MISMATCH,
    );

    let registry_id =
        object::id(registry);

    let instrument =
        vector::borrow_mut(
            &mut registry.instruments,
            index,
        );

    instrument.total_issued_units =
        instrument.total_issued_units + issue_units;

    instrument.outstanding_units =
        instrument.outstanding_units + issue_units;

    instrument.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        ETFUnitsIssued {
            registry_id,

            instrument_id,
            issued_units:
                issue_units,

            outstanding_units:
                instrument.outstanding_units,

            issued_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   ETF Unit Redemption
   ============================================================ */

public fun redeem_units(
    access: &AccessControl,

    registry: &mut ETFInstrumentRegistry,

    institution_registry_obj: &InstitutionRegistry,
    regulated_asset_registry_obj: &RegulatedAssetRegistry,

    instrument_id: u64,
    redeem_units: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        redeem_units > 0,
        E_ZERO_REDEEM_UNITS,
    );

    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    let (
        regulated_asset_id,
        issuer_institution_id,
        issuer_authority,
        creation_unit_size,
        outstanding_units,
        status,
    ) = {
        let instrument =
            vector::borrow(
                &registry.instruments,
                index,
            );

        (
            instrument.regulated_asset_id,
            instrument.issuer_institution_id,
            instrument.issuer_authority,
            instrument.creation_unit_size,
            instrument.outstanding_units,
            instrument.status,
        )
    };

    assert!(
        status == STATUS_ACTIVE,
        E_INSTRUMENT_NOT_ACTIVE,
    );

    regulated_asset::assert_asset_active(
        regulated_asset_registry_obj,
        regulated_asset_id,
    );

    assert!(
        regulated_asset::asset_class(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == regulated_asset::asset_etf(),
        E_NOT_ETF_ASSET,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == issuer_institution_id,
        E_ISSUER_MISMATCH,
    );

    assert_issuer_authority(
        institution_registry_obj,
        issuer_institution_id,
        issuer_authority,
        ctx,
    );

    assert!(
        redeem_units % creation_unit_size == 0,
        E_CREATION_UNIT_MISMATCH,
    );

    assert!(
        redeem_units <= outstanding_units,
        E_REDEEM_EXCEEDS_OUTSTANDING,
    );

    let registry_id =
        object::id(registry);

    let instrument =
        vector::borrow_mut(
            &mut registry.instruments,
            index,
        );

    instrument.total_redeemed_units =
        instrument.total_redeemed_units + redeem_units;

    instrument.outstanding_units =
        instrument.outstanding_units - redeem_units;

    instrument.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        ETFUnitsRedeemed {
            registry_id,

            instrument_id,
            redeemed_units:
                redeem_units,

            outstanding_units:
                instrument.outstanding_units,

            redeemed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Instrument Status Lifecycle
   ============================================================ */

public fun set_instrument_status(
    access: &AccessControl,

    registry: &mut ETFInstrumentRegistry,
    admin_cap: &ETFInstrumentAdminCap,

    instrument_id: u64,
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
        instrument_index(
            registry,
            instrument_id,
        );

    let instrument =
        vector::borrow_mut(
            &mut registry.instruments,
            index,
        );

    let previous_status =
        instrument.status;

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
        registry.active_instrument_count =
            registry.active_instrument_count - 1;
    } else {
        registry.suspended_instrument_count =
            registry.suspended_instrument_count - 1;
    };

    if (new_status == STATUS_ACTIVE) {
        registry.active_instrument_count =
            registry.active_instrument_count + 1;
    } else if (new_status == STATUS_SUSPENDED) {
        registry.suspended_instrument_count =
            registry.suspended_instrument_count + 1;
    } else {
        registry.retired_instrument_count =
            registry.retired_instrument_count + 1;
    };

    instrument.status =
        new_status;

    instrument.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        ETFInstrumentStatusChanged {
            registry_id:
                object::id(registry),

            instrument_id,
            previous_status,
            new_status,

            changed_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Registry Administration
   ============================================================ */

public fun set_paused(
    admin_cap: &ETFInstrumentAdminCap,
    registry: &mut ETFInstrumentRegistry,
    paused: bool,
    _ctx: &mut TxContext,
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
}

public fun set_version(
    admin_cap: &ETFInstrumentAdminCap,
    registry: &mut ETFInstrumentRegistry,
    new_version: u64,
    _ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        admin_cap,
    );

    assert!(
        new_version > registry.version,
        E_VERSION_NOT_INCREASING,
    );

    registry.version =
        new_version;
}


/* ============================================================
   Read API
   ============================================================ */

public fun registry_id(
    registry: &ETFInstrumentRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &ETFInstrumentRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &ETFInstrumentRegistry,
): bool {
    registry.paused
}

public fun total_instruments(
    registry: &ETFInstrumentRegistry,
): u64 {
    registry.total_instruments
}

public fun active_instrument_count(
    registry: &ETFInstrumentRegistry,
): u64 {
    registry.active_instrument_count
}

public fun suspended_instrument_count(
    registry: &ETFInstrumentRegistry,
): u64 {
    registry.suspended_instrument_count
}

public fun retired_instrument_count(
    registry: &ETFInstrumentRegistry,
): u64 {
    registry.retired_instrument_count
}

public fun instrument_status(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u8 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).status
}

public fun instrument_regulated_asset_id(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).regulated_asset_id
}

public fun instrument_issuer_institution_id(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).issuer_institution_id
}

public fun creation_unit_size(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).creation_unit_size
}

public fun total_issued_units(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).total_issued_units
}

public fun total_redeemed_units(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).total_redeemed_units
}

public fun outstanding_units(
    registry: &ETFInstrumentRegistry,
    instrument_id: u64,
): u64 {
    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    vector::borrow(
        &registry.instruments,
        index,
    ).outstanding_units
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
): ETFInstrumentRegistry {
    ETFInstrumentRegistry {
        id: object::new(ctx),

        version:
            PROTOCOL_VERSION,

        paused:
            false,

        next_instrument_id:
            1,

        instruments:
            vector[],

        total_instruments:
            0,

        active_instrument_count:
            0,

        suspended_instrument_count:
            0,

        retired_instrument_count:
            0,
    }
}

#[test_only]
public fun admin_cap_for_testing(
    registry: &ETFInstrumentRegistry,
    ctx: &mut TxContext,
): ETFInstrumentAdminCap {
    ETFInstrumentAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: ETFInstrumentRegistry,
) {
    let ETFInstrumentRegistry {
        id,

        version: _,
        paused: _,

        next_instrument_id: _,

        instruments,

        total_instruments: _,
        active_instrument_count: _,
        suspended_instrument_count: _,
        retired_instrument_count: _,
    } = registry;

    let mut instruments =
        instruments;

    while (
        !vector::is_empty(
            &instruments,
        )
    ) {
        let instrument =
            vector::pop_back(
                &mut instruments,
            );

        let ETFInstrument {
            instrument_id: _,
            regulated_asset_id: _,

            issuer_institution_id: _,
            issuer_authority: _,

            creation_unit_size: _,

            total_issued_units: _,
            total_redeemed_units: _,
            outstanding_units: _,

            status: _,
            version: _,

            created_epoch: _,
            updated_epoch: _,
        } = instrument;
    };

    vector::destroy_empty(
        instruments,
    );

    object::delete(
        id,
    );
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: ETFInstrumentAdminCap,
) {
    let ETFInstrumentAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
