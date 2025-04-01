import { Contract } from "./contract";
import type { Coin, AVS, Operator } from "./types";

const findStrategy = (coinType: string): Coin | undefined => {
  return strategy_ids.find((strategy) => strategy.type == coinType);
};

const strategy_ids: Coin[] = [
  {
    name: "Native SUI",
    symbol: "SUI",
    decimals: 9,
    image: "/images/sui.png",
    type: "0x2::sui::SUI",
    about:
      "Lorem ipsum dolor sit, amet consectetur adipisicing elit. Pariatur veniam itaque a tempora dicta ipsa perferendis corrupti nobis. Est amet ad omnis ex. Voluptas, similique. Aperiam nihil cupiditate molestiae labore?",
    link: "https://sui.io",
    isNative: true,
  },
  {
    name: "AlphaFi Staked SUI",
    symbol: "stSUI",
    decimals: 9,
    image: "/images/alpha_stsui.png",
    type: "${Contract.deeplayer}::stsui::STSUI",
    about:
      "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
    link: "https://stsui.com",
    isLst: true,
    faucet: {
      amount: 5,
      module: "stsui",
      object:
        "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55",
    },
  },
  {
    name: "Haedal Staked SUI",
    symbol: "haSUI",
    decimals: 9,
    image: "/images/ha_sui.png",
    type: `${Contract.deeplayer}::hasui::HASUI`,
    about:
      "haSUI stands for Haedal staked SUI, it is minted when you stake SUI via Haedal.This is a yield bearing token which represents your ownership of the SUI staked via Haedal.As the staking pool earns validator rewards for securing the Sui network, the value of haSUI will appreciate vs SUI. haSUI will have all primary utilities of SUI, and is usable across the Sui ecosystem.",
    link: "https://www.haedal.xyz",
    isLst: true,
    faucet: {
      amount: 5,
      module: "hasui",
      object:
        "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55",
    },
  },
  {
    name: "Aftermath SUI",
    symbol: "afSUI",
    decimals: 9,
    image: "/images/af_sui.png",
    type: `${Contract.deeplayer}::afsui::AFSUI`,
    about:
      "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
    link: "https://aftermath.finance",
    isLst: true,
    faucet: {
      amount: 5,
      module: "afsui",
      object:
        "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55",
    },
  },
  {
    name: "Wrapped BTC",
    symbol: "WBTC",
    decimals: 9,
    image: "/images/wbtc.png",
    type: `${Contract.deeplayer}::wbtc::WBTC`,
    about:
      "Wrapped Bitcoin is a coin on the SUI blockchain that represents Bitcoin. Each WBTC is backed 1:1 with Bitcoin. Wrapped Bitcoin allows for Bitcoin transfers to be conducted quicker on the SUI blockchain and opens up the possibility for BTC to be used in the SUI ecosystem. Bitcoin is held in custody by the centralized custodian, BitGo. Bitcoin can be converted to Wrapped Bitcoin and vice versa easily.",
    link: "https://wbtc.network",
    faucet: {
      amount: 0.5,
      module: "wbtc",
      object:
        "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55",
    },
  },
  {
    name: "Volo SUI",
    symbol: "vSUI",
    decimals: 9,
    image: "/images/v_sui.png",
    type: `${Contract.deeplayer}::cert::CERT`,
    about:
      "Volo is a liquid staking solution that helps you maximize utility and liquidity for SUI by offering voloSUI.",
    link: "https://www.volosui.com",
    isLst: true,
    faucet: {
      amount: 5,
      module: "vsui",
      object:
        "0x50b16a00498bf70a1334d539896b95d1f7295558afa06c1cc50cb5eafb4786ac",
    },
  },
  {
    name: "Pyth Network",
    symbol: "PYTH",
    decimals: 9,
    image: "/images/pyth.png",
    type: `${Contract.deeplayer}::pyth::PYTH`,
    about:
      "Volo is a liquid staking solution that helps you maximize utility and liquidity for SUI by offering voloSUI.",
    link: "https://pyth.network",
    faucet: {
      amount: 20,
      module: "pyth",
      object:
        "0x15a5f028b561300bb724876856801354426b58445d7476b970288845172fbcb1",
    },
  },
];

const operators: Operator[] = [
  {
    name: "Mysten Labs (Unofficial)",
    image: "/images/mysten.png",
    about:
      "At Mysten, we are building a company that aims to address these problems (and many others) by laying the foundations for a decentralized web stack suitable for mass adoption. The drive to unlock everything that web3 enables is our north star.",
    active: true,
    address:
      "0x0000000000000000000000000000000000000000000000000000000000000001",
    link: "https://mystenlabs.com",
  },
  {
    name: "Pyth (Unofficial)",
    image: "/images/pyth.png",
    about:
      "Pyth is a protocol that allows market participants to publish pricing information on-chain for others to use.",
    active: true,
    address:
      "0x0000000000000000000000000000000000000000000000000000000000000002",
    link: "https://pyth.network",
  },
  {
    name: "Google (Unofficial)",
    image: "/images/google.png",
    about:
      "Our Web3 team at Google Cloud is dedicated to empowering the next generation of decentralized applications and services by providing developers and businesses with the essential tools, infrastructure, and knowledge to build and scale in the Web3 space.",
    active: true,
    address:
      "0x0000000000000000000000000000000000000000000000000000000000000003",
    link: "https://google.com",
  },
];

const services: AVS[] = [
  {
    name: "Randomizer",
    address:
      "0x0000000000000000000000000000000000000000000000000000000000000001",
    description:
      "Lorem ipsum dolor sit amet consectetur adipisicing elit. Enim placeat harum ex rem minima error illo magni repellat excepturi rerum, voluptatibus, possimus maiores accusamus, atque totam voluptatem vitae qui sint!",
    link: "https://sui-randomizer.netlify.app",
    image: "/images/colors.png",
    reward_coin: findStrategy("0x2::sui::SUI")!,
    weekly_rewards: 9432930,
  },
  {
    name: "SUI zkBridge",
    address:
      "0x0000000000000000000000000000000000000000000000000000000000000002",
    description:
      "Lorem ipsum dolor sit amet consectetur adipisicing elit. Enim placeat harum ex rem minima error illo magni repellat excepturi rerum, voluptatibus, possimus maiores accusamus, atque totam voluptatem vitae qui sint!",
    link: "https://sui-zkbridge.netlify.app",
    image: "/images/colors.png",
    reward_coin: findStrategy("0x2::sui::SUI")!,
    weekly_rewards: 12291230,
  },
];

const findOperator = (address: string): Operator | undefined => {
  return operators.find((operator) => operator.address == address);
};

const findService = (address: string): AVS | undefined => {
  return services.find((service) => service.address == address);
};

export {
  strategy_ids,
  findStrategy,
  operators,
  findOperator,
  services,
  findService,
};
