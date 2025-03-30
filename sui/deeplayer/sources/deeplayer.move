// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::deeplayer_module {
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
