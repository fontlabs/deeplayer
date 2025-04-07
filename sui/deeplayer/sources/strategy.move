// SPDX-License-Identifier: MIT
module deeplayer::strategy_module {
    use std::option;
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::table;
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::math_module;
    use deeplayer::coin_utils_module;

    // Constants
    const WAD: u64 = 1_000_000_000;
    const SHARES_OFFSET: u64 = 1_000; 
    const BALANCE_OFFSET: u64 = 1_000; 
    const MAX_TOTAL_SHARES: u64 = 1_000_000_000_000_000_000;

    // Error codes
    const E_ONLY_STRATEGY_MANAGER: u64 = 1;
    const E_NEW_SHARES_ZERO: u64 = 2;
    const E_TOTAL_SHARES_EXCEEDS_MAX: u64 = 3;
    const E_WITHDRAWAL_AMOUNT_EXCEEDS_TOTAL: u64 = 4;
    const E_ONLY_UNDERLYING_COIN: u64 = 5;
    const E_PAUSED: u64 = 6;

    // Structs
    public struct Strategy<phantom CoinType> has store {
        balance_underlying: balance::Balance<CoinType>, 
        is_paused: bool
    }

    // Events
    public struct ExchangeRateEmitted has copy, drop {
        strategy_id: string::String,
        rate: u64,
    }

    // Package functions
    public(package) fun create<CoinType>(
        ctx: &mut TxContext
    ): Strategy<CoinType> {
        Strategy {
            balance_underlying: balance::zero<CoinType>(),
            is_paused: false
        }
    }

    public(package) fun deposit<CoinType>(
        strategy: &mut Strategy<CoinType>,
        prior_total_shares: u64,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ): u64 {
        check_not_paused(strategy);

        let amount = coin::value(&coin_deposited);

        balance::join<CoinType>(&mut strategy.balance_underlying, coin::into_balance(coin_deposited));

        let virtual_share_amount = prior_total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        let virtual_prior_coin_balance = virtual_coin_balance - amount;
        let new_shares = math_module::mul_div(virtual_share_amount, amount, virtual_prior_coin_balance);

        assert!(new_shares != 0, E_NEW_SHARES_ZERO);

        let total_shares = prior_total_shares + new_shares;
        assert!(total_shares <= MAX_TOTAL_SHARES, E_TOTAL_SHARES_EXCEEDS_MAX);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        emit_exchange_rate(strategy_id, virtual_coin_balance, total_shares + SHARES_OFFSET);

        new_shares
    }

    public(package) fun withdraw<CoinType>(
        strategy: &mut Strategy<CoinType>,
        recipient: address,
        prior_total_shares: u64,
        total_shares: u64,
        amount_shares: u64,
        ctx: &mut TxContext
    ) {
        check_not_paused(strategy);

        assert!(amount_shares <= prior_total_shares, E_WITHDRAWAL_AMOUNT_EXCEEDS_TOTAL);

        let virtual_prior_total_shares = prior_total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        let amount_to_send = math_module::mul_div(virtual_coin_balance, amount_shares, virtual_prior_total_shares);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        emit_exchange_rate(strategy_id, virtual_coin_balance - amount_to_send, total_shares + SHARES_OFFSET);

        after_withdrawal(strategy, recipient, amount_to_send, ctx);
    }

    public(package) fun shares_to_underlying<CoinType>(
        strategy: &Strategy<CoinType>,
        total_shares: u64,
        amount_shares: u64
    ): u64 {
        shares_to_underlying_impl(strategy, total_shares, amount_shares)
    }

    public(package) fun underlying_to_shares<CoinType>(
        strategy: &Strategy<CoinType>,
        total_shares: u64,
        amount_underlying: u64
    ): u64 {
        let virtual_total_shares = total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        math_module::mul_div(amount_underlying, virtual_total_shares, virtual_coin_balance)
    }

    // Internal functions
    fun shares_to_underlying_impl<CoinType>(
        strategy: &Strategy<CoinType>,
        total_shares: u64,
        amount_shares: u64
    ): u64 {
        let virtual_total_shares = total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        math_module::mul_div(virtual_coin_balance, amount_shares, virtual_total_shares)
    }

    fun after_withdrawal<CoinType>(
        strategy: &mut Strategy<CoinType>,
        recipient: address,
        amount_to_send: u64,
        ctx: &mut TxContext
    ) {
        let balance_sent = balance::split(&mut strategy.balance_underlying, amount_to_send);
        let coin_sent = coin::from_balance(balance_sent, ctx);
        transfer::public_transfer(coin_sent, recipient);
    }

    fun emit_exchange_rate(
        strategy_id: string::String,
        virtual_coin_balance: u64,
        virtual_total_shares: u64
    ) {
        event::emit(ExchangeRateEmitted {
            strategy_id,
            rate: math_module::mul_div(WAD, virtual_coin_balance, virtual_total_shares)
        });
    }

    // Modifier checks
    fun check_not_paused<CoinType>(
        strategy: &Strategy<CoinType>
    ) {
        assert!(!strategy.is_paused, E_PAUSED);
    }
}