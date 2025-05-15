<script setup lang="ts">
import AppHeader from './components/AppHeader.vue';
import NotifyPop from '@/components/NotifyPop.vue';
import { useBalanceStore } from '@/stores/balance';
import { onMounted, watch } from 'vue';
import { initializeApp } from "firebase/app";
import { useWalletStore } from './stores/wallet';

initializeApp({
  apiKey: import.meta.env.VITE_FS_API_KEY,
  authDomain: import.meta.env.VITE_FS_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FS_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FS_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FS_MSG_SENDER_ID,
  appId: import.meta.env.VITE_FS_APP_ID,
  measurementId: import.meta.env.VITE_FS_MEASUREMENT_ID,
});

const walletStore = useWalletStore();
const balanceStore = useBalanceStore();

onMounted(() => {
  balanceStore.getOperatorBalances();
});

watch(walletStore, () => {
  balanceStore.getBalances(walletStore.address);
});
</script>

<template>
  <main>
    <AppHeader />
    <RouterView />
    <NotifyPop />
  </main>
</template>