<#
.SYNOPSIS
  Credential and private-data scanner for CI and pre-push use.
.DESCRIPTION
  Prints pattern names and locations only. Never echoes a matched value, because the
  scan log itself could otherwise leak the secret it is looking for.
  Keep this file pure ASCII.
.OUTPUT
  Exit 0 = clean, 1 = findings.
#>
[CmdletBinding()]
param(
    [string]$Path
)

$ErrorActionPreference = 'Stop'
if (-not $Path) { $Path = Split-Path -Parent $PSScriptRoot }

$patterns = [ordered]@{
    'GitHub token'          = 'gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{16,}'
    'sk-style API key'      = 'sk-[A-Za-z0-9]{16,}'
    'Private key block'     = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    'AWS access key id'     = 'AKIA[0-9A-Z]{12,}'
    'Bearer token'          = '(?i)bearer\s+[A-Za-z0-9\-_\.]{20,}'
    'Credential assignment' = '(?i)(password|passwd|pwd|secret|api[_-]?key|access[_-]?token|cookie)\s*[:=]\s*["'']?[^\s"''@]{6,}'
    'JWT'                   = 'eyJ[A-Za-z0-9_\-]{12,}\.eyJ[A-Za-z0-9_\-]{12,}'
    'Feishu app secret'     = '(?i)(app_secret|tenant_token|verification_token)\s*[:=]'
    'CN ID card number'     = '\b\d{17}[\dXx]\b'
    'Bank-card-like digits' = '\b\d{16,19}\b'
    'Local absolute path'   = '[A-Za-z]:\\\\Users\\\\|/Users/[a-z0-9_]+/'
    'Internal hostname'     = '(?i)inly[a-z0-9.\-]*|yinlimedia|\.feishu\.cn'
    'Private repo name'     = 'my-ai-memory'
}

$myLeaf = [System.IO.Path]::GetFileName($PSCommandPath)
$files = Get-ChildItem -LiteralPath $Path -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch '\\\.git\\' -and
        # The scanner's own pattern list contains every string it looks for.
        $_.Name -ne $myLeaf
    }

$hits = 0
foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $lines = $text -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($name in $patterns.Keys) {
            if ($lines[$i] -match $patterns[$name]) {
                $rel = $file.FullName.Substring($Path.Length).TrimStart('\','/')
                Write-Output ('FINDING  ' + $rel + ':' + ($i + 1) + '  ' + $name)
                $hits++
            }
        }
    }
}
Write-Output ('files_scanned=' + $files.Count + ' findings=' + $hits)
if ($hits -gt 0) { Write-Output 'SCAN=FAIL'; exit 1 }
Write-Output 'SCAN=PASS'
exit 0
