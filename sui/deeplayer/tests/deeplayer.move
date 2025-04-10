#[test_only]
module deeplayer::deeplayer_tests {
    use std::debug;
    use std::option;
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance;
    use sui::clock;
    use std::string;
    use sui::transfer;
    use sui::bcs;
    use sui::ed25519;
    use sui::test_utils;
    use sui::tx_context;

    use deeplayer::math_module;
    use deeplayer::coin_utils_module;
    use deeplayer::lbtc::{Self, LBTC, Faucet};
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager};
    use deeplayer::delegation_module::{Self, DelegationManager};
    use deeplayer::avs_directory_module::{Self, AVSDirectory};

    use deeplayer::hello_world_service_manager::{Self, HelloWorldServiceManager};

    #[test]
    fun restake_lbtc() {
        let mut scenario = ts::begin(@0x123);
        let admin = @0x1;
        let staker = @0x2;
        let operator = @0x3;
        let operator2 = @0x4;

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

        avs_directory_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        hello_world_service_manager::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        // ========== TAKE OBJECTS ========== //

        let mut treasury_cap = ts::take_from_sender<TreasuryCap<LBTC>>(&scenario);
        let mut faucet = ts::take_shared<Faucet<LBTC>>(&scenario);
        let mut strategy_factory = ts::take_shared<StrategyFactory>(&scenario);
        let mut strategy_manager = ts::take_shared<StrategyManager>(&scenario);
        let mut allocation_manager = ts::take_shared<AllocationManager>(&scenario);
        let mut delegation_manager = ts::take_shared<DelegationManager>(&scenario);
        let mut avs_directory = ts::take_shared<AVSDirectory>(&scenario);
        let mut hello_world_service_manager = ts::take_shared<HelloWorldServiceManager>(&scenario);

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
        let strategy_ids = vector[strategy_id];

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

        // Delegate the shares to the operator   
        delegation_module::delegate(
            &strategy_manager,
            &allocation_manager, 
            &mut delegation_manager, 
            operator, 
            &the_clock,
            ts::ctx(&mut scenario)
        );

        let operator_shares = delegation_module::get_operator_shares(&delegation_manager, operator, strategy_ids);
        let operator_shares2 = delegation_module::get_operator_shares(&delegation_manager, operator2, strategy_ids);
        
        assert!(*vector::borrow(&operator_shares, 0) > 0, 5);
        assert!(*vector::borrow(&operator_shares2, 0) == 0, 6);

        // ========== REGISTER OPERATOR 2 ========== //
        ts::next_tx(&mut scenario, operator2);

        let metadata_uri = string::utf8(b"metadata_uri_2");
        delegation_module::register_as_operator(&strategy_manager, &allocation_manager, &mut delegation_manager, metadata_uri, ts::ctx(&mut scenario));
        
        // ========== REGISTER OPERATOR TO AVS ========== //  
        // ts::next_tx(&mut scenario, operator2);

        // // Contruct signed message
        // let expiry = clock::timestamp_ms(&the_clock) + 1_000;
        // let salt = vector[1, 2, 3];

        // let mut msg = vector::empty<u8>();
        // vector::append(&mut msg, salt);
        // vector::append(&mut msg, bcs::to_bytes<u64>(&expiry));

        // let signature = ed25519::ed25519_sign(
        //     &msg, 
        //     ts::ctx(&mut scenario)
        // );

        // hello_world_service_manager::register_operator(
        //     &mut avs_directory,
        //     &delegation_manager,
        //     signature,
        //     salt,
        //     expiry,
        //     &the_clock,
        //     ts::ctx(&mut scenario)
        // );

        // ========== REDELEGATE ========== //
        ts::next_tx(&mut scenario, staker);
        
        clock::increment_for_testing(&mut the_clock, 10000);

        let withdrawal_roots = delegation_module::redelegate(
            &mut strategy_manager,
            &allocation_manager, 
            &mut delegation_manager, 
            operator2, 
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // // ========== UNDELEGATE ========== //
        // ts::next_tx(&mut scenario, staker);

        // let withdrawal_roots = delegation_module::undelegate(
        //     &mut strategy_manager,
        //     &allocation_manager, 
        //     &mut delegation_manager, 
        //     staker,
        //     ts::ctx(&mut scenario)
        // );

        // let u_operator_shares = delegation_module::get_operator_shares(&delegation_manager, operator, strategy_ids);
        
        // assert!(*vector::borrow(&u_operator_shares, 0) == 0, 6);

        // Withdraw the shares
        // Increment epoch number to 100
        let mut x = 0;
        while (x <= 100) {
            tx_context::increment_epoch_number(ts::ctx(&mut scenario));
            x = x + 1;
        };

        delegation_module::complete_queued_withdrawal<LBTC>(
            &mut strategy_factory,
            &mut strategy_manager,
            &allocation_manager, 
            &mut delegation_manager, 
            *vector::borrow(&withdrawal_roots, 0),
            false, // receive_as_coins
            ts::ctx(&mut scenario)
        );

        // let coin_withdrawn = ts::take_from_sender<Coin<LBTC>>(&scenario);
        // assert!(coin::value(&coin_withdrawn) == amount, 4);

        // ts::return_to_sender(&scenario, coin_withdrawn);

        // ========== RETURN/CLOSE OBJECTS ========== //
        ts::next_tx(&mut scenario, admin);

        clock::destroy_for_testing(the_clock);
        ts::return_shared(strategy_factory);
        ts::return_shared(strategy_manager);
        ts::return_shared(allocation_manager);
        ts::return_shared(delegation_manager);
        ts::return_shared(faucet);
        ts::return_shared(avs_directory);
        ts::return_shared(hello_world_service_manager);
        ts::return_to_sender(&scenario, treasury_cap);
        ts::end(scenario);
    }
}