// SPDX-License-Identifier: MIT
module deeplayer::deeplayer {
    use sui::object::{Self, UID};    
    use sui::tx_context::{Self, TxContext};

    // Struct
    public struct DLCap has key {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let cap = DLCap { id: object::new(ctx) };

        transfer::transfer(cap, @deeplayer);
    }
}
