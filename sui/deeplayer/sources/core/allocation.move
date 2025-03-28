// SPDX-License-Identifier: MIT
module deeplayer::allocation {
    use std::option;
    use std::string;
    use std::vector;
    use sui::balance;
    use sui::coin;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::table;
    use sui::bcs::to_bytes;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::deeplayer::{DLCap};
    use deeplayer::delegation::{Self, DelegationManager};

    // Constants
    const WAD: u64 = 100000000; 

    // Error codes
    const E_INPUT_ARRAY_LENGTH_MISMATCH: u64 = 1;
    const E_INVALID_OPERATOR_SET: u64 = 2;
    const E_OPERATOR_NOT_SLASHABLE: u64 = 3;
    const E_STRATEGIES_MUST_BE_IN_ASCENDING_ORDER: u64 = 4;
    const E_INVALID_WAD_TO_SLASH: u64 = 5;
    const E_STRATEGY_NOT_IN_OPERATOR_SET: u64 = 6;
    const E_INSUFFICIENT_MAGNITUDE: u64 = 7;
    const E_ALREADY_MEMBER_OF_SET: u64 = 8;
    const E_INVALID_CALLER: u64 = 9;
    const E_UNINITIALIZED_ALLOCATION_DELAY: u64 = 10;
    const E_NOT_MEMBER_OF_SET: u64 = 11;
    const E_INVALID_OPERATOR: u64 = 12;
    const E_INVALID_AVS_REGISTRAR: u64 = 13;
    const E_NONEXISTENT_AVS_METADATA: u64 = 14;
    const E_STRATEGY_ALREADY_IN_OPERATOR_SET: u64 = 15;
    const E_MODIFICATION_PENDING: u64 = 16;
    const E_SAME_MAGNITUDE: u64 = 17;
    const E_PAUSED: u64 = 18;

    // Structs
    public struct OperatorSet has copy, drop {
        avs: address,
        id: u32,
    }

    public struct Allocation has copy, drop, store {
        current_magnitude: u64,
        pending_diff: u64,
        effect_block: u64,
    }

    public struct StrategyInfo has copy, drop {
        max_magnitude: u64,
        encumbered_magnitude: u64,
    }

    public struct RegistrationStatus has copy, drop, store {
        registered: bool,
        slashable_until: u64
    }

    public struct AllocationDelayInfo has copy, drop, store {
        delay: u64,
        pending_delay: u64,
        effect_block: u64,
        is_set: bool,
    }

    public struct SlashingParams has copy, drop {
        operator: address,
        operator_set_id: u32,
        strategies: vector<address>,
        wads_to_slash: vector<u64>,
        description: string::String,
    }

    public struct AllocateParams has copy, drop {
        operator_set: OperatorSet,
        strategies: vector<address>,
        new_magnitudes: vector<u64>,
    }

    public struct RegisterParams has copy, drop {
        avs: address,
        operator_set_ids: vector<u32>,
        data: vector<u8>,
    }

    public struct DeregisterParams has copy, drop {
        operator: address,
        avs: address,
        operator_set_ids: vector<u32>,
    }

    public struct CreateSetParams has copy, drop {
        operator_set_id: u32,
        strategies: vector<address>,
    }

    public struct AllocationManager has key {
        id: UID,
        deallocation_delay: u32,
        allocation_configuration_delay: u32,
        is_paused: bool,
        version: string::String,
        operator_sets: table::Table<address, vector<u32>>,
        operator_set_members: table::Table<vector<u8>, vector<address>>,
        operator_set_strategies: table::Table<vector<u8>, vector<address>>,
        registered_sets: table::Table<address, vector<vector<u8>>>,
        allocated_sets: table::Table<address, vector<vector<u8>>>,
        allocated_strategies: table::Table<address, table::Table<vector<u8>, vector<address>>>,
        deallocation_queue: table::Table<address, table::Table<address, vector<vector<u8>>>>,
        allocations: table::Table<address, table::Table<vector<u8>, table::Table<address, Allocation>>>,
        max_magnitude_history: table::Table<address, table::Table<address, vector<u64>>>,
        encumbered_magnitude: table::Table<address, table::Table<address, u64>>,
        registration_status: table::Table<address, table::Table<vector<u8>, RegistrationStatus>>,
        allocation_delay_info: table::Table<address, AllocationDelayInfo>,
        avs_registrar: table::Table<address, address>,
        avs_registered_metadata: table::Table<address, bool>,
    }

