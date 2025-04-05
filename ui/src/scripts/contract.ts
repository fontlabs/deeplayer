import { TransactionBlock } from "sui-dapp-kit-vue";
import type { Coin } from "./types";
import { CoinAPI } from "./coin";
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";

const Contract = {
  deeplayer:
    "0x43d20dbffe39e23263ac2f3e5c1d0222b6ba23dfa0855960638db8f81283fb08",
  avsDirectory:
    "0x8a9025ce03a3622f5b65ac3db581942f1c82e95b9dcad1811ab2d5a5dad29eed",
  strategyFactory:
    "0x1b8c4dc84618e8e2a9c16927586d7103ec60be9433b21f7f38a34481919ae87f",
  strategyManager:
    "0x938488fd5822bcf09ac4c5893fef2c1bea79309b14017821e38b64039046335e",
  rewardsCondinator: "0x",
  delegationManager:
    "0x08acd45115e553de930f6a4ef979c90214101168d44d0338f321490e9b2be3df",
  allocationManager:
    "0x0118a11fa89531de7bd09658d913ae79ad97d726bc1df884bcbedb56bcd7eea5",

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

  async getStakerShares(
    strategyId: string,
    sender: string
  ): Promise<TransactionBlock | null> {
    try {
      const transactionBlock = new TransactionBlock();

      transactionBlock.moveCall({
        target: `${this.deeplayer}::strategy_manager_module::get_staker_shares`,
        arguments: [
          transactionBlock.object(this.strategyManager),
          transactionBlock.pure.string(strategyId),
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
