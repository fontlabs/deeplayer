<script setup lang="ts">
import AppHeader from './components/AppHeader.vue';
import ChevronDownIcon from './components/icons/ChevronDownIcon.vue';
</script>

<template>
  <AppHeader />
  <section>
    <div class="app_width">
      <div class="app">
        <div class="form">
          <span>Bridge</span>

          <div class="input">
            <label>From</label>
            <div class="chain">
              <img src="/images/eth.png" alt="Ethereum">
              <p>Sepolia</p>
              <ChevronDownIcon />
            </div>
          </div>

          <div class="input">
            <label>To</label>
            <div class="chain">
              <img src="/images/sui.png" alt="SUI">
              <p>SUI</p>
              <ChevronDownIcon />
            </div>
          </div>

          <div class="input">
            <label>Asset</label>
            <div class="chain">
              <img src="/images/lbtc.png" alt="LBTC">
              <p>LBTC</p>
              <ChevronDownIcon />
            </div>
          </div>

          <div class="input2">
            <div class="labels">
              <label>Amount</label>
              <div class="bal">
                <p>Bal: 0 LBTC</p>
                <button>Mint</button>
              </div>
            </div>
            <input type="number" placeholder="0.00" />
          </div>

          <div class="input2">
            <label>Receiver (SUI address)</label>
            <input type="text" placeholder="0x1234567890abcdef1234567890abcdef12345678" />
          </div>

          <div class="actions">
            <button>Approve</button>
            <button disabled>Bridge</button>
          </div>
        </div>
        <div class="about">
          <span>About</span>
          <h1>Nebula</h1>
          <p>
            Nebula is a decentralized bridge that allows users to transfer assets between different blockchains using
            zero-knowledge proofs.
          </p>
          <a href="https://beta.deeplayr.xyz/avs/0x0000000000000000000000000000000000000000000000000000000000000002"
            target="_blank">
            <button>View AVS on DeepLayr.</button>
          </a>
        </div>
      </div>
    </div>
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

.form {
  padding: 40px 30px;
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
  margin-top: 20px;
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
