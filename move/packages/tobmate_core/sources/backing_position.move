module tobmate_core::backing_position;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{Self, AccessControl};
use tobmate_core::gold_reserve::{
    Self,
    CustodianCap,
    GoldReserve,
    GoldReserveRegistry,
};

const E_ZERO_WEIGHT: u64 = 1;
const E_POSITION_NOT_ACTIVE: u64 = 2;
const E_NFT_ALREADY_LINKED: u64 = 3;
const E_GOLDPEG_ALREADY_ISSUED: u64 = 4;
const E_NFT_NOT_LINKED: u64 = 5;
const E_GOLDPEG_NOT_BURNED: u64 = 6;
const E_RESERVE_MISMATCH: u64 = 7;
const E_WEIGHT_MISMATCH: u64 = 8;
const E_UNAUTHORIZED_MODULE_STATE: u64 = 9;

const STATUS_ACTIVE: u8 = 1;
const STATUS_CLOSED: u8 = 2;

/// Administrative capability for the common backing layer.
public struct BackingAdminCap has key, store {
    id: UID,
}

/// Shared aggregate registry.
public struct BackingRegistry has key {
    id: UID,
    version: u64,
    total_positions_created: u64,
    total_active_positions: u64,
    total_closed_positions: u64,
    total_backed_weight_mg: u64,
}

/// A single physical-gold allocation shared by Gold NFT and GOLDPEG.
///
/// The physical reserve weight is allocated exactly once when this
/// position is created. Gold NFT and GOLDPEG later link to this object.
public struct GoldBackingPosition has key {
    id: UID,
    sequence: u64,
    reserve_id: ID,
    custodian: address,
    weight_mg: u64,
    purity_bps: u64,

    /// Gold NFT object linked to the collectible/additional right.
    gold_nft_id: Option<ID>,

    /// Amount of GOLDPEG principal units currently issued.
    goldpeg_issued_units: u64,

    status: u8,
    created_at_epoch: u64,
    closed_at_epoch: u64,
}

public struct BackingPositionCreated has copy, drop {
    position_id: ID,
    reserve_id: ID,
    sequence: u64,
    custodian: address,
    weight_mg: u64,
    purity_bps: u64,
}

public struct GoldNFTLinked has copy, drop {
    position_id: ID,
    gold_nft_id: ID,
}

public struct GoldNFTUnlinked has copy, drop {
    position_id: ID,
    gold_nft_id: ID,
}

public struct GoldpegPrincipalIssued has copy, drop {
    position_id: ID,
    issued_units: u64,
}

public struct GoldpegPrincipalBurned has copy, drop {
    position_id: ID,
    burned_units: u64,
}

public struct BackingPositionClosed has copy, drop {
    position_id: ID,
    reserve_id: ID,
    released_weight_mg: u64,
}

fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        BackingAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        BackingRegistry {
            id: object::new(ctx),
            version: 1,
            total_positions_created: 0,
            total_active_positions: 0,
            total_closed_positions: 0,
            total_backed_weight_mg: 0,
        },
    );
}

/// Allocates reserve weight once and creates the common backing position.
public fun create_position(
    _admin_cap: &BackingAdminCap,
    custodian_cap: &CustodianCap,
    access_control: &AccessControl,
    backing_registry: &mut BackingRegistry,
    reserve_registry: &mut GoldReserveRegistry,
    reserve: &mut GoldReserve,
    weight_mg: u64,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(weight_mg > 0, E_ZERO_WEIGHT);

    gold_reserve::assert_allocatable(reserve, weight_mg);

    gold_reserve::allocate(
        custodian_cap,
        access_control,
        reserve_registry,
        reserve,
        weight_mg,
        ctx,
    );

    backing_registry.total_positions_created =
        backing_registry.total_positions_created + 1;
    backing_registry.total_active_positions =
        backing_registry.total_active_positions + 1;
    backing_registry.total_backed_weight_mg =
        backing_registry.total_backed_weight_mg + weight_mg;

    let sequence = backing_registry.total_positions_created;
    let reserve_id = gold_reserve::reserve_id(reserve);
    let custodian = gold_reserve::custodian(reserve);
    let purity_bps = gold_reserve::purity_bps(reserve);

    let position = GoldBackingPosition {
        id: object::new(ctx),
        sequence,
        reserve_id,
        custodian,
        weight_mg,
        purity_bps,
        gold_nft_id: option::none(),
        goldpeg_issued_units: 0,
        status: STATUS_ACTIVE,
        created_at_epoch: tx_context::epoch(ctx),
        closed_at_epoch: 0,
    };

    let position_id = object::uid_to_inner(&position.id);

    event::emit(BackingPositionCreated {
        position_id,
        reserve_id,
        sequence,
        custodian,
        weight_mg,
        purity_bps,
    });

    transfer::share_object(position);
}

