import type { Hex } from "viem";

export type Token = {
  name: string;
  symbol: string;
  decimals: number;
  address: Hex;
  image: string;
};
