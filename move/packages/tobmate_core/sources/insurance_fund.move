module tobmate_core::insurance_fund;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, ID, UID};
use sui::sui::SUI;
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use std::vector;

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

const CLAIM_STATUS_SUBMITTED: u8 = 1;
const CLAIM_STATUS_REVIEWED: u8 = 2;
const CLAIM_STATUS_APPROVED: u8 = 3;
const CLAIM_STATUS_REJECTED: u8 = 4;
const CLAIM_STATUS_PAID: u8 = 5;

const E_FUND_PAUSED: u64 = 1;
const E_ZERO_DEPOSIT: u64 = 2;
const E_ZERO_CLAIM_AMOUNT: u64 = 3;
const E_CLAIM_NOT_FOUND: u64 = 4;
const E_INVALID_CLAIM_STATUS: u64 = 5;
const E_INVALID_APPROVED_AMOUNT: u64 = 6;
const E_INSUFFICIENT_BALANCE: u64 = 7;
const E_STATE_UNCHANGED: u64 = 8;
const E_VERSION_UNCHANGED: u64 = 9;
const E_ACCOUNTING_INVARIANT: u64 = 10;

public struct InsuranceFundAdminCap has key, store {
    id: UID,
}

public struct InsuranceClaim has store {
    claim_id: u64,
    claimant: address,
    requested_amount: u64,
    approved_amount: u64,
    claim_type: u64,
    evidence_hash: vector<u8>,
    status: u8,
    submitted_epoch: u64,
    reviewed_epoch: u64,
    resolved_epoch: u64,
    reviewer: address,
    resolution_code: u64,
}

public struct InsuranceFund has key {
    id: UID,
    version: u64,
    paused: bool,
    funds: Balance<SUI>,
    claims: vector<InsuranceClaim>,
    next_claim_id: u64,
    total_deposited: u64,
    total_claimed: u64,
    total_approved: u64,
    total_paid: u64,
    total_rejected: u64,
    deposit_count: u64,
    paid_claim_count: u64,
    rejected_claim_count: u64,
}

public struct InsuranceDeposited has copy, drop {
    fund_id: ID,
    amount: u64,
    deposited_by: address,
    epoch: u64,
}

public struct InsuranceClaimSubmitted has copy, drop {
    fund_id: ID,
    claim_id: u64,
    claimant: address,
    requested_amount: u64,
    claim_type: u64,
    epoch: u64,
}

public struct InsuranceClaimReviewed has copy, drop {
    fund_id: ID,
    claim_id: u64,
    reviewer: address,
    epoch: u64,
}

public struct InsuranceClaimApproved has copy, drop {
    fund_id: ID,
    claim_id: u64,
    approved_amount: u64,
    approved_by: address,
    resolution_code: u64,
    epoch: u64,
}

public struct InsuranceClaimRejected has copy, drop {
    fund_id: ID,
    claim_id: u64,
    rejected_by: address,
    resolution_code: u64,
    epoch: u64,
}

public struct InsuranceClaimPaid has copy, drop {
    fund_id: ID,
    claim_id: u64,
    claimant: address,
    amount: u64,
    paid_by: address,
    epoch: u64,
}

public struct InsuranceFundPauseStateChanged has copy, drop {
    fund_id: ID,
    paused: bool,
    changed_by: address,
}

public struct InsuranceFundVersionChanged has copy, drop {
    fund_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

fun init(ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);

    transfer::transfer(
        InsuranceFundAdminCap {
            id: object::new(ctx),
        },
        sender,
    );

    transfer::share_object(
        InsuranceFund {
            id: object::new(ctx),
            version: 1,
            paused: false,
            funds: balance::zero<SUI>(),
            claims: vector[],
            next_claim_id: 1,
            total_deposited: 0,
            total_claimed: 0,
            total_approved: 0,
            total_paid: 0,
            total_rejected: 0,
            deposit_count: 0,
            paid_claim_count: 0,
            rejected_claim_count: 0,
        },
    );
}

