<#
.SYNOPSIS
  Structure validator for payment-term / risk opinion documents (prose, not JSON).
.DESCRIPTION
  The legal skill's deliverable is a Chinese document, so a JSON envelope contract does
  not apply. This checks the things that actually break in practice:

    - required sections present (no silently dropped paragraph)
    - the conclusion states term days, whether advance payment is involved, and the
      objection verdict - all three, per SKILL.md 2.1
    - a penetration calculation is shown, not just asserted
    - when evidence is missing, the conclusion is not a bare "no objection"
    - no credentials in the document

  Section names live in opinion-requirements.json so this file stays pure ASCII.
.PARAMETER InputPath
  Path to the document (.md or .txt).
.OUTPUT
  Exit 0 = structurally sound, 2 = violations, 1 = read/parse error.
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

$req = ([System.IO.File]::ReadAllText($reqPath, [System.Text.Encoding]::UTF8)) | ConvertFrom-Json
$doc = [System.IO.File]::ReadAllText($InputPath, [System.Text.Encoding]::UTF8)

$v = @()
function Add-V([string]$m) { $script:v += $m }

# 1. required sections
foreach ($s in @($req.required_sections)) {
    if ($doc -notlike ('*' + $s + '*')) { Add-V ('missing required section: ' + $s) }
}

# 2. conclusion must state the three things. Scope to the conclusion paragraph so a stray
    # number elsewhere in the document cannot satisfy the check.
$idx = $doc.IndexOf([string]$req.required_sections[-1])
$conclusion = if ($idx -ge 0) { $doc.Substring($idx) } else { $doc }
foreach ($need in @($req.conclusion_must_contain_any)) {
    $hit = $false
    foreach ($p in @($need.patterns)) { if ($conclusion -match $p) { $hit = $true; break } }
    if (-not $hit) { Add-V ('conclusion does not state: ' + $need.label) }
}

# 3. penetration calculation must be shown, not asserted
$segTerms = @($req.penetration_proof_patterns)
$foundTerms = @($segTerms | Where-Object { $doc -like ('*' + $_ + '*') })
if ($foundTerms.Count -lt 2) {
    Add-V ('no penetration breakdown shown (found ' + $foundTerms.Count + ' of ' + $segTerms.Count +
           ' term components); a bare day count is not an audit trail')
}
# The arithmetic lives in the term table, not in the closing paragraph, so the equality
# check is scoped to the whole document. Restricting it to the conclusion produced
# false failures on correctly structured opinions.
# Alternation, not concatenation: either halfwidth or fullwidth equals counts.
# Fullwidth U+FF1D is built from its code point so this file stays pure ASCII.
$eqPattern = '=|' + [string][char]0xFF1D
if ($req.penetration_requires_equals -and $doc -notmatch $eqPattern) {
    Add-V 'a term is stated but no arithmetic expression produces it anywhere in the document'
}

# 4. missing evidence must not coexist with a bare clean verdict
$hasGap = $false
foreach ($g in @($req.gap_markers)) { if ($doc -match $g) { $hasGap = $true; break } }
if ($hasGap -and $conclusion -match [string]$req.clean_verdict_pattern) {
    $flagged = $false
    foreach ($p in @($req.gap_flag_patterns)) {
        if ($conclusion -match $p) { $flagged = $true; break }
    }
    if (-not $flagged) {
        Add-V 'evidence gaps exist but the conclusion claims a clean verdict without flagging them'
    }
}

# 5. credentials must never appear
foreach ($fp in @($req.forbidden_patterns)) {
    if ($doc -match $fp) { Add-V ('document contains a credential-like pattern: ' + $fp) }
}

Write-Output ('file=' + (Split-Path -Leaf $InputPath))
Write-Output ('chars=' + $doc.Length + ' sections_found=' +
    (@($req.required_sections | Where-Object { $doc -like ('*' + $_ + '*') }).Count) + '/' +
    @($req.required_sections).Count)
if ($v.Count -eq 0) { Write-Output 'OPINION=PASS'; exit 0 }
Write-Output 'OPINION=FAIL'
foreach ($m in $v) { Write-Output ('  VIOLATION: ' + $m) }
Write-Output ('violations=' + $v.Count)
exit 2
