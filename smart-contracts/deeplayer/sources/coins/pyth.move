// SPDX-License-Identifier: MIT
module deeplayer::pyth {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct PYTH has drop {}

    public struct Faucet<phantom PYTH> has key {
        id: UID,
        balance: Balance<PYTH>
    }

    fun init(
        witness: PYTH,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"PYTH", 
            b"Pyth Network", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<PYTH>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<PYTH>(
        treasury_cap: &mut TreasuryCap<PYTH>,
        faucet: &mut Faucet<PYTH>, 
        ctx: &mut TxContext,
    ) {
        let coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        balance::join<PYTH>(&mut faucet.balance, coin_minted.into_balance<PYTH>());
    }

    public entry fun mint<PYTH>(
        faucet: &mut Faucet<PYTH>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<PYTH>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }
}