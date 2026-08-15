[CmdletBinding()]
param(
    [string]$ProjectPath,
    [string]$ModDirectory
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Split-Path -Parent $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($ModDirectory)) {
    $ModDirectory = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Paradox Interactive\Europa Universalis IV\mod'
}

$resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$linkPath = Join-Path $ModDirectory 'sixteen_kingdoms_dev'
$descriptorPath = Join-Path $ModDirectory 'sixteen_kingdoms_dev.mod'

New-Item -ItemType Directory -Path $ModDirectory -Force | Out-Null

if (Test-Path -LiteralPath $linkPath) {
    $existingLink = Get-Item -Force -LiteralPath $linkPath
    $existingTarget = @($existingLink.Target)[0]
    if ($existingLink.LinkType -ne 'Junction' -or $existingTarget -ne $resolvedProjectPath) {
        throw "目标已存在且不是指向本项目的目录联接：$linkPath"
    }
} else {
    New-Item -ItemType Junction -Path $linkPath -Target $resolvedProjectPath | Out-Null
}

$launcherPath = $linkPath.Replace('\', '/')
$descriptor = @"
version="0.1.0"
tags={
    "Alternative History"
    "Historical"
    "Gameplay"
}
dependencies={
    "Chinese Language Mod for 1.37"
    "Chinese Language Supplementary Mod for 1.37"
}
name="东晋十六国"
supported_version="1.37.*"
path="$launcherPath"
"@

[System.IO.File]::WriteAllText($descriptorPath, $descriptor, [System.Text.UTF8Encoding]::new($false))

Write-Host "开发目录联接：$linkPath -> $resolvedProjectPath"
Write-Host "启动器描述文件：$descriptorPath"