    // Events
    public struct OperatorSlashed has copy, drop {
        operator: address,
        operator_set: OperatorSet,
        strategies: vector<address>,
        wad_slashed: vector<u64>,
        description: string::String,
    }

    public struct AllocationUpdated has copy, drop {
        operator: address,
        operator_set: OperatorSet,
        strategy_address: address,
        magnitude: u64,
        effect_block: u64,
    }

    public struct EncumberedMagnitudeUpdated has copy, drop {
        operator: address,
        strategy_address: address,
        magnitude: u64,
    }

    public struct MaxMagnitudeUpdated has copy, drop {
        operator: address,
        strategy_address: address,
        magnitude: u64,
    }

    public struct OperatorAddedToOperatorSet has copy, drop {
        operator: address,
        operator_set: OperatorSet,
    }

    public struct OperatorRemovedFromOperatorSet has copy, drop {
        operator: address,
        operator_set: OperatorSet,
    }

    public struct AllocationDelaySet has copy, drop {
        operator: address,
        delay: u32,
        effect_block: u64,
    }

    public struct AVSRegistrarSet has copy, drop {
        avs: address,
        registrar: address,
    }

    public struct AVSMetadataURIUpdated has copy, drop {
        avs: address,
        metadata_uri: string::String,
    }

    public struct OperatorSetCreated has copy, drop {
        operator_set: OperatorSet,
    }

    public struct StrategyAddedToOperatorSet has copy, drop {
        operator_set: OperatorSet,
        strategy_address: address,
    }

    public struct StrategyRemovedFromOperatorSet has copy, drop {
        operator_set: OperatorSet,
        strategy_address: address,
    }

    public entry fun initialize(
        dl_cap: &DLCap,
        deallocation_delay: u32,
        allocation_configuration_delay: u32,
        version: vector<u8>,
        ctx: &mut TxContext
    ) {
        let allocation = AllocationManager {
            id: object::new(ctx),
            deallocation_delay,
            allocation_configuration_delay,
            is_paused: false,
            version: string::utf8(version),
            operator_sets: table::new<address, vector<u32>>(ctx),
            operator_set_members: table::new<vector<u8>, vector<address>>(ctx),
            operator_set_strategies: table::new<vector<u8>, vector<address>>(ctx),
            registered_sets: table::new<address, vector<vector<u8>>>(ctx),
            allocated_sets: table::new<address, vector<vector<u8>>>(ctx),
            allocated_strategies: table::new<address, table::Table<vector<u8>, vector<address>>>(ctx),
            deallocation_queue: table::new<address, table::Table<address, vector<vector<u8>>>>(ctx),
            allocations: table::new<address, table::Table<vector<u8>, table::Table<address, Allocation>>>(ctx),
            max_magnitude_history: table::new<address, table::Table<address, vector<u64>>>(ctx),
            encumbered_magnitude: table::new<address, table::Table<address, u64>>(ctx),
            registration_status: table::new<address, table::Table<vector<u8>, RegistrationStatus>>(ctx),
            allocation_delay_info: table::new<address, AllocationDelayInfo>(ctx),
            avs_registrar: table::new<address, address>(ctx),
            avs_registered_metadata: table::new<address, bool>(ctx),
        };

        transfer::share_object(allocation);
    }

