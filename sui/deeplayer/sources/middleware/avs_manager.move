// SPDX-License-Identifier: MIT
module deeplayer::avs_manager_module {
    use std::string;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use sui::clock;
    use sui::table;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::math_module;    
    use deeplayer::allocation_module;    
    use deeplayer::rewards_module::{Self, RewardsCoordinator};    
    use deeplayer::avs_directory_module::{Self, AVSDirectory};
    use deeplayer::delegation_module::{Self, DelegationManager};

    // Constants
    // BPS is the basis points for the multipliers of the strategies in the quorum
    const BPS: u64 = 10_000;

    // Errors
    const E_INVALID_QUORUM_WEIGHT: u64 = 0;
    const E_INSUFFICIENT_QUORUM_WEIGHT: u64 = 1;
    const E_OPERATOR_NOT_REGISTERED_TO_AVS: u64 = 2;

    // Structs
    public struct Quorum has copy, drop, store {
        strategy_ids: vector<string::String>,
        multipliers: vector<u64>
    }

    public struct AVSManager has key {
        id: UID,
        min_weights: table::Table<address, u64>,
        quorums: table::Table<address, Quorum>,
        total_operators: table::Table<address, u64>,
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let avs_manager = AVSManager {
            id: object::new(ctx),
            min_weights: table::new<address, u64>(ctx),
            quorums: table::new<address, Quorum>(ctx),
            total_operators: table::new<address, u64>(ctx),
        };

        transfer::share_object(avs_manager);
    }
    
    // Public functions
    public fun update_avs_metadata_uri(
        avs: address,
        metadata_uri: string::String
    ) {      
        avs_directory_module::update_avs_metadata_uri(
            avs,
            metadata_uri
        )
    }

    public fun set_min_weight(
        avs_manager: &mut AVSManager,
        avs: address,
        min_weight: u64
    ) {
        if (!table::contains(&avs_manager.min_weights, avs)) {
            table::add(&mut avs_manager.min_weights, avs, 0);
        };

        let mut current_weight = table::borrow_mut(&mut avs_manager.min_weights, avs);
        *current_weight = min_weight;
    }

    public fun set_quorum(
        avs_manager: &mut AVSManager,
        avs: address,
        strategy_ids: vector<string::String>,
        multipliers: vector<u64>
    ) {
        let quorum = Quorum { strategy_ids, multipliers };

        validate_quorum(quorum);

        if (!table::contains(&avs_manager.quorums, avs)) {
            table::add(&mut avs_manager.quorums, avs, quorum);
        } else {
            let mut current_quorum = table::borrow_mut(&mut avs_manager.quorums, avs);
            *current_quorum = quorum;
        };
    }

    public fun register_operator_to_avs(
        avs_manager: &mut AVSManager,
        avs_directory: &mut AVSDirectory,
        delegation_manager: &DelegationManager,
        avs: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        let operator = tx_context::sender(ctx);
        let min_weight = get_min_weight(avs_manager, avs);
        let operator_weight = get_operator_weight(avs_manager, delegation_manager, avs, operator);

        assert!(operator_weight >= min_weight, E_INSUFFICIENT_QUORUM_WEIGHT);

        avs_directory_module::register_operator_to_avs(
            avs_directory,
            delegation_manager,
            avs,
            operator,
            the_clock,
            ctx
        );

        if (!table::contains(&avs_manager.total_operators, avs)) {
            table::add(&mut avs_manager.total_operators, avs, 0);
        };

        let mut current_total_operators = table::borrow_mut(&mut avs_manager.total_operators, avs);
        *current_total_operators = *current_total_operators + 1;
    }

    public fun deregister_operator_from_avs(
        avs_manager: &mut AVSManager,
        avs_directory: &mut AVSDirectory,
        avs: address,
        ctx: &mut TxContext
    ) {        
        let operator = tx_context::sender(ctx);

        avs_directory_module::deregister_operator_from_avs(
            avs_directory,
            avs,
            operator,
            ctx
        );

        let mut current_total_operators = table::borrow_mut(&mut avs_manager.total_operators, avs);
        *current_total_operators = *current_total_operators - 1;
    }

    public fun is_operator_registered(
        avs_directory: &AVSDirectory,
        avs: address,
        operator: address
    ): bool {
        avs_directory_module::is_operator_registered(
            avs_directory,
            avs,
            operator
        )
    }

    public fun check_operator(
        avs_manager: &AVSManager,
        avs_directory: &AVSDirectory,
        delegation_manager: &DelegationManager,
        avs: address,
        operator: address
    ) {
        assert!(is_operator_registered(
            avs_directory, 
            avs, 
            operator
        ), E_OPERATOR_NOT_REGISTERED_TO_AVS);

        let min_weight = get_min_weight(avs_manager, avs);
        let operator_weight = get_operator_weight(avs_manager, delegation_manager, avs, operator);
      
        assert!(operator_weight >= min_weight, E_INSUFFICIENT_QUORUM_WEIGHT);
    }

    public fun get_min_weight(
        avs_manager: &AVSManager,
        avs: address
    ): u64 {
        if (!table::contains(&avs_manager.min_weights, avs)) {
            return 0;
        };
        let min_weight = table::borrow(&avs_manager.min_weights, avs);
        *min_weight
    }

    public fun get_total_operators(
        avs_manager: &AVSManager,
        avs: address
    ): u64 {
        if (!table::contains(&avs_manager.total_operators, avs)) {
            return 0;
        };
        let total_operators = table::borrow(&avs_manager.total_operators, avs);
        *total_operators
    }

    public fun get_quorum(
        avs_manager: &AVSManager,
        avs: address
    ): Quorum {
        if (!table::contains(&avs_manager.quorums, avs)) {
            return Quorum { strategy_ids: vector::empty<string::String>(), multipliers: vector::empty<u64>() };
        };
        let quorum = table::borrow(&avs_manager.quorums, avs);
        *quorum
    }

    public fun get_operator_shares(
        delegation_manager: &DelegationManager,
        operator: address,
        strategy_ids: vector<string::String>
    ): vector<u64> {
        delegation_module::get_operator_shares(delegation_manager, operator, strategy_ids)
    }

    public fun get_operator_weight(
        avs_manager: &AVSManager,        
        delegation_manager: &DelegationManager,
        avs: address,
        operator: address,
    ): u64 {
        if (!table::contains(&avs_manager.quorums, avs)) {
            return 0;
        };
        let quorum = table::borrow(&avs_manager.quorums, avs);
        let shares = get_operator_shares(
            delegation_manager,
            operator,
            quorum.strategy_ids
        );

        let mut operator_weight: u64 = 0;

        let mut i: u64 = 0;
        let len = vector::length(&quorum.multipliers);

        while (i < len) {
            operator_weight = operator_weight + (*vector::borrow(&quorum.multipliers, i) * *vector::borrow(&shares, i));
            i = i + 1;
        };

        math_module::div(operator_weight, BPS)
    }

    fun validate_quorum(
        quorum: Quorum,
    ) {
        let mut total_multiplier: u64 = 0;

        assert!(vector::length(&quorum.strategy_ids) == vector::length(&quorum.multipliers), E_INVALID_QUORUM_WEIGHT);

        let mut i: u64 = 0;
        let len = vector::length(&quorum.multipliers);

        while (i < len) {
            total_multiplier = total_multiplier + *vector::borrow(&quorum.multipliers, i);
            i = i + 1;
        };

        assert!(total_multiplier == BPS, E_INVALID_QUORUM_WEIGHT);
    }

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext
    ) {
        init(ctx);
    }
}