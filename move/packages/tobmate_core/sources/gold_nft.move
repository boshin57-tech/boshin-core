module tobmate_core::gold_nft;

use std::option;
use std::vector;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{Self, AccessControl};
use tobmate_core::backing_position::{Self, GoldBackingPosition};

/// Error codes.
const E_POSITION_NOT_ACTIVE: u64 = 1;
const E_POSITION_ALREADY_HAS_NFT: u64 = 2;
const E_POSITION_NOT_LINKED: u64 = 3;
const E_POSITION_ID_MISMATCH: u64 = 4;
const E_RESERVE_ID_MISMATCH: u64 = 5;
const E_WEIGHT_MISMATCH: u64 = 6;
const E_PURITY_MISMATCH: u64 = 7;
const E_NFT_NOT_ACTIVE: u64 = 8;
const E_NFT_FROZEN: u64 = 9;
const E_UNCHANGED_VALUE: u64 = 10;
const E_EMPTY_NAME: u64 = 11;
const E_EMPTY_METADATA_HASH: u64 = 12;
const E_INVALID_RECIPIENT: u64 = 13;
const E_REGISTRY_INVARIANT: u64 = 14;

/// NFT lifecycle status.
const STATUS_ACTIVE: u8 = 1;

/// Administrative capability for the Gold NFT subsystem.
public struct GoldNFTAdminCap has key, store {
    id: UID,
}

/// Shared aggregate registry for Gold NFTs.
public struct GoldNFTRegistry has key {
    id: UID,
    version: u64,
    total_minted: u64,
    total_active: u64,
    total_burned: u64,
    total_backed_weight_mg: u64,
}

/// Gold NFT representing the collectible and additional ownership right.
///
/// This object does not independently allocate physical gold.
/// It references an existing GoldBackingPosition whose reserve weight
/// was already allocated exactly once.
public struct GoldNFT has key {
    id: UID,

    /// Monotonically increasing NFT serial number.
    serial_number: u64,

    /// Shared backing position used by both Gold NFT and GOLDPEG.
    backing_position_id: ID,

    /// Physical reserve object referenced by the backing position.
    reserve_id: ID,

    /// Gold weight inherited from the backing position.
    weight_mg: u64,

    /// Gold purity inherited from the backing position.
    purity_bps: u64,

    /// Human-readable metadata.
    name: vector<u8>,
    description: vector<u8>,
    media_url: vector<u8>,

    /// Cryptographic commitment to off-chain metadata.
    metadata_hash: vector<u8>,

    /// Address that issued the NFT.
    issuer: address,

    status: u8,

    /// Prevents module-controlled transfer and burn while true.
    frozen: bool,

    minted_at_epoch: u64,
    updated_at_epoch: u64,
}

/// Emitted when a Gold NFT is minted.
public struct GoldNFTMinted has copy, drop {
    nft_id: ID,
    serial_number: u64,
    backing_position_id: ID,
    reserve_id: ID,
    owner: address,
    weight_mg: u64,
    purity_bps: u64,
    issuer: address,
}

/// Emitted when a Gold NFT is transferred.
public struct GoldNFTTransferred has copy, drop {
    nft_id: ID,
    from: address,
    to: address,
}

/// Emitted when a Gold NFT is burned.
public struct GoldNFTBurned has copy, drop {
    nft_id: ID,
    serial_number: u64,
    backing_position_id: ID,
    reserve_id: ID,
    weight_mg: u64,
    burned_by: address,
}

/// Emitted when metadata is updated.
public struct GoldNFTMetadataUpdated has copy, drop {
    nft_id: ID,
    updated_by: address,
    updated_at_epoch: u64,
}

/// Emitted when the frozen state changes.
public struct GoldNFTFrozenStateChanged has copy, drop {
    nft_id: ID,
    frozen: bool,
    changed_by: address,
    changed_at_epoch: u64,
}

