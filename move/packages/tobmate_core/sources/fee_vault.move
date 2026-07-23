module tobmate_core::fee_vault;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::sui::SUI;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

/// Fee amount must be greater than zero.
const E_ZERO_AMOUNT: u64 = 1;

/// FeeVault does not contain enough pending funds.
const E_INSUFFICIENT_BALANCE: u64 = 2;

/// FeeVault is locally paused.
const E_FEE_VAULT_PAUSED: u64 = 3;

/// Requested pause state is already active.
const E_STATE_UNCHANGED: u64 = 4;

/// Unknown fee category.
const E_INVALID_FEE_CATEGORY: u64 = 5;

/// Accounting invariant has been violated.
const E_ACCOUNTING_INVARIANT: u64 = 6;

/// FeeVault schema version must change.
const E_VERSION_UNCHANGED: u64 = 7;

/// Fee categories.
const FEE_MARKETPLACE: u8 = 1;
const FEE_MINT: u8 = 2;
const FEE_BURN: u8 = 3;
const FEE_LIQUIDITY: u8 = 4;
const FEE_TRADING_PROFIT: u8 = 5;
const FEE_ORACLE: u8 = 6;
const FEE_OTHER: u8 = 7;

/// Administrative capability for FeeVault.
public struct FeeVaultAdminCap has key, store {
    id: UID,
}

/// Capability authorizing RevenueRouter to collect pending fees.
///
/// This object remains privately owned by the protocol operator until
/// RevenueRouter integration is completed.
public struct FeeCollectorCap has key, store {
    id: UID,
}

/// Shared vault holding actual SUI protocol fee revenue.
///
/// Accounting invariant:
///
/// total_collected
///     = pending_funds.value()
///     + total_released
public struct FeeVault has key {
    id: UID,
    version: u64,
    paused: bool,
    pending_funds: Balance<SUI>,
    total_collected: u64,
    total_released: u64,
    collection_count: u64,
    release_count: u64,
    marketplace_fees: u64,
    mint_fees: u64,
    burn_fees: u64,
    liquidity_fees: u64,
    trading_profit_fees: u64,
    oracle_fees: u64,
    other_fees: u64,
    last_collection_epoch: u64,
    last_release_epoch: u64,
}

/// Emitted whenever a protocol fee enters FeeVault.
public struct FeeCollected has copy, drop {
    vault_id: ID,
    category: u8,
    amount: u64,
    pending_after: u64,
    total_collected: u64,
    collected_from: address,
    epoch: u64,
}

/// Emitted whenever pending fees leave FeeVault for routing.
public struct FeesReleased has copy, drop {
    vault_id: ID,
    amount: u64,
    pending_after: u64,
    total_released: u64,
    released_by: address,
    epoch: u64,
}

/// Emitted whenever FeeVault pause state changes.
public struct FeeVaultPauseStateChanged has copy, drop {
    vault_id: ID,
    paused: bool,
    changed_by: address,
}

/// Emitted whenever FeeVault version changes.
public struct FeeVaultVersionChanged has copy, drop {
    vault_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

/// Initializes FeeVault.
///
/// Publisher receives:
/// - FeeVaultAdminCap
/// - FeeCollectorCap
///
/// FeeVault becomes shared.
fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        FeeVaultAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::transfer(
        FeeCollectorCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        FeeVault {
            id: object::new(ctx),
            version: 1,
            paused: false,
            pending_funds: balance::zero<SUI>(),
            total_collected: 0,
            total_released: 0,
            collection_count: 0,
            release_count: 0,
            marketplace_fees: 0,
            mint_fees: 0,
            burn_fees: 0,
            liquidity_fees: 0,
            trading_profit_fees: 0,
            oracle_fees: 0,
            other_fees: 0,
            last_collection_epoch: 0,
            last_release_epoch: 0,
        },
    );
}

