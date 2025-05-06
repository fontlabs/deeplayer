import { NightlyConnectSuiAdapter } from "@nightlylabs/wallet-selector-sui";
import { ref } from "vue";

const appMetadata = {
  name: "DeepLayr.",
  description: "App | DeepLayr.",
  icon: "https://avatars.githubusercontent.com/u/37784886",
  additionalInfo: "DeepLayr",
};

const adapter = ref<NightlyConnectSuiAdapter | null>(null);

export const useAdapter = () => {
  console.log("test");
  const initAdapter = async () => {
    adapter.value = await NightlyConnectSuiAdapter.build({
      appMetadata,
    });
    console.log(adapter.value);
  };

  return { adapter, initAdapter };
};
