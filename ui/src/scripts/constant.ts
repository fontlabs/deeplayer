import { SUI_TYPE_ARG } from "@mysten/sui/utils";
import { Contract } from "./contract";
import type { Coin, AVS, Operator } from "./types";

const findStrategy = (coinType: string): Coin | undefined => {
  return strategies.find((strategy) => strategy.type == coinType);
};

const strategies: Coin[] = [
  {
    name: "Native SUI",
    symbol: "SUI",
    decimals: 9,
    image: "/images/sui.png",
    type: SUI_TYPE_ARG,
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
    type: `${Contract.DeepLayer}::stsui::STSUI`,
    about:
      "AlphaFi Staked SUI (stSUI) is the first liquid staked token (LST) built on the innovative AlphaFi stSUI LST Standard. It offers instant unstaking, enhancing safety by mitigating the risk of depegging. Users can stake their SUI while maintaining full liquidity, allowing them to freely transfer, trade, or use stSUI in DeFi protocols without sacrificing staking rewards. The platform also enables other teams to deploy their own LSTs using the AlphaFi stSUI LST Standard—completely permissionless and at no cost.",
    link: "https://stsui.com",
    isLst: true,
    faucet: {
      amount: 5,
      module: "stsui",
      object:
        "0x6cf2273d40d8573afa3885372edcda3777b9449ebfc018e9a3e333b922a69718",
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
        "0x804d1d25a0f91868b6547d0e12631a6aa41732fbc46719aed6993f21bb591218",
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
        "0x3dc7716af9ad73f88bd8a760fc990e33d62d235dfcfe06fd20258cbd704e750d",
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
        "0x8ef3c576afce65777825052e5ca2ff1e0502bc46b2195c0e3333e8549785411d",
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
        "0xc16ed3db2bf10942e068f6c080ba4934e4ec17f3063dc10c8af05c847c4c41f6",
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
        "0x15925860e11a78dfe4eb76a4545006ef88c521fbfd41fe3ef315ddf97998f1df",
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
      "0x9e1b49043efc0bead9d0381713fa0c4348b05f59450cbb90961b6b98a67adb23",
    link: "https://mystenlabs.com",
  },
  {
    name: "Pyth (Unofficial)",
    image: "/images/pyth.png",
    about:
      "Pyth is a protocol that allows market participants to publish pricing information on-chain for others to use.",
    active: true,
    address:
      "0x43988c5c280487483d05c4d5e1aba8d206f82c4c5d8493e85205f9ac393bcc61",
    link: "https://pyth.network",
  },
  {
    name: "Google (Unofficial)",
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
      "0x0000000000000000000000000000000000000000000000000000000000000002",
    description:
      "Nebula is a decentralized bridge that allows users to transfer assets between different blockchains using zero-knowledge proofs.",
    link: "https://nebula.deeplayr.xyz",
    image: "/images/colors.png",
    reward_coin: findStrategy(SUI_TYPE_ARG)!,
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
  strategies,
  findStrategy,
  operators,
  findOperator,
  services,
  findService,
};