/// Collects an actual SUI protocol fee.
///
/// Any protocol module may submit a fee Coin, but the category must be valid.
public fun collect_fee(
    access_control: &AccessControl,
    vault: &mut FeeVault,
    category: u8,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(access_control, vault);
    assert_valid_category(category);

    let amount = coin::value(&payment);
    assert!(amount > 0, E_ZERO_AMOUNT);

    let payment_balance = coin::into_balance(payment);
    balance::join(&mut vault.pending_funds, payment_balance);

    vault.total_collected =
        vault.total_collected + amount;
    vault.collection_count =
        vault.collection_count + 1;
    vault.last_collection_epoch =
        tx_context::epoch(ctx);

    add_category_total(vault, category, amount);

    assert_accounting_invariant(vault);

    event::emit(FeeCollected {
        vault_id: object::uid_to_inner(&vault.id),
        category,
        amount,
        pending_after: balance::value(&vault.pending_funds),
        total_collected: vault.total_collected,
        collected_from: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

/// Releases pending fees as Coin<SUI> for RevenueRouter.
///
/// This does not send funds directly to a recipient. The resulting Coin
/// must be consumed by RevenueRouter or another authorized settlement flow
/// in the same transaction.
public fun release_fees(
    _collector_cap: &FeeCollectorCap,
    access_control: &AccessControl,
    vault: &mut FeeVault,
    amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert_operational(access_control, vault);
    assert!(amount > 0, E_ZERO_AMOUNT);
    assert!(
        balance::value(&vault.pending_funds) >= amount,
        E_INSUFFICIENT_BALANCE,
    );

    let released_balance =
        balance::split(&mut vault.pending_funds, amount);

    vault.total_released =
        vault.total_released + amount;
    vault.release_count =
        vault.release_count + 1;
    vault.last_release_epoch =
        tx_context::epoch(ctx);

    assert_accounting_invariant(vault);

    event::emit(FeesReleased {
        vault_id: object::uid_to_inner(&vault.id),
        amount,
        pending_after: balance::value(&vault.pending_funds),
        total_released: vault.total_released,
        released_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });

    coin::from_balance(released_balance, ctx)
}

/// Releases all currently pending fees.
///
/// Aborts when the pending balance is zero.
public fun release_all(
    collector_cap: &FeeCollectorCap,
    access_control: &AccessControl,
    vault: &mut FeeVault,
    ctx: &mut TxContext,
): Coin<SUI> {
    let amount = balance::value(&vault.pending_funds);
    release_fees(
        collector_cap,
        access_control,
        vault,
        amount,
        ctx,
    )
}

/// Changes FeeVault-local pause state.
public fun set_paused(
    _admin_cap: &FeeVaultAdminCap,
    vault: &mut FeeVault,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(vault.paused != paused, E_STATE_UNCHANGED);

    vault.paused = paused;

    event::emit(FeeVaultPauseStateChanged {
        vault_id: object::uid_to_inner(&vault.id),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}

/// Updates FeeVault schema version.
public fun set_version(
    _admin_cap: &FeeVaultAdminCap,
    vault: &mut FeeVault,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version = vault.version;
    assert!(previous_version != new_version, E_VERSION_UNCHANGED);

    vault.version = new_version;

    event::emit(FeeVaultVersionChanged {
        vault_id: object::uid_to_inner(&vault.id),
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

/// Aborts unless global protocol and FeeVault are active.
public fun assert_operational(
    access_control: &AccessControl,
    vault: &FeeVault,
) {
    access_control::assert_not_paused(access_control);
    assert!(!vault.paused, E_FEE_VAULT_PAUSED);
}

/// Checks FeeVault accounting invariant.
public fun assert_accounting_invariant(
    vault: &FeeVault,
) {
    assert!(
        vault.total_collected
            == balance::value(&vault.pending_funds)
                + vault.total_released,
        E_ACCOUNTING_INVARIANT,
    );
}

/// Checks fee category range.
public fun assert_valid_category(category: u8) {
    assert!(
        category >= FEE_MARKETPLACE
            && category <= FEE_OTHER,
        E_INVALID_FEE_CATEGORY,
    );
}

fun add_category_total(
    vault: &mut FeeVault,
    category: u8,
    amount: u64,
) {
    if (category == FEE_MARKETPLACE) {
        vault.marketplace_fees =
            vault.marketplace_fees + amount;
    } else if (category == FEE_MINT) {
        vault.mint_fees =
            vault.mint_fees + amount;
    } else if (category == FEE_BURN) {
        vault.burn_fees =
            vault.burn_fees + amount;
    } else if (category == FEE_LIQUIDITY) {
        vault.liquidity_fees =
            vault.liquidity_fees + amount;
    } else if (category == FEE_TRADING_PROFIT) {
        vault.trading_profit_fees =
            vault.trading_profit_fees + amount;
    } else if (category == FEE_ORACLE) {
        vault.oracle_fees =
            vault.oracle_fees + amount;
    } else {
        vault.other_fees =
            vault.other_fees + amount;
    };
}

// -------------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------------

public fun fee_marketplace(): u8 {
    FEE_MARKETPLACE
}

public fun fee_mint(): u8 {
    FEE_MINT
}

public fun fee_burn(): u8 {
    FEE_BURN
}

public fun fee_liquidity(): u8 {
    FEE_LIQUIDITY
}

public fun fee_trading_profit(): u8 {
    FEE_TRADING_PROFIT
}

public fun fee_oracle(): u8 {
    FEE_ORACLE
}

public fun fee_other(): u8 {
    FEE_OTHER
}

// -------------------------------------------------------------------------
// Read APIs
// -------------------------------------------------------------------------

public fun vault_id(vault: &FeeVault): ID {
    object::uid_to_inner(&vault.id)
}

public fun version(vault: &FeeVault): u64 {
    vault.version
}

public fun is_paused(vault: &FeeVault): bool {
    vault.paused
}

public fun pending_balance(vault: &FeeVault): u64 {
    balance::value(&vault.pending_funds)
}

public fun total_collected(vault: &FeeVault): u64 {
    vault.total_collected
}

public fun total_released(vault: &FeeVault): u64 {
    vault.total_released
}

public fun collection_count(vault: &FeeVault): u64 {
    vault.collection_count
}

public fun release_count(vault: &FeeVault): u64 {
    vault.release_count
}

public fun marketplace_fees(vault: &FeeVault): u64 {
    vault.marketplace_fees
}

public fun mint_fees(vault: &FeeVault): u64 {
    vault.mint_fees
}

public fun burn_fees(vault: &FeeVault): u64 {
    vault.burn_fees
}

public fun liquidity_fees(vault: &FeeVault): u64 {
    vault.liquidity_fees
}

public fun trading_profit_fees(vault: &FeeVault): u64 {
    vault.trading_profit_fees
}

public fun oracle_fees(vault: &FeeVault): u64 {
    vault.oracle_fees
}

public fun other_fees(vault: &FeeVault): u64 {
    vault.other_fees
}

// -------------------------------------------------------------------------
// Test fixtures
// -------------------------------------------------------------------------

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): FeeVaultAdminCap {
    FeeVaultAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_collector_cap_for_testing(
    ctx: &mut TxContext,
): FeeCollectorCap {
    FeeCollectorCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): FeeVault {
    FeeVault {
        id: object::new(ctx),
        version: 1,
        paused: false,
        pending_funds: balance::zero<SUI>(),
        total_collected: 0,
        total_released: 0,
        collection_count: 0,
        release_count: 0,
        marketplace_fees: 0,
        mint_fees: 0,
        burn_fees: 0,
        liquidity_fees: 0,
        trading_profit_fees: 0,
        oracle_fees: 0,
        other_fees: 0,
        last_collection_epoch: 0,
        last_release_epoch: 0,
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: FeeVaultAdminCap,
) {
    let FeeVaultAdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun destroy_collector_cap_for_testing(
    cap: FeeCollectorCap,
) {
    let FeeCollectorCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun destroy_empty_for_testing(
    vault: FeeVault,
) {
    assert!(
        balance::value(&vault.pending_funds) == 0,
        E_ACCOUNTING_INVARIANT,
    );

    let FeeVault {
        id,
        version: _,
        paused: _,
        pending_funds,
        total_collected: _,
        total_released: _,
        collection_count: _,
        release_count: _,
        marketplace_fees: _,
        mint_fees: _,
        burn_fees: _,
        liquidity_fees: _,
        trading_profit_fees: _,
        oracle_fees: _,
        other_fees: _,
        last_collection_epoch: _,
        last_release_epoch: _,
    } = vault;

    balance::destroy_zero(pending_funds);
    object::delete(id);
}
