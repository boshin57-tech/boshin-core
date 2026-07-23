module tobmate_core::goldpeg;

use std::option;

use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{Self, AccessControl};
use tobmate_core::backing_position::{Self, GoldBackingPosition};

/// GOLDPEG uses six decimal places.
///
/// 1 GOLDPEG display unit = 1 gram of gold principal.
/// 1 milligram of backing = 1,000 minimum GOLDPEG units.
const DECIMALS: u8 = 6;
const UNITS_PER_MG: u64 = 1_000;

/// Largest milligram value that can safely be multiplied by UNITS_PER_MG.
const MAX_SAFE_WEIGHT_MG: u64 = 18_446_744_073_709_551;

/// Error codes.
const E_ZERO_AMOUNT: u64 = 1;
const E_INVALID_RECIPIENT: u64 = 2;
const E_POSITION_NOT_ACTIVE: u64 = 3;
const E_POSITION_CAPACITY_EXCEEDED: u64 = 4;
const E_POSITION_INSUFFICIENT_ISSUED_UNITS: u64 = 5;
const E_WEIGHT_OVERFLOW: u64 = 6;
const E_REGISTRY_INVARIANT: u64 = 7;
const E_SUPPLY_MISMATCH: u64 = 8;
const E_UNCHANGED_VALUE: u64 = 9;

/// One-time witness and Sui coin type.
public struct GOLDPEG has drop {}

/// Additional governance capability.
///
/// TreasuryCap remains necessary for technical mint and burn operations.
/// GoldpegAdminCap ensures those operations also pass Tobmate protocol
/// authorization rather than relying on TreasuryCap possession alone.
public struct GoldpegAdminCap has key, store {
    id: UID,
}

/// Shared aggregate state for the GOLDPEG subsystem.
public struct GoldpegRegistry has key {
    id: UID,
    version: u64,

    /// Lifetime amount minted.
    total_issued_units: u64,

    /// Lifetime amount burned.
    total_burned_units: u64,

    /// Current circulating supply tracked by this protocol.
    circulating_units: u64,

    /// Positions whose recorded GOLDPEG principal is greater than zero.
    active_backing_positions: u64,

    /// Emergency protocol-level issuance switch.
    issuance_paused: bool,
}

/// Emitted when GOLDPEG is issued against a backing position.
public struct GoldpegIssued has copy, drop {
    backing_position_id: ID,
    reserve_id: ID,
    recipient: address,
    amount: u64,
    position_issued_units_after: u64,
    circulating_units_after: u64,
    issued_by: address,
    issued_at_epoch: u64,
}

/// Emitted when GOLDPEG is burned against a backing position.
public struct GoldpegBurned has copy, drop {
    backing_position_id: ID,
    reserve_id: ID,
    amount: u64,
    position_issued_units_after: u64,
    circulating_units_after: u64,
    burned_by: address,
    burned_at_epoch: u64,
}

/// Emitted when the issuance switch changes.
public struct GoldpegIssuancePauseChanged has copy, drop {
    paused: bool,
    changed_by: address,
    changed_at_epoch: u64,
}

/// Emitted when the registry version changes.
public struct GoldpegRegistryVersionChanged has copy, drop {
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

/// Initializes the GOLDPEG currency and protocol registry.
///
/// TreasuryCap and GoldpegAdminCap are transferred to the package publisher.
/// Coin metadata is frozen because symbol, decimals and principal denomination
/// must remain immutable after publication.
fun init(witness: GOLDPEG, ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    let (treasury_cap, metadata): (
        TreasuryCap<GOLDPEG>,
        CoinMetadata<GOLDPEG>,
    ) = coin::create_currency(
        witness,
        DECIMALS,
        b"GOLDPEG",
        b"Tobmate GOLDPEG",
        b"Fungible gold principal units backed through Tobmate GoldBackingPosition objects",
        option::none(),
        ctx,
    );

    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury_cap, publisher);

    transfer::transfer(
        GoldpegAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        GoldpegRegistry {
            id: object::new(ctx),
            version: 1,
            total_issued_units: 0,
            total_burned_units: 0,
            circulating_units: 0,
            active_backing_positions: 0,
            issuance_paused: false,
        },
    );
}

