// SPDX-License-Identifier: MIT
module deeplayer::avs_manager_module {
    use std::string;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use sui::clock;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::allocation_module;    
    use deeplayer::rewards_module::{Self, RewardsCoordinator};    
    use deeplayer::avs_directory_module::{Self, AVSDirectory};
    use deeplayer::delegation_module::{Self, DelegationManager};
    
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

    public fun register_operator_to_avs(
        avs_directory: &mut AVSDirectory,
        delegation_manager: &DelegationManager,
        avs: address,
        salt: vector<u8>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        avs_directory_module::register_operator_to_avs(
            avs_directory,
            delegation_manager,
            avs,
            tx_context::sender(ctx),
            salt,
            the_clock,
            ctx
        )
    }

    public fun deregister_operator_from_avs(
        avs_directory: &mut AVSDirectory,
        avs: address,
        operator: address,
        ctx: &mut TxContext
    ) {
        avs_directory_module::deregister_operator_from_avs(
            avs_directory,
            avs,
            operator,
            ctx
        ) 
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

    public fun get_operator_shares(
        delegation_manager: &DelegationManager,
        operator: address,
        strategy_ids: vector<string::String>
    ): vector<u64> {
        delegation_module::get_operator_shares(delegation_manager, operator, strategy_ids)
    }
}