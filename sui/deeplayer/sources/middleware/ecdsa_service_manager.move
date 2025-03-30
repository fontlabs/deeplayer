// SPDX-License-Identifier: MIT
module deeplayer::ecdsa_service_manager_module {
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
    use deeplayer::signature_module::{Self, SignatureWithSaltAndExpiry};

    public entry fun update_avs_metadata_uri(
        directory: &AVSDirectory,
        avs: address,
        metadata_uri: string::String,
        ctx: &mut TxContext
    ) {      
        avs_directory_module::update_avs_metadata_uri(
            directory,
            avs,
            metadata_uri,
            ctx
        )
    }

    public entry fun create_avs_rewards_submission<COIN>(
        rewards_coordinator: &mut RewardsCoordinator,
        avs: address,
        duration: u64,
        coin_rewards: coin::Coin<COIN>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        rewards_module::create_avs_rewards_submission<COIN>(
            rewards_coordinator,
            avs,
            duration,
            coin_rewards,
            the_clock,
            ctx
        )
    }

    public fun register_operator_to_avs(
        directory: &mut AVSDirectory,
        delegation_manager: &DelegationManager,
        avs: address,
        operator: address,
        operator_signature: SignatureWithSaltAndExpiry,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        avs_directory_module::register_operator_to_avs(
            directory,
            delegation_manager,
            avs,
            operator,
            operator_signature,
            the_clock,
            ctx
        )
    }

    public(package) fun deregister_operator_from_avs(
        directory: &mut AVSDirectory,
        avs: address,
        operator: address,
        ctx: &mut TxContext
    ) {
        avs_directory_module::deregister_operator_from_avs(
            directory,
            avs,
            operator,
            ctx
        ) 
    }

    public fun get_operator_weight_at_block(
    ): u64 {
        0
    }
}