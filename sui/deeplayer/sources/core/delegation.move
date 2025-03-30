// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::delegation_module {
    use std::option;
    use std::string;
    use std::vector;
    use std::clock;
    use sui::balance;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::table;
    use sui::tx_context::{Self, TxContext};
    use sui::bcs;

    use deeplayer::signature;
    use deeplayer::allocation_module::{Self, AllocationManager};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};

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

    // Structs
    public struct OperatorDetails has store {
        delegation_approver: address,
        metadata_uri: string::String,
    }

    public struct DepositScalingFactor has store {
        scaling_factor: u64,
        last_update_block: u64,
    }

    public struct SignatureWithExpiry has store {
        signature: vector<u8>,
        expiry: u64,
    }

    public struct Withdrawal has store, drop {
        staker: address,
        delegated_to: address,
        withdrawer: address,
        nonce: u64,
        start_block: u64,
        strategies: vector<address>,
        scaled_shares: vector<u64>,
    }

    public struct QueuedWithdrawalParams has store {
        strategies: vector<address>,
        deposit_shares: vector<u64>,
    }

    public struct DelegationManager has key {
        id: UID,
        min_withdrawal_delay: u64,
        is_paused: bool,
        operator_details: table::Table<address, OperatorDetails>,
        delegated_to: table::Table<address, address>,
        operator_shares: table::Table<address, table::Table<address, u64>>,
        deposit_scaling_factors: table::Table<address, table::Table<address, DepositScalingFactor>>,
        pending_withdrawals: table::Table<vector<u8>, bool>,
        queued_withdrawals: table::Table<vector<u8>, Withdrawal>,
        staker_queued_withdrawal_roots: table::Table<address, vector<vector<u8>>>,
        delegation_approver_salt_spent: table::Table<address, table::Table<vector<u8>, bool>>,
        cumulative_withdrawals_queued: table::Table<address, u64>,
    }

    // Events
    public struct OperatorRegistered has copy, drop {
        operator: address,
        delegation_approver: address,
    }

    public struct OperatorMetadataURIUpdated has copy, drop {
        operator: address,
        metadata_uri: string::String,
    }

    public struct DelegationApproverUpdated has copy, drop {
        operator: address,
        new_delegation_approver: address,
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
        strategy_address: address,
        added_shares: u64,
    }

    public struct OperatorSharesDecreased has copy, drop {
        operator: address,
        staker: address,
        strategy_address: address,
        shares_decreased: u64,
    }

    public struct OperatorSharesSlashed has copy, drop {
        operator: address,
        strategy_address: address,
        total_deposit_shares_to_burn: u64,
    }

    public struct DepositScalingFactorUpdated has copy, drop {
        staker: address,
        strategy_address: address,
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
            operator_shares: table::new<address, table::Table<address, u64>>(ctx),
            deposit_scaling_factors: table::new<address, table::Table<address, DepositScalingFactor>>(ctx),
            pending_withdrawals: table::new<vector<u8>, bool>(ctx),
            queued_withdrawals: table::new<vector<u8>, Withdrawal>(ctx),
            staker_queued_withdrawal_roots: table::new<address, vector<vector<u8>>>(ctx),
            delegation_approver_salt_spent: table::new<address, table::Table<vector<u8>, bool>>(ctx),
            cumulative_withdrawals_queued: table::new<address, u64>(ctx),
        };

        transfer::share_object(delegation_manager);
    }

    // Public functions
    public entry fun register_as_operator(
        delegation_manager: &mut DelegationManager,
        allocation_manager, &AllocationManager,
        init_delegation_approver: address,
        allocation_delay: u64,
        metadata_uri: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(!is_delegated(delegation_manager, sender), E_ACTIVELY_DELEGATED);

        allocation_module::set_allocation_delay(sender, allocation_delay);

        let operator_details = OperatorDetails {
            delegation_approver: init_delegation_approver,
            metadata_uri: string::utf8(metadata_uri),
        };
        table::add(&mut delegation_manager.operator_details, sender, operator_details);

        // Delegate from the operator to themselves
        delegate(delegation_manager, allocation_manager, sender, sender, ctx);

        event::emit(OperatorRegistered {
            operator: sender,
            delegation_approver: init_delegation_approver,
        });
        event::emit(OperatorMetadataURIUpdated {
            operator: sender,
            metadata_uri: string::utf8(metadata_uri),
        });
    }

    public entry fun modify_operator_details(
        delegation_manager: &mut DelegationManager,
        operator: address,
        new_delegation_approver: address,
        ctx: &mut TxContext
    ) {
        check_can_call(delegation_manager, operator, ctx);
        assert!(is_operator(delegation_manager, operator), E_OPERATOR_NOT_REGISTERED);
        set_delegation_approver(delegation_manager, operator, new_delegation_approver);
    }

    public entry fun update_operator_metadata_uri(
        delegation_manager: &mut DelegationManager,
        operator: address,
        metadata_uri: vector<u8>,
        ctx: &mut TxContext
    ) {
        check_can_call(delegation_manager, operator, ctx);
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
        allocation_manager: &AllocationManager,
        operator: address,
        signature: &SignatureWithExpiry,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        assert!(!is_delegated(delegation_manager, sender), E_ACTIVELY_DELEGATED);
        assert!(is_operator(delegation_manager, operator), E_OPERATOR_NOT_REGISTERED);

        // Check approver signature
        check_approver_signature(
            delegation_manager,
            sender,
            operator,
            signature,
            the_clock,
            ctx
        );

        // Delegate sender to the operator
        delegate(delegation_manager, allocation_manager, sender, operator, ctx);
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
            assert!(
                check_can_call(delegation_manager, operator, ctx) || 
                sender == delegation_approver(delegation_manager, operator),
                E_CALLER_CANNOT_UNDELEGATE
            );

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
        new_operator_approver_sig: SignatureWithExpiry,
        approver_salt: vector<u8>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        undelegate_impl(delegation_manager, strategy_manager, allocation_manager, tx_context::sender(ctx), ctx);
        delegate_to(
            delegation_manager, 
            new_operator, 
            new_operator_approver_sig, 
            approver_salt, 
            the_clock,
            ctx
        );
    }

    public entry fun queue_withdrawals(
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        strategy_manager: &StrategyManager,
        strategy_factory: &StrategyFactory,
        params: vector<QueuedWithdrawalParams>,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);

        let sender = tx_context::sender(ctx);
        let operator = *table::borrow(&delegation_manager.delegated_to, sender);

        let i = 0;
        let len = vector::length(&params);
        while (i < len) {
            let param = vector::borrow(&params, i);
            assert!(
                vector::length(&param.strategies) == vector::length(&param.deposit_shares),
                E_INPUT_ARRAY_LENGTH_MISMATCH
            );

            let slashing_factors = get_slashing_factors(
                delegation_manager,
                allocation_manager,
                sender,
                operator,
                &param.strategies
            );

            remove_shares_and_queue_withdrawal(
                delegation_manager,
                strategy_manager,
                strategy_factory,
                sender,
                operator,
                &param.strategies,
                &param.deposit_shares,
                &slashing_factors,
                ctx
            );

            i = i + 1;
        }
    }

    public entry fun complete_queued_withdrawal<COIN>(
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        strategy_factory: &mut StrategyFactory,
        strategy_manager: &StrategyManager,
        withdrawal: &Withdrawal,
        receive_as_coins: bool,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);

        assert!(
            tx_context::sender(ctx) == withdrawal.withdrawer,
            E_WITHDRAWER_NOT_CALLER
        );

        let withdrawal_root = calculate_withdrawal_root(&withdrawal);
        assert!(
            *table::borrow(&delegation_manager.pending_withdrawals, withdrawal_root),
            E_WITHDRAWAL_NOT_QUEUED
        );

        assert!(
            vector::length(&withdrawal.strategies) == vector::length(&coin_types),
            E_INPUT_ARRAY_LENGTH_MISMATCH
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
        let staker_roots = table::borrow_mut(&mut delegation_manager.staker_queued_withdrawal_roots, &withdrawal.staker);
        let i = 0;
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
            &withdrawal.strategies,
            slashable_until
        );

        // Get current slashing factors for redeposit
        let new_operator = *table::borrow(&delegation_manager.delegated_to, withdrawal.staker);
        let new_slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            withdrawal.staker,
            new_operator,
            &withdrawal.strategies
        );

        // Process each strategy
        let i = 0;
        let len = vector::length(&withdrawal.strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(&withdrawal.strategies, i);
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

            if (receive_as_coins) {
                strategy_manager_module::withdraw_shares_as_coins<COIN>(
                    strategy_factory,
                    withdrawal.staker,
                    shares_to_withdraw,
                    ctx
                );
            } else {
                let (prev_deposit_shares, added_shares) = strategy_manager_module::add_shares(
                    strategy_manager,
                    withdrawal.staker,
                    strategy_address,
                    shares_to_withdraw,
                    ctx
                )

                increase_delegation(
                    delegation_manager,
                    new_operator,
                    withdrawal.staker,
                    strategy_address,
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
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        strategy_address: address,
        prev_deposit_shares: u64,
        added_shares: u64,
        ctx: &mut TxContext
    ) {      
        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let max_magnitude = allocation_module::get_max_magnitude(allocation_manager, operator, strategy_address);

        let slashing_factor = get_slashing_factor(
            delegation_manager,
            staker,
            strategy_address,
            max_magnitude
        );

        increase_delegation(
            delegation_manager,
            operator,
            staker,
            strategy_address,
            prev_deposit_shares,
            added_shares,
            slashing_factor,
            ctx
        );
    }

    public(package) fun slash_operator_shares(
        delegation_manager: &mut DelegationManager,
        operator: address,
        strategy_address: address,
        prev_max_magnitude: u64,
        new_max_magnitude: u64,
        ctx: &mut TxContext
    ) {             
        let operator_shares = get_operator_shares_impl(
            delegation_manager, 
            operator, 
            strategy_address
        );

        let operator_shares_slashed = calc_slashed_amount(
            operator_shares,
            prev_max_magnitude,
            new_max_magnitude
        );

        let scaled_shares_slashed_from_queue = get_slashable_shares_in_queue_impl(
            delegation_manager,
            operator,
            strategy_address,
            prev_max_magnitude,
            new_max_magnitude
        );

        let total_deposit_shares_to_burn = operator_shares_slashed + scaled_shares_slashed_from_queue;

        decrease_delegation(
            delegation_manager,
            operator,
            @0x0, // zero address
            strategy_address,
            operator_shares_slashed
        );

        event::emit(OperatorSharesSlashed {
            operator,
            strategy_address,
            total_deposit_shares_to_burn,
        });

        // Increase burnable shares in strategy manager
        strategy_manager_module::increase_burnable_shares<COIN>(
            strategy_manager,
            strategy_address, 
            total_deposit_shares_to_burn, 
            ctx
        );
    }

    // Internal functions
    fun set_delegation_approver(
        delegation_manager: &mut DelegationManager,
        operator: address,
        new_delegation_approver: address
    ) {
        let operator_details = table::borrow_mut(&mut delegation_manager.operator_details, operator);
        operator_details.delegation_approver = new_delegation_approver;
        event::emit(DelegationApproverUpdated {
            operator,
            new_delegation_approver,
        });
    }

    fun delegate(
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        operator: address,
        ctx: &mut TxContext
    ) {
        check_not_paused(delegation_manager);
        
        // Get staker's deposited strategies and shares
        let (strategies, withdrawable_shares) = get_deposited_shares(delegation_manager, staker);
        
        // Get slashing factors
        let slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            @0x0, // zero address
            operator,
            &strategies
        );

        // Delegate to operator
        table::add(&mut delegation.delegated_to, staker, operator);
        event::emit(StakerDelegated {
            staker,
            operator,
        });

        let i = 0;
        let len = vector::length(&strategies);
        while (i < len) {
            let strategy = *vector::borrow(&strategies, i);
            let mut shares = *vector::borrow(&withdrawable_shares, i);

            increase_delegation(
                delegation_manager,
                operator,
                staker,
                strategy,
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
        check_not_paused(delegation_manager, PAUSED_ENTER_WITHDRAWAL_QUEUE);
        
        let operator = *table::remove(&mut delegation_manager.delegated_to, staker);
        event::emit(StakerUndelegated {
            staker,
            operator,
        });

        // Get all staker's deposited strategies/shares
        let (strategies, deposited_shares) = get_deposited_shares(delegation_manager, staker);
        if (vector::is_empty(&strategies)) {
            return;
        };

        // Get slashing factors
        let slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager,
            staker,
            operator,
            &strategies
        );

        // Queue withdrawals for each strategy
        let i = 0;
        let len = vector::length(&strategies);
        while (i < len) {
            let single_strategy_address = vector[vector::borrow(&strategies, i)];
            let single_deposit_shares = vector[vector::borrow(&deposited_shares, i)];
            let single_slashing_factor = vector[vector::borrow(&slashing_factors, i)];

            remove_shares_and_queue_withdrawal(
                delegation_manager,
                strategy_manager,
                strategy_factory,
                staker,
                operator,
                &single_strategy_address,
                &single_deposit_shares,
                &single_slashing_factor,
                ctx
            );

            i = i + 1;
        };
    }

    fun remove_shares_and_queue_withdrawal(
        delegation_manager: &mut DelegationManager,
        strategy_manager: &mut StrategyManager,
        strategy_factory: &StrategyFactory,
        staker: address,
        operator: address,
        strategies: &vector<address>,
        deposit_shares_to_withdraw: &vector<u64>,
        slashing_factors: &vector<u64>,
        ctx: &mut TxContext
    ) {
        assert!(staker != @0x0, E_INPUT_ADDRESS_ZERO);
        assert!(!vector::is_empty(strategies), E_INPUT_ARRAY_LENGTH_ZERO);

        let scaled_shares = vector::empty<u64>();
        let withdrawable_shares = vector::empty<u64>();

        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(strategies, i);
            let deposit_shares = *vector::borrow(deposit_shares_to_withdraw, i);
            let slashing_factor = *vector::borrow(slashing_factors, i);

            let dsf = get_deposit_scaling_factor(
                delegation_manager, 
                staker, 
                strategy_address,
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
                    strategy_address,
                    scaled
                );

                decrease_delegation(
                    delegation_manager,
                    operator,
                    staker,
                    strategy_address,
                    withdrawable
                );
            };

            // Remove deposit shares from strategy manager
               let shares_after = strategy_manager_module::remove_deposit_shares(
                strategy_manager,
                staker, 
                strategy_address, 
                deposit_shares, 
                ctx
            );

            if (shares_after == 0) {
                reset_deposit_scaling_factor(delegation_manager, staker, strategy_address);
            };

            i = i + 1;
        };

        // Create withdrawal
        let nonce = *table::borrow(&delegation_manager.cumulative_withdrawals_queued, staker);
        table::add(&mut delegation_manager.cumulative_withdrawals_queued, staker, nonce + 1);

        let withdrawal = Withdrawal {
            staker,
            delegated_to: operator,
            withdrawer: staker,
            nonce,
            start_block: tx_context::epoch(ctx),
            strategies: *strategies,
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
        strategy_address: address,
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
            strategy_address,
            ctx
        );
        update_deposit_scaling_factor(dsf, prev_deposit_shares, added_shares, slashing_factor, ctx);
        event::emit(DepositScalingFactorUpdated {
            staker,
            strategy_address,
            scaling_factor: dsf.scaling_factor,
        });

        // Update operator shares if staker is delegated
        if (is_delegated(delegation_manager, staker)) {
            let operator_strategy_shares = get_operator_shares_impl(delegation_manager, operator, strategy_address);
            set_operator_shares(
                delegation_manager, 
                operator, 
                strategy_address,
                operator_strategy_shares + added_shares,
                ctx
            );
            event::emit(OperatorSharesIncreased {
                operator,
                staker,
                strategy_address,
                added_shares,
            });
        };
    }

    fun decrease_delegation(
        delegation_manager: &mut DelegationManager,
        operator: address,
        staker: address,
        strategy_address: address,
        shares_to_decrease: u64
    ) {
        let operator_strategy_shares = get_operator_shares_impl(delegation_manager, operator, strategy_address);
        set_operator_shares(
            delegation_manager, 
            operator, 
            strategy_address, 
            operator_strategy_shares - shares_to_decrease, 
            ctx
        );
        event::emit(OperatorSharesDecreased {
            operator,
            staker,
            strategy_address,
            shares_decreased: shares_to_decrease
        });
    }

    fun check_approver_signature(
        delegation_manager: &mut DelegationManager,
        staker: address,
        operator: address,
        signature: SignatureWithSaltAndExpiry,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        let approver = delegation_approver(delegation_manager, operator);
        if (approver == @0x0) {
            return;
        };

        assert!(
            !is_salt_spent(delegation_manager, approver, signature.salt),
            E_SALT_SPENT
        );
        
        if (!table::contains(&delegation_manager.delegation_approver_salt_spent, approver)) {
            table::add(&mut delegation_manager.delegation_approver_salt_spent, approver, table::new<vector<u8>, bool>(ctx));
        };

        let approver_salts = table::borrow_mut(&mut delegation_manager.delegation_approver_salt_spent, approver);
        table::add(approver_salts, signature,salt, true);

        // Validate signature       
        let verify = signature_module::verify(
            &signature.signature, 
            approver, 
            the_clock,
            ctx
        );
        assert!(verify, E_INVALID_SIGNATURE);
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

    public fun delegation_approver(delegation_manager: &DelegationManager, operator: address): address {
        if (!table::contains(&delegation_manager.operator_details, operator)) {
            return @0x0;
        };
        let details = table::borrow(&delegation_manager.operator_details, operator);
        details.delegation_approver
    }

    public fun deposit_scaling_factor(
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_address: address,
        ctx: &mut TxContext
    ): u64 {
        let dsf = get_deposit_scaling_factor(
            delegation_manager, 
            staker, 
            strategy_address,
            ctx
        );
        dsf.scaling_factor
    }

    public fun get_operator_shares(
        delegation_manager: &DelegationManager,
        operator: address,
        strategies: &vector<address>
    ): vector<u64> {
        let shares = vector::empty<u64>();
        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            let strategy = *vector::borrow(strategies, i);
            vector::push_back(&mut shares, get_operator_shares_impl(delegation_manager, operator, strategy));
            i = i + 1;
        };
        shares
    }

    public fun get_slashable_shares_in_queue(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        operator: address,
        strategy_address: address
    ): u64 {
        let max_magnitude = allocation_module::get_max_magnitude(
            allocation_manager,
            operator, 
            strategy_address
        );

        get_slashable_shares_in_queue_impl(
            delegation_manager,
            operator,
            strategy_address,
            max_magnitude,
            0
        )
    }

    public fun get_withdrawable_shares(
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        strategy_manager: &StrategyManager,
        staker: address,
        strategies: &vector<address>,
        ctx: &mut TxContext
    ): (vector<u64>, vector<u64>) {
        let withdrawable_shares = vector::empty<u64>();
        let deposit_shares = vector::empty<u64>();

        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factors = get_slashing_factors(delegation_manager, allocation_manager, staker, operator, strategies);

        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(strategies, i);
            let shares = strategy_manager_module::staker_deposit_shares(
                strategy_manager,
                staker,
                strategy_address
            );
            vector::push_back(&mut deposit_shares, shares);

            let dsf = get_deposit_scaling_factor(
                delegation_manager, 
                staker, 
                strategy_address,
                ctx
            );
            let withdrawable = calc_withdrawable(dsf, shares, *vector::borrow(&slashing_factors, i));
            vector::push_back(&mut withdrawable_shares, withdrawable);

            i = i + 1;
        };

        (withdrawable_shares, deposit_shares)
    }

    public fun get_deposited_shares(
        strategy_manager: &StrategyManager,
        staker: address
    ): (vector<address>, vector<u64>) {
        strategy_manager_module::get_deposits(strategy_manager, staker)
    }

    public fun queued_withdrawals(
        delegation_manager: &DelegationManager,
        withdrawal_root: vector<u8>
    ): &Withdrawal {
        table::borrow(&delegation_manager.queued_withdrawals, withdrawal_root)
    }

    public fun get_queued_withdrawal(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        withdrawal_root: vector<u8>,
        ctx: &mut TxContext
    ): (Withdrawal, vector<u64>) {
        let withdrawal = table::borrow(&delegation_manager.queued_withdrawals, withdrawal_root);
        let shares = get_shares_by_withdrawal_root(
            delegation_manager, 
            allocation_manager, 
            withdrawal, 
            ctx
        );
        (withdrawal, shares)
    }

    public fun get_queued_withdrawals(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address
    ): (vector<Withdrawal>, vector<vector<u64>>) {
        let withdrawal_roots = get_queued_withdrawal_roots(delegation_manager, staker);
        let withdrawals = vector::empty<Withdrawal>();
        let shares = vector::empty<vector<u64>>();

        let i = 0;
        let len = vector::length(withdrawal_roots);
        while (i < len) {
            let root = vector::borrow(withdrawal_roots, i);
            let (withdrawal, share) = get_queued_withdrawal(
                delegation_manager, 
                allocation_manager, 
                root, 
                ctx
            );
            vector::push_back(&mut withdrawals, withdrawal);
            vector::push_back(&mut shares, share);
            i = i + 1;
        };

        (withdrawals, shares)
    }

    public fun get_queued_withdrawal_roots(
        delegation_manager: &DelegationManager,
        staker: address
    ): &vector<vector<u8>> {
        table::borrow(&delegation_manager.staker_queued_withdrawal_roots, staker)
    }

    public fun convert_to_deposit_shares(
        delegation_manager: &mut DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        strategies: &vector<address>,
        withdrawable_shares: &vector<u64>,
        ctx: &mut TxContext
    ): vector<u64> {
        let operator = *table::borrow(&delegation_manager.delegated_to, staker);
        let slashing_factors = get_slashing_factors(
            delegation_manager,
            allocation_manager, 
            staker, 
            operator,
            strategies
        );

        let deposit_shares = vector::empty<u64>();
        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(strategies, i);
            let dsf = get_deposit_scaling_factor(
                delegation_manager, 
                staker, 
                strategy_address,
                ctx
            );
            let deposit = calc_deposit_shares(
                dsf,
                *vector::borrow(withdrawable_shares, i),
                *vector::borrow(&slashing_factors, i)
            );
            vector::push_back(&mut deposit_shares, deposit);
            i = i + 1;
        };
        deposit_shares
    }

    public fun calculate_withdrawal_root(withdrawal: &Withdrawal): vector<u8> {
        let mut serialized = vector::empty<u8>();
        vector::append(&mut serialized, bcs::to_bytes<address>(withdraw.staker));
        vector::append(&mut serialized, bcs::to_bytes<address>(withdraw.delegated_to));
        vector::append(&mut serialized, bcs::to_bytes<address>(withdraw.withdrawer));
        vector::append(&mut serialized, bcs::to_bytes<u64>(withdraw.nonce));
        vector::append(&mut serialized, bcs::to_bytes<u64>(withdraw.start_block));
        serialized
    }

    public fun min_withdrawal_delay_blocks(delegation_manager: &DelegationManager): u64 {
        delegation_manager.min_withdrawal_delay
    }

    // Helper functions
    fun get_slashing_factor(
        delegation_manager: &DelegationManager,
        staker: address,
        strategy_address: address,
        operator_max_magnitude: u64
    ): u64 {
        operator_max_magnitude
    }

    fun get_slashing_factors(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        staker: address,
        operator: address,
        strategies: &vector<address>
    ): vector<u64> {
        let slashing_factors = vector::empty<u64>();
        let max_magnitudes = allocation_module::get_max_magnitudes(
            allocation_manager,
            operator,
            strategies
        );

        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            let strategy = *vector::borrow(strategies, i);
            let max_magnitude = *vector::borrow(&max_magnitudes, i);
            vector::push_back(
                &mut slashing_factors,
                get_slashing_factor(delegation_manager, staker, strategy, max_magnitude)
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
        strategies: &vector<address>,
        block_number: u64
    ): vector<u64> {
        let slashing_factors = vector::empty<u64>();
        let max_magnitudes = allocation_module::get_max_magnitudes_at_block(
            allocation_manager,
            operator, 
            strategies, 
            block_number
        );

        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            let strategy = *vector::borrow(strategies, i);
            let max_magnitude = *vector::borrow(&max_magnitudes, i);
            vector::push_back(
                &mut slashing_factors,
                get_slashing_factor(delegation_manager, staker, strategy, max_magnitude)
            );
            i = i + 1;
        };
        slashing_factors
    }

    fun get_slashable_shares_in_queue_impl(
        delegation_manager: &DelegationManager,
        operator: address,
        strategy_address: address,
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
        strategy_address: address,
        scaled_shares: u64
    ) {
        // In Sui Move, we'd need to update the cumulative shares history
        // This is a simplified version
    }

    fun get_shares_by_withdrawal_root(
        delegation_manager: &DelegationManager,
        allocation_manager: &AllocationManager,
        withdrawal: &Withdrawal,
        ctx: &mut TxContext
    ): vector<u64> {
        let shares = vector::empty<u64>();
        let slashable_until = withdrawal.start_block + delegation_manager.min_withdrawal_delay;

        let slashing_factors = if (slashable_until < tx_context::epoch(ctx)) {
            get_slashing_factors_at_block(
                delegation_manager,
                allocation_manager,
                withdrawal.staker,
                withdrawal.delegated_to,
                &withdrawal.strategies,
                slashable_until
            )
        } else {
            get_slashing_factors(
                delegation_manager,
                allocation_manager,
                withdrawal.staker,
                withdrawal.delegated_to,
                &withdrawal.strategies
            )
        };

        let i = 0;
        let len = vector::length(&withdrawal.strategies);
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
        strategy_address: address,
        ctx: &mut TxContext
    ): &mut DepositScalingFactor {
        if (!table::contains(&delegation_manager.deposit_scaling_factors, staker)) {
            table::add(&mut delegation_manager.deposit_scaling_factors, staker, table::new<address, DepositScalingFactor>(ctx));
        };
        let staker_factors = table::borrow_mut(&mut delegation_manager.deposit_scaling_factors, staker);
        if (!table::contains(staker_factors, strategy_address)) {
            table::add(staker_factors, strategy_address, DepositScalingFactor {
                scaling_factor: WAD,
                last_update_block: 0,
            });
        };
        table::borrow_mut(staker_factors, strategy_address)
    }

    fun reset_deposit_scaling_factor(
        delegation_manager: &mut DelegationManager,
        staker: address,
        strategy_address: address
    ) {
        if (table::contains(&delegation_manager.deposit_scaling_factors, staker)) {
            let staker_factors = table::borrow_mut(&mut delegation_manager.deposit_scaling_factors, staker);
            if (table::contains(staker_factors, strategy_address)) {
                let dsf = table::borrow_mut(staker_factors, strategy_address);
                dsf.scaling_factor = WAD;
                dsf.last_update_block = 0;
            };
        };
    }

    fun update_deposit_scaling_factor(
        dsf: &mut DepositScalingFactor,
        prev_deposit_shares: u64,
        added_shares: u64,
        slashing_factor: u64,
        ctx: &mut TxContext
    ) {
        dsf.scaling_factor = (prev_deposit_shares * dsf.scaling_factor + added_shares * WAD) / 
                            (prev_deposit_shares + added_shares);
        dsf.last_update_block = tx_context::epoch(ctx);
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
        strategy_address: address
    ): u64 {
        if (!table::contains(&delegation_manager.operator_shares, operator)) {
            return 0;
        };
        let operator_strategies = table::borrow(&delegation_manager.operator_shares, operator);
        if (!table::contains(operator_strategies, strategy_address)) {
            return 0;
        };
        *table::borrow(operator_strategies, strategy_address)
    }

    fun set_operator_shares(
        delegation_manager: &mut DelegationManager,
        operator: address,
        strategy_address: address,
        shares: u64,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&mut delegation_manager.operator_shares, operator)) {
            table::add(&mut delegation_manager.operator_shares, operator, table::new<address, u64>(ctx));
        };
        let operator_strategies = table::borrow_mut(&mut delegation_manager.operator_shares, operator);
        table::add(operator_strategies, strategy_address, shares);
    }

    fun is_salt_spent(
        delegation_manager: &DelegationManager,
        approver: address,
        salt: vector<u8>
    ): bool {
        if (!table::contains(&delegation_manager.delegation_approver_salt_spent, approver)) {
            return false;
        };
        let approver_salts = table::borrow(&delegation_manager.delegation_approver_salt_spent, approver);
        table::contains(approver_salts, salt)
    }

    fun check_can_call(
        delegation_manager: &DelegationManager,
        operator: address,
        ctx: &mut TxContext
    ): bool {
        tx_context::sender(ctx) == operator
    }

    fun check_not_paused(delegation_manager: &DelegationManager) {
        assert!(!delegation_manager.is_paused, E_PAUSED);
    }
}