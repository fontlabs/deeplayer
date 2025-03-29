import {
  getFullnodeUrl,
  SuiClient,
  type PaginatedCoins,
} from "@mysten/sui/client";

const CoinAPI = {
  getCoins(owner: string, coinType: string): Promise<PaginatedCoins> {
    const client = new SuiClient({
      url: getFullnodeUrl("testnet"),
    });

    return client.getCoins({ owner, coinType });
  },
};

export { CoinAPI };