/// Issues GOLDPEG against an existing GoldBackingPosition.
///
/// This function does not call gold_reserve::allocate().
/// Physical reserve allocation already occurred when the backing position
/// was created.
///
/// The caller must supply:
/// - GoldpegAdminCap for Tobmate protocol authorization.
/// - TreasuryCap<GOLDPEG> for Sui coin supply authorization.
/// - The shared GoldpegRegistry.
/// - The backing position that provides the gold principal capacity.
public fun issue(
    _admin_cap: &GoldpegAdminCap,
    treasury_cap: &mut TreasuryCap<GOLDPEG>,
    access_control: &AccessControl,
    registry: &mut GoldpegRegistry,
    position: &mut GoldBackingPosition,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(!registry.issuance_paused, E_POSITION_NOT_ACTIVE);
    assert!(amount > 0, E_ZERO_AMOUNT);
    assert!(recipient != @0x0, E_INVALID_RECIPIENT);
    assert!(
        backing_position::is_active(position),
        E_POSITION_NOT_ACTIVE,
    );

    let capacity = position_capacity_units(position);
    let issued_before =
        backing_position::goldpeg_issued_units(position);

    assert!(
        amount <= capacity - issued_before,
        E_POSITION_CAPACITY_EXCEEDED,
    );

    let circulating_after =
        registry.circulating_units + amount;

    assert!(
        circulating_after >= registry.circulating_units,
        E_REGISTRY_INVARIANT,
    );

    if (issued_before == 0) {
        registry.active_backing_positions =
            registry.active_backing_positions + 1;
    };

    backing_position::record_goldpeg_issue(position, amount);

    registry.total_issued_units =
        registry.total_issued_units + amount;
    registry.circulating_units = circulating_after;

    let issued_after =
        backing_position::goldpeg_issued_units(position);

    let minted_coin = coin::mint(
        treasury_cap,
        amount,
        ctx,
    );

    event::emit(GoldpegIssued {
        backing_position_id:
            backing_position::position_id(position),
        reserve_id:
            backing_position::reserve_id(position),
        recipient,
        amount,
        position_issued_units_after: issued_after,
        circulating_units_after: circulating_after,
        issued_by: tx_context::sender(ctx),
        issued_at_epoch: tx_context::epoch(ctx),
    });

    transfer::public_transfer(minted_coin, recipient);
}

/// Burns an entire Coin<GOLDPEG> and removes the same principal amount
/// from a selected backing position.
///
/// Coin<GOLDPEG> is fungible and does not permanently retain provenance
/// to one backing position after transfers, splits and joins. The authorized
/// redemption operator therefore selects an active position with sufficient
/// recorded principal and retires the burned amount from that position.
///
/// A user can split a larger Coin<GOLDPEG> before calling this function.
public fun burn(
    _admin_cap: &GoldpegAdminCap,
    treasury_cap: &mut TreasuryCap<GOLDPEG>,
    access_control: &AccessControl,
    registry: &mut GoldpegRegistry,
    position: &mut GoldBackingPosition,
    goldpeg_coin: Coin<GOLDPEG>,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(
        backing_position::is_active(position),
        E_POSITION_NOT_ACTIVE,
    );

    let amount = coin::value(&goldpeg_coin);
    assert!(amount > 0, E_ZERO_AMOUNT);

    let issued_before =
        backing_position::goldpeg_issued_units(position);

    assert!(
        issued_before >= amount,
        E_POSITION_INSUFFICIENT_ISSUED_UNITS,
    );

    assert!(
        registry.circulating_units >= amount,
        E_REGISTRY_INVARIANT,
    );

    backing_position::record_goldpeg_burn(position, amount);

    let burned_amount =
        coin::burn(treasury_cap, goldpeg_coin);

    assert!(burned_amount == amount, E_SUPPLY_MISMATCH);

    registry.total_burned_units =
        registry.total_burned_units + burned_amount;
    registry.circulating_units =
        registry.circulating_units - burned_amount;

    let issued_after =
        backing_position::goldpeg_issued_units(position);

    if (issued_after == 0) {
        assert!(
            registry.active_backing_positions > 0,
            E_REGISTRY_INVARIANT,
        );

        registry.active_backing_positions =
            registry.active_backing_positions - 1;
    };

    event::emit(GoldpegBurned {
        backing_position_id:
            backing_position::position_id(position),
        reserve_id:
            backing_position::reserve_id(position),
        amount: burned_amount,
        position_issued_units_after: issued_after,
        circulating_units_after:
            registry.circulating_units,
        burned_by: tx_context::sender(ctx),
        burned_at_epoch: tx_context::epoch(ctx),
    });
}

