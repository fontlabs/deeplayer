import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

const Contract = {
  DeepLayer:
    "0x2f0b1dd354dd818e3173c104d7e6f8a682fc8908c0920d85caf9bfb9a220dfba",
  AVSDirectory:
    "0x34fd078388478dd6767c4c0bf2c94a902a29a918d527065311ac08753f767f2d",
  StrategyFactory:
    "0xce7cda2fe94a759e88aa873317704186e29addbf78f6784cdbe422b7031a17fb",
  StrategyManager:
    "0xc7e24fa965bf58943438f581e3ac2bb140e0d64676f41562fa4b856ab633923b",
  RewardsCoordinator:
    "0x336dff21853ce350580d25a82f60d5eeb401bfeb18b51ea1ae157a9083e754bf",
  AllocationManager:
    "0xf7a6f3220a95a5ad5f0736fbd1a91be78a8721ad3406d211429ff0b138de4600",
  DelegationManager:
    "0x539715ec47e209b4d0264da8f3f5be41982ff21ed3bd90d9751ea8cd0dedde31",

  async mintCoin(
    sender: string,
    strategy: Coin,
    amount: bigint
  ): Promise<Transaction | null> {
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
        target: `${this.DeepLayer}::strategy_manager_module::deposit_into_strategy`,
        arguments: [
          tx.object(this.StrategyFactory),
          tx.object(this.StrategyManager),
          tx.object(coinDesposited),
        ],
        typeArguments: [strategy.type],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },

  async delegate(operator: string): Promise<Transaction | null> {
    try {
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
    } catch (error) {
      return null;
    }
  },

  async getTotalShares(
    strategyId: string,
    staker: string
  ): Promise<Transaction | null> {
    try {
      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::strategy_manager_module::get_total_shares`,
        arguments: [
          tx.object(this.StrategyManager),
          tx.pure.string(strategyId),
        ],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },

  async getStakerShares(
    strategyId: string,
    staker: string
  ): Promise<Transaction | null> {
    try {
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
    } catch (error) {
      return null;
    }
  },

  async getAllStakerShares(
    strategyIds: string[],
    staker: string
  ): Promise<Transaction | null> {
    try {
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
    } catch (error) {
      return null;
    }
  },

  async getDepositShares(staker: string): Promise<Transaction | null> {
    try {
      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::strategy_manager_module::deposit_shares`,
        arguments: [tx.object(this.StrategyManager), tx.pure.string(staker)],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },

  async isDelegated(staker: string): Promise<Transaction | null> {
    try {
      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::is_delegated`,
        arguments: [tx.object(this.DelegationManager), tx.pure.string(staker)],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },

  async isOperator(account: string): Promise<Transaction | null> {
    try {
      const tx = new Transaction();

      tx.moveCall({
        target: `${this.DeepLayer}::delegation_module::is_operator`,
        arguments: [tx.object(this.DelegationManager), tx.pure.string(account)],
      });

      return tx;
    } catch (error) {
      return null;
    }
  },
};

export { Contract };
