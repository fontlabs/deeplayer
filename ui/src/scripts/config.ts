import { NightlyConnectSuiAdapter } from "@nightlylabs/wallet-selector-sui";
import { ref } from "vue";

const adapter = ref<NightlyConnectSuiAdapter | null>(null);

export const useAdapter = () => {
  const initAdapter = async () => {
    adapter.value = await NightlyConnectSuiAdapter.build({
      appMetadata: {
        name: "DeepLayr.",
        description: "App | DeepLayr.",
        icon: "https://avatars.githubusercontent.com/u/37784886",
        additionalInfo: "DeepLayr",
      },
    });
  };

  return { adapter, initAdapter };
};
