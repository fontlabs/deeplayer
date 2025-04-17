import { createRouter, createWebHistory } from "vue-router";
import RestakeView from "../views/RestakeView.vue";
import OperatorView from "../views/OperatorView.vue";
import AVSView from "../views/AVSView.vue";
import StakeView from "@/views/restake/StakeView.vue";
import UnStakeView from "@/views/restake/UnStakeView.vue";
import DelegateView from "@/views/operator/DelegateView.vue";
import AVSInfoView from "@/views/avs/AVSInfoView.vue";
import AIView from "@/views/AIView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    } else {
      return { top: 0 };
    }
  },
  routes: [
    {
      path: "/",
      name: "restake",
      component: RestakeView,
    },
    {
      path: "/operator",
      name: "operator",
      component: OperatorView,
    },
    {
      path: "/avs",
      name: "avs",
      component: AVSView,
    },
    {
      path: "/restake/:id",
      name: "restake-stake",
      component: StakeView,
    },
    {
      path: "/restake/:id/unstake",
      name: "restake-unstake",
      component: UnStakeView,
    },
    {
      path: "/operator/:id",
      name: "operator-delegate",
      component: DelegateView,
    },
    {
      path: "/avs/:id",
      name: "avs-id",
      component: AVSInfoView,
    },
    {
      path: "/ai",
      name: "ai",
      component: AIView,
    },
  ],
});

export default router;
