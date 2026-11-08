# Pixel Desk Lab

基于 Godot 4.7 的复古桌面交互原型，包含舱室场景、可输入的终端屏幕、收音机、录音机和台灯，以及像素化与旧印刷效果。

## 运行

1. 安装 Godot 4.7（当前开发版本为 4.7.2）。
2. 克隆仓库，在 Godot 项目管理器中导入 `project.godot`。
3. 等待资源导入完成，按 **F5** 运行。主场景为 `scenes/lab.tscn`。

界面中可切换观察视角、渲染模式和分辨率。点击终端屏幕输入，演示解锁口令为 `HELLO WORLD`；点击或拖动道具上的交互控件。

## 项目内容

- `scenes/`、`scripts/`、`shaders/`：场景、交互逻辑和渲染效果。
- `models/`、`art/`、`audio/`：模型、图像与音效；HI3D 模型来源记录见 `models/hi3d/manifest.json`。
- `tools/`、`scenarios/`、`verification/`：制作工具、检查场景和参考截图。

Godot 导入缓存 `.godot/` 与导出构建不纳入版本控制，首次打开时会重新生成缓存。
