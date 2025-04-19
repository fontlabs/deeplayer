module deeplayer::daxios {
    use std::string;
    use sui::event;
    use sui::sui::{SUI};
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
    use sui::address;

    use deeplayer::math_module;
    use deeplayer::utils_module;
    use deeplayer::avs_manager_module::{Self, AVSManager};
    use deeplayer::avs_directory_module::{AVSDirectory};
    use deeplayer::delegation_module::{Self, DelegationManager};

    const E_INVALID_SIGNATURE: u64 = 0;

    public struct Request has copy, drop {
        url: string::String,
        body: string::String,
        headers: string::String
    }

    public struct Response<T> has copy, store, drop {
        data: T,
        operator: address
    }

    public struct DAxios has key {
        id: UID,
        responses: bag::Bag,
        request_ids: u64,
        fees: balance::Balance<SUI>
    }

    public struct GetRequestCreated<phantom T> has copy, drop {
        request_id: vector<u8>,
        url: string::String,
        headers: string::String
    }

    public struct PostRequestCreated<phantom T> has copy, drop {        
        request_id: vector<u8>,
        url: string::String,
        body: string::String,
        headers: string::String
    }

    fun init(
        ctx: &mut TxContext
    ) {
        let daxios = DAxios {
            id: object::new(ctx),
            responses: bag::new(ctx),
            request_ids: 0,
            fees: balance::zero<SUI>()
        };

        transfer::share_object(daxios);
    }

    public fun get<T: copy, store, drop>(
        daxios: &mut DAxios,
        request: Request,
        fee: coin::Coin<SUI>
    ): vector<u8> {
        balance::join(&mut daxios.fees, coin::into_balance(fee));

        let request_id = create_request_id(daxios);
        event::emit(GetRequestCreated<T> {            
            request_id,
            url: request.url,
            headers: request.headers
        });

        request_id
    }

    public fun post<T: copy, store, drop>(
        daxios: &mut DAxios,
        request: Request,
        fee: coin::Coin<SUI>
    ): vector<u8> {
        balance::join(&mut daxios.fees, coin::into_balance(fee));

        let request_id = create_request_id(daxios);
        event::emit(PostRequestCreated<T> {
            request_id,
            url: request.url,
            body: request.body,
            headers: request.headers
        });
        
        request_id
    }

    public entry fun respond<T: copy, store, drop>(
        daxios: &mut DAxios,
        avs_manager: &AVSManager,
        avs_directory: &AVSDirectory,
        delegation_manager: &DelegationManager,
        signature: vector<u8>,
        operator: address,
        request_id: vector<u8>,
        data: T
    ) {
        assert!(ed25519::ed25519_verify(
            &signature, 
            &address::to_bytes(operator), 
            &request_id
        ), E_INVALID_SIGNATURE);

        avs_manager_module::check_operator(
            avs_manager,
            avs_directory,
            delegation_manager,
            @daxios,
            operator
        );   
        
        bag::add(&mut daxios.responses, request_id, Response<T> {
            data,
            operator
        });
    }

    public fun get_response<T: copy, store, drop>(
        daxios: &DAxios,
        request_id: vector<u8>
    ): Response<T> {
        *bag::borrow<vector<u8>, Response<T>>(&daxios.responses, request_id)
    }

    public fun new_request(
        url: string::String,
        body: string::String,
        headers: string::String
    ): Request {
        Request { url, body, headers }
    }

    fun create_request_id(
        daxios: &mut DAxios
    ): vector<u8> {
        daxios.request_ids = daxios.request_ids + 1; 
        bcs::to_bytes<u64>(&daxios.request_ids)
    }
}