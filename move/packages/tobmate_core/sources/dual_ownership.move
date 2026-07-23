module tobmate_core::dual_ownership;

use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::event;
use sui::table::{Self, Table};

use tobmate_core::access_control::{Self, AccessControl};
use tobmate_core::gold_nft::{Self, GoldNFT, GoldNFTAdminCap, GoldNFTRegistry};
use tobmate_core::backing_position::{Self, GoldBackingPosition};

/// ================================================================
/// Dual Ownership status constants
/// ================================================================

/// The record is active and its ownership rights may be managed.
const STATUS_ACTIVE: u8 = 1;

/// The record has completed its lifecycle.
const STATUS_CLOSED: u8 = 2;

/// ================================================================
/// Error codes
/// ================================================================

/// An owner address must not be the zero address.
const E_INVALID_OWNER: u64 = 1;

/// The record is not active.
const E_NOT_ACTIVE: u64 = 2;

/// The record has already been closed.
const E_ALREADY_CLOSED: u64 = 3;

/// The record is frozen.
const E_FROZEN: u64 = 4;

/// The transaction sender is not the principal owner.
const E_NOT_PRINCIPAL_OWNER: u64 = 5;

/// The transaction sender is not the collectible owner.
const E_NOT_COLLECTIBLE_OWNER: u64 = 6;

/// The proposed owner is already the current owner.
const E_SAME_OWNER: u64 = 7;

/// The supplied backing position does not match the record.
const E_POSITION_MISMATCH: u64 = 8;

/// The supplied GoldNFT does not match the record.
const E_NFT_MISMATCH: u64 = 9;

/// The GoldNFT remains linked to the backing position.
const E_NFT_STILL_LINKED: u64 = 10;

/// The principal owner's burn approval is missing.
const E_PRINCIPAL_APPROVAL_REQUIRED: u64 = 11;

/// The collectible owner's burn approval is missing.
const E_COLLECTIBLE_APPROVAL_REQUIRED: u64 = 12;

/// The requested value is the same as the existing value.
const E_UNCHANGED_VALUE: u64 = 13;

/// Registry aggregate accounting is inconsistent.
const E_REGISTRY_INVARIANT: u64 = 14;

/// The record contains an unsupported lifecycle status.
const E_INVALID_STATUS: u64 = 15;

/// A duplicate dual ownership record was detected.
const E_DUPLICATE_RECORD: u64 = 16;

/// Registry arithmetic would overflow or underflow.
const E_REGISTRY_ARITHMETIC: u64 = 17;

/// ================================================================
/// Administrative capability
/// ================================================================

/// Capability controlling administrative operations for the
/// dual ownership subsystem.
///
/// This capability is initially transferred to the package publisher.
public struct DualOwnershipAdminCap has key, store {
    id: UID,
}

/// ================================================================
/// Shared registry
/// ================================================================

/// Shared aggregate state for all DualOwnershipRecord objects.
///
/// The registry does not itself own individual records. It maintains
/// global accounting values and protocol version information.
public struct DualOwnershipRegistry has key {
    id: UID,

    /// Registry schema and protocol version.
    version: u64,

    /// Lifetime number of records created.
    total_created: u64,

    /// Number of records currently in STATUS_ACTIVE.
    total_active: u64,

    /// Lifetime number of records moved to STATUS_CLOSED.
    total_closed: u64,

    /// Lifetime number of principal ownership transfers.
    total_principal_transfers: u64,

    /// Lifetime number of collectible ownership transfers.
    total_collectible_transfers: u64,

    /// Lifetime number of principal burn approvals granted.
    total_principal_approvals: u64,

    /// Lifetime number of collectible burn approvals granted.
    total_collectible_approvals: u64,

    /// Maps each backing position to its single active
    /// DualOwnershipRecord.
    active_record_by_position: Table<ID, ID>,
}

/// ================================================================
/// Dual ownership record
/// ================================================================

/// Separates physical-gold principal ownership from GoldNFT
/// collectible ownership.
///
/// One GoldBackingPosition may provide two independently managed rights:
///
/// 1. principal_owner
///    - owns the original physical-gold principal and redemption right;
///
/// 2. collectible_owner
///    - owns the artistic, commemorative and tradable GoldNFT right.
///
/// Transferring the GoldNFT must not automatically transfer the physical
/// gold principal right.
public struct DualOwnershipRecord has key {
    id: UID,

