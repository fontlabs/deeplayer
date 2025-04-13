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
    address: "0xF3F9b7d82650F38795200326B6DE933f4E78965f",
    image: "/images/lbtc.png",
    faucet: 0.5,
  },
  {
    name: "Ethereum SUI",
    symbol: "ethSUI",
    decimals: 9,
    price: 3.42,
    address: "0x93cdD8AD086B719C7F56D540B38b373010481471",
    image: "/images/sui.png",
    faucet: 0.1,
  },
];
