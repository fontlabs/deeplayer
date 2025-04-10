// SPDX-License-Identifier: MIT
module deeplayer::lbtc {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct LBTC has drop {}

    public struct Faucet<phantom LBTC> has key {
        id: UID,
        balance: Balance<LBTC>
    }

    fun init(
        witness: LBTC,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"LBTC", 
            b"Liquid Bitcoin", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<LBTC>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<LBTC>(
        treasury_cap: &mut TreasuryCap<LBTC>,
        faucet: &mut Faucet<LBTC>, 
        ctx: &mut TxContext,
    ) {
        let coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        balance::join<LBTC>(&mut faucet.balance, coin_minted.into_balance<LBTC>());
    }

    public entry fun mint<LBTC>(
        faucet: &mut Faucet<LBTC>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<LBTC>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }

    public fun get_faucet_balance(
        faucet: &Faucet<LBTC>,
    ): u64 {
        balance::value(&faucet.balance)
    }

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext,
    ) {
        init(LBTC {}, ctx);
    }    
}