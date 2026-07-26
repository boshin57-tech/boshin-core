module tobmate_core::cbdc_instrument;

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
   Stage 12 Part 4-C
   CBDC / Regulated Currency Control Plane
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
const E_NOT_CBDC_ASSET: u64 = 2;
const E_DUPLICATE_INSTRUMENT: u64 = 3;
const E_ZERO_UNIT_SCALE: u64 = 4;
const E_INSTRUMENT_NOT_FOUND: u64 = 5;
const E_INSTRUMENT_NOT_ACTIVE: u64 = 6;
const E_OPERATOR_MISMATCH: u64 = 7;
const E_OPERATOR_AUTHORITY_MISMATCH: u64 = 8;
const E_INVALID_STATUS_TRANSITION: u64 = 9;
const E_VERSION_NOT_INCREASING: u64 = 10;
const E_ADMIN_CAP_MISMATCH: u64 = 11;
const E_ZERO_MINT_AMOUNT: u64 = 12;
const E_ZERO_BURN_AMOUNT: u64 = 13;
const E_BURN_EXCEEDS_CIRCULATION: u64 = 14;


/* ============================================================
   Registry
   ============================================================ */

public struct CBDCInstrumentRegistry has key {
    id: UID,

    version: u64,
    paused: bool,

    next_instrument_id: u64,

    instruments: vector<CBDCInstrument>,

    total_instruments: u64,
    active_instrument_count: u64,
    suspended_instrument_count: u64,
    retired_instrument_count: u64,
}


/* ============================================================
   Admin Capability
   ============================================================ */

public struct CBDCInstrumentAdminCap has key, store {
    id: UID,
    registry_id: ID,
}


/* ============================================================
   CBDC Instrument
   ============================================================ */

public struct CBDCInstrument has store {
    instrument_id: u64,

    regulated_asset_id: u64,

    operator_institution_id: u64,
    operator_authority: address,

    unit_scale: u64,

    total_minted: u64,
    total_burned: u64,
    circulating_supply: u64,

    status: u8,
    version: u64,

    created_epoch: u64,
    updated_epoch: u64,
}


/* ============================================================
   Events
   ============================================================ */

public struct CBDCInstrumentCreated has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    regulated_asset_id: u64,
    operator_institution_id: u64,
    unit_scale: u64,
}

public struct CBDCMinted has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    amount: u64,
    circulating_supply: u64,
    minted_by: address,
}

public struct CBDCBurned has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    amount: u64,
    circulating_supply: u64,
    burned_by: address,
}

public struct CBDCInstrumentStatusChanged has copy, drop {
    registry_id: ID,
    instrument_id: u64,
    previous_status: u8,
    new_status: u8,
    changed_by: address,
}


/* ============================================================
   Creation
   ============================================================ */

public fun create(
    ctx: &mut TxContext,
): (
    CBDCInstrumentRegistry,
    CBDCInstrumentAdminCap,
) {
    let registry =
        CBDCInstrumentRegistry {
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
        CBDCInstrumentAdminCap {
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
    registry: &CBDCInstrumentRegistry,
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
    registry: &CBDCInstrumentRegistry,
    admin_cap: &CBDCInstrumentAdminCap,
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
    registry: &CBDCInstrumentRegistry,
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
            record.instrument_id == instrument_id
        ) {
            return i
        };

        i = i + 1;
    };

    abort E_INSTRUMENT_NOT_FOUND
}