/// Initializes the Gold NFT subsystem.
///
/// The publisher receives GoldNFTAdminCap.
/// GoldNFTRegistry becomes a shared object.
fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        GoldNFTAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        GoldNFTRegistry {
            id: object::new(ctx),
            version: 1,
            total_minted: 0,
            total_active: 0,
            total_burned: 0,
            total_backed_weight_mg: 0,
        },
    );
}

/// Mints a Gold NFT and links it to an existing backing position.
///
/// This function intentionally does not receive GoldReserve or
/// GoldReserveRegistry because it must not allocate reserve weight again.
public fun mint_gold_nft(
    _admin_cap: &GoldNFTAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldNFTRegistry,
    position: &mut GoldBackingPosition,
    recipient: address,
    name: vector<u8>,
    description: vector<u8>,
    media_url: vector<u8>,
    metadata_hash: vector<u8>,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(recipient != @0x0, E_INVALID_RECIPIENT);
    assert!(!vector::is_empty(&name), E_EMPTY_NAME);
    assert!(
        !vector::is_empty(&metadata_hash),
        E_EMPTY_METADATA_HASH,
    );
    assert!(
        backing_position::is_active(position),
        E_POSITION_NOT_ACTIVE,
    );
    assert!(
        !backing_position::has_gold_nft(position),
        E_POSITION_ALREADY_HAS_NFT,
    );

    registry.total_minted = registry.total_minted + 1;
    registry.total_active = registry.total_active + 1;

    let weight_mg = backing_position::weight_mg(position);
    let purity_bps = backing_position::purity_bps(position);
    let position_id = backing_position::position_id(position);
    let reserve_id = backing_position::reserve_id(position);
    let issuer = tx_context::sender(ctx);
    let epoch = tx_context::epoch(ctx);
    let serial_number = registry.total_minted;

    registry.total_backed_weight_mg =
        registry.total_backed_weight_mg + weight_mg;

    let nft = GoldNFT {
        id: object::new(ctx),
        serial_number,
        backing_position_id: position_id,
        reserve_id,
        weight_mg,
        purity_bps,
        name,
        description,
        media_url,
        metadata_hash,
        issuer,
        status: STATUS_ACTIVE,
        frozen: false,
        minted_at_epoch: epoch,
        updated_at_epoch: epoch,
    };

    let nft_id = object::uid_to_inner(&nft.id);

    // Package-visible mutation ensures only modules in tobmate_core
    // can create the authoritative position-to-NFT link.
    backing_position::link_gold_nft(position, nft_id);

    event::emit(GoldNFTMinted {
        nft_id,
        serial_number,
        backing_position_id: position_id,
        reserve_id,
        owner: recipient,
        weight_mg,
        purity_bps,
        issuer,
    });

    transfer::transfer(nft, recipient);
}

/// Transfers a Gold NFT through the controlled module path.
///
/// GoldNFT intentionally lacks the `store` ability, preventing an
/// unrestricted external public_transfer call.
public fun transfer_gold_nft(
    access_control: &AccessControl,
    nft: GoldNFT,
    recipient: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(recipient != @0x0, E_INVALID_RECIPIENT);
    assert!(nft.status == STATUS_ACTIVE, E_NFT_NOT_ACTIVE);
    assert!(!nft.frozen, E_NFT_FROZEN);

    let nft_id = object::uid_to_inner(&nft.id);
    let sender = tx_context::sender(ctx);

    event::emit(GoldNFTTransferred {
        nft_id,
        from: sender,
        to: recipient,
    });

    transfer::transfer(nft, recipient);
}

/// Updates Gold NFT metadata.
///
/// Requires both the NFT owner's participation and GoldNFTAdminCap.
public fun update_metadata(
    _admin_cap: &GoldNFTAdminCap,
    access_control: &AccessControl,
    nft: &mut GoldNFT,
    name: vector<u8>,
    description: vector<u8>,
    media_url: vector<u8>,
    metadata_hash: vector<u8>,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(nft.status == STATUS_ACTIVE, E_NFT_NOT_ACTIVE);
    assert!(!nft.frozen, E_NFT_FROZEN);
    assert!(!vector::is_empty(&name), E_EMPTY_NAME);
    assert!(
        !vector::is_empty(&metadata_hash),
        E_EMPTY_METADATA_HASH,
    );

    nft.name = name;
    nft.description = description;
    nft.media_url = media_url;
    nft.metadata_hash = metadata_hash;
    nft.updated_at_epoch = tx_context::epoch(ctx);

    event::emit(GoldNFTMetadataUpdated {
        nft_id: object::uid_to_inner(&nft.id),
        updated_by: tx_context::sender(ctx),
        updated_at_epoch: nft.updated_at_epoch,
    });
}

