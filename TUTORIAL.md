NoASLR32 Toolkit

中英双语使用教程  ·  Bilingual User Guide

Windows 11 26100 / 26300 系 32 位程序 0xC0000005 修复  ·  Fix for 32-bit programs failing with 0xC0000005 on Windows 11 builds 26100 / 26300

# 1. 这是什么 / What this is

这是一套判断并修复 **Windows 11 26100/26300 系（24H2 / 25H2 / 26H2）** 上“32 位程序一双击就报 0xC0000005”的工具。它不重装运行库、不改系统策略，只做一件事：把出问题的 EXE 的 ASLR 标志位清掉，让它按原始基址加载。

A small toolkit that diagnoses and fixes 32-bit applications that fail to start with 0xC0000005 on Windows 11 builds 26100 / 26300 (24H2 / 25H2 / 26H2). It does not touch runtime libraries or system policy; it only clears the ASLR flag of the affected EXE so it loads at its preferred base address.

- 四件套：检测脚本、修复脚本、整机开关脚本、这份教程。 — Four pieces: a tester, a fixer, a machine-wide switch, and this guide.

- 默认只改一个文件，改完会自动生成 .orig-nosaslr 备份，随时可还原。 — Only one file is modified by default; a .orig-nosaslr backup is created automatically and can be restored at any time.

# 2. 先判断是不是这个病 / Check first

这个工具不是“32 位崩溃”的万灵药。**只有崩溃发生在加载器阶段**才有效。判断方法：跑一次检测脚本，看它给出 LOADER / APP / PASS 中的哪一个。

This is not a cure for every 32-bit crash. It only helps when the crash happens in the loader stage. Run the tester and read which of LOADER / APP / PASS it reports.

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-PE32Loader.ps1 -Path "D:\app\app.exe"
```

典型症状（同时满足才像）：

Typical symptoms (all of them together):

- 双击立刻弹“应用程序无法正常启动(0xc0000005)”，没有窗口、没有加载画面。 — Immediate dialog “The application was unable to start correctly (0xc0000005)”, no window, no splash.

- 同一台机器上的 64 位程序全部正常。 — All 64-bit programs on the same machine work fine.

- 用 Process Monitor 看，进程只加载了 ntdll / wow64* 就退出，kernel32 都没加载。 — In Process Monitor the process loads only ntdll / wow64* and exits before kernel32 is loaded.

- 换目录、改兼容性、重装 VC++ 运行库都无效。 — Changing folders, compatibility flags, or reinstalling the VC++ runtime makes no difference.

# 3. 三分钟上手 / Quick start in 3 minutes

把工具包解压到任意目录，在该目录打开 PowerShell，按下面四步走。

Extract the toolkit anywhere, open PowerShell in that folder, and follow the four steps.

## 3.1 第一步：预览（不写入） / Step 1: dry run

先看清楚它要改哪个字节、现在是什么值，不会动文件。

See exactly which byte would change and its current value. Nothing is written.

```
.\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe" -DryRun
```

## 3.2 第二步：修复 / Step 2: apply

真正写入。会自动生成 app.exe.orig-nosaslr 备份。

Actually writes the change and creates app.exe.orig-nosaslr as a backup.

```
.\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe"
```

## 3.3 第三步：验证 / Step 3: verify

修复完再跑一次检测，应该从 LOADER 变成 PASS。

Run the tester again; the result should change from LOADER to PASS.

```
.\Test-PE32Loader.ps1 -Path "D:\app\app.exe"
```

## 3.4 第四步：还原（需要时） / Step 4: restore (if needed)

任何一步不满意，一条命令还原到原始文件。

Any time you want to undo it, one command restores the original file.

```
.\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe" -Restore
```

# 4. 四种用法 / Four ways to use it

脚本会自动跳过 64 位程序和系统保护文件，不会误伤。

64-bit executables and protected system files are skipped automatically.

# 5. 输出怎么读 / Reading the output

修复脚本对每个文件的输出分三部分：路径、PE 头里的原始标记、改完的标记。关键字段是 `DllCharacteristics`：

For each file the fixer prints the path, the original PE flag, and the new one. The key field is DllCharacteristics:

```
  32-bit : DllCharacteristics = 0x8140  (ASLR on  / 动态基址开)
  fixed  : DllCharacteristics = 0x8100  (ASLR off / 动态基址关)
