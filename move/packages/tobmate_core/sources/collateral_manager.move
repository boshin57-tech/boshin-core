module tobmate_core::collateral_manager;

use std::vector;

use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};
use sui::transfer;
use sui::event;

use tobmate_core::access_control::{
    Self as access_control,
    AccessControl,
};

use tobmate_core::oracle_price_router::{
    Self as oracle_price_router,
    PriceQuote,
};

const BPS_DENOMINATOR: u64 = 10_000;

const COLLATERAL_SUI: u8 = 1;
const COLLATERAL_GOLDPEG: u8 = 2;
const COLLATERAL_GOLD_NFT: u8 = 3;
const COLLATERAL_LP_POSITION: u8 = 4;
const COLLATERAL_RWA: u8 = 5;

const E_MANAGER_PAUSED: u64 = 1;
const E_STATE_UNCHANGED: u64 = 2;
const E_VERSION_UNCHANGED: u64 = 3;
const E_INVALID_COLLATERAL_TYPE: u64 = 4;
const E_INVALID_LTV: u64 = 5;
const E_INVALID_LIQUIDATION_THRESHOLD: u64 = 6;
const E_INVALID_LIQUIDATION_BONUS: u64 = 7;
const E_DUPLICATE_POLICY: u64 = 8;
const E_POLICY_NOT_FOUND: u64 = 9;
const E_POLICY_INACTIVE: u64 = 10;
const E_POSITION_NOT_FOUND: u64 = 11;
const E_NOT_POSITION_OWNER: u64 = 12;
const E_ZERO_COLLATERAL: u64 = 13;
const E_WITHDRAW_ABOVE_COLLATERAL: u64 = 14;
const E_POSITION_INACTIVE: u64 = 15;
const E_ACCOUNTING_INVARIANT: u64 = 16;
const E_INVALID_PRICE: u64 = 17;
const E_DEBT_EXCEEDS_CAPACITY: u64 = 18;
const E_ORACLE_FEED_MISMATCH: u64 = 19;
const E_UNSAFE_WITHDRAWAL: u64 = 20;

public struct CollateralManagerAdminCap has key, store {
    id: UID,
}

public struct CollateralAssetPolicy has store {
    policy_id: u64,

    collateral_type: u8,

    asset_key: vector<u8>,

    oracle_symbol: vector<u8>,

    oracle_feed_id: u64,

    asset_decimals: u8,

    max_ltv_bps: u64,

    liquidation_threshold_bps: u64,

    liquidation_bonus_bps: u64,

    active: bool,

    total_collateral_units: u64,

    total_debt_value: u64,

    position_count: u64,
}

public struct CollateralPosition has store {
    position_id: u64,

    policy_id: u64,

    owner: address,

    collateral_units: u64,

    debt_value: u64,

    active: bool,

    created_epoch: u64,

    updated_epoch: u64,
}

public struct CollateralManager has key {
    id: UID,

    version: u64,

    paused: bool,

    policies: vector<CollateralAssetPolicy>,

    positions: vector<CollateralPosition>,

    next_policy_id: u64,

    next_position_id: u64,

    total_collateral_units: u64,

    total_debt_value: u64,

    active_position_count: u64,
}

public struct CollateralPolicyRegistered has copy, drop {
    manager_id: ID,
    policy_id: u64,
    collateral_type: u8,
    max_ltv_bps: u64,
    liquidation_threshold_bps: u64,
    liquidation_bonus_bps: u64,
    registered_by: address,
}

public struct CollateralPolicyStateChanged has copy, drop {
    manager_id: ID,
    policy_id: u64,
    active: bool,
    changed_by: address,
}

public struct CollateralPositionOpened has copy, drop {
    manager_id: ID,
    position_id: u64,
    policy_id: u64,
    owner: address,
    collateral_units: u64,
}

public struct CollateralDeposited has copy, drop {
    manager_id: ID,
    position_id: u64,
    amount: u64,
    collateral_after: u64,
}

public struct CollateralWithdrawn has copy, drop {
    manager_id: ID,
    position_id: u64,
    amount: u64,
    collateral_after: u64,
}

