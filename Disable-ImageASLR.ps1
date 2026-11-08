<#
    NoASLR32 Toolkit
    Copyright (c) 2026 震东1(zhendong1)  ·  MIT License
    https://github.com/zhendong1/NoASLR32-Toolkit
    保留本段版权信息即可自由使用、修改、再分发。
#>

<#
.SYNOPSIS
    系统级关闭"镜像随机化(ASLR)"/恢复默认。

.DESCRIPTION
    等价于给全机器所有程序打上本工具包的补丁：不再对 EXE/DLL 做基址重定位，
    因此 26H2 加载器的那个缺陷不会被触发。适合"中招的程序太多、懒得逐个改"的情况。

    代价：整机失去 ASLR 保护（安全性下降），且需要重启才生效。
    改的是 HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\MoveImages
      - 0           = 关闭镜像随机化
      - 删除该值     = 恢复系统默认

    需要管理员权限。

.PARAMETER Undo
    删除 MoveImages 值，恢复系统默认行为（同样需要重启）。

.EXAMPLE
    .\Disable-ImageASLR.ps1

.EXAMPLE
    .\Disable-ImageASLR.ps1 -Undo
#>
[CmdletBinding()]
param(
    [switch]$Undo
)

$ErrorActionPreference = 'Stop'
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
$name = 'MoveImages'

# --- 管理员检查 ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '需要管理员权限。请右键 PowerShell 选择“以管理员身份运行”，或在本窗口执行：' -ForegroundColor Red
    Write-Host ('  Start-Process powershell -Verb RunAs -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -File "{0}"''' -f $PSCommandPath) -ForegroundColor Yellow
    exit 1
}

function Get-Current {
    $v = Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $v) { return $null }
    return $v.$name
}

$before = Get-Current

if ($Undo) {
    if ($null -eq $before) {
        Write-Host '当前没有 MoveImages 值，本来就是系统默认，无需恢复。' -ForegroundColor Yellow
        return
    }
    Remove-ItemProperty -Path $key -Name $name -Force
    Write-Host ('已删除 MoveImages（原值 0x{0:X}）' -f $before) -ForegroundColor Green
    Write-Host '重启后生效。' -ForegroundColor Green
    return
}

# 先备份原值到桌面
$backupFile = Join-Path ([Environment]::GetFolderPath('Desktop')) 'MoveImages-backup.txt'
$line = if ($null -eq $before) { 'MoveImages 原本不存在（系统默认）' } else { ('MoveImages 原值: 0x{0:X}' -f $before) }
Set-Content -LiteralPath $backupFile -Value $line -Encoding UTF8

New-ItemProperty -Path $key -Name $name -PropertyType DWord -Value 0 -Force | Out-Null

$after = Get-Current
Write-Host ('MoveImages: {0} -> 0x{1:X}' -f $(if ($null -eq $before) { '不存在' } else { ('0x{0:X}' -f $before) }), $after) -ForegroundColor Green
Write-Host ('原值已备份到: {0}' -f $backupFile)
Write-Host '重启后生效。恢复：.\Disable-ImageASLR.ps1 -Undo' -ForegroundColor Yellow
