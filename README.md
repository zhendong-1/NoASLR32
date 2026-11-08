# NoASLR32 Toolkit

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D6)](#兼容性--compatibility)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE)](#兼容性--compatibility)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> 修复 Windows 11 **26100 / 26300 系（24H2 / 25H2 / 26H2）** 上 32 位程序启动即报 `0xC0000005` 的加载器缺陷。
> A workaround for 32-bit applications crashing with `0xC0000005` at startup on Windows 11 builds **26100 / 26300**.

---

## 问题 / The problem

在这些版本上，部分 32 位程序双击后立刻弹出：

```
应用程序无法正常启动(0xc0000005)。请单击“确定”关闭应用程序。
```

64 位程序完全正常；换目录、改兼容性、重装运行库都无效。

On these builds, some 32-bit programs fail immediately with `0xc0000005` — while every 64-bit program works fine,
and changing folders, compatibility flags, or reinstalling runtimes does nothing.

**原因 / Cause**：32 位加载器在处理被 ASLR 重定位过的镜像时写错地址，崩在 `ntdll+0x35D41`，此时 `kernel32` 还没加载。

The 32-bit loader writes to the wrong address while handling an ASLR-relocated image, crashing at `ntdll+0x35D41`
before `kernel32` is even loaded.

**修法 / Fix**：清掉 EXE 头部 `IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE`（`0x40`）位，系统按首选基址 `0x400000` 加载，不再重定位。

Clear the `IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE` (`0x40`) bit so the image loads at its preferred base `0x400000`
without relocation.

---

## 快速开始 / Quick start

```powershell
# 1) 判断是不是这个病 / check whether this is the defect
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-PE32Loader.ps1 -Path "D:\app\app.exe"

#    LOADER = 中招，可修 / affected, fixable
#    APP    = 崩在程序自己代码里，本工具无效 / crashes in app code, not applicable
#    PASS   = 本来就能跑 / already fine

# 2) 预览（不写入）/ dry run, nothing written
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe" -DryRun

# 3) 修复（自动备份为 .orig-nosaslr）/ apply, auto-backup
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe"

# 4) 还原 / restore
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe" -Restore
```

## 文件说明 / Files

| 文件 / File | 作用 / Purpose |
|---|---|
| `Fix-PE32-ASLR.ps1` | 修复单个/一批 32 位 EXE，自动备份、可还原<br>Patch one or many 32-bit EXEs; auto-backup and restore |
| `Test-PE32Loader.ps1` | 判断崩溃发生在加载器阶段还是应用阶段<br>Tell whether the crash is in the loader or the app |
| `Disable-ImageASLR.ps1` | 系统级一次性关闭（需管理员 + 重启，整机失去 ASLR）<br>Machine-wide switch (admin + reboot; removes ASLR everywhere) |
| `docs/NoASLR32-双语教程-Bilingual-Guide.docx` | 完整中英双语图文教程<br>Full bilingual guide (Word) |
| `docs/TUTORIAL.md` | 同上的 Markdown 版<br>Same guide in Markdown |

## 输出示例 / Sample output

```
32-bit : DllCharacteristics = 0x8140  (ASLR on)
fixed  : DllCharacteristics = 0x8100  (ASLR off)
```

只改 `0x40` 一位，其它位（NX、大地址感知、高熵）保持不动。
Only bit `0x40` changes; NX, large-address-aware and high-entropy bits are untouched.

## 注意 / Notes

- 只对 **32 位** 有效，脚本自动跳过 64 位 EXE。Only applies to 32-bit binaries; 64-bit EXEs are skipped.
- 被修的程序**失去地址随机化**，浏览器、密码管理器这类别动。
  Patched programs **lose address randomization**; do not use it on browsers or password managers.
- Steam 等平台验证文件完整性或自动更新会冲掉补丁，**更新后重跑一次**。
  Platform verify/updates overwrite the patch — **re-run after each update**.
- 检测结果是 `APP` 时本工具无效，那是程序自身的 bug。
  If the tester reports `APP`, this toolkit does not apply — that is a bug in the program itself.

## 兼容性 / Compatibility

- Windows 10 / 11；主要针对 **26100 / 26300 系**，更早版本通常没有该缺陷。
  Windows 10 / 11; aimed at builds **26100 / 26300**. Earlier builds usually do not have this defect.
- Windows PowerShell 5.1 与 PowerShell 7 均可，脚本带 UTF-8 BOM。
  Works on Windows PowerShell 5.1 and PowerShell 7; scripts carry a UTF-8 BOM.
- 不需要安装运行库，不联网。
  No runtime install, no network access.

## 参与 / Contributing

见 [CONTRIBUTING.md](CONTRIBUTING.md)。提交崩溃样本时请附上：系统版本（`winver`）、程序名称与位数、
`Test-PE32Loader.ps1` 的输出、以及崩溃地址（若有）。

See [CONTRIBUTING.md](CONTRIBUTING.md). When reporting a crash, include: OS build (`winver`), program name and
bitness, `Test-PE32Loader.ps1` output, and the fault address if available.

## 作者 / Author

**震东1（zhendong1）** · © 2026 · MIT License

- 项目主页 / Homepage: <https://github.com/zhendong1/NoASLR32-Toolkit>
- 引用请保留署名 / Keep the attribution when citing:

```
震东1（zhendong1）— NoASLR32 Toolkit, MIT License
```

## 许可 / License

[MIT](LICENSE) © 2026 zhendong1

## 免责 / Disclaimer

按“现状”提供。修改可执行文件存在风险，请先在副本上测试，并确认你有权修改该软件。
Provided **as is**. Modifying executables carries risk — test on a copy and make sure you are allowed to modify the software.