```

- 0x8140 与 0x8100 只差 0x40，也就是 IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE。 — Only bit 0x40 differs: IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE.

- 其它位（NX、大地址感知、高熵）保持不动。 — All other bits (NX, large-address-aware, high-entropy) are left untouched.

- 校验失败时脚本会拒绝写入，不会产生半改文件。 — If validation fails the script refuses to write, so you never get a half-patched file.

# 6. 原理 / How it works

26100/26300 系的 32 位加载器在处理“**被 ASLR 重定位过**”的镜像时，往错误地址写数据，崩在 ntdll+0x35D41，此时 kernel32 还没加载。把 EXE 的 DYNAMIC_BASE 位清掉之后，系统直接把它加载到首选基址 0x400000，不再重定位，崩溃点消失。

The 32-bit loader in builds 26100/26300 writes to the wrong address while handling an image that has been relocated by ASLR, crashing at ntdll+0x35D41 before kernel32 is even loaded. Clearing DYNAMIC_BASE makes Windows load the EXE at its preferred base 0x400000 with no relocation, so the crash disappears.

为什么 64 位不受影响：64 位加载器走的是另一条代码路径，这个缺陷只在 32 位 WOW64 路径上触发。

Why 64-bit is unaffected: the 64-bit loader uses a different code path; the defect only triggers on the 32-bit WOW64 path.

# 7. 风险与边界 / Risks and limits

# 8. 整机模式（慎用） / Machine-wide mode (use with care)

当中招程序太多、逐个修太麻烦时，可以用系统级开关一次性关闭镜像随机化。它会改注册表 MoveImages，需要管理员权限并重启，**整机所有程序**都会失去 ASLR。

When too many programs are affected, a machine-wide switch can disable image randomization at once. It changes the MoveImages registry value, needs administrator rights and a reboot, and removes ASLR for every process on the machine.

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\Disable-ImageASLR.ps1
```

这个脚本会先打印将要修改的注册表项，确认后才写入，并给出还原方法。只在你明确知道后果时使用。

The script prints the registry value it will change, asks for confirmation, and documents how to revert. Use it only when you fully understand the trade-off.

# 9. 常见问题 / FAQ

Q：修完还是报 0xC0000005？

Q: Still getting 0xC0000005 after patching?

A：先看检测结果是不是 LOADER。如果是 APP，说明崩溃不在加载器，本工具不适用；把程序名和崩溃地址发出来再判断。

A: Check whether the tester reports LOADER. If it reports APP, the crash is not in the loader and this toolkit does not apply. Share the program name and fault address for further triage.

Q：杀毒软件报毒？

Q: Antivirus flags the script?

A：脚本会修改 EXE 文件头，属于“可疑行为”。这是开源明文 PowerShell，可以逐行读；也可以先 -DryRun 看它要改什么。

A: The script edits an EXE header, which looks suspicious. It is plain-text PowerShell and can be read line by line; run it with -DryRun first to see exactly what it would change.

Q：更新后又要修一次？

Q: Do I have to re-patch after an update?

A：是。平台更新会替换整个 EXE，补丁随之消失。把修复命令存成 .bat，更新后双击跑一次。

A: Yes. An update replaces the whole EXE and the patch is gone. Save the command as a .bat and run it after each update.

Q：能不能一次修完 Steam 里所有游戏？

Q: Can I patch every Steam game at once?

A：可以，用 -Recurse 指向游戏库目录；但建议先 -DryRun 看清单，避免改到带反作弊的程序。

A: Yes, point it at the library folder with -Recurse; but run -DryRun first and avoid anti-cheat protected titles.

Q：改坏了怎么办？

Q: What if something breaks?

A：一条 -Restore 命令还原；若备份丢失，用平台“验证文件完整性”也能恢复。

