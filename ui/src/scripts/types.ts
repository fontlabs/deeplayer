export type CoinType = `${string}:${string}:${string}`;

export type AVS = {
  name: string;
  address: string;
  description: string;
  image: string;
  link?: string;
  reward_coin: Coin;
  weekly_rewards: number;
};

export type Operator = {
  name: string;
  address: string;
  about: string;
  image: string;
  link?: string;
  active: boolean;
};

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
  isNative?: boolean;
  isLst?: boolean;
};

export type Notification = {
  title: string;
  description: string;
  category: string;
  linkTitle?: string;
  linkUrl?: string;
};
