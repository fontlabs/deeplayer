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

    use deeplayer::utils_module;
    use deeplayer::strategy_module::{Strategy};
    use deeplayer::delegation_module::{Self, DelegationManager};
    use deeplayer::strategy_manager_module::{Self, StrategyManager};
    use deeplayer::strategy_factory_module::{Self, StrategyFactory};

    // Errors
    const E_PAUSED: u64 = 1;
    const E_AMOUNT_ZERO: u64 = 2;
    const E_TIMESTAMP_EXPIRED: u64 = 3;

    // Structs
    public struct RewardsSubmission<phantom CoinType> has store {
        unclaimed: balance::Balance<CoinType>,
        claimed: u64,
        allocations: table::Table<address, u64>,
        start_timestamp: u64,
        duration: u64,
    }

    public struct RewardsCoordinator has key {
        id: UID,
        is_paused: bool,
        rewards_submissions: bag::Bag,
        rewards_submission_claims: table::Table<vector<u8>, table::Table<address, bool>>,
    }

    // Events
    public struct RewardsSubmissionCreated has copy, drop {
        rewards_root: vector<u8>,
        avs: address,
        duration: u64
    }

    public struct RewardsSubmissionClaimed has copy, drop {
        rewards_root: vector<u8>,
        claimer: address,
        amount: u64
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
    public entry fun create_avs_rewards_submission<CoinType>(
        rewards_coordinator: &mut RewardsCoordinator,
        avs: address,
        duration: u64,
        coin_rewards: coin::Coin<CoinType>,
        claimers: vector<address>,
        amounts: vector<u64>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ): vector<u8> {
        check_not_paused(rewards_coordinator);

        assert!(vector::length(&claimers) == vector::length(&amounts), 0);
        
        let mut allocations = table::new<address, u64>(ctx);

        let mut i = 0;
        while (i < vector::length(&claimers)) {
            let claimer = *vector::borrow<address>(&claimers, i);
            let amount = *vector::borrow<u64>(&amounts, i);
            table::add(&mut allocations, claimer, amount);
            i = i + 1;
        };
        
        let rewards_submission = RewardsSubmission {
            unclaimed: coin::into_balance(coin_rewards),
            claimed: 0,
            allocations,
            start_timestamp: clock::timestamp_ms(the_clock),
            duration: duration
        };

        let rewards_root = calc_rewards_root<CoinType>(&rewards_submission, avs);

        bag::add(&mut rewards_coordinator.rewards_submissions, rewards_root, rewards_submission);

        event::emit(RewardsSubmissionCreated {
            rewards_root,
            avs,
            duration
        });

        rewards_root
    }

    public entry fun claim_rewards<CoinType>(
        rewards_coordinator: &mut RewardsCoordinator,
        rewards_root: vector<u8>,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        check_not_paused(rewards_coordinator);

        let claimer = tx_context::sender(ctx);
        let mut rewards_submission = bag::borrow_mut<vector<u8>, RewardsSubmission<CoinType>>(
            &mut rewards_coordinator.rewards_submissions, 
            rewards_root
        );

        assert!(clock::timestamp_ms(the_clock) < rewards_submission.start_timestamp + rewards_submission.duration, E_TIMESTAMP_EXPIRED);

        let amount = table::borrow_mut(&mut rewards_submission.allocations, claimer);
        assert!(*amount > 0, E_AMOUNT_ZERO);

        let balance_withdrawn = balance::split(&mut rewards_submission.unclaimed, *amount);
        let coin_withdrawn = coin::from_balance(balance_withdrawn, ctx);
        transfer::public_transfer(coin_withdrawn, claimer);
        rewards_submission.claimed = rewards_submission.claimed + *amount;

        event::emit(RewardsSubmissionClaimed {
            rewards_root,
            claimer,
            amount: *amount
        });

        *amount = 0;
    }

    // Helper functions
    fun calc_rewards_root<CoinType>(
        rewards_submission: &RewardsSubmission<CoinType>,
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

    // View functions
    public fun get_allocation_amount<CoinType>(
        rewards_coordinator: &RewardsCoordinator,
        rewards_root: vector<u8>,
        claimer: address
    ): u64 {
        if (!bag::contains<vector<u8>>(&rewards_coordinator.rewards_submissions, rewards_root)) {
            return 0;
        };
        let rewards_submission = bag::borrow<vector<u8>, RewardsSubmission<CoinType>>(&rewards_coordinator.rewards_submissions, rewards_root);
        if (!table::contains(&rewards_submission.allocations, claimer)) {
            return 0;
        };
        *table::borrow(&rewards_submission.allocations, claimer)
    } 

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext
    ) {
        init(ctx);
    }
}