    /// GoldBackingPosition associated with this record.
    backing_position_id: ID,

    /// GoldReserve associated with the backing position.
    reserve_id: ID,

    /// GoldNFT associated with the backing position.
    gold_nft_id: ID,

    /// First investor who established the original principal position.
    ///
    /// This address is historical and must never change.
    original_investor: address,

    /// Current physical-gold principal owner.
    principal_owner: address,

    /// Current GoldNFT collectible owner.
    collectible_owner: address,

    /// Gold weight snapshot copied from the backing position.
    weight_mg: u64,

    /// Gold purity snapshot copied from the backing position.
    purity_bps: u64,

    /// Current principal owner's approval for GoldNFT burn.
    principal_burn_approved: bool,

    /// Current collectible owner's approval for GoldNFT burn.
    collectible_burn_approved: bool,

    /// Emergency freeze state.
    frozen: bool,

    /// Current lifecycle status.
    status: u8,

    /// Epoch in which the record was created.
    created_at_epoch: u64,

    /// Epoch in which the record was most recently updated.
    updated_at_epoch: u64,
}

/// ================================================================
/// Events
/// ================================================================

/// Emitted when a dual ownership record is created.
public struct DualOwnershipCreated has copy, drop {
    record_id: ID,
    backing_position_id: ID,
    reserve_id: ID,
    gold_nft_id: ID,
    original_investor: address,
    principal_owner: address,
    collectible_owner: address,
    weight_mg: u64,
    purity_bps: u64,
    created_by: address,
    created_at_epoch: u64,
}

/// Emitted when physical-gold principal ownership changes.
public struct PrincipalOwnershipTransferred has copy, drop {
    record_id: ID,
    backing_position_id: ID,
    previous_owner: address,
    new_owner: address,
    transferred_by: address,
    transferred_at_epoch: u64,
}

/// Emitted when GoldNFT collectible ownership changes.
public struct CollectibleOwnershipTransferred has copy, drop {
    record_id: ID,
    gold_nft_id: ID,
    previous_owner: address,
    new_owner: address,
    synchronized_by: address,
    synchronized_at_epoch: u64,
}

/// Emitted when the principal owner grants or revokes burn approval.
public struct PrincipalBurnApprovalChanged has copy, drop {
    record_id: ID,
    principal_owner: address,
    approved: bool,
    changed_at_epoch: u64,
}

/// Emitted when the collectible owner grants or revokes burn approval.
public struct CollectibleBurnApprovalChanged has copy, drop {
    record_id: ID,
    collectible_owner: address,
    approved: bool,
    changed_at_epoch: u64,
}

/// Emitted when a dual ownership record is frozen or unfrozen.
public struct DualOwnershipFrozenStateChanged has copy, drop {
    record_id: ID,
    frozen: bool,
    changed_by: address,
    changed_at_epoch: u64,
}

/// Emitted when a dual ownership record is closed.
public struct DualOwnershipClosed has copy, drop {
    record_id: ID,
    backing_position_id: ID,
    gold_nft_id: ID,
    principal_owner: address,
    collectible_owner: address,
    closed_by: address,
    closed_at_epoch: u64,
}

/// Emitted when the registry version changes.
public struct DualOwnershipRegistryVersionChanged has copy, drop {
    previous_version: u64,
    new_version: u64,
    changed_by: address,
    changed_at_epoch: u64,
}

/// ================================================================
/// Module initialization
/// ================================================================

/// Initializes the dual ownership subsystem.
///
/// Creates:
///
/// - one publisher-owned DualOwnershipAdminCap;
/// - one shared DualOwnershipRegistry.
fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    let admin_cap = DualOwnershipAdminCap {
        id: object::new(ctx),
    };

    let registry = DualOwnershipRegistry {
        id: object::new(ctx),
        version: 1,
        total_created: 0,
        total_active: 0,
        total_closed: 0,
        total_principal_transfers: 0,
        total_collectible_transfers: 0,
        total_principal_approvals: 0,
        total_collectible_approvals: 0,
            active_record_by_position: table::new(ctx),
};

    transfer::transfer(admin_cap, publisher);
    transfer::share_object(registry);
}

/// ================================================================
/// Record creation
/// ================================================================