public struct CollateralDebtUpdated has copy, drop {
    manager_id: ID,
    position_id: u64,
    previous_debt_value: u64,
    new_debt_value: u64,
}

public struct CollateralManagerPauseChanged has copy, drop {
    manager_id: ID,
    paused: bool,
    changed_by: address,
}

public struct CollateralManagerVersionChanged has copy, drop {
    manager_id: ID,
    previous_version: u64,
    new_version: u64,
    changed_by: address,
}

fun init(ctx: &mut TxContext) {
    let publisher =
        tx_context::sender(ctx);

    transfer::transfer(
        CollateralManagerAdminCap {
            id: object::new(ctx),
        },
        publisher,
    );

    transfer::share_object(
        CollateralManager {
            id: object::new(ctx),

            version: 1,

            paused: false,

            policies:
                vector[],

            positions:
                vector[],

            next_policy_id: 1,

            next_position_id: 1,

            total_collateral_units: 0,

            total_debt_value: 0,

            active_position_count: 0,
        },
    );
}

public fun register_policy(
    _admin_cap: &CollateralManagerAdminCap,
    manager: &mut CollateralManager,
    collateral_type: u8,
    asset_key: vector<u8>,
    oracle_symbol: vector<u8>,
    oracle_feed_id: u64,
    asset_decimals: u8,
    max_ltv_bps: u64,
    liquidation_threshold_bps: u64,
    liquidation_bonus_bps: u64,
    ctx: &mut TxContext,
): u64 {
    assert!(
        !manager.paused,
        E_MANAGER_PAUSED,
    );

    assert_valid_collateral_type(
        collateral_type,
    );

    assert_valid_risk_parameters(
        max_ltv_bps,
        liquidation_threshold_bps,
        liquidation_bonus_bps,
    );

    assert!(
        !contains_policy_key(
            manager,
            &asset_key,
        ),
        E_DUPLICATE_POLICY,
    );

    let policy_id =
        manager.next_policy_id;

    manager.next_policy_id =
        policy_id + 1;

    vector::push_back(
        &mut manager.policies,
        CollateralAssetPolicy {
            policy_id,
            collateral_type,
            asset_key,
            oracle_symbol,
            oracle_feed_id,
            asset_decimals,
            max_ltv_bps,
            liquidation_threshold_bps,
            liquidation_bonus_bps,
            active: false,
            total_collateral_units: 0,
            total_debt_value: 0,
            position_count: 0,
        },
    );

    event::emit(CollateralPolicyRegistered {
        manager_id:
            object::uid_to_inner(&manager.id),

        policy_id,
        collateral_type,
        max_ltv_bps,
        liquidation_threshold_bps,
        liquidation_bonus_bps,

        registered_by:
            tx_context::sender(ctx),
    });

    policy_id
}

