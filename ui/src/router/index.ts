import { createRouter, createWebHistory } from "vue-router";
import RestakeView from "../views/RestakeView.vue";
import OperatorView from "../views/OperatorView.vue";
import AVSView from "../views/AVSView.vue";
import StakeView from "@/views/restake/StakeView.vue";
import UnStakeView from "@/views/restake/UnStakeView.vue";
import DelegateView from "@/views/operator/DelegateView.vue";
import UnDelegateView from "@/views/operator/UnDelegateView.vue";
import AVSInfoView from "@/views/avs/AVSInfoView.vue";

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
      path: "/operator/:id/undelegate",
      name: "operator-undelegate",
      component: UnDelegateView,
    },
    {
      path: "/avs/:id",
      name: "avs-id",
      component: AVSInfoView,
    },
  ],
});

export default router;
