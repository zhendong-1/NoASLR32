<#
    NoASLR32 Toolkit
    Copyright (c) 2026 震东1(zhendong1)  ·  MIT License
    https://github.com/zhendong1/NoASLR32-Toolkit
    保留本段版权信息即可自由使用、修改、再分发。
#>

<#
.SYNOPSIS
    判定一个 32 位 EXE 的 0xc0000005 是"加载器阶段"崩溃还是"应用阶段"崩溃。

.DESCRIPTION
    用调试 API（DEBUG_ONLY_THIS_PROCESS）启动目标进程，捕获第一次访问冲突，
    并报告：
      - 崩溃发生在哪个模块的哪个偏移
      - 崩溃时进程里已经加载了哪些模块（据此区分加载器阶段 / 应用阶段）
      - 出错指令试图写入的地址及其内存保护属性

    判读规则：
      * 崩溃时只有 ntdll + wow64* 模块        -> LOADER，Windows 加载器自身的问题
      * 崩溃时已经加载 kernel32/user32 等      -> APP，程序自身或其依赖的问题

.PARAMETER Path
    要测试的 32 位 EXE 完整路径。

.PARAMETER Seconds
    等待超时（默认 8 秒）。超时未崩溃视为"加载器通过"。

.EXAMPLE
    .\Test-PE32Loader.ps1 -Path 'D:\Game\app.exe'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$Seconds = 8
)

if (-not (Test-Path -LiteralPath $Path)) { throw "找不到文件: $Path" }
$Path = (Resolve-Path -LiteralPath $Path).Path

# ---- 先确认位数 ----
$fs = [System.IO.File]::OpenRead($Path)
try {
    $br = New-Object System.IO.BinaryReader($fs)
    $fs.Position = 0x3C
    $peOff = $br.ReadInt32()
    $fs.Position = $peOff + 4
    $machine = $br.ReadUInt16()
} finally { $br.Close(); $fs.Close() }

switch ($machine) {
    0x014C { $arch = 'x86' }
    0x8664 { $arch = 'x64' }
    0xAA64 { $arch = 'ARM64' }
    default { $arch = ('0x{0:X4}' -f $machine) }
}
Write-Host ("目标 : {0}" -f $Path)
Write-Host ("架构 : {0}" -f $arch)
if ($machine -ne 0x014C) {
    Write-Warning '本脚本只对 32 位(x86) 程序有意义：64 位程序不经过 WOW64 加载器。'
}

