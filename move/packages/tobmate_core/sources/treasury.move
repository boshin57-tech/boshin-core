module tobmate_core::treasury;

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

/// Deposit and withdrawal amount must be greater than zero.
const E_ZERO_AMOUNT: u64 = 1;

/// Treasury does not contain enough available funds.
const E_INSUFFICIENT_BALANCE: u64 = 2;

/// Treasury is locally paused.
const E_TREASURY_PAUSED: u64 = 3;

/// Requested treasury pause state is already active.
const E_STATE_UNCHANGED: u64 = 4;

/// Accounting invariant has been violated.
const E_ACCOUNTING_INVARIANT: u64 = 5;

/// Treasury schema version must change.
const E_VERSION_UNCHANGED: u64 = 6;

/// Root administrative capability for the Treasury subsystem.
///
/// Possession of this object authorizes:
/// - Treasury-local pause changes
/// - Treasury version upgrades
/// - Treasury withdrawals
///
/// This capability must remain privately owned and must never be shared.
public struct TreasuryAdminCap has key, store {
    id: UID,
}

/// Shared protocol treasury holding actual SUI fee revenue.
///
/// Accounting invariant:
///
/// total_deposited
///     = balance.value()
///     + total_withdrawn
///
/// Internal routing balances are introduced later by RevenueRouter,
/// FeeVault and InsuranceFund modules. ProtocolTreasury remains the
/// canonical protocol-owned settlement treasury.
public struct ProtocolTreasury has key {
    id: UID,
    version: u64,
    paused: bool,
    funds: Balance<SUI>,
    total_deposited: u64,
    total_withdrawn: u64,
    deposit_count: u64,
    withdrawal_count: u64,
    last_deposit_epoch: u64,
    last_withdrawal_epoch: u64,
}

/// Emitted whenever SUI enters the Protocol Treasury.
public struct TreasuryDeposit has copy, drop {
    treasury_id: ID,
    amount: u64,
    balance_after: u64,
    total_deposited: u64,
    deposited_by: address,
    epoch: u64,
}

/// Emitted whenever an administrator withdraws SUI.
public struct TreasuryWithdrawal has copy, drop {
    treasury_id: ID,
    amount: u64,
    balance_after: u64,
    total_withdrawn: u64,
    recipient: address,
    withdrawn_by: address,
    epoch: u64,
}

/// Emitted whenever the Treasury-local pause state changes.
public struct TreasuryPauseStateChanged has copy, drop {
    treasury_id: ID,
    paused: bool,
    changed_by: address,
}

/// Emitted whenever the Treasury schema version changes.
public struct TreasuryVersionChanged has copy, drop {
    treasury_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

/// Initializes the Treasury subsystem.
///
/// Package publisher receives TreasuryAdminCap.
/// ProtocolTreasury becomes a shared object.
fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        TreasuryAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        ProtocolTreasury {
            id: object::new(ctx),
            version: 1,
            paused: false,
            funds: balance::zero<SUI>(),
            total_deposited: 0,
            total_withdrawn: 0,
            deposit_count: 0,
            withdrawal_count: 0,
            last_deposit_epoch: 0,
            last_withdrawal_epoch: 0,
        },
    );
}

