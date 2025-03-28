// SPDX-License-Identifier: MIT
module deeplayer::strategy_factory {
    use std::option;
    use std::string;
    use sui::balance;
    use std::string;
    use sui::coin;
    use sui::table;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::coin_utils;
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
        deployed_strategies: table::Table<string::String, address>,
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
            deployed_strategies: table::new<string::String, address>(ctx),
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
    ): address {
        check_not_paused(strategy_factory);

        let coin_id = coin_utils::get_coin_id<COIN>();

        assert!(!table::contains(&strategy_factory.is_blacklisted, &coin_id), E_BLACKLISTED_TOKEN);
        assert!(!table::contains(&strategy_factory.deployed_strategies, &coin_id), E_STRATEGY_ALREADY_EXISTS);

        let strategy = strategy_module::create<COIN>(ctx);

        set_strategy_for_coin<COIN>(strategy_factory, &strategy);

        // Whitelist the strategy
        let strategies_to_whitelist = vector[strategy];

        strategy_manager_module::add_strategies_to_deposit_whitelist(
            strategy_manager,
            strategies_to_whitelist, 
            ctx
        );

        strategy
    }

    public entry fun blacklist_coins(
        strategy_factory: &mut StrategyFactory,
        coins: vector<address>,
        ctx: &mut TxContext
    ) {
        check_only_owner(strategy_factory, ctx);

        let strategies_to_remove = vector::empty<address>();
        let i = 0;
        let len = vector::length(&coins);
        while (i < len) {
            let coin_id = *vector::borrow(&coins, i);
            assert!(!table::contains(&strategy_factory.is_blacklisted, &coin_id), E_ALREADY_BLACKLISTED);
            table::add(&mut strategy_factory.is_blacklisted, coin_id, true);
            event::emit(CoinBlacklisted { coin_id });

            if (table::contains(&strategy_factory.deployed_strategies, &coin_id)) {
                let strategy = *table::borrow(&strategy_factory.deployed_strategies, &coin_id);
                vector::push_back(&mut strategies_to_remove, strategy);
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
        dl_cap: &DLCap,
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
        dl_cap: &DLCap,
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

    // Internal functions
    fun set_strategy_for_coin<COIN>(
        strategy_factory: &mut StrategyFactory,
        strategy: &Strategy<COIN>
    ) {
        let coin_id = coin_utils::get_coin_id<COIN>();
        let strategy_address = object::id_to_address(&object::id(strategy));

        table::add(&mut strategy_factory.deployed_strategies, coin_id, strategy_address);
        event::emit(StrategySetForCoin { coin_id, strategy_address });
    }

    // Modifier checks
    fun check_not_paused(strategy_factory: &StrategyFactory) {
        assert!(!strategy_factory.is_paused, E_PAUSED);
    }
}