module deeplayer::nebula {
    use std::string;
    use sui::event;
    use sui::table;
    use sui::balance;
    use sui::coin;
    use sui::bag;
    use sui::clock;
    use sui::bcs;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::ed25519;

    use deeplayer::math_module;
    use deeplayer::utils_module;
    use deeplayer::avs_manager_module::{Self, AVSManager};
    use deeplayer::avs_directory_module::{AVSDirectory};
    use deeplayer::delegation_module::{Self, DelegationManager};

    // Constants
    const MIN_ATTESTATIONS: u64 = 2;

    // Errors
    const E_ALREADY_CLAIMED: u64 = 1;
    const E_ALREADY_ATTESTED: u64 = 2;
    const E_INVALID_SIGNATURE: u64 = 3;
    const E_WRONG_SALT: u64 = 4;

    // Structs
    public struct Claim has copy, store {
        source_uid: vector<u8>,
        source_chain: u64,
        source_block_number: u64,
        amount: u64,
        receiver: address,
        attestations: vector<address>,
        claimed: bool
    }

    public struct Pool<phantom CoinType> has store {
        balance_underlying: balance::Balance<CoinType>
    }

    public struct Nebula has key {
        id: UID,
        min_attestations: u64,
        pools: bag::Bag,
        claims: table::Table<vector<u8>, Claim>
    }

    public struct NebulaCap has key { 
        id: UID
    }

    // Events
    public struct ClaimAttested has copy, drop {
        claim_root: vector<u8>,
        claimed: bool,
        operator: address
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let nebula = Nebula { 
            id: object::new(ctx),
            min_attestations: MIN_ATTESTATIONS,
            pools: bag::new(ctx),
            claims: table::new<vector<u8>, Claim>(ctx)
        };

        transfer::share_object(nebula);

        let cap = NebulaCap { 
            id: object::new(ctx) 
        };

        transfer::transfer(cap, tx_context::sender(ctx));

        avs_manager_module::update_avs_metadata_uri(
            @nebula,
            string::utf8(b"https://nebula.deep_layr.xyz/metadata.json"),
        );
    }

    public fun set_required_operator_weight(
        avs_manager: &mut AVSManager,
        cap: &NebulaCap,
        min_weight: u64
    ) {
        avs_manager_module::set_min_weight(avs_manager, @nebula, min_weight)
    }

    public fun set_quorum(
        avs_manager: &mut AVSManager,
        cap: &NebulaCap,
        strategy_ids: vector<string::String>,
        weights: vector<u64>
    ) {
        avs_manager_module::set_quorum(avs_manager, @nebula, strategy_ids, weights)
    }

    public entry fun deposit<CoinType>(
        nebula: &mut Nebula,
        cap: &NebulaCap,
        coin_deposited: coin::Coin<CoinType>,
        ctx: &mut TxContext
    ) {
        let coin_type = utils_module::get_strategy_id<CoinType>();
        if (!bag::contains(&nebula.pools, coin_type)) {
            bag::add(&mut nebula.pools, coin_type, Pool<CoinType> {
                balance_underlying: balance::zero<CoinType>()
            });
        };
        let mut pool = bag::borrow_mut<string::String, Pool<CoinType>>(&mut nebula.pools, coin_type);
        let balance_deposited = coin::into_balance(coin_deposited);
        balance::join(&mut pool.balance_underlying, balance_deposited);
    }

    public entry fun withdraw<CoinType>(
        nebula: &mut Nebula,
        cap: &NebulaCap,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coin_type = utils_module::get_strategy_id<CoinType>();
        let mut pool = bag::borrow_mut<string::String, Pool<CoinType>>(&mut nebula.pools, coin_type);
        let balance_withdrawn = balance::split(&mut pool.balance_underlying, amount);
        let coin_withdrawn = coin::from_balance(balance_withdrawn, ctx);
        transfer::public_transfer(coin_withdrawn, tx_context::sender(ctx));
    }

    public entry fun register_operator(
        avs_manager: &mut AVSManager,
        avs_directory: &mut AVSDirectory,
        delegation_manager: &DelegationManager,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        avs_manager_module::register_operator_to_avs(
            avs_manager,
            avs_directory,
            delegation_manager,
            @nebula,
            the_clock,
            ctx
        )
    }