/// Freezes or unfreezes a Gold NFT.
///
/// A frozen NFT cannot be transferred, updated or burned through this
/// module until an administrator unfreezes it.
public fun set_frozen(
    _admin_cap: &GoldNFTAdminCap,
    access_control: &AccessControl,
    nft: &mut GoldNFT,
    frozen: bool,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(nft.status == STATUS_ACTIVE, E_NFT_NOT_ACTIVE);
    assert!(nft.frozen != frozen, E_UNCHANGED_VALUE);

    nft.frozen = frozen;
    nft.updated_at_epoch = tx_context::epoch(ctx);

    event::emit(GoldNFTFrozenStateChanged {
        nft_id: object::uid_to_inner(&nft.id),
        frozen,
        changed_by: tx_context::sender(ctx),
        changed_at_epoch: nft.updated_at_epoch,
    });
}

/// Burns a Gold NFT and removes its authoritative backing-position link.
///
/// Burning the NFT does not release physical reserve weight.
/// The backing position may still support GOLDPEG principal units.
/// Reserve release occurs only when the entire backing position is closed.
public(package) fun burn_gold_nft(
    _admin_cap: &GoldNFTAdminCap,
    access_control: &AccessControl,
    registry: &mut GoldNFTRegistry,
    position: &mut GoldBackingPosition,
    nft: GoldNFT,
    ctx: &TxContext,
) {
    access_control::assert_not_paused(access_control);

    assert!(nft.status == STATUS_ACTIVE, E_NFT_NOT_ACTIVE);
    assert!(!nft.frozen, E_NFT_FROZEN);

    assert_matches_position(&nft, position);

    let linked_nft_id_option =
        backing_position::gold_nft_id(position);

    assert!(
        option::is_some(&linked_nft_id_option),
        E_POSITION_NOT_LINKED,
    );

    let nft_id = object::uid_to_inner(&nft.id);
    let linked_nft_id = *option::borrow(&linked_nft_id_option);

    assert!(linked_nft_id == nft_id, E_POSITION_ID_MISMATCH);

    backing_position::unlink_gold_nft(position, nft_id);

    assert!(registry.total_active > 0, E_REGISTRY_INVARIANT);
    assert!(
        registry.total_backed_weight_mg >= nft.weight_mg,
        E_REGISTRY_INVARIANT,
    );

    registry.total_active = registry.total_active - 1;
    registry.total_burned = registry.total_burned + 1;
    registry.total_backed_weight_mg =
        registry.total_backed_weight_mg - nft.weight_mg;

    let GoldNFT {
        id,
        serial_number,
        backing_position_id,
        reserve_id,
        weight_mg,
        purity_bps: _,
        name: _,
        description: _,
        media_url: _,
        metadata_hash: _,
        issuer: _,
        status: _,
        frozen: _,
        minted_at_epoch: _,
        updated_at_epoch: _,
    } = nft;

    event::emit(GoldNFTBurned {
        nft_id,
        serial_number,
        backing_position_id,
        reserve_id,
        weight_mg,
        burned_by: tx_context::sender(ctx),
    });

    object::delete(id);
}

