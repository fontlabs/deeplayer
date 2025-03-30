// SPDX-License-Identifier: MIT
module deeplayer::allocation_module {
    use std::option;
    use std::string;
    use std::vector;
    use sui::balance;
    use sui::coin;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::table;
    use sui::bcs;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::delegation_module::{Self, DelegationManager};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};

    // Constants
    const WAD: u64 = 1_000_000_000;

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
        id: u64,
    }

    public struct Allocation has copy, drop, store {
        current_magnitude: u64,
        pending_diff: u64,
        effect_block: u64,
    }

    public struct Snapshot has copy, drop, store {
        block_number: u64,
        max_magnitude: u64,
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

    public struct SlashingParams has copy, drop, store {
        operator: address,
        operator_set_id: u64,
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
        operator_set_ids: vector<u64>,
        data: vector<u8>,
    }

    public struct DeregisterParams has copy, drop {
        operator: address,
        avs: address,
        operator_set_ids: vector<u64>,
    }

    public struct CreateSetParams has copy, drop {
        operator_set_id: u64,
        strategies: vector<address>,
    }

    public struct AllocationManager has key {
        id: UID,
        is_paused: bool,
        operator_sets: table::Table<address, vector<u64>>,
        operator_set_strategies: table::Table<vector<u8>, vector<address>>,
        allocated_sets: table::Table<address, vector<vector<u8>>>,
        allocated_strategies: table::Table<address, table::Table<vector<u8>, vector<address>>>,
        allocations: table::Table<address, table::Table<vector<u8>, table::Table<address, Allocation>>>,
        max_magnitude_snapshots: table::Table<address, table::Table<address, vector<Snapshot>>>,
        encumbered_magnitude: table::Table<address, table::Table<address, u64>>,
        registration_status: table::Table<address, table::Table<vector<u8>, RegistrationStatus>>,
        allocation_delay_info: table::Table<address, AllocationDelayInfo>,
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
        delay: u64,
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

    fun init(
        ctx: &mut TxContext
    ) {
        let allocation_manager = AllocationManager {
            id: object::new(ctx),
            is_paused: false,
            operator_sets: table::new<address, vector<u64>>(ctx),
            operator_set_strategies: table::new<vector<u8>, vector<address>>(ctx),
            allocated_sets: table::new<address, vector<vector<u8>>>(ctx),
            allocated_strategies: table::new<address, table::Table<vector<u8>, vector<address>>>(ctx),
            allocations: table::new<address, table::Table<vector<u8>, table::Table<address, Allocation>>>(ctx),
            max_magnitude_snapshots: table::new<address, table::Table<address, vector<Snapshot>>>(ctx),
            encumbered_magnitude: table::new<address, table::Table<address, u64>>(ctx),
            registration_status: table::new<address, table::Table<vector<u8>, RegistrationStatus>>(ctx),
            allocation_delay_info: table::new<address, AllocationDelayInfo>(ctx),
        };

        transfer::share_object(allocation_manager);
    }

    // Package functions
    public(package) fun slash_operator(
        allocation_manager: &mut AllocationManager,
        strategy_manager: &mut StrategyManager,
        delegation_manager: &mut DelegationManager,
        avs: address,
        params: SlashingParams,
        ctx: &mut TxContext
    ) {
        check_not_paused(allocation_manager);

        let operator_set = OperatorSet { avs, id: params.operator_set_id };
        assert!(vector::length(&params.strategies) == vector::length(&params.wads_to_slash), E_INPUT_ARRAY_LENGTH_MISMATCH);
        assert!(operator_set_exists(allocation_manager, operator_set), E_INVALID_OPERATOR_SET);
        assert!(is_operator_slashable(allocation_manager, params.operator, operator_set, ctx), E_OPERATOR_NOT_SLASHABLE);

        let mut wad_slashed = vector::empty<u64>();

        let mut i = 0;
        let len = vector::length(&params.strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(&params.strategies, i);
            let wad_to_slash = *vector::borrow(&params.wads_to_slash, i);

            assert!(0 < wad_to_slash && wad_to_slash <= WAD, E_INVALID_WAD_TO_SLASH);
            assert!(operator_set_contains_strategy(allocation_manager, operator_set, strategy_address), E_STRATEGY_NOT_IN_OPERATOR_SET);

            let (mut info, mut allocation) = get_updated_allocation(
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
                allocation,
                ctx
            );

            // emit_allocation_updated(
            //     params.operator,
            //     operator_set,
            //     strategy_address,
            //     allocation.current_magnitude,
            //     tx_context::epoch(ctx)
            // );

            update_max_magnitude(allocation_manager, params.operator, strategy_address, info.max_magnitude, ctx);

            delegation_module::slash_operator_shares(
                delegation_manager,
                strategy_manager,
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

    // Internal helper functions
    fun operator_set_exists(
        allocation_manager: &AllocationManager,
        operator_set: OperatorSet
    ): bool {
        if (!table::contains(&allocation_manager.operator_sets, operator_set.avs)) {
            return false;
        };
        let sets = table::borrow(&allocation_manager.operator_sets, operator_set.avs);
        vector::contains(sets, &operator_set.id)
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
        let strategies = table::borrow(&allocation_manager.operator_set_strategies, key);
        vector::contains(strategies, &strategy_address)
    }

    fun operator_set_key(operator_set: OperatorSet): vector<u8> {
        let mut key = vector::empty<u8>();
        vector::append(&mut key, bcs::to_bytes<address>(&operator_set.avs));
        vector::append(&mut key, bcs::to_bytes<u64>(&operator_set.id));
        key
    }

    fun get_updated_allocation(
        allocation_manager: &AllocationManager,
        operator: address,
        operator_set: OperatorSet,
        strategy_address: address,
        ctx: &mut TxContext
    ): (StrategyInfo, Allocation) {
        let max_magnitude = get_max_magnitude(allocation_manager, operator, strategy_address, 0);
        
        let encumbered_magnitude = if (table::contains(&allocation_manager.encumbered_magnitude, operator) &&
            table::contains(table::borrow(&allocation_manager.encumbered_magnitude, operator), strategy_address)) {
            *table::borrow(table::borrow(&allocation_manager.encumbered_magnitude, operator), strategy_address)
        } else {
            0
        };

        let mut info = StrategyInfo { max_magnitude, encumbered_magnitude };

        let mut allocation = if (table::contains(&allocation_manager.allocations, operator) &&
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
            if (!vector::contains(allocated_sets, &set_key)) {
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
            if (!vector::contains(set_strategies, &strategy_address)) {
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
                        // let i = vector::find_index<address>(set_strategies, fn (strategy: &address): bool {
                        //     strategy == &strategy_address
                        // });
                        // vector::remove(set_strategies, option::extract(i));
                    };
                };
            };

            if (table::contains(&allocation_manager.allocated_sets, operator)) {
                let mut allocated_sets = table::borrow_mut(&mut allocation_manager.allocated_sets, operator);
                if (!vector::is_empty(allocated_sets)) {
                    // let i = vector::find_index<vector<u8>>(allocated_sets, fn (key: &vector<u8>): bool {
                    //     key == &set_key 
                    // });
                    // vector::remove(allocated_sets, option::extract(i));
                };
            };
        };
    }

    fun update_max_magnitude(
        allocation_manager: &mut AllocationManager, 
        operator: address, 
        strategy_address: address, 
        max_magnitude: u64,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&allocation_manager.max_magnitude_snapshots, operator)) {
            table::add(&mut allocation_manager.max_magnitude_snapshots, operator, table::new<address, vector<Snapshot>>(ctx))
        };
        let max_magnitude_snapshots = table::borrow_mut(&mut allocation_manager.max_magnitude_snapshots, operator);
        let max_magnitudes = table::borrow_mut(max_magnitude_snapshots, strategy_address);
        
        let snapshot = Snapshot {
            block_number: tx_context::epoch(ctx),
            max_magnitude: max_magnitude
        };
        vector::push_back(max_magnitudes, snapshot);
    }

    fun check_not_paused(
        allocation_manager: &AllocationManager
    ) {
        assert!(!allocation_manager.is_paused, E_PAUSED);
    }

    // View functions
    public fun get_max_magnitudes(
        allocation_manager: &AllocationManager,
        operator: address,
        strategies: vector<address>,
        min_block: u64
    ): vector<u64> {
        let mut max_magnitudes = vector::empty<u64>();

        let mut i = 0;
        let len = vector::length(&strategies);
        while (i < len) {
            let strategy_address = *vector::borrow(&strategies, i);

            vector::push_back(
                &mut max_magnitudes,
                get_max_magnitude(allocation_manager, operator, strategy_address, min_block)
            );

            i = i + 1;
        };
        
        max_magnitudes
    }

    public fun get_max_magnitude(
        allocation_manager: &AllocationManager,
        operator: address,
        strategy_address: address,
        min_block: u64
    ): u64 {
        if (!table::contains(&allocation_manager.max_magnitude_snapshots, operator) ||
            !table::contains(table::borrow(&allocation_manager.max_magnitude_snapshots, operator), strategy_address)) {
            return WAD;
        };
        let snapshots = table::borrow(table::borrow(&allocation_manager.max_magnitude_snapshots, operator), strategy_address);
        if (vector::is_empty(snapshots)) {
            return WAD;
        };
        
        let mut max_magnitude: u64 = WAD;

        let mut i = 0;
        let len = vector::length(snapshots);
        while (i < len) {
            let snapshot = vector::borrow(snapshots, i);

            if (snapshot.block_number >= min_block && snapshot.max_magnitude > max_magnitude) {
                max_magnitude = snapshot.max_magnitude;
            };

            i = i + 1;
        };

        max_magnitude
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
            return (true, info.pending_delay);
        };

        (is_set, delay)
    }
}