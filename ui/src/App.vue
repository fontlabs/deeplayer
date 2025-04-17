<script setup lang="ts">
import AppHeader from './components/AppHeader.vue';
import NotifyPop from '@/components/NotifyPop.vue';
import { useCurrentAccount } from 'sui-dapp-kit-vue';
import { useBalanceStore } from '@/stores/balance';
import { onMounted, watch } from 'vue';

const balanceStore = useBalanceStore();
const { currentAccount } = useCurrentAccount();

onMounted(() => {
  balanceStore.getOperatorBalances();
});

watch(currentAccount, () => {
  balanceStore.getBalances(currentAccount.value?.address);
});
</script>

<template>
  <main>
    <AppHeader />
    <RouterView />
    <NotifyPop />
  </main>
</template>