// SPDX-License-Identifier: MIT
module deeplayer::strategy_factory_module {
    use std::option;
    use std::string;
    use sui::balance;
    use sui::coin;
    use sui::table;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::bag::{Self, Bag};
    use sui::tx_context::{Self, TxContext};

    use deeplayer::coin_utils_module;
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};

    // Error codes
    const E_BLACKLISTED_TOKEN: u64 = 1;
    const E_STRATEGY_ALREADY_EXISTS: u64 = 2;
    const E_ALREADY_BLACKLISTED: u64 = 3;
    const E_ONLY_OWNER: u64 = 4;
    const E_PAUSED: u64 = 5;

    // Structs
    public struct StrategyFactory has key {
        id: UID,
        deployed_strategies: Bag,
        is_blacklisted: table::Table<string::String, bool>,
        is_paused: bool
    }

    // Events
    public struct CoinBlacklisted has copy, drop {
        coin_type: string::String,
    }

    public struct StrategySetForCoin has copy, drop {
        coin_type: string::String,
        strategy_address: address,
    }

    // Initialization
    fun init(
        ctx: &mut TxContext
    ) {
        let strategy_factory = StrategyFactory {
            id: object::new(ctx),
            deployed_strategies: bag::new(ctx),
            is_blacklisted: table::new<string::String, bool>(ctx),
            is_paused: false
        };

        transfer::share_object(strategy_factory);
    }

    // Public functions
    public entry fun deploy_new_strategy<COIN>(
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        ctx: &mut TxContext
    ) {
        check_not_paused(strategy_factory);

        let coin_type = coin_utils_module::get_coin_type<COIN>();

        assert!(!table::contains(&strategy_factory.is_blacklisted, coin_type), E_BLACKLISTED_TOKEN);
        assert!(!bag::contains(&strategy_factory.deployed_strategies, coin_type), E_STRATEGY_ALREADY_EXISTS);

        let (strategy, strategy_address) = strategy_module::create<COIN>(ctx);
        bag::add(&mut strategy_factory.deployed_strategies, coin_type, strategy);

        event::emit(StrategySetForCoin { 
            coin_type, 
            strategy_address
        });

        // Whitelist the strategy
        let strategies_to_whitelist = vector[strategy_address];
        strategy_manager_module::add_strategies_to_deposit_whitelist(
            strategy_manager,
            strategies_to_whitelist, 
            ctx
        );
    }

    public entry fun blacklist_coins(
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        coin_types: vector<string::String>,
        ctx: &mut TxContext
    ) {
        let strategies_to_remove = vector::empty<address>();
        let mut i = 0;
        let len = vector::length(&coin_types);
        while (i < len) {
            let coin_type = *vector::borrow(&coin_types, i);
            assert!(!table::contains(&strategy_factory.is_blacklisted, coin_type), E_ALREADY_BLACKLISTED);
            
            table::add(&mut strategy_factory.is_blacklisted, coin_type, true);
          
            event::emit(CoinBlacklisted { 
                coin_type
            });

            if (bag::contains(&strategy_factory.deployed_strategies, coin_type)) {
                // vector::push_back(&mut strategies_to_remove, strategy_address);
            };
            i = i + 1;
        };

        if (vector::length(&strategies_to_remove) > 0) {
            strategy_manager_module::remove_strategies_from_deposit_whitelist(
                strategy_manager,
                strategies_to_remove, 
                ctx
            );
        };
    }

    public entry fun whitelist_strategies(
        strategy_manager: &mut StrategyManager,
        strategies_to_whitelist: vector<address>,
        ctx: &mut TxContext
    ) {
        strategy_manager_module::add_strategies_to_deposit_whitelist(
            strategy_manager,
            strategies_to_whitelist, 
            ctx
        );
    }

    public entry fun remove_strategies_from_whitelist(
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        strategies_to_remove_from_whitelist: vector<address>,
        ctx: &mut TxContext
    ) {
        strategy_manager_module::remove_strategies_from_deposit_whitelist(
            strategy_manager,
            strategies_to_remove_from_whitelist, 
            ctx
        );
    }

    // View functions
    public fun get_strategy<COIN>(
        strategy_factory: &mut StrategyFactory,
        coin_type: string::String
    ): &mut Strategy<COIN> {
        bag::borrow_mut<string::String, Strategy<COIN>>(
            &mut strategy_factory.deployed_strategies, 
            coin_type
        )
    }

    // Modifier checks
    fun check_not_paused(strategy_factory: &StrategyFactory) {
        assert!(!strategy_factory.is_paused, E_PAUSED);
    }
}