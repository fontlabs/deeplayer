import type { Strategy, AVS, Operator } from "./types";

const strategies: Strategy[] = [
  {
    address: "0x2",
    coin: {
      address:
        "0x0000000000000000000000000000000000000000000000000000000000000002",
      name: "Native SUI",
      symbol: "SUI",
      decimals: 9,
      image: "/images/sui.png",
      type: "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
      about:
        "Lorem ipsum dolor sit, amet consectetur adipisicing elit. Pariatur veniam itaque a tempora dicta ipsa perferendis corrupti nobis. Est amet ad omnis ex. Voluptas, similique. Aperiam nihil cupiditate molestiae labore?",
      link: "https://sui.io",
      isNative: true,
    },
  },
  {
    address: "0x6",
    coin: {
      address:
        "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55",
      name: "AlphaFi Staked SUI",
      symbol: "stSUI",
      decimals: 9,
      image: "/images/alpha_stsui.png",
      type: "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI",
      about:
        "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
      link: "https://stsui.com",
      isLst: true,
    },
  },
  {
    address: "0x4",
    coin: {
      address:
        "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d",
      name: "Haedal Staked SUI",
      symbol: "haSUI",
      decimals: 9,
      image: "/images/ha_sui.png",
      type: "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI",
      about:
        "haSUI stands for Haedal staked SUI, it is minted when you stake SUI via Haedal.This is a yield bearing token which represents your ownership of the SUI staked via Haedal.As the staking pool earns validator rewards for securing the Sui network, the value of haSUI will appreciate vs SUI. haSUI will have all primary utilities of SUI, and is usable across the Sui ecosystem.",
      link: "https://www.haedal.xyz",
      isLst: true,
    },
  },
  {
    address: "0x10",
    coin: {
      address:
        "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc",
      name: "Aftermath SUI",
      symbol: "afSUI",
      decimals: 9,
      image: "/images/af_sui.png",
      type: "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI",
      about:
        "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
      link: "https://aftermath.finance",
      isLst: true,
    },
  },
  {
    address: "0x5",
    coin: {
      address:
        "0x027792d9fed7f9844eb4839566001bb6f6cb4804f66aa2da6fe1ee242d896881",
      name: "Wrapped BTC",
      symbol: "WBTC",
      decimals: 9,
      image: "/images/wbtc.png",
      type: "0x027792d9fed7f9844eb4839566001bb6f6cb4804f66aa2da6fe1ee242d896881::coin::COIN",
      about:
        "Wrapped Bitcoin is a coin on the SUI blockchain that represents Bitcoin. Each WBTC is backed 1:1 with Bitcoin. Wrapped Bitcoin allows for Bitcoin transfers to be conducted quicker on the SUI blockchain and opens up the possibility for BTC to be used in the SUI ecosystem. Bitcoin is held in custody by the centralized custodian, BitGo. Bitcoin can be converted to Wrapped Bitcoin and vice versa easily.",
      link: "https://wbtc.network",
    },
  },
  {
    address: "0x11",
    coin: {
      address:
        "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55",
      name: "Volo SUI",
      symbol: "vSUI",
      decimals: 9,
      image: "/images/v_sui.png",
      type: "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
      about:
        "Volo is a liquid staking solution that helps you maximize utility and liquidity for SUI by offering voloSUI.",
      link: "https://www.volosui.com",
      isLst: true,
    },
  },
  {
    address: "0x12",
    coin: {
      address:
        "0x9c6d76eb273e6b5ba2ec8d708b7fa336a5531f6be59f326b5be8d4d8b12348a4",
      name: "Pyth Network",
      symbol: "PYTH",
      decimals: 9,
      image: "/images/pyth.png",
      type: "0x9c6d76eb273e6b5ba2ec8d708b7fa336a5531f6be59f326b5be8d4d8b12348a4::coin::COIN",
      about:
        "Volo is a liquid staking solution that helps you maximize utility and liquidity for SUI by offering voloSUI.",
      link: "https://pyth.network",
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
    reward_coin: {
      address:
        "0x0000000000000000000000000000000000000000000000000000000000000002",
      name: "Native SUI",
      symbol: "SUI",
      decimals: 9,
      image: "/images/sui.png",
      type: "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
      about:
        "Lorem ipsum dolor sit, amet consectetur adipisicing elit. Pariatur veniam itaque a tempora dicta ipsa perferendis corrupti nobis. Est amet ad omnis ex. Voluptas, similique. Aperiam nihil cupiditate molestiae labore?",
      link: "https://sui.io",
      isNative: true,
    },
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
    reward_coin: {
      address:
        "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55",
      name: "AlphaFi Staked SUI",
      symbol: "stSUI",
      decimals: 9,
      image: "/images/alpha_stsui.png",
      type: "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI",
      about:
        "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
      link: "https://stsui.com",
      isLst: true,
    },
    weekly_rewards: 12291230,
  },
];

const findStrategy = (address: string): Strategy | undefined => {
  return strategies.find((strategy) => strategy.address == address);
};

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
