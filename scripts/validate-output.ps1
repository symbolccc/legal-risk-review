<#
.SYNOPSIS
  Validate a review result against the schema AND against the skill's own tiering rules.
.DESCRIPTION
  Two layers:
    1. Structural  - required keys, types, enumerations from schemas/review-output.schema.json
    2. Consistency - the conclusion must be derivable from the checks (SKILL.md section 4)

  Layer 2 catches the bug class where a result contains an uncertain check yet still claims
  confidence: high. A plain schema check is blind to that contradiction.

  Zero external dependencies; runs on Windows PowerShell 5.1 and pwsh 7.
  Keep this file pure ASCII: CJK enum values are loaded from the schema file instead of
  being hard-coded, because 5.1 reads BOM-less UTF-8 scripts as ANSI.
.PARAMETER InputPath
  Path to a review result JSON file, or '-' to read JSON from stdin.
.PARAMETER SchemaPath
  Optional override for the schema location.
.OUTPUT
  Violation list. Exit 0 = clean, 1 = file or parse error, 2 = violations found.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPath,
    [string]$SchemaPath
)

$ErrorActionPreference = 'Stop'

if (-not $SchemaPath) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $SchemaPath = Join-Path $repoRoot 'schemas\review-output.schema.json'
}
if (-not (Test-Path -LiteralPath $SchemaPath)) {
    Write-Output ('SCHEMA_NOT_FOUND ' + $SchemaPath); exit 1
}

function Read-Utf8([string]$p) {
    return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}

try { $schema = (Read-Utf8 $SchemaPath) | ConvertFrom-Json }
catch { Write-Output ('SCHEMA_PARSE_ERROR ' + $_.Exception.Message); exit 1 }

$jsonText = if ($InputPath -eq '-') { [Console]::In.ReadToEnd() } else { Read-Utf8 $InputPath }
if ([string]::IsNullOrWhiteSpace($jsonText)) { Write-Output 'EMPTY_INPUT'; exit 1 }
try { $obj = $jsonText | ConvertFrom-Json }
catch { Write-Output ('JSON_PARSE_ERROR ' + $_.Exception.Message); exit 1 }

# CJK enum values come from the schema, in declared order.
$overallEnum   = @($schema.properties.overall_result.enum)
$RESULT_PASS   = $overallEnum[0]
$RESULT_FAIL   = $overallEnum[1]
$RESULT_MANUAL = $overallEnum[2]
$CONF_ENUM = @($schema.properties.confidence.enum)
$EVID_ENUM = @($schema.properties.checks.items.properties.evidence_source.enum)

$v = @()
# A helper writing to $global:v would mutate a different variable than the one the
# summary reads, silently discarding every violation. Scope must match.
function Add-V([string]$m) { $script:v += $m }

foreach ($req in @($schema.required)) {
    if ($obj.PSObject.Properties.Name -notcontains $req) { Add-V ('missing required key: ' + $req) }
}
if ([string]::IsNullOrWhiteSpace([string]$obj.case_id)) { Add-V 'case_id is empty - every result must bind to one document' }
if ($overallEnum -notcontains $obj.overall_result) { Add-V ('overall_result not in enum: ' + [string]$obj.overall_result) }
if ($CONF_ENUM -notcontains $obj.confidence) { Add-V ('confidence not in enum: ' + [string]$obj.confidence) }
if ([string]::IsNullOrWhiteSpace([string]$obj.approval_comment)) { Add-V 'approval_comment is empty' }
if ($null -eq $obj.checks -or @($obj.checks).Count -lt 1) { Add-V 'checks must contain at least one item' }

$checks = @($obj.checks)
$nFail = 0; $nUnc = 0; $nPass = 0; $nNa = 0
for ($i = 0; $i -lt $checks.Count; $i++) {
    $c = $checks[$i]
    $tag = 'checks[' + $i + ']'
    if ($c.PSObject.Properties.Name -notcontains 'check_id') { Add-V ($tag + '.check_id missing') }
    if ($c.PSObject.Properties.Name -notcontains 'field')    { Add-V ($tag + '.field missing') }
    if ([string]::IsNullOrWhiteSpace([string]$c.reason))     { Add-V ($tag + '.reason empty - a verdict without a reason is unauditable') }
    switch ([string]$c.result) {
        'fail'           { $nFail++ }
        'uncertain'      { $nUnc++ }
        'pass'           { $nPass++ }
        'not_applicable' { $nNa++ }
        default          { Add-V ($tag + '.result not in enum: ' + [string]$c.result) }
    }
    if ($c.PSObject.Properties.Name -contains 'evidence_source') {
        if ($EVID_ENUM -notcontains [string]$c.evidence_source) {
            Add-V ($tag + '.evidence_source not in enum: ' + [string]$c.evidence_source)
        }
    }
    if ($c.PSObject.Properties.Name -notcontains 'requires_human_review') {
        Add-V ($tag + '.requires_human_review missing')
    }
    elseif ($c.result -eq 'uncertain' -and $c.requires_human_review -ne $true) {
        Add-V ($tag + ' is uncertain but requires_human_review is not true')
    }
}

$expected = $RESULT_PASS
if ($nFail -gt 0) { $expected = $RESULT_FAIL }
elseif ($nUnc -gt 0) { $expected = $RESULT_MANUAL }

if ($overallEnum -contains $obj.overall_result -and $obj.overall_result -ne $expected) {
    Add-V ('tiering conflict: fail=' + $nFail + ' uncertain=' + $nUnc + ' implies ' + $expected + ' but got ' + [string]$obj.overall_result)
}
if ($nUnc -gt 0 -and $obj.confidence -eq 'high') {
    Add-V ('confidence=high with ' + $nUnc + ' uncertain check(s); any uncertain forces low')
}
if ($obj.overall_result -eq $RESULT_PASS) {
    if (@($obj.issues).Count -gt 0) { Add-V 'overall=pass but issues is non-empty' }
    if (($nFail + $nUnc) -gt 0)     { Add-V 'overall=pass but not every check is pass or not_applicable' }
}
if ($nFail -gt 0 -and @($obj.issues).Count -eq 0) {
    Add-V 'fail checks exist but issues is empty - every defect must be named'
}

Write-Output ('case_id=' + [string]$obj.case_id)
Write-Output ('checks=' + $checks.Count + ' pass=' + $nPass + ' fail=' + $nFail + ' uncertain=' + $nUnc + ' na=' + $nNa)
Write-Output ('overall=' + [string]$obj.overall_result + ' confidence=' + [string]$obj.confidence)
if ($v.Count -eq 0) {
    Write-Output 'VALIDATION=PASS'
    exit 0
}
Write-Output 'VALIDATION=FAIL'
foreach ($m in $v) { Write-Output ('  VIOLATION: ' + $m) }
Write-Output ('violations=' + $v.Count)
exit 2
