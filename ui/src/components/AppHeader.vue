<script setup lang="ts">
import { ConnectButton } from 'sui-dapp-kit-vue';
import { useRoute } from 'vue-router';

const route = useRoute();
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
                    <button class="ai">Ask AI</button>
                    <ConnectButton />
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
</style>