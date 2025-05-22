<script setup lang="ts">
import { ref, watch } from 'vue';
import AppHeader from './components/AppHeader.vue';
import ChevronDownIcon from './components/icons/ChevronDownIcon.vue';
import { Converter } from './scripts/converter';
import { tokens } from './scripts/constants';
import { TokenContract } from './scripts/erc20';
import { useWalletStore } from './stores/wallet';
import { formatUnits, parseUnits, zeroAddress, type Hex } from 'viem';
import AllAssets from './components/AllAssets.vue';
import NotifyPop from './components/NotifyPop.vue';
import type { Token } from './scripts/types';
import { Contract } from './scripts/contract';
import { notify } from './reactives/notify';

const walletStore = useWalletStore();
const allAssets = ref<boolean>(false);
const minting = ref<boolean>(false);
const approving = ref<boolean>(false);
const bridging = ref<boolean>(false);

const form = ref({
  token: tokens[0],
  amount: undefined as number | undefined,
  receiver: undefined as Hex | undefined,
});

const onTokenChanged = (token: Token) => {
  form.value.token = token;
  allAssets.value = false;
};

const mint = async () => {
  if (minting.value) return;
  if (!walletStore.address) return;

  minting.value = true;

  const tx = await TokenContract.mint(
    form.value.token.address,
    parseUnits(form.value.token.faucet.toString(), form.value.token.decimals),
  );

  if (tx) {
    notify.push({
      title: 'Minted',
      description: `Minted ${form.value.token.symbol}`,
      category: 'success',
      linkTitle: 'View Trx',
      linkUrl: `${import.meta.env.VITE_EXPLORER_URL}/tx/${tx}`,
    });

    getBalances();
  } else {
    notify.push({
      title: 'Mint Failed',
      description: `Failed to mint ${form.value.token.symbol}`,
      category: 'error'
    });
  }

  minting.value = false;
};

const approve = async () => {
  if (approving.value) return;
  if (!walletStore.address) return;
  if (!form.value.amount) return;

  approving.value = true;

  const tx = await TokenContract.approve(
    form.value.token.address,
    Contract.address,
    parseUnits(form.value.amount.toString(), form.value.token.decimals),
  );

  if (tx) {
    notify.push({
      title: 'Approved',
      description: `Approved ${form.value.token.symbol}`,
      category: 'success',
      linkTitle: 'View Trx',
      linkUrl: `${import.meta.env.VITE_EXPLORER_URL}/tx/${tx}`,
    });

    getApprovals();
  } else {
    notify.push({
      title: 'Approval Failed',
      description: `Failed to approve ${form.value.token.symbol}`,
      category: 'error'
    });
  }

  approving.value = false;
};

const bridge = async () => {
  if (bridging.value) return;
  if (!walletStore.address) return;

  if (!form.value.amount) {
    notify.push({
      title: 'Amount Required',
      description: `Please enter an amount`,
      category: 'error'
    });
    return;
  }

  if (!form.value.receiver) {
    notify.push({
      title: 'Receiver Required',
      description: `Please enter a receiver address`,
      category: 'error'
    });
    return;
  }

  bridging.value = true;

  let tx: Hex | null = null;

  if (form.value.token.address == zeroAddress) {
    tx = await Contract.lockETH(
      parseUnits(form.value.amount.toString(), form.value.token.decimals),
      form.value.receiver,
    );
  } else {
    tx = await Contract.lock(
      form.value.token.address,
      parseUnits(form.value.amount.toString(), form.value.token.decimals),
      form.value.receiver,
    );
  }

  if (tx) {
    notify.push({
      title: 'Bridged',
      description: `Bridged ${form.value.token.symbol}`,
      category: 'success',
      linkTitle: 'View Trx',
      linkUrl: `${import.meta.env.VITE_EXPLORER_URL}/tx/${tx}`,
    });

    form.value.amount = undefined;
    form.value.receiver = undefined;

    getBalances();
    getApprovals();

  } else {
    notify.push({
      title: 'Bridge Failed',
      description: `Failed to bridge ${form.value.token.symbol}`,
      category: 'error'
    });
  }

  bridging.value = false;
};

const getBalances = async () => {
  if (!walletStore.address) return;

  for (let i = 0; i < tokens.length; i++) {
    const balance = await TokenContract.getTokenBalance(
      tokens[i].address,
      walletStore.address
    );

    walletStore.setBalance(
      tokens[i].address,
      Number(formatUnits(balance, tokens[i].decimals))
    );
  }
};

const getApprovals = async () => {
  if (!walletStore.address) return;

  for (let i = 0; i < tokens.length; i++) {
    const approval = await TokenContract.getAllowance(
      tokens[i].address,
      walletStore.address,
      Contract.address,
    );

    walletStore.setApproval(
      tokens[i].address,
      Number(formatUnits(approval, tokens[i].decimals))
    );
  }
};

watch(form, () => {
  getBalances();
  getApprovals();
});

watch(walletStore, () => {
  getBalances();
  getApprovals();
});
</script>

