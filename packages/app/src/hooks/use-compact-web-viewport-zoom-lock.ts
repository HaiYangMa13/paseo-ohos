import { useEffect } from "react";
import { isWeb } from "@/constants/platform";

const COMPACT_WEB_VIEWPORT_CONTENT =
  "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover";
const DEFAULT_WEB_VIEWPORT_CONTENT = "width=device-width, initial-scale=1, viewport-fit=cover";

export function useCompactWebViewportZoomLock(isCompactLayout: boolean) {
  useEffect(() => {
    if (!isWeb) {
      return;
    }

    // On HarmonyOS foldables (Pura X Max / Mate X), locking user-scalable=no with a static
    // scale prevents the WebView engine from stretching/re-layouting when the physical screen
    // unfolds or rotates, leaving half of the screen as a black/blank canvas.
    // Instead, allow dynamic re-scaling and full viewport-fit coverage.
    if (typeof globalThis !== "undefined" && (globalThis as { HarmonyBridge?: unknown }).HarmonyBridge != null) {
      const viewportMeta =
        document.querySelector<HTMLMetaElement>('meta[name="viewport"]') ??
        document.createElement("meta");
      if (!viewportMeta.parentElement) {
        viewportMeta.name = "viewport";
        document.head.appendChild(viewportMeta);
      }
      viewportMeta.setAttribute("content", "width=device-width, initial-scale=1, viewport-fit=cover");
      return;
    }

    const viewportMeta =
      document.querySelector<HTMLMetaElement>('meta[name="viewport"]') ??
      document.createElement("meta");
    const hadViewportMeta = viewportMeta.parentElement !== null;
    const previousContent = viewportMeta.getAttribute("content");

    if (!hadViewportMeta) {
      viewportMeta.name = "viewport";
      document.head.appendChild(viewportMeta);
    }

    viewportMeta.setAttribute(
      "content",
      isCompactLayout ? COMPACT_WEB_VIEWPORT_CONTENT : DEFAULT_WEB_VIEWPORT_CONTENT,
    );

    return () => {
      if (!hadViewportMeta) {
        viewportMeta.remove();
        return;
      }
      if (previousContent !== null) {
        viewportMeta.setAttribute("content", previousContent);
      }
    };
  }, [isCompactLayout]);
}