    public entry fun attest<CoinType>(
        nebula: &mut Nebula,
        coin_metadata: &coin::CoinMetadata<CoinType>,
        avs_manager: &AVSManager,
        avs_directory: &AVSDirectory,
        delegation_manager: &DelegationManager,
        signatures: vector<vector<u8>>,
        signers: vector<address>,
        source_uid: vector<u8>,
        source_chain: u64,
        source_block_number: u64,
        amount: u64,
        decimals: u8,
        receiver: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext,
    ) {
        let mut i = 0;
        let len = vector::length(&signatures);
        while (i < len) {
            let signature = *vector::borrow(&signatures, i);
            let signer = *vector::borrow(&signers, i);
            
            // if (!ed25519::ed25519_verify(&signature, &bcs::to_bytes(&signer), &source_uid)) continue;

            attest_impl<CoinType>(
                nebula,
                coin_metadata,
                avs_manager,
                avs_directory,
                delegation_manager,
                signer,
                source_uid,
                source_chain,
                source_block_number,
                amount,
                decimals,
                receiver,
                the_clock,
                ctx
            );

            i = i + 1;
        };
    }

    fun attest_impl<CoinType>(
        nebula: &mut Nebula,
        coin_metadata: &coin::CoinMetadata<CoinType>,
        avs_manager: &AVSManager,
        avs_directory: &AVSDirectory,
        delegation_manager: &DelegationManager,
        operator: address,
        source_uid: vector<u8>,
        source_chain: u64,
        source_block_number: u64,
        amount: u64,
        decimals: u8,
        receiver: address,
        the_clock: &clock::Clock,
        ctx: &mut TxContext,
    ) {
        avs_manager_module::check_operator(
            avs_manager,
            avs_directory,
            delegation_manager,
            @nebula,
            operator
        );     

        let claim_root = get_claim_root(source_uid, source_chain, source_block_number, amount, decimals, receiver);

        if (!table::contains(&nebula.claims, claim_root)) {
            table::add(&mut nebula.claims, claim_root, Claim {
                source_uid,
                source_chain,
                source_block_number,
                amount,
                receiver,
                attestations: vector::empty<address>(),
                claimed: false
            });
        };

        let mut claim = table::borrow_mut(&mut nebula.claims, claim_root);

        // Check if the claim is already attested by operator
        assert!(!vector::contains(&claim.attestations, &operator), E_ALREADY_ATTESTED);

        // Attest the claim
        vector::push_back(&mut claim.attestations, operator);

        if (claim.claimed) {
            event::emit(ClaimAttested {
                claim_root,
                claimed: true,
                operator: operator
            });
        } else if (!claim.claimed && vector::length(&claim.attestations) >= nebula.min_attestations) {
            let coin_type = utils_module::get_strategy_id<CoinType>();
            let pool = bag::borrow_mut<string::String, Pool<CoinType>>(&mut nebula.pools, coin_type);
            let coin_decimals = coin::get_decimals(coin_metadata);
            let amount_claimed = math_module::scale(amount, decimals, coin_decimals);
            let balance_claimed = balance::split(&mut pool.balance_underlying, amount_claimed);
            let coin_claimed = coin::from_balance(balance_claimed, ctx);
            transfer::public_transfer(coin_claimed, receiver);

            event::emit(ClaimAttested {
                claim_root,
                claimed: true,
                operator: operator
            });
            
            claim.claimed = true;
        } else {
            event::emit(ClaimAttested {
                claim_root,
                claimed: false,
                operator: operator
            });
        };      
    }

    public entry fun set_min_attestations(
        nebula: &mut Nebula,
        cap: &NebulaCap,
        min_attestations: u64,
        ctx: &mut TxContext
    ) {
        nebula.min_attestations = min_attestations;
    }

    public fun get_claim_root(
        source_uid: vector<u8>,
        source_chain: u64,
        source_block_number: u64,
        amount: u64,
        decimals: u8,
        receiver: address
    ): vector<u8> {
        let mut root = vector::empty<u8>();
        vector::append(&mut root, source_uid);
        vector::append(&mut root, bcs::to_bytes(&source_chain));
        vector::append(&mut root, bcs::to_bytes(&source_block_number));
        vector::append(&mut root, bcs::to_bytes(&amount));
        vector::append(&mut root, bcs::to_bytes(&decimals));
        vector::append(&mut root, bcs::to_bytes(&receiver));
        root
    }

    #[test_only]
    public(package) fun init_for_testing(
        ctx: &mut TxContext,
    ) {
        init(ctx)
    }

    #[test_only]
    public fun verify_simple_sig(
        signature: vector<u8>,
        signer: address,
        msg: vector<u8>
    ): bool {
        ed25519::ed25519_verify(&signature, &bcs::to_bytes(&signer), &msg)
    }
}
