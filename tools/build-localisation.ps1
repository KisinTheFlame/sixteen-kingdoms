[CmdletBinding()]
param(
    [string]$SourceDirectory,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot

# EU4SpecialEscape，采用 EU4 1.26+ 规则和 UTF-8 输出模式。
$internalCharacters = @(
    0x00, 0x0A, 0x0D, 0x20, 0x22, 0x24, 0x40, 0x5B, 0x5C,
    0x7B, 0x7D, 0x7E, 0x80, 0xA3, 0xA4, 0xA7, 0xBD,
    0x3B, 0x5D, 0x5F, 0x3D, 0x23, 0x2F
)

$cp1252ToUnicode = @{
    0x80 = 0x20AC; 0x82 = 0x201A; 0x83 = 0x0192; 0x84 = 0x201E
    0x85 = 0x2026; 0x86 = 0x2020; 0x87 = 0x2021; 0x88 = 0x02C6
    0x89 = 0x2030; 0x8A = 0x0160; 0x8B = 0x2039; 0x8C = 0x0152
    0x8E = 0x017D; 0x91 = 0x2018; 0x92 = 0x2019; 0x93 = 0x201C
    0x94 = 0x201D; 0x95 = 0x2022; 0x96 = 0x2013; 0x97 = 0x2014
    0x98 = 0x02DC; 0x99 = 0x2122; 0x9A = 0x0161; 0x9B = 0x203A
    0x9C = 0x0153; 0x9E = 0x017E; 0x9F = 0x0178
}

function Convert-Cp1252ByteToUnicode {
    param([int]$Value)
    if ($cp1252ToUnicode.ContainsKey($Value)) {
        return [int]$cp1252ToUnicode[$Value]
    }
    return $Value
}

function Convert-ToEu4SpecialEscape {
    param([Parameter(Mandatory)] [string]$Text)

    $result = [System.Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        $codePoint = [int]$character
        if ($codePoint -lt 256) {
            [void]$result.Append($character)
            continue
        }
        if ([char]::IsSurrogate($character)) {
            throw ('汉化字体编码暂不支持基本多文种平面之外的字符：U+{0:X4}' -f $codePoint)
        }

        $low = $codePoint -band 0xFF
        $high = ($codePoint -shr 8) -band 0xFF
        $escapeCharacter = 0x10

        if ($internalCharacters -contains $high) { $escapeCharacter += 2 }
        if ($internalCharacters -contains $low) { $escapeCharacter += 1 }

        switch ($escapeCharacter) {
            0x11 { $low += 14 }
            0x12 { $high -= 9 }
            0x13 {
                $low += 14
                $high -= 9
            }
        }

        $low = Convert-Cp1252ByteToUnicode $low
        $high = Convert-Cp1252ByteToUnicode $high
        [void]$result.Append([char]$escapeCharacter)
        [void]$result.Append([char]$low)
        [void]$result.Append([char]$high)
    }
    return $result.ToString()
}

function Assert-EscapeBytes {
    param(
        [string]$InputText,
        [string]$ExpectedHex
    )
    $escaped = Convert-ToEu4SpecialEscape $InputText
    $actualHex = ([System.Text.Encoding]::UTF8.GetBytes($escaped) | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
    if ($actualHex -ne $ExpectedHex) {
        throw "编码自检失败：$InputText，预期 $ExpectedHex，实际 $actualHex"
    }
}

Assert-EscapeBytes '君' '10 1B 54'
Assert-EscapeBytes '王' '10 E2 80 B9 73'
Assert-EscapeBytes ([string][char]0x4E20) '11 2E 4E'
Assert-EscapeBytes ([string][char]0x20AC) '12 C2 AC 17'
Assert-EscapeBytes ([string][char]0x2020) '13 2E 17'

if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
    $SourceDirectory = Join-Path $projectPath 'localisation_source'
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectPath 'localisation'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$sourceFiles = @(Get-ChildItem -LiteralPath $SourceDirectory -Filter '*_l_english.yml' -File)
if ($sourceFiles.Count -eq 0) {
    throw "没有找到中文本地化源码：$SourceDirectory"
}

foreach ($sourceFile in $sourceFiles) {
    $text = [System.IO.File]::ReadAllText($sourceFile.FullName, [System.Text.Encoding]::UTF8)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    if ($text -notmatch '^l_english:\r?\n') {
        throw "本地化文件缺少 l_english 头：$($sourceFile.FullName)"
    }

    $outputPath = Join-Path $OutputDirectory $sourceFile.Name
    $escapedText = Convert-ToEu4SpecialEscape $text
    [System.IO.File]::WriteAllText($outputPath, $escapedText, [System.Text.UTF8Encoding]::new($true))
    Write-Output "已编译中文本地化：$outputPath"
}
