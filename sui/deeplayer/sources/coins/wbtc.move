// SPDX-License-Identifier: MIT
module deeplayer::wbtc {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct WBTC has drop {}

    public struct Faucet<phantom WBTC> has key {
        id: UID,
        balance: Balance<WBTC>
    }

    fun init(
        witness: WBTC,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"WBTC", 
            b"Wrapped BTC", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<WBTC>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<WBTC>(
        treasury_cap: &mut TreasuryCap<WBTC>,
        faucet: &mut Faucet<WBTC>, 
        ctx: &mut TxContext,
    ) {
        let coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        balance::join<WBTC>(&mut faucet.balance, coin_minted.into_balance<WBTC>());
    }

    public entry fun mint<WBTC>(
        faucet: &mut Faucet<WBTC>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<WBTC>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }
}