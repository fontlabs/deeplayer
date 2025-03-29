// SPDX-License-Identifier: MIT
module deeplayer::strategy_factory_module {
    use std::option;
    use std::string;
    use sui::balance;
    use std::string;
    use sui::coin;
    use sui::table;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::object_bag:{Self, ObjectBag};
    use sui::tx_context::{Self, TxContext};

    use deeplayer::coin_utils_module;
    use deeplayer::deeplayer::{DLCap};
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};

    // Error codes
    const E_BLACKLISTED_TOKEN: u64 = 1;
    const E_STRATEGY_ALREADY_EXISTS: u64 = 2;
    const E_ALREADY_BLACKLISTED: u64 = 3;
    const E_ONLY_OWNER: u64 = 4;
    const E_PAUSED: u64 = 5;


    // Structs
    struct StrategyFactory has key {
        id: UID,
        deployed_strategies: ObjectBag,
        deployed_strategies_with_address: ObjectBag,
        is_blacklisted: table::Table<address, bool>,
        is_paused: bool
    }

    // Events
    struct CoinBlacklisted has copy, drop {
        coin: address,
    }

    struct StrategySetForCoin has copy, drop {
        coin_id: string::String,
        strategy_address: address,
    }

    // Initialization
    fun init(
        ctx: &mut TxContext
    ) {
        let strategy_factory = StrategyFactory {
            id: object::new(ctx),
            deployed_strategies: object_bag::new(ctx),
            deployed_strategies_with_address: object_bag::new(ctx),
            is_blacklisted: table::new<address, bool>(ctx),
            is_paused: false
        };

        transfer::share_object(strategy_factory);
    }

    // Public functions
    public entry fun deploy_new_strategy<COIN>(
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        ctx: &mut TxContext
    ): Strategy<COIN> {
        check_not_paused(strategy_factory);

        let coin_id = coin_utils_module::get_coin_id<COIN>();

        assert!(!table::contains(&strategy_factory.is_blacklisted, &coin_id), E_BLACKLISTED_TOKEN);
        assert!(!object_bag::contains(&strategy_factory.deployed_strategies, &coin_id), E_STRATEGY_ALREADY_EXISTS);

        let strategy = strategy_module::create<COIN>(ctx);

        let strategy_address = set_strategy_for_coin<COIN>(
            strategy_factory, 
            &strategy
        );

        // Whitelist the strategy
        let strategies_to_whitelist = vector[strategy_address];
        strategy_manager_module::add_strategies_to_deposit_whitelist(
            strategy_manager,
            strategies_to_whitelist, 
            ctx
        );

        strategy
    }

    public entry fun blacklist_coins(
        strategy_factory: &mut StrategyFactory,
        coin_ids: vector<string::String>,
        ctx: &mut TxContext
    ) {
        let strategies_to_remove = vector::empty<address>();
        let i = 0;
        let len = vector::length(&coin_ids);
        while (i < len) {
            let coin_id = *vector::borrow(&coin_ids, i);
            assert!(!table::contains(&strategy_factory.is_blacklisted, &coin_id), E_ALREADY_BLACKLISTED);
            
            table::add(&mut strategy_factory.is_blacklisted, coin_id, true);
          
            event::emit(CoinBlacklisted { 
                coin_id
            });

            if (object_bag::contains(&strategy_factory.deployed_strategies, coin_id)) {
                let strategy = get_strategy<any>(coin_id);
                let strategy_address = object::id_to_address(&object::id(strategy));
                vector::push_back(&mut strategies_to_remove, strategy_address);
            };
            i = i + 1;
        };

        if (vector::length(&strategies_to_remove) > 0) {
            strategy_manager::remove_strategies_from_deposit_whitelist(
                strategies_to_remove, 
                ctx
            );
        };
    }

    public entry fun whitelist_strategies(
        strategy_factory: &mut StrategyFactory,
        strategies_to_whitelist: vector<address>,
        ctx: &mut TxContext
    ) {
        strategy_manager::add_strategies_to_deposit_whitelist(
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
        coin_id: string::String
    ): Strategy<COIN> {
        object_bag::borrow<String, Strategy<COIN>>(
            &strategy_factory.deployed_strategies, 
            coin_id
        )
    }

    public fun get_strategy_from_address<COIN>(
        strategy_factory: &mut StrategyFactory,
        strategy_address: address
    ): Strategy<COIN> {
        object_bag::borrow<String, Strategy<COIN>>(
            &strategy_factory.deployed_strategies_with_address, 
            strategy_address
        )
    }

    // Internal functions
    fun set_strategy_for_coin<COIN>(
        strategy_factory: &mut StrategyFactory,
        strategy: &Strategy<COIN>
    ): address {
        let coin_id = coin_utils_module::get_coin_id<COIN>();

        object_bag::add(&mut strategy_factory.deployed_strategies, coin_id, strategy);

        let strategy_address = object::id_to_address(&object::id(strategy));
        object_bag::add(&mut strategy_factory.deployed_strategies_with_address, strategy_address, strategy);

        event::emit(StrategySetForCoin { 
            coin_id, 
            strategy_address
        });

        strategy_address
    }

    // Modifier checks
    fun check_not_paused(strategy_factory: &StrategyFactory) {
        assert!(!strategy_factory.is_paused, E_PAUSED);
    }
}