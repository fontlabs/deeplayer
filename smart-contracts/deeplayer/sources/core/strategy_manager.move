// SPDX-License-Identifier: MIT
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

    use deeplayer::utils_module;
    use deeplayer::deeplayer_module::{DeepLayerCap};
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};

    // Constants
    const MAX_STAKER_STRATEGY_LIST_LENGTH: u64 = 32;
    const DEFAULT_BURN_ADDRESS: address = @0x0;

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
        total_shares: table::Table<string::String, u64>,
        burnable_shares: table::Table<string::String, u64>,
        staker_shares: table::Table<address, table::Table<string::String, u64>>,
        nonces: table::Table<address, u64>,
    }

    // Events
    public struct StrategyAddedToDepositWhitelist has copy, drop {
        strategy_id: string::String,
    }

    public struct StrategyRemovedFromDepositWhitelist has copy, drop {
        strategy_id: string::String,
    }

    public struct BurnableSharesDecreased has copy, drop {
        strategy_id: string::String,
        shares_burned: u64,
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
            total_shares: table::new<string::String, u64>(ctx),
            burnable_shares: table::new<string::String, u64>(ctx),
            staker_shares: table::new<address, table::Table<string::String, u64>>(ctx),
            nonces: table::new<address, u64>(ctx),
        };

        transfer::share_object(strategy_manager);
    } 

    // Package functions
    public(package) fun deposit<CoinType>(   
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ): (u64, u64) {
        check_not_paused(strategy_manager);

        let strategy_id = utils_module::get_strategy_id<CoinType>();

        let prior_total_shares = if (table::contains(&strategy_manager.total_shares, strategy_id)) {
            *table::borrow(&strategy_manager.total_shares, strategy_id)
        } else {
            0
        };

        let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);

        let new_shares = strategy_module::deposit<CoinType>(
            strategy, 
            prior_total_shares,
            coin_deposited,
            ctx
        );

        let staker = tx_context::sender(ctx);

        event::emit(Deposit {
            staker,
            strategy_id,
            shares: new_shares,
        });

        increase_total_shares(strategy_manager, strategy_id, new_shares);

        add_deposit_shares(
            strategy_manager,
            strategy_id,
            staker, 
            new_shares,
            ctx
        )
    }

    public entry fun burn_shares<CoinType>(
        cap: &DeepLayerCap,
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        ctx: &mut TxContext
    ) {        
        let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);
        let strategy_id = utils_module::get_strategy_id<CoinType>();

        let shares_burned = burn_shares_impl(strategy_manager, strategy_id);

        event::emit(BurnableSharesDecreased {
            strategy_id,
            shares_burned,
        });

        let prior_total_shares = if (table::contains(&strategy_manager.total_shares, strategy_id)) {
            *table::borrow(&strategy_manager.total_shares, strategy_id)
        } else {
            0
        };


        if (shares_burned != 0) {
            strategy_module::withdraw(
                strategy,
                DEFAULT_BURN_ADDRESS, 
                prior_total_shares,
                (prior_total_shares - shares_burned),
                shares_burned,
                ctx
            );
        }
    }

    // Package functions
    public(package) fun withdraw_shares_as_coins<CoinType>(
        strategy: &mut Strategy<CoinType>,
        strategy_manager: &mut StrategyManager,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        let strategy_id = utils_module::get_strategy_id<CoinType>();

        let prior_total_shares = get_total_shares(strategy_manager, strategy_id);
        let total_shares = decrease_total_shares(strategy_manager, strategy_id, shares);

        strategy_module::withdraw<CoinType>(
            strategy,
            staker, 
            prior_total_shares,
            total_shares,
            shares, 
            ctx
        );
    }

    public(package) fun increase_burnable_shares<CoinType>(
        strategy_manager: &mut StrategyManager,
        strategy: &mut Strategy<CoinType>,
        added_shares_to_burn: u64
    ) {
        let strategy_id = utils_module::get_strategy_id<CoinType>();
        
        increase_burnable_shares_impl(strategy_manager, strategy_id, added_shares_to_burn);

        event::emit(BurnableSharesIncreased {
            strategy_id,
            added_shares_to_burn,
        });
    }

    public(package) fun add_deposit_shares(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        assert!(staker != @0x0, E_STAKER_ADDRESS_ZERO);
        assert!(shares != 0, E_SHARES_AMOUNT_ZERO);

        // Deposit shares
        let prev_staker_shares = get_staker_shares(strategy_manager, strategy_id, staker);

        if (!table::contains(&strategy_manager.staker_shares, staker)) {
            table::add(&mut strategy_manager.staker_shares, staker, table::new<string::String, u64>(ctx));
        };
        let mut staker_shares = table::borrow_mut(&mut strategy_manager.staker_shares, staker);
        if (!table::contains(staker_shares, strategy_id)) {
            table::add(staker_shares, strategy_id, 0);
        };
        let mut staker_shares_in_strategy = table::borrow_mut(staker_shares, strategy_id);
        *staker_shares_in_strategy = *staker_shares_in_strategy + shares;

        // Strategy list
        if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
            table::add(&mut strategy_manager.staker_strategy_list, staker, vector::empty<string::String>());
        };
        let strategy_ids = table::borrow_mut(&mut strategy_manager.staker_strategy_list, staker);
        assert!(vector::length(strategy_ids) < MAX_STAKER_STRATEGY_LIST_LENGTH, E_MAX_STRATEGIES_EXCEEDED);
        vector::push_back(strategy_ids, strategy_id);

        (prev_staker_shares, shares)
    }

    public(package) fun remove_deposit_shares(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        staker: address,
        deposit_shares_to_remove: u64
    ): (bool, u64) {
        assert!(deposit_shares_to_remove != 0, E_SHARES_AMOUNT_ZERO);

        let mut staker_shares = table::borrow_mut(&mut strategy_manager.staker_shares, staker);
        let mut staker_shares_in_strategy = table::borrow_mut(staker_shares, strategy_id);
        *staker_shares_in_strategy = *staker_shares_in_strategy - deposit_shares_to_remove;

        let updated_staker_shares_in_strategy = get_staker_shares(strategy_manager, strategy_id, staker);

        if (updated_staker_shares_in_strategy == 0) {
            remove_strategy_from_staker_strategy_list(
                strategy_manager, 
                staker, 
                strategy_id
            );

            return (true, updated_staker_shares_in_strategy);
        };

        (false, updated_staker_shares_in_strategy)
    }

    public(package) fun increase_burnable_shares_impl(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        shares_to_burn: u64
    ) {
        let mut burnable_shares = table::borrow_mut(&mut strategy_manager.burnable_shares, strategy_id);
        *burnable_shares = *burnable_shares + shares_to_burn;
    }

    public(package) fun burn_shares_impl(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String
    ): u64 {
        let prev_burnable_shares = get_burnable_shares(strategy_manager, strategy_id);
        let mut burnable_shares = table::borrow_mut(&mut strategy_manager.burnable_shares, strategy_id);
        *burnable_shares = 0;
        prev_burnable_shares
    }

    public(package) fun burn_staker_shares(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        staker: address
    ): u64 {
        let staker_shares_in_strategy = get_staker_shares(strategy_manager, strategy_id, staker);
        
        increase_burnable_shares_impl(strategy_manager, strategy_id, staker_shares_in_strategy);

        let mut staker_shares = table::borrow_mut(&mut strategy_manager.staker_shares, staker);
        let mut staker_shares_burned = table::borrow_mut(staker_shares, strategy_id);
        *staker_shares_burned = 0;

        staker_shares_in_strategy
    }

    public(package) fun increase_total_shares(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        shares: u64
    ): u64 {
        if (!table::contains(&strategy_manager.total_shares, strategy_id)) {
            table::add(&mut strategy_manager.total_shares, strategy_id, 0);
        };
        let mut total_shares = table::borrow_mut(&mut strategy_manager.total_shares, strategy_id);
        *total_shares = *total_shares + shares;
        
        get_total_shares(strategy_manager, strategy_id)
    }

    public(package) fun decrease_total_shares(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        shares: u64
    ): u64 {
        let mut total_shares = table::borrow_mut(&mut strategy_manager.total_shares, strategy_id);
        *total_shares = *total_shares - shares;
        
        get_total_shares(strategy_manager, strategy_id)
    }

    // Internal functions
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
        
        let mut deposited_shares = vector::empty<u64>();

        let mut i = 0;
        let len = vector::length(strategy_ids);
        
        while (i < len) {
            let strategy_id = *vector::borrow(strategy_ids, i);
            let staker_shares_in_strategy = get_staker_shares(strategy_manager, strategy_id, staker);
            vector::push_back(&mut deposited_shares, staker_shares_in_strategy);
            i = i + 1;
        };

        (*strategy_ids, deposited_shares)
    }

    public fun get_staker_deposit_shares_as_underlying<CoinType>(
        strategy: &Strategy<CoinType>,
        strategy_manager: &StrategyManager,
        strategy_id: string::String,
        staker: address
    ): u64 {
        let staker_shares_in_strategy = get_staker_shares(strategy_manager, strategy_id, staker);
        let total_shares = get_total_shares(strategy_manager, strategy_id);
        strategy_module::shares_to_underlying(strategy, total_shares, staker_shares_in_strategy)
    }

    public fun get_staker_strategy_list(
        strategy_manager: &StrategyManager,
        staker: address
    ): vector<string::String> {
        if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
            return vector::empty<string::String>();
        };
        *table::borrow(&strategy_manager.staker_strategy_list, staker)
    }

    public fun get_total_shares(
        strategy_manager: &StrategyManager,
        strategy_id: string::String     
    ): u64 {
        let total_shares = if (table::contains(&strategy_manager.total_shares, strategy_id)) {
            *table::borrow(&strategy_manager.total_shares, strategy_id)
        } else {
            0
        };
        total_shares
    }

    public fun get_all_total_shares(
        strategy_manager: &StrategyManager,
        strategy_ids: vector<string::String>     
    ): vector<u64> {
        let mut shares = vector::empty<u64>();
        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let total_shares = get_total_shares(strategy_manager, strategy_id);
            vector::push_back(&mut shares, total_shares);
            i = i + 1;
        };
        shares
    }

    public fun get_staker_shares(
        strategy_manager: &StrategyManager,
        strategy_id: string::String,
        staker: address
    ): u64 {
        let staker_shares_in_strategy = if (table::contains(&strategy_manager.staker_shares, staker)) {
            let staker_shares = table::borrow(&strategy_manager.staker_shares, staker);
            if (table::contains(staker_shares, strategy_id)) {
                *table::borrow(staker_shares, strategy_id)
            } else {
                0
            }
        } else {
            0
        };
        staker_shares_in_strategy
    }

    public fun get_all_staker_shares(
        strategy_manager: &StrategyManager,
        strategy_ids: vector<string::String>,
        staker: address
    ): vector<u64> {
        let mut shares = vector::empty<u64>();
        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let staker_shares_in_strategy = get_staker_shares(strategy_manager, strategy_id, staker);
            vector::push_back(&mut shares, staker_shares_in_strategy);
            i = i + 1;
        };
        shares
    }

    public fun get_burnable_shares(
        strategy_manager: &StrategyManager,
        strategy_id: string::String
    ): u64 {
        if (!table::contains(&strategy_manager.burnable_shares, strategy_id)) {
            return 0;
        };
        *table::borrow(&strategy_manager.burnable_shares, strategy_id)
    }

    // Modifier checks 
    fun check_not_paused(
        strategy_manager: &StrategyManager
    ) {
        assert!(!strategy_manager.is_paused, E_PAUSED);
    }
    
    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext,
    ) {
        init(ctx)
    }
}