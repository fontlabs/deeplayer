// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
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

    use deeplayer::coin_utils_module;
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

    public struct DepositScalingFactor has store {
        scaling_factor: u64,
        last_update_block: u64,
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

        let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);

        let (staker, strategy_id, prev_deposit_shares, added_shares) = strategy_manager_module::deposit_into_strategy<CoinType>(
            strategy,
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
        );
    }

    // Public functions
    public entry fun register_as_operator(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &StrategyManager,
        allocation_manager: &AllocationManager,
        metadata_uri: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(!is_delegated(delegation_manager, sender), E_ACTIVELY_DELEGATED);

        let operator_details = OperatorDetails {
            metadata_uri: string::utf8(metadata_uri),
        };

        table::add(&mut delegation_manager.operator_details, sender, operator_details);

        // Delegate from the operator to themselves
        delegate(delegation_manager, strategy_manager, allocation_manager, sender, sender, ctx);

        event::emit(OperatorRegistered {
            operator: sender,
        });

        event::emit(OperatorMetadataURIUpdated {
            operator: sender,
            metadata_uri: string::utf8(metadata_uri),
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

    public entry fun delegate_to(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &StrategyManager,
        allocation_manager: &AllocationManager,
        operator: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        assert!(!is_delegated(delegation_manager, sender), E_ACTIVELY_DELEGATED);
        assert!(is_operator(delegation_manager, operator), E_OPERATOR_NOT_REGISTERED);

        // Delegate sender to the operator
        delegate(delegation_manager, strategy_manager, allocation_manager, sender, operator, ctx);
    }

    public entry fun undelegate(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        staker: address,
        ctx: &mut TxContext
    ) {
        assert!(is_delegated(delegation_manager, staker), E_NOT_ACTIVELY_DELEGATED);
        assert!(!is_operator(delegation_manager, staker), E_OPERATORS_CANNOT_UNDELEGATE);

        let sender = tx_context::sender(ctx);

        if (sender != staker) {
            let operator = *table::borrow(&delegation_manager.delegated_to, staker);
            assert!(check_can_call(operator, ctx),E_CALLER_CANNOT_UNDELEGATE);

            event::emit(StakerForceUndelegated {
                staker,
                operator
            });
        };

        undelegate_impl(delegation_manager, strategy_manager, allocation_manager, staker, ctx);
    }

    public entry fun redelegate(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
        new_operator: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        undelegate_impl(delegation_manager, strategy_manager, allocation_manager, tx_context::sender(ctx), ctx);
        delegate_to(delegation_manager, strategy_manager, allocation_manager, new_operator, the_clock, ctx);
    }

    public entry fun queue_withdrawals(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
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

        let slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            sender,
            operator,
            strategy_ids
        );

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
        let prev_slashing_factors = get_slashing_factors_at_block(
            delegation_manager,
            allocation_manager,
            withdrawal.staker,
            withdrawal.delegated_to,
            withdrawal.strategy_ids,
            slashable_until
        );

        // Get current slashing factors for redeposit
        let new_operator = *table::borrow(&delegation_manager.delegated_to, withdrawal.staker);
        let new_slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            withdrawal.staker,
            new_operator,
            withdrawal.strategy_ids
        );

        // Process each strategy
        let mut i = 0;
        let len = vector::length(&withdrawal.strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&withdrawal.strategy_ids, i);
            let scaled_shares = *vector::borrow(&withdrawal.scaled_shares, i);
            let prev_slashing_factor = *vector::borrow(&prev_slashing_factors, i);
            let new_slashing_factor = *vector::borrow(&new_slashing_factors, i);

            let shares_to_withdraw = scale_for_complete_withdrawal(
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
        let max_magnitude = allocation_module::get_max_magnitude(allocation_manager, operator, strategy_id, 0);

        let slashing_factor = get_slashing_factor(
            delegation_manager,
            staker,
            strategy_id,
            max_magnitude
        );

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

        let operator_shares_slashed = calc_slashed_amount(
            operator_shares,
            prev_max_magnitude,
            new_max_magnitude
        );

        let scaled_shares_slashed_from_queue = get_slashable_shares_in_queue_impl(
            delegation_manager,
            operator,
            strategy_id,
            prev_max_magnitude,
            new_max_magnitude
        );

        let total_deposit_shares_to_burn = operator_shares_slashed + scaled_shares_slashed_from_queue;

        decrease_delegation(delegation_manager, operator, @0x0, strategy_id, operator_shares_slashed, ctx);

        event::emit(OperatorSharesSlashed {
            operator,
            strategy_id,
            total_deposit_shares_to_burn,
        });

        // Increase burnable shares in strategy manager
        strategy_manager_module::increase_burnable_shares<CoinType>(
            strategy_manager,
            strategy, 
            total_deposit_shares_to_burn
        );
    }

    // Internal functions
    fun delegate(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &StrategyManager,
        allocation_manager: &AllocationManager,
        staker: address,
        operator: address,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);
        
        // Get staker's deposited strategy_ids and shares
        let (strategy_ids, withdrawable_shares) = strategy_manager_module::get_deposits(strategy_manager, staker);
        
        // Get slashing factors
        let slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            @0x0,
            operator,
            strategy_ids
        );

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
            let mut shares = *vector::borrow(&withdrawable_shares, i);

            increase_delegation(
                delegation_manager,
                operator,
                staker,
                strategy_id ,
                0, // prev_deposit_shares
                shares,
                *vector::borrow(&slashing_factors, i),
                ctx
            );

            i = i + 1;
        };
    }

    fun undelegate_impl(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &mut StrategyManager,
        allocation_manager: &AllocationManager,
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
        let slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            staker,
            operator,
            strategy_ids
        );

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

            let dsf = get_deposit_scaling_factor(
                delegation_manager, 
                staker, 
                strategy_id,
                ctx
            );
            let withdrawable = calc_withdrawable(dsf, deposit_shares, slashing_factor);
            vector::push_back(&mut withdrawable_shares, withdrawable);

            let scaled = scale_for_queue_withdrawal(dsf, deposit_shares);
            vector::push_back(&mut scaled_shares, scaled);

            if (operator != @0x0) {
                add_queued_slashable_shares(
                    delegation_manager,
                    operator,
                    strategy_id,
                    scaled
                );

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

        // Update deposit scaling factor
        let dsf = get_deposit_scaling_factor(
            delegation_manager,
            staker, 
            strategy_id,
            ctx
        );

        // dsf.scaling_factor = (prev_deposit_shares * dsf.scaling_factor + added_shares * WAD) / 
        //                     (prev_deposit_shares + added_shares);
        // dsf.last_update_block = tx_context::epoch(ctx);

        event::emit(DepositScalingFactorUpdated {
            staker,
            strategy_id,
            scaling_factor: dsf.scaling_factor,
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

    public fun deposit_scaling_factor(
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_id: string::String,
        ctx: &mut TxContext
    ): u64 {
        let dsf = get_deposit_scaling_factor(
            delegation_manager, 
            staker, 
            strategy_id,
            ctx
        );
        dsf.scaling_factor
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
            let strategy_id  = *vector::borrow(&strategy_ids, i);
            vector::push_back(&mut shares, get_operator_shares_impl(delegation_manager, operator, strategy_id));
            i = i + 1;
        };
        shares
    }

    public fun get_slashable_shares_in_queue(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        operator: address,
        strategy_id: string::String
    ): u64 {
        let max_magnitude = allocation_module::get_max_magnitude(allocation_manager, operator, strategy_id, 0);
        get_slashable_shares_in_queue_impl(delegation_manager, operator, strategy_id, max_magnitude, 0)
    }

    public fun get_withdrawable_shares(
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        strategy_manager: &StrategyManager,
        staker: address,
        strategy_ids: vector<string::String>,
        ctx: &mut TxContext
    ): (vector<u64>, vector<u64>) {
        let mut withdrawable_shares = vector::empty<u64>();
        let mut deposit_shares = vector::empty<u64>();

        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factors = get_slashing_factors(delegation_manager, allocation_manager, staker, operator, strategy_ids);

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

            let dsf = get_deposit_scaling_factor(delegation_manager, staker, strategy_id, ctx);
            let withdrawable = calc_withdrawable(dsf, shares, *vector::borrow(&slashing_factors, i));
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
        let shares = get_shares_by_withdrawal_root(delegation_manager, allocation_manager, withdrawal, ctx);
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
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        strategy_ids: vector<string::String>,
        withdrawable_shares: vector<u64>,
        ctx: &mut TxContext
    ): vector<u64> {
        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factors = get_slashing_factors(delegation_manager, allocation_manager, staker, operator, strategy_ids);

        let mut deposit_shares = vector::empty<u64>();
        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let dsf = get_deposit_scaling_factor( delegation_manager, staker, strategy_id, ctx);
            let deposit = calc_deposit_shares(
                dsf,
                *vector::borrow(&withdrawable_shares, i),
                *vector::borrow(&slashing_factors, i)
            );
            vector::push_back(&mut deposit_shares, deposit);
            i = i + 1;
        };
        deposit_shares
    }

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

    // Helper functions
    fun get_slashing_factor(
        delegation_manager: &DelegationManager,
        staker: address,
        strategy_id: string::String,
        operator_max_magnitude: u64
    ): u64 {
        operator_max_magnitude
    }

    fun get_slashing_factors(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        operator: address,
        strategy_ids: vector<string::String>
    ): vector<u64> {
        let mut slashing_factors = vector::empty<u64>();
        let max_magnitudes = allocation_module::get_max_magnitudes(allocation_manager, operator, strategy_ids, 0);

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let max_magnitude = *vector::borrow(&max_magnitudes, i);
            vector::push_back(
                &mut slashing_factors,
                get_slashing_factor(delegation_manager, staker, strategy_id, max_magnitude)
            );
            i = i + 1;
        };
        slashing_factors
    }

    fun get_slashing_factors_at_block(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        operator: address,
        strategy_ids: vector<string::String>,
        block_number: u64
    ): vector<u64> {
        let mut slashing_factors = vector::empty<u64>();
        let max_magnitudes = allocation_module::get_max_magnitudes(allocation_manager, operator, strategy_ids, block_number);

        let mut i = 0;
        let len = vector::length(&strategy_ids);
        while (i < len) {
            let strategy_id = *vector::borrow(&strategy_ids, i);
            let max_magnitude = *vector::borrow(&max_magnitudes, i);
            vector::push_back(
                &mut slashing_factors,
                get_slashing_factor(delegation_manager, staker, strategy_id, max_magnitude)
            );
            i = i + 1;
        };
        slashing_factors
    }

    fun get_slashable_shares_in_queue_impl(
        delegation_manager: &DelegationManager,
        operator: address,
        strategy_id: string::String,
        prev_max_magnitude: u64,
        new_max_magnitude: u64
    ): u64 {
        // In Sui Move, we'd need to implement the cumulative shares history tracking
        // This is a simplified version
        0 // Placeholder
    }

    fun add_queued_slashable_shares(
        delegation_manager: &mut DelegationManager,
        operator: address,
        strategy_id: string::String,
        scaled_shares: u64
    ) {
        // In Sui Move, we'd need to update the cumulative shares history
        // This is a simplified version
    }

    fun get_shares_by_withdrawal_root(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        withdrawal: Withdrawal,
        ctx: &mut TxContext
    ): vector<u64> {
        let mut shares = vector::empty<u64>();
        let slashable_until = withdrawal.start_block + delegation_manager.min_withdrawal_delay;

        let slashing_factors = if (slashable_until < tx_context::epoch(ctx)) {
            get_slashing_factors_at_block(
                delegation_manager,
                allocation_manager,
                withdrawal.staker,
                withdrawal.delegated_to,
                withdrawal.strategy_ids,
                slashable_until
            )
        } else {
            get_slashing_factors(
                delegation_manager,
                allocation_manager,
                withdrawal.staker,
                withdrawal.delegated_to,
                withdrawal.strategy_ids
            )
        };

        let mut i = 0;
        let len = vector::length(&withdrawal.strategy_ids);
        while (i < len) {
            let scaled_shares = *vector::borrow(&withdrawal.scaled_shares, i);
            let slashing_factor = *vector::borrow(&slashing_factors, i);
            vector::push_back(
                &mut shares,
                scale_for_complete_withdrawal(scaled_shares, slashing_factor)
            );
            i = i + 1;
        };

        shares
    }

    fun get_deposit_scaling_factor(
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_id: string::String,
        ctx: &mut TxContext
    ): &mut DepositScalingFactor {
        if (!table::contains(&delegation_manager.deposit_scaling_factors, staker)) {
            table::add(&mut delegation_manager.deposit_scaling_factors, staker, table::new<string::String, DepositScalingFactor>(ctx));
        };
        let staker_factors = table::borrow_mut(&mut delegation_manager.deposit_scaling_factors, staker);
        if (!table::contains(staker_factors, strategy_id)) {
            table::add(staker_factors, strategy_id, DepositScalingFactor {
                scaling_factor: WAD,
                last_update_block: 0,
            });
        };
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
                let dsf = table::borrow_mut(staker_factors, strategy_id);
                dsf.scaling_factor = WAD;
                dsf.last_update_block = 0;
            };
        };
    }

    fun calc_withdrawable(
        dsf: &DepositScalingFactor,
        deposit_shares: u64,
        slashing_factor: u64
    ): u64 {
        deposit_shares * dsf.scaling_factor * slashing_factor / (WAD * WAD)
    }

    fun calc_deposit_shares(
        dsf: &DepositScalingFactor,
        withdrawable_shares: u64,
        slashing_factor: u64
    ): u64 {
        withdrawable_shares * WAD * WAD / (dsf.scaling_factor * slashing_factor)
    }

    fun scale_for_queue_withdrawal(
        dsf: &DepositScalingFactor,
        deposit_shares: u64
    ): u64 {
        deposit_shares * WAD / dsf.scaling_factor
    }

    fun scale_for_complete_withdrawal(
        scaled_shares: u64,
        slashing_factor: u64
    ): u64 {
        scaled_shares * slashing_factor / WAD
    }

    fun calc_slashed_amount(
        operator_shares: u64,
        prev_max_magnitude: u64,
        new_max_magnitude: u64
    ): u64 {
        operator_shares * (prev_max_magnitude - new_max_magnitude) / prev_max_magnitude
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
        table::add(operator_strategies, strategy_id, shares);
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