import { Transaction } from "@mysten/sui/transactions";
import { Addresses, client, signer } from "./shared";

const Coins = [
  { module: "afsui", coinType: "AFSUI", treasuryCap: "", faucet: "" },
  { module: "hasui", coinType: "HASUI", treasuryCap: "", faucet: "" },
  { module: "pyth", coinType: "PYTH", treasuryCap: "", faucet: "" },
  { module: "stsui", coinType: "STSUI", treasuryCap: "", faucet: "" },
  { module: "cert", coinType: "CERT", treasuryCap: "", faucet: "" },
  { module: "wbtc", coinType: "WBTC", treasuryCap: "", faucet: "" },
];

async function initSupply(
  module: string,
  coinType: string,
  treasuryCap: string,
  faucet: string
) {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Addresses.DeepLayer}::${module}::init_supply`,
    arguments: [transaction.object(treasuryCap), transaction.object(faucet)],
    typeArguments: [coinType],
  });
  transaction.setGasBudget(500_000);
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
}

main();
