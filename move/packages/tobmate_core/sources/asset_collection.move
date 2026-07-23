module tobmate_core::asset_collection;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

//
// Error codes
//

const E_NOT_COLLECTION_ADMIN: u64 = 1;
const E_COLLECTION_INACTIVE: u64 = 2;
const E_MAX_SUPPLY_EXCEEDED: u64 = 3;
const E_NOTHING_TO_BURN: u64 = 4;
const E_INVALID_MAX_SUPPLY: u64 = 5;
const E_DUPLICATE_ACTIVE_STATE: u64 = 6;

//
// Asset classes
//

const ASSET_GOLD: u8 = 1;
const ASSET_SILVER: u8 = 2;
const ASSET_PLATINUM: u8 = 3;

const ASSET_DIAMOND: u8 = 10;
const ASSET_RUBY: u8 = 11;
const ASSET_SAPPHIRE: u8 = 12;
const ASSET_EMERALD: u8 = 13;

const ASSET_JEWELRY: u8 = 20;
const ASSET_ART: u8 = 30;
const ASSET_COLLECTIBLE: u8 = 40;

//
// Core objects
//

/// Administrative capability for one collection.
///
/// A capability is bound to exactly one AssetCollection object.
public struct CollectionAdminCap has key, store {
    id: UID,
    collection_id: ID,
}

/// On-chain registry object for an NFT or real-world-asset collection.
///
/// The first intended production collection is:
///
/// GOLD_COIN_GENESIS_36000
///
/// with a maximum supply of 36,000.
public struct AssetCollection has key {
    id: UID,

    version: u64,

    asset_class: u8,
    collection_code: vector<u8>,
    name: vector<u8>,

    max_supply: u64,
    minted_supply: u64,
    burned_supply: u64,

    active: bool,
}

//
// Events
//

public struct CollectionCreated has copy, drop {
    collection_id: ID,
    asset_class: u8,
    max_supply: u64,
    administrator: address,
}

public struct CollectionMintRecorded has copy, drop {
    collection_id: ID,
    quantity: u64,
    minted_supply: u64,
    circulating_supply: u64,
}

public struct CollectionBurnRecorded has copy, drop {
    collection_id: ID,
    quantity: u64,
    burned_supply: u64,
    circulating_supply: u64,
}

public struct CollectionStatusChanged has copy, drop {
    collection_id: ID,
    active: bool,
}

public struct CollectionVersionChanged has copy, drop {
    collection_id: ID,
    old_version: u64,
    new_version: u64,
}

//
// Collection creation
//

/// Creates a new shared collection and transfers its administrative
/// capability to the transaction sender.
public fun create_collection(
    asset_class: u8,
    collection_code: vector<u8>,
    name: vector<u8>,
    max_supply: u64,
    ctx: &mut TxContext,
) {
    assert!(max_supply > 0, E_INVALID_MAX_SUPPLY);

    let administrator = tx_context::sender(ctx);

    let collection = AssetCollection {
        id: object::new(ctx),
        version: 1,
        asset_class,
        collection_code,
        name,
        max_supply,
        minted_supply: 0,
        burned_supply: 0,
        active: true,
    };

    let collection_id = object::id(&collection);

    let admin_cap = CollectionAdminCap {
        id: object::new(ctx),
        collection_id,
    };

    event::emit(CollectionCreated {
        collection_id,
        asset_class,
        max_supply,
        administrator,
    });

    transfer::public_transfer(admin_cap, administrator);
    transfer::share_object(collection);
}

//
// Supply accounting
//

/// Records one or more newly minted assets belonging to the collection.
///
/// The NFT minting module will call this function during an atomic
/// mint transaction.
public fun record_mint(
    admin_cap: &CollectionAdminCap,
    collection: &mut AssetCollection,
    quantity: u64,
) {
    assert_admin(admin_cap, collection);
    assert!(collection.active, E_COLLECTION_INACTIVE);
    assert!(quantity > 0, E_INVALID_MAX_SUPPLY);

    let new_minted_supply = collection.minted_supply + quantity;

    assert!(
        new_minted_supply <= collection.max_supply,
        E_MAX_SUPPLY_EXCEEDED,
    );

    collection.minted_supply = new_minted_supply;

    event::emit(CollectionMintRecorded {
        collection_id: object::id(collection),
        quantity,
        minted_supply: collection.minted_supply,
        circulating_supply: circulating_supply(collection),
    });
}