public fun set_policy_active(
    _admin_cap: &CollateralManagerAdminCap,
    manager: &mut CollateralManager,
    policy_id: u64,
    active: bool,
    ctx: &mut TxContext,
) {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    let policy =
        vector::borrow_mut(
            &mut manager.policies,
            index,
        );

    assert!(
        policy.active != active,
        E_STATE_UNCHANGED,
    );

    policy.active = active;

    event::emit(CollateralPolicyStateChanged {
        manager_id:
            object::uid_to_inner(&manager.id),

        policy_id,

        active,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_policy_risk_parameters(
    _admin_cap: &CollateralManagerAdminCap,
    manager: &mut CollateralManager,
    policy_id: u64,
    max_ltv_bps: u64,
    liquidation_threshold_bps: u64,
    liquidation_bonus_bps: u64,
) {
    assert_valid_risk_parameters(
        max_ltv_bps,
        liquidation_threshold_bps,
        liquidation_bonus_bps,
    );

    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    let policy =
        vector::borrow_mut(
            &mut manager.policies,
            index,
        );

    policy.max_ltv_bps =
        max_ltv_bps;

    policy.liquidation_threshold_bps =
        liquidation_threshold_bps;

    policy.liquidation_bonus_bps =
        liquidation_bonus_bps;
}

fun assert_valid_risk_parameters(
    max_ltv_bps: u64,
    liquidation_threshold_bps: u64,
    liquidation_bonus_bps: u64,
) {
    assert!(
        max_ltv_bps > 0
            && max_ltv_bps < BPS_DENOMINATOR,
        E_INVALID_LTV,
    );

    assert!(
        liquidation_threshold_bps
            > max_ltv_bps
            && liquidation_threshold_bps
                <= BPS_DENOMINATOR,
        E_INVALID_LIQUIDATION_THRESHOLD,
    );

    assert!(
        liquidation_bonus_bps
            <= BPS_DENOMINATOR,
        E_INVALID_LIQUIDATION_BONUS,
    );
}

fun assert_valid_collateral_type(
    collateral_type: u8,
) {
    assert!(
        collateral_type >= COLLATERAL_SUI
            && collateral_type <= COLLATERAL_RWA,
        E_INVALID_COLLATERAL_TYPE,
    );
}

fun contains_policy_key(
    manager: &CollateralManager,
    asset_key: &vector<u8>,
): bool {
    let length =
        vector::length(
            &manager.policies,
        );

    let mut i = 0;

    while (i < length) {
        let policy =
            vector::borrow(
                &manager.policies,
                i,
            );

        if (&policy.asset_key == asset_key) {
            return true
        };

        i = i + 1;
    };

    false
}

fun find_policy_index(
    manager: &CollateralManager,
    policy_id: u64,
): u64 {
    let length =
        vector::length(
            &manager.policies,
        );

    let mut i = 0;

    while (i < length) {
        let policy =
            vector::borrow(
                &manager.policies,
                i,
            );

        if (policy.policy_id == policy_id) {
            return i
        };

        i = i + 1;
    };

    abort E_POLICY_NOT_FOUND
}

fun find_position_index(
    manager: &CollateralManager,
    position_id: u64,
): u64 {
    let length =
        vector::length(
            &manager.positions,
        );

    let mut i = 0;

    while (i < length) {
        let position =
            vector::borrow(
                &manager.positions,
                i,
            );

        if (position.position_id == position_id) {
            return i
        };

        i = i + 1;
    };

    abort E_POSITION_NOT_FOUND
}

public fun open_position(
    access: &AccessControl,
    manager: &mut CollateralManager,
    policy_id: u64,
    owner: address,
    collateral_units: u64,
    ctx: &mut TxContext,
): u64 {
    assert_operational(
        access,
        manager,
    );

    assert!(
        collateral_units > 0,
        E_ZERO_COLLATERAL,
    );

    let policy_index =
        find_policy_index(
            manager,
            policy_id,
        );

    {
        let policy =
            vector::borrow(
                &manager.policies,
                policy_index,
            );

        assert!(
            policy.active,
            E_POLICY_INACTIVE,
        );
    };

    let position_id =
        manager.next_position_id;

    manager.next_position_id =
        position_id + 1;

    vector::push_back(
        &mut manager.positions,
        CollateralPosition {
            position_id,
            policy_id,
            owner,
            collateral_units,
            debt_value: 0,
            active: true,
            created_epoch:
                tx_context::epoch(ctx),
            updated_epoch:
                tx_context::epoch(ctx),
        },
    );

    {
        let policy =
            vector::borrow_mut(
                &mut manager.policies,
                policy_index,
            );

        policy.total_collateral_units =
            policy.total_collateral_units
                + collateral_units;

        policy.position_count =
            policy.position_count + 1;
    };

    manager.total_collateral_units =
        manager.total_collateral_units
            + collateral_units;

    manager.active_position_count =
        manager.active_position_count + 1;

    event::emit(CollateralPositionOpened {
        manager_id:
            object::uid_to_inner(&manager.id),

        position_id,
        policy_id,
        owner,
        collateral_units,
    });

    position_id
}

public fun deposit_collateral(
    access: &AccessControl,
    manager: &mut CollateralManager,
    position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        manager,
    );

    assert!(
        amount > 0,
        E_ZERO_COLLATERAL,
    );

    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let policy_id;

    {
        let position =
            vector::borrow_mut(
                &mut manager.positions,
                position_index,
            );

        assert!(
            position.active,
            E_POSITION_INACTIVE,
        );

        assert!(
            position.owner
                == tx_context::sender(ctx),
            E_NOT_POSITION_OWNER,
        );

        position.collateral_units =
            position.collateral_units
                + amount;

        position.updated_epoch =
            tx_context::epoch(ctx);

        policy_id =
            position.policy_id;
    };

    let policy_index =
        find_policy_index(
            manager,
            policy_id,
        );

    {
        let policy =
            vector::borrow_mut(
                &mut manager.policies,
                policy_index,
            );

        policy.total_collateral_units =
            policy.total_collateral_units
                + amount;
    };

    manager.total_collateral_units =
        manager.total_collateral_units
            + amount;

    let collateral_after = {
        let position =
            vector::borrow(
                &manager.positions,
                position_index,
            );

        position.collateral_units
    };

    event::emit(CollateralDeposited {
        manager_id:
            object::uid_to_inner(&manager.id),

        position_id,
        amount,
        collateral_after,
    });
}

public fun withdraw_collateral(
    access: &AccessControl,
    manager: &mut CollateralManager,
    position_id: u64,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        manager,
    );

    assert!(
        amount > 0,
        E_ZERO_COLLATERAL,
    );

    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let policy_id;

    {
        let position =
            vector::borrow(
                &manager.positions,
                position_index,
            );

        assert!(
            position.active,
            E_POSITION_INACTIVE,
        );

        assert!(
            position.owner
                == tx_context::sender(ctx),
            E_NOT_POSITION_OWNER,
        );

        assert!(
            position.collateral_units
                >= amount,
            E_WITHDRAW_ABOVE_COLLATERAL,
        );

        policy_id =
            position.policy_id;
    };

    {
        let position =
            vector::borrow_mut(
                &mut manager.positions,
                position_index,
            );

        position.collateral_units =
            position.collateral_units
                - amount;

        position.updated_epoch =
            tx_context::epoch(ctx);
    };

    let policy_index =
        find_policy_index(
            manager,
            policy_id,
        );

    {
        let policy =
            vector::borrow_mut(
                &mut manager.policies,
                policy_index,
            );

        policy.total_collateral_units =
            policy.total_collateral_units
                - amount;
    };

    manager.total_collateral_units =
        manager.total_collateral_units
            - amount;

    let collateral_after = {
        let position =
            vector::borrow(
                &manager.positions,
                position_index,
            );

        position.collateral_units
    };

    event::emit(CollateralWithdrawn {
        manager_id:
            object::uid_to_inner(&manager.id),
        position_id,
        amount,
        collateral_after,
    });
}

public fun set_position_debt_value(
    _admin_cap: &CollateralManagerAdminCap,
    access: &AccessControl,
    manager: &mut CollateralManager,
    position_id: u64,
    new_debt_value: u64,
    ctx: &mut TxContext,
) {
    assert_operational(
        access,
        manager,
    );

    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let policy_id;
    let previous_debt_value;

    {
        let position =
            vector::borrow(
                &manager.positions,
                position_index,
            );

        assert!(
            position.active,
            E_POSITION_INACTIVE,
        );

        policy_id =
            position.policy_id;

        previous_debt_value =
            position.debt_value;
    };

    {
        let position =
            vector::borrow_mut(
                &mut manager.positions,
                position_index,
            );

        position.debt_value =
            new_debt_value;

        position.updated_epoch =
            tx_context::epoch(ctx);
    };

    let policy_index =
        find_policy_index(
            manager,
            policy_id,
        );

    {
        let policy =
            vector::borrow_mut(
                &mut manager.policies,
                policy_index,
            );

        if (new_debt_value >= previous_debt_value) {
            policy.total_debt_value =
                policy.total_debt_value
                    + (
                        new_debt_value
                            - previous_debt_value
                    );
        } else {
            policy.total_debt_value =
                policy.total_debt_value
                    - (
                        previous_debt_value
                            - new_debt_value
                    );
        };
    };

    if (new_debt_value >= previous_debt_value) {
        manager.total_debt_value =
            manager.total_debt_value
                + (
                    new_debt_value
                        - previous_debt_value
                );
    } else {
        manager.total_debt_value =
            manager.total_debt_value
                - (
                    previous_debt_value
                        - new_debt_value
                );
    };

    event::emit(CollateralDebtUpdated {
        manager_id:
            object::uid_to_inner(&manager.id),

        position_id,

        previous_debt_value,

        new_debt_value,
    });
}

public fun collateral_value_from_price(
    collateral_units: u64,
    asset_decimals: u8,
    price: u64,
): u64 {
    assert!(
        price > 0,
        E_INVALID_PRICE,
    );

    let scale =
        pow10(asset_decimals);

    collateral_units
        * price
        / scale
}

public fun borrow_capacity_from_value(
    collateral_value: u64,
    max_ltv_bps: u64,
): u64 {
    collateral_value
        * max_ltv_bps
        / BPS_DENOMINATOR
}

public fun liquidation_value_from_value(
    collateral_value: u64,
    liquidation_threshold_bps: u64,
): u64 {
    collateral_value
        * liquidation_threshold_bps
        / BPS_DENOMINATOR
}

public fun position_collateral_value(
    manager: &CollateralManager,
    position_id: u64,
    price: u64,
): u64 {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    let policy_index =
        find_policy_index(
            manager,
            position.policy_id,
        );

    let policy =
        vector::borrow(
            &manager.policies,
            policy_index,
        );

    collateral_value_from_price(
        position.collateral_units,
        policy.asset_decimals,
        price,
    )
}

public fun position_borrow_capacity(
    manager: &CollateralManager,
    position_id: u64,
    price: u64,
): u64 {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    let policy_index =
        find_policy_index(
            manager,
            position.policy_id,
        );

    let policy =
        vector::borrow(
            &manager.policies,
            policy_index,
        );

    let collateral_value =
        collateral_value_from_price(
            position.collateral_units,
            policy.asset_decimals,
            price,
        );

    borrow_capacity_from_value(
        collateral_value,
        policy.max_ltv_bps,
    )
}

fun pow10(
    decimals: u8,
): u64 {
    let mut result = 1;
    let mut i = 0;

    while (i < decimals) {
        result = result * 10;
        i = i + 1;
    };

    result
}

const HEALTH_FACTOR_SCALE: u64 = 1_000_000;
const NO_DEBT_HEALTH_FACTOR: u64 = 1_000_000_000_000;

public fun health_factor_from_values(
    collateral_value: u64,
    debt_value: u64,
    liquidation_threshold_bps: u64,
): u64 {
    if (debt_value == 0) {
        return NO_DEBT_HEALTH_FACTOR
    };

    let liquidation_value =
        liquidation_value_from_value(
            collateral_value,
            liquidation_threshold_bps,
        );

    liquidation_value
        * HEALTH_FACTOR_SCALE
        / debt_value
}

public fun position_health_factor(
    manager: &CollateralManager,
    position_id: u64,
    price: u64,
): u64 {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    let policy_index =
        find_policy_index(
            manager,
            position.policy_id,
        );

    let policy =
        vector::borrow(
            &manager.policies,
            policy_index,
        );

    let collateral_value =
        collateral_value_from_price(
            position.collateral_units,
            policy.asset_decimals,
            price,
        );

    health_factor_from_values(
        collateral_value,
        position.debt_value,
        policy.liquidation_threshold_bps,
    )
}

public fun is_position_liquidatable(
    manager: &CollateralManager,
    position_id: u64,
    price: u64,
): bool {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    if (!position.active) {
        return false
    };

    if (position.debt_value == 0) {
        return false
    };

    let health_factor =
        position_health_factor(
            manager,
            position_id,
            price,
        );

    health_factor
        < HEALTH_FACTOR_SCALE
}

public fun assert_debt_within_capacity(
    manager: &CollateralManager,
    position_id: u64,
    price: u64,
    proposed_debt_value: u64,
) {
    let capacity =
        position_borrow_capacity(
            manager,
            position_id,
            price,
        );

    assert!(
        proposed_debt_value <= capacity,
        E_DEBT_EXCEEDS_CAPACITY,
    );
}

public fun validated_quote_price(
    quote: &PriceQuote,
): u64 {
    let price =
        oracle_price_router::quote_price(
            quote,
        );

    assert!(
        price > 0,
        E_INVALID_PRICE,
    );

    price
}

public fun position_collateral_value_with_quote(
    manager: &CollateralManager,
    position_id: u64,
    quote: &PriceQuote,
): u64 {
    assert_quote_matches_policy(
        manager,
        position_id,
        quote,
    );


    let price =
        validated_quote_price(
            quote,
        );

    position_collateral_value(
        manager,
        position_id,
        price,
    )
}

public fun position_borrow_capacity_with_quote(
    manager: &CollateralManager,
    position_id: u64,
    quote: &PriceQuote,
): u64 {
    assert_quote_matches_policy(
        manager,
        position_id,
        quote,
    );


    let price =
        validated_quote_price(
            quote,
        );

    position_borrow_capacity(
        manager,
        position_id,
        price,
    )
}

public fun position_health_factor_with_quote(
    manager: &CollateralManager,
    position_id: u64,
    quote: &PriceQuote,
): u64 {
    assert_quote_matches_policy(
        manager,
        position_id,
        quote,
    );


    let price =
        validated_quote_price(
            quote,
        );

    position_health_factor(
        manager,
        position_id,
        price,
    )
}

public fun is_position_liquidatable_with_quote(
    manager: &CollateralManager,
    position_id: u64,
    quote: &PriceQuote,
): bool {
    assert_quote_matches_policy(
        manager,
        position_id,
        quote,
    );


    let price =
        validated_quote_price(
            quote,
        );

    is_position_liquidatable(
        manager,
        position_id,
        price,
    )
}

public fun assert_quote_matches_policy(
    manager: &CollateralManager,
    position_id: u64,
    quote: &PriceQuote,
) {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    let policy_index =
        find_policy_index(
            manager,
            position.policy_id,
        );

    let policy =
        vector::borrow(
            &manager.policies,
            policy_index,
        );

    let quote_feed_id =
        oracle_price_router::quote_feed_id(
            quote,
        );

    assert!(
        quote_feed_id
            == policy.oracle_feed_id,
        E_ORACLE_FEED_MISMATCH,
    );
}

public fun assert_operational(
    access: &AccessControl,
    manager: &CollateralManager,
) {
    access_control::assert_not_paused(access);

    assert!(
        !manager.paused,
        E_MANAGER_PAUSED,
    );
}

public fun set_paused(
    _admin_cap: &CollateralManagerAdminCap,
    manager: &mut CollateralManager,
    paused: bool,
    ctx: &mut TxContext,
) {
    assert!(
        manager.paused != paused,
        E_STATE_UNCHANGED,
    );

    manager.paused = paused;

    event::emit(CollateralManagerPauseChanged {
        manager_id:
            object::uid_to_inner(&manager.id),

        paused,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun set_version(
    _admin_cap: &CollateralManagerAdminCap,
    manager: &mut CollateralManager,
    new_version: u64,
    ctx: &mut TxContext,
) {
    let previous_version =
        manager.version;

    assert!(
        previous_version != new_version,
        E_VERSION_UNCHANGED,
    );

    manager.version =
        new_version;

    event::emit(CollateralManagerVersionChanged {
        manager_id:
            object::uid_to_inner(&manager.id),

        previous_version,

        new_version,

        changed_by:
            tx_context::sender(ctx),
    });
}

public fun assert_accounting_invariant(
    manager: &CollateralManager,
) {
    let policy_count =
        vector::length(
            &manager.policies,
        );

    let mut policy_collateral_total = 0;
    let mut policy_debt_total = 0;
    let mut i = 0;

    while (i < policy_count) {
        let policy =
            vector::borrow(
                &manager.policies,
                i,
            );

        policy_collateral_total =
            policy_collateral_total
                + policy.total_collateral_units;

        policy_debt_total =
            policy_debt_total
                + policy.total_debt_value;

        i = i + 1;
    };

    assert!(
        policy_collateral_total
            == manager.total_collateral_units,
        E_ACCOUNTING_INVARIANT,
    );

    assert!(
        policy_debt_total
            == manager.total_debt_value,
        E_ACCOUNTING_INVARIANT,
    );
}

public fun set_position_debt_value_with_quote(
    admin_cap: &CollateralManagerAdminCap,
    access: &AccessControl,
    manager: &mut CollateralManager,
    position_id: u64,
    new_debt_value: u64,
    quote: &PriceQuote,
    ctx: &mut TxContext,
) {
    assert_quote_matches_policy(
        manager,
        position_id,
        quote,
    );

    let price =
        validated_quote_price(
            quote,
        );

    assert_debt_within_capacity(
        manager,
        position_id,
        price,
        new_debt_value,
    );

    set_position_debt_value(
        admin_cap,
        access,
        manager,
        position_id,
        new_debt_value,
        ctx,
    );
}

public fun borrow_capacity_after_withdrawal(
    manager: &CollateralManager,
    position_id: u64,
    withdraw_amount: u64,
    price: u64,
): u64 {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    assert!(
        position.collateral_units
            >= withdraw_amount,
        E_WITHDRAW_ABOVE_COLLATERAL,
    );

    let policy_index =
        find_policy_index(
            manager,
            position.policy_id,
        );

    let policy =
        vector::borrow(
            &manager.policies,
            policy_index,
        );

    let remaining_units =
        position.collateral_units
            - withdraw_amount;

    let remaining_value =
        collateral_value_from_price(
            remaining_units,
            policy.asset_decimals,
            price,
        );

    borrow_capacity_from_value(
        remaining_value,
        policy.max_ltv_bps,
    )
}

public fun assert_withdrawal_safe(
    manager: &CollateralManager,
    position_id: u64,
    withdraw_amount: u64,
    price: u64,
) {
    let position_index =
        find_position_index(
            manager,
            position_id,
        );

    let position =
        vector::borrow(
            &manager.positions,
            position_index,
        );

    let capacity_after =
        borrow_capacity_after_withdrawal(
            manager,
            position_id,
            withdraw_amount,
            price,
        );

    assert!(
        position.debt_value
            <= capacity_after,
        E_UNSAFE_WITHDRAWAL,
    );
}

public fun withdraw_collateral_with_quote(
    access: &AccessControl,
    manager: &mut CollateralManager,
    position_id: u64,
    amount: u64,
    quote: &PriceQuote,
    ctx: &mut TxContext,
) {
    assert_quote_matches_policy(
        manager,
        position_id,
        quote,
    );

    let price =
        validated_quote_price(
            quote,
        );

    assert_withdrawal_safe(
        manager,
        position_id,
        amount,
        price,
    );

    withdraw_collateral(
        access,
        manager,
        position_id,
        amount,
        ctx,
    );
}

public fun manager_id(
    manager: &CollateralManager,
): ID {
    object::uid_to_inner(&manager.id)
}

public fun version(
    manager: &CollateralManager,
): u64 {
    manager.version
}

public fun is_paused(
    manager: &CollateralManager,
): bool {
    manager.paused
}

public fun policy_count(
    manager: &CollateralManager,
): u64 {
    vector::length(&manager.policies)
}

public fun position_count(
    manager: &CollateralManager,
): u64 {
    vector::length(&manager.positions)
}

public fun total_collateral_units(
    manager: &CollateralManager,
): u64 {
    manager.total_collateral_units
}

public fun total_debt_value(
    manager: &CollateralManager,
): u64 {
    manager.total_debt_value
}

public fun active_position_count(
    manager: &CollateralManager,
): u64 {
    manager.active_position_count
}

public fun policy_is_active(
    manager: &CollateralManager,
    policy_id: u64,
): bool {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    vector::borrow(
        &manager.policies,
        index,
    ).active
}

public fun policy_collateral_type(
    manager: &CollateralManager,
    policy_id: u64,
): u8 {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    vector::borrow(
        &manager.policies,
        index,
    ).collateral_type
}

public fun policy_oracle_feed_id(
    manager: &CollateralManager,
    policy_id: u64,
): u64 {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    vector::borrow(
        &manager.policies,
        index,
    ).oracle_feed_id
}

public fun policy_max_ltv_bps(
    manager: &CollateralManager,
    policy_id: u64,
): u64 {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    vector::borrow(
        &manager.policies,
        index,
    ).max_ltv_bps
}

public fun policy_liquidation_threshold_bps(
    manager: &CollateralManager,
    policy_id: u64,
): u64 {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    vector::borrow(
        &manager.policies,
        index,
    ).liquidation_threshold_bps
}

public fun policy_liquidation_bonus_bps(
    manager: &CollateralManager,
    policy_id: u64,
): u64 {
    let index =
        find_policy_index(
            manager,
            policy_id,
        );

    vector::borrow(
        &manager.policies,
        index,
    ).liquidation_bonus_bps
}

public fun position_owner(
    manager: &CollateralManager,
    position_id: u64,
): address {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).owner
}

public fun position_policy_id(
    manager: &CollateralManager,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).policy_id
}

public fun position_collateral_units(
    manager: &CollateralManager,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).collateral_units
}

public fun position_debt_value(
    manager: &CollateralManager,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).debt_value
}

