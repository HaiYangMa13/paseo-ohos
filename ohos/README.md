# Paseo OHOS — HarmonyOS/OpenHarmony Client

> Unofficial downstream client. Not affiliated with or endorsed by the upstream Paseo project or Huawei Technologies Co., Ltd.

基于 **HarmonyOS NEXT (API 12/13)** 纯原生开发的 Paseo 控制端，用于在华为鸿蒙手机、折叠屏及平板电脑上实时监控与控制本地 AI 编码 Agent（如 Claude Code、Codex、GitHub Copilot、OpenCode、Pi、Cursor 等）。

---

## 架构概览

Paseo 遵循严格的客户端-服务端解耦设计：

- **Paseo Daemon（运行在 PC / 服务器）**：负责进程调度、Git Worktree 管理、终端 PTY 字符流以及运行各大 Agent 的 CLI。
- **Paseo HarmonyOS Client（运行在鸿蒙设备）**：纯 ArkTS + ArkUI 原生开发，通过 WebSocket RPC 协议与 Daemon 或 Relay 中继通信。

```
┌─────────────────────────────────────────────────────────┐
│              HarmonyOS NEXT (Phone / Foldable)          │
│                                                         │
│  ┌─────────────────┐ ┌────────────────┐ ┌────────────┐  │
│  │ Agent Chat/Diff │ │ Live View 实况窗│ │  Terminal  │  │
│  └────────┬────────┘ └───────┬────────┘ └──────┬─────┘  │
│           └──────────────────┼─────────────────┘        │
│                    PaseoStore / ArkTS                   │
│                              │                          │
│                PaseoWebSocketClient (RPC)               │
└──────────────────────────────┼──────────────────────────┘
                               │  WebSocket JSON-RPC
                               │  (Direct LAN / Relay)
┌──────────────────────────────▼──────────────────────────┐
│              PC / Linux / Mac (Paseo Daemon)            │
│                       Port 6767                         │
│                                                         │
│   Claude Code │ Codex │ Pi Agent │ OpenCode │ Cursor    │
└─────────────────────────────────────────────────────────┘
```

---

## 核心特性与鸿蒙专属适配

1. **鸿蒙实况窗 (Live View)**
   - 通过 `@kit.LiveViewKit` 的 `PROGRESS` 场景接入原生实况窗；Agent 处于 `running` 状态时显示状态栏胶囊与锁屏卡片；
   - 任务完成切为 `idle` 时结束实况窗，需要审批时发送横幅通知；
   - `PROGRESS` 场景需要在 AppGallery Connect 为当前应用申请并开通 Live View Kit 权益；未开通时系统会返回 `1003500005`。
2. **折叠屏与平板双栏响应式布局 (Split View)**
   - 自动检测屏幕宽度（`min-width: 600vp`）：
     - **普通手机模式**：底部 Tab 栏导航，点击 Agent 页面无缝转场详情页；
     - **折叠屏展开态 / 平板模式**：左侧 Workspace / Agent 树形列表，右侧宽屏展示 Agent 流式对话、ANSI 彩色终端及 Git 实时 Diff。
3. **ANSI 虚拟终端仿真**
   - 完整支持 Paseo 二进制终端帧协议（Opcode 0x01 Output / 0x02 Input / 0x03 Resize）；
   - 内置轻量级 ANSI 颜色转义字符解析器（16 色及高亮色），高帧率渲染终端字符流。
4. **Git Diff 审查器**
   - 结构化解析统一 Diff 补丁格式（Unified Diff），支持按文件折叠、行号对照、绿红增删代码高亮。
5. **实时工具审批 (Permission Flow)**
   - 遇到高危 Bash 指令或文件写入时，客户端即时弹出原生核准卡片，支持一键批准或驳回。
6. **语音交互 (Voice)**
   - ArkWeb 会把网页的音频采集请求转交原生权限回调，并动态申请 `ohos.permission.MICROPHONE`；
   - 同时兼容 `navigator.mediaDevices.getUserMedia` 与 ArkWeb 旧版 `getUserMedia` 入口。

---

## 工程目录结构

