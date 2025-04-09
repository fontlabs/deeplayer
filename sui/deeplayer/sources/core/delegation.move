// SPDX-License-Identifier: MIT
module deeplayer::delegation_module {
    use std::option;
    use std::string;
    use std::vector;
    use sui::clock;
    use sui::coin;
    use sui::balance;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::table;
    use sui::tx_context::{Self, TxContext};
    use sui::bcs;

    use deeplayer::math_module;
    use deeplayer::coin_utils_module;
    use deeplayer::slashing_lib_module::{Self, DepositScalingFactor};
    use deeplayer::strategy_module::{Strategy};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager};

    // Constants
    const WAD: u64 = 1_000_000_000;
    const MIN_WITHDRAWAL_DELAY: u64 = 100;

    // Error codes
    const E_ACTIVELY_DELEGATED: u64 = 4;
    const E_OPERATOR_NOT_REGISTERED: u64 = 5;
    const E_NOT_ACTIVELY_DELEGATED: u64 = 6;
    const E_OPERATORS_CANNOT_UNDELEGATE: u64 = 7;
    const E_CALLER_CANNOT_UNDELEGATE: u64 = 8;
    const E_INPUT_ARRAY_LENGTH_MISMATCH: u64 = 9;
    const E_WITHDRAWAL_NOT_QUEUED: u64 = 10;
    const E_WITHDRAWAL_DELAY_NOT_ELAPSED: u64 = 11;
    const E_FULLY_SLASHED: u64 = 12;
    const E_SALT_SPENT: u64 = 13;
    const E_INPUT_ADDRESS_ZERO: u64 = 14;
    const E_INPUT_ARRAY_LENGTH_ZERO: u64 = 15;
    const E_PAUSED: u64 = 16;
    const E_INVALID_SIGNATURE: u64 = 17;
    const E_WITHDRAWER_NOT_CALLER: u64 = 18;

    // Structs
    public struct OperatorDetails has store {
        metadata_uri: string::String,
    }

    public struct Withdrawal has copy, drop, store {
        staker: address,
        delegated_to: address,
        withdrawer: address,
        nonce: u64,
        start_block: u64,
        strategy_ids: vector<string::String>,
        scaled_shares: vector<u64>,
    }

    public struct DelegationManager has key {
        id: UID,
        min_withdrawal_delay: u64,
        is_paused: bool,
        operator_details: table::Table<address, OperatorDetails>,
        delegated_to: table::Table<address, address>,
        operator_shares: table::Table<address, table::Table<string::String, u64>>,
        deposit_scaling_factors: table::Table<address, table::Table<string::String, DepositScalingFactor>>,
        pending_withdrawals: table::Table<vector<u8>, bool>,
        queued_withdrawals: table::Table<vector<u8>, Withdrawal>,
        staker_queued_withdrawal_roots: table::Table<address, vector<vector<u8>>>,
        withdrawal_nonces: table::Table<address, u64>,
    }

    // Events
    public struct OperatorRegistered has copy, drop {
        operator: address,
    }

    public struct OperatorMetadataURIUpdated has copy, drop {
        operator: address,
        metadata_uri: string::String,
    }

    public struct StakerDelegated has copy, drop {
        staker: address,
        operator: address,
    }

    public struct StakerUndelegated has copy, drop {
        staker: address,
        operator: address,
    }

    public struct StakerForceUndelegated has copy, drop {
        staker: address,
        operator: address,
    }

    public struct SlashingWithdrawalQueued has copy, drop {
        withdrawal_root: vector<u8>,
        withdrawal: Withdrawal,
        withdrawable_shares: vector<u64>,
    }

    public struct SlashingWithdrawalCompleted has copy, drop {
        withdrawal_root: vector<u8>,
    }

    public struct OperatorSharesIncreased has copy, drop {
        operator: address,
        staker: address,
        strategy_id: string::String,
        added_shares: u64,
    }

    public struct OperatorSharesDecreased has copy, drop {
        operator: address,
        staker: address,
        strategy_id: string::String,
        shares_decreased: u64,
    }

    public struct OperatorSharesSlashed has copy, drop {
        operator: address,
        strategy_id: string::String,
        total_deposit_shares_to_burn: u64,
    }

    public struct DepositScalingFactorUpdated has copy, drop {
        staker: address,
        strategy_id: string::String,
        scaling_factor: u64,
    }

    // Initialization
    fun init(
        ctx: &mut TxContext
    ) {
        let delegation_manager = DelegationManager {
            id: object::new(ctx),
            min_withdrawal_delay: MIN_WITHDRAWAL_DELAY,
            is_paused: false,
            operator_details: table::new<address, OperatorDetails>(ctx),
            delegated_to: table::new<address, address>(ctx),
            operator_shares: table::new<address, table::Table<string::String, u64>>(ctx),
            deposit_scaling_factors: table::new<address, table::Table<string::String, DepositScalingFactor>>(ctx),
            pending_withdrawals: table::new<vector<u8>, bool>(ctx),
            queued_withdrawals: table::new<vector<u8>, Withdrawal>(ctx),
            staker_queued_withdrawal_roots: table::new<address, vector<vector<u8>>>(ctx),
            withdrawal_nonces: table::new<address, u64>(ctx),
        };

        transfer::share_object(delegation_manager);
    }

    // Public functions
    public entry fun deposit_into_strategy<CoinType>(   
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);

        let staker = tx_context::sender(ctx);
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        let (prev_deposit_shares, added_shares) = strategy_manager_module::deposit<CoinType>(
            strategy_factory,
            strategy_manager,
            coin_deposited,
            ctx
        );

        increase_delegated_shares(
            allocation_manager,
            delegation_manager, 
            staker, 
            strategy_id, 
            prev_deposit_shares, 
            added_shares,
            ctx
        )
    }

    public entry fun register_as_operator(
        strategy_manager: &StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        metadata_uri: string::String,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(!is_delegated(delegation_manager, sender), E_ACTIVELY_DELEGATED);

        let operator_details = OperatorDetails {
            metadata_uri: metadata_uri,
        };

        table::add(&mut delegation_manager.operator_details, sender, operator_details);

        // Delegate from the operator to themselves
        delegate_impl(strategy_manager, allocation_manager, delegation_manager, sender, sender, ctx);

        event::emit(OperatorRegistered {
            operator: sender,
        });

        event::emit(OperatorMetadataURIUpdated {
            operator: sender,
            metadata_uri: metadata_uri,
        });
    }

    public entry fun update_operator_metadata_uri(
        delegation_manager: &mut DelegationManager,
        metadata_uri: vector<u8>,
        ctx: &mut TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(is_operator(delegation_manager, operator), E_OPERATOR_NOT_REGISTERED);
        
        let operator_details = table::borrow_mut(&mut delegation_manager.operator_details, operator);
        operator_details.metadata_uri = string::utf8(metadata_uri);

        event::emit(OperatorMetadataURIUpdated {
            operator,
            metadata_uri: string::utf8(metadata_uri),
        });
    }

    public entry fun delegate(
        strategy_manager: &StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        operator: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        assert!(!is_delegated(delegation_manager, sender), E_ACTIVELY_DELEGATED);
        assert!(is_operator(delegation_manager, operator), E_OPERATOR_NOT_REGISTERED);

        // Delegate sender to the operator
        delegate_impl(strategy_manager, allocation_manager, delegation_manager, sender, operator, ctx);
    }

    public entry fun undelegate(
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        staker: address,
        ctx: &mut TxContext
    ) {
        assert!(is_delegated(delegation_manager, staker), E_NOT_ACTIVELY_DELEGATED);
        assert!(!is_operator(delegation_manager, staker), E_OPERATORS_CANNOT_UNDELEGATE);

        let sender = tx_context::sender(ctx);

        if (sender != staker) {
            let operator = *table::borrow(&delegation_manager.delegated_to, staker);
            assert!(check_can_call(operator, ctx), E_CALLER_CANNOT_UNDELEGATE);

            event::emit(StakerForceUndelegated {
                staker,
                operator
            });
        };

        undelegate_impl(strategy_manager, allocation_manager, delegation_manager, staker, ctx);
    }

    public entry fun redelegate(
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        new_operator: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        undelegate(strategy_manager, allocation_manager, delegation_manager, tx_context::sender(ctx), ctx);
        delegate(strategy_manager, allocation_manager, delegation_manager, new_operator, the_clock, ctx);
    }

    public entry fun queue_withdrawals(
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        strategy_ids: vector<string::String>,
        deposit_shares: vector<u64>,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);

        let sender = tx_context::sender(ctx);
        let operator = *table::borrow(&delegation_manager.delegated_to, sender);

        assert!(
            vector::length(&strategy_ids) == vector::length(&deposit_shares),
            E_INPUT_ARRAY_LENGTH_MISMATCH
        );

        let slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, operator, strategy_ids, 0);

        remove_shares_and_queue_withdrawal(
            delegation_manager,
            strategy_manager,
            sender,
            operator,
            strategy_ids,
            deposit_shares,
            slashing_factors,
            ctx
        );
    }

    public entry fun complete_queued_withdrawal<CoinType>(
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        withdrawal_root: vector<u8>,
        receive_as_coins: bool,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);

        assert!(
            *table::borrow(&delegation_manager.pending_withdrawals, withdrawal_root),
            E_WITHDRAWAL_NOT_QUEUED
        );
        
        let withdrawal = *table::borrow(&delegation_manager.queued_withdrawals, withdrawal_root);

        assert!(
            tx_context::sender(ctx) == withdrawal.withdrawer,
            E_WITHDRAWER_NOT_CALLER
        );

        let slashable_until = withdrawal.start_block + delegation_manager.min_withdrawal_delay;
        assert!(
            tx_context::epoch(ctx) > slashable_until,
            E_WITHDRAWAL_DELAY_NOT_ELAPSED
        );

        // Remove the withdrawal from the queue
        table::remove(&mut delegation_manager.queued_withdrawals, withdrawal_root);
        table::remove(&mut delegation_manager.pending_withdrawals, withdrawal_root);

        // Remove from staker's queued withdrawal roots
        let staker_roots = table::borrow_mut(&mut delegation_manager.staker_queued_withdrawal_roots, withdrawal.staker);
        let mut i = 0;
        let len = vector::length(staker_roots);
        while (i < len) {
            if (*vector::borrow(staker_roots, i) == withdrawal_root) {
                vector::remove(staker_roots, i);
                break;
            };
            i = i + 1;
        };

        event::emit(SlashingWithdrawalCompleted {
            withdrawal_root,
        });

        // Get slashing factors at completion time
        let prev_slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, withdrawal.delegated_to, withdrawal.strategy_ids, slashable_until);

        // Get current slashing factors for redeposit
        let new_operator = *table::borrow(&delegation_manager.delegated_to, withdrawal.staker);
        let new_slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, new_operator, withdrawal.strategy_ids, 0);

        // Process each strategy
        let mut i = 0;
        let len = vector::length(&withdrawal.strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&withdrawal.strategy_ids, i);
            let scaled_shares = *vector::borrow(&withdrawal.scaled_shares, i);
            let prev_slashing_factor = *vector::borrow(&prev_slashing_factors, i);
            let new_slashing_factor = *vector::borrow(&new_slashing_factors, i);

            let shares_to_withdraw = slashing_lib_module::scale_for_complete_withdrawal(
                scaled_shares,
                prev_slashing_factor
            );

            if (shares_to_withdraw == 0) {
                continue;
            };

            let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);

            if (receive_as_coins) {
                strategy_manager_module::withdraw_shares_as_coins<CoinType>(
                    strategy,
                    strategy_manager,
                    withdrawal.staker,
                    shares_to_withdraw,
                    ctx
                );
            } else {
                let (prev_deposit_shares, added_shares) = strategy_manager_module::add_shares<CoinType>(
                    strategy_manager,
                    withdrawal.staker,
                    shares_to_withdraw,
                    ctx
                );

                increase_delegation(
                    delegation_manager,
                    new_operator,
                    withdrawal.staker,
                    strategy_id,
                    prev_deposit_shares,
                    added_shares,
                    new_slashing_factor,
                    ctx
                );
            };

            i = i + 1;
        };
    }

    // Package functions
    public(package) fun increase_delegated_shares(
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_id: string::String,
        prev_deposit_shares: u64,
        added_shares: u64,
        ctx: &mut TxContext
    ) {      
        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factor = allocation_module::get_max_magnitude(allocation_manager, operator, strategy_id, 0);

        increase_delegation(
            delegation_manager,
            operator,
            staker,
            strategy_id,
            prev_deposit_shares,
            added_shares,
            slashing_factor,
            ctx
        );
    }

    public(package) fun slash_operator_shares<CoinType>(
        strategy: &mut Strategy<CoinType>,
        strategy_manager: &mut StrategyManager,
        delegation_manager: &mut DelegationManager,
        operator: address,
        prev_max_magnitude: u64,
        new_max_magnitude: u64,
        ctx: &mut TxContext
    ) {     
        let strategy_id = coin_utils_module::get_strategy_id<CoinType>();

        let operator_shares = get_operator_shares_impl(
            delegation_manager, 
            operator, 
            strategy_id
        );

        let operator_shares_slashed = slashing_lib_module::calc_slashed_amount(
            operator_shares,
            prev_max_magnitude,
            new_max_magnitude
        );

        decrease_delegation(delegation_manager, operator, @0x0, strategy_id, operator_shares_slashed, ctx);

        event::emit(OperatorSharesSlashed {
            operator,
            strategy_id,
            total_deposit_shares_to_burn: operator_shares_slashed,
        });

        // Increase burnable shares in strategy manager
        strategy_manager_module::increase_burnable_shares<CoinType>(
            strategy_manager,
            strategy, 
            operator_shares_slashed
        );
    }

    // Internal functions
    fun delegate_impl(
        strategy_manager: &StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        staker: address,
        operator: address,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);
        
        // Get staker's deposited strategy_ids and shares
        let (strategy_ids, withdrawable_shares) = strategy_manager_module::get_deposits(strategy_manager, staker);
        
        // Get slashing factors
        let slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, @0x0, strategy_ids, 0);

        // Delegate to operator
        table::add(&mut delegation_manager.delegated_to, staker, operator);
        event::emit(StakerDelegated {
            staker,
            operator,
        });

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id  = *vector::borrow(&strategy_ids, i);
            let prev_deposit_shares = strategy_manager_module::get_staker_shares(
                strategy_manager,
                strategy_id,
                staker
            );
            let mut shares = *vector::borrow(&withdrawable_shares, i);

            increase_delegation(
                delegation_manager,
                operator,
                staker,
                strategy_id ,
                prev_deposit_shares,
                shares,
                *vector::borrow(&slashing_factors, i),
                ctx
            );

            i = i + 1;
        };
    }

    fun undelegate_impl(
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        delegation_manager: &mut DelegationManager,
        staker: address,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);
        
        let operator = table::remove(&mut delegation_manager.delegated_to, staker);
        event::emit(StakerUndelegated {
            staker,
            operator,
        });

        // Get all staker's deposited strategy_ids/shares
        let (strategy_ids, deposited_shares) = strategy_manager_module::get_deposits(strategy_manager, staker);
        if (vector::is_empty(&strategy_ids)) {
            return;
        };

        // Get slashing factors
        let slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, operator, strategy_ids, 0);

        // Queue withdrawals for each strategy
        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let single_strategy_address = vector[*vector::borrow(&strategy_ids, i)];
            let single_deposit_shares = vector[*vector::borrow(&deposited_shares, i)];
            let single_slashing_factor = vector[*vector::borrow(&slashing_factors, i)];

            remove_shares_and_queue_withdrawal(
                delegation_manager,
                strategy_manager,
                staker,
                operator,
                single_strategy_address,
                single_deposit_shares,
                single_slashing_factor,
                ctx
            );

            i = i + 1;
        };
    }

    fun remove_shares_and_queue_withdrawal(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &mut StrategyManager,
        staker: address,
        operator: address,
        strategy_ids: vector<string::String>,
        deposit_shares_to_withdraw: vector<u64>,
        slashing_factors: vector<u64>,
        ctx: &mut TxContext
    ) {
        assert!(staker != @0x0, E_INPUT_ADDRESS_ZERO);
        assert!(!vector::is_empty(&strategy_ids), E_INPUT_ARRAY_LENGTH_ZERO);

        let mut scaled_shares = vector::empty<u64>();
        let mut withdrawable_shares = vector::empty<u64>();

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let deposit_shares = *vector::borrow(&deposit_shares_to_withdraw, i);
            let slashing_factor = *vector::borrow(&slashing_factors, i);

            let dsf = get_deposit_scaling_factor(delegation_manager, staker, strategy_id);
            let withdrawable = slashing_lib_module::calc_withdrawable(dsf, deposit_shares, slashing_factor);
            vector::push_back(&mut withdrawable_shares, withdrawable);

            let scaled = slashing_lib_module::scale_for_queue_withdrawal(dsf, deposit_shares);
            vector::push_back(&mut scaled_shares, scaled);

            if (operator != @0x0) {
                decrease_delegation(
                    delegation_manager,
                    operator,
                    staker,
                    strategy_id,
                    withdrawable,
                    ctx
                );
            };

            // Remove deposit shares from strategy manager
            let (_, shares_after) = strategy_manager_module::remove_deposit_shares(
                strategy_manager,
                strategy_id, 
                staker, 
                deposit_shares
            );

            if (shares_after == 0) {
                reset_deposit_scaling_factor(delegation_manager, staker, strategy_id);
            };

            i = i + 1;
        };

        // Create withdrawal
        if (!table::contains(&delegation_manager.withdrawal_nonces, staker)) {
            table::add(&mut delegation_manager.withdrawal_nonces, staker, 0)
        };
        let nonce = *table::borrow(&delegation_manager.withdrawal_nonces, staker);
        table::add(&mut delegation_manager.withdrawal_nonces, staker, nonce + 1);

        let withdrawal = Withdrawal {
            staker,
            delegated_to: operator,
            withdrawer: staker,
            nonce,
            start_block: tx_context::epoch(ctx),
            strategy_ids: strategy_ids,
            scaled_shares,
        };

        let withdrawal_root = calculate_withdrawal_root(&withdrawal);
        table::add(&mut delegation_manager.pending_withdrawals, withdrawal_root, true);
        table::add(&mut delegation_manager.queued_withdrawals, withdrawal_root, withdrawal);

        // Add to staker's queued withdrawal roots
        if (!table::contains(&delegation_manager.staker_queued_withdrawal_roots, staker)) {
            table::add(&mut delegation_manager.staker_queued_withdrawal_roots, staker, vector::empty<vector<u8>>());
        };
        let staker_roots = table::borrow_mut(&mut delegation_manager.staker_queued_withdrawal_roots, staker);
        vector::push_back(staker_roots, withdrawal_root);

        event::emit(SlashingWithdrawalQueued {
            withdrawal_root,
            withdrawal,
            withdrawable_shares,
        });
    }

    fun increase_delegation(
        delegation_manager: &mut DelegationManager,
        operator: address,
        staker: address,
        strategy_id: string::String,
        prev_deposit_shares: u64,
        added_shares: u64,
        slashing_factor: u64,
        ctx: &mut TxContext
    ) {
        assert!(slashing_factor != 0, E_FULLY_SLASHED);
        if (added_shares == 0) {
            return;
        };

        let mut dsf = get_deposit_scaling_factor_mut(delegation_manager, staker, strategy_id);
        let new_scaling_factor = slashing_lib_module::update(dsf, prev_deposit_shares, added_shares, slashing_factor);

        event::emit(DepositScalingFactorUpdated {
            staker,
            strategy_id,
            scaling_factor: new_scaling_factor
        });

        // Update operator shares if staker is delegated
        if (is_delegated(delegation_manager, staker)) {
            let operator_strategy_shares = get_operator_shares_impl(delegation_manager, operator, strategy_id);
            set_operator_shares(
                delegation_manager, 
                operator, 
                strategy_id,
                operator_strategy_shares + added_shares,
                ctx
            );

            event::emit(OperatorSharesIncreased {
                operator,
                staker,
                strategy_id,
                added_shares,
            });
        };
    }

    fun decrease_delegation(
        delegation_manager: &mut DelegationManager,
        operator: address,
        staker: address,
        strategy_id: string::String,
        shares_to_decrease: u64,
        ctx: &mut TxContext
    ) {
        let operator_strategy_shares = get_operator_shares_impl(delegation_manager, operator, strategy_id);
        set_operator_shares(
            delegation_manager, 
            operator, 
            strategy_id, 
            operator_strategy_shares - shares_to_decrease, 
            ctx
        );
        event::emit(OperatorSharesDecreased {
            operator,
            staker,
            strategy_id,
            shares_decreased: shares_to_decrease
        });
    }

    // View functions
    public fun is_delegated(delegation_manager: &DelegationManager, staker: address): bool {
        table::contains(&delegation_manager.delegated_to, staker)
    }

    public fun is_operator(delegation_manager: &DelegationManager, operator: address): bool {
        operator != @0x0 && 
        table::contains(&delegation_manager.delegated_to, operator) && 
        *table::borrow(&delegation_manager.delegated_to, operator) == operator
    }

    public fun get_deposit_scaling_factor_value(
        delegation_manager: &DelegationManager,
        staker: address,
        strategy_id: string::String,
        ctx: &mut TxContext
    ): u64 {
        let dsf = get_deposit_scaling_factor(delegation_manager, staker, strategy_id);
        slashing_lib_module::get_scaling_factor(dsf)
    }

    public fun get_operator_shares(
        delegation_manager: &DelegationManager,
        operator: address,
        strategy_ids: vector<string::String>
    ): vector<u64> {
        let mut shares = vector::empty<u64>();

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            vector::push_back(&mut shares, get_operator_shares_impl(delegation_manager, operator, strategy_id));
            i = i + 1;
        };

        shares
    }

    public fun get_all_operator_shares(
        delegation_manager: &DelegationManager,
        operators: vector<address>,
        strategy_ids: vector<string::String>
    ): vector<vector<u64>> {
        let mut shares = vector::empty<vector<u64>>();

        let mut i = 0;
        let len = vector::length(&operators);
        while (i < len) {
            let operator = *vector::borrow(&operators, i);
            let operator_shares = get_operator_shares(delegation_manager, operator, strategy_ids);
            vector::push_back(&mut shares, operator_shares);
            i = i + 1;
        };

        shares
    }

    public fun get_withdrawable_shares(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        strategy_manager: &StrategyManager,
        staker: address,
        strategy_ids: vector<string::String>
    ): (vector<u64>, vector<u64>) {
        if (!table::contains(&delegation_manager.delegated_to, staker)) {
            let shares = strategy_manager_module::get_all_staker_shares(
                strategy_manager,
                strategy_ids,
                staker
            );
            return (shares, shares);
        };

        let mut withdrawable_shares = vector::empty<u64>();
        let mut deposit_shares = vector::empty<u64>();

        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, operator, strategy_ids, 0);

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let shares = strategy_manager_module::get_staker_shares(
                strategy_manager,
                strategy_id,
                staker
            );
            vector::push_back(&mut deposit_shares, shares);

            let dsf = get_deposit_scaling_factor(delegation_manager, staker, strategy_id);
            let withdrawable = slashing_lib_module::calc_withdrawable(dsf, shares, *vector::borrow(&slashing_factors, i));
            vector::push_back(&mut withdrawable_shares, withdrawable);
            i = i + 1;
        };

        (withdrawable_shares, deposit_shares)
    }

    public fun queued_withdrawals(
        delegation_manager: &DelegationManager,
        withdrawal_root: vector<u8>
    ): Withdrawal {
        *table::borrow(&delegation_manager.queued_withdrawals, withdrawal_root)
    }

    public fun get_queued_withdrawal(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        withdrawal_root: vector<u8>,
        ctx: &mut TxContext
    ): (Withdrawal, vector<u64>) {
        let withdrawal = *table::borrow(&delegation_manager.queued_withdrawals, withdrawal_root);
        let shares = get_shares_by_withdrawal(delegation_manager, allocation_manager, withdrawal, ctx);
        (withdrawal, shares)
    }

    public fun get_queued_withdrawals(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        ctx: &mut TxContext
    ): (vector<Withdrawal>, vector<vector<u64>>) {
        let withdrawal_roots = get_queued_withdrawal_roots(delegation_manager, staker);
        
        let mut withdrawals = vector::empty<Withdrawal>();
        let mut shares = vector::empty<vector<u64>>();

        let mut i = 0;
        let len = vector::length(&withdrawal_roots);
        while (i < len) {
            let root = *vector::borrow(&withdrawal_roots, i);
            let (withdrawal, share) = get_queued_withdrawal(delegation_manager, allocation_manager, root, ctx);
            vector::push_back(&mut withdrawals, withdrawal);
            vector::push_back(&mut shares, share);
            i = i + 1;
        };

        (withdrawals, shares)
    }

    public fun get_queued_withdrawal_roots(
        delegation_manager: &DelegationManager,
        staker: address
    ): vector<vector<u8>> {
        *table::borrow(&delegation_manager.staker_queued_withdrawal_roots, staker)
    }

    public fun convert_to_deposit_shares(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        strategy_ids: vector<string::String>,
        withdrawable_shares: vector<u64>,
        ctx: &mut TxContext
    ): vector<u64> {
        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factors = allocation_module::get_max_magnitudes(allocation_manager, operator, strategy_ids, 0);

        let mut deposit_shares = vector::empty<u64>();

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let dsf = get_deposit_scaling_factor(delegation_manager, staker, strategy_id);
            let deposit = slashing_lib_module::calc_deposit_shares(
                dsf,
                *vector::borrow(&withdrawable_shares, i),
                *vector::borrow(&slashing_factors, i)
            );
            vector::push_back(&mut deposit_shares, deposit);
            i = i + 1;
        };

        deposit_shares
    }

    // Helper functions
    fun calculate_withdrawal_root(
        withdrawal: &Withdrawal
    ): vector<u8> {
        let mut root = vector::empty<u8>();
        vector::append(&mut root, bcs::to_bytes<address>(&withdrawal.staker));
        vector::append(&mut root, bcs::to_bytes<address>(&withdrawal.delegated_to));
        vector::append(&mut root, bcs::to_bytes<address>(&withdrawal.withdrawer));
        vector::append(&mut root, bcs::to_bytes<u64>(&withdrawal.nonce));
        vector::append(&mut root, bcs::to_bytes<u64>(&withdrawal.start_block));
        root
    }

    fun get_shares_by_withdrawal(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        withdrawal: Withdrawal,
        ctx: &mut TxContext
    ): vector<u64> {
        let mut shares = vector::empty<u64>();
        let slashable_until = withdrawal.start_block + delegation_manager.min_withdrawal_delay;

        let slashing_factors = if (slashable_until < tx_context::epoch(ctx)) {
            allocation_module::get_max_magnitudes(allocation_manager, withdrawal.delegated_to, withdrawal.strategy_ids, slashable_until)
        } else {
            allocation_module::get_max_magnitudes(allocation_manager, withdrawal.delegated_to, withdrawal.strategy_ids, 0)
        };

        let mut i = 0;
        let len = vector::length(&withdrawal.strategy_ids);
        while (i < len) {
            let scaled_shares = *vector::borrow(&withdrawal.scaled_shares, i);
            let slashing_factor = *vector::borrow(&slashing_factors, i);
            vector::push_back(
                &mut shares,
                slashing_lib_module::scale_for_complete_withdrawal(scaled_shares, slashing_factor)
            );
            i = i + 1;
        };

        shares
    }

    fun get_deposit_scaling_factor(
        delegation_manager: &DelegationManager,
        staker: address,
        strategy_id: string::String
    ): &DepositScalingFactor {
        let staker_factors = table::borrow(&delegation_manager.deposit_scaling_factors, staker);
        table::borrow(staker_factors, strategy_id)
    }

    fun get_deposit_scaling_factor_mut(
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_id: string::String
    ): &mut DepositScalingFactor {
        let mut staker_factors = table::borrow_mut(&mut delegation_manager.deposit_scaling_factors, staker);
        table::borrow_mut(staker_factors, strategy_id)
    }

    fun reset_deposit_scaling_factor(
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_id: string::String
    ) {
        if (table::contains(&delegation_manager.deposit_scaling_factors, staker)) {
            let staker_factors = table::borrow_mut(&mut delegation_manager.deposit_scaling_factors, staker);
            if (table::contains(staker_factors, strategy_id)) {
                let mut dsf = table::borrow_mut(staker_factors, strategy_id);
                slashing_lib_module::reset(dsf);
            };
        };
    }

    fun get_operator_shares_impl(
        delegation_manager: &DelegationManager,
        operator: address,
        strategy_id: string::String
    ): u64 {
        if (!table::contains(&delegation_manager.operator_shares, operator)) {
            return 0;
        };
        let operator_strategies = table::borrow(&delegation_manager.operator_shares, operator);
        if (!table::contains(operator_strategies, strategy_id)) {
            return 0;
        };
        *table::borrow(operator_strategies, strategy_id)
    }

    fun set_operator_shares(
        delegation_manager: &mut DelegationManager,
        operator: address,
        strategy_id: string::String,
        shares: u64,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&mut delegation_manager.operator_shares, operator)) {
            table::add(&mut delegation_manager.operator_shares, operator, table::new<string::String, u64>(ctx));
        };
        let operator_strategies = table::borrow_mut(&mut delegation_manager.operator_shares, operator);
        if (!table::contains(operator_strategies, strategy_id)) {
            table::add(operator_strategies, strategy_id, 0);
        };
        let prev_shares = table::borrow_mut(operator_strategies, strategy_id);
        *prev_shares = shares;
    }

    fun check_can_call(
        operator: address,
        ctx: &mut TxContext
    ): bool {
        tx_context::sender(ctx) == operator
    }

    fun check_not_paused(delegation_manager: &DelegationManager) {
        assert!(!delegation_manager.is_paused, E_PAUSED);
    }
}