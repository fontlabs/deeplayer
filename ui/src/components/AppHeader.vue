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
                </div>

                <div class="actions">
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
    gap: 20px;
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
}

.tab_active {
    color: var(--tx-normal);
    background: var(--bg-lighter);
    border: 1px solid var(--bg-lightest);
}

.actions {
    display: flex;
    justify-content: flex-end;
}
</style>