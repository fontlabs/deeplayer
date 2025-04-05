import { CoinType } from "./../../ui/src/scripts/types";
import { Transaction } from "@mysten/sui/transactions";
import { Addresses, client, Coins, signer } from "./shared";

async function deployStrategy(coinType: string) {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Addresses.DeepLayer}::strategy_factory_module::deploy_new_strategy`,
    arguments: [transaction.object(Addresses.StrategyFactory)],
    typeArguments: [coinType],
  });
  transaction.setGasBudget(5_000_000);
  const { digest } = await client.signAndExecuteTransaction({
    transaction,
    signer,
  });
  console.log("Transaction digest:", digest);
}

async function main() {
  for (const coin of Coins) {
    await deployStrategy(
      `${Addresses.DeepLayer}::${coin.module}::${coin.coinType}`
    );
  }
}

main();
