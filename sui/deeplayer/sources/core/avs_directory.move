// SPDX-License-Identifier: MIT
module deeplayer::avs_directory_module {
    use std::string;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::table;
    use sui::clock;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::strategy_manager_module::{StrategyManager};
    use deeplayer::delegation_module::{Self, DelegationManager};

    // Constants
    const OPERATOR_AVS_REG_UNREGISTERED: u64 = 0;
    const OPERATOR_AVS_REG_REGISTERED: u64 = 1;

    // Errors
    const E_OPERATOR_ALREADY_REGISTERED_TO_AVS: u64 = 0;
    const E_OPERATOR_NOT_REGISTERED_TO_AVS: u64 = 1;
    const E_INVALID_SIGNATURE: u64 = 3;
    const E_SALT_SPENT: u64 = 4;
    const E_OPERATOR_NOT_REGISTERED: u64 = 5;

    // Structs
    public struct AVSDirectory has key {
        id: UID,
        avs_operator_status: table::Table<address, table::Table<address, u64>>
    }

    // Events
    public struct AVSMetadataURIUpdated has copy, drop {
        avs: address,
        metadata_uri: string::String,
    }

    public struct OperatorAVSRegistrationStatusUpdated has copy, drop {
        operator: address,
        avs: address,
        status: u64,
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let avs_directory = AVSDirectory {
            id: object::new(ctx),
            avs_operator_status: table::new<address, table::Table<address, u64>>(ctx)
        };

        transfer::share_object(avs_directory);
    }

    // Package functions
    public(package) fun update_avs_metadata_uri(
        avs: address,
        metadata_uri: string::String
    ) {             
        event::emit(AVSMetadataURIUpdated {
            avs,
            metadata_uri,
        });
    }

    public(package) fun register_operator_to_avs(
        avs_directory: &mut AVSDirectory,
        delegation_manager: &DelegationManager,
        avs: address,
        operator: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {        
        // Check if operator is already registered
        if (!table::contains(&avs_directory.avs_operator_status, avs)) {
            table::add(&mut avs_directory.avs_operator_status, avs, table::new<address, u64>(ctx));
        };
        let mut operator_status = table::borrow_mut(&mut avs_directory.avs_operator_status, avs);
        if (!table::contains(operator_status, operator)) {
            table::add(operator_status, operator, OPERATOR_AVS_REG_UNREGISTERED);
        };

        let mut status = table::borrow_mut(operator_status, operator);
        assert!(*status != OPERATOR_AVS_REG_REGISTERED, E_OPERATOR_ALREADY_REGISTERED_TO_AVS);
    
        let is_operator = delegation_module::is_operator(delegation_manager, operator);
        assert!(is_operator, E_OPERATOR_NOT_REGISTERED);
        
        *status = OPERATOR_AVS_REG_REGISTERED;       

        event::emit(OperatorAVSRegistrationStatusUpdated {
            operator,
            avs,
            status: OPERATOR_AVS_REG_REGISTERED,
        });
    }

    public(package) fun deregister_operator_from_avs(
        avs_directory: &mut AVSDirectory,
        avs: address,
        operator: address,
        ctx: &mut TxContext
    ) {        
        // Check if operator is not registered
        if (!table::contains(&avs_directory.avs_operator_status, avs)) {
            table::add(&mut avs_directory.avs_operator_status, avs, table::new<address, u64>(ctx));
        };
        let mut operator_status = table::borrow_mut(&mut avs_directory.avs_operator_status, avs);
        if (!table::contains(operator_status, operator)) {
            table::add(operator_status, operator, OPERATOR_AVS_REG_UNREGISTERED);
        };

        let status = table::borrow(operator_status, operator);
        assert!(status != OPERATOR_AVS_REG_UNREGISTERED, E_OPERATOR_NOT_REGISTERED_TO_AVS);
        
        table::add(operator_status, operator, OPERATOR_AVS_REG_UNREGISTERED);        
        
        event::emit(OperatorAVSRegistrationStatusUpdated {
            operator,
            avs,
            status: OPERATOR_AVS_REG_UNREGISTERED,
        });
    }

    public fun is_operator_registered(
        avs_directory: &AVSDirectory,
        avs: address,
        operator: address
    ): bool {
        if (!table::contains(&avs_directory.avs_operator_status, avs)) {
            return false;
        };
        let operator_status = table::borrow(&avs_directory.avs_operator_status, avs);
        if (!table::contains(operator_status, operator)) {
            return false;
        };
        let status = table::borrow(operator_status, operator);
        status == OPERATOR_AVS_REG_REGISTERED
    }

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext
    ) {
        init(ctx);
    }
}