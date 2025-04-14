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
    use deeplayer::utils_module;
    use deeplayer::lbtc::{Self, LBTC, Faucet};
    use deeplayer::strategy_module::{Self, Strategy};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};
    use deeplayer::allocation_module::{Self, AllocationManager};
    use deeplayer::delegation_module::{Self, DelegationManager};
    use deeplayer::avs_directory_module::{Self, AVSDirectory};
    use deeplayer::avs_manager_module::{Self, AVSManager};
    use deeplayer::rewards_module::{Self, RewardsCoordinator, RewardsSubmission};
    use deeplayer::nebula::{Self, Nebula, NebulaCap, Pool, Claim};

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

        avs_manager_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        nebula::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        // ========== TAKE OBJECTS ========== //

        let mut treasury_cap = ts::take_from_sender<TreasuryCap<LBTC>>(&scenario);
        let mut faucet = ts::take_shared<Faucet<LBTC>>(&scenario);
        let mut strategy_factory = ts::take_shared<StrategyFactory>(&scenario);
        let mut strategy_manager = ts::take_shared<StrategyManager>(&scenario);
        let mut allocation_manager = ts::take_shared<AllocationManager>(&scenario);
        let mut delegation_manager = ts::take_shared<DelegationManager>(&scenario);
        let mut avs_directory = ts::take_shared<AVSDirectory>(&scenario);
        let mut avs_manager = ts::take_shared<AVSManager>(&scenario);
        let mut nebula = ts::take_shared<Nebula>(&scenario);   
        let mut nebula_cap = ts::take_from_sender<NebulaCap>(&scenario);


        // ========== CREATE COIN ========== //
        ts::next_tx(&mut scenario, admin);

        lbtc::init_supply(&mut treasury_cap, &mut faucet, ts::ctx(&mut scenario));
        
        // ========== MINT COIN ========== //
        ts::next_tx(&mut scenario, admin);

        let amount = 100_000;
        lbtc::mint(&mut faucet, amount, staker, ts::ctx(&mut scenario));
        
        // Verify staker got the coins
        ts::next_tx(&mut scenario, admin);
        let coin = ts::take_from_address<Coin<LBTC>>(&scenario, staker);
        assert!(coin::value(&coin) == amount, 2);
        ts::return_to_address(staker, coin);
        
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

        let strategy_id = utils_module::get_strategy_id<LBTC>();
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
        ts::next_tx(&mut scenario, operator);

        nebula::register_operator(
            &mut avs_manager,
            &mut avs_directory,
            &delegation_manager,
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // ========== REGISTER OPERATOR2 TO AVS ========== //  
        ts::next_tx(&mut scenario, operator2);

        nebula::register_operator(
            &mut avs_manager,
            &mut avs_directory,
            &delegation_manager,
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // =========== DEPOSIT INTO NEBULA ========== //
        ts::next_tx(&mut scenario, admin);

        // Mint coins to deposit into nebula
        let nebula_amount = 100_000;
        lbtc::mint(&mut faucet, nebula_amount, admin, ts::ctx(&mut scenario));
        
        ts::next_tx(&mut scenario, admin);
        let nebula_coin_deposited = ts::take_from_address<Coin<LBTC>>(&scenario, admin);

        nebula::deposit<LBTC>(
            &mut nebula,
            &nebula_cap,
            nebula_coin_deposited,
            ts::ctx(&mut scenario)
        );

        nebula::set_required_operator_weight(
            &mut avs_manager,
            &nebula_cap,
            0, // min_weight
        );

        nebula::set_quorum(
            &mut avs_manager,
            &nebula_cap,
            vector[utils_module::get_strategy_id<LBTC>()], // strategy_ids
            vector[10_000] // multipliers
        );

        let operator_weight = avs_manager_module::get_operator_weight(&avs_manager, &delegation_manager, @nebula, operator);
        debug::print(&operator_weight);

        // =========== ATTEST TO NEBULA EVENT ========== //
        ts::next_tx(&mut scenario, operator);

        nebula::attest<LBTC>(
            &mut nebula,
            &avs_manager,
            &avs_directory,
            &delegation_manager,
            vector[0, 2], // source_uid,
            17000, // source_chain
            12, // source_block_number
            100_000, // amount
            9, // decimals
            staker, // receiver
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // =========== ATTEST2 TO NEBULA EVENT ========== //
        ts::next_tx(&mut scenario, operator2);

        nebula::attest<LBTC>(
            &mut nebula,
            &avs_manager,
            &avs_directory,
            &delegation_manager,
            vector[0, 2], // source_uid,
            17000, // source_chain
            12, // source_block_number
            100_000, // amount
            9, // decimals
            staker, // receiver
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // ========== UNDELEGATE ========== //
        ts::next_tx(&mut scenario, staker);

        let withdrawal_roots = delegation_module::undelegate(
            &mut strategy_manager,
            &allocation_manager, 
            &mut delegation_manager, 
            staker,
            ts::ctx(&mut scenario)
        );

        let u_operator_shares = delegation_module::get_operator_shares(&delegation_manager, operator, strategy_ids);
        
        assert!(*vector::borrow(&u_operator_shares, 0) == 0, 6);

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
            true, // receive_as_coins
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
        ts::return_shared(avs_manager);
        ts::return_shared(avs_directory);
        ts::return_to_sender(&scenario, treasury_cap);
        ts::return_shared(nebula);
        ts::return_to_sender(&scenario, nebula_cap);
        ts::end(scenario);
    }

    #[test]
    fun reward_claiming() {
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

        rewards_module::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, admin);

        // ========== TAKE OBJECTS ========== //

        let mut treasury_cap = ts::take_from_sender<TreasuryCap<LBTC>>(&scenario);
        let mut faucet = ts::take_shared<Faucet<LBTC>>(&scenario);
        let mut rewards_coordinator = ts::take_shared<RewardsCoordinator>(&scenario);

        // ========== CREATE COIN ========== //
        ts::next_tx(&mut scenario, admin);

        lbtc::init_supply(&mut treasury_cap, &mut faucet, ts::ctx(&mut scenario));
        
        // ========== MINT COIN ========== //
        ts::next_tx(&mut scenario, admin);

        let amount = 100_000 + 150_000;
        lbtc::mint(&mut faucet, amount, admin, ts::ctx(&mut scenario));
        
        // Verify admin got the coins
        ts::next_tx(&mut scenario, admin);
        let coin = ts::take_from_address<Coin<LBTC>>(&scenario, admin);
        assert!(coin::value(&coin) == amount, 2);
        ts::return_to_address(admin, coin);

        // ========== CREATE REWARD SUBMISSION ========== //
        ts::next_tx(&mut scenario, admin);

        let coin_rewards = ts::take_from_sender<Coin<LBTC>>(&scenario);

        let rewards_root = rewards_module::create_avs_rewards_submission<LBTC>(
            &mut rewards_coordinator, 
            @nebula,
            10_000, // duration,
            coin_rewards,
            vector[staker, operator], // claimers
            vector[100_000, 150_000], // amounts
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // ========== CLAIM REWARDS ========== //
        ts::next_tx(&mut scenario, staker);

        let amount = rewards_module::get_allocation_amount<LBTC>(
            &rewards_coordinator, 
            rewards_root,
            staker
        );

        assert!(amount == 100_000, 2);

        rewards_module::claim_rewards<LBTC>(
            &mut rewards_coordinator, 
            rewards_root,
            &the_clock,
            ts::ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, operator);

        let amount2 = rewards_module::get_allocation_amount<LBTC>(
            &rewards_coordinator, 
            rewards_root,
            operator
        );

        assert!(amount2 == 150_000, 2);

        clock::increment_for_testing(&mut the_clock, 999);

        rewards_module::claim_rewards<LBTC>(
            &mut rewards_coordinator, 
            rewards_root,
            &the_clock,
            ts::ctx(&mut scenario)
        );

        // ========== RETURN/CLOSE OBJECTS ========== //
        ts::next_tx(&mut scenario, admin);

        clock::destroy_for_testing(the_clock);
        ts::return_shared(faucet);
        ts::return_shared(rewards_coordinator);
        ts::return_to_sender(&scenario, treasury_cap);
        ts::end(scenario);
    }
}