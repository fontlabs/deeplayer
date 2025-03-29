module deeplayer::slasher_module {
    use sui::tx_context::{Self, TxContext};

    use deeplayer::delegation_module::{DelegationManager};
    use deeplayer::allocation_module::{Self, SlashingParams};

    public entry fun fulfill_slashing_request(
        allocation_manager: &mut AllocationManager,
        delegation_manager: &mut DelegationManager,
        avs: address,
        params: &SlashingParams,
        ctx: &mut TxContext
    ) {
        allocation_module::slash_operator(
            allocation_manager,
            delegation_manager,
            avs,
            params,
            ctx
        );
    }
}