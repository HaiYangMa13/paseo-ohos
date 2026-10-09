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
  unavailable: "huaweiPush.unavailable",
} as const;

function HostPushCallout({ serverId, entry }: { serverId: string; entry: HarmonyPushEntry }) {
  const { t } = useTranslation();
  const callouts = useSidebarCallouts();
  const hosts = useHosts();
  const label = hosts.find((host) => host.serverId === serverId)?.label ?? serverId;
  useEffect(() => {
    const state = entry.state;
    const failed = state.status === "error" || state.status === "denied";
    const description =
      state.status === "error"
        ? t("huaweiPush.error", { code: state.code })
        : t(DESCRIPTION_KEYS[state.status]);
    const actions: SidebarCalloutAction[] = [];
    if (state.status === "permission-required")
      actions.push({ label: t("huaweiPush.enable"), onPress: entry.retry });
    if (state.status === "denied")
      actions.push({ label: t("huaweiPush.settings"), onPress: entry.retry });
    if (state.status === "error")
      actions.push({ label: t("common.actions.retry"), onPress: entry.retry });
    let variant: "default" | "success" | "error" = "default";
    if (state.status === "ready") variant = "success";
    if (failed) variant = "error";
    return callouts.show({
      id: `huawei-push:${serverId}`,
      dismissalKey: state.status === "ready" ? `huawei-push-ready:${serverId}` : undefined,
      title: t("huaweiPush.title", { host: label }),
      description: <SidebarCalloutDescriptionText>{description}</SidebarCalloutDescriptionText>,
      variant,
      actions,
      dismissible: !failed,
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
