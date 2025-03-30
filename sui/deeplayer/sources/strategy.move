// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::strategy_module {
    use std::option;
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::strategy_manager_module::{Self, StrategyManager};

    // Constants
    const WAD: u64 = 1_000_000_000;
    const SHARES_OFFSET: u64 = 1_000; 
    const BALANCE_OFFSET: u64 = 1_000; 
    const MAX_TOTAL_SHARES: u64 = 1_000_000_000_000_000_000 - 1;

    // Error codes
    const E_ONLY_STRATEGY_MANAGER: u64 = 1;
    const E_NEW_SHARES_ZERO: u64 = 2;
    const E_TOTAL_SHARES_EXCEEDS_MAX: u64 = 3;
    const E_WITHDRAWAL_AMOUNT_EXCEEDS_TOTAL: u64 = 4;
    const E_ONLY_UNDERLYING_COIN: u64 = 5;
    const E_PAUSED: u64 = 6;

    // Structs
    public struct Strategy<phantom COIN> has key, store {
        id: UID,
        total_shares: u64,
        balance_underlying: balance::Balance<COIN>, 
        is_paused: bool
    }

    // Events
    public struct ExchangeRateEmitted has copy, drop {
        rate: u64,
    }

    // Public functions
    public(package) fun create<COIN>(
        ctx: &mut TxContext
    ): (Strategy<COIN>, address) {
        let id = object::new(ctx);

        let strategy = Strategy {
            id,
            total_shares: 0,
            balance_underlying: balance::zero<COIN>(),
            is_paused: false
        };       

        transfer::share_object(strategy);

        (strategy, @0x0)
    }

    public(package) fun deposit<COIN>(
        strategy: &mut Strategy<COIN>,
        coin_deposited: coin::Coin<COIN>,
        ctx: &mut TxContext
    ): u64 {
        check_not_paused(strategy);

        let amount = coin::value(&coin_deposited);

        balance::join<COIN>(&mut strategy.balance_underlying, coin::into_balance(coin_deposited));

        let prior_total_shares = strategy.total_shares;
        let virtual_share_amount = prior_total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        let virtual_prior_coin_balance = virtual_coin_balance - amount;
        let new_shares = (amount * virtual_share_amount) / virtual_prior_coin_balance;

        assert!(new_shares != 0, E_NEW_SHARES_ZERO);

        strategy.total_shares = prior_total_shares + new_shares;
        assert!(strategy.total_shares <= MAX_TOTAL_SHARES, E_TOTAL_SHARES_EXCEEDS_MAX);

        emit_exchange_rate(strategy, virtual_coin_balance, strategy.total_shares + SHARES_OFFSET);

        new_shares
    }

    public(package) fun withdraw<COIN>(
        strategy: &mut Strategy<COIN>,
        recipient: address,
        amount_shares: u64,
        ctx: &mut TxContext
    ) {
        check_not_paused(strategy);

        let prior_total_shares = strategy.total_shares;
        assert!(amount_shares <= prior_total_shares, E_WITHDRAWAL_AMOUNT_EXCEEDS_TOTAL);

        let virtual_prior_total_shares = prior_total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        let amount_to_send = (virtual_coin_balance * amount_shares) / virtual_prior_total_shares;

        strategy.total_shares = prior_total_shares - amount_shares;

        emit_exchange_rate(strategy, virtual_coin_balance - amount_to_send, strategy.total_shares + SHARES_OFFSET);
        after_withdrawal(strategy, recipient, amount_to_send, ctx);
    }

    // View functions
    public fun shares_to_underlying<COIN>(
        strategy: &Strategy<COIN>,
        amount_shares: u64
    ): u64 {
        shares_to_underlying_impl(strategy, amount_shares)
    }

    public fun underlying_to_shares<COIN>(
        strategy: &Strategy<COIN>,
        amount_underlying: u64
    ): u64 {
        let virtual_total_shares = strategy.total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        (amount_underlying * virtual_total_shares) / virtual_coin_balance
    }

    public fun user_underlying_view<COIN>(        
        strategy_manager: &StrategyManager,
        strategy: &Strategy<COIN>,
        user: address
    ): u64 {
        shares_to_underlying_impl(strategy, shares(strategy_manager, strategy, user))
    }

    public fun user_underlying<COIN>(
        strategy_manager: &StrategyManager,
        strategy: &Strategy<COIN>,
        user: address
    ): u64 {
        shares_to_underlying(strategy, shares(strategy_manager, strategy, user))
    }

    public fun shares<COIN>(
        strategy_manager: &StrategyManager,
        strategy: &Strategy<COIN>,
        user: address
    ): u64 {       
        let strategy_address = object::id_to_address(&object::id(strategy));
        strategy_manager_module::staker_deposit_shares(
            strategy_manager, 
            user, 
            strategy_address
        )
    }

    // Internal functions
    fun shares_to_underlying_impl<COIN>(
        strategy: &Strategy<COIN>,
        amount_shares: u64
    ): u64 {
        let virtual_total_shares = strategy.total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        (virtual_coin_balance * amount_shares) / virtual_total_shares
    }

    fun after_withdrawal<COIN>(
        strategy: &mut Strategy<COIN>,
        recipient: address,
        amount_to_send: u64,
        ctx: &mut TxContext
    ) {
        let balance_sent = balance::split(&mut strategy.balance_underlying, amount_to_send);
        let coin_sent = coin::from_balance(balance_sent, ctx);
        transfer::public_transfer(coin_sent, recipient);
    }

    fun emit_exchange_rate<COIN>(
        strategy: &Strategy<COIN>,
        virtual_coin_balance: u64,
        virtual_total_shares: u64
    ) {
        event::emit(ExchangeRateEmitted {
            rate: (WAD * virtual_coin_balance) / virtual_total_shares,
        });
    }

    // Modifier checks
    fun check_not_paused<COIN>(
        strategy: &Strategy<COIN>
    ) {
        assert!(!strategy.is_paused, E_PAUSED);
    }
}