/// Called later by the Gold NFT module.
///
/// Package visibility prevents arbitrary external packages from linking
/// an unrelated NFT to a backing position.
public(package) fun link_gold_nft(
    position: &mut GoldBackingPosition,
    gold_nft_id: ID,
) {
    assert!(position.status == STATUS_ACTIVE, E_POSITION_NOT_ACTIVE);
    assert!(option::is_none(&position.gold_nft_id), E_NFT_ALREADY_LINKED);

    position.gold_nft_id = option::some(gold_nft_id);

    event::emit(GoldNFTLinked {
        position_id: object::uid_to_inner(&position.id),
        gold_nft_id,
    });
}

/// Called by Gold NFT burn logic.
public(package) fun unlink_gold_nft(
    position: &mut GoldBackingPosition,
    expected_gold_nft_id: ID,
) {
    assert!(position.status == STATUS_ACTIVE, E_POSITION_NOT_ACTIVE);
    assert!(option::is_some(&position.gold_nft_id), E_NFT_NOT_LINKED);

    let linked_id = *option::borrow(&position.gold_nft_id);
    assert!(linked_id == expected_gold_nft_id, E_UNAUTHORIZED_MODULE_STATE);

    position.gold_nft_id = option::none();

    event::emit(GoldNFTUnlinked {
        position_id: object::uid_to_inner(&position.id),
        gold_nft_id: expected_gold_nft_id,
    });
}

/// Called later by the GOLDPEG module when principal units are minted.
public(package) fun record_goldpeg_issue(
    position: &mut GoldBackingPosition,
    issued_units: u64,
) {
    assert!(position.status == STATUS_ACTIVE, E_POSITION_NOT_ACTIVE);
    assert!(issued_units > 0, E_ZERO_WEIGHT);
    assert!(
        position.goldpeg_issued_units == 0,
        E_GOLDPEG_ALREADY_ISSUED,
    );

    position.goldpeg_issued_units = issued_units;

    event::emit(GoldpegPrincipalIssued {
        position_id: object::uid_to_inner(&position.id),
        issued_units,
    });
}

/// Called later when all GOLDPEG principal units are burned.
public(package) fun record_goldpeg_burn(
    position: &mut GoldBackingPosition,
    burned_units: u64,
) {
    assert!(position.status == STATUS_ACTIVE, E_POSITION_NOT_ACTIVE);
    assert!(
        position.goldpeg_issued_units == burned_units,
        E_WEIGHT_MISMATCH,
    );

    position.goldpeg_issued_units = 0;

    event::emit(GoldpegPrincipalBurned {
        position_id: object::uid_to_inner(&position.id),
        burned_units,
    });
}

/// Closes the position and releases its physical reserve allocation.
///
/// Closure is permitted only after:
/// - Gold NFT has been burned/unlinked.
/// - All GOLDPEG principal units have been burned.
public fun close_position(
    _admin_cap: &BackingAdminCap,
    custodian_cap: &CustodianCap,
    access_control: &AccessControl,
    backing_registry: &mut BackingRegistry,
    reserve_registry: &mut GoldReserveRegistry,
    reserve: &mut GoldReserve,
    position: &mut GoldBackingPosition,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(position.status == STATUS_ACTIVE, E_POSITION_NOT_ACTIVE);
    assert!(option::is_none(&position.gold_nft_id), E_NFT_ALREADY_LINKED);
    assert!(position.goldpeg_issued_units == 0, E_GOLDPEG_NOT_BURNED);
    assert!(
        gold_reserve::reserve_id(reserve) == position.reserve_id,
        E_RESERVE_MISMATCH,
    );

    gold_reserve::release(
        custodian_cap,
        access_control,
        reserve_registry,
        reserve,
        position.weight_mg,
        ctx,
    );

    position.status = STATUS_CLOSED;
    position.closed_at_epoch = tx_context::epoch(ctx);

    backing_registry.total_active_positions =
        backing_registry.total_active_positions - 1;
    backing_registry.total_closed_positions =
        backing_registry.total_closed_positions + 1;
    backing_registry.total_backed_weight_mg =
        backing_registry.total_backed_weight_mg - position.weight_mg;

    event::emit(BackingPositionClosed {
        position_id: object::uid_to_inner(&position.id),
        reserve_id: position.reserve_id,
        released_weight_mg: position.weight_mg,
    });
}

