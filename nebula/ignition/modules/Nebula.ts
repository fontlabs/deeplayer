// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { zeroAddress } from "viem";
import TokenModule from "./Token";

const DeepLayer = "";

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

  return { nebula };
});

export default NebulaModule;
