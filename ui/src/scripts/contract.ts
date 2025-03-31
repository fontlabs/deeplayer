import { TransactionBlock } from "sui-dapp-kit-vue";
import type { Strategy } from "./types";
import { CoinAPI } from "./coin";

const Contract = {
  deeplayer: "0x",
  avsDirectory: "0x",
  strategyFactory: "0x",
  strategyManager: "0x",
  rewardsCondinator: "0x",
  delegationManager: "0x",
  allocationManager: "0x",

  async depositIntoStrategy(
    sender: string,
    strategy: Strategy,
    amount: bigint
  ): Promise<TransactionBlock> {
    const transaction = new TransactionBlock();

    const coins = await CoinAPI.getCoins(sender, strategy.coin.type);
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
      typeArguments: [strategy.coin.type],
    });

    return transaction;
  },
};

export { Contract };