public fun deposit(
    access: &AccessControl,
    fund: &mut InsuranceFund,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert_operational(access, fund);

    let amount = coin::value(&payment);
    assert!(amount > 0, E_ZERO_DEPOSIT);

    balance::join(
        &mut fund.funds,
        coin::into_balance(payment),
    );

    fund.total_deposited =
        fund.total_deposited + amount;

    fund.deposit_count =
        fund.deposit_count + 1;

    assert_accounting_invariant(fund);

    event::emit(InsuranceDeposited {
        fund_id: fund_id(fund),
        amount,
        deposited_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

public fun submit_claim(
    access: &AccessControl,
    fund: &mut InsuranceFund,
    requested_amount: u64,
    claim_type: u64,
    evidence_hash: vector<u8>,
    ctx: &mut TxContext,
): u64 {
    assert_operational(access, fund);
    assert!(requested_amount > 0, E_ZERO_CLAIM_AMOUNT);

    let claim_id = fund.next_claim_id;
    let claimant = tx_context::sender(ctx);
    let epoch = tx_context::epoch(ctx);

    vector::push_back(
        &mut fund.claims,
        InsuranceClaim {
            claim_id,
            claimant,
            requested_amount,
            approved_amount: 0,
            claim_type,
            evidence_hash,
            status: CLAIM_STATUS_SUBMITTED,
            submitted_epoch: epoch,
            reviewed_epoch: 0,
            resolved_epoch: 0,
            reviewer: @0x0,
            resolution_code: 0,
        },
    );

    fund.next_claim_id = claim_id + 1;
    fund.total_claimed =
        fund.total_claimed + requested_amount;

    event::emit(InsuranceClaimSubmitted {
        fund_id: fund_id(fund),
        claim_id,
        claimant,
        requested_amount,
        claim_type,
        epoch,
    });

    claim_id
}

public fun review_claim(
    _admin_cap: &InsuranceFundAdminCap,
    access: &AccessControl,
    fund: &mut InsuranceFund,
    claim_id: u64,
    ctx: &mut TxContext,
) {
    assert_operational(access, fund);

    let index = find_claim_index(fund, claim_id);
    let claim = vector::borrow_mut(
        &mut fund.claims,
        index,
    );

    assert!(
        claim.status == CLAIM_STATUS_SUBMITTED,
        E_INVALID_CLAIM_STATUS,
    );

    claim.status = CLAIM_STATUS_REVIEWED;
    claim.reviewer = tx_context::sender(ctx);
    claim.reviewed_epoch = tx_context::epoch(ctx);

    event::emit(InsuranceClaimReviewed {
        fund_id: fund_id(fund),
        claim_id,
        reviewer: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

public fun approve_claim(
    _admin_cap: &InsuranceFundAdminCap,
    access: &AccessControl,
    fund: &mut InsuranceFund,
    claim_id: u64,
    approved_amount: u64,
    resolution_code: u64,
    ctx: &mut TxContext,
) {
    assert_operational(access, fund);

    let index = find_claim_index(fund, claim_id);
    let claim = vector::borrow_mut(
        &mut fund.claims,
        index,
    );

    assert!(
        claim.status == CLAIM_STATUS_REVIEWED,
        E_INVALID_CLAIM_STATUS,
    );

    assert!(
        approved_amount > 0
            && approved_amount
                <= claim.requested_amount,
        E_INVALID_APPROVED_AMOUNT,
    );

    claim.approved_amount = approved_amount;
    claim.status = CLAIM_STATUS_APPROVED;
    claim.resolution_code = resolution_code;
    claim.resolved_epoch = tx_context::epoch(ctx);

    fund.total_approved =
        fund.total_approved + approved_amount;

    event::emit(InsuranceClaimApproved {
        fund_id: fund_id(fund),
        claim_id,
        approved_amount,
        approved_by: tx_context::sender(ctx),
        resolution_code,
        epoch: tx_context::epoch(ctx),
    });
}

public fun reject_claim(
    _admin_cap: &InsuranceFundAdminCap,
    access: &AccessControl,
    fund: &mut InsuranceFund,
    claim_id: u64,
    resolution_code: u64,
    ctx: &mut TxContext,
) {
    assert_operational(access, fund);

    let index = find_claim_index(fund, claim_id);
    let claim = vector::borrow_mut(
        &mut fund.claims,
        index,
    );

    assert!(
        claim.status == CLAIM_STATUS_SUBMITTED
            || claim.status == CLAIM_STATUS_REVIEWED,
        E_INVALID_CLAIM_STATUS,
    );

    claim.status = CLAIM_STATUS_REJECTED;
    claim.resolution_code = resolution_code;
    claim.resolved_epoch = tx_context::epoch(ctx);

    fund.total_rejected =
        fund.total_rejected + claim.requested_amount;

    fund.rejected_claim_count =
        fund.rejected_claim_count + 1;

    event::emit(InsuranceClaimRejected {
        fund_id: fund_id(fund),
        claim_id,
        rejected_by: tx_context::sender(ctx),
        resolution_code,
        epoch: tx_context::epoch(ctx),
    });
}

public fun pay_claim(
    _admin_cap: &InsuranceFundAdminCap,
    access: &AccessControl,
    fund: &mut InsuranceFund,
    claim_id: u64,
    ctx: &mut TxContext,
) {
    assert_operational(access, fund);

    let index = find_claim_index(fund, claim_id);

    let (
        claimant,
        approved_amount,
        status,
    ) = {
        let claim = vector::borrow(
            &fund.claims,
            index,
        );

        (
            claim.claimant,
            claim.approved_amount,
            claim.status,
        )
    };

    assert!(
        status == CLAIM_STATUS_APPROVED,
        E_INVALID_CLAIM_STATUS,
    );

    assert!(
        balance::value(&fund.funds)
            >= approved_amount,
        E_INSUFFICIENT_BALANCE,
    );

    let payment_balance =
        balance::split(
            &mut fund.funds,
            approved_amount,
        );

    let payment =
        coin::from_balance(payment_balance, ctx);

    transfer::public_transfer(payment, claimant);

    let claim = vector::borrow_mut(
        &mut fund.claims,
        index,
    );

    claim.status = CLAIM_STATUS_PAID;
    claim.resolved_epoch = tx_context::epoch(ctx);

    fund.total_paid =
        fund.total_paid + approved_amount;

    fund.paid_claim_count =
        fund.paid_claim_count + 1;

    assert_accounting_invariant(fund);

    event::emit(InsuranceClaimPaid {
        fund_id: fund_id(fund),
        claim_id,
        claimant,
        amount: approved_amount,
        paid_by: tx_context::sender(ctx),
        epoch: tx_context::epoch(ctx),
    });
}

public fun set_paused(
    _admin_cap: &InsuranceFundAdminCap,
    fund: &mut InsuranceFund,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(fund.paused != paused, E_STATE_UNCHANGED);

    fund.paused = paused;

    event::emit(InsuranceFundPauseStateChanged {
        fund_id: fund_id(fund),
        paused,
        changed_by: tx_context::sender(ctx),
    });
}

public fun set_version(
    _admin_cap: &InsuranceFundAdminCap,
    fund: &mut InsuranceFund,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version = fund.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    fund.version = new_version;

    event::emit(InsuranceFundVersionChanged {
        fund_id: fund_id(fund),
        previous_version,
        new_version,
        changed_by: tx_context::sender(ctx),
    });
}

fun find_claim_index(
    fund: &InsuranceFund,
    claim_id: u64,
): u64 {
    let length = vector::length(&fund.claims);
    let mut index = 0;

    while (index < length) {
        let claim =
            vector::borrow(&fund.claims, index);

        if (claim.claim_id == claim_id) {
            return index
        };

        index = index + 1;
    };

    abort E_CLAIM_NOT_FOUND
}

public fun assert_operational(
    access: &AccessControl,
    fund: &InsuranceFund,
) {
    access_control::assert_not_paused(access);
    assert!(!fund.paused, E_FUND_PAUSED);
}

public fun assert_accounting_invariant(
    fund: &InsuranceFund,
) {
    assert!(
        fund.total_deposited
            == balance::value(&fund.funds)
                + fund.total_paid,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        fund.total_paid <= fund.total_approved,
        E_ACCOUNTING_INVARIANT,
    );
}

public fun fund_id(fund: &InsuranceFund): ID {
    object::uid_to_inner(&fund.id)
}

public fun version(fund: &InsuranceFund): u64 {
    fund.version
}

public fun is_paused(fund: &InsuranceFund): bool {
    fund.paused
}

public fun fund_balance(fund: &InsuranceFund): u64 {
    balance::value(&fund.funds)
}

public fun claim_count(fund: &InsuranceFund): u64 {
    vector::length(&fund.claims)
}

public fun total_deposited(
    fund: &InsuranceFund,
): u64 {
    fund.total_deposited
}

public fun total_claimed(
    fund: &InsuranceFund,
): u64 {
    fund.total_claimed
}

public fun total_approved(
    fund: &InsuranceFund,
): u64 {
    fund.total_approved
}

public fun total_paid(fund: &InsuranceFund): u64 {
    fund.total_paid
}

public fun total_rejected(
    fund: &InsuranceFund,
): u64 {
    fund.total_rejected
}

public fun deposit_count(
    fund: &InsuranceFund,
): u64 {
    fund.deposit_count
}

public fun paid_claim_count(
    fund: &InsuranceFund,
): u64 {
    fund.paid_claim_count
}

public fun rejected_claim_count(
    fund: &InsuranceFund,
): u64 {
    fund.rejected_claim_count
}

public fun claim_status(
    fund: &InsuranceFund,
    claim_id: u64,
): u8 {
    let index = find_claim_index(fund, claim_id);
    vector::borrow(&fund.claims, index).status
}

public fun claim_requested_amount(
    fund: &InsuranceFund,
    claim_id: u64,
): u64 {
    let index = find_claim_index(fund, claim_id);
    vector::borrow(
        &fund.claims,
        index,
    ).requested_amount
}

public fun claim_approved_amount(
    fund: &InsuranceFund,
    claim_id: u64,
): u64 {
    let index = find_claim_index(fund, claim_id);
    vector::borrow(
        &fund.claims,
        index,
    ).approved_amount
}

public fun status_submitted(): u8 {
    CLAIM_STATUS_SUBMITTED
}

public fun status_reviewed(): u8 {
    CLAIM_STATUS_REVIEWED
}

public fun status_approved(): u8 {
    CLAIM_STATUS_APPROVED
}

public fun status_rejected(): u8 {
    CLAIM_STATUS_REJECTED
}

public fun status_paid(): u8 {
    CLAIM_STATUS_PAID
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): InsuranceFundAdminCap {
    InsuranceFundAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): InsuranceFund {
    InsuranceFund {
        id: object::new(ctx),
        version: 1,
        paused: false,
        funds: balance::zero<SUI>(),
        claims: vector[],
        next_claim_id: 1,
        total_deposited: 0,
        total_claimed: 0,
        total_approved: 0,
        total_paid: 0,
        total_rejected: 0,
        deposit_count: 0,
        paid_claim_count: 0,
        rejected_claim_count: 0,
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: InsuranceFundAdminCap,
) {
    let InsuranceFundAdminCap { id } = cap;
    object::delete(id);
}

#[test_only]
public fun drain_for_testing(
    fund: &mut InsuranceFund,
    ctx: &mut TxContext,
): Coin<SUI> {
    let funds =
        balance::withdraw_all(&mut fund.funds);

    coin::from_balance(funds, ctx)
}

#[test_only]
public fun destroy_for_testing(
    fund: InsuranceFund,
) {
    let InsuranceFund {
        id,
        version: _,
        paused: _,
        funds,
        mut claims,
        next_claim_id: _,
        total_deposited: _,
        total_claimed: _,
        total_approved: _,
        total_paid: _,
        total_rejected: _,
        deposit_count: _,
        paid_claim_count: _,
        rejected_claim_count: _,
    } = fund;

    balance::destroy_zero(funds);

    while (!vector::is_empty(&claims)) {
        let InsuranceClaim {
            claim_id: _,
            claimant: _,
            requested_amount: _,
            approved_amount: _,
            claim_type: _,
            evidence_hash: _,
            status: _,
            submitted_epoch: _,
            reviewed_epoch: _,
            resolved_epoch: _,
            reviewer: _,
            resolution_code: _,
        } = vector::pop_back(&mut claims);
    };

    vector::destroy_empty(claims);
    object::delete(id);
}
