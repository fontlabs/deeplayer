import { zeroAddress } from "viem";
import type { Token } from "./types";

export const tokens: Token[] = [
  {
    name: "Ethereum",
    symbol: "ETH",
    decimals: 18,
    price: 3_424.23,
    address: zeroAddress,
    image: "/images/eth.png",
    faucet: 0,
  },
  {
    name: "Liquid Bitcoin",
    symbol: "LBTC",
    decimals: 8,
    price: 94_329.42,
    address: "0x9DeB5E5E901F84fda356869A58DcB4885FDB7080",
    image: "/images/lbtc.png",
    faucet: 0.5,
  },
  {
    name: "Ethereum SUI",
    symbol: "SUI",
    decimals: 9,
    price: 3.42,
    address: "0xa0b1D1D7f115859c359666d978Edd57698CF8841",
    image: "/images/sui.png",
    faucet: 0.1,
  },
];
