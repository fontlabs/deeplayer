<script setup lang="ts">
import { config, chains } from '@/scripts/config';
import { useWalletStore } from '@/stores/wallet';
import { createWeb3Modal } from '@web3modal/wagmi/vue';
import { useWeb3Modal } from '@web3modal/wagmi/vue';
import { watchAccount } from '@wagmi/core';
import { onMounted } from 'vue';
import { Converter } from '@/scripts/converter';

createWeb3Modal({
    wagmiConfig: config,
    projectId: import.meta.env.VITE_PROJECT_ID,
    // @ts-ignore
    chains: chains,
    enableAnalytics: true,
    themeMode: 'dark'
});

const modal = useWeb3Modal();
const walletStore = useWalletStore();

onMounted(() => {
    watchAccount(config, {
        onChange(account) {
            if (account.address) {
                walletStore.setAddress(account.address);
            }
        },
    });
});
</script>

<template>
    <section>
        <div class="app_width">
            <header>
                <div class="logo">
                    <RouterLink to="/">
                        <h3>Deep<span>Layr.</span></h3>
                    </RouterLink>
                </div>

                <div class="tabs">
                    <a href="https://x.com/deep_layr" target="_blank" rel="noopener noreferrer">
                        <button class="tab">
                            <img src="/images/x.png" alt="X">
                        </button>
                    </a>
                </div>

                <div class="actions">
                    <button @click="modal.open()">
                        {{ walletStore.address ? Converter.trimAddress(walletStore.address, 4) : 'Connect' }}
                    </button>
                </div>
            </header>
        </div>
    </section>
</template>

<style scoped>
section {
    position: sticky;
    top: 0;
    z-index: 99;
    background: var(--dark);
    border-bottom: 1px solid var(--bg-lightest);
}

header {
    height: 70px;
    display: grid;
    align-items: center;
    grid-template-columns: auto 1fr auto;
    gap: 40px;
}


.logo h3 {
    font-size: 24px;
    font-weight: 500;
    color: var(--tx-normal);
    font-style: italic;
}

.logo h3 span {
    color: var(--primary-light);
    font-style: normal;
}

.tabs {
    display: flex;
    align-items: center;
    gap: 16px;
}

.tab {
    padding: 0 20px;
    height: 40px;
    border-radius: 20px;
    color: var(--tx-semi);
    background: none;
    border: 1px solid transparent;
    cursor: pointer;
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
}

.tab img {
    width: 16px;
    height: 16px;
}

.tab_active {
    color: var(--tx-normal);
    background: var(--bg-lighter);
    border: 1px solid var(--bg-lightest);
}

.actions {
    display: flex;
    justify-content: flex-end;
    gap: 20px;
}

.actions button {
    padding: 0 20px;
    height: 40px;
    border-radius: 8px;
    color: var(--tx-normal);
    background: var(--primary);
    border: 1px solid transparent;
    cursor: pointer;
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
}
</style>