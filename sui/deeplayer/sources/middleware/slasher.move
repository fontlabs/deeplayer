// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::slasher_module {
    use sui::tx_context::{Self, TxContext};

    use deeplayer::delegation_module::{DelegationManager};
    use deeplayer::strategy_manager_module::{StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager, SlashingParams};

    public(package) fun instant_slash(
        allocation_manager: &mut AllocationManager,
        strategy_manager: &mut StrategyManager,
        avs: address,
        params: SlashingParams,
        ctx: &mut TxContext
    ) {
        allocation_module::slash_operator(
            allocation_manager,
            strategy_manager,
            avs,
            params,
            ctx
        );
    }
}