public fun position_is_active(
    manager: &CollateralManager,
    position_id: u64,
): bool {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).active
}

public fun position_created_epoch(
    manager: &CollateralManager,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).created_epoch
}

public fun position_updated_epoch(
    manager: &CollateralManager,
    position_id: u64,
): u64 {
    let index =
        find_position_index(
            manager,
            position_id,
        );

    vector::borrow(
        &manager.positions,
        index,
    ).updated_epoch
}

#[test_only]
public fun new_admin_cap_for_testing(
    ctx: &mut TxContext,
): CollateralManagerAdminCap {
    CollateralManagerAdminCap {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): CollateralManager {
    CollateralManager {
        id: object::new(ctx),

        version: 1,
        paused: false,

        policies:
            vector[],

        positions:
            vector[],

        next_policy_id: 1,
        next_position_id: 1,

        total_collateral_units: 0,
        total_debt_value: 0,

        active_position_count: 0,
    }
}

#[test_only]
public fun destroy_admin_cap_for_testing(
    cap: CollateralManagerAdminCap,
) {
    let CollateralManagerAdminCap { id } =
        cap;

    object::delete(id);
}

#[test_only]
public fun destroy_for_testing(
    manager: CollateralManager,
) {
    let CollateralManager {
        id,
        version: _,
        paused: _,
        mut policies,
        mut positions,
        next_policy_id: _,
        next_position_id: _,
        total_collateral_units: _,
        total_debt_value: _,
        active_position_count: _,
    } = manager;

    while (!vector::is_empty(&positions)) {
        let CollateralPosition {
            position_id: _,
            policy_id: _,
            owner: _,
            collateral_units: _,
            debt_value: _,
            active: _,
            created_epoch: _,
            updated_epoch: _,
        } = vector::pop_back(
            &mut positions,
        );
    };

    vector::destroy_empty(positions);

    while (!vector::is_empty(&policies)) {
        let CollateralAssetPolicy {
            policy_id: _,
            collateral_type: _,
            asset_key: _,
            oracle_symbol: _,
            oracle_feed_id: _,
            asset_decimals: _,
            max_ltv_bps: _,
            liquidation_threshold_bps: _,
            liquidation_bonus_bps: _,
            active: _,
            total_collateral_units: _,
            total_debt_value: _,
            position_count: _,
        } = vector::pop_back(
            &mut policies,
        );
    };

    vector::destroy_empty(policies);

    object::delete(id);
}
