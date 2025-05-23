// SPDX-License-Identifier: MIT
module deeplayer::afsui {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct AFSUI has drop {}

    public struct Faucet<phantom AFSUI> has key {
        id: UID,
        balance: Balance<AFSUI>
    }

    fun init(
        witness: AFSUI,
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"haSUI", 
            b"Haedal Staked SUI", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<AFSUI>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<AFSUI>(
        treasury_cap: &mut TreasuryCap<AFSUI>,
        faucet: &mut Faucet<AFSUI>, 
        ctx: &mut TxContext,
    ) {
        let coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        balance::join<AFSUI>(&mut faucet.balance, coin_minted.into_balance<AFSUI>());
    }

    public entry fun mint<AFSUI>(
        faucet: &mut Faucet<AFSUI>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<AFSUI>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }
}