public fun create_record(
    _admin_cap: &DualOwnershipAdminCap,
    access_control: &AccessControl,
    registry: &mut DualOwnershipRegistry,
    position: &GoldBackingPosition,
    nft: &GoldNFT,
    original_investor: address,
    principal_owner: address,
    collectible_owner: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(original_investor != @0x0, E_INVALID_OWNER);
    assert!(principal_owner != @0x0, E_INVALID_OWNER);
    assert!(collectible_owner != @0x0, E_INVALID_OWNER);

    assert!(
        backing_position::is_active(position),
        E_NOT_ACTIVE,
    );

    assert!(
        gold_nft::is_active(nft),
        E_NOT_ACTIVE,
    );

    gold_nft::assert_matches_position(nft, position);
    gold_nft::assert_linked_to_position(nft, position);

    let position_id =
        backing_position::position_id(position);

    // A backing position may have only one active
    // DualOwnershipRecord.
    assert!(
        !table::contains(
            &registry.active_record_by_position,
            position_id,
        ),
        E_DUPLICATE_RECORD,
    );


    let reserve_id =
        backing_position::reserve_id(position);

    let nft_id =
        gold_nft::nft_id(nft);

    let weight_mg =
        backing_position::weight_mg(position);

    let purity_bps =
        backing_position::purity_bps(position);

    let epoch =
        tx_context::epoch(ctx);

    let record = DualOwnershipRecord {
        id: object::new(ctx),
        backing_position_id: position_id,
        reserve_id,
        gold_nft_id: nft_id,
        original_investor,
        principal_owner,
        collectible_owner,
        weight_mg,
        purity_bps,
        principal_burn_approved: false,
        collectible_burn_approved: false,
        frozen: false,
        status: STATUS_ACTIVE,
        created_at_epoch: epoch,
        updated_at_epoch: epoch,
    };

    let record_id =
        object::id(&record);

    let created_after =
        registry.total_created + 1;

    let active_after =
        registry.total_active + 1;

    assert!(
        created_after > registry.total_created,
        E_REGISTRY_ARITHMETIC,
    );

    assert!(
        active_after > registry.total_active,
        E_REGISTRY_ARITHMETIC,
    );

    registry.total_created = created_after;
    registry.total_active = active_after;

        let active_record_id = object::id(&record);

    table::add(
        &mut registry.active_record_by_position,
        position_id,
        active_record_id,
    );

event::emit(DualOwnershipCreated {
        record_id,
        backing_position_id: position_id,
        reserve_id,
        gold_nft_id: nft_id,
        original_investor,
        principal_owner,
        collectible_owner,
        weight_mg,
        purity_bps,
        created_by: tx_context::sender(ctx),
        created_at_epoch: epoch,
    });

    transfer::share_object(record);
}

/// ================================================================
/// State assertions
/// ================================================================

public fun assert_active(
    record: &DualOwnershipRecord,
) {
    assert!(
        record.status != STATUS_CLOSED,
        E_ALREADY_CLOSED,
    );

    assert!(
        record.status == STATUS_ACTIVE,
        E_INVALID_STATUS,
    );
}

public fun assert_active_and_unfrozen(
    record: &DualOwnershipRecord,
) {
    assert_active(record);

    assert!(
        !record.frozen,
        E_FROZEN,
    );
}

public fun assert_matches_position(
    record: &DualOwnershipRecord,
    position: &GoldBackingPosition,
) {
    assert!(
        record.backing_position_id ==
            backing_position::position_id(position),
        E_POSITION_MISMATCH,
    );

    assert!(
        record.reserve_id ==
            backing_position::reserve_id(position),
        E_POSITION_MISMATCH,
    );

    assert!(
        record.weight_mg ==
            backing_position::weight_mg(position),
        E_POSITION_MISMATCH,
    );

    assert!(
        record.purity_bps ==
            backing_position::purity_bps(position),
        E_POSITION_MISMATCH,
    );
}

public fun assert_matches_position_and_nft(
    record: &DualOwnershipRecord,
    position: &GoldBackingPosition,
    nft: &GoldNFT,
) {
    assert_matches_position(record, position);

    assert!(
        record.gold_nft_id ==
            gold_nft::nft_id(nft),
        E_NFT_MISMATCH,
    );

    assert!(
        gold_nft::backing_position_id(nft) ==
            record.backing_position_id,
        E_NFT_MISMATCH,
    );

    assert!(
        gold_nft::reserve_id(nft) ==
            record.reserve_id,
        E_NFT_MISMATCH,
    );

    gold_nft::assert_matches_position(nft, position);
    gold_nft::assert_linked_to_position(nft, position);
}

