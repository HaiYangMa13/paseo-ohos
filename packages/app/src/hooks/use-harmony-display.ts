import { useState, useEffect, useSyncExternalStore } from "react";
import { useWindowDimensions } from "react-native";
import { isHarmony } from "@/constants/platform";

export interface HarmonyDisplayMetrics {
  foldStatus: number; // 0: UNKNOWN, 1: EXPANDED, 2: FOLDED, 3: HALF_FOLDED
  isFoldExpanded: boolean;
  isFolded: boolean;
  isHalfFolded: boolean;
  isFoldable: boolean;
  rotation: number; // 0: 0, 1: 90, 2: 180, 3: 270
  orientation: number;
  widthVp: number;
  heightVp: number;
  isLandscape: boolean;
  safeAreaInsets: {
    top: number;
    bottom: number;
    left: number;
    right: number;
  };
}

const DEFAULT_METRICS: HarmonyDisplayMetrics = {
  foldStatus: 0,
  isFoldExpanded: false,
  isFolded: false,
  isHalfFolded: false,
  isFoldable: false,
  rotation: 0,
  orientation: 0,
  widthVp: 0,
  heightVp: 0,
  isLandscape: false,
  safeAreaInsets: { top: 0, bottom: 0, left: 0, right: 0 },
};

let currentMetrics: HarmonyDisplayMetrics = DEFAULT_METRICS;
const listeners = new Set<() => void>();

function emitChange() {
  for (const listener of listeners) {
    listener();
  }
}

// Initial read from bridge if available
if (isHarmony && typeof globalThis !== "undefined") {
  const bridge = (globalThis as unknown as { HarmonyBridge?: { getDisplayMetrics?: () => string } }).HarmonyBridge;
  if (bridge?.getDisplayMetrics) {
    try {
      const raw = bridge.getDisplayMetrics();
      if (raw) {
        currentMetrics = JSON.parse(raw);
      }
    } catch {
      // Ignore
    }
  }

  // Register global callback for push updates from ArkTS host
  (globalThis as unknown as { __onHarmonyDisplayMetricsChange?: (metrics: HarmonyDisplayMetrics) => void }).__onHarmonyDisplayMetricsChange = (metrics: HarmonyDisplayMetrics) => {
    currentMetrics = metrics;
    emitChange();
    // Dispatch resize event so Unistyles and react-native-web re-calculate breakpoints immediately
    if (typeof window !== "undefined") {
      window.dispatchEvent(new Event("resize"));
    }
  };
}

function subscribe(callback: () => void) {
  listeners.add(callback);
  return () => {
    listeners.delete(callback);
  };
}

function getSnapshot(): HarmonyDisplayMetrics {
  return currentMetrics;
}

export function useHarmonyDisplayMetrics(): HarmonyDisplayMetrics {
  const { width, height } = useWindowDimensions();
  const metrics = useSyncExternalStore(subscribe, getSnapshot, () => DEFAULT_METRICS);

  // If we are on Harmony, prefer the native metrics; fill width/height from RN window if 0
  if (isHarmony) {
    return {
      ...metrics,
      widthVp: metrics.widthVp > 0 ? metrics.widthVp : width,
      heightVp: metrics.heightVp > 0 ? metrics.heightVp : height,
      isLandscape: (metrics.widthVp > 0 ? metrics.widthVp : width) > (metrics.heightVp > 0 ? metrics.heightVp : height),
    };
  }

  return {
    ...DEFAULT_METRICS,
    widthVp: width,
    heightVp: height,
    isLandscape: width > height,
  };
}

/**
 * Returns whether the device is currently in an expanded foldable or wide tablet form factor.
 * When unfolded on a foldable phone like Mate X / Pura X Max, the layout should give ample room
 * for side-by-side agent stream and changes/terminal panes.
 */
export function useIsFoldExpanded(): boolean {
  const metrics = useHarmonyDisplayMetrics();
  if (isHarmony) {
    if (metrics.isFoldExpanded) return true;
    // Fallback: if width >= 700 on a square/tablet ratio, it's expanded
    return metrics.widthVp >= 700;
  }
  return false;
}
