// SPDX-License-Identifier: MIT
module deeplayer::rewards_module {
    use sui::object::{Self, UID}; 
    use sui::clock;
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::bcs;
    use sui::bag::{Self, Bag};
    use sui::table;

    use deeplayer::strategy_module::{Strategy};
    use deeplayer::delegation_module::{Self, DelegationManager};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};

    // Errors
    const E_PAUSED: u64 = 1;
   
    public struct RewardsSubmission<phantom COIN> has store {
        unclaimed: balance::Balance<COIN>,
        claimed: u64,
        start_timestamp: u64,
        duration: u64,
    }

    public struct RewardsCoordinator has key {
        id: UID,
        is_paused: bool,
        rewards_submissions: bag::Bag,
        rewards_submission_claims: table::Table<vector<u8>, table::Table<address, bool>>,
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let rewards_coordinator = RewardsCoordinator {
            id: object::new(ctx),
            is_paused: false,
            rewards_submissions: bag::new(ctx),
            rewards_submission_claims: table::new<vector<u8>, table::Table<address, bool>>(ctx)
        };

        transfer::share_object(rewards_coordinator);
    }

    // Public functions
    public entry fun create_avs_rewards_submission<COIN>(
        rewards_coordinator: &mut RewardsCoordinator,
        avs: address,
        duration: u64,
        coin_rewards: coin::Coin<COIN>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        check_not_paused(rewards_coordinator);
        
        let rewards_submission = RewardsSubmission {
            unclaimed: coin::into_balance(coin_rewards),
            claimed: 0,
            start_timestamp: clock::timestamp_ms(the_clock),
            duration: duration
        };

        let rewards_root = calc_rewards_root<COIN>(&rewards_submission, avs);

        bag::add(&mut rewards_coordinator.rewards_submissions, rewards_root, rewards_submission);
    }

    public entry fun claim_rewards<COIN>(
        rewards_coordinator: &mut RewardsCoordinator,
        delegation_manager: &DelegationManager,
        strategy_manager: &StrategyManager,
        strategy: &Strategy<COIN>,
        rewards_root: vector<u8>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        check_not_paused(rewards_coordinator);

        let strategy_address = object::id_to_address(&object::id(strategy));

        let staker = tx_context::sender(ctx);
        let rewards_submission = bag::borrow_mut<vector<u8>, RewardsSubmission<COIN>>(
            &mut rewards_coordinator.rewards_submissions, 
            rewards_root
        );

        let total_rewards = balance::value(&rewards_submission.unclaimed) + rewards_submission.claimed;

        // let total_shares = 0;
        // let staker_shares = strategy_manager_module::staker_deposit_shares(
        //     strategy_manager,
        //     staker,
        //     strategy_address
        // );

    }

    fun calc_rewards_root<COIN>(
        rewards_submission: &RewardsSubmission<COIN>,
        avs: address
    ): vector<u8> {
        let mut root = vector::empty<u8>();
        vector::append(&mut root, bcs::to_bytes<u64>(&rewards_submission.start_timestamp));
        vector::append(&mut root, bcs::to_bytes<u64>(&rewards_submission.duration));
        vector::append(&mut root, bcs::to_bytes<address>(&avs));
        root
    }

    fun check_not_paused(
        rewards_coordinator: &RewardsCoordinator,
    ) {
        assert!(!rewards_coordinator.is_paused, E_PAUSED)
    }
}