public fun assert_registry_invariants(
    registry: &DualOwnershipRegistry,
) {
    assert!(
        registry.total_created ==
            registry.total_active +
                registry.total_closed,
        E_REGISTRY_INVARIANT,
    );
}

/// ================================================================
/// Principal ownership transfer
/// ================================================================

/// Transfers only the physical-gold principal and redemption rights.
///
/// The transaction sender must be the current principal owner.
///
/// This function does not:
///
/// - transfer the linked GoldNFT;
/// - modify collectible_owner;
/// - modify original_investor;
/// - allocate or release physical gold reserve.
///
/// Any principal burn approval made by the former owner is automatically
/// revoked because that approval must not be inherited by the new owner.
public fun transfer_principal_ownership(
    access_control: &AccessControl,
    registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    new_owner: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert_active_and_unfrozen(record);

    let sender = tx_context::sender(ctx);

    assert!(
        sender == record.principal_owner,
        E_NOT_PRINCIPAL_OWNER,
    );

    assert!(
        new_owner != @0x0,
        E_INVALID_OWNER,
    );

    assert!(
        new_owner != record.principal_owner,
        E_SAME_OWNER,
    );

    let previous_owner = record.principal_owner;
    let epoch = tx_context::epoch(ctx);

    record.principal_owner = new_owner;

    // Consent granted by the previous principal owner cannot be
    // transferred to or inherited by the new principal owner.
    record.principal_burn_approved = false;
    record.updated_at_epoch = epoch;

    let transfer_count_after =
        registry.total_principal_transfers + 1;

    assert!(
        transfer_count_after >
            registry.total_principal_transfers,
        E_REGISTRY_ARITHMETIC,
    );

    registry.total_principal_transfers =
        transfer_count_after;

    event::emit(PrincipalOwnershipTransferred {
        record_id: object::id(record),
        backing_position_id: record.backing_position_id,
        previous_owner,
        new_owner,
        transferred_by: sender,
        transferred_at_epoch: epoch,
    });
}

/// ================================================================
/// Collectible ownership synchronization
/// ================================================================

/// Records an atomic GoldNFT collectible-right transfer.
///
/// This function is package-restricted because it does not itself transfer
/// the GoldNFT object. A future marketplace or NFT transfer orchestration
/// module must call this function in the same programmable transaction
/// block in which the GoldNFT is transferred.
///
/// The function updates only collectible ownership. It never changes:
///
/// - original_investor;
/// - principal_owner;
/// - physical-gold reserve allocation;
/// - GOLDPEG issuance.
public(package) fun record_collectible_transfer(
    registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    expected_gold_nft_id: ID,
    previous_owner: address,
    new_owner: address,
    ctx: &TxContext,
) {
    assert_active_and_unfrozen(record);

    assert!(
        expected_gold_nft_id == record.gold_nft_id,
        E_NFT_MISMATCH,
    );

    assert!(
        previous_owner == record.collectible_owner,
        E_NOT_COLLECTIBLE_OWNER,
    );

    assert!(
        new_owner != @0x0,
        E_INVALID_OWNER,
    );

    assert!(
        new_owner != previous_owner,
        E_SAME_OWNER,
    );

    let epoch = tx_context::epoch(ctx);

    record.collectible_owner = new_owner;

    // Consent granted by the former NFT owner cannot be inherited by
    // the new collectible owner.
    record.collectible_burn_approved = false;
    record.updated_at_epoch = epoch;

    let transfer_count_after =
        registry.total_collectible_transfers + 1;

    assert!(
        transfer_count_after >
            registry.total_collectible_transfers,
        E_REGISTRY_ARITHMETIC,
    );

    registry.total_collectible_transfers =
        transfer_count_after;

    event::emit(CollectibleOwnershipTransferred {
        record_id: object::id(record),
        gold_nft_id: record.gold_nft_id,
        previous_owner,
        new_owner,
        synchronized_by: tx_context::sender(ctx),
        synchronized_at_epoch: epoch,
    });
}

/// ================================================================
/// Administrative collectible-owner recovery
/// ================================================================

