// SPDX-License-Identifier: MIT
module deeplayer::hasui {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct HASUI has drop {}

    public struct Faucet<phantom HASUI> has key {
        id: UID,
        balance: Balance<HASUI>
    }

    fun init(
        witness: HASUI,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"afSUI", 
            b"Aftermath SUI", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<HASUI>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<HASUI>(
        treasury_cap: &mut TreasuryCap<HASUI>,
        faucet: &mut Faucet<HASUI>, 
        ctx: &mut TxContext,
    ) {
        let coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        balance::join<HASUI>(&mut faucet.balance, coin_minted.into_balance<HASUI>());
    }

    public entry fun mint<HASUI>(
        faucet: &mut Faucet<HASUI>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<HASUI>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }
}