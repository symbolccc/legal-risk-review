<#
.SYNOPSIS
  Run the evaluation suite for the legal-risk-review skill.
.DESCRIPTION
  Two halves, both required:

    evals/cases/    golden results. Each MUST pass validation. If a golden case fails,
                    either the rule set or the case is wrong - either way the repo is
                    inconsistent and CI must go red.

    evals/invalid/  deliberately broken results. Each MUST be rejected, and must be
                    rejected for the reason recorded in _expect.must_contain. This is
                    the test-the-tester half: it proves the validator actually catches
                    the bug class instead of silently passing everything.
.OUTPUT
  Pass/fail summary. Exit 0 = all good, 1 = failures present.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $PSScriptRoot 'validate-output.ps1'
if (-not (Test-Path -LiteralPath $validator)) { Write-Output 'VALIDATOR_NOT_FOUND'; exit 1 }

$failures = @()
$passed = 0

function Invoke-Validator([string]$file) {
    $output = & $validator -InputPath $file 2>&1 | Out-String
    return [pscustomobject]@{ Code = $LASTEXITCODE; Text = $output }
}

Write-Output '=== golden cases (must pass) ==='
$caseDir = Join-Path $repoRoot 'evals\cases'
if (Test-Path -LiteralPath $caseDir) {
    foreach ($f in Get-ChildItem -LiteralPath $caseDir -Filter '*.json' | Sort-Object Name) {
        $r = Invoke-Validator $f.FullName
        if ($r.Code -eq 0) {
            Write-Output ('  PASS  ' + $f.Name)
            $passed++
        }
        else {
            Write-Output ('  FAIL  ' + $f.Name + ' (exit ' + $r.Code + ')')
            ($r.Text -split "`n") | Where-Object { $_ -match 'VIOLATION' } | ForEach-Object { Write-Output ('        ' + $_.Trim()) }
            $failures += ('golden: ' + $f.Name)
        }
    }
}

Write-Output '=== negative cases (must be rejected for the right reason) ==='
$badDir = Join-Path $repoRoot 'evals\invalid'
if (Test-Path -LiteralPath $badDir) {
    foreach ($f in Get-ChildItem -LiteralPath $badDir -Filter '*.json' | Sort-Object Name) {
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $expect = @((($text | ConvertFrom-Json)._expect).must_contain)
        $r = Invoke-Validator $f.FullName

        if ($r.Code -eq 0) {
            Write-Output ('  MISS  ' + $f.Name + ' - validator accepted an invalid result')
            $failures += ('negative not caught: ' + $f.Name)
            continue
        }
        $hitAll = $true
        foreach ($e in $expect) {
            if ($e -and $r.Text -notlike ('*' + $e + '*')) { $hitAll = $false }
        }
        if ($hitAll) {
            Write-Output ('  CAUGHT  ' + $f.Name)
            $passed++
        }
        else {
            Write-Output ('  WRONG-REASON  ' + $f.Name + ' expected: ' + ($expect -join ' | '))
            ($r.Text -split "`n") | Where-Object { $_ -match 'VIOLATION' } | ForEach-Object { Write-Output ('        ' + $_.Trim()) }
            $failures += ('negative wrong reason: ' + $f.Name)
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
