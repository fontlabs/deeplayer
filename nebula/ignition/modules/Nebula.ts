// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { zeroAddress } from "viem";
import TokenModule from "./Token";

const DeepLayer =
  "0x7b941196e87bbf0f0ee85717c68f49ad88ef598b81943ff4bde11dfea5e1b9a4";

const NebulaModule = buildModule("NebulaModule", (m) => {
  const nebula = m.contract("Nebula");
  const { sui, lbtc } = m.useModule(TokenModule);

  m.call(nebula, "setCoinType", [zeroAddress, `${DeepLayer}::eth::ETH`], {
    id: "ETH",
  });
  m.call(nebula, "setCoinType", [sui, `${DeepLayer}::sui::SUI`], { id: "SUI" });
  m.call(nebula, "setCoinType", [lbtc, `${DeepLayer}::lbtc::LBTC`], {
    id: "LBTC",
  });

  m.call(nebula, "setCoinType", [zeroAddress, `${DeepLayer}::eth::ETH`], {
    id: "ETH2",
  });
  m.call(nebula, "setCoinType", [sui, `${DeepLayer}::sui::SUI`], {
    id: "SUI2",
  });
  m.call(nebula, "setCoinType", [lbtc, `${DeepLayer}::lbtc::LBTC`], {
    id: "LBTC2",
  });

  return { nebula };
});

export default NebulaModule;