/// Validates every immutable relationship between a Gold NFT and its
/// shared backing position.
public fun assert_matches_position(
    nft: &GoldNFT,
    position: &GoldBackingPosition,
) {
    assert!(
        backing_position::is_active(position),
        E_POSITION_NOT_ACTIVE,
    );

    assert!(
        nft.backing_position_id ==
            backing_position::position_id(position),
        E_POSITION_ID_MISMATCH,
    );

    assert!(
        nft.reserve_id == backing_position::reserve_id(position),
        E_RESERVE_ID_MISMATCH,
    );

    assert!(
        nft.weight_mg == backing_position::weight_mg(position),
        E_WEIGHT_MISMATCH,
    );

    assert!(
        nft.purity_bps == backing_position::purity_bps(position),
        E_PURITY_MISMATCH,
    );
}

/// Validates that the backing position points back to this NFT.
public fun assert_linked_to_position(
    nft: &GoldNFT,
    position: &GoldBackingPosition,
) {
    assert_matches_position(nft, position);

    let linked_nft_id_option =
        backing_position::gold_nft_id(position);

    assert!(
        option::is_some(&linked_nft_id_option),
        E_POSITION_NOT_LINKED,
    );

    let linked_nft_id = *option::borrow(&linked_nft_id_option);

    assert!(
        linked_nft_id == object::uid_to_inner(&nft.id),
        E_POSITION_ID_MISMATCH,
    );
}

/// Registry invariant:
///
/// total_minted = total_active + total_burned
public fun assert_registry_invariants(
    registry: &GoldNFTRegistry,
) {
    assert!(
        registry.total_minted ==
            registry.total_active + registry.total_burned,
        E_REGISTRY_INVARIANT,
    );
}

/// Gold NFT getters.

public fun nft_id(nft: &GoldNFT): ID {
    object::uid_to_inner(&nft.id)
}

public fun serial_number(nft: &GoldNFT): u64 {
    nft.serial_number
}

public fun backing_position_id(nft: &GoldNFT): ID {
    nft.backing_position_id
}

public fun reserve_id(nft: &GoldNFT): ID {
    nft.reserve_id
}

public fun weight_mg(nft: &GoldNFT): u64 {
    nft.weight_mg
}

public fun purity_bps(nft: &GoldNFT): u64 {
    nft.purity_bps
}

public fun issuer(nft: &GoldNFT): address {
    nft.issuer
}

public fun status(nft: &GoldNFT): u8 {
    nft.status
}

public fun is_active(nft: &GoldNFT): bool {
    nft.status == STATUS_ACTIVE
}

public fun is_frozen(nft: &GoldNFT): bool {
    nft.frozen
}

public fun minted_at_epoch(nft: &GoldNFT): u64 {
    nft.minted_at_epoch
}

public fun updated_at_epoch(nft: &GoldNFT): u64 {
    nft.updated_at_epoch
}

public fun name(nft: &GoldNFT): &vector<u8> {
    &nft.name
}

public fun description(nft: &GoldNFT): &vector<u8> {
    &nft.description
}

public fun media_url(nft: &GoldNFT): &vector<u8> {
    &nft.media_url
}

public fun metadata_hash(nft: &GoldNFT): &vector<u8> {
    &nft.metadata_hash
}

/// Registry getters.

public fun registry_version(
    registry: &GoldNFTRegistry,
): u64 {
    registry.version
}

public fun registry_total_minted(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_minted
}

public fun registry_total_active(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_active
}

public fun registry_total_burned(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_burned
}

public fun registry_total_backed_weight_mg(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_backed_weight_mg
}

// TOBMATE_TEST_GOLD_NFT_FIXTURE
#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): GoldNFTAdminCap {
    GoldNFTAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_registry_for_testing(
    ctx: &mut TxContext,
): GoldNFTRegistry {
    GoldNFTRegistry {
        id: object::new(ctx),
        version: 1,
        total_minted: 0,
        total_active: 0,
        total_burned: 0,
        total_backed_weight_mg: 0,
    }
}

