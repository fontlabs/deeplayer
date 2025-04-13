// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseUnits } from "viem";

const TokenModule = buildModule("TokenModule", (m) => {
  const sui = m.contract("Token", ["SUI", "SUI", 9], { id: "Token_SUI" });
  const lbtc = m.contract("Token", ["Liquid Bitcoin", "LBTC", 8], {
    id: "Token_LBTC",
  });

  m.call(sui, "mint", [parseUnits("1", 9)], { id: "SUI" });
  m.call(lbtc, "mint", [parseUnits("0.5", 8)], { id: "LBTC" });

  return { sui, lbtc };
});

export default TokenModule;