if (-not ('Pe32LoaderProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class Pe32LoaderProbe
{
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern bool CreateProcessW(string app, string cmd, IntPtr pa, IntPtr ta, bool inherit,
        uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll")] static extern bool WaitForDebugEvent(IntPtr ev, uint ms);
    [DllImport("kernel32.dll")] static extern bool ContinueDebugEvent(uint pid, uint tid, uint status);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h, uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualQueryEx(IntPtr hp, IntPtr addr, byte[] mbi, IntPtr len);
    [DllImport("psapi.dll")] static extern bool EnumProcessModulesEx(IntPtr hp, IntPtr[] mods, int cb, out int needed, uint filter);
    [DllImport("psapi.dll", CharSet=CharSet.Unicode)] static extern uint GetModuleFileNameExW(IntPtr hp, IntPtr mod, StringBuilder sb, int n);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct STARTUPINFO { public int cb; public string r, d, t; public int x,y,xs,ys,xc,yc,fill,flags; public short show, r2, r2b; public IntPtr r3, in_, out_, err; }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public uint pid, tid; }

    // 返回: "PASS" / "LOADER" / "APP" / "ERROR:..."，并附带说明
    public static string[] Run(string exe, int seconds)
    {
        var output = new StringBuilder();
        STARTUPINFO si = new STARTUPINFO(); si.cb = Marshal.SizeOf(si);
        PROCESS_INFORMATION pi;
        if (!CreateProcessW(exe, null, IntPtr.Zero, IntPtr.Zero, false, 0x2, IntPtr.Zero,
                            System.IO.Path.GetDirectoryName(exe), ref si, out pi))
            return new string[] { "ERROR", "CreateProcess 失败: " + Marshal.GetLastWin32Error() };

        IntPtr ev = Marshal.AllocHGlobal(512);
        int waited = 0;
        string verdict = "PASS";
        bool done = false;

        while (!done && waited < seconds * 4)
        {
            if (!WaitForDebugEvent(ev, 250)) { waited++; continue; }
            int code = Marshal.ReadInt32(ev, 0);
            uint pid = (uint)Marshal.ReadInt32(ev, 4);
            uint tid = (uint)Marshal.ReadInt32(ev, 8);
            uint cont = 0x00010002;

            if (code == 1)
            {
                int u = 16;
                int exc = Marshal.ReadInt32(ev, u);
                long ip = Marshal.ReadInt64(ev, u + 16);
                int np = Marshal.ReadInt32(ev, u + 24);
                long info0 = np > 0 ? Marshal.ReadInt64(ev, u + 32) : 0;
                long info1 = np > 1 ? Marshal.ReadInt64(ev, u + 40) : 0;

                // 0x80000003 = 断点, 0x4000001F = WOW64 单步, 都不是故障
                if (exc == unchecked((int)0xC0000005))
                {
                    bool loaderStage = OnlyNativeModules(pi.hProcess);
                    verdict = loaderStage ? "LOADER" : "APP";
                    output.AppendLine(string.Format("首次访问冲突: 0x{0:X8} 指令地址 0x{1:X}", exc, ip));
                    output.AppendLine("  访问类型: " + (info0 == 0 ? "读" : info0 == 1 ? "写" : info0 == 8 ? "执行" : "0x" + info0.ToString("X")));
                    output.AppendLine(string.Format("  目标地址: 0x{0:X}", info1));
                    output.AppendLine("  已加载模块: " + ModuleList(pi.hProcess));
                    output.AppendLine("  结论: " + (loaderStage
                        ? "LOADER —— 进程还没加载 kernel32，属于 Windows 32 位加载器崩溃（用户层无法修）"
                        : "APP —— 加载器已通过，崩溃发生在程序初始化/依赖 DLL 阶段"));
                    done = true;
                    cont = 0x80010001;
                }
            }
            ContinueDebugEvent(pid, tid, cont);
        }
        TerminateProcess(pi.hProcess, 1);
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess); Marshal.FreeHGlobal(ev);

        if (!done) output.AppendLine("在 " + seconds + " 秒内没有捕获到访问冲突（进程被留在后台启动状态）。");
        return new string[] { verdict, output.ToString() };
    }

    static string ModuleList(IntPtr hp)
    {
        IntPtr[] mods = new IntPtr[512];
        int needed;
        if (!EnumProcessModulesEx(hp, mods, mods.Length * IntPtr.Size, out needed, 0x3)) return "(枚举失败)";
        int n = needed / IntPtr.Size;
        var sb = new StringBuilder();
        var seen = new System.Collections.Generic.HashSet<string>();
        int shown = 0;
        for (int i = 0; i < n && shown < 12; i++)
        {
            var name = new StringBuilder(260);
            GetModuleFileNameExW(hp, mods[i], name, 260);
            string fn = System.IO.Path.GetFileName(name.ToString());
            if (!seen.Add(fn)) continue;
            sb.Append(shown == 0 ? "" : ", ").Append(fn);
            shown++;
        }
        return n + " 个: " + sb;
    }

    static bool OnlyNativeModules(IntPtr hp)
    {
        IntPtr[] mods = new IntPtr[512];
        int needed;
        if (!EnumProcessModulesEx(hp, mods, mods.Length * IntPtr.Size, out needed, 0x3)) return false;
        int n = needed / IntPtr.Size;
        for (int i = 0; i < n; i++)
        {
            var name = new StringBuilder(260);
            GetModuleFileNameExW(hp, mods[i], name, 260);
            string f = System.IO.Path.GetFileName(name.ToString()).ToLowerInvariant();
            if (f == "kernel32.dll" || f == "kernelbase.dll" || f == "user32.dll") return false;
        }
        return true;
    }
}
'@
}

$result = [Pe32LoaderProbe]::Run($Path, $Seconds)
Write-Host ("结果 : {0}" -f $result[0]) -ForegroundColor $(if ($result[0] -eq 'LOADER') { 'Red' } elseif ($result[0] -eq 'APP') { 'Yellow' } else { 'Green' })
if ($result[1]) { Write-Host $result[1] }