/// Cross-module invariant checks.

public fun assert_active(position: &GoldBackingPosition) {
    assert!(position.status == STATUS_ACTIVE, E_POSITION_NOT_ACTIVE);
}

public fun assert_reserve(
    position: &GoldBackingPosition,
    reserve: &GoldReserve,
) {
    assert!(
        position.reserve_id == gold_reserve::reserve_id(reserve),
        E_RESERVE_MISMATCH,
    );
}

public fun assert_weight(
    position: &GoldBackingPosition,
    expected_weight_mg: u64,
) {
    assert!(position.weight_mg == expected_weight_mg, E_WEIGHT_MISMATCH);
}

public fun position_id(position: &GoldBackingPosition): ID {
    object::uid_to_inner(&position.id)
}

public fun reserve_id(position: &GoldBackingPosition): ID {
    position.reserve_id
}

public fun sequence(position: &GoldBackingPosition): u64 {
    position.sequence
}

public fun custodian(position: &GoldBackingPosition): address {
    position.custodian
}

public fun weight_mg(position: &GoldBackingPosition): u64 {
    position.weight_mg
}

public fun purity_bps(position: &GoldBackingPosition): u64 {
    position.purity_bps
}

public fun goldpeg_issued_units(
    position: &GoldBackingPosition,
): u64 {
    position.goldpeg_issued_units
}

public fun has_gold_nft(position: &GoldBackingPosition): bool {
    option::is_some(&position.gold_nft_id)
}

public fun gold_nft_id(position: &GoldBackingPosition): Option<ID> {
    position.gold_nft_id
}

public fun is_active(position: &GoldBackingPosition): bool {
    position.status == STATUS_ACTIVE
}

public fun is_closed(position: &GoldBackingPosition): bool {
    position.status == STATUS_CLOSED
}

public fun registry_total_positions_created(
    registry: &BackingRegistry,
): u64 {
    registry.total_positions_created
}

public fun registry_total_active_positions(
    registry: &BackingRegistry,
): u64 {
    registry.total_active_positions
}

public fun registry_total_closed_positions(
    registry: &BackingRegistry,
): u64 {
    registry.total_closed_positions
}

public fun registry_total_backed_weight_mg(
    registry: &BackingRegistry,
): u64 {
    registry.total_backed_weight_mg
}

// TOBMATE_TEST_BACKING_POSITION_FIXTURE
#[test_only]
public fun new_for_testing(
    reserve_id: ID,
    custodian: address,
    weight_mg: u64,
    purity_bps: u64,
    ctx: &mut TxContext,
): GoldBackingPosition {
    assert!(weight_mg > 0, E_ZERO_WEIGHT);

    GoldBackingPosition {
        id: object::new(ctx),
        sequence: 1,
        reserve_id,
        custodian,
        weight_mg,
        purity_bps,
        gold_nft_id: option::none(),
        goldpeg_issued_units: 0,
        status: STATUS_ACTIVE,
        created_at_epoch: tx_context::epoch(ctx),
        closed_at_epoch: 0,
    }
}

#[test_only]
public fun destroy_for_testing(
    position: GoldBackingPosition,
) {
    let GoldBackingPosition {
        id,
        sequence: _,
        reserve_id: _,
        custodian: _,
        weight_mg: _,
        purity_bps: _,
        gold_nft_id,
        goldpeg_issued_units: _,
        status: _,
        created_at_epoch: _,
        closed_at_epoch: _,
    } = position;

    option::destroy_none(gold_nft_id);
    object::delete(id);
}

// TOBMATE_GOLD_MARKETPLACE_POSITION_TEST_HELPERS

#[test_only]
public fun destroy_linked_for_testing(
    position: GoldBackingPosition,
) {
    let GoldBackingPosition {
        id,
        sequence: _,
        reserve_id: _,
        custodian: _,
        weight_mg: _,
        purity_bps: _,
        gold_nft_id,
        goldpeg_issued_units: _,
        status: _,
        created_at_epoch: _,
        closed_at_epoch: _,
    } = position;

    if (option::is_some(&gold_nft_id)) {
        let _ = option::destroy_some(gold_nft_id);
    } else {
        option::destroy_none(gold_nft_id);
    };

    object::delete(id);
}