    // Public functions
    public entry fun slash_operator(
        allocation_manager: &mut AllocationManager,
        delegation_manager: &mut DelegationManager,
        avs: address,
        params: &SlashingParams,
        ctx: &mut TxContext
    ) {
        check_not_paused(allocation_manager);

        check_can_call(allocation_manager, avs, ctx);

        let operator_set = OperatorSet { avs, id: params.operator_set_id };
        assert!(vector::length(&params.strategies) == vector::length(&params.wads_to_slash), E_INPUT_ARRAY_LENGTH_MISMATCH);
        assert!(operator_set_exists(allocation_manager, operator_set), E_INVALID_OPERATOR_SET);
        assert!(is_operator_slashable(allocation_manager, params.operator, operator_set, ctx), E_OPERATOR_NOT_SLASHABLE);

        let wad_slashed = vector::empty<u64>();

        let i = 0;
        let len = vector::length(&params.strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(&params.strategies, i);
            let wad_to_slash = *vector::borrow(&params.wads_to_slash, i);

            // if (i > 0) {
            //     let prev_strategy = *vector::borrow(&params.strategies, i - 1);
            //     assert!(strategy_address > prev_strategy, E_STRATEGIES_MUST_BE_IN_ASCENDING_ORDER);
            // };

            assert!(0 < wad_to_slash && wad_to_slash <= WAD, E_INVALID_WAD_TO_SLASH);
            assert!(operator_set_contains_strategy(allocation_manager, operator_set, strategy_address), E_STRATEGY_NOT_IN_OPERATOR_SET);

            let (info, allocation) = get_updated_allocation(
                allocation_manager,
                params.operator,
                operator_set,
                strategy_address,
                ctx
            );

            if (allocation.current_magnitude == 0) {
                vector::push_back(&mut wad_slashed, 0);
                i = i + 1;
                continue;
            };

            let slashed_magnitude = allocation.current_magnitude * wad_to_slash / WAD;
            let prev_max_magnitude = info.max_magnitude;
            let wad_slash = slashed_magnitude * WAD / info.max_magnitude;
            vector::push_back(&mut wad_slashed, wad_slash);

            allocation.current_magnitude = allocation.current_magnitude - slashed_magnitude;
            info.max_magnitude = info.max_magnitude - slashed_magnitude;
            info.encumbered_magnitude = info.encumbered_magnitude - slashed_magnitude;

            if (allocation.pending_diff < 0) {
                let slashed_pending = allocation.pending_diff * wad_to_slash / WAD;
                allocation.pending_diff = allocation.pending_diff - slashed_pending;

                // emit_allocation_updated(
                //     params.operator,
                //     operator_set,
                //     strategy_address,
                //     allocation.current_magnitude + allocation.pending_diff,
                //     allocation.effect_block
                // );
            };

            update_allocation_info(
                allocation_manager,
                params.operator,
                operator_set,
                strategy_address,
                info,
                allocation
            );

            // emit_allocation_updated(
            //     params.operator,
            //     operator_set,
            //     strategy_address,
            //     allocation.current_magnitude,
            //     tx_context::epoch(ctx)
            // );

            _update_max_magnitude(allocation_manager, params.operator, strategy_address, info.max_magnitude);

            delegation::slash_operator_shares(
                delegation_manager,
                params.operator,
                strategy_address,
                prev_max_magnitude,
                info.max_magnitude,
                ctx
            );

            i = i + 1;
        };

        event::emit(OperatorSlashed {
            operator: params.operator,
            operator_set,
            strategies: params.strategies,
            wad_slashed,
            description: params.description,
        });
    }