/// Synchronizes collectible ownership through an administrative recovery
/// operation.
///
/// Normal GoldNFT transfers must use the package-only atomic transfer hook.
/// This function exists for exceptional cases such as:
///
/// - migration recovery;
/// - marketplace state synchronization failure;
/// - operational correction authorized by protocol governance.
///
/// The function does not transfer the GoldNFT object itself. Operational
/// procedures must verify the actual NFT owner before invoking recovery.
public fun admin_sync_collectible_owner(
    _admin_cap: &DualOwnershipAdminCap,
    access_control: &AccessControl,
    registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    expected_gold_nft_id: ID,
    new_owner: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert_active_and_unfrozen(record);

    assert!(
        expected_gold_nft_id == record.gold_nft_id,
        E_NFT_MISMATCH,
    );

    assert!(
        new_owner != @0x0,
        E_INVALID_OWNER,
    );

    assert!(
        new_owner != record.collectible_owner,
        E_SAME_OWNER,
    );

    let previous_owner = record.collectible_owner;
    let epoch = tx_context::epoch(ctx);

    record.collectible_owner = new_owner;
    record.collectible_burn_approved = false;
    record.updated_at_epoch = epoch;

    let transfer_count_after =
        registry.total_collectible_transfers + 1;

    assert!(
        transfer_count_after >
            registry.total_collectible_transfers,
        E_REGISTRY_ARITHMETIC,
    );

    registry.total_collectible_transfers =
        transfer_count_after;

    event::emit(CollectibleOwnershipTransferred {
        record_id: object::id(record),
        gold_nft_id: record.gold_nft_id,
        previous_owner,
        new_owner,
        synchronized_by: tx_context::sender(ctx),
        synchronized_at_epoch: epoch,
    });
}

/// ================================================================
/// Principal burn authorization
/// ================================================================

/// Sets or revokes the physical-gold principal owner's consent to the
/// destruction and closing of the linked dual-ownership position.
///
/// Only the current principal owner may change this approval.
public fun set_principal_burn_approval(
    access_control: &AccessControl,
    record: &mut DualOwnershipRecord,
    approved: bool,
    ctx: &TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert_active_and_unfrozen(record);

    let sender = tx_context::sender(ctx);

    assert!(
        sender == record.principal_owner,
        E_NOT_PRINCIPAL_OWNER,
    );

    assert!(
        record.principal_burn_approved != approved,
        E_UNCHANGED_VALUE,
    );

    let epoch = tx_context::epoch(ctx);

    record.principal_burn_approved = approved;
    record.updated_at_epoch = epoch;

    event::emit(PrincipalBurnApprovalChanged {
        record_id: object::id(record),
        principal_owner: sender,
        approved,
        changed_at_epoch: epoch,
    });
}

/// ================================================================
/// Collectible burn authorization
/// ================================================================

/// Sets or revokes the collectible owner's consent to burning the
/// linked GoldNFT and closing the dual-ownership record.
///
/// Only the current collectible owner may change this approval.
public fun set_collectible_burn_approval(
    access_control: &AccessControl,
    record: &mut DualOwnershipRecord,
    approved: bool,
    ctx: &TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert_active_and_unfrozen(record);

    let sender = tx_context::sender(ctx);

    assert!(
        sender == record.collectible_owner,
        E_NOT_COLLECTIBLE_OWNER,
    );

    assert!(
        record.collectible_burn_approved != approved,
        E_UNCHANGED_VALUE,
    );

    let epoch = tx_context::epoch(ctx);

    record.collectible_burn_approved = approved;
    record.updated_at_epoch = epoch;

    event::emit(CollectibleBurnApprovalChanged {
        record_id: object::id(record),
        collectible_owner: sender,
        approved,
        changed_at_epoch: epoch,
    });
}

/// Verifies that both independent ownership-right holders have approved
/// the burn and close lifecycle.
///
/// Principal approval protects the physical-gold principal right.
/// Collectible approval protects the GoldNFT collectible right.
public fun assert_burn_authorized(
    record: &DualOwnershipRecord,
) {
    assert_active_and_unfrozen(record);

    assert!(
        record.principal_burn_approved,
        E_PRINCIPAL_APPROVAL_REQUIRED,
    );

    assert!(
        record.collectible_burn_approved,
        E_COLLECTIBLE_APPROVAL_REQUIRED,
    );
}

