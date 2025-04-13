// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const TokenModule = buildModule("TokenModule", (m) => {
  const sui = m.contract("Token");
  const lbtc = m.contract("Token");

  m.call(sui, "mint", [parseEther("1")], { id: "SUI" });
  m.call(lbtc, "mint", [parseEther("0.5")], { id: "LBTC" });

  return { sui, lbtc };
});

export default TokenModule;
