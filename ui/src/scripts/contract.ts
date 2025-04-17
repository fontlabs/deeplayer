import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

const Contract = {
  DeepLayer:
    "0x7b941196e87bbf0f0ee85717c68f49ad88ef598b81943ff4bde11dfea5e1b9a4",
  AVSDirectory:
    "0x9cad346e85eea93d429ab78aba5e1547bd9782fe41c30dfbe301a622957910cc",
  StrategyFactory:
    "0x469ae718fda2fcf93fa64ed4e8555ba03c521807ff0eb3ebc90d8ac78eb62aa9",
  StrategyManager:
    "0x72bc80b016c2d9faebfff315d3dd2e0d3d252f8335c51b09bcec2f1f9ee9a8fc",
  RewardsCoordinator:
    "0x5fe16ed96834f9f01a52e1a2a52d7a7a4a02fe9e8983575de70f92cee9c1fb62",
  AllocationManager:
    "0x3946025d5bb43d7538b5d50b18bf35356dfd4a29036e8253e8c7f548e085d6bc",
  DelegationManager:
    "0x4f9789410e46b594e2f67a2b0c5a1cedf4ac453f8083e4f800c5745d8bac1e48",

  mintCoin(sender: string, strategy: Coin, amount: bigint): Transaction | null {
    try {
      const tx = new Transaction();

      if (!strategy.faucet) return null;

      tx.moveCall({
        target: `${this.DeepLayer}::${strategy.faucet.module}::mint`,
        arguments: [
          tx.object(strategy.faucet.object),
          tx.pure.u64(amount),
          tx.pure.address(sender),
        ],
        typeArguments: [strategy.type],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },

  async depositIntoStrategy(
    sender: string,
    strategy: Coin,
    amount: bigint
  ): Promise<Transaction | null> {
    try {
      const tx = new Transaction();

      const coins = await CoinAPI.getCoins(sender, strategy.type);
      const coinsObject = coins.data.map((coin) => coin.coinObjectId);
      if (coinsObject.length === 0) return null;
      const destinationInCoin = coinsObject[0];
      if (coinsObject.length > 1) {
        const [, ...otherInCoins] = coinsObject;
        tx.mergeCoins(destinationInCoin, otherInCoins);
      }
      const [coinDesposited] = tx.splitCoins(destinationInCoin, [
        tx.pure.u64(amount),
      ]);

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::deposit_into_strategy`,
        arguments: [
          tx.object(this.StrategyFactory),
          tx.object(this.StrategyManager),
          tx.object(this.AllocationManager),
          tx.object(this.DelegationManager),
          tx.object(coinDesposited),
        ],
        typeArguments: [strategy.type],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },

  delegate(operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::delegate`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.object(this.AllocationManager),
        tx.object(this.DelegationManager),
        tx.pure.address(operator),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  },

  undelegate(staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::undelegate`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.object(this.AllocationManager),
        tx.object(this.DelegationManager),
        tx.pure.address(staker),
      ],
    });

    return tx;
  },

  redelegate(new_operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::redelegate`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.object(this.AllocationManager),
        tx.object(this.DelegationManager),
        tx.pure.address(new_operator),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  },

  getAllTotalShares(strategyIds: string[]): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::get_all_total_shares`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.pure(bcs.vector(bcs.String).serialize(strategyIds)),
      ],
    });

    return tx;
  },

  getStakerShares(strategyId: string, staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::get_staker_shares`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.pure.string(strategyId),
        tx.pure.address(staker),
      ],
    });

    return tx;
  },

  getAllStakerShares(strategyIds: string[], staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::get_all_staker_shares`,
      arguments: [
        tx.object(this.StrategyManager),
        tx.pure(bcs.vector(bcs.String).serialize(strategyIds)),
        tx.pure.address(staker),
      ],
    });

    return tx;
  },

  getDepositShares(staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::strategy_manager_module::deposit_shares`,
      arguments: [tx.object(this.StrategyManager), tx.pure.string(staker)],
    });

    return tx;
  },

  isDelegated(staker: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_delegated`,
      arguments: [tx.object(this.DelegationManager), tx.pure.address(staker)],
    });

    return tx;
  },

  isDelegatedTo(staker: string, operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_delegated_to`,
      arguments: [
        tx.object(this.DelegationManager),
        tx.pure.address(staker),
        tx.pure.address(operator),
      ],
    });

    return tx;
  },

  isOperator(account: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_operator`,
      arguments: [tx.object(this.DelegationManager), tx.pure.string(account)],
    });

    return tx;
  },

  getOperatorShares(strategyIds: string[], operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::get_operator_shares`,
      arguments: [
        tx.object(this.DelegationManager),
        tx.pure.address(operator),
        tx.pure(bcs.vector(bcs.String).serialize(strategyIds)),
      ],
    });

    return tx;
  },
};

export { Contract };
