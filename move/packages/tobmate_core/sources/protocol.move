module tobmate_core::protocol;

use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

/// Global shared configuration for the Tobmate protocol.
public struct ProtocolConfig has key, store {
    id: UID,
    version: u64,
    paused: bool,
}

/// Created once when the package is initially published.
fun init(ctx: &mut TxContext) {
    let config = ProtocolConfig {
        id: object::new(ctx),
        version: 1,
        paused: false,
    };

    transfer::share_object(config);
}

public fun version(config: &ProtocolConfig): u64 {
    config.version
}

public fun is_paused(config: &ProtocolConfig): bool {
    config.paused
}
