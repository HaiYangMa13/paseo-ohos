# Paseo OHOS — HarmonyOS Client

> 社区维护的非官方下游，不隶属于 Paseo 或华为。当前同步基线为上游 `v0.11.1`。

## 当前运行架构

`EntryAbility.ets` 启动 `pages/Index.ets`。主页面是 **ArkUI 外壳 + ArkWeb**，加载由 `packages/app` 导出的内嵌 Web 客户端，通过该客户端的 host-runtime 与电脑上的 Paseo Daemon 通信。

原生外壳负责扫码、麦克风权限、折叠屏安全区、键盘避让、UIAbility 生命周期、实况窗与本地通知。工程中保留的原生 `PaseoWebSocketClient`、聊天和终端页面不是当前主入口。

## 构建

在仓库根目录执行：

```sh
npm ci
npm run build:ohos-web
```

`build:ohos-web` 导出 Expo 浏览器客户端，然后将产物同步至 `entry/src/main/resources/rawfile/`。同步脚本将入口、字体及动态分块的根路径改为文档相对路径，供 ArkWeb rawfile URL 加载。只改 TypeScript 源码而不重新同步会让手机继续运行旧客户端。

用 DevEco Studio 打开本目录，配置本机签名并构建 `entry` HAP。不要提交本地证书、签名材料或 `entry/build/`。rawfile 是应用随包交付的客户端资源，保留在版本控制中；源码格式化与 lint 不检查生成的 bundle。

应用包名保持 `sh.paseo.harmony`。`versionName` 对齐上游版本；`versionCode` 独立递增，不能因为上游版本命名低于早期下游的 `1.0.0` 而降低安装版本码。

## 鸿蒙桥接

- **配对**：Scan Kit 的扫码结果交给上游 `openPairScan` 模型，沿用主机确认、密码与取消流程。不要恢复旧版直接添加主机的逻辑。
- **语音**：ArkWeb 音频权限回调申请 `ohos.permission.MICROPHONE`。Web 音频引擎兼容现代及旧版 `getUserMedia`；本地 rawfile 环境仍由原生权限回调授权。
- **前后台**：UIAbility 状态通过显式事件送入 host-runtime。回前台验证连接并合并重复恢复信号，不能仅依赖 Web 文档可见性事件。
- **实况窗**：使用 Live View Kit 的 `PROGRESS` 场景。需要在 AppGallery Connect 为应用开通权益；未开通可能返回 `1003500005`。
- **本地通知**：运行中的客户端发现审批请求后发送通知。它不是系统远程推送，客户端被挂起时不能承诺仍能收到审批。

## 后台连接边界

声明 `KEEP_BACKGROUND_RUNNING` 权限不会自动申请长时任务，也不保证 ArkWeb 后台持续执行。当前没有以空闲 WebSocket 为理由申请通用长时保活。真实后台上传/下载应按华为的业务类型、进度更新和暂停规则单独实现。

安装成功、定向逻辑测试通过与真机后台恢复验证是不同验收阶段。发布前需在手机验证扫码确认及密码、键盘避让、折叠/横屏安全区、后台后恢复连接和消息追赶。

## 上游同步

最初的下游快照来自 `d636abd7a4ce302e7ccb9eb6074f637c6dd4d83b`，但没有共同祖先。升级时用不改变文件的 `ours` 合并记录该明确基线，再三方合并 `v0.11.1`；没有重写旧提交。后续同步可使用正常的上游合并。

自建中继部署的消息尺寸补丁独立于源码同步。不要用上游镜像直接覆盖运行中的自定义 64 MiB 中继，也不要未经许可重启管理运行中 Agent 的主 daemon。
