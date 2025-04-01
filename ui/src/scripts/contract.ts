import { TransactionBlock } from "sui-dapp-kit-vue";
import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";

const Contract = {
  deeplayer:
    "0x61a6d51871eedde7f727323d16d0a5419c42e85276147978b5c5ce05e79ccaf0",
  avsDirectory: "0x",
  strategyFactory:
    "0x0292ed215f2daa67e526827b89804084457c5521732e922adb41c0bbcc744b3f",
  strategyManager: "0x",
  rewardsCondinator: "0x",
  delegationManager: "0x",
  allocationManager: "0x",

  async mintCoin(
    sender: string,
    strategy: Coin,
    amount: bigint
  ): Promise<TransactionBlock | null> {
    const transaction = new TransactionBlock();

    if (!strategy.faucet) return null;

    transaction.moveCall({
      target: `${this.deeplayer}::${strategy.faucet.module}::mint`,
      arguments: [
        transaction.object(strategy.faucet.object),
        transaction.pure.u64(amount),
        transaction.pure.address(sender),
      ],
      typeArguments: [strategy.type],
    });

    return transaction;
  },

  async depositIntoStrategy(
    sender: string,
    strategy: Coin,
    amount: bigint
  ): Promise<TransactionBlock | null> {
    const transactionBlock = new TransactionBlock();

    const coins = await CoinAPI.getCoins(sender, strategy.type);
    const coinsObject = coins.data.map((coin) => coin.coinObjectId);

    const destinationInCoin = coinsObject[0];

    if (coinsObject.length > 1) {
      const [, ...otherInCoins] = coinsObject;
      transactionBlock.mergeCoins(destinationInCoin, otherInCoins);
    }

    const [coinDesposited] = transactionBlock.splitCoins(destinationInCoin, [
      transactionBlock.pure.u64(amount),
    ]);

    transactionBlock.moveCall({
      target: `${this.deeplayer}::delegation_module::deposit_into_strategy`,
      arguments: [
        transactionBlock.object(this.strategyFactory),
        transactionBlock.object(this.strategyManager),
        transactionBlock.object(this.allocationManager),
        transactionBlock.object(this.delegationManager),
        transactionBlock.object(coinDesposited),
      ],
      typeArguments: [strategy.type],
    });

    return transactionBlock;
  },

  async getStakerDepositShares(
    sender: string
  ): Promise<TransactionBlock | null> {
    try {
      const transactionBlock = new TransactionBlock();

      transactionBlock.moveCall({
        target: `${this.deeplayer}::strategy_manager_module::staker_deposit_shares`,
        arguments: [
          transactionBlock.object(this.strategyManager),
          transactionBlock.pure.address(sender),
        ],
      });

      return transactionBlock;
    } catch (error) {
      return null;
    }
  },

  async getDepositShares(
    strategyIds: string[]
  ): Promise<TransactionBlock | null> {
    try {
      const transactionBlock = new TransactionBlock();

      strategyIds.forEach((strategyId) => {
        transactionBlock.moveCall({
          target: `${this.deeplayer}::strategy_manager_module::deposit_shares`,
          arguments: [
            transactionBlock.object(this.strategyManager),
            transactionBlock.pure.string(strategyId),
          ],
        });
      });

      return transactionBlock;
    } catch (error) {
      return null;
    }
  },
};

export { Contract };
