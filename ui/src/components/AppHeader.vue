<script setup lang="ts">
import { useAdapter } from '@/scripts/config';
import { Converter } from '@/scripts/converter';
import { useWalletStore } from '@/stores/wallet';
import { onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const walletStore = useWalletStore();
const { adapter, initAdapter } = useAdapter();

watch(adapter, (newAdapter) => {
    newAdapter?.on('connect', (accounts) => {
        if (accounts.length > 0) {
            walletStore.setAddress(accounts[0].address);
        }
    });

    newAdapter?.on('change', (adapter) => {
        if (adapter.accounts?.length) {
            walletStore.setAddress(adapter.accounts?.[0].address);
        }
    });

    newAdapter?.on('disconnect', () => {
        walletStore.setAddress(null);
    });
});

onMounted(() => {
    initAdapter();
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
                    <RouterLink to="/">
                        <button :class="route.name?.toString().startsWith('restake') ? 'tab tab_active' : 'tab'">Restake
                        </button>
                    </RouterLink>

                    <RouterLink to="/operator">
                        <button
                            :class="route.name?.toString().startsWith('operator') ? 'tab tab_active' : 'tab'">Operator
                        </button>
                    </RouterLink>

                    <RouterLink to="/avs">
                        <button :class="route.name?.toString().startsWith('avs') ? 'tab tab_active' : 'tab'">AVS
                        </button>
                    </RouterLink>

                    <a href="https://x.com/deep_layr" target="_blank" rel="noopener noreferrer">
                        <button class="tab">
                            <img src="/images/x.png" alt="X">
                        </button>
                    </a>
                </div>

                <div class="actions">
                    <RouterLink to="/ai"><button class="ai">Ask AI</button></RouterLink>
                    <button class="connect" @click="adapter?.connect()">
                        {{
                            walletStore.address ? Converter.trimAddress(walletStore.address, 5) : 'Connect Wallet'
                        }}
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
    align-items: center;
    justify-content: flex-end;
    gap: 20px;
}

.ai {
    color: var(--tx-normal);
    padding: 14px 20px;
    border-radius: 14px;
    font-size: 16px;
    border: 0;
    user-select: none;
    -webkit-user-select: none;
    touch-action: manipulation;
    cursor: pointer;
    box-shadow: rgba(255, 255, 255, 0.1) -3px -3px 9px inset, rgba(255, 255, 255, 0.15) 0 3px 9px inset, rgba(255, 255, 255, 0.6) 0 1px 1px inset, rgba(0, 0, 0, 0.3) 0 -8px 36px inset, rgba(255, 255, 255, 0.6) 0 1px 5px inset, rgba(0, 0, 0, 0.2) 2px 19px 31px;
    background-color: var(--accent-green);
    background-image: radial-gradient(93% 87% at 87% 89%, rgba(0, 0, 0, .23) 0, transparent 86.18%), radial-gradient(66% 66% at 26% 20%, rgba(255, 255, 255, .55) 0, rgba(255, 255, 255, 0) 69.79%, rgba(255, 255, 255, 0) 100%);
    transition: all 150ms ease-in-out;
}

.ai:hover {
    filter: brightness(1.05);
}

.ai:active {
    transform: scale(.95);
}

.connect {
    cursor: pointer;
    background: var(--primary);
    border: none;
    color: var(--tx-normal);
    border-radius: 8px;
    font-size: 16px;
    height: 40px;
    padding: 0 20px;
}
</style>