/// ================================================================
/// Administrative freeze control
/// ================================================================

/// Freezes or unfreezes a dual-ownership record.
///
/// A frozen record cannot:
///
/// - transfer principal ownership;
/// - synchronize collectible ownership;
/// - change burn approvals;
/// - begin the normal burn lifecycle.
///
/// Closing an already-burned NFT position remains possible through the
/// package-only finalization function so registry accounting cannot remain
/// permanently inconsistent.
public fun set_frozen(
    _admin_cap: &DualOwnershipAdminCap,
    access_control: &AccessControl,
    record: &mut DualOwnershipRecord,
    frozen: bool,
    ctx: &TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert_active(record);

    assert!(
        record.frozen != frozen,
        E_UNCHANGED_VALUE,
    );

    let sender = tx_context::sender(ctx);
    let epoch = tx_context::epoch(ctx);

    record.frozen = frozen;
    record.updated_at_epoch = epoch;

    event::emit(DualOwnershipFrozenStateChanged {
        record_id: object::id(record),
        frozen,
        changed_by: sender,
        changed_at_epoch: epoch,
    });
}

/// ================================================================
/// Burn and close finalization
/// ================================================================

/// Finalizes a dual-ownership record after the linked GoldNFT burn has
/// completed.
///
/// This function is package-restricted. It must be called only by the
/// Tobmate GoldNFT burn-orchestration module in the same protocol flow
/// that destroys or permanently invalidates the linked GoldNFT.
///
/// The package-only visibility prevents an external transaction sender
/// from falsely claiming that an NFT has been burned.
///
/// Both ownership approvals must already exist before finalization.
public(package) fun close_after_nft_burn(
    registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    position: &GoldBackingPosition,
    burned_gold_nft_id: ID,
    ctx: &TxContext,
) {
    assert_active(record);

    assert!(
        burned_gold_nft_id == record.gold_nft_id,
        E_NFT_MISMATCH,
    );

    // The supplied BackingPosition must be the position recorded
    // by this DualOwnershipRecord.
    assert!(
        backing_position::position_id(position) ==
            record.backing_position_id,
        E_POSITION_MISMATCH,
    );

    // GoldNFT burn finalization is permitted only after the NFT link
    // has actually been removed from the BackingPosition.
    assert!(
        !backing_position::has_gold_nft(position),
        E_NFT_STILL_LINKED,
    );


    assert!(
        record.principal_burn_approved,
        E_PRINCIPAL_APPROVAL_REQUIRED,
    );

    assert!(
        record.collectible_burn_approved,
        E_COLLECTIBLE_APPROVAL_REQUIRED,
    );

        // The active position index must point to this exact record.
    assert!(
        table::contains(
            &registry.active_record_by_position,
            record.backing_position_id,
        ),
        E_REGISTRY_INVARIANT,
    );

    let indexed_record_id = table::remove(
        &mut registry.active_record_by_position,
        record.backing_position_id,
    );

    assert!(
        indexed_record_id == object::id(record),
        E_REGISTRY_INVARIANT,
    );

assert!(
        registry.total_active > 0,
        E_REGISTRY_ARITHMETIC,
    );

    let closed_after =
        registry.total_closed + 1;

    assert!(
        closed_after > registry.total_closed,
        E_REGISTRY_ARITHMETIC,
    );

    let epoch = tx_context::epoch(ctx);

    record.status = STATUS_CLOSED;
    record.frozen = false;
    record.principal_burn_approved = false;
    record.collectible_burn_approved = false;
    record.updated_at_epoch = epoch;

    registry.total_active =
        registry.total_active - 1;

    registry.total_closed =
        closed_after;

    assert_registry_invariants(registry);

    event::emit(DualOwnershipClosed {
        record_id: object::id(record),
        backing_position_id: record.backing_position_id,
        gold_nft_id: record.gold_nft_id,
        principal_owner: record.principal_owner,
        collectible_owner: record.collectible_owner,
        closed_by: tx_context::sender(ctx),
        closed_at_epoch: epoch,
    });
}

