## v0.2.0

### ✨ 新增功能

- 应用品牌重命名为 SingBar，菜单栏图标更新为 sing-box 风格
- 支持检测系统安装的 sing-box 作为 Core（用于无内置内核版本）
- 新增 sing-box JSON 配置模板（过渡）

### 🚀 优化改进

- 菜单栏面板布局更紧凑，二级 Tab 默认仅展示图标
- 空闲状态的网速曲线回归基线，减少无意义的抖动
- 降低闲置状态的轮询与流事件开销，减少不必要的状态发布

### 🧰 构建与发布

- Release DMG 产物命名与下载链接统一为 SingBar
- 修复打包后的 app bundle 可执行文件名仍为 ClashBar 的问题（进程名显示为 SingBar）

## v0.1.5

### 🐞 修复问题

- 修复 macOS 13 Intel 平台下的兼容性问题，提升应用在旧版 Intel 设备上的启动与界面稳定性

<details>
<summary><strong> ✨ 新增功能 </strong></summary>

- 新增无内核版本的 ClashBar 安装包，支持按需分发不内置 Mihomo 内核的应用版本
- 支持在未内置核心组件时提供首次启动引导，方便用户手动安装和配置 Mihomo 内核

</details>

<details>
<summary><strong> 🚀 优化改进 </strong></summary>

- 优化未内置内核场景下的启动流程，缺少托管内核时将延后自动启动并提供更清晰的提示信息
- 调整启动失败与 TUN 相关错误提示文案，帮助用户更快定位和处理手动安装内核后的运行问题
- 优化打包与发布流程，适配新的安装包结构并同步更新相关资源与文档

</details>
