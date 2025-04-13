// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { zeroAddress } from "viem";

const NebulaModule = buildModule("NebulaModule", (m) => {
  const zKBridge = m.contract("Nebula");

  m.call(zKBridge, "setCoinType", [zeroAddress, ""], { id: "ETH" });
  m.call(zKBridge, "setCoinType", [zeroAddress, ""], { id: "SUI" });
  m.call(zKBridge, "setCoinType", [zeroAddress, ""], { id: "LBTC" });

  return { zKBridge };
});

export default NebulaModule;