<template>
  <AppHeader />
  <section>
    <div class="app_width">
      <div class="app">
        <div class="form">
          <div class="scroll">
            <div class="container">
              <span>Bridge</span>

              <div class="input input_disabled">
                <label>From</label>
                <div class="chain">
                  <img src="/images/eth.png" alt="Ethereum">
                  <p>Holesky</p>
                  <ChevronDownIcon />
                </div>
              </div>

              <div class="input input_disabled">
                <label>To</label>
                <div class="chain">
                  <img src="/images/sui.png" alt="SUI">
                  <p>SUI</p>
                  <ChevronDownIcon />
                </div>
              </div>

              <div class="input">
                <label>Asset</label>
                <div class="chain" @click="allAssets = true">
                  <img :src="form.token.image" :alt="form.token.name">
                  <p>{{ form.token.symbol }}</p>
                  <ChevronDownIcon />
                </div>
              </div>

              <div class="input2">
                <div class="labels">
                  <label>Amount</label>
                  <div class="bal">
                    <p>Bal: {{ Converter.toMoney(walletStore.balances[form.token.address]) }} {{ form.token.symbol }}
                    </p>
                    <a href="https://cloud.google.com/application/web3/faucet/ethereum/holesky" target="_blank"
                      v-if="form.token.address == zeroAddress">
                      <button>Request ETH</button>
                    </a>
                    <button v-else @click="mint">{{ minting ? '•••' : 'Mint' }}</button>
                  </div>
                </div>
                <input type="number" placeholder="0.00" v-model="form.amount" />
              </div>

              <div class="input2">
                <label>Receiver (SUI address)</label>
                <input type="text" placeholder="0x264d28e6e657b8d099cefafc7d186f15f74b88bc76882feb31bcd81d7804ddd9"
                  v-model="form.receiver" />
              </div>
            </div>
          </div>

          <div class="actions" v-if="walletStore.balances[form.token.address] < (form.amount || 0)">
            <button disabled>Insufficient Bal</button>
          </div>

          <div class="actions" v-else>
            <button v-if="form.token.address != zeroAddress" @click="approve"
              :disabled="!form.amount || form.amount == 0 || walletStore.approvals[form.token.address] >= form.amount">{{
                approving ? '•••' : 'Approve' }}</button>
            <button v-if="form.token.address != zeroAddress" @click="bridge"
              :disabled="!form.amount || form.amount == 0 || walletStore.approvals[form.token.address] < form.amount">
              {{ bridging ? '•••' : 'Bridge' }}</button>
            <button v-else @click="bridge" :disabled="!form.amount || form.amount == 0">
              {{ bridging ? '•••' : 'Bridge' }}</button>
          </div>
        </div>
        <div class="about">
          <span>About</span>
          <h1>Nebula</h1>
          <p>
            Nebula is a decentralized bridge that allows users to transfer assets between different blockchains using
            zero-knowledge proofs.
          </p>
          <a href="https://beta.deeplayr.xyz/avs/0x8c4bcfe5cac89ea732d9f507f46d56a7e37e3d161007060a5686b9399a9ea03c"
            target="_blank">
            <button>View AVS on DeepLayr.</button>
          </a>
        </div>
      </div>
    </div>

    <AllAssets v-if="allAssets" @change="onTokenChanged" :balances="walletStore.balances" :tokens="tokens"
      @close="allAssets = false" />
    <NotifyPop />
  </section>
</template>

<style scoped>
.app {
  display: grid;
  grid-template-columns: 1fr 500px;
}

.app_width {
  max-width: 100%;
}

.about {
  border-left: 1px solid var(--bg-lightest);
  padding: 40px 30px;
  min-height: calc(100vh - 70px - 1px);
}

.about span {
  font-size: 16px;
  color: var(--tx-semi);
}

.about h1 {
  font-size: 48px;
  font-weight: 500;
  color: var(--tx-normal);
  margin-top: 20px;
}

.about p {
  font-size: 14px;
  color: var(--tx-semi);
  margin-top: 10px;
  line-height: 26px;
}

.about button {
  width: 100%;
  height: 50px;
  margin-top: 40px;
  font-size: 16px;
  padding: 10px 20px;
  background: var(--accent-red);
  color: var(--tx-normal);
  border-radius: 8px;
  border: none;
  cursor: pointer;
}

.scroll {
  height: calc(100vh - 240px);
  overflow: auto;
}

.form {
  padding: 40px 30px 0 30px;
  position: relative;
}

.form span {
  font-size: 16px;
  color: var(--tx-semi);
}

.input {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 40px;
}

.input_disabled .chain {
  cursor: not-allowed;
}

.input label {
  font-size: 40px;
  color: var(--tx-dimmed)
}

.labels {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.bal {
  display: flex;
  align-items: center;
  gap: 20px;
}

.bal p {
  font-size: 16px;
  color: var(--tx-dimmed)
}

.bal button {
  height: 30px;
  font-size: 14px;
  padding: 0 16px;
  background: var(--accent-green);
  color: var(--tx-normal);
  border-radius: 8px;
  border: none;
  cursor: pointer;
}

.input2 {
  width: 100%;
  display: flex;
  flex-direction: column;
  margin-bottom: 40px;
  gap: 10px;
}

.input2:last-child {
  margin-bottom: 0;
}

.input2 label {
  font-size: 20px;
  color: var(--tx-dimmed)
}

.input2 input {
  width: 100%;
  height: 70px;
  padding: 0 20px;
  font-size: 40px;
  border: none;
  outline: none;
  border-bottom: 1px solid var(--bg-lighter);
  background: var(--bg-light);
  color: var(--tx-normal);
}

.chain {
  display: flex;
  align-items: center;
  gap: 20px;
  border-bottom: 2px dashed var(--bg-lightest);
  height: 80px;
  cursor: pointer;
}

.chain img {
  width: 40px;
  height: 40px;
  border-radius: 50%;
}

.chain p {
  font-size: 40px;
  color: var(--tx-normal)
}

.chain svg {
  width: 40px;
  height: 40px;
}

.actions {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 20px 0;
}

.actions button {
  width: 100%;
  height: 80px;
  font-size: 18px;
  padding: 0 20px;
  background: var(--primary-light);
  color: var(--bg);
  border-radius: 8px;
  border: none;
  cursor: pointer;
}

.actions button:disabled {
  background: var(--bg-lighter);
  color: var(--tx-dimmed);
  cursor: not-allowed;
}
</style>
