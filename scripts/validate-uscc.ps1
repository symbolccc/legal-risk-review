<#
.SYNOPSIS
  Unified Social Credit Code (USCC) format and check-digit validation, GB 32100-2015.
.DESCRIPTION
  Deterministic math belongs in code, not in a model. The model reads characters from
  an attachment; this script decides whether the resulting string is valid.

  Algorithm: 31-character alphabet (digits + uppercase letters, excluding I O Z S V);
  weights Wi = 3^(i-1) mod 31 for the first 17 characters;
  check index = (31 - weightedSum mod 31) mod 31.

  NOTE: keep this file pure ASCII. Windows PowerShell 5.1 reads BOM-less UTF-8 scripts
  as ANSI, which corrupts non-ASCII literals and breaks parsing.
.PARAMETER Code
  Candidate 18-character code.
.OUTPUT
  PSCustomObject: Code Valid LengthOk CharsetOk ChecksumOk Expected Actual Reason
.EXAMPLE
  ./scripts/validate-uscc.ps1 -Code 92350100M000100Y43
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [AllowEmptyString()]
    [string]$Code
)

$ErrorActionPreference = 'Stop'

# GB 32100-2015 alphabet: 31 characters, no I O Z S V.
$Charset = '0123456789ABCDEFGHJKLMNPQRTUWXY'

# Wi = 3^(i-1) mod 31, i = 1..17
$Weights = @()
$p = 1
for ($i = 0; $i -lt 17; $i++) {
    $Weights += $p
    $p = ($p * 3) % 31
}

$normalized = ($Code -replace '\s', '').ToUpper()

$out = [ordered]@{
    Code       = $normalized
    Valid      = $false
    LengthOk   = $false
    CharsetOk  = $false
    ChecksumOk = $false
    Expected   = ''
    Actual     = ''
    Reason     = ''
}

function Complete([string]$why) {
    $out.Reason = $why
    Write-Output ([pscustomobject]$out)
    if ($out.Valid) { exit 0 }
    if (-not $out.LengthOk)  { exit 1 }
    if (-not $out.CharsetOk) { exit 1 }
    exit 2
}

if ($normalized.Length -ne 18) {
    Complete ('length must be 18, got ' + $normalized.Length)
}
$out.LengthOk = $true

$chars = $normalized.ToCharArray()
$bad = @()
for ($i = 0; $i -lt 18; $i++) {
    if ($Charset.IndexOf([string]$chars[$i]) -lt 0) {
        $bad += ('pos ' + ($i + 1) + ' = ' + $chars[$i])
    }
}
if ($bad.Count -gt 0) {
    Complete ('illegal characters (I O Z S V and lowercase are not in the alphabet): ' + ($bad -join ', '))
}
$out.CharsetOk = $true

$sum = 0
for ($i = 0; $i -lt 17; $i++) {
    $sum += $Charset.IndexOf([string]$chars[$i]) * $Weights[$i]
}
$expected = [string]$Charset[((31 - ($sum % 31)) % 31)]

$out.Expected    = $expected
$out.Actual      = [string]$chars[17]
$out.ChecksumOk  = ($expected -eq [string]$chars[17])

if ($out.ChecksumOk) {
    $out.Valid = $true
    Complete 'check digit matches'
}
Complete ('check digit should be ' + $expected + ' but is ' + $out.Actual)
