# 琉璃作业（GlassHomework）未来规划与多端构想

> 状态：已记录搁置，待后续有需要时推进。

---

## 1. 最推荐：Mac 端对接苹果「提醒事项（Reminders / EventKit）」实现 iPhone 零成本联动

- **核心动机**：在不安装完整 Xcode、不额外维护 iOS App 证书与 7 天续签的前提下，让 iPhone 也能随时查看与提醒未完成作业。
- **实现思路**：
  1. 在 Mac 端引入系统 `EventKit` 框架（仅需 Command Line Tools 即可继续编译打包）。
  2. 在「琉璃作业」设置中增加「同步到 Apple 提醒事项」开关，指定同步列表（如「琉璃作业」）。
  3. 当作业新增、修改截止时间、勾选完成或删除时，双向或单向同步至该 `EKCalendar` 列表。
  4. 借助 Apple ID 自带的 iCloud 同步，iPhone 上无需安装任何第三方应用，直接使用系统自带 **「提醒事项」桌面小组件、锁屏组件与系统通知** 接收提醒。

---

## 2. iPhone（iOS 26）原生独立版本移植构想

- **代码复用率**：
  - `GlassHomeworkCore`（数据模型、紧急度分级与倒计时算法、提醒排期、Store、JSON 备份结构）可直接作为跨平台 Swift Package 复用，无需重写核心业务逻辑。
  - iOS 26 与 macOS 26 共用 SwiftUI 原生液态玻璃 API（`GlassEffectContainer`、`.glassEffect()`、`glassEffectID` 等）及 `UNUserNotificationCenter`。
- **主要改造点**：
  - 替换 macOS 专属 `AppKit` / `Carbon` / `LaunchAgents` 层，改为 iOS `NavigationStack` / `TabView` 页面交互。
  - 使用 **WidgetKit** 开发小 / 中 / 大尺寸主屏幕小组件与锁屏组件，通过 **App Group** 与主 App 共享数据，还原“桌面常驻查看与勾选”体验。
  - 若需要实时自动跨端同步，可进一步升级为 iCloud（CloudKit）存储（需苹果开发者权限）；轻量化场景亦可继续兼容 JSON 导入导出。
- **低本地磁盘占用构建方式**：
  - 由于完整 Xcode 对小容量 Mac 磁盘压力较大，后续若开发 iOS 版，可考虑使用 **GitHub Actions**（`macos-latest` runner）在云端自动编译打包，或将 Xcode 安装至外接高速 SSD。

---

## 3. Windows 端移植构想（远期评估）

- **现状评估**：由于 Mac 版深度依赖 macOS 26 原生 `NSGlassEffectView`、SwiftUI Liquid Glass、桌面壁纸层级窗口与系统服务，移植到 Windows 需保留 `store.json` 数据兼容并重写约 80% 客户端层。
- **可选技术路线**：
  1. **WinUI 3 / WPF（C# + Win32）**：性能轻量，结合系统 Acrylic / Mica 材质与 Win32 底层窗口层级实现桌面常驻贴纸。
  2. **Tauri（Rust + 前端）**：若未来需要一套界面同时覆盖 Windows 与 macOS，可用前端 CSS / Shader 模拟玻璃质感（但真实壁纸光学折射弱于 macOS 26 原生实现）。
