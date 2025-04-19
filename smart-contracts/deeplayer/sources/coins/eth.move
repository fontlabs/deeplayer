// SPDX-License-Identifier: MIT
module deeplayer::eth {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct ETH has drop {}

    public struct Faucet<phantom ETH> has key {
        id: UID,
        balance: Balance<ETH>
    }

    fun init(
        witness: ETH,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"suiETH", 
            b"SUI Ethereum", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<ETH>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<ETH>(
        treasury_cap: &mut TreasuryCap<ETH>,
        faucet: &mut Faucet<ETH>, 
        ctx: &mut TxContext,
    ) {
        let coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        balance::join<ETH>(&mut faucet.balance, coin_minted.into_balance<ETH>());
    }

    public entry fun mint<ETH>(
        faucet: &mut Faucet<ETH>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<ETH>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }
}