```
paseo-harmonyos/
├── AppScope/
│   ├── app.json5                               # 应用全局配置 (包名: sh.paseo.harmony)
│   └── resources/base/media/app_icon.png       # 应用图标
├── build-profile.json5                         # 工程级编译配置 (API 12)
├── oh-package.json5                            # ohpm 包配置
└── entry/
    ├── build-profile.json5                     # 模块编译配置
    ├── oh-package.json5                        # 模块依赖
    └── src/main/
        ├── module.json5                        # Ability 配置、权限申请 (网络/后台等)
        ├── resources/base/                     # 颜色、字符、页面路由配置
        └── ets/
            ├── entryability/
            │   └── EntryAbility.ets            # 应用生命周期入口、沉浸式窗口配置
            ├── common/
            │   ├── constants/AppConstants.ets  # 全局常量、默认端口
            │   ├── models/                     # 强类型数据模型
            │   │   ├── Agent.ets               # Agent 生命周期与工具审批定义
            │   │   ├── Workspace.ets           # 工作区与 Git Diff 结构
            │   │   ├── TimelineItem.ets        # 流式时间线模型
            │   │   └── ProtocolMessages.ets    # WebSocket Wire 协议封装
            │   ├── protocol/
            │   │   ├── PaseoWebSocketClient.ets# 底层 WS 客户端、心跳、RPC 回调
            │   │   └── TerminalBinaryCodec.ets # 终端二进制帧编解码
            │   ├── store/
            │   │   ├── HostConfigStore.ets     # 主机配置持久化存储 (Preferences)
            │   │   └── PaseoStore.ets          # 全局响应式状态管理中心
            │   ├── utils/
            │   │   ├── AnsiParser.ets          # ANSI 颜色转义解析器
            │   │   ├── DiffParser.ets          # Git Diff 统一补丁解析器
            │   │   └── Logger.ets              # HiLog 日志封装
            │   └── services/
            │       └── LiveViewService.ets     # 鸿蒙实况窗与后台状态同步服务
            ├── components/
            │   ├── AgentCard.ets               # Agent 状态卡片
            │   ├── AgentChatView.ets           # 交互流式对话与输入栏
            │   ├── PermissionDialog.ets        # 工具审批弹窗
            │   ├── TerminalView.ets            # ANSI 彩色虚拟终端交互组件
            │   ├── DiffViewer.ets              # 代码改动差异对比组件
            │   └── HostConnectSheet.ets        # 多主机管理与连接弹窗
            └── pages/
                ├── Index.ets                   # 响应式主界面 (手机单栏 / 折叠屏双栏)
                ├── AgentDetailPage.ets         # Agent 移动端全屏详情页
                ├── TerminalPage.ets            # 全屏独立终端页
                ├── DiffPage.ets                # 全屏 Git 变更检查页
                └── SettingsPage.ets            # 连接状态与设置诊断页
```

---

## 快速上手与运行

### 1. 开发环境要求

- **IDE**：Huawei DevEco Studio 5.0 Release 或更新版本
- **SDK**：HarmonyOS NEXT Developer Beta / Release SDK (API Version 12 以上)

### 2. 打开与构建

1. 打开 DevEco Studio，选择 **File -> Open...**，选择本目录 `ohos/`。
2. 检查右上角 **Project Structure -> Project -> Signing Configs**，勾选 `Automatically generate signature`（或者配置你的开发者证书）。
3. 选择目标设备（鸿蒙真机或模拟器），点击 **Run** 即可一键编译安装并运行。

### 3. 连接电脑上的 Paseo Daemon

1. **电脑端准备**：
   - 确保本机或局域网服务器已安装并运行 Paseo（默认端口 `6767`）。
   - 查看电脑局域网 IP（例如 `192.168.1.100`）。
2. **鸿蒙 App 连接**：
   - 打开 Paseo 鸿蒙 App，点击右上角的主机名称按钮；
   - 点击 **+ Add Host**，输入：
     - 名称：`Work PC`
     - 地址：`ws://192.168.1.100:6767`
   - 点击 **Save & Connect**；
   - 状态指示灯变绿（CONNECTED），即可直接在鸿蒙手机上查看到电脑上的所有 Workspaces、实时交互 Agent、查看终端和审批代码工具执行！