/// Atomically burns a GoldNFT and closes its DualOwnershipRecord.
///
/// Transaction sequence:
/// 1. Verify dual-owner burn authorization.
/// 2. Verify Record, GoldNFT, and BackingPosition identity.
/// 3. Burn the GoldNFT. The GoldNFT module unlinks the NFT from the
///    BackingPosition and updates the GoldNFTRegistry.
/// 4. Close the DualOwnershipRecord and remove its active index.
///
/// Any abort rolls back every state change in this function.
public fun burn_gold_nft_atomic(
    admin_cap: &GoldNFTAdminCap,
    access_control: &AccessControl,
    gold_nft_registry: &mut GoldNFTRegistry,
    dual_ownership_registry: &mut DualOwnershipRegistry,
    record: &mut DualOwnershipRecord,
    position: &mut GoldBackingPosition,
    nft: GoldNFT,
    ctx: &TxContext,
) {
    // Both the principal owner and collectible owner must approve.
    assert_burn_authorized(record);

    let burned_gold_nft_id = object::id(&nft);
    let supplied_position_id =
        backing_position::position_id(position);

    // The consumed NFT must be the NFT represented by this
    // DualOwnershipRecord.
    assert!(
        burned_gold_nft_id == record.gold_nft_id,
        E_NFT_MISMATCH,
    );

    // The mutable BackingPosition must be the position represented by
    // this DualOwnershipRecord.
    assert!(
        supplied_position_id == record.backing_position_id,
        E_POSITION_MISMATCH,
    );

    // This function performs unlinking, registry accounting, event
    // emission, and deletion of the GoldNFT object.
    gold_nft::burn_gold_nft(
        admin_cap,
        access_control,
        gold_nft_registry,
        position,
        nft,
        ctx,
    );

    // burn_gold_nft() must have removed the position's NFT link.
    // close_after_nft_burn() independently verifies that state before
    // closing the ownership record.
    close_after_nft_burn(
        dual_ownership_registry,
        record,
        position,
        burned_gold_nft_id,
        ctx,
    );
}


/// ================================================================
/// Registry version administration
/// ================================================================

/// Updates the dual-ownership registry schema or protocol version.
///
/// Version changes do not modify active ownership records. They provide
/// an on-chain marker for migration and compatibility management.
public fun set_registry_version(
    _admin_cap: &DualOwnershipAdminCap,
    access_control: &AccessControl,
    registry: &mut DualOwnershipRegistry,
    new_version: u64,
    ctx: &TxContext,
) {
    access_control::assert_not_paused(access_control);

    let previous_version = registry.version;

    assert!(
        new_version != previous_version,
        E_UNCHANGED_VALUE,
    );

    registry.version = new_version;

    event::emit(DualOwnershipRegistryVersionChanged {
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
        changed_at_epoch: tx_context::epoch(ctx),
    });
}

// TOBMATE_TEST_DUAL_OWNERSHIP_FIXTURE
#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): DualOwnershipAdminCap {
    DualOwnershipAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_registry_for_testing(
    ctx: &mut TxContext,
): DualOwnershipRegistry {
    DualOwnershipRegistry {
        id: object::new(ctx),
        version: 1,
        total_created: 0,
        total_active: 0,
        total_closed: 0,
        total_principal_transfers: 0,
        total_collectible_transfers: 0,
        total_principal_approvals: 0,
        total_collectible_approvals: 0,
        active_record_by_position: table::new(ctx),
    }
}

#[test_only]
public fun create_record_for_testing(
    registry: &mut DualOwnershipRegistry,
    position: &GoldBackingPosition,
    nft: &GoldNFT,
    original_investor: address,
    principal_owner: address,
    collectible_owner: address,
    ctx: &mut TxContext,
): DualOwnershipRecord {
    assert!(original_investor != @0x0, E_INVALID_OWNER);
    assert!(principal_owner != @0x0, E_INVALID_OWNER);
    assert!(collectible_owner != @0x0, E_INVALID_OWNER);

    let position_id =
        backing_position::position_id(position);

    assert!(
        !table::contains(
            &registry.active_record_by_position,
            position_id,
        ),
        E_DUPLICATE_RECORD,
    );

    assert!(
        gold_nft::backing_position_id(nft) == position_id,
        E_POSITION_MISMATCH,
    );

    assert!(
        gold_nft::reserve_id(nft)
            == backing_position::reserve_id(position),
        E_POSITION_MISMATCH,
    );

    assert!(
        gold_nft::weight_mg(nft)
            == backing_position::weight_mg(position),
        E_POSITION_MISMATCH,
    );

    assert!(
        gold_nft::purity_bps(nft)
            == backing_position::purity_bps(position),
        E_POSITION_MISMATCH,
    );

    registry.total_created =
        registry.total_created + 1;
    registry.total_active =
        registry.total_active + 1;

    let record = DualOwnershipRecord {
        id: object::new(ctx),
        backing_position_id: position_id,
        reserve_id: backing_position::reserve_id(position),
        gold_nft_id: gold_nft::nft_id_for_testing(nft),
        original_investor,
        principal_owner,
        collectible_owner,
        weight_mg: backing_position::weight_mg(position),
        purity_bps: backing_position::purity_bps(position),
        principal_burn_approved: false,
        collectible_burn_approved: false,
        frozen: false,
        status: STATUS_ACTIVE,
        created_at_epoch: tx_context::epoch(ctx),
        updated_at_epoch: tx_context::epoch(ctx),
    };

    let record_id =
        object::uid_to_inner(&record.id);

    table::add(
        &mut registry.active_record_by_position,
        position_id,
        record_id,
    );

    record
}

