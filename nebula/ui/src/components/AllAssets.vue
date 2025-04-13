<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import { Converter } from '@/scripts/converter';
import CloseIcon from './icons/CloseIcon.vue';

const emit = defineEmits(['close', 'change']);

const props = defineProps({
    balances: { type: Object, required: true },
    tokens: { type: Object, required: true },
});

onMounted(() => {
    document.body.style.overflowY = 'hidden';
});

onUnmounted(() => {
    document.body.style.overflowY = 'auto';
});
</script>

<template>
    <div class="overlay">
        <div class="form">
            <div class="title">
                <p>All Assets</p>

                <div class="close" @click="emit('close')">
                    <CloseIcon />
                </div>
            </div>

            <div class="subtitle">
                <p>Type</p>
                <p>Value</p>
            </div>

            <div class="scroll">
                <div class="assets">
                    <div class="asset" v-for="token in props.tokens" @click="emit('change', token)"
                        :key="token.address">
                        <div class=" info">
                            <img :src="token.image" alt="">
                            <div class="name">
                                <p>{{ token.name }}</p>
                                <p>{{ token.symbol }}</p>
                            </div>
                        </div>

                        <div class="amount">
                            <p>{{ Converter.toMoney(props.balances[token.address]) }}</p>
                            <p>≈ ${{ Converter.toMoney(token.price * props.balances[token.address]) }}</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
.overlay {
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    position: fixed;
    background: rgba(51, 51, 51, 0.35);
    backdrop-filter: blur(5px);
    z-index: 100;
    display: flex;
    align-items: center;
    justify-content: center;
    padding-right: 20px;
}

.form {
    height: fit-content;
    width: 400px;
    border-radius: 8px;
    background: var(--bg);
    overflow: hidden;
}

.title {
    padding: 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.title p {
    font-size: 16px;
    color: var(--tx-normal);
}

.subtitle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 34px;
    background: var(--bg-lighter);
    padding: 0 16px;
}

.subtitle p {
    font-size: 14px;
    color: var(--tx-semi);
}

.close {
    width: 36px;
    height: 30px;
    border-radius: 6px;
    cursor: pointer;
    border: 1px solid var(--bg-lightest);
    display: flex;
    align-items: center;
    justify-content: center;
}

.scroll {
    overflow-y: auto;
    height: calc(100vh - 500px);
}

.asset {
    height: 80px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 16px;
    border-bottom: 1px solid var(--bg-lightest);
    cursor: pointer;
}

.asset:last-child {
    border-bottom: none
}

.asset:hover {
    background: var(--bg-light);
}

.info {
    display: flex;
    align-items: center;
    gap: 14px;
}

.asset img {
    width: 30px;
    width: 30px;
    border-radius: 16px;
}

.name p:first-child {
    color: var(--tx-normal);
    font-size: 14px;
}

.name p:last-child {
    margin-top: 2px;
    color: var(--tx-semi);
    font-size: 12px;
}

.amount {
    text-align: right;
}

.amount p:first-child {
    color: var(--tx-normal);
    font-size: 14px;
}

.amount p:last-child {
    margin-top: 4px;
    color: var(--tx-semi);
    font-size: 12px;
}
</style>