A: Use -Restore to revert; if the backup is lost, the platform’s “verify integrity” will restore the file.

# 10. 核验与还原 / Verify and revert

任何时候都可以用检测脚本判断当前状态：PASS 表示能正常启动，LOADER 表示仍是原始问题。

At any time the tester tells you the current state: PASS means it starts, LOADER means the original defect is still present.

```
.\Test-PE32Loader.ps1 -Path "D:\app\app.exe" -Verbose
```

备份文件命名规则：<原文件名>.orig-nosaslr。想手工还原，把备份改回原名即可。

Backup naming: <original>.orig-nosaslr. To revert manually, rename the backup back.

# 11. 兼容性 / Compatibility

- Windows PowerShell 5.1 与 PowerShell 7 均可，脚本带 UTF-8 BOM，中文不乱码。 — Works with Windows PowerShell 5.1 and PowerShell 7; scripts carry a UTF-8 BOM so Chinese text renders correctly.

- 若提示“在此系统上禁止运行脚本”，用本教程里带 -ExecutionPolicy Bypass 的命令行调用。 — If you see “running scripts is disabled on this system”, use the command lines in this guide, which include -ExecutionPolicy Bypass.

- 不需要安装任何运行库，也不联网。 — No runtime installation and no network access required.

# 12. 免责声明 / Disclaimer

本工具按“现状”提供，用于修复已知的加载器缺陷。修改可执行文件本身存在风险，请先在副本上测试，并确认你拥有修改该软件的权限。作者不对因使用本工具造成的任何损失负责。

Provided “as is” to work around a known loader defect. Modifying executables carries risk: test on a copy first and make sure you are allowed to modify the software. The author accepts no liability for any damage arising from use.

---

## 附录：表格数据 / Appendix: tables

### 表 1 / Table 1

| 结果 / Result | 含义 / Meaning | 能否修 / Fixable |
|---|---|---|
| LOADER | 崩溃发生在加载器阶段，本工具可修 / Crash in loader stage | ✅ 是 / Yes |
| APP | 程序自己能跑起来，崩在业务代码 / Program runs, crashes in its own code | ❌ 不是这个病 / No |
| PASS | 本来就能正常启动 / Starts fine | 不需要 / Not needed |

### 表 2 / Table 2

| 场景 / Scenario | 命令 / Command |
|---|---|
| 修单个程序 Single file | .\Fix-PE32-ASLR.ps1 -Path "D:\app\app.exe" |
| 修整个目录（不含子目录） Whole folder | .\Fix-PE32-ASLR.ps1 -Path "D:\game" |
| 修整个目录并递归 Folder + subfolders | .\Fix-PE32-ASLR.ps1 -Path "D:\game" -Recurse |
| 先看会改哪些 Preview only | .\Fix-PE32-ASLR.ps1 -Path "D:\game" -Recurse -DryRun |
| 批量还原 Restore all | .\Fix-PE32-ASLR.ps1 -Path "D:\game" -Recurse -Restore |

### 表 3 / Table 3

| 事项 / Item | 说明 / Detail |
|---|---|
| 安全代价 Security cost | 被修的程序失去地址随机化；游戏/工具无所谓，浏览器/密码管理器别动。 The patched EXE loses address randomization. Fine for games and utilities; avoid browsers and password managers. |
| 只对 32 位有效 32-bit only | 脚本自动跳过 64 位 EXE。 64-bit executables are skipped automatically. |
| 会被覆盖 Overwritten | Steam 等平台“验证文件完整性”或自动更新会冲掉补丁，重跑一次即可。 Steam “verify integrity” or auto-updates will restore the original file; just run the fixer again. |
| 不是万能药 Not a cure-all | 若检测结果是 APP，说明崩在程序自己的代码里，本工具无效。 If the tester reports APP, the crash is in the program’s own code; this toolkit will not help. |
| 系统版范围 OS range | 主要影响 26100 / 26300 系（24H2 / 25H2 / 26H2）；更早版本通常没这个问题。 Mainly affects builds 26100 / 26300 (24H2 / 25H2 / 26H2); earlier builds usually do not have this defect. |
