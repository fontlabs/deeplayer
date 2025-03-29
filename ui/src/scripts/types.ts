export type CoinType = `${string}:${string}:${string}`;

export type Strategy = {
  address: string;
  coin: Coin;
};

export type Coin = {
  name: string;
  image: string;
  symbol: string;
  decimals: number;
  type: CoinType;
  about: string;
  link?: string;
  address: string;
};
