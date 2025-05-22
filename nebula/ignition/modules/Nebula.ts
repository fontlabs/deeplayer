// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { zeroAddress } from "viem";
import TokenModule from "./Token";

const DeepLayer =
  "0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c";

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
