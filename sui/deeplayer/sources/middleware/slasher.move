// SPDX-License-Identifier: MIT
#[allow(unused_use,unused_const,unused_variable,duplicate_alias,unused_type_parameter,unused_function)]
module deeplayer::slasher_module {
    use sui::tx_context::{Self, TxContext};

    use deeplayer::strategy_factory_module::{Self, StrategyFactory};
    use deeplayer::strategy_manager_module::{StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager, SlashingParams};
    use deeplayer::delegation_module::{Self, DelegationManager};

    public(package) fun instant_slash<CoinType>(
        strategy_factory: &mut StrategyFactory,
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
        let strategy = strategy_factory_module::get_strategy_mut<CoinType>(strategy_factory);

        delegation_module::slash_operator_shares<CoinType>(
            strategy,
            strategy_manager,
            delegation_manager,
            operator,
            prev_max_magnitude,
            max_magnitude,
            ctx
        );
    }
}