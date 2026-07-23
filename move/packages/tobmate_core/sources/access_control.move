module tobmate_core::access_control;

use sui::event;
use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

/// Protocol is currently paused.
const E_PROTOCOL_PAUSED: u64 = 1;

/// Requested pause state is already active.
const E_STATE_UNCHANGED: u64 = 2;

/// Root administrative capability.
///
/// Possession of this object authorizes protocol-level administration.
/// This capability must never be shared.
public struct AdminCap has key, store {
    id: UID,
}

/// Shared protocol access-control state.
///
/// Later modules including TMID, Gold Reserve, GOLDPEG and Mint/Burn
/// must check this object before performing state-changing operations.
public struct AccessControl has key {
    id: UID,
    version: u64,
    paused: bool,
}

/// Emitted whenever the global pause state changes.
public struct PauseStateChanged has copy, drop {
    paused: bool,
    changed_by: address,
}

/// Emitted when the access-control schema version changes.
public struct AccessControlVersionChanged has copy, drop {
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

/// Runs once when the package is first published.
///
/// - Transfers the unique AdminCap to the publisher.
/// - Creates the globally shared AccessControl object.
fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    let access_control = AccessControl {
        id: object::new(ctx),
        version: 1,
        paused: false,
    };

    transfer::transfer(admin_cap, publisher);
    transfer::share_object(access_control);
}

/// Abort unless the protocol is operating normally.
public fun assert_not_paused(access_control: &AccessControl) {
    assert!(!access_control.paused, E_PROTOCOL_PAUSED);
}

/// Set the global protocol pause state.
///
/// Requiring `&AdminCap` ensures that only its current owner can call
/// this function successfully.
public fun set_paused(
    _admin_cap: &AdminCap,
    access_control: &mut AccessControl,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(access_control.paused != paused, E_STATE_UNCHANGED);

    access_control.paused = paused;

    event::emit(PauseStateChanged {
        paused,
        changed_by: tx_context::sender(ctx),
    });
}

/// Update the access-control schema version.
public fun set_version(
    _admin_cap: &AdminCap,
    access_control: &mut AccessControl,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version = access_control.version;
    assert!(previous_version != new_version, E_STATE_UNCHANGED);

    access_control.version = new_version;

    event::emit(AccessControlVersionChanged {
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

public fun is_paused(access_control: &AccessControl): bool {
    access_control.paused
}

public fun version(access_control: &AccessControl): u64 {
    access_control.version
}

// TOBMATE_TEST_ACCESS_CONTROL_FIXTURE
#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): AccessControl {
    AccessControl {
        id: object::new(ctx),
        version: 1,
        paused: false,
    }
}

#[test_only]
public fun destroy_for_testing(
    access_control: AccessControl,
) {
    let AccessControl {
        id,
        version: _,
        paused: _,
    } = access_control;

    object::delete(id);
}