#[test_only]
public fun record_is_closed_for_testing(
    record: &DualOwnershipRecord,
): bool {
    record.status == STATUS_CLOSED
}

#[test_only]
public fun registry_total_active_for_testing(
    registry: &DualOwnershipRegistry,
): u64 {
    registry.total_active
}

#[test_only]
public fun registry_total_closed_for_testing(
    registry: &DualOwnershipRegistry,
): u64 {
    registry.total_closed
}

#[test_only]
public fun registry_has_active_position_for_testing(
    registry: &DualOwnershipRegistry,
    position_id: ID,
): bool {
    table::contains(
        &registry.active_record_by_position,
        position_id,
    )
}

#[test_only]
public fun destroy_record_for_testing(
    registry: &mut DualOwnershipRegistry,
    record: DualOwnershipRecord,
) {
    let DualOwnershipRecord {
        id,
        backing_position_id,
        reserve_id: _,
        gold_nft_id: _,
        original_investor: _,
        principal_owner: _,
        collectible_owner: _,
        weight_mg: _,
        purity_bps: _,
        principal_burn_approved: _,
        collectible_burn_approved: _,
        frozen: _,
        status: _,
        created_at_epoch: _,
        updated_at_epoch: _,
    } = record;

    if (
        table::contains(
            &registry.active_record_by_position,
            backing_position_id,
        )
    ) {
        let record_id = table::remove(
            &mut registry.active_record_by_position,
            backing_position_id,
        );

        assert!(
            record_id == object::uid_to_inner(&id),
            9002,
        );

        if (registry.total_active > 0) {
            registry.total_active =
                registry.total_active - 1;
        };
    };

    object::delete(id);
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: DualOwnershipAdminCap,
) {
    let DualOwnershipAdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun destroy_registry_for_testing(
    registry: DualOwnershipRegistry,
) {
    let DualOwnershipRegistry {
        id,
        version: _,
        total_created: _,
        total_active: _,
        total_closed: _,
        total_principal_transfers: _,
        total_collectible_transfers: _,
        total_principal_approvals: _,
        total_collectible_approvals: _,
        active_record_by_position,
    } = registry;

    table::destroy_empty(active_record_by_position);
    object::delete(id);
}

/// ================================================================
/// Marketplace and integration read API
/// ================================================================

public fun record_id(record: &DualOwnershipRecord): ID {
    object::id(record)
}

public fun backing_position_id(
    record: &DualOwnershipRecord,
): ID {
    record.backing_position_id
}

public fun reserve_id(
    record: &DualOwnershipRecord,
): ID {
    record.reserve_id
}

public fun gold_nft_id(
    record: &DualOwnershipRecord,
): ID {
    record.gold_nft_id
}

public fun original_investor(
    record: &DualOwnershipRecord,
): address {
    record.original_investor
}

public fun principal_owner(
    record: &DualOwnershipRecord,
): address {
    record.principal_owner
}

public fun collectible_owner(
    record: &DualOwnershipRecord,
): address {
    record.collectible_owner
}

public fun is_frozen(
    record: &DualOwnershipRecord,
): bool {
    record.frozen
}

public fun is_active_record(
    record: &DualOwnershipRecord,
): bool {
    record.status == STATUS_ACTIVE
}

public fun is_closed(
    record: &DualOwnershipRecord,
): bool {
    record.status == STATUS_CLOSED
}
