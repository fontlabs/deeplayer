import {
  getFullnodeUrl,
  SuiClient,
  type PaginatedCoins,
} from "@mysten/sui/client";

const CoinAPI = {
  async getCoinBalance(owner: string, coinType: string): Promise<bigint> {
    const coins = (await this.getCoins(owner, coinType)).data;
    return coins.reduce((a, b) => a + BigInt(b.balance), BigInt(0));
  },

  getCoins(owner: string, coinType: string): Promise<PaginatedCoins> {
    const client = new SuiClient({
      url: getFullnodeUrl("testnet"),
    });

    return client.getCoins({ owner, coinType });
  },
};

export { CoinAPI };
