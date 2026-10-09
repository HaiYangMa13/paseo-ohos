import { useEffect } from "react";
import { useTranslation } from "react-i18next";
import {
  SidebarCalloutDescriptionText,
  type SidebarCalloutAction,
} from "@/components/sidebar-callout";
import { useSidebarCallouts } from "@/contexts/sidebar-callout-context";
import { useHosts } from "@/runtime/host-runtime";
import { useHarmonyPushStore, type HarmonyPushEntry } from "./internal/harmony";

const DESCRIPTION_KEYS = {
  loading: "huaweiPush.loading",
  ready: "huaweiPush.ready",
  denied: "huaweiPush.denied",
  "permission-required": "huaweiPush.permissionRequired",
} as const;

function HostPushCallout({ serverId, entry }: { serverId: string; entry: HarmonyPushEntry }) {
  const { t } = useTranslation();
  const callouts = useSidebarCallouts();
  const hosts = useHosts();
  const label = hosts.find((host) => host.serverId === serverId)?.label ?? serverId;

  useEffect(() => {
    const state = entry.state;
    const description =
      state.status === "error"
        ? t("huaweiPush.error", { code: state.code })
        : t(DESCRIPTION_KEYS[state.status]);
    const actions: SidebarCalloutAction[] = [];
    if (state.status === "permission-required") {
      actions.push({ label: t("huaweiPush.enable"), onPress: entry.retry });
    }
    if (state.status === "denied") {
      actions.push({ label: t("huaweiPush.settings"), onPress: entry.retry });
    }
    if (state.status === "error") {
      actions.push({ label: t("common.actions.retry"), onPress: entry.retry });
    }
    let variant: "default" | "success" | "error" = "default";
    if (state.status === "ready") variant = "success";
    if (state.status === "denied" || state.status === "error") variant = "error";

    return callouts.show({
      id: `huawei-push:${serverId}`,
      // One reminder per host and state: dismissing it stops the nagging until the state changes.
      dismissalKey:
        state.status === "loading" ? undefined : `huawei-push:${state.status}:${serverId}`,
      title: t("huaweiPush.title", { host: label }),
      description: <SidebarCalloutDescriptionText>{description}</SidebarCalloutDescriptionText>,
      variant,
      actions,
      dismissible: state.status !== "loading",
      priority: 90,
      testID: "huawei-push-callout",
    });
  }, [callouts, entry, label, serverId, t]);

  return null;
}

export function HarmonyPushCalloutSource() {
  const entries = useHarmonyPushStore((state) => state.entries);
  return Object.entries(entries).map(([serverId, entry]) => (
    <HostPushCallout key={serverId} serverId={serverId} entry={entry} />
  ));
}
