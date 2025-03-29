module deeplayer::strategy_manager_module {
    use std::option;
    use std::string;
    use std::vector;
    use sui::balance;
    use sui::coin;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::table;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::deeplayer::{DLCap};
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::delegation_module::{Self, DelegationManager};

    // Constants
    const MAX_STAKER_STRATEGY_LIST_LENGTH: u64 = 32;
    const DEFAULT_BURN_ADDRESS: address = @0x0;

    // Error codes
    const E_ONLY_STRATEGY_WHITELISTER: u64 = 1;
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
        strategy_whitelister: address,
        is_paused: bool,
        version: string::String,
        strategy_is_whitelisted: table::Table<address, bool>,
        staker_deposit_shares: table::Table<address, table::Table<address, u64>>,
        staker_strategy_list: table::Table<address, vector<address>>,
        burnable_shares: table::Table<address, u64>,
        nonces: table::Table<address, u64>,
    }

    // Events
    public struct StrategyAddedToDepositWhitelist has copy, drop {
        strategy_address: address,
    }

    public struct StrategyRemovedFromDepositWhitelist has copy, drop {
        strategy_address: address,
    }

    public struct StrategyWhitelisterChanged has copy, drop {
        old_whitelister: address,
        new_whitelister: address,
    }

    public struct Deposit has copy, drop {
        staker: address,
        strategy_address: address,
        shares: u64,
    }

    public struct BurnableSharesIncreased has copy, drop {
        strategy_address: address,
        added_shares_to_burn: u64,
    }

    public struct BurnableSharesDecreased has copy, drop {
        strategy_address: address,
        shares_burned: u64,
    }

    public entry fun initialize(
        dl_cap: &DLCap,
        version: vector<u8>,
        initial_strategy_whitelister: address,
        ctx: &mut TxContext
    ) {
        let strategy_manager = StrategyManager {
            id: object::new(ctx),
            strategy_whitelister: initial_strategy_whitelister,
            is_paused: false,
            version: string::utf8(version),
            strategy_is_whitelisted: table::new<address, bool>(ctx),
            staker_deposit_shares: table::new<address, table::Table<address, u64>>(ctx),
            staker_strategy_list: table::new<address, vector<address>>(ctx),
            burnable_shares: table::new<address, u64>(ctx),
            nonces: table::new<address, u64>(ctx),
        };

        transfer::share_object(strategy_manager);
    }

    // Public functions
    public entry fun deposit_into_strategy<COIN>(
        strategy_manager: &mut StrategyManager,
        delegation_manager: &mut DelegationManager,
        strategy: &mut Strategy<COIN>,
        coin_deposited: coin::Coin<COIN>,
        ctx: &mut TxContext
    ) {
        check_not_paused(strategy_manager);

        deposit_into_strategy_impl(
            strategy_manager, 
            delegation_manager,
            tx_context::sender(ctx), 
            strategy,
            coin_deposited, 
            ctx
        );
    }

    public entry fun remove_deposit_shares<COIN>(
        strategy_manager: &mut StrategyManager,
        dl_cap: &DLCap,
        staker: address,
        strategy: &Strategy<COIN>,
        deposit_shares_to_remove: u64,
        ctx: &mut TxContext
    ): u64 {
        let (_, shares_after) = remove_deposit_shares_impl<COIN>(
            strategy_manager, 
            staker, 
            strategy, 
            deposit_shares_to_remove
        );

        shares_after
    }

    public entry fun add_shares<COIN>(
        dl_cap: &DLCap,
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy: &Strategy<COIN>,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        add_shares_impl<COIN>(
            strategy_manager, 
            staker, 
            strategy, 
            shares,
            ctx
        )
    }

    public entry fun withdraw_shares_as_coins<COIN>(
        strategy: &mut Strategy<COIN>,
        staker: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        strategy_module::withdraw(
            strategy,
            staker, 
            shares, 
            ctx
        );
    }

    public entry fun increase_burnable_shares<COIN>(
        dl_cap: DLCap,
        strategy_manager: &mut StrategyManager,
        strategy: &Strategy<COIN>,
        added_shares_to_burn: u64,
        ctx: &mut TxContext
    ) {
        let strategy_address = object::id_to_address(&object::id(strategy));

        let current_shares = if (table::contains(&strategy_manager.burnable_shares, strategy_address)) {
            *table::borrow(&strategy_manager.burnable_shares, strategy_address)
        } else {
            0
        };

        table::add(&mut strategy_manager.burnable_shares, strategy_address, current_shares + added_shares_to_burn);
      
        event::emit(BurnableSharesIncreased {
            strategy_address,
            added_shares_to_burn,
        });
    }

    public entry fun burn_shares<COIN>(
        dl_cap: DLCap,
        strategy_manager: &mut StrategyManager,
        strategy: &mut Strategy<COIN>,
        ctx: &mut TxContext
    ) {
        let strategy_address = object::id_to_address(&object::id(strategy));

        let shares_to_burn = if (table::contains(&strategy_manager.burnable_shares, strategy_address)) {
            *table::borrow(&strategy_manager.burnable_shares, strategy_address)
        } else {
            0
        };

        table::remove(&mut strategy_manager.burnable_shares, strategy_address);

        event::emit(BurnableSharesDecreased {
            strategy_address,
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

    public entry fun set_strategy_whitelister(
        strategy_manager: &mut StrategyManager,
        dl_cap: &DLCap,
        new_strategy_whitelister: address
    ) {
        set_strategy_whitelister_impl(strategy_manager, new_strategy_whitelister);
    }

    public(package) fun add_strategies_to_deposit_whitelist(
        strategy_manager: &mut StrategyManager,
        strategies_to_whitelist: vector<address>,
        ctx: &mut TxContext
    ) {
        let i = 0;
        let len = vector::length(&strategies_to_whitelist);
        while (i < len) {
            let strategy_address = *vector::borrow(&strategies_to_whitelist, i);
            if (!table::contains(&strategy_manager.strategy_is_whitelisted, strategy_address) || 
                !*table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_address)) {
                table::add(&mut strategy_manager.strategy_is_whitelisted, strategy_address, true);
                event::emit(StrategyAddedToDepositWhitelist { 
                    strategy_address 
                });
            };
            i = i + 1;
        };
    }

    public entry fun remove_strategies_from_deposit_whitelist(
        strategy_manager: &mut StrategyManager,
        strategies_to_remove_from_whitelist: vector<address>,
        ctx: &mut TxContext
    ) {
        check_only_strategy_whitelister(strategy_manager, ctx);

        let i = 0;
        let len = vector::length(&strategies_to_remove_from_whitelist);
        while (i < len) {
            let strategy_address = *vector::borrow(&strategies_to_remove_from_whitelist, i);
            if (table::contains(&strategy_manager.strategy_is_whitelisted, strategy_address) && 
                *table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_address)) {
                table::add(&mut strategy_manager.strategy_is_whitelisted, strategy_address, false);
                
                event::emit(StrategyRemovedFromDepositWhitelist { 
                    strategy_address 
                });
            };
            i = i + 1;
        };
    }

    // Internal functions
    fun add_shares_impl<COIN>(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy: &Strategy<COIN>,
        shares: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        assert!(staker != @0x0, E_STAKER_ADDRESS_ZERO);
        assert!(shares != 0, E_SHARES_AMOUNT_ZERO);

        let strategy_address = object::id_to_address(&object::id(strategy));

        let prev_deposit_shares = if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
            table::contains(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_address)) {
            *table::borrow(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_address)
        } else {
            0
        };

        if (prev_deposit_shares == 0) {
            if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
                table::add(&mut strategy_manager.staker_strategy_list, staker, vector::empty<address>());
            };
            let strategies = table::borrow_mut(&mut strategy_manager.staker_strategy_list, staker);
            
            assert!(vector::length(strategies) < MAX_STAKER_STRATEGY_LIST_LENGTH, E_MAX_STRATEGIES_EXCEEDED);
            vector::push_back(strategies, strategy_address);
        };

        // Update deposit shares
        if (!table::contains(&strategy_manager.staker_deposit_shares, staker)) {
            table::add(&mut strategy_manager.staker_deposit_shares, staker, table::new<address, u64>(ctx));
        };
        let staker_shares = table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker);
        table::add(staker_shares, strategy_address, prev_deposit_shares + shares);

        event::emit(Deposit {
            staker,
            strategy_address,
            shares,
        });

        (prev_deposit_shares, shares)
    }

    fun deposit_into_strategy_impl<COIN>(
        strategy_manager: &mut StrategyManager,
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy: &mut Strategy<COIN>,
        coin_deposited: coin::Coin<COIN>,
        ctx: &mut TxContext
    ): u64 {
        let strategy_address = object::id_to_address(&object::id(strategy));

        assert!(
            table::contains(&strategy_manager.strategy_is_whitelisted, strategy_address) &&
            *table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_address),
            E_STRATEGY_NOT_WHITELISTED
        );

        let shares = strategy_module::deposit<COIN>(
            strategy, 
            coin_deposited,
            ctx
        );

        let (prev_deposit_shares, added_shares) = add_shares_impl<COIN>(
            strategy_manager,
            staker, 
            strategy, 
            shares,
            ctx
        );

        delegation_module::increase_delegated_shares(
            delegation_manager,
            staker, 
            strategy_address, 
            prev_deposit_shares, 
            added_shares, 
            ctx
        );

        shares
    }

    fun remove_deposit_shares_impl<COIN>(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy: &Strategy<COIN>,
        deposit_shares_to_remove: u64
    ): (bool, u64) {
        assert!(deposit_shares_to_remove != 0, E_SHARES_AMOUNT_ZERO);

        let strategy_address = object::id_to_address(&object::id(strategy));

        let user_deposit_shares = if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
            table::contains(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_address)) {
            *table::borrow(table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker), strategy_address)
        } else {
            0
        };

        assert!(deposit_shares_to_remove <= user_deposit_shares, E_SHARES_AMOUNT_TOO_HIGH);
        let shares_after = user_deposit_shares - deposit_shares_to_remove;

        // Update shares
        let staker_shares = table::borrow_mut(&mut strategy_manager.staker_deposit_shares, staker);
        table::add(staker_shares, strategy_address, shares_after);

        if (shares_after == 0) {
            remove_strategy_from_staker_strategy_list(
                strategy_manager, 
                staker, 
                strategy_address
            );

            return (true, shares_after);
        };

        (false, shares_after)
    }

    fun remove_strategy_from_staker_strategy_list(
        strategy_manager: &mut StrategyManager,
        staker: address,
        strategy_address: address
    ) {
        assert!(table::contains(&strategy_manager.staker_strategy_list, staker), E_STRATEGY_NOT_FOUND);
        let strategies = table::borrow_mut(&mut strategy_manager.staker_strategy_list, staker);
        
        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            if (*vector::borrow(strategies, i) == strategy_address) {
                vector::swap_remove(strategies, i);
                return;
            };
            i = i + 1;
        };
        assert!(false, E_STRATEGY_NOT_FOUND);
    }

    fun set_strategy_whitelister_impl(
        strategy_manager: &mut StrategyManager,
        new_strategy_whitelister: address
    ) {
        let old_whitelister = strategy_manager.strategy_whitelister;
        strategy_manager.strategy_whitelister = new_strategy_whitelister;

        event::emit(StrategyWhitelisterChanged {
            old_whitelister,
            new_whitelister: new_strategy_whitelister,
        });
    }

    // View functions
    public fun get_deposits(
        strategy_manager: &StrategyManager,
        staker: address
    ): (vector<address>, vector<u64>) {
        if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
            return (vector::empty<address>(), vector::empty<u64>());
        };
        
        let strategies = table::borrow(&strategy_manager.staker_strategy_list, staker);
        let len = vector::length(strategies);
        let deposited_shares = vector::empty<u64>();
        
        let i = 0;
        while (i < len) {
            let strategy = *vector::borrow(strategies, i);
            let shares = if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
                table::contains(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy)) {
                *table::borrow(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy)
            } else {
                0
            };
            vector::push_back(&mut deposited_shares, shares);
            i = i + 1;
        };

        (*strategies, deposited_shares)
    }

    public fun staker_deposit_shares(
        strategy_manager: &StrategyManager,
        staker: address,
        strategy_address: address
    ): u64 {
        if (table::contains(&strategy_manager.staker_deposit_shares, staker) &&
            table::contains(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy_address)) {
            *table::borrow(table::borrow(&strategy_manager.staker_deposit_shares, staker), strategy_address)
        } else {
            0
        }
    }

    public fun get_staker_strategy_list(
        strategy_manager: &StrategyManager,
        staker: address
    ): &vector<address> {
        table::borrow(&strategy_manager.staker_strategy_list, staker)
    }

    public fun staker_strategy_list_length(
        strategy_manager: &StrategyManager,
        staker: address
    ): u64 {
        if (!table::contains(&strategy_manager.staker_strategy_list, staker)) {
            return 0;
        };
        vector::length(table::borrow(&strategy_manager.staker_strategy_list, staker))
    }

    public fun get_burnable_shares(
        strategy_manager: &StrategyManager,
        strategy_address: address
    ): u64 {
        if (table::contains(&strategy_manager.burnable_shares, strategy_address)) {
            *table::borrow(&strategy_manager.burnable_shares, strategy_address)
        } else {
            0
        }
    }

    public fun get_strategies_with_burnable_shares(
        strategy_manager: &StrategyManager
    ): (vector<address>, vector<u64>) {
        let strategies = vector::empty<address>();
        let shares = vector::empty<u64>();
        
        
        (strategies, shares)
    }

    // Modifier checks
    fun check_only_strategy_whitelister(
        strategy_manager: &StrategyManager,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == strategy_manager.strategy_whitelister, E_ONLY_STRATEGY_WHITELISTER);
    }

    fun check_strategy_whitelisted_for_deposit(strategy_manager: &StrategyManager, strategy_address: address) {
        assert!(
            table::contains(&strategy_manager.strategy_is_whitelisted, strategy_address) &&
            *table::borrow(&strategy_manager.strategy_is_whitelisted, strategy_address),
            E_STRATEGY_NOT_WHITELISTED
        );
    }

    fun check_not_paused(strategy_manager: &StrategyManager) {
        assert!(!strategy_manager.is_paused, E_PAUSED);
    }
}