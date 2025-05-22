import { Contract } from "./contract";
import type { Coin, AVS, Operator } from "./types";

export const SUI_COIN =
  "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI";

const findStrategy = (coinType: string): Coin | undefined => {
  return strategies.find((strategy) => strategy.type == coinType);
};

const strategies: Coin[] = [
  {
    name: "AlphaFi Staked SUI",
    symbol: "stSUI",
    decimals: 9,
    image: "/images/alpha_stsui.png",
    type: `${Contract.DeepLayer}::stsui::STSUI`,
    about:
      "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
    link: "https://stsui.com",
    isLst: true,
    faucet: {
      amount: 5,
      module: "stsui",
      object:
        "0x25a29d43d7ae60c18fda39359692788345aa5c077affab6b200c3a3afa6f793e",
    },
  },
  {
    name: "Liquid Bitcoin",
    symbol: "LBTC",
    decimals: 9,
    image: "/images/lbtc.png",
    type: `${Contract.DeepLayer}::lbtc::LBTC`,
    about:
      "Lombard is on a mission to expand the digital economy by transforming Bitcoin’s utility from a store of value into a productive financial tool with LBTC.",
    link: "https://lombard.finance",
    isBtc: true,
    faucet: {
      amount: 0.5,
      module: "lbtc",
      object:
        "0xb27375b69641ee6536da89d401800cc60d676428d4a4b8b84aaf2f317ac2416c",
    },
  },
  {
    name: "Haedal Staked SUI",
    symbol: "haSUI",
    decimals: 9,
    image: "/images/ha_sui.png",
    type: `${Contract.DeepLayer}::hasui::HASUI`,
    about:
      "haSUI stands for Haedal staked SUI, it is minted when you stake SUI via Haedal.This is a yield bearing token which represents your ownership of the SUI staked via Haedal.As the staking pool earns validator rewards for securing the Sui network, the value of haSUI will appreciate vs SUI. haSUI will have all primary utilities of SUI, and is usable across the Sui ecosystem.",
    link: "https://www.haedal.xyz",
    isLst: true,
    faucet: {
      amount: 5,
      module: "hasui",
      object:
        "0xbbcdc923ff540b739d0e976f54c37403e36e90d8bffe28abcb25d882ae2a467c",
    },
  },
  {
    name: "Aftermath SUI",
    symbol: "afSUI",
    decimals: 9,
    image: "/images/af_sui.png",
    type: `${Contract.DeepLayer}::afsui::AFSUI`,
    about:
      "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
    link: "https://aftermath.finance",
    isLst: true,
    faucet: {
      amount: 5,
      module: "afsui",
      object:
        "0x4e0e3cae00f77614ad73a508f27316b7bc81c95fc47a6700c1769031824d8d2d",
    },
  },
  {
    name: "Volo SUI",
    symbol: "vSUI",
    decimals: 9,
    image: "/images/v_sui.png",
    type: `${Contract.DeepLayer}::cert::CERT`,
    about:
      "Volo is a liquid staking solution that helps you maximize utility and liquidity for SUI by offering voloSUI.",
    link: "https://www.volosui.com",
    isLst: true,
    faucet: {
      amount: 5,
      module: "cert",
      object:
        "0x112cad2de14d528d2c9dc383b4972aa43ce8d19b3b9be86ce3514397617862f1",
    },
  },
  {
    name: "Pyth Network",
    symbol: "PYTH",
    decimals: 9,
    image: "/images/pyth.png",
    type: `${Contract.DeepLayer}::pyth::PYTH`,
    about:
      "Volo is a liquid staking solution that helps you maximize utility and liquidity for SUI by offering voloSUI.",
    link: "https://pyth.network",
    faucet: {
      amount: 20,
      module: "pyth",
      object:
        "0xd381851cf0dee6bb81af3fd0b1a8b84c35569a00df437d3c3e0ef5aa80c1d076",
    },
  },
];

const operators: Operator[] = [
  {
    name: "Font Labs",
    image: "/images/mysten.png",
    about:
      "At Mysten, we are building a company that aims to address these problems (and many others) by laying the foundations for a decentralized web stack suitable for mass adoption. The drive to unlock everything that web3 enables is our north star.",
    active: true,
    address:
      "0x9e1b49043efc0bead9d0381713fa0c4348b05f59450cbb90961b6b98a67adb23",
    link: "https://mystenlabs.com",
  },
  {
    name: "ShunLexxi",
    image: "/images/pyth.png",
    about:
      "Pyth is a protocol that allows market participants to publish pricing information on-chain for others to use.",
    active: true,
    address:
      "0x43988c5c280487483d05c4d5e1aba8d206f82c4c5d8493e85205f9ac393bcc61",
    link: "https://pyth.network",
  },
  {
    name: "Krypt0ne",
    image: "/images/google.png",
    about:
      "Our Web3 team at Google Cloud is dedicated to empowering the next generation of decentralized applications and services by providing developers and businesses with the essential tools, infrastructure, and knowledge to build and scale in the Web3 space.",
    active: true,
    address:
      "0x237fab2f9f5afc3eacec176fe1721534032cf85590f0e5a36dc6d7c668dbf897",
    link: "https://google.com",
  },
];

const services: AVS[] = [
  {
    name: "Nebula",
    address:
      "0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c",
    description:
      "Nebula is a decentralized bridge that allows users to transfer assets between different blockchains using zero-knowledge proofs.",
    link: "https://nebula.deeplayr.xyz",
    image: "/images/colors.png",
    reward_coin: {
      name: "SUI",
      symbol: "SUI",
      decimals: 9,
      image: "/images/sui.png",
      type: SUI_COIN,
      about: "SUI Coin.",
      link: "https://sui.io",
    },
    weekly_rewards: 16402000,
  },
];

const findOperator = (address: string): Operator | undefined => {
  return operators.find((operator) => operator.address == address);
};

const findService = (address: string): AVS | undefined => {
  return services.find((service) => service.address == address);
};

export {
  strategies,
  findStrategy,
  operators,
  findOperator,
  services,
  findService,
};
