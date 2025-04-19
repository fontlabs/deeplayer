// SPDX-License-Identifier: MIT
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

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext
    ) {
        init(ctx);
    }
}