#[test_only]
public fun mint_for_testing(
    registry: &mut GoldNFTRegistry,
    position: &mut GoldBackingPosition,
    recipient: address,
    ctx: &mut TxContext,
): GoldNFT {
    assert!(recipient != @0x0, E_INVALID_RECIPIENT);
    assert!(
        backing_position::is_active(position),
        E_POSITION_NOT_ACTIVE,
    );
    assert!(
        !backing_position::has_gold_nft(position),
        E_POSITION_ALREADY_HAS_NFT,
    );

    registry.total_minted =
        registry.total_minted + 1;
    registry.total_active =
        registry.total_active + 1;

    let weight_mg =
        backing_position::weight_mg(position);
    let purity_bps =
        backing_position::purity_bps(position);
    let position_id =
        backing_position::position_id(position);
    let reserve_id =
        backing_position::reserve_id(position);
    let serial_number =
        registry.total_minted;
    let epoch =
        tx_context::epoch(ctx);

    registry.total_backed_weight_mg =
        registry.total_backed_weight_mg + weight_mg;

    let nft = GoldNFT {
        id: object::new(ctx),
        serial_number,
        backing_position_id: position_id,
        reserve_id,
        weight_mg,
        purity_bps,
        name: b"Test Gold NFT",
        description: b"Atomic burn fixture",
        media_url: b"test://gold-nft",
        metadata_hash: b"test-metadata-hash",
        issuer: tx_context::sender(ctx),
        status: STATUS_ACTIVE,
        frozen: false,
        minted_at_epoch: epoch,
        updated_at_epoch: epoch,
    };

    backing_position::link_gold_nft(
        position,
        object::uid_to_inner(&nft.id),
    );

    nft
}

#[test_only]
public fun nft_id_for_testing(
    nft: &GoldNFT,
): ID {
    object::uid_to_inner(&nft.id)
}

#[test_only]
public fun registry_total_active_for_testing(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_active
}

#[test_only]
public fun registry_total_burned_for_testing(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_burned
}

#[test_only]
public fun registry_total_backed_weight_for_testing(
    registry: &GoldNFTRegistry,
): u64 {
    registry.total_backed_weight_mg
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: GoldNFTAdminCap,
) {
    let GoldNFTAdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun destroy_registry_for_testing(
    registry: GoldNFTRegistry,
) {
    let GoldNFTRegistry {
        id,
        version: _,
        total_minted: _,
        total_active: _,
        total_burned: _,
        total_backed_weight_mg: _,
    } = registry;

    object::delete(id);
}

/// ================================================================
/// Package-controlled marketplace escrow

/// ================================================================
/// Package-controlled marketplace object escrow
/// ================================================================

/// Transfers an active GoldNFT to the address of a marketplace listing.
///
/// The destination must be the ID-derived address of the newly created
/// listing object. The NFT remains an owned child object and never
/// becomes a shared object.
public(package) fun transfer_to_marketplace_escrow(
    nft: GoldNFT,
    listing_address: address,
) {
    assert!(listing_address != @0x0, E_INVALID_RECIPIENT);
    assert!(nft.status == STATUS_ACTIVE, E_NFT_NOT_ACTIVE);
    assert!(!nft.frozen, E_NFT_FROZEN);

    transfer::transfer(nft, listing_address);
}

/// Receives a GoldNFT owned by a marketplace listing.
///
/// GoldNFT has `key` but intentionally lacks `store`, so receiving must
/// occur through the GoldNFT defining module.
public(package) fun receive_from_marketplace_escrow(
    listing_uid: &mut UID,
    receiving: transfer::Receiving<GoldNFT>,
): GoldNFT {
    transfer::receive(listing_uid, receiving)
}

// TOBMATE_GOLD_MARKETPLACE_NFT_TEST_HELPERS

#[test_only]
public fun freeze_for_testing(
    nft: &mut GoldNFT,
) {
    nft.frozen = true;
}

#[test_only]
public fun destroy_nft_for_testing(
    nft: GoldNFT,
) {
    let GoldNFT {
        id,
        serial_number: _,
        backing_position_id: _,
        reserve_id: _,
        weight_mg: _,
        purity_bps: _,
        name: _,
        description: _,
        media_url: _,
        metadata_hash: _,
        issuer: _,
        status: _,
        frozen: _,
        minted_at_epoch: _,
        updated_at_epoch: _,
    } = nft;

    object::delete(id);
}
