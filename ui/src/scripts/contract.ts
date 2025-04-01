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

  client: new SuiClient({ url: getFullnodeUrl("testnet") }),

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
    const transaction = new TransactionBlock();

    const coins = await CoinAPI.getCoins(sender, strategy.type);
    const coinsObject = coins.data.map((coin) => coin.coinObjectId);

    const destinationInCoin = coinsObject[0];

    if (coinsObject.length > 1) {
      const [, ...otherInCoins] = coinsObject;
      transaction.mergeCoins(destinationInCoin, otherInCoins);
    }

    const [coinDesposited] = transaction.splitCoins(destinationInCoin, [
      transaction.pure.u64(amount),
    ]);

    transaction.moveCall({
      target: `${this.deeplayer}::strategy_manager_module::deposit_into_strategy`,
      arguments: [
        transaction.object(this.strategyManager),
        transaction.object(this.delegationManager),
        transaction.object(strategy.address),
        transaction.object(coinDesposited),
      ],
      typeArguments: [strategy.type],
    });

    return transaction;
  },
};

export { Contract };