fun instrument_exists_for_asset(
    registry: &CBDCInstrumentRegistry,
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
   CBDC Instrument Registration
   ============================================================ */

public fun register_instrument(
    access: &AccessControl,

    registry: &mut CBDCInstrumentRegistry,
    admin_cap: &CBDCInstrumentAdminCap,

    institution_registry_obj: &InstitutionRegistry,
    regulated_asset_registry_obj: &RegulatedAssetRegistry,

    regulated_asset_id: u64,
    operator_institution_id: u64,

    unit_scale: u64,

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
        ) == regulated_asset::asset_cbdc(),
        E_NOT_CBDC_ASSET,
    );

    institution_registry::assert_institution_active(
        institution_registry_obj,
        operator_institution_id,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == operator_institution_id,
        E_OPERATOR_MISMATCH,
    );

    assert!(
        unit_scale > 0,
        E_ZERO_UNIT_SCALE,
    );

    assert!(
        !instrument_exists_for_asset(
            registry,
            regulated_asset_id,
        ),
        E_DUPLICATE_INSTRUMENT,
    );

    let operator_authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            operator_institution_id,
        );

    let instrument_id =
        registry.next_instrument_id;

    registry.next_instrument_id =
        instrument_id + 1;

    vector::push_back(
        &mut registry.instruments,

        CBDCInstrument {
            instrument_id,
            regulated_asset_id,

            operator_institution_id,
            operator_authority,

            unit_scale,

            total_minted:
                0,

            total_burned:
                0,

            circulating_supply:
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
        CBDCInstrumentCreated {
            registry_id:
                object::id(registry),

            instrument_id,
            regulated_asset_id,
            operator_institution_id,
            unit_scale,
        },
    );

    instrument_id
}


/* ============================================================
   Instrument Guards
   ============================================================ */

