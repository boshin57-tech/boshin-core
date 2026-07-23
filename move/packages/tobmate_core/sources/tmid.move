module tobmate_core::tmid;

use sui::event;
use sui::object::{Self, ID, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

use tobmate_core::access_control::{Self, AccessControl};

const E_INVALID_STATUS: u64 = 1;
const E_ALREADY_REVOKED: u64 = 2;
const E_CONTROLLER_UNCHANGED: u64 = 3;

/// TMID status values.
const STATUS_ACTIVE: u8 = 1;
const STATUS_SUSPENDED: u8 = 2;
const STATUS_REVOKED: u8 = 3;

/// Capability authorizing TMID issuance and lifecycle administration.
public struct TMIDAdminCap has key, store {
    id: UID,
}

/// Shared registry tracking TMID issuance.
public struct TMIDRegistry has key {
    id: UID,
    version: u64,
    total_issued: u64,
}

/// Tobmate identity object.
public struct TMID has key, store {
    id: UID,
    controller: address,
    status: u8,
    sequence: u64,
    created_at_epoch: u64,
}

/// Emitted when a TMID is issued.
public struct TMIDIssued has copy, drop {
    tmid_id: ID,
    controller: address,
    sequence: u64,
}

/// Emitted when TMID status changes.
public struct TMIDStatusChanged has copy, drop {
    tmid_id: ID,
    previous_status: u8,
    new_status: u8,
    changed_by: address,
}

/// Emitted when the TMID controller changes.
public struct TMIDControllerChanged has copy, drop {
    tmid_id: ID,
    previous_controller: address,
    new_controller: address,
    changed_by: address,
}

fun init(ctx: &mut TxContext) {
    let publisher = tx_context::sender(ctx);

    transfer::transfer(
        TMIDAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        TMIDRegistry {
            id: object::new(ctx),
            version: 1,
            total_issued: 0,
        },
    );
}

/// Issue a new active TMID.
public fun issue(
    _admin_cap: &TMIDAdminCap,
    access_control: &AccessControl,
    registry: &mut TMIDRegistry,
    controller: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);

    registry.total_issued = registry.total_issued + 1;
    let sequence = registry.total_issued;

    let tmid = TMID {
        id: object::new(ctx),
        controller,
        status: STATUS_ACTIVE,
        sequence,
        created_at_epoch: tx_context::epoch(ctx),
    };

    let tmid_id = object::uid_to_inner(&tmid.id);

    event::emit(TMIDIssued {
        tmid_id,
        controller,
        sequence,
    });

    transfer::transfer(tmid, controller);
}

/// Suspend an active TMID.
public fun suspend(
    _admin_cap: &TMIDAdminCap,
    access_control: &AccessControl,
    tmid: &mut TMID,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(tmid.status == STATUS_ACTIVE, E_INVALID_STATUS);

    let previous_status = tmid.status;
    tmid.status = STATUS_SUSPENDED;

    event::emit(TMIDStatusChanged {
        tmid_id: object::uid_to_inner(&tmid.id),
        previous_status,
        new_status: STATUS_SUSPENDED,
        changed_by: tx_context::sender(ctx),
    });
}

/// Reactivate a suspended TMID.
public fun reactivate(
    _admin_cap: &TMIDAdminCap,
    access_control: &AccessControl,
    tmid: &mut TMID,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(tmid.status == STATUS_SUSPENDED, E_INVALID_STATUS);

    let previous_status = tmid.status;
    tmid.status = STATUS_ACTIVE;

    event::emit(TMIDStatusChanged {
        tmid_id: object::uid_to_inner(&tmid.id),
        previous_status,
        new_status: STATUS_ACTIVE,
        changed_by: tx_context::sender(ctx),
    });
}

/// Permanently revoke a TMID.
public fun revoke(
    _admin_cap: &TMIDAdminCap,
    access_control: &AccessControl,
    tmid: &mut TMID,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(tmid.status != STATUS_REVOKED, E_ALREADY_REVOKED);

    let previous_status = tmid.status;
    tmid.status = STATUS_REVOKED;

    event::emit(TMIDStatusChanged {
        tmid_id: object::uid_to_inner(&tmid.id),
        previous_status,
        new_status: STATUS_REVOKED,
        changed_by: tx_context::sender(ctx),
    });
}

/// Change the controlling address of a non-revoked TMID.
public fun change_controller(
    _admin_cap: &TMIDAdminCap,
    access_control: &AccessControl,
    tmid: &mut TMID,
    new_controller: address,
    ctx: &mut TxContext,
) {
    access_control::assert_not_paused(access_control);
    assert!(tmid.status != STATUS_REVOKED, E_ALREADY_REVOKED);
    assert!(tmid.controller != new_controller, E_CONTROLLER_UNCHANGED);

    let previous_controller = tmid.controller;
    tmid.controller = new_controller;

    event::emit(TMIDControllerChanged {
        tmid_id: object::uid_to_inner(&tmid.id),
        previous_controller,
        new_controller,
        changed_by: tx_context::sender(ctx),
    });
}

public fun controller(tmid: &TMID): address {
    tmid.controller
}

public fun status(tmid: &TMID): u8 {
    tmid.status
}

public fun sequence(tmid: &TMID): u64 {
    tmid.sequence
}

public fun created_at_epoch(tmid: &TMID): u64 {
    tmid.created_at_epoch
}

public fun total_issued(registry: &TMIDRegistry): u64 {
    registry.total_issued
}

public fun is_active(tmid: &TMID): bool {
    tmid.status == STATUS_ACTIVE
}

public fun is_suspended(tmid: &TMID): bool {
    tmid.status == STATUS_SUSPENDED
}

public fun is_revoked(tmid: &TMID): bool {
    tmid.status == STATUS_REVOKED
}
