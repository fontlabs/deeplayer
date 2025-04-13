import type { Hex } from "viem";

export type Token = {
  name: string;
  symbol: string;
  decimals: number;
  price: number;
  address: Hex;
  image: string;
  faucet: number;
};

export type Notification = {
  title: string;
  description: string;
  category: string;
  linkTitle?: string;
  linkUrl?: string;
};
