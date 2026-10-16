<#
.SYNOPSIS
  Run the evaluation suite for both skills.
.DESCRIPTION
  Three guarantees, in order of importance:

    1. COUNT FLOOR. Every bucket must contain at least Min cases. An empty or missing
       directory is a hard failure, never a silent pass. This exists because a bare
       `cases/` entry in .gitignore once removed the whole golden set from CI checkouts,
       and the suite reported green while testing nothing.

    2. GOLDEN. Every case under evals/supplier and evals/legal must validate cleanly.

    3. NEGATIVE. Every case under evals/invalid must be rejected, and rejected for the
       reason recorded in _expect.must_contain. This is the test-the-tester half.
.OUTPUT
  Exit 0 = all three hold, 1 = any of them broke.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $PSScriptRoot 'validate-output.ps1'
if (-not (Test-Path -LiteralPath $validator)) { Write-Output 'VALIDATOR_NOT_FOUND'; exit 1 }

$buckets = @(
    [pscustomobject]@{ Name = 'supplier golden'; Dir = 'evals\supplier'; Min = 6; MustPass = $true  }
    [pscustomobject]@{ Name = 'legal golden';    Dir = 'evals\legal';    Min = 2; MustPass = $true  }
    [pscustomobject]@{ Name = 'negative';        Dir = 'evals\invalid';  Min = 5; MustPass = $false }
)

$failures = @()
$passed = 0

# Two deliverable shapes, two checkers, chosen by extension:
#   .json -> JSON envelope contract (OA supplier review output)
#   .md   -> prose document structure (payment-term / risk opinion)
$opinionValidator = Join-Path $PSScriptRoot 'validate-opinion.ps1'

function Invoke-Validator([string]$file, [string]$schema) {
    # Split-Path has no -Extension parameter; use the .NET helper instead.
    if ([System.IO.Path]::GetExtension($file) -eq '.md') {
        $output = & $opinionValidator -InputPath $file 2>&1 | Out-String
    }
    elseif ($schema) {
        $output = & $validator -InputPath $file -SchemaPath $schema 2>&1 | Out-String
    }
    else {
        $output = & $validator -InputPath $file 2>&1 | Out-String
    }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Text = $output }
}

foreach ($b in $buckets) {
    $full = Join-Path $repoRoot $b.Dir
    Write-Output ('=== ' + $b.Name + ' (' + $b.Dir + ') ===')

    $files = @()
    if (Test-Path -LiteralPath $full) {
        $files = @(Get-ChildItem -LiteralPath $full -File |
            Where-Object { $_.Extension -eq '.json' -or $_.Extension -eq '.md' } |
            Sort-Object Name)
    }

    # Guarantee 1: count floor.
    if ($files.Count -lt $b.Min) {
        $msg = ($b.Name + ' has ' + $files.Count + ' case(s), expected at least ' + $b.Min +
                ' - directory missing or ignored? (check .gitignore anchoring)')
        Write-Output ('  FLOOR_BROKEN  ' + $msg)
        $failures += $msg
        continue
    }

foreach ($f in $files) {
        # Reset per file. A .md case that inherited the previous .json case's $expect
        # was reported as WRONG-REASON even though the validator caught it correctly.
        $expect = @()
        $schema = $null
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if ($f.Extension -eq '.json') {
            $meta = $text | ConvertFrom-Json
            if ($meta._expect) {
                $expect = @($meta._expect.must_contain)
                if ($meta._expect.schema) {
                    $schema = Join-Path $repoRoot ($meta._expect.schema -replace '/', '\')
                }
            }
        }
        else {
            # Prose cases carry their expected reason as an HTML comment.
            $m = [regex]::Match($text, '<!--\s*expect:\s*(.+?)\s*-->')
            if ($m.Success) { $expect = @($m.Groups[1].Value) }
        }
        $r = Invoke-Validator $f.FullName $schema

        if ($b.MustPass) {
            if ($r.Code -eq 0) {
                Write-Output ('  PASS    ' + $f.Name); $passed++
            }
            else {
                Write-Output ('  FAIL    ' + $f.Name + ' (exit ' + $r.Code + ')')
                ($r.Text -split "`n") | Where-Object { $_ -match 'VIOLATION' } |
                    ForEach-Object { Write-Output ('          ' + $_.Trim()) }
                $failures += ('golden rejected: ' + $f.Name)
            }
        }
        else {
            if ($r.Code -eq 0) {
                Write-Output ('  MISSED  ' + $f.Name + ' - validator accepted an invalid result')
                $failures += ('negative not caught: ' + $f.Name)
                continue
            }
            $hitAll = $true
            foreach ($e in $expect) {
                if ($e -and $r.Text -notlike ('*' + $e + '*')) { $hitAll = $false }
            }
            if ($hitAll) {
                Write-Output ('  CAUGHT  ' + $f.Name); $passed++
            }
            else {
                Write-Output ('  WRONG-REASON  ' + $f.Name + ' expected: ' + ($expect -join ' | '))
                ($r.Text -split "`n") | Where-Object { $_ -match 'VIOLATION' } |
                    ForEach-Object { Write-Output ('          ' + $_.Trim()) }
                $failures += ('negative wrong reason: ' + $f.Name)
            }
        }
    }
}

Write-Output '=== summary ==='
Write-Output ('passed=' + $passed + ' failures=' + $failures.Count)
if ($failures.Count -gt 0) {
    foreach ($m in $failures) { Write-Output ('  - ' + $m) }
    Write-Output 'EVALS=FAIL'
    exit 1
}
Write-Output 'EVALS=PASS'
exit 0
