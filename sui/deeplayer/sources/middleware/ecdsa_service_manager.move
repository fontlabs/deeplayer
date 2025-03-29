module deeplayer::ecdsa_service_manager_module {
    use std::string;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::table;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::allocation;    
    use deeplayer::rewards;    
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

    public entry fun create_avs_rewards_submission(
        rewards_submissions: &vector<RewardsSubmission>
    ) {
        rewards::create_avs_rewards_submission(
            rewards_submissions
        )
    }

    public entry fun register_operator_to_avs(
        directory: &mut AVSDirectory,
        delegation_manager: &DelegationManager,
        avs: address,
        operator: address,
        operator_signature: SignatureWithSaltAndExpiry,
        ctx: &mut TxContext
    ) {
        avs_directory_module::register_operator_to_avs(
            directory,
            delegation_manager,
            avs,
            operator,
            operator_signature,
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
        
    }
}