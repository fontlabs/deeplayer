<script setup lang="ts">
import AppHeader from './components/AppHeader.vue';
import NotifyPop from '@/components/NotifyPop.vue';
import AIButton from '@/components/AIButton.vue';
import { useCurrentAccount } from 'sui-dapp-kit-vue';
import { useBalanceStore } from '@/stores/balance';
import { watch } from 'vue';

const balanceStore = useBalanceStore();
const { currentAccount } = useCurrentAccount();

watch(currentAccount, () => {
  if (!currentAccount.value) return;
  balanceStore.getBalances(currentAccount.value.address);
});
</script>

<template>
  <main>
    <AppHeader />
    <RouterView />
    <NotifyPop />
    <AIButton />
  </main>
</template>