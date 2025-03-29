import { TransactionBlock } from "sui-dapp-kit-vue";
import type { Strategy } from "./types";
import { CoinAPI } from "./coin";

const Contract = {
  deeplayer: "0x",
  strategyManager: "0x",
  delegationManager: "0x",

  async depositIntoStrategy(
    sender: string,
    strategy: Strategy,
    amount: bigint
  ): Promise<TransactionBlock> {
    const block = new TransactionBlock();

    const coins = await CoinAPI.getCoins(sender, strategy.coin.type);
    const coinsObject = coins.data.map((coin) => coin.coinObjectId);

    const destinationInCoin = coinsObject[0];

    if (coinsObject.length > 1) {
      const [, ...otherInCoins] = coinsObject;
      block.mergeCoins(destinationInCoin, otherInCoins);
    }

    const [coinDesposited] = block.splitCoins(destinationInCoin, [
      block.pure.u64(amount),
    ]);

    block.moveCall({
      target: `${this.deeplayer}::strategy_manager_module::deposit_into_strategy`,
      arguments: [
        block.object(this.strategyManager),
        block.object(this.delegationManager),
        block.object(strategy.address),
        block.object(coinDesposited),
      ],
      typeArguments: [strategy.coin.type],
    });

    return block;
  },
};

export { Contract };
