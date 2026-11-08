<#
    NoASLR32 Toolkit
    Copyright (c) 2026 震东1(zhendong1)  ·  MIT License
    https://github.com/zhendong1/NoASLR32-Toolkit
    保留本段版权信息即可自由使用、修改、再分发。
#>

<#
.SYNOPSIS
    修复 Windows 11 26H2(Build 26300) 上特定 32 位程序启动即 0xC0000005 的问题。

.DESCRIPTION
    原理：该版本加载器在处理被 ASLR 重定位的 32 位镜像时会写坏地址（详见教程）。
    把目标 EXE 的 PE 可选头里 IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE(0x40) 位清掉，
    系统就会把它加载到首选基址、不再重定位，崩溃消失。

    修改前会自动备份为 <文件名>.orig-nosaslr，可随时用 -Restore 还原。

.PARAMETER Path
    要处理的 EXE 文件，或者包含 EXE 的目录。

.PARAMETER Recurse
    当 Path 是目录时，递归处理子目录。

.PARAMETER DryRun
    只报告会做什么，不写任何文件。

.PARAMETER Restore
    从 <文件名>.orig-nosaslr 还原（会同时把 DllCharacteristics 位复原）。

.EXAMPLE
    .\Fix-PE32-ASLR.ps1 -Path 'D:\OMSI2\OMSI 2\openOMSI\omsi-plugin-host32.exe'

.EXAMPLE
    .\Fix-PE32-ASLR.ps1 -Path 'D:\game' -Recurse -DryRun

.EXAMPLE
    .\Fix-PE32-ASLR.ps1 -Path 'D:\game\app.exe' -Restore
#>
[CmdletBinding(DefaultParameterSetName = 'Fix')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(ParameterSetName = 'Fix')]
    [switch]$Recurse,

    [Parameter(ParameterSetName = 'Fix')]
    [switch]$DryRun,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [switch]$Restore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BACKUP_SUFFIX = '.orig-nosaslr'
$DYNAMIC_BASE  = 0x0040

function Get-Targets {
    param([string]$p, [bool]$rec)
    if (Test-Path -LiteralPath $p -PathType Leaf) { return @(Get-Item -LiteralPath $p) }
    if (-not (Test-Path -LiteralPath $p -PathType Container)) { throw "路径不存在: $p" }
    $gci = @{ LiteralPath = $p; Filter = '*.exe'; File = $true }
    if ($rec) { $gci.Recurse = $true }
    return @(Get-ChildItem @gci)
}

function Read-PeInfo {
    param([string]$file)
    $fs = [System.IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
    try {
        $br = New-Object System.IO.BinaryReader($fs)
        if ($fs.Length -lt 0x40) { throw '文件太小，不是 PE' }
        $fs.Position = 0x3C
        $peOff = $br.ReadInt32()
        if ($peOff -le 0 -or ($peOff + 0x18) -ge $fs.Length) { throw '不是有效的 PE 文件' }
        $fs.Position = $peOff + 4
        $machine = $br.ReadUInt16()
        $fs.Position = $peOff + 24 + 70
        $dllChar = $br.ReadUInt16()
    } finally { $br.Close(); $fs.Close() }
    [pscustomobject]@{
        Machine   = $machine
        DllChar   = $dllChar
        IsX86     = ($machine -eq 0x014C)
        HasASLR   = (($dllChar -band $DYNAMIC_BASE) -ne 0)
    }
}

function Update-DllCharacteristics {
    param([string]$file, [UInt16]$newValue, [UInt16]$exceptValue = 0xFFFF)
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $peOff = [BitConverter]::ToInt32($bytes, 0x3C)
    $opt = $peOff + 24
    $cur = [BitConverter]::ToUInt16($bytes, $opt + 70)
    if ($cur -eq $exceptValue) { return $false }
    $bytes[$opt + 70] = [byte]($newValue -band 0xFF)
    $bytes[$opt + 71] = [byte](($newValue -shr 8) -band 0xFF)
    [System.IO.File]::WriteAllBytes($file, $bytes)
    return $true
}

# ---------------------------------------------------------------- 主流程
$targets = @(Get-Targets -p $Path -rec ([bool]$Recurse))
if (@($targets).Count -eq 0) { Write-Warning '没有找到 .exe 文件'; return }

$rows = @()

foreach ($f in $targets) {
    $row = [ordered]@{ File = $f.Name; 架构 = ''; 动作 = ''; 结果 = '' }
    try { $pe = Read-PeInfo -file $f.FullName }
    catch { $row.结果 = '跳过（不是有效 PE）'; $rows += [pscustomobject]$row; continue }

    $row.架构 = if ($pe.IsX86) { 'x86' } elseif ($pe.Machine -eq 0x8664) { 'x64' } else { ('0x{0:X4}' -f $pe.Machine) }

    if (-not $pe.IsX86) {
        $row.动作 = '—'
        $row.结果 = '跳过（只有 32 位程序受影响）'
        $rows += [pscustomobject]$row
        continue
    }

    $backup = $f.FullName + $BACKUP_SUFFIX

    if ($Restore) {
        if (-not (Test-Path -LiteralPath $backup)) {
            $row.动作 = '还原'
            $row.结果 = '没有备份，跳过'
        } else {
            Copy-Item -LiteralPath $backup -Destination $f.FullName -Force
            $row.动作 = '还原'
            $row.结果 = '已从备份恢复'
        }
        $rows += [pscustomobject]$row
        continue
    }

    if ($pe.HasASLR -eq $false) {
        $row.动作 = '无需处理'
        $row.结果 = ('已关闭 ASLR（DllChar=0x{0:X4}）' -f $pe.DllChar)
        $rows += [pscustomobject]$row
        continue
    }

    $newVal = [UInt16]($pe.DllChar -band (-bnot $DYNAMIC_BASE))

    if ($DryRun) {
        $row.动作 = '将修改'
        $row.结果 = ('DllChar 0x{0:X4} -> 0x{1:X4}' -f $pe.DllChar, $newVal)
        $rows += [pscustomobject]$row
        continue
    }

    if (-not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $f.FullName -Destination $backup -Force
    }
    try {
        # 处理只读属性
        $attrs = (Get-Item -LiteralPath $f.FullName).Attributes
        if ($attrs -band [IO.FileAttributes]::ReadOnly) {
            Set-ItemProperty -LiteralPath $f.FullName -Name IsReadOnly -Value $false
        }
        [void](Update-DllCharacteristics -file $f.FullName -newValue $newVal)
        $check = Read-PeInfo -file $f.FullName
        if ($check.HasASLR) { throw '写入后校验失败' }
        $row.动作 = '已修改'
        $row.结果 = ('DllChar 0x{0:X4} -> 0x{1:X4}（备份已生成）' -f $pe.DllChar, $newVal)
    } catch {
        $row.动作 = '失败'
        $row.结果 = $_.Exception.Message
    }
    $rows += [pscustomobject]$row
}

$rows | Format-Table -AutoSize -Wrap
$changed = @($rows | Where-Object { $_.动作 -eq '已修改' }).Count
$restored = @($rows | Where-Object { $_.动作 -eq '还原' -and $_.结果 -eq '已从备份恢复' }).Count
Write-Host ''
if ($Restore) { Write-Host ("还原完成：{0} 个文件" -f $restored) -ForegroundColor Green }
else { Write-Host ("完成：修改 {0} 个 / 共检查 {1} 个" -f $changed, @($rows).Count) -ForegroundColor Green }
if ($DryRun) { Write-Host '（这是 DryRun，没有写入任何文件）' -ForegroundColor Yellow }