/// Records one or more permanently burned assets.
///
/// minted_supply remains the historical total minted amount.
/// burned_supply tracks permanent destruction.
public fun record_burn(
    admin_cap: &CollectionAdminCap,
    collection: &mut AssetCollection,
    quantity: u64,
) {
    assert_admin(admin_cap, collection);
    assert!(quantity > 0, E_NOTHING_TO_BURN);

    let circulating = circulating_supply(collection);

    assert!(quantity <= circulating, E_NOTHING_TO_BURN);

    collection.burned_supply = collection.burned_supply + quantity;

    event::emit(CollectionBurnRecorded {
        collection_id: object::id(collection),
        quantity,
        burned_supply: collection.burned_supply,
        circulating_supply: circulating_supply(collection),
    });
}

//
// Administration
//

public fun set_active(
    admin_cap: &CollectionAdminCap,
    collection: &mut AssetCollection,
    active: bool,
) {
    assert_admin(admin_cap, collection);

    assert!(
        collection.active != active,
        E_DUPLICATE_ACTIVE_STATE,
    );

    collection.active = active;

    event::emit(CollectionStatusChanged {
        collection_id: object::id(collection),
        active,
    });
}

public fun update_version(
    admin_cap: &CollectionAdminCap,
    collection: &mut AssetCollection,
    new_version: u64,
) {
    assert_admin(admin_cap, collection);

    let old_version = collection.version;
    collection.version = new_version;

    event::emit(CollectionVersionChanged {
        collection_id: object::id(collection),
        old_version,
        new_version,
    });
}

//
// Internal validation
//

fun assert_admin(
    admin_cap: &CollectionAdminCap,
    collection: &AssetCollection,
) {
    assert!(
        admin_cap.collection_id == object::id(collection),
        E_NOT_COLLECTION_ADMIN,
    );
}

//
// Public read API
//

public fun collection_id(
    collection: &AssetCollection,
): ID {
    object::id(collection)
}

public fun admin_collection_id(
    admin_cap: &CollectionAdminCap,
): ID {
    admin_cap.collection_id
}

public fun version(
    collection: &AssetCollection,
): u64 {
    collection.version
}

public fun asset_class(
    collection: &AssetCollection,
): u8 {
    collection.asset_class
}

public fun collection_code(
    collection: &AssetCollection,
): &vector<u8> {
    &collection.collection_code
}

public fun name(
    collection: &AssetCollection,
): &vector<u8> {
    &collection.name
}

public fun max_supply(
    collection: &AssetCollection,
): u64 {
    collection.max_supply
}

public fun minted_supply(
    collection: &AssetCollection,
): u64 {
    collection.minted_supply
}

public fun burned_supply(
    collection: &AssetCollection,
): u64 {
    collection.burned_supply
}

public fun circulating_supply(
    collection: &AssetCollection,
): u64 {
    collection.minted_supply - collection.burned_supply
}

public fun is_active(
    collection: &AssetCollection,
): bool {
    collection.active
}

//
// Asset-class getters
//

public fun asset_gold(): u8 {
    ASSET_GOLD
}

public fun asset_silver(): u8 {
    ASSET_SILVER
}

public fun asset_platinum(): u8 {
    ASSET_PLATINUM
}

public fun asset_diamond(): u8 {
    ASSET_DIAMOND
}

public fun asset_ruby(): u8 {
    ASSET_RUBY
}

public fun asset_sapphire(): u8 {
    ASSET_SAPPHIRE
}

public fun asset_emerald(): u8 {
    ASSET_EMERALD
}

public fun asset_jewelry(): u8 {
    ASSET_JEWELRY
}

public fun asset_art(): u8 {
    ASSET_ART
}

public fun asset_collectible(): u8 {
    ASSET_COLLECTIBLE
}
