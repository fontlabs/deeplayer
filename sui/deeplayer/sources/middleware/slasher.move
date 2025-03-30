// SPDX-License-Identifier: MIT
module deeplayer::slasher_module {
    use sui::tx_context::{Self, TxContext};

    use deeplayer::delegation_module::{DelegationManager};
    use deeplayer::strategy_manager_module::{StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager, SlashingParams};

    public(package) fun instant_slash(
        allocation_manager: &mut AllocationManager,
        strategy_manager: &mut StrategyManager,
        delegation_manager: &mut DelegationManager,
        avs: address,
        params: SlashingParams,
        ctx: &mut TxContext
    ) {
        allocation_module::slash_operator(
            allocation_manager,
            strategy_manager,
            delegation_manager,
            avs,
            params,
            ctx
        );
    }
}