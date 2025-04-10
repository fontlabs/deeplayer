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
    public entry fun deploy_new_strategy<CoinType>(
        strategy_factory: &mut StrategyFactory,
        ctx: &mut TxContext
    ) {
        check_not_paused(strategy_factory);

        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        assert!(!table::contains(&strategy_factory.is_blacklisted, strategy_id), E_BLACKLISTED_TOKEN);
        assert!(!bag::contains(&strategy_factory.deployed_strategies, strategy_id), E_STRATEGY_ALREADY_EXISTS);

        let strategy = strategy_module::create<CoinType>(ctx);
        bag::add(&mut strategy_factory.deployed_strategies, strategy_id, strategy);
    }

    // Public View functions
    public fun get_strategy<CoinType>(
        strategy_factory: &StrategyFactory
    ): &Strategy<CoinType> {
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        bag::borrow<string::String, Strategy<CoinType>>(&strategy_factory.deployed_strategies, strategy_id)
    }

    public fun get_strategy_mut<CoinType>(
        strategy_factory: &mut StrategyFactory
    ): &mut Strategy<CoinType> {
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();
        bag::borrow_mut<string::String, Strategy<CoinType>>(&mut strategy_factory.deployed_strategies, strategy_id)
    }

    // Modifier checks
    fun check_not_paused(strategy_factory: &StrategyFactory) {
        assert!(!strategy_factory.is_paused, E_PAUSED);
    }

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext,
    ) {
        init(ctx)
    }
}