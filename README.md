# cod fishing mod

作者 / Author: **florain**

为星露谷的海洋增添奇妙的新住客与钓鱼故事。支持简体中文和英文。
New sea creatures and fishing stories for Stardew Valley, in Simplified Chinese and English.

## 下载与安装 / Download and install

**[下载可直接安装的最新版 / Download the latest release](https://github.com/huxinzhao/codfishingmod/releases/latest)**

[Nexus Mods 下载与更新 / Nexus Mods downloads and updates](https://www.nexusmods.com/stardewvalley/mods/52606)

选择发布附件 cod-fishing-mod-VERSION.zip，解压后将 cod fishing mod 文件夹放入游戏 Mods 文件夹。GitHub 的 Source code 和 Code → Download ZIP 是源码，不包含 DLL，不能直接安装。

Download the cod-fishing-mod-VERSION.zip release asset and extract its cod fishing mod folder into Mods. GitHub's source-code archives do not include the compiled DLL.

- Stardew Valley **1.6.15+**；SMAPI **4.5.1+**。
- 无需其他前置模组 / No other mods required.
- 从 1.5.4 起，SMAPI 会检查 Nexus 新版本并提供下载提示，不会自动安装更新。 / Starting with 1.5.4, SMAPI checks Nexus for updates and provides a download link; it does not install updates automatically.
- [中文安装说明](outputs/cod%20fishing%20mod/安装说明.txt) · [English installation guide](outputs/cod%20fishing%20mod/INSTALL.txt)

更新前备份存档。旧版特殊订单不再自动迁移；请先在旧版完成，或通过 1.4.0–1.5.0 迁移并保存。新版普通任务进度可以保留。勿同时安装旧版两个文件夹和新版文件夹。

Back up your save before updating. Legacy special orders are no longer migrated automatically: finish them on the old version, or migrate and save using 1.4.0–1.5.0 first. Current ordinary quest progress is retained. Remove the old two-folder installation before installing this version.

## 开发 / Development

- src/：源码、构建与检查脚本 / source, build and checks.
- outputs/cod fishing mod/：运行时数据与素材 / runtime data and assets.
- docs/文案审阅稿.md：中英对照审阅稿 / bilingual text review.

本机验证环境为 Windows + PowerShell 7.6.5。脚本使用 PowerShell 随附的 Roslyn 编译器，不需要另装 .NET SDK。游戏目录须已安装 SMAPI。

Validated locally on Windows with PowerShell 7.6.5. The scripts use PowerShell's bundled Roslyn compiler; no separate .NET SDK is required. Install SMAPI in the game directory first.

~~~powershell
pwsh -File ./src/build.ps1 -GameDir "D:/Games/Stardew Valley"
pwsh -File ./src/check.ps1 -GameDir "D:/Games/Stardew Valley"
pwsh -File ./src/package.ps1
~~~

也可设置 STARDEW_GAME_PATH 环境变量并省略 -GameDir。检查脚本会在独立进程中运行各项检查，避免测试类型冲突。检查不等于游戏内实测。

Alternatively, set STARDEW_GAME_PATH and omit -GameDir. Checks run in separate processes to avoid stub-type conflicts. These checks do not replace in-game testing.

构建结果 / Build output: outputs/cod fishing mod/CodFishingMod.dll.

## 文案维护 / Editing translations

~~~powershell
# Check that the review matches both language files.
pwsh -File ./src/sync-text.ps1 -Mode Check
# Import edited Chinese AND English entries.
pwsh -File ./src/sync-text.ps1 -Mode Import
# Regenerate the review from current translations and metadata.
pwsh -File ./src/sync-text.ps1 -Mode Export
~~~

先修改审阅稿，再执行 Import；两种语言需分别编辑，脚本不会自动翻译。导入会检查完整键集合和动态占位符。Export 会覆盖审阅稿，未导入的修改请先保存。

Edit the review, then run Import. Edit both languages yourself; the script does not translate automatically. Import validates the complete key set and dynamic placeholders. Export overwrites the review, so import pending edits first.

模组名称、作者与安装说明不由 Import 修改。请直接编辑 manifest.json、安装说明.txt 和 INSTALL.txt，再执行 Export。

Import does not modify metadata or installation guides. Edit those files directly, then run Export.
