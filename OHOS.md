# Paseo OHOS

This repository is an unofficial downstream of [Paseo](https://github.com/getpaseo/paseo) with a HarmonyOS/OpenHarmony client under [`ohos/`](./ohos/).

> Paseo OHOS is community-maintained and is not affiliated with, endorsed by, or sponsored by the Paseo project or Huawei Technologies Co., Ltd.

## What is included

- Official Paseo app sources with HarmonyOS-specific web-runtime fixes.
- ArkTS/ArkUI HarmonyOS client in `ohos/`.
- HarmonyOS Scan Kit QR pairing bridge.
- Edge-to-edge foldable/landscape layout handling.
- Foldable Explorer safe-area handling.
- HarmonyOS-specific behavior that prevents automatic Composer focus when entering a tab.

## Build the HarmonyOS client

1. Open `ohos/` in DevEco Studio.
2. Configure a HarmonyOS signing profile for your test device.
3. Build the HAP with API 12 or newer.
4. Install the signed HAP with `hdc` or run it from DevEco Studio.

The embedded Paseo web client is generated from `packages/app` and copied into `ohos/entry/src/main/resources/rawfile/` during the downstream build process. Do not commit local signing files or generated build directories.

## Upstream relationship

The upstream project remains the source of the desktop/server/client architecture and protocol. HarmonyOS-specific changes are kept in this downstream so they can be reviewed and, where appropriate, proposed upstream separately.

See [`ohos/README.md`](./ohos/README.md) for the HarmonyOS client details.
