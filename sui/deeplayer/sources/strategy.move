// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::strategy_module {
    use std::option;
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::table;
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::coin_utils_module;

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
    public struct Strategy<phantom CoinType> has store {
        total_shares: u64,       
        burnable_shares: u64,
        staker_shares: table::Table<address, u64>,
        balance_underlying: balance::Balance<CoinType>, 
        is_paused: bool
    }

    // Events
    public struct ExchangeRateEmitted has copy, drop {
        strategy_id: string::String,
        rate: u64,
    }

    // Public functions
    public(package) fun create<CoinType>(
        ctx: &mut TxContext
    ): Strategy<CoinType> {
        let strategy = Strategy {
            total_shares: 0,
            burnable_shares: 0,
            staker_shares: table::new<address, u64>(ctx),
            balance_underlying: balance::zero<CoinType>(),
            is_paused: false
        };       

        strategy
    }

    public(package) fun deposit<CoinType>(
        strategy: &mut Strategy<CoinType>,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ): u64 {
        check_not_paused(strategy);

        let amount = coin::value(&coin_deposited);

        balance::join<CoinType>(&mut strategy.balance_underlying, coin::into_balance(coin_deposited));

        let prior_total_shares = strategy.total_shares;
        let virtual_share_amount = prior_total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        let virtual_prior_coin_balance = virtual_coin_balance - amount;
        let new_shares = (amount * virtual_share_amount) / virtual_prior_coin_balance;

        assert!(new_shares != 0, E_NEW_SHARES_ZERO);

        strategy.total_shares = prior_total_shares + new_shares;
        assert!(strategy.total_shares <= MAX_TOTAL_SHARES, E_TOTAL_SHARES_EXCEEDS_MAX);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        emit_exchange_rate(strategy_id, virtual_coin_balance, strategy.total_shares + SHARES_OFFSET);

        let staker = tx_context::sender(ctx);
        if (!table::contains(&strategy.staker_shares, staker)) {
            table::add(&mut strategy.staker_shares, staker, 0);
        };
        let mut staker_shares = *table::borrow_mut(&mut strategy.staker_shares, staker);
        staker_shares = staker_shares + new_shares;

        new_shares
    }

    public(package) fun withdraw<CoinType>(
        strategy: &mut Strategy<CoinType>,
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

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        emit_exchange_rate(strategy_id, virtual_coin_balance - amount_to_send, strategy.total_shares + SHARES_OFFSET);

        let staker = tx_context::sender(ctx);
        let mut staker_shares = *table::borrow_mut(&mut strategy.staker_shares, staker);
        staker_shares = staker_shares - amount_shares;

        after_withdrawal(strategy, recipient, amount_to_send, ctx);
    }

    public(package) fun add_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        staker: address,
        shares: u64
    ): u64 {
        strategy.total_shares = strategy.total_shares + shares;
        if (!table::contains(&strategy.staker_shares, staker)) {
            table::add(&mut strategy.staker_shares, staker, 0);
        };
        let mut staker_shares = *table::borrow_mut(&mut strategy.staker_shares, staker);
        staker_shares = staker_shares + shares;
        staker_shares
    }

    public(package) fun remove_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        staker: address,
        shares: u64
    ): u64 {
        strategy.total_shares = strategy.total_shares - shares;
        let mut staker_shares = *table::borrow_mut(&mut strategy.staker_shares, staker);
        staker_shares = staker_shares - shares;
        staker_shares
    }

    public(package) fun increase_burnable_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        shares_to_burn: u64
    ) {
        strategy.burnable_shares = strategy.burnable_shares + shares_to_burn;
    }

    public(package) fun burn_shares<CoinType>(
        strategy: &mut Strategy<CoinType>
    ): u64 {
        let shares_burned = strategy.burnable_shares;
        strategy.burnable_shares = 0;
        shares_burned
    }

    // View functions
    public(package) fun total_shares<CoinType>(
        strategy: &Strategy<CoinType>
    ): u64 {
        strategy.total_shares
    }

    public(package) fun burnable_shares<CoinType>(
        strategy: &Strategy<CoinType>
    ): u64 {
        strategy.burnable_shares
    }

    public(package) fun staker_shares<CoinType>(
        strategy: &Strategy<CoinType>,
        staker: address
    ): u64 {
        *table::borrow(&strategy.staker_shares, staker)
    }

    public(package) fun shares_to_underlying<CoinType>(
        strategy: &Strategy<CoinType>,
        amount_shares: u64
    ): u64 {
        shares_to_underlying_impl(strategy, amount_shares)
    }

    public(package) fun underlying_to_shares<CoinType>(
        strategy: &Strategy<CoinType>,
        amount_underlying: u64
    ): u64 {
        let virtual_total_shares = strategy.total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        (amount_underlying * virtual_total_shares) / virtual_coin_balance
    }

    // Internal functions
    fun shares_to_underlying_impl<CoinType>(
        strategy: &Strategy<CoinType>,
        amount_shares: u64
    ): u64 {
        let virtual_total_shares = strategy.total_shares + SHARES_OFFSET;
        let virtual_coin_balance = balance::value(&strategy.balance_underlying) + BALANCE_OFFSET;
        (virtual_coin_balance * amount_shares) / virtual_total_shares
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
            rate: (WAD * virtual_coin_balance) / virtual_total_shares,
        });
    }

    // Modifier checks
    fun check_not_paused<CoinType>(
        strategy: &Strategy<CoinType>
    ) {
        assert!(!strategy.is_paused, E_PAUSED);
    }
}