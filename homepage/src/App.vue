<script setup lang="ts">
import { Application } from '@splinetool/runtime';
import { onMounted } from 'vue';
import AppHeader from './components/icons/AppHeader.vue';

onMounted(() => {
  const canvas = document.getElementById('canvas3d')! as HTMLCanvasElement;
  const app = new Application(canvas);
  app.load('/scene.splinecode');
});
</script>

<template>
  <AppHeader />

  <section class="hero_section">
    <div class="app_width">
      <div class="hero">
        <div class="text">
          <h3>Restake, Earn, and Build Actively Validated Services.</h3>
          <p>Leverage on SUI and Bitcoin economical security for off-chain verification.</p>
          <a href="https://beta.deeplayr.xyz" target="_blank"><button>Launch Beta</button></a>
        </div>
      </div>
    </div>
  </section>

  <canvas id="canvas3d" class="canvas"></canvas>
</template>

<style scoped>
.canvas {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  opacity: 0.3;
}

.hero {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-wrap: wrap;
  min-height: 80vh;
  padding: 50px 0;
}

.text {
  width: 1000px;
  text-align: center;
  max-width: 100%;
}

.text h3 {
  font-size: 80px;
  line-height: 60px;
  color: var(--tx-normal);
  font-weight: 600;
}

.text p {
  margin-top: 30px;
  font-size: 30px;
  line-height: 40px;
  color: var(--tx-semi);
}

.text button {
  margin-top: 60px;
  color: var(--tx-normal);
  padding: 16px 40px;
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
  z-index: 10;
  position: absolute;
  left: 50%;
  top: 600px;
  transform: translate(-50%, 0);
}

.text button:hover {
  filter: brightness(1.05);
}

.text button:active {
  transform: scale(.95);
}
</style>