/// Pauses or resumes new GOLDPEG issuance.
///
/// This switch affects only issue().
/// Burning remains available so supply and liabilities can still be reduced.
public fun set_issuance_paused(
    _admin_cap: &GoldpegAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldpegRegistry,
    paused: bool,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(
        registry.issuance_paused != paused,
        E_UNCHANGED_VALUE,
    );

    registry.issuance_paused = paused;

    event::emit(GoldpegIssuancePauseChanged {
        paused,
        changed_by: tx_context::sender(ctx),
        changed_at_epoch: tx_context::epoch(ctx),
    });
}

/// Updates the protocol registry version.
public fun set_registry_version(
    _admin_cap: &GoldpegAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldpegRegistry,
    new_version: u64,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(
        registry.version != new_version,
        E_UNCHANGED_VALUE,
    );

    let previous_version = registry.version;
    registry.version = new_version;

    event::emit(GoldpegRegistryVersionChanged {
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

/// Returns the maximum GOLDPEG minimum units supported by a position.
///
/// A position weight of 1,000 mg supports:
///
/// 1,000 × 1,000 = 1,000,000 minimum units = 1.000000 GOLDPEG.
public fun position_capacity_units(
    position: &GoldBackingPosition,
): u64 {
    let weight_mg = backing_position::weight_mg(position);

    assert!(weight_mg <= MAX_SAFE_WEIGHT_MG, E_WEIGHT_OVERFLOW);

    weight_mg * UNITS_PER_MG
}

/// Returns the currently unused GOLDPEG issuance capacity.
public fun position_available_units(
    position: &GoldBackingPosition,
): u64 {
    let capacity = position_capacity_units(position);
    let issued =
        backing_position::goldpeg_issued_units(position);

    assert!(issued <= capacity, E_REGISTRY_INVARIANT);

    capacity - issued
}

/// Verifies the accounting relationship for one backing position.
public fun assert_position_invariants(
    position: &GoldBackingPosition,
) {
    let capacity = position_capacity_units(position);
    let issued =
        backing_position::goldpeg_issued_units(position);

    assert!(issued <= capacity, E_POSITION_CAPACITY_EXCEEDED);
}

/// Verifies registry lifetime and circulating-supply accounting.
///
/// total issued = total burned + current circulating
public fun assert_registry_invariants(
    registry: &GoldpegRegistry,
) {
    assert!(
        registry.total_issued_units ==
            registry.total_burned_units +
                registry.circulating_units,
        E_REGISTRY_INVARIANT,
    );
}

/// Verifies that the protocol registry and TreasuryCap report the same
/// circulating supply.
public fun assert_treasury_supply_matches_registry(
    registry: &GoldpegRegistry,
    treasury_cap: &TreasuryCap<GOLDPEG>,
) {
    assert!(
        coin::total_supply(treasury_cap) ==
            registry.circulating_units,
        E_SUPPLY_MISMATCH,
    );
}

/// Coin and denomination getters.

public fun decimals(): u8 {
    DECIMALS
}

public fun units_per_mg(): u64 {
    UNITS_PER_MG
}

public fun coin_value(goldpeg_coin: &Coin<GOLDPEG>): u64 {
    coin::value(goldpeg_coin)
}

/// Registry getters.

public fun registry_version(
    registry: &GoldpegRegistry,
): u64 {
    registry.version
}

public fun registry_total_issued_units(
    registry: &GoldpegRegistry,
): u64 {
    registry.total_issued_units
}

public fun registry_total_burned_units(
    registry: &GoldpegRegistry,
): u64 {
    registry.total_burned_units
}

public fun registry_circulating_units(
    registry: &GoldpegRegistry,
): u64 {
    registry.circulating_units
}

public fun registry_active_backing_positions(
    registry: &GoldpegRegistry,
): u64 {
    registry.active_backing_positions
}

public fun registry_issuance_paused(
    registry: &GoldpegRegistry,
): bool {
    registry.issuance_paused
}
