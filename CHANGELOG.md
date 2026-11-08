# 更新日志 / Changelog

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。
This project follows [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-11-08

### 新增 / Added
- 中英双语教程（Word + Markdown）：`docs/NoASLR32-双语教程-Bilingual-Guide.docx`、`docs/TUTORIAL.md`
  Bilingual guide (Word + Markdown)
- 开源项目文件：`LICENSE`（MIT）、`CONTRIBUTING.md`、`CHANGELOG.md`、`.gitignore`
  Open-source project files: MIT license, contributing guide, changelog, gitignore

### 变更 / Changed
- 补齐著作权声明：NOTICE.txt、脚本头部版权、README 作者区块（MIT 兼容）
  Added copyright notices: NOTICE.txt, script headers, README author section (MIT-compatible)
- README 重写为中英双语，补充徽章、快速开始与风险说明
  README rewritten bilingually with badges, quick start and risk notes

## [1.2.0] - 2026-11-06

### 新增 / Added
- `Disable-ImageASLR.ps1`：系统级一次性关闭镜像随机化（需管理员 + 重启）
  Machine-wide switch to disable image ASLR (admin + reboot)

### 修复 / Fixed
- 目录递归模式下跳过符号链接，避免重复处理
  Skip symlinks in recursive mode to avoid double processing

## [1.1.0] - 2026-11-03

### 新增 / Added
- `Test-PE32Loader.ps1`：区分 `LOADER` / `APP` / `PASS` 三种结果
  Tester distinguishing LOADER / APP / PASS
- 修复前自动备份为 `.orig-nosaslr`
  Automatic `.orig-nosaslr` backup before patching

### 修复 / Fixed
- 修复带 BOM 的路径解析异常
  Fixed path parsing for paths containing a BOM

## [1.0.0] - 2026-11-02

### 新增 / Added
- 首个版本：`Fix-PE32-ASLR.ps1`，清除 32 位 EXE 的 `DYNAMIC_BASE` 位
  Initial release: `Fix-PE32-ASLR.ps1` clearing the `DYNAMIC_BASE` bit of 32-bit EXEs
