// SPDX-License-Identifier: MIT
module deeplayer::cert {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};

    public struct CERT has drop {}

    public struct Faucet<phantom CERT> has key {
        id: UID,
        balance: Balance<CERT>
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let (treasury, metadata) = coin::create_currency(
            CERT {}, 
            9, 
            b"vSUI", 
            b"Volo SUI", 
            b"", 
            option::none(), 
            ctx
        );

        let faucet = Faucet {
            id: object::new(ctx),
            balance: balance::zero<CERT>()
        };

        transfer::share_object(faucet);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun init_supply<CERT>(
        treasury_cap: &mut TreasuryCap<CERT>,
        faucet: &mut Faucet<CERT>, 
        ctx: &mut TxContext,
    ) {
        let mut coin_minted = coin::mint(treasury_cap, 1_000_000_000_000_000, ctx);
        let coin_faucet = coin_minted.split(50_000_000_000, ctx);

        let balance_faucet = coin_faucet.into_balance<CERT>();
        balance::join<CERT>(&mut faucet.balance, balance_faucet);

        transfer::public_transfer(coin_minted, tx_context::sender(ctx))
    }

    public entry fun mint<CERT>(
        faucet: &mut Faucet<CERT>,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let coin_took = coin::take<CERT>(&mut faucet.balance, amount, ctx);
        transfer::public_transfer(coin_took, receiver)
    }
}