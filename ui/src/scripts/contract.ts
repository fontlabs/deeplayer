import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

const Contract = {
  DeepLayer:
    "0xf52e10b4ceb96a57686e6df13661e1873e1b02ad566e560c106ad70ff2c4bdfe",
  AVSDirectory:
    "0x6c657abead0a727adb3b95e8b27dc66e6c774041f2ae1fb1f95a30c8a0fd8e32",
  StrategyFactory:
    "0xcc628e6a4e73cbe20974dfd6d66d778e3521f39f805ac03a63b59302aa469703",
  StrategyManager:
    "0x66164e4c4d7aa32c9ce81e02a5c335c21160f850890b929b77e84786f711d986",
  RewardsCoordinator:
    "0xea669ed0d6ebb63a64da296dd1253d32056d2addab322d407edc29099cfaf573",
  AllocationManager:
    "0x026a05d8070e624cb815e48235b51b389e5d25912d6cc4027acd3c37e77fa7f6",
  DelegationManager:
    "0x0a54afc3604e4c22a9127b0e687d3860df93eeb3723461d5be247acfdcfd0719",

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
    operator: string,
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

      // tx.moveCall({
      //   target: `${this.DeepLayer}::delegation_module::delegate`,
      //   arguments: [
      //     tx.object(this.StrategyManager),
      //     tx.object(this.AllocationManager),
      //     tx.object(this.DelegationManager),
      //     tx.pure.address(operator),
      //     tx.object(SUI_CLOCK_OBJECT_ID),
      //   ],
      // });

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
