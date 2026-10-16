<#
.SYNOPSIS
  Structure validator for prose deliverables, profile-aware.
.DESCRIPTION
  Three document types share one checker: payment-term opinions, settlement reviews and
  seal/archiving records. A document picks its profile with a marker line:

      <!-- profile: settlement -->

  Missing marker falls back to default_profile. Requirements (including all CJK strings)
  live in opinion-requirements.json so this file stays pure ASCII - Windows PowerShell
  5.1 reads BOM-less UTF-8 scripts as ANSI and corrupts non-ASCII literals.

  What it catches that a model reviewing its own output does not:
    - a silently dropped section
    - a conclusion missing one of its required elements
    - a computed figure asserted without the calculation behind it
    - evidence gaps coexisting with a clean verdict
    - credentials pasted into the document
.PARAMETER InputPath
  Path to the document.
.OUTPUT
  Exit 0 = sound, 2 = violations, 1 = read/config error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$reqPath = Join-Path $PSScriptRoot 'opinion-requirements.json'
if (-not (Test-Path -LiteralPath $reqPath)) { Write-Output 'REQUIREMENTS_NOT_FOUND'; exit 1 }
if (-not (Test-Path -LiteralPath $InputPath)) { Write-Output ('FILE_NOT_FOUND ' + $InputPath); exit 1 }

$cfg = ([System.IO.File]::ReadAllText($reqPath, [System.Text.Encoding]::UTF8)) | ConvertFrom-Json
$doc = [System.IO.File]::ReadAllText($InputPath, [System.Text.Encoding]::UTF8)

$pm = [regex]::Match($doc, '<!--\s*profile:\s*([A-Za-z0-9\-]+)\s*-->')
$profileName = if ($pm.Success) { $pm.Groups[1].Value } else { [string]$cfg.default_profile }
if (-not $cfg.profiles.PSObject.Properties.Name -contains $profileName) {
    Write-Output ('UNKNOWN_PROFILE ' + $profileName)
    exit 1
}
$p = $cfg.profiles.$profileName
$sh = $cfg.shared

$v = @()
function Add-V([string]$m) { $script:v += $m }

# 1. required sections
foreach ($s in @($p.required_sections)) {
    if ($doc -notlike ('*' + $s + '*')) { Add-V ('missing required section: ' + $s) }
}

# 2. conclusion elements, scoped to the paragraph after the anchor
$anchor = [string]$p.conclusion_anchor
$idx = if ($anchor) { $doc.IndexOf($anchor) } else { -1 }
$conclusion = if ($idx -ge 0) { $doc.Substring($idx) } else { $doc }
foreach ($need in @($p.conclusion_must_contain_any)) {
    $hit = $false
    foreach ($pat in @($need.patterns)) { if ($conclusion -match $pat) { $hit = $true; break } }
    if (-not $hit) { Add-V ('conclusion does not state: ' + $need.label) }
}

# 3. a computed figure must show its components, not just the result
# NOTE: @($null).Count is 1, so testing a missing property with @(...).Count -gt 0 is
# always true and silently produced a single-element list of $null (which matched
# everything). Check property existence on the object instead.
$names = $p.PSObject.Properties.Name
$terms = @()
if ($names -contains 'penetration_terms') { $terms = @($p.penetration_terms) }
elseif ($names -contains 'check_terms')   { $terms = @($p.check_terms) }
$terms = @($terms | Where-Object { $_ })
if ($terms.Count -gt 0) {
    $min = 2
    if ($names -contains 'penetration_min_terms') { $min = [int]$p.penetration_min_terms }
    if ($names -contains 'check_min_terms')       { $min = [int]$p.check_min_terms }
    $found = @($terms | Where-Object { $doc -like ('*' + $_ + '*') })
    if ($found.Count -lt $min) {
        Add-V ('only ' + $found.Count + ' of required ' + $min +
               ' checklist/calculation components present - a verdict without its audit trail')
    }
}

# 4. arithmetic behind the figure (payment-term only)
if ($p.require_equals) {
    # Alternation of halfwidth and fullwidth equals. U+FF1D built from code point for ASCII-only source.
    $eqPattern = '=|' + [string][char]0xFF1D
    if ($doc -notmatch $eqPattern) {
        Add-V 'a figure is stated but no arithmetic expression produces it anywhere in the document'
    }
}

# 5. defects must be named one by one, never summarised as "incomplete"
if ($p.must_name_each_defect) {
    # CJK phrases come from config: a non-ASCII literal in this file is corrupted by
    # PowerShell 5.1's ANSI reading of BOM-less UTF-8 and would never match.
    # Scope both halves to the conclusion. A document may legitimately use semicolons in a
    # checklist paragraph while still waving defects away vaguely in its verdict.
    $vague = $false
    foreach ($vp in @($sh.vague_defect_patterns)) { if ($conclusion -match $vp) { $vague = $true; break } }
    if ($vague -and $conclusion -notmatch [string]$sh.enumerated_defect_pattern) {
        Add-V 'defects summarised as a generic phrase instead of listed one by one'
    }
}

# 6. evidence gaps must not coexist with a bare clean verdict
$hasGap = $false
foreach ($g in @($sh.gap_markers)) { if ($doc -match $g) { $hasGap = $true; break } }
if ($hasGap -and $conclusion -match [string]$sh.clean_verdict_pattern) {
    $flagged = $false
    foreach ($fp in @($sh.gap_flag_patterns)) { if ($conclusion -match $fp) { $flagged = $true; break } }
    if (-not $flagged) {
        Add-V 'evidence gaps exist but the conclusion claims a clean verdict without flagging them'
    }
}

# 7. credentials must never appear
foreach ($fp in @($sh.forbidden_patterns)) {
    if ($doc -match $fp) { Add-V ('document contains a credential-like pattern: ' + $fp) }
}

Write-Output ('file=' + (Split-Path -Leaf $InputPath) + ' profile=' + $profileName)
$present = @($p.required_sections | Where-Object { $doc -like ('*' + $_ + '*') }).Count
Write-Output ('chars=' + $doc.Length + ' sections=' + $present + '/' + @($p.required_sections).Count)
if ($v.Count -eq 0) { Write-Output 'OPINION=PASS'; exit 0 }
Write-Output 'OPINION=FAIL'
foreach ($m in $v) { Write-Output ('  VIOLATION: ' + $m) }
Write-Output ('violations=' + $v.Count)
exit 2