    public entry fun modify_allocations(
        allocation_manager: &mut AllocationManager,
        operator: address,
        params: vector<&AllocateParams>,
        ctx: &mut TxContext
    ) {
        check_not_paused(allocation);

        assert!(_check_can_call(allocation_manager, operator), E_INVALID_CALLER);

        let (is_set, delay) = get_allocation_delay(allocation_manager, operator, ctx);
        assert!(is_set, E_UNINITIALIZED_ALLOCATION_DELAY);
        let operator_allocation_delay = delay;

        let i = 0;
        let len = vector::length(&params);
        while (i < len) {
            let param = *vector::borrow(&params, i);
            assert!(vector::length(&param.strategies) == vector::length(&param.new_magnitudes), E_INPUT_ARRAY_LENGTH_MISMATCH);

            let operator_set = param.operator_set;
            assert!(operator_set_exists(allocation_manager, operator_set), E_INVALID_OPERATOR_SET);
            let is_operator_slashable = is_operator_slashable(allocation_manager, operator, operator_set, ctx);

            let j = 0;
            let strategies_len = vector::length(&param.strategies);
            while (j < strategies_len) {
                let strategy = *vector::borrow(&param.strategies, j);
                let new_magnitude = *vector::borrow(&param.new_magnitudes, j);

                clear_deallocation_queue(
                    allocation_manager, 
                    operator, 
                    strategy, 
                    65535  // uint16 max
                );

                let (info, allocation) = get_updated_allocation(
                    allocation_manager,
                    operator,
                    operator_set,
                    strategy,
                    ctx
                );
                assert!(allocation.effect_block == 0, E_MODIFICATION_PENDING);

                let is_slashable = is_allocation_slashable(
                    allocation_manager,
                    operator_set,
                    strategy,
                    allocation_manager,
                    is_operator_slashable
                );

                allocation.pending_diff = _calc_delta(allocation.current_magnitude, new_magnitude);
                assert!(allocation.pending_diff != 0, E_SAME_MAGNITUDE);

                if (allocation.pending_diff < 0) {
                    if (is_slashable) {
                        _add_to_deallocation_queue(allocation_manager, operator, strategy, operator_set);
                        allocation.effect_block = tx_context::epoch(ctx) + allocation_manager.deallocation_delay + 1;
                    } else {
                        info.encumbered_magnitude = info.encumbered_magnitude + allocation.pending_diff;
                        allocation.current_magnitude = new_magnitude;
                        allocation.pending_diff = 0;
                        allocation.effect_block = tx_context::epoch(ctx);
                    }
                } else if (allocation.pending_diff > 0) {
                    info.encumbered_magnitude = info.encumbered_magnitude + allocation.pending_diff;
                    assert!(info.encumbered_magnitude <= info.max_magnitude, E_INSUFFICIENT_MAGNITUDE);
                    allocation.effect_block = tx_context::epoch(ctx) + operator_allocation_delay;
                };

                update_allocation_info(
                    allocation_manager,
                    operator,
                    operator_set,
                    strategy,
                    info,
                    allocation,
                    ctx
                );

                // emit_allocation_updated(
                //     allocation_manager,
                //     operator,
                //     operator_set,
                //     strategy,
                //     (allocation.current_magnitude as i128 + allocation.pending_diff) as u64,
                //     allocation.effect_block
                // );

                j = j + 1;
            };

            i = i + 1;
        };
    }

    fun clear_deallocation_queue(
        allocation_manager: &AllocationManager,
        operator: address,
        strategy_address: address,
        num_to_clear: u64
    ) {
        let i = 0;
        let num_cleared = 0;
        let len = if (table::contains(&allocation_manager.deallocation_queue, operator)) {
            let strategies = table::borrow_mut(&mut allocation.deallocation_queue, operator);
            if (table::contains(strategies, strategy_address)) {
                let queue = table::borrow(strategies, strategy_address);
                vector::length(queue)
            } else {
                0
            }
        } else {
            0
        }

        while (i < len && num_cleared < num_to_clear)  {

            i = i + 1;
            num_cleared = num_cleared + 1;
        }
    }
    // - register_for_operator_sets
    // - deregister_from_operator_sets
    // - set_allocation_delay
    // - set_avs_registrar
    // - update_avs_metadata_uri
    // - create_operator_sets
    // - add_strategies_to_operator_set
    // - remove_strategies_from_operator_set

    // - And all view functions

    // Internal helper functions
    fun operator_set_exists(
        allocation_manager: &AllocationManager,
        operator_set: OperatorSet
    ): bool {
        if (!table::contains(&allocation_manager.operator_sets, operator_set.avs)) {
            return false;
        };
        let sets = table::borrow(&allocation_manager.operator_sets, operator_set.avs);
        vector::contains(sets, operator_set.id)
    }

    fun operator_set_contains_strategy(
        allocation_manager: &AllocationManager,
        operator_set: OperatorSet,
        strategy_address: address
    ): bool {
        let key = operator_set_key(operator_set);
        if (!table::contains(&allocation_manager.operator_set_strategies, key)) {
            return false;
        };
        let strategies = &mut table::borrow_mut(&allocation_manager.operator_set_strategies, key);
        vector::contains(strategies, strategy_address)
    }

    fun operator_set_key(operator_set: OperatorSet): vector<u8> {
        let mut key = vector::empty<u8>();
        vector::append(&mut key, to_bytes<address>(&operator_set.avs));
        vector::append(&mut key, to_bytes<u32>(&operator_set.id));
        key
    }

