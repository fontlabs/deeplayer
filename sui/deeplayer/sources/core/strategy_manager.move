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

    use deeplayer::coin_utils_module;
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
        strategy_is_whitelisted: table::Table<string::String, bool>,
        staker_deposit_shares: table::Table<address, table::Table<string::String, u64>>,
        staker_strategy_list: table::Table<address, vector<string::String>>,
        burnable_shares: table::Table<string::String, u64>,
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

    public struct BurnableSharesDecreased has copy, drop {
        strategy_id: string::String,
        shares_burned: u64,
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let strategy_manager = StrategyManager {
            id: object::new(ctx),
            is_paused: false,
            strategy_is_whitelisted: table::new<string::String, bool>(ctx),
            staker_deposit_shares: table::new<address, table::Table<string::String, u64>>(ctx),
            staker_strategy_list: table::new<address, vector<string::String>>(ctx),
            burnable_shares: table::new<string::String, u64>(ctx),
            nonces: table::new<address, u64>(ctx),
        };

        transfer::share_object(strategy_manager);
    }

    // Public functions
    public(package) fun deposit_into_strategy<CoinType>(   
        strategy_manager: &mut StrategyManager,
        strategy: &mut Strategy<CoinType>,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ): (address, string::String, u64, u64) {
        check_not_paused(strategy_manager);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        check_strategy_whitelisted_for_deposit(strategy_manager, strategy_id);

        assert!(
            table::contains(&strategy_manager.strategy_is_whitelisted, strategy_id) &&
            *table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_id),
            E_STRATEGY_NOT_WHITELISTED
        );

        let shares = strategy_module::deposit<CoinType>(
            strategy, 
            coin_deposited,
            ctx
        );

        let staker = tx_context::sender(ctx);
        let (prev_deposit_shares, added_shares) = add_shares_impl(
            strategy_manager,
            staker, 
            strategy_id, 
            shares,
            ctx
        );

        (staker, strategy_id, prev_deposit_shares, added_shares)
    }
    
    public entry fun burn_shares<CoinType>(
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        ctx: &mut TxContext
    ) {        
        let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        let shares_to_burn = if (table::contains(&strategy_manager.burnable_shares, strategy_id)) {
            *table::borrow(&strategy_manager.burnable_shares, strategy_id)
        } else {
            0
        };

        table::remove(&mut strategy_manager.burnable_shares, strategy_id);

        event::emit(BurnableSharesDecreased {
            strategy_id,
            shares_burned: shares_to_burn,
        });

        if (shares_to_burn != 0) {
            strategy_module::withdraw(
                strategy,
                DEFAULT_BURN_ADDRESS, 
                shares_to_burn,
                ctx
            );
        }
    }

    public(package) fun add_shares(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy_id: string::String,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        add_shares_impl(
            strategy_manager, 
            staker, 
            strategy_id, 
            shares,
            ctx
        )
    }

    public(package) fun withdraw_shares_as_coins<CoinType>(
        strategy_factory: &mut StrategyFactory,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);
        strategy_module::withdraw<CoinType>(
            strategy,
            staker, 
            shares, 
            ctx
        );
    }

    public(package) fun increase_burnable_shares(
        strategy_manager: &mut StrategyManager,
        strategy_id: string::String,
        added_shares_to_burn: u64,
        ctx: &mut TxContext
    ) {
        let current_shares = if (table::contains(&strategy_manager.burnable_shares, strategy_id)) {
            *table::borrow(&strategy_manager.burnable_shares, strategy_id)
        } else {
            0
        };

        table::add(&mut strategy_manager.burnable_shares, strategy_id, current_shares + added_shares_to_burn);
      
        event::emit(BurnableSharesIncreased {
            strategy_id,
            added_shares_to_burn,
        });
    }

    public(package) fun add_strategies_to_deposit_whitelist(
        strategy_manager: &mut StrategyManager,
        strategies_to_whitelist: vector<string::String>,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        let len = vector::length(&strategies_to_whitelist);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategies_to_whitelist, i);
            if (!table::contains(&strategy_manager.strategy_is_whitelisted, strategy_id) || 
                !*table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_id)) {
                table::add(&mut strategy_manager.strategy_is_whitelisted, strategy_id, true);
                event::emit(StrategyAddedToDepositWhitelist { 
                    strategy_id 
                });
            };
            i = i + 1;
        };
    }

    public(package) fun remove_strategies_from_deposit_whitelist(
        strategy_manager: &mut StrategyManager,
        strategies_to_remove_from_whitelist: vector<string::String>,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        let len = vector::length(&strategies_to_remove_from_whitelist);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategies_to_remove_from_whitelist, i);
            if (table::contains(&strategy_manager.strategy_is_whitelisted, strategy_id) && 
                *table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_id)) {
                table::add(&mut strategy_manager.strategy_is_whitelisted, strategy_id, false);
                
                event::emit(StrategyRemovedFromDepositWhitelist { 
                    strategy_id 
                });
            };
            i = i + 1;
        };
    }

    // Internal functions
    fun add_shares_impl(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy_id: string::String,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        assert!(staker != @0x0, E_STAKER_ADDRESS_ZERO);
        assert!(shares != 0, E_SHARES_AMOUNT_ZERO);

        let prev_deposit_shares = if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
            table::contains(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_id)) {
            *table::borrow(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_id)
        } else {
            0
        };

        if (prev_deposit_shares == 0) {
            if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
                table::add(&mut strategy_manager.staker_strategy_list, staker, vector::empty<string::String>());
            };
            let strategy_ids = table::borrow_mut(&mut strategy_manager.staker_strategy_list, staker);
            
            assert!(vector::length(strategy_ids) < MAX_STAKER_STRATEGY_LIST_LENGTH, E_MAX_STRATEGIES_EXCEEDED);
            vector::push_back(strategy_ids, strategy_id);
        };

        // Update deposit shares
        if (!table::contains(&strategy_manager.staker_deposit_shares, staker)) {
            table::add(&mut strategy_manager.staker_deposit_shares, staker, table::new<string::String, u64>(ctx));
        };
        let staker_shares = table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker);
        table::add(staker_shares, strategy_id, prev_deposit_shares + shares);

        event::emit(Deposit {
            staker,
            strategy_id,
            shares,
        });

        (prev_deposit_shares, shares)
    }

    public(package) fun remove_deposit_shares(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy_id: string::String,
        deposit_shares_to_remove: u64
    ): (bool, u64) {
        assert!(deposit_shares_to_remove != 0, E_SHARES_AMOUNT_ZERO);

        let user_deposit_shares = if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
            table::contains(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_id)) {
            *table::borrow(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_id)
        } else {
            0
        };

        assert!(deposit_shares_to_remove <= user_deposit_shares, E_SHARES_AMOUNT_TOO_HIGH);
        let shares_after = user_deposit_shares - deposit_shares_to_remove;

        // Update shares
        let staker_shares = table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker);
        table::add(staker_shares, strategy_id, shares_after);

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
            let strategy_id = *vector::borrow(strategy_ids, i);
            let shares = if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
                table::contains(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy_id)) {
                *table::borrow(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy_id)
            } else {
                0
            };
            vector::push_back(&mut deposited_shares, shares);
            i = i + 1;
        };

        (*strategy_ids, deposited_shares)
    }

    public fun staker_deposit_shares(
        strategy_manager: &StrategyManager,
        staker: address,
        strategy_id: string::String
    ): u64 {
        if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
            table::contains(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy_id)) {
            *table::borrow(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy_id)
        } else {
            0
        }
    }

    public fun get_staker_strategy_list(
        strategy_manager: &StrategyManager,
        staker: address
    ): vector<string::String> {
        *table::borrow(&strategy_manager.staker_strategy_list, staker)
    }

    public fun get_burnable_shares(
        strategy_manager: &StrategyManager,
        strategy_id: string::String
    ): u64 {
        if (table::contains(&strategy_manager.burnable_shares, strategy_id)) {
            *table::borrow(&strategy_manager.burnable_shares, strategy_id)
        } else {
            0
        }
    }

    // Modifier checks
    fun check_strategy_whitelisted_for_deposit(
        strategy_manager: &StrategyManager,
        strategy_id: string::String
    ) {
        assert!(
            table::contains(&strategy_manager.strategy_is_whitelisted, strategy_id) &&
            *table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_id),
            E_STRATEGY_NOT_WHITELISTED
        );
    }

    fun check_not_paused(
        strategy_manager: &StrategyManager
    ) {
        assert!(!strategy_manager.is_paused, E_PAUSED);
    }
}