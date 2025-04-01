import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";

const Clients = {
  suiClient: new SuiClient({ url: getFullnodeUrl("testnet") }),
};

export { Clients };