    fun get_updated_allocation(
        allocation_manager: &AllocationManager,
        operator: address,
        operator_set: OperatorSet,
        strategy_address: address,
        ctx: &mut TxContext
    ): (StrategyInfo, Allocation) {
        let max_magnitude = get_max_magnitude(allocation_manager, operator, strategy_address);
        let encumbered_magnitude = if (table::contains(&allocation_manager.encumbered_magnitude, operator) &&
            table::contains(table::borrow(&allocation_manager.encumbered_magnitude, operator), strategy_address)) {
            *table::borrow(table::borrow(&allocation_manager.encumbered_magnitude, operator), strategy_address)
        } else {
            0
        };

        let info = StrategyInfo { max_magnitude, encumbered_magnitude };

        let allocation = if (table::contains(&allocation_manager.allocations, operator) &&
            table::contains(table::borrow(&allocation_manager.allocations, operator), operator_set_key(operator_set)) &&
            table::contains(table::borrow(table::borrow(&allocation_manager.allocations, operator), operator_set_key(operator_set)), strategy_address)) {
            *table::borrow(table::borrow(table::borrow(&allocation_manager.allocations, operator), operator_set_key(operator_set)), strategy_address)
        } else {
            Allocation { current_magnitude: 0, pending_diff: 0, effect_block: 0 }
        };

        if (tx_context::epoch(ctx) < allocation.effect_block) {
            return (info, allocation);
        };

        allocation.current_magnitude = allocation.current_magnitude + allocation.pending_diff;
        if (allocation.pending_diff < 0) {
            info.encumbered_magnitude = info.encumbered_magnitude + allocation.pending_diff;
        };
        allocation.effect_block = 0;
        allocation.pending_diff = 0;

        (info, allocation)
    }

    fun update_allocation_info(
        allocation_manager: &mut AllocationManager,
        operator: address,
        operator_set: OperatorSet,
        strategy_address: address,
        info: StrategyInfo,
        allocation: Allocation,
        ctx: &mut TxContext
    ) {
        // Update encumbered magnitude
        if (!table::contains(&allocation_manager.encumbered_magnitude, operator)) {
            table::add(&mut allocation_manager.encumbered_magnitude, operator, table::new<address, u64>(ctx));
        };
        let operator_magnitudes = table::borrow_mut(&mut allocation_manager.encumbered_magnitude, operator);
        table::add(operator_magnitudes, strategy_address, info.encumbered_magnitude);

        // Update allocation
        if (!table::contains(&allocation_manager.allocations, operator)) {
            table::add(&mut allocation_manager.allocations, operator, table::new<vector<u8>, table::Table<address, Allocation>>(ctx));
        };
        let operator_allocations = table::borrow_mut(&mut allocation_manager.allocations, operator);
        
        let set_key = operator_set_key(operator_set);
        if (!table::contains(operator_allocations, set_key)) {
            table::add(operator_allocations, set_key, table::new<address, Allocation>(ctx));
        };
        let set_allocations = table::borrow_mut(operator_allocations, set_key);
        table::add(set_allocations, strategy_address, allocation);

        // Update allocated sets and strategies
        if (allocation.pending_diff != 0) {
            if (!table::contains(&allocation_manager.allocated_sets, operator)) {
                table::add(&mut allocation_manager.allocated_sets, operator, vector::empty<vector<u8>>());
            };
            let mut allocated_sets = table::borrow_mut(&mut allocation_manager.allocated_sets, operator);
            if (!vector::contains(allocated_sets, set_key)) {
                vector::push_back(allocated_sets, set_key);
            };

            if (!table::contains(&allocation_manager.allocated_strategies, operator)) {
                table::add(&mut allocation_manager.allocated_strategies, operator, table::new<vector<u8>, vector<address>>(ctx));
            };
            let mut allocated_strategies = table::borrow_mut(&mut allocation_manager.allocated_strategies, operator);
            if (!table::contains(allocated_strategies, set_key)) {
                table::add(allocated_strategies, set_key, vector::empty<address>());
            };
            let mut set_strategies = table::borrow_mut(allocated_strategies, set_key);
            if (!vector::contains(set_strategies, strategy_address)) {
                vector::push_back(set_strategies, strategy_address);
            };
        } else if (allocation.current_magnitude == 0) {
            if (table::contains(&allocation_manager.allocated_strategies, operator)) {
                let mut allocated_strategies = table::borrow_mut(&mut allocation_manager.allocated_strategies, operator);
                if (table::contains(allocated_strategies, set_key)) {
                    let mut set_strategies = table::borrow_mut(allocated_strategies, set_key);
                    if (vector::is_empty(set_strategies)) {
                        table::remove(allocated_strategies, set_key);
                    } else {
                        let i = vector::find_index<address>(set_strategies, fun (strategy: &address): bool {
                            strategy == &strategy_address
                        });
                        vector::remove(set_strategies, option::extract(i));
                    };
                };
            };

            if (table::contains(&allocation_manager.allocated_sets, operator)) {
                let mut allocated_sets = table::borrow_mut(&mut allocation_manager.allocated_sets, operator);
                if (vector::is_empty(allocated_sets)) {
                    table::remove(allocated_sets, set_key);
                } else {
                    let i = vector::find_index<vector<u8>>(allocated_sets, fun (key: &vector<u8>): bool {
                        key == &set_key 
                    });
                    vector::remove(allocated_sets, option::extract(i));
                };
            };
        };
    }

