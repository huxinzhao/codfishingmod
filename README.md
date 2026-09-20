# cod fishing mod

作者：florain

为 Stardew Valley 的海洋增添新的生物与钓鱼故事，支持简体中文和英文。

## 项目结构

- `src/`：SMAPI 模组源码、构建脚本与检查脚本。
- `outputs/cod fishing mod/`：运行时数据、贴图、语言文件与安装说明。
- `docs/文案审阅稿.md`：可编辑的中英文文案。

## 构建

需要 PowerShell 7、Stardew Valley 1.6.15+ 和 SMAPI 4.5.1+。先将 `src/build.ps1` 中的 `$gameDir` 改为本机游戏目录，再运行：

```powershell
pwsh -File ./src/build.ps1
```

构建生成 `outputs/cod fishing mod/CodFishingMod.dll`。将整个 `cod fishing mod` 文件夹放入游戏的 `Mods` 文件夹，通过 SMAPI 启动游戏。

Git 仓库不包含生成的 DLL 和发布压缩包；直接下载源码后需要先构建。
