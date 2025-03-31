// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::deeplayer_module {
    use sui::transfer;
    use sui::object::{Self, UID};    
    use sui::tx_context::{Self, TxContext};

    // Struct
    public struct DeepLayerCap has key {
        id: UID
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let cap = DeepLayerCap { 
            id: object::new(ctx) 
        };

        transfer::transfer(cap, tx_context::sender(ctx));
    }
}