    // Additional helper functions would be implemented similarly...
    // - clear_deallocation_queue
    // - _add_to_deallocation_queue
    // - _update_max_magnitude
    // - _calc_delta
    // - is_allocation_slashable
    // - _check_can_call
    // - check_not_paused

    fun check_not_paused(
        allocation_manager: &AllocationManager
    ) {
        assert!(!allocation_manager.is_paused, E_PAUSED);
    }

    // - emit_allocation_updated
    // - And all view function implementations

    // View functions
    public fun get_max_magnitudes_at_block(
        allocation_manager: &AllocationManager,
        operator: address,
        strategies: &vector<address>,
        block_number: u64
    ): vector<u64> {
        let max_magnitudes = vector::empty<u64>();

        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            vector::push_back(
                &mut max_magnitudes,
                get_max_magnitude_at_block(
                    allocation_manager, operator, 
                    *vector::borrow(strategies, i), 
                    block_number
                )
            );
            i = i + 1;
        };
        
        max_magnitudes
    }

    public fun get_max_magnitudes(
        allocation_manager: &AllocationManager,
        operator: address,
        strategies: &vector<address>
    ): vector<u64> {
        let max_magnitudes = vector::empty<u64>();

        let i = 0;
        let len = vector::length(strategies);
        while (i < len) {
            vector::push_back(
                &mut max_magnitudes,
                get_max_magnitude(
                    allocation_manager, 
                    operator, 
                    *vector::borrow(strategies, i)
                )
            );
            i = i + 1;
        };
        
        max_magnitudes
    }

    public fun get_max_magnitude_at_block(
        allocation_manager: &AllocationManager,
        operator: address,
        strategy_address: address,
        block_number: u64
    ): u64 {
        get_max_magnitude(allocation_manager, operator, strategy_address)
    }

    public fun get_max_magnitude(
        allocation_manager: &AllocationManager,
        operator: address,
        strategy_address: address
    ): u64 {
        if (!table::contains(&allocation_manager.max_magnitude_history, operator) ||
            !table::contains(table::borrow(&allocation_manager.max_magnitude_history, operator), strategy_address)) {
            return 0;
        };
        let history = table::borrow(table::borrow(&allocation_manager.max_magnitude_history, operator), strategy_address);
        if (vector::is_empty(history)) {
            return 0;
        };
        let magnitude = *vector::borrow(history, vector::length(history) - 1);
        magnitude
    }

    public fun is_operator_slashable(
        allocation_manager: &AllocationManager,
        operator: address,
        operator_set: OperatorSet,
        ctx: &mut TxContext
    ): bool {
        if (!table::contains(&allocation_manager.registration_status, operator) ||
            !table::contains(table::borrow(&allocation_manager.registration_status, operator), operator_set_key(operator_set))) {
            return false;
        };
        let status = *table::borrow(table::borrow(&allocation_manager.registration_status, operator), operator_set_key(operator_set));
        status.registered || tx_context::epoch(ctx) <= status.slashable_until
    }

    public fun get_allocation_delay(
        allocation_manager: &AllocationManager,
        operator: address,
        ctx: &mut TxContext
    ): (bool, u64) {
        if (!table::contains(&allocation_manager.allocation_delay_info, operator)) {
            return (false, 0);
        };
        let info = *table::borrow(&allocation_manager.allocation_delay_info, operator);
        let delay = info.delay;
        let is_set = info.is_set;

        if (info.effect_block != 0 && tx_context::epoch(ctx) >= info.effect_block) {
            delay = info.pending_delay;
            is_set = true;
        };

        (is_set, delay)
    }
}