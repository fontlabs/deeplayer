// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::strategy_manager_module {
    use std::option;
    use std::string;
    use std::vector;
    use sui::balance;
    use sui::coin;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::table;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::coin_utils_module;
    use deeplayer::strategy_module::{Self, Strategy};

    // Constants
    const MAX_STAKER_STRATEGY_LIST_LENGTH: u64 = 32;

    // Error codes
    const E_STRATEGY_NOT_WHITELISTED: u64 = 2;
    const E_PAUSED: u64 = 3;
    const E_STAKER_ADDRESS_ZERO: u64 = 4;
    const E_SHARES_AMOUNT_ZERO: u64 = 5;
    const E_MAX_STRATEGIES_EXCEEDED: u64 = 6;
    const E_SHARES_AMOUNT_TOO_HIGH: u64 = 7;
    const E_STRATEGY_NOT_FOUND: u64 = 8;

    // Structs
    public struct StrategyManager has key {
        id: UID,
        is_paused: bool,
        staker_strategy_list: table::Table<address, vector<string::String>>,
        nonces: table::Table<address, u64>,
    }

    // Events
    public struct StrategyAddedToDepositWhitelist has copy, drop {
        strategy_id: string::String,
    }

    public struct StrategyRemovedFromDepositWhitelist has copy, drop {
        strategy_id: string::String,
    }

    public struct Deposit has copy, drop {
        staker: address,
        strategy_id: string::String,
        shares: u64,
    }

    public struct BurnableSharesIncreased has copy, drop {
        strategy_id: string::String,
        added_shares_to_burn: u64,
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let strategy_manager = StrategyManager {
            id: object::new(ctx),
            is_paused: false,
            staker_strategy_list: table::new<address, vector<string::String>>(ctx),
            nonces: table::new<address, u64>(ctx),
        };

        transfer::share_object(strategy_manager);
    } 

    // Public functions
    public(package) fun deposit_into_strategy<CoinType>(   
        strategy: &mut Strategy<CoinType>,
        strategy_manager: &mut StrategyManager,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ): (address, string::String, u64, u64) {
        check_not_paused(strategy_manager);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        let shares = strategy_module::deposit<CoinType>(
            strategy, 
            coin_deposited,
            ctx
        );

        let staker = tx_context::sender(ctx);
        let (prev_deposit_shares, added_shares) = add_shares_impl<CoinType>(
            strategy,
            strategy_manager,
            staker, 
            shares,
            ctx
        );

        (staker, strategy_id, prev_deposit_shares, added_shares)
    }

    public(package) fun add_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        strategy_manager: &mut StrategyManager,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        add_shares_impl(
            strategy,
            strategy_manager, 
            staker, 
            shares,
            ctx
        )
    }

    public(package) fun withdraw_shares_as_coins<CoinType>(
        strategy: &mut Strategy<CoinType>,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        strategy_module::withdraw<CoinType>(
            strategy,
            staker, 
            shares, 
            ctx
        );
    }

    public(package) fun increase_burnable_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        added_shares_to_burn: u64
    ) {
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        strategy_module::increase_burnable_shares(strategy, added_shares_to_burn);

        event::emit(BurnableSharesIncreased {
            strategy_id,
            added_shares_to_burn,
        });
    }

    // Internal functions
    fun add_shares_impl<CoinType>(
        strategy: &mut Strategy<CoinType>,
        strategy_manager: &mut StrategyManager,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        assert!(staker != @0x0, E_STAKER_ADDRESS_ZERO);
        assert!(shares != 0, E_SHARES_AMOUNT_ZERO);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        // Deposit shares
        let prev_staker_shares = strategy_module::staker_shares(strategy, staker);
        strategy_module::add_shares(strategy, staker, shares);

        // Strategy list
        if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
            table::add(&mut strategy_manager.staker_strategy_list, staker, vector::empty<string::String>());
        };
        let strategy_ids = table::borrow_mut(&mut strategy_manager.staker_strategy_list, staker);
        assert!(vector::length(strategy_ids) < MAX_STAKER_STRATEGY_LIST_LENGTH, E_MAX_STRATEGIES_EXCEEDED);
        vector::push_back(strategy_ids, strategy_id);

        event::emit(Deposit {
            staker,
            strategy_id,
            shares,
        });

        (prev_staker_shares, shares)
    }

    public(package) fun remove_deposit_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        strategy_manager: &mut StrategyManager,
        staker: address,
        deposit_shares_to_remove: u64
    ): (bool, u64) {
        assert!(deposit_shares_to_remove != 0, E_SHARES_AMOUNT_ZERO);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        let shares_after = strategy_module::remove_shares(strategy, staker, deposit_shares_to_remove);

        if (shares_after == 0) {
            remove_strategy_from_staker_strategy_list(
                strategy_manager, 
                staker, 
                strategy_id
            );

            return (true, shares_after);
        };

        (false, shares_after)
    }

    fun remove_strategy_from_staker_strategy_list(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy_id: string::String
    ) {
        assert!(table::contains(&strategy_manager.staker_strategy_list, staker), E_STRATEGY_NOT_FOUND);
        let strategy_ids = table::borrow_mut(&mut strategy_manager.staker_strategy_list, staker);
        
        let mut i = 0;
        let len = vector::length(strategy_ids);
        while (i < len) {
            if (*vector::borrow(strategy_ids, i) == strategy_id) {
                vector::swap_remove(strategy_ids, i);
                return;
            };
            i = i + 1;
        };
        assert!(false, E_STRATEGY_NOT_FOUND);
    }

    // View functions
    public fun get_deposits(
        strategy_manager: &StrategyManager,
        staker: address
    ): (vector<string::String>, vector<u64>) {
        if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
            return (vector::empty<string::String>(), vector::empty<u64>());
        };
        
        let strategy_ids = table::borrow(&strategy_manager.staker_strategy_list, staker);
        let len = vector::length(strategy_ids);
        let mut deposited_shares = vector::empty<u64>();
        
        let mut i = 0;
        while (i < len) {
            // let strategy_id = *vector::borrow(strategy_ids, i);
            // let shares = strategy_module::staker_shares_with_id(strategy_id, staker);            
            // vector::push_back(&mut deposited_shares, shares);
            i = i + 1;
        };

        (*strategy_ids, deposited_shares)
    }

    public fun get_staker_strategy_list(
        strategy_manager: &StrategyManager,
        staker: address
    ): vector<string::String> {
        *table::borrow(&strategy_manager.staker_strategy_list, staker)
    }

    // Modifier checks 
    fun check_not_paused(
        strategy_manager: &StrategyManager
    ) {
        assert!(!strategy_manager.is_paused, E_PAUSED);
    }
}