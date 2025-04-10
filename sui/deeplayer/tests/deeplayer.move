#[test_only]
module deeplayer::deeplayer_tests {
    use std::option;
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance;
    use sui::clock;
    use std::string;
    use sui::transfer;

    use deeplayer::math_module;
    use deeplayer::coin_utils_module;
    use deeplayer::lbtc::{Self, LBTC, Faucet};
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager};
    use deeplayer::delegation_module::{Self, DelegationManager};

    #[test]
    fun restake_lbtc() {
        let mut scenario = ts::begin(@0x123);
        let admin = @0x1;
        let staker = @0x2;
        let operator = @0x3;

        // ========== INIT ========== //
        ts::next_tx(&mut scenario, admin);

        let mut the_clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut the_clock, 98_749_028);

        lbtc::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);
        
        strategy_factory_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        strategy_manager_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        allocation_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        delegation_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        // ========== TAKE OBJECTS ========== //

        let mut treasury_cap = ts::take_from_sender<TreasuryCap<LBTC>>(&scenario);
        let mut faucet = ts::take_shared<Faucet<LBTC>>(&scenario);
        let mut strategy_factory = ts::take_shared<StrategyFactory>(&scenario);
        let mut strategy_manager = ts::take_shared<StrategyManager>(&scenario);
        let mut allocation_manager = ts::take_shared<AllocationManager>(&scenario);
        let mut delegation_manager = ts::take_shared<DelegationManager>(&scenario);

        // ========== CREATE COIN ========== //
        ts::next_tx(&mut scenario, admin);

        lbtc::init_supply(&mut treasury_cap, &mut faucet, ts::ctx(&mut scenario));
        
        // ========== MINT COIN ========== //
        ts::next_tx(&mut scenario, admin);

        let amount = 100_000;
        lbtc::mint(&mut faucet, amount, staker, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);
        
        // Verify staker got the coins
        let coin = ts::take_from_address<Coin<LBTC>>(&scenario, staker);
        assert!(coin::value(&coin) == amount, 2);
        ts::return_to_address(staker, coin);

        ts::next_tx(&mut scenario, admin);
        
        // Verify faucet balance was decreased
        let faucet_balance = lbtc::get_faucet_balance(&faucet);
        assert!(faucet_balance == 1_000_000_000_000_000 - amount, 3);

        // ========== CREATE STRATEGY ========== //
        ts::next_tx(&mut scenario, admin);

        strategy_factory_module::deploy_new_strategy<LBTC>(&mut strategy_factory, ts::ctx(&mut scenario));

        // ========== REGISTER OPERATOR ========== //
        ts::next_tx(&mut scenario, operator);

        let metadata_uri = string::utf8(b"metadata_uri");
        delegation_module::register_as_operator(&strategy_manager, &allocation_manager, &mut delegation_manager, metadata_uri, ts::ctx(&mut scenario));
       
        // ========== DEPOSIT INTO STRATEGY ========== //
        ts::next_tx(&mut scenario, staker);

        let strategy_id = coin_utils_module::get_strategy_id<LBTC>();
        let coin_deposited = ts::take_from_sender<Coin<LBTC>>(&scenario);

        assert!(coin::value(&coin_deposited) == amount, 4);
        assert!(strategy_manager_module::get_total_shares(&strategy_manager, strategy_id) == 0, 5);

        delegation_module::deposit_into_strategy<LBTC>(
            &mut strategy_factory, 
            &mut strategy_manager,
            &allocation_manager, 
            &mut delegation_manager, 
            coin_deposited,
            ts::ctx(&mut scenario)
        );

        assert!(strategy_manager_module::get_staker_shares(&strategy_manager, strategy_id, staker) > 0, 5);

        delegation_module::delegate(
            &strategy_manager,
            &allocation_manager, 
            &mut delegation_manager, 
            operator, 
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // ========== RETURN/CLOSE OBJECTS ========== //
        ts::next_tx(&mut scenario, admin);

        clock::destroy_for_testing(the_clock);

        ts::return_shared(strategy_factory);
        ts::return_shared(strategy_manager);
        ts::return_shared(allocation_manager);
        ts::return_shared(delegation_manager);
        ts::return_shared(faucet);
        ts::return_to_sender(&scenario, treasury_cap);
        ts::end(scenario);
    }
}