public fun assert_instrument_active(
    registry: &CBDCInstrumentRegistry,
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

fun assert_operator_authority(
    institution_registry_obj: &InstitutionRegistry,
    operator_institution_id: u64,
    expected_authority: address,
    ctx: &TxContext,
) {
    institution_registry::assert_institution_active(
        institution_registry_obj,
        operator_institution_id,
    );

    let authority =
        institution_registry::institution_authority(
            institution_registry_obj,
            operator_institution_id,
        );

    assert!(
        authority == expected_authority,
        E_OPERATOR_AUTHORITY_MISMATCH,
    );

    assert!(
        authority == tx_context::sender(ctx),
        E_OPERATOR_AUTHORITY_MISMATCH,
    );
}


/* ============================================================
   CBDC Mint
   ============================================================ */

public fun mint(
    access: &AccessControl,

    registry: &mut CBDCInstrumentRegistry,

    institution_registry_obj: &InstitutionRegistry,
    regulated_asset_registry_obj: &RegulatedAssetRegistry,

    instrument_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        amount > 0,
        E_ZERO_MINT_AMOUNT,
    );

    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    let (
        regulated_asset_id,
        operator_institution_id,
        operator_authority,
        status,
    ) = {
        let instrument =
            vector::borrow(
                &registry.instruments,
                index,
            );

        (
            instrument.regulated_asset_id,
            instrument.operator_institution_id,
            instrument.operator_authority,
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
        ) == regulated_asset::asset_cbdc(),
        E_NOT_CBDC_ASSET,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == operator_institution_id,
        E_OPERATOR_MISMATCH,
    );

    assert_operator_authority(
        institution_registry_obj,
        operator_institution_id,
        operator_authority,
        ctx,
    );

    let registry_id =
        object::id(registry);

    let instrument =
        vector::borrow_mut(
            &mut registry.instruments,
            index,
        );

    instrument.total_minted =
        instrument.total_minted + amount;

    instrument.circulating_supply =
        instrument.circulating_supply + amount;

    instrument.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        CBDCMinted {
            registry_id,

            instrument_id,
            amount,

            circulating_supply:
                instrument.circulating_supply,

            minted_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   CBDC Burn
   ============================================================ */

public fun burn(
    access: &AccessControl,

    registry: &mut CBDCInstrumentRegistry,

    institution_registry_obj: &InstitutionRegistry,
    regulated_asset_registry_obj: &RegulatedAssetRegistry,

    instrument_id: u64,
    amount: u64,

    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        registry,
    );

    assert!(
        amount > 0,
        E_ZERO_BURN_AMOUNT,
    );

    let index =
        instrument_index(
            registry,
            instrument_id,
        );

    let (
        regulated_asset_id,
        operator_institution_id,
        operator_authority,
        circulating_supply,
        status,
    ) = {
        let instrument =
            vector::borrow(
                &registry.instruments,
                index,
            );

        (
            instrument.regulated_asset_id,
            instrument.operator_institution_id,
            instrument.operator_authority,
            instrument.circulating_supply,
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
        ) == regulated_asset::asset_cbdc(),
        E_NOT_CBDC_ASSET,
    );

    assert!(
        regulated_asset::asset_issuer_institution_id(
            regulated_asset_registry_obj,
            regulated_asset_id,
        ) == operator_institution_id,
        E_OPERATOR_MISMATCH,
    );

    assert_operator_authority(
        institution_registry_obj,
        operator_institution_id,
        operator_authority,
        ctx,
    );

    assert!(
        amount <= circulating_supply,
        E_BURN_EXCEEDS_CIRCULATION,
    );

    let registry_id =
        object::id(registry);

    let instrument =
        vector::borrow_mut(
            &mut registry.instruments,
            index,
        );

    instrument.total_burned =
        instrument.total_burned + amount;

    instrument.circulating_supply =
        instrument.circulating_supply - amount;

    instrument.updated_epoch =
        tx_context::epoch(ctx);

    event::emit(
        CBDCBurned {
            registry_id,

            instrument_id,
            amount,

            circulating_supply:
                instrument.circulating_supply,

            burned_by:
                tx_context::sender(ctx),
        },
    );
}


/* ============================================================
   Instrument Status Lifecycle
   ============================================================ */

public fun set_instrument_status(
    access: &AccessControl,

    registry: &mut CBDCInstrumentRegistry,
    admin_cap: &CBDCInstrumentAdminCap,

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
        CBDCInstrumentStatusChanged {
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
    admin_cap: &CBDCInstrumentAdminCap,
    registry: &mut CBDCInstrumentRegistry,
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
    admin_cap: &CBDCInstrumentAdminCap,
    registry: &mut CBDCInstrumentRegistry,
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
    registry: &CBDCInstrumentRegistry,
): ID {
    object::id(registry)
}

public fun version(
    registry: &CBDCInstrumentRegistry,
): u64 {
    registry.version
}

public fun is_paused(
    registry: &CBDCInstrumentRegistry,
): bool {
    registry.paused
}

public fun total_instruments(
    registry: &CBDCInstrumentRegistry,
): u64 {
    registry.total_instruments
}

public fun active_instrument_count(
    registry: &CBDCInstrumentRegistry,
): u64 {
    registry.active_instrument_count
}

public fun suspended_instrument_count(
    registry: &CBDCInstrumentRegistry,
): u64 {
    registry.suspended_instrument_count
}

public fun retired_instrument_count(
    registry: &CBDCInstrumentRegistry,
): u64 {
    registry.retired_instrument_count
}

public fun instrument_status(
    registry: &CBDCInstrumentRegistry,
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
    registry: &CBDCInstrumentRegistry,
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

public fun operator_institution_id(
    registry: &CBDCInstrumentRegistry,
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
    ).operator_institution_id
}

public fun unit_scale(
    registry: &CBDCInstrumentRegistry,
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
    ).unit_scale
}

public fun total_minted(
    registry: &CBDCInstrumentRegistry,
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
    ).total_minted
}

public fun total_burned(
    registry: &CBDCInstrumentRegistry,
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
    ).total_burned
}

public fun circulating_supply(
    registry: &CBDCInstrumentRegistry,
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
    ).circulating_supply
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
): CBDCInstrumentRegistry {
    CBDCInstrumentRegistry {
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
    registry: &CBDCInstrumentRegistry,
    ctx: &mut TxContext,
): CBDCInstrumentAdminCap {
    CBDCInstrumentAdminCap {
        id: object::new(ctx),

        registry_id:
            object::id(registry),
    }
}

#[test_only]
public fun destroy_for_testing(
    registry: CBDCInstrumentRegistry,
) {
    let CBDCInstrumentRegistry {
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

        let CBDCInstrument {
            instrument_id: _,
            regulated_asset_id: _,

            operator_institution_id: _,
            operator_authority: _,

            unit_scale: _,

            total_minted: _,
            total_burned: _,
            circulating_supply: _,

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
    cap: CBDCInstrumentAdminCap,
) {
    let CBDCInstrumentAdminCap {
        id,
        registry_id: _,
    } = cap;

    object::delete(
        id,
    );
}
