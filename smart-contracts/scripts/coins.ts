import { Transaction } from "@mysten/sui/transactions";
import { Contract, client, Coins, signer, Eth_Coin } from "./shared";

async function initSupply(
  module: string,
  coinType: string,
  treasuryCap: string,
  faucet: string
) {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Contract.DeepLayer}::${module}::init_supply`,
    arguments: [transaction.object(treasuryCap), transaction.object(faucet)],
    typeArguments: [`${Contract.DeepLayer}::${module}::${coinType}`],
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
    await initSupply(coin.module, coin.coinType, coin.treasuryCap, coin.faucet);
  }
  await initSupply(
    Eth_Coin.module,
    Eth_Coin.coinType,
    Eth_Coin.treasuryCap,
    Eth_Coin.faucet
  );
}

main();
