import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

const Contract = {
  DeepLayer:
    "0x75883ea1ba2ba25d4ea8ef3fef720511af880936549e2927ddb8422db88691c7",
  AVSDirectory:
    "0x61dd4a12b50ec2494c422007c97efb1e200baf351b390db766fbf82fec677e1b",
  StrategyFactory:
    "0x148fb2188709766a2fd51c46e572ff42d9cdb512fcc891fb8c3267de3c724ee4",
  StrategyManager:
    "0x8395b1e9e6fcb845930ab3d97a807971cdc90cc1d5fff2bf45953ec750b98ca4",
  RewardsCoordinator:
    "0x40a8d600650b6f3947df6fe04f0018bb57f34efef311404403120e67d50904d1",
  AllocationManager:
    "0xf0dfffde1b7200b0d93de58aa4a4973cf1fc8a8e0eedebcad503f15c6d66dfe3",
  DelegationManager:
    "0x34dc47d3fee8a06103a130ff686d45ed54f56cc9aab4521001d979d45ada1b91",

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
      arguments: [tx.object(this.DelegationManager), tx.pure.string(staker)],
    });

    return tx;
  },

  isDelegatedTo(staker: string, operator: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.DeepLayer}::delegation_module::is_delegated_to`,
      arguments: [
        tx.object(this.DelegationManager),
        tx.pure.string(staker),
        tx.pure.string(operator),
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
};

export { Contract };
