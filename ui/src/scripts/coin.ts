import { type PaginatedCoins } from "@mysten/sui/client";
import { Clients } from "./sui";

const CoinAPI = {
  async getCoinsBalance(
    owner: string,
    coinTypes: string[]
  ): Promise<{ [key: string]: bigint }> {
    let hasNextPage = false;
    let nextCursor = undefined;

    const balances: { [key: string]: bigint } = {};

    do {
      const coins = await Clients.suiClient.getAllCoins({
        owner,
        cursor: nextCursor,
      });

      for (let index = 0; index < coinTypes.length; index++) {
        let coinType = coinTypes[index];

        const filteredCoins = coins.data.filter(
          (coin) => coin.coinType == coinType
        );
        if (!balances[coinType]) balances[coinType] = BigInt(0);
        balances[coinType] += filteredCoins.reduce(
          (a, b) => a + BigInt(b.balance),
          BigInt(0)
        );
      }

      hasNextPage = coins.hasNextPage;
      nextCursor = coins.nextCursor;
    } while (hasNextPage);

    return balances;
  },

  async getCoinBalance(owner: string, coinType: string): Promise<bigint> {
    const coins = (await this.getCoins(owner, coinType)).data;
    return coins.reduce((a, b) => a + BigInt(b.balance), BigInt(0));
  },

  getCoins(owner: string, coinType: string): Promise<PaginatedCoins> {
    return Clients.suiClient.getCoins({ owner, coinType });
  },
};

export { CoinAPI };
