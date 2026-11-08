# 贡献指南 / Contributing

感谢你愿意改进这个项目。Thank you for helping improve this project.

## 报告问题 / Reporting issues

请附上以下信息，缺少这些很难定位：

Please include the following — without them triage is very hard:

| 项目 / Item | 获取方式 / How |
|---|---|
| 系统版本 / OS build | `winver` 截图或 `[System.Environment]::OSVersion.Version` |
| 程序名称与位数 / Program & bitness | 文件名，32 位还是 64 位 / file name and bitness |
| 检测输出 / Tester output | `Test-PE32Loader.ps1 -Path "...\app.exe"` 的完整输出 |
| 崩溃地址 / Fault address | 事件查看器 → Windows 日志 → 应用程序，事件 ID 1000 |
| 是否已尝试 / What you tried | 兼容性模式、重装运行库等 |

如果是 `APP` 结果，本工具不适用——但也欢迎贴出来，便于统计哪些崩溃**不是**加载器问题。
If the result is `APP`, this toolkit does not apply — still welcome, it helps document what is *not* a loader issue.

## 提交代码 / Pull requests

- 保持纯 PowerShell（5.1 兼容），不引入外部依赖。
  Keep it pure PowerShell (5.1 compatible), no external dependencies.
- 所有写操作必须有 `-DryRun` 预览路径和备份/还原路径。
  Every write path must have a `-DryRun` preview and a backup/restore path.
- 改动 PE 头时只碰 `DllCharacteristics` 的 `0x40` 位，其它位不得变动。
  When editing the PE header, only touch bit `0x40` of `DllCharacteristics`.
- 脚本文件保持 UTF-8 BOM 编码（否则 Windows PowerShell 5.1 下中文乱码）。
  Keep scripts UTF-8 **with BOM**, otherwise Chinese text breaks on Windows PowerShell 5.1.
- 提交信息用中文或英文皆可，说清“改了什么、为什么”。
  Commit messages may be Chinese or English — state what changed and why.

## 文档 / Documentation

双语教程在 `docs/`。修改文档时请**中英同步**，不要把一种语言落下。
The bilingual guide lives in `docs/`. When editing docs, update both languages.

## 行为准则 / Code of conduct

技术讨论就事论事。不欢迎人身攻击、广告和与项目无关的内容。
Keep discussions technical and civil. No personal attacks, ads, or off-topic content.
