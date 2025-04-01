// SPDX-License-Identifier: MIT
module deeplayer::slasher_module {
    use sui::tx_context::{Self, TxContext};

    use deeplayer::delegation_module::{Self, DelegationManager};
    use deeplayer::strategy_manager_module::{StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager, SlashingParams};

    public(package) fun instant_slash(
        strategy_manager: &mut StrategyManager,
        allocation_manager: &mut AllocationManager,
        delegation_manager: &mut DelegationManager,
        avs: address,
        params: SlashingParams,
        ctx: &mut TxContext
    ) {
        let (prev_max_magnitude, max_magnitude) = allocation_module::slash_operator_shares(
            strategy_manager,
            allocation_manager,
            avs,
            params,
            ctx
        );

        let (operator, strategy_id) = allocation_module::params_to_operator_and_strategy_id(params);

        delegation_module::slash_operator_shares(
            strategy_manager,
            delegation_manager,
            operator,
            strategy_id,
            prev_max_magnitude,
            max_magnitude,
            ctx
        );
    }
}