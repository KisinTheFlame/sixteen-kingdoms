[CmdletBinding()]
param([string]$ProjectPath)

$ErrorActionPreference = 'Stop'
$ProjectPath = if ([string]::IsNullOrWhiteSpace($ProjectPath)) { Split-Path -Parent $PSScriptRoot } else { $ProjectPath }
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([string]$Message)
    $script:errors.Add($Message)
}

$requiredDirectories = @(
    'common', 'decisions', 'docs', 'events', 'gfx\flags', 'history\countries',
    'history\diplomacy', 'history\provinces', 'history\wars', 'localisation',
    'localisation_source', 'missions', 'tools'
)
foreach ($directory in $requiredDirectories) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath $directory) -PathType Container)) {
        Add-ValidationError "缺少目录：$directory"
    }
}

$descriptorPath = Join-Path $ProjectPath 'descriptor.mod'
if (-not (Test-Path -LiteralPath $descriptorPath -PathType Leaf)) {
    Add-ValidationError '缺少 descriptor.mod'
} else {
    $descriptor = Get-Content -Raw -LiteralPath $descriptorPath
    foreach ($field in @('name', 'version', 'supported_version')) {
        if ($descriptor -notmatch ('(?m)^' + $field + '="[^"]+"')) {
            Add-ValidationError "descriptor.mod 缺少字段：$field"
        }
    }
}

$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'localisation_source') -Filter '*_l_english.yml' -File)
if ($sourceFiles.Count -eq 0) {
    Add-ValidationError '缺少中文本地化源码'
}

$allKeys = [System.Collections.Generic.List[string]]::new()
foreach ($sourceFile in $sourceFiles) {
    $sourceText = [System.IO.File]::ReadAllText($sourceFile.FullName, [System.Text.Encoding]::UTF8)
    if ($sourceText.TrimStart([char]0xFEFF) -notmatch '^l_english:\r?\n') {
        Add-ValidationError "本地化源码缺少 l_english 头：$($sourceFile.Name)"
    }
    foreach ($line in ($sourceText -split "`r?`n")) {
        if ($line -match '^\s+([A-Za-z0-9_.-]+):\d+\s+') {
            $allKeys.Add($Matches[1])
        }
    }

    $runtimePath = Join-Path (Join-Path $ProjectPath 'localisation') $sourceFile.Name
    if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
        Add-ValidationError "缺少运行时本地化：$($sourceFile.Name)"
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($runtimePath)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        Add-ValidationError "运行时本地化缺少 UTF-8 BOM：$($sourceFile.Name)"
    }
}

$duplicateKeys = @($allKeys | Group-Object | Where-Object Count -gt 1)
foreach ($duplicate in $duplicateKeys) {
    Add-ValidationError "本地化键重复：$($duplicate.Name)"
}

$scriptFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'common') -Recurse -Filter '*.txt' -File
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'decisions') -Recurse -Filter '*.txt' -File
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'events') -Recurse -Filter '*.txt' -File
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'history') -Recurse -Filter '*.txt' -File
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'missions') -Recurse -Filter '*.txt' -File
)
foreach ($file in $scriptFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $withoutComments = $text -replace '(?m)#.*$', ''
    $openBraces = ([regex]::Matches($withoutComments, '\{')).Count
    $closeBraces = ([regex]::Matches($withoutComments, '\}')).Count
    if ($openBraces -ne $closeBraces) {
        Add-ValidationError "花括号不平衡：$($file.FullName)（$openBraces / $closeBraces）"
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "模组静态校验失败：$($errors.Count) 项"
}

Write-Output "静态校验通过：$($requiredDirectories.Count) 个必需目录，$($sourceFiles.Count) 个本地化文件，$($scriptFiles.Count) 个脚本文件。"
