// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
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

    // Constants
    const DEFAULT_BURN_ADDRESS: address = @0x0;

    // Structs
    public struct StrategyFactory has key {
        id: UID,
        deployed_strategies: Bag,
        is_blacklisted: table::Table<string::String, bool>,
        is_paused: bool
    }

    public struct BurnableSharesDecreased has copy, drop {
        strategy_id: string::String,
        shares_burned: u64,
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

    public entry fun burn_shares<CoinType>(
        strategy_factory: &mut StrategyFactory,
        ctx: &mut TxContext
    ) {        
        let strategy = get_strategy_mut<CoinType>(strategy_factory);
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        let shares_burned = strategy_module::burn_shares(strategy);

        event::emit(BurnableSharesDecreased {
            strategy_id,
            shares_burned,
        });

        if (shares_burned != 0) {
            strategy_module::withdraw(
                strategy,
                DEFAULT_BURN_ADDRESS, 
                shares_burned,
                ctx
            );
        }
    }

    // View functions
    public fun get_total_shares<CoinType>(
        strategy_factory: &StrategyFactory
    ): u64 {
        let strategy = get_strategy<CoinType>(strategy_factory);
        strategy_module::total_shares(strategy)   
    }

    public fun get_total_shares_as_underlying<CoinType>(
        strategy_factory: &StrategyFactory
    ): u64 {
        let strategy = get_strategy<CoinType>(strategy_factory);
        let shares = strategy_module::total_shares(strategy);  
        strategy_module::shares_to_underlying(strategy, shares)
    }

    public fun get_staker_deposit_shares<CoinType>(
        strategy_factory: &StrategyFactory,
        staker: address
    ): u64 {
        let strategy = get_strategy<CoinType>(strategy_factory);
        strategy_module::staker_shares(strategy, staker)
    }

    public fun get_staker_deposit_shares_as_underlying<CoinType>(
        strategy_factory: &StrategyFactory,
        staker: address
    ): u64 {
        let strategy = get_strategy<CoinType>(strategy_factory);
        let shares = strategy_module::staker_shares(strategy, staker);
        strategy_module::shares_to_underlying(strategy, shares)
    }

    public fun get_burnable_shares<CoinType>(        
        strategy_factory: &StrategyFactory
    ): u64 {        
        let strategy = get_strategy<CoinType>(strategy_factory);
        strategy_module::burnable_shares(strategy)
    }

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
}