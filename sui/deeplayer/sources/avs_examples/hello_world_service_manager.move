module deeplayer::hello_world_service_manager {
    use std::string;
    use sui::event;
    use sui::table;
    use sui::bcs;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use deeplayer::signature_module::{Self, SignatureWithSaltAndExpiry};

    // Constants
    const E_OPERATOR_NOT_REGISTERED: u64 = 0;
    const E_TASK_MISMATCH: u64 = 1;
    const E_RESPONSE_TIME_EXPIRED: u64 = 2;
    const E_REFERENCE_BLOCK_MISMATCH: u64 = 3;
    const E_OPERATOR_ALREADY_RESPONDED: u64 = 4;
    const E_INVALID_SIGNATURE: u64 = 5;
    const E_TASK_ALREADY_RESPONDED: u64 = 6;
    const E_RESPONSE_TIME_NOT_EXPIRED: u64 = 7;
    const E_OPERATOR_NOT_REGISTERED_AT_TASK: u64 = 8;

    // Structs
    public struct OwnerCap has key { 
        id: UID
    }

    public struct Task has copy, drop {
        name: string::String,
        task_created_block: u64,
    }

    public struct TaskResponse has copy, drop {
        value: string::String,
    }

    public struct HelloWorldServiceManager has key {
        id: UID,
        max_response_interval_blocks: u64,
        task_infos: table::Table<u64, TaskInfo>,
        latest_task_num: u64,
    }

    public struct TaskInfo has copy, drop, store {
        id: UID,
        task_hash: vector<u8>,
        confirmations: u64,
        responded: bool
    }

    // Events
    struct NewTaskCreated has copy, drop {
        task_index: u64,
        task: Task,
    }

    public struct TaskConfirmation has copy, drop {
        task_index: u64,
        task_response: TaskResponse,
        operator: address,
    }
    
    public struct TaskResponded has copy, drop {
        task_index: u64,
        task: Task,
        task_response: TaskResponse,
    }

    public struct OperatorSlashed has copy, drop {
        task_index: u64,
        operator: address,
    }

    // Initializer
    fun init(
        ctx: &mut TxContext
    ) {
        let service_manager = HelloWorldServiceManager {
            id: object::new(ctx),
            max_response_interval_blocks: 500,
            task_infos: table::new<u64, TaskInfo>(ctx),
            latest_task_num: 0,
        }

        transfer::share_object(service_manager);

        let owner_cap = OwnerCap {
            id: object::new(ctx)
        }

        transfer::transfer(owner_cap, tx_context::sender(ctx));
    }

    // Public functions
    public entry fun create_new_task(
        service_manager: &mut HelloWorldServiceManager,
        name: string::String,
        ctx: &mut TxContext
    ) {
        let new_task = Task {
            name,
            task_created_block: tx_context::epoch(ctx),
        };

        let task_index = service_manager.latest_task_num;
        let task_hash = calculate_task_hash(&new_task);
        let task_info = TaskInfo {
            id: object::new(ctx),
            task_hash,
            confirmations: 0,
            responded: false
        };

        table::add(&mut service_manager.task_infos, task_index, task_info);

        event::emit(NewTaskCreated {
            task_index,
            task: new_task,
        });

        service_manager.latest_task_num = task_index + 1;
    }

    public entry fun respond_to_task(
        service_manager: &mut HelloWorldServiceManager,
        task: &Task,
        task_response: &TaskResponse,
        reference_task_index: u64,
        signature_data: &SignatureWithSaltAndExpiry,
        the_clock: &clock::Clock,
        ctx: &mut TxContext
    ) {
        let operator = tx_context::sender(ctx);

        // Check task hash matches
        let task_hash = calculate_task_hash(&task);
        let task_info = get_task_info(service_manager, reference_task_index);

        assert!(task_hash == task_info.task_hash, E_TASK_MISMATCH);

        // Check response time
        assert!(
            tx_context::epoch(ctx) <= task.task_created_block + service_manager.max_response_interval_blocks,
            E_RESPONSE_TIME_EXPIRED
        );

        let verify = signature_module::verify(
            signature_data,
            operator,
            the_clock,
            ctx
        );

        assert!(verify, E_INVALID_SIGNATURE);
        
        // stake_registry::validate(operator);

        task_info.confirmations = task_info.confirmations + 1;

        event::emit(TaskConfirmation {
            task_index: reference_task_index,
            task_response,
            operator
        });

        if (task_info.confirmations >= MIN_CONFIRMATIONS) {
            task_info.responded = true;

            event::emit(TaskResponded {
                task_index: reference_task_index,
                task,
                task_response
            });
        }
    }

    public entry fun slash_operator(
        owner_cap: &OwnerCap,
        service_manager: &mut HelloWorldServiceManager,
        task: &Task,
        reference_task_index: u64,
        operator: address,
        ctx: &mut TxContext
    ) {
        // Check task hash matches
        let task_hash = calculate_task_hash(task);
        let task_info = get_task_info(service_manager, reference_task_index);
        
        assert!(task_hash == task_info.task_hash, E_TASK_MISMATCH);

        // Check task has been responded
        assert!(is_task_responded(service_manager, reference_task_index), E_TASK_ALREADY_RESPONDED);

        // Check operator was registered when task was created
        // let operator_weight = get_operator_weight_at_block(stake_registry, operator, task.task_created_block);
        // assert!(operator_weight > 0, E_OPERATOR_NOT_REGISTERED_AT_TASK);

        event::emit(OperatorSlashed {
            task_index: reference_task_index,
            operator,
        });

        // slasher_module::slash_operator()
    }

    // View functions
    public fun get_latest_task_num(
        service_manager: &HelloWorldServiceManager
    ): u64 {
        service_manager.latest_task_num
    }

    public fun get_max_response_interval_blocks(
        service_manager: &HelloWorldServiceManager
    ): u64 {
        service_manager.max_response_interval_blocks
    }

    public fun is_task_responded(
        service_manager: &mut HelloWorldServiceManager,
        reference_task_index: u64
    ): bool {
        let task_info = get_task_info(service_manager, reference_task_index);
        task_info.responded
    }

    // Helper functions
    fun calculate_task_hash(
        task: &Task
    ): vector<u8> {
        let mut hash = vector::empty<u8>();
        vector::append(&mut hash, bcs::to_bytes<string::String>(&task.name));
        vector::append(&mut hash, bcs::to_bytes<u64>(task.task_created_block));
        hash
    }

    fun get_task_info(
        service_manager: &mut HelloWorldServiceManager,
        task_index: u64
    ): &mut TaskInfo {
        table::borrow_mut(&mut service_manager.task_infos, task_index);
    }

    fun get_operator_weight_at_block(
        stake_registry: address,
        operator: address,
        block_number: u64
    ): u64 {
        // Simplified weight check
        // In real implementation, query stake registry
        1
    }
}