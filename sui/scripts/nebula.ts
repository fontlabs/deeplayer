import { Transaction } from "@mysten/sui/transactions";
import { client, Coins, Contract, Eth_Coin, signer } from "./shared";
import { bcs } from "@mysten/sui/bcs";

async function setMinWeight() {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Contract.DeepLayer}::nebula::set_required_operator_weight`,
    arguments: [
      transaction.object(Contract.AVSManager),
      transaction.object(Contract.NebulaCap),
      transaction.pure.u64(1_000),
    ],
  });
  transaction.setGasBudget(50_000_000);
  const { digest } = await client.signAndExecuteTransaction({
    transaction,
    signer,
  });
  console.log("Transaction digest:", digest);
}

async function setQuorum() {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Contract.DeepLayer}::nebula::set_quorum`,
    arguments: [
      transaction.object(Contract.AVSManager),
      transaction.object(Contract.NebulaCap),
      transaction.pure(
        bcs
          .vector(bcs.String)
          .serialize([
            "0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
            ...Coins.map((coin) =>
              `${Contract.DeepLayer}::${coin.module}::${coin.coinType}`.replace(
                "0x",
                ""
              )
            ),
          ])
      ),
      transaction.pure(
        bcs
          .vector(bcs.U64)
          .serialize([1_500, 1_500, 1_500, 1_500, 1_500, 1_500, 1_000])
      ),
    ],
  });
  transaction.setGasBudget(50_000_000);
  const { digest } = await client.signAndExecuteTransaction({
    transaction,
    signer,
  });
  console.log("Transaction digest:", digest);
}

async function mintCoins(
  amount: number,
  faucet: string,
  module: string,
  coinType: string
) {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Contract.DeepLayer}::${module}::mint`,
    arguments: [
      transaction.object(faucet),
      transaction.pure.u64(amount),
      transaction.pure.address(signer.getPublicKey().toSuiAddress()),
    ],
    typeArguments: [`${Contract.DeepLayer}::${module}::${coinType}`],
  });
  transaction.setGasBudget(5_000_000);
  const { digest } = await client.signAndExecuteTransaction({
    transaction,
    signer,
  });
  client.waitForTransaction({ digest });
  await new Promise((rv) => setTimeout(() => rv(null), 2_000));
  console.log("Transaction digest:", digest);
}

async function depositCoins(
  coin_deposited: string,
  module: string,
  coinType: string
) {
  const transaction = new Transaction();
  transaction.moveCall({
    target: `${Contract.DeepLayer}::nebula::deposit`,
    arguments: [
      transaction.object(Contract.Nebula),
      transaction.object(Contract.NebulaCap),
      transaction.object(coin_deposited),
    ],
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
  await setQuorum();
  await setMinWeight();

  // Deposit ETH
  const eth_amount = 1_000_000 * 10 ** 9;
  await mintCoins(
    eth_amount,
    Eth_Coin.faucet,
    Eth_Coin.module,
    Eth_Coin.coinType
  );
  const eth_coin_deposited = await client.getCoins({
    coinType: `${Contract.DeepLayer}::${Eth_Coin.module}::${Eth_Coin.coinType}`,
    owner: signer.getPublicKey().toSuiAddress(),
  });

  await depositCoins(
    eth_coin_deposited.data[0].coinObjectId,
    Eth_Coin.module,
    Eth_Coin.coinType
  );

  // Deposit LBTC
  const lbtc_amount = 10_000 * 10 ** 9;
  await mintCoins(
    lbtc_amount,
    Coins[5].faucet,
    Coins[5].module,
    Coins[5].coinType
  );
  const lbtc_coin_deposited = await client.getCoins({
    coinType: `${Contract.DeepLayer}::${Coins[5].module}::${Coins[5].coinType}`,
    owner: signer.getPublicKey().toSuiAddress(),
  });
  await depositCoins(
    lbtc_coin_deposited.data[0].coinObjectId,
    Coins[5].module,
    Coins[5].coinType
  );
}

main();
