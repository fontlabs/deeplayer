import {
  getFullnodeUrl,
  SuiClient,
  type PaginatedCoins,
} from "@mysten/sui/client";
import { Clients } from "./sui";

const CoinAPI = {
  async getCoinsBalance(
    owner: string,
    coinTypes: string[]
  ): Promise<{ [key: string]: bigint }> {
    const coins = await Clients.suiClient.getAllCoins({ owner });
    const balances: { [key: string]: bigint } = {};

    for (let index = 0; index < coinTypes.length; index++) {
      let coinType = coinTypes[index];

      const innerCoins = coins.data.filter((coin) => coin.coinType == coinType);

      balances[coinType] = innerCoins.reduce(
        (a, b) => a + BigInt(b.balance),
        BigInt(0)
      );
    }

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