/// Deposits an actual SUI Coin into the Protocol Treasury.
///
/// Anyone may deposit protocol revenue, but deposits are disabled whenever:
/// - the global Tobmate protocol is paused; or
/// - the Treasury subsystem is locally paused.
public fun deposit(
    access_control: &AccessControl,
    treasury: &mut ProtocolTreasury,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(access_control, treasury);

    let amount = coin::value(&payment);
    assert!(amount > 0, E_ZERO_AMOUNT);

    let payment_balance = coin::into_balance(payment);
    balance::join(&mut treasury.funds, payment_balance);

    treasury.total_deposited =
        treasury.total_deposited + amount;
    treasury.deposit_count =
        treasury.deposit_count + 1;
    treasury.last_deposit_epoch =
        tx_context::epoch(ctx);

    assert_accounting_invariant(treasury);

    event::emit(TreasuryDeposit {
        treasury_id: object::uid_to_inner(&treasury.id),
        amount,
        balance_after: balance::value(&treasury.funds),
        total_deposited: treasury.total_deposited,
        deposited_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

/// Withdraws SUI from the Protocol Treasury.
///
/// Only the owner of TreasuryAdminCap may authorize this operation.
/// The withdrawn Coin is transferred directly to `recipient`.
public fun withdraw(
    _admin_cap: &TreasuryAdminCap,
    access_control: &AccessControl,
    treasury: &mut ProtocolTreasury,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert_operational(access_control, treasury);
    assert!(amount > 0, E_ZERO_AMOUNT);
    assert!(
        balance::value(&treasury.funds) >= amount,
        E_INSUFFICIENT_BALANCE,
    );

    let withdrawn_balance =
        balance::split(&mut treasury.funds, amount);

    treasury.total_withdrawn =
        treasury.total_withdrawn + amount;
    treasury.withdrawal_count =
        treasury.withdrawal_count + 1;
    treasury.last_withdrawal_epoch =
        tx_context::epoch(ctx);

    assert_accounting_invariant(treasury);

    let withdrawn_coin =
        coin::from_balance(withdrawn_balance, ctx);

    transfer::public_transfer(withdrawn_coin, recipient);

    event::emit(TreasuryWithdrawal {
        treasury_id: object::uid_to_inner(&treasury.id),
        amount,
        balance_after: balance::value(&treasury.funds),
        total_withdrawn: treasury.total_withdrawn,
        recipient,
        withdrawn_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

/// Changes the Treasury-local pause state.
///
/// Global protocol pause and Treasury-local pause are independent.
/// Either pause state blocks deposits and withdrawals.
public fun set_paused(
    _admin_cap: &TreasuryAdminCap,
    treasury: &mut ProtocolTreasury,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(treasury.paused != paused, E_STATE_UNCHANGED);

    treasury.paused = paused;

    event::emit(TreasuryPauseStateChanged {
        treasury_id: object::uid_to_inner(&treasury.id),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}

/// Updates the Treasury schema version.
public fun set_version(
    _admin_cap: &TreasuryAdminCap,
    treasury: &mut ProtocolTreasury,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version = treasury.version;
    assert!(previous_version != new_version, E_VERSION_UNCHANGED);

    treasury.version = new_version;

    event::emit(TreasuryVersionChanged {
        treasury_id: object::uid_to_inner(&treasury.id),
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

/// Aborts unless both the global protocol and Treasury are operational.
public fun assert_operational(
    access_control: &AccessControl,
    treasury: &ProtocolTreasury,
) {
    access_control::assert_not_paused(access_control);
    assert!(!treasury.paused, E_TREASURY_PAUSED);
}

/// Verifies the canonical Treasury accounting invariant.
public fun assert_accounting_invariant(
    treasury: &ProtocolTreasury,
) {
    assert!(
        treasury.total_deposited
            == balance::value(&treasury.funds)
                + treasury.total_withdrawn,
        E_ACCOUNTING_INVARIANT,
    );
}

/// Returns the Treasury object ID.
public fun treasury_id(
    treasury: &ProtocolTreasury,
): ID {
    object::uid_to_inner(&treasury.id)
}

/// Returns the current SUI balance held by the Treasury.
public fun balance(
    treasury: &ProtocolTreasury,
): u64 {
    balance::value(&treasury.funds)
}

/// Returns all-time gross deposits.
public fun total_deposited(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.total_deposited
}

/// Returns all-time gross withdrawals.
public fun total_withdrawn(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.total_withdrawn
}

/// Returns the number of successful deposits.
public fun deposit_count(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.deposit_count
}

/// Returns the number of successful withdrawals.
public fun withdrawal_count(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.withdrawal_count
}

/// Returns the epoch of the latest successful deposit.
public fun last_deposit_epoch(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.last_deposit_epoch
}

/// Returns the epoch of the latest successful withdrawal.
public fun last_withdrawal_epoch(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.last_withdrawal_epoch
}

/// Returns whether the Treasury subsystem is locally paused.
public fun is_paused(
    treasury: &ProtocolTreasury,
): bool {
    treasury.paused
}

/// Returns the Treasury schema version.
public fun version(
    treasury: &ProtocolTreasury,
): u64 {
    treasury.version
}

// -------------------------------------------------------------------------
// Test-only fixtures
// -------------------------------------------------------------------------

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): TreasuryAdminCap {
    TreasuryAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): ProtocolTreasury {
    ProtocolTreasury {
        id: object::new(ctx),
        version: 1,
        paused: false,
        funds: balance::zero<SUI>(),
        total_deposited: 0,
        total_withdrawn: 0,
        deposit_count: 0,
        withdrawal_count: 0,
        last_deposit_epoch: 0,
        last_withdrawal_epoch: 0,
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    admin_cap: TreasuryAdminCap,
) {
    let TreasuryAdminCap { id } = admin_cap;
    object::delete(id);
}

#[test_only]
public fun destroy_empty_for_testing(
    treasury: ProtocolTreasury,
) {
    assert!(balance::value(&treasury.funds) == 0, E_ACCOUNTING_INVARIANT);

    let ProtocolTreasury {
        id,
        version: _,
        paused: _,
        funds,
        total_deposited: _,
        total_withdrawn: _,
        deposit_count: _,
        withdrawal_count: _,
        last_deposit_epoch: _,
        last_withdrawal_epoch: _,
    } = treasury;

    balance::destroy_zero(funds);
    object::delete(id);
}
