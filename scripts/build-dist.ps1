# Rebuild the single-file distribution build from the skill sources.
# Version is read from SKILL.md frontmatter, so the output filename follows the version.
# Exits non-zero if any source file is not reproduced verbatim in the output.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$skill = Join-Path $root 'skills\legal-risk-review'
$distDir = Join-Path $root 'dist'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function ReadU8($p) { return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }

$skillText = ReadU8 (Join-Path $skill 'SKILL.md')
$verMatch = [regex]::Match($skillText, '(?m)^version:\s*(\S+)\s*$')
if (-not $verMatch.Success) {
    Write-Error 'Cannot read "version:" from SKILL.md frontmatter'
    exit 2
}
$ver = $verMatch.Groups[1].Value
$out = Join-Path $distDir ('legal-risk-review-v' + $ver + '.md')

New-Item -ItemType Directory -Path $distDir -Force | Out-Null

$appendices = [ordered]@{
    'A' = 'references\source-contract.md'
    'B' = 'references\supplier-rules.md'
    'C' = 'references\settlement-review.md'
    'D' = 'references\contract-seal.md'
    'E' = 'assets\risk-opinion-template.md'
    'F' = 'assets\approval-replies.md'
    'G' = 'examples\example-payment-term.md'
    'H' = 'examples\example-supplier-review.md'
}

$parts = @()
$parts += (ReadU8 (Join-Path $PSScriptRoot 'dist-header.md'))
$parts += $skillText
$sep = "`n`n---`n`n"
foreach ($k in $appendices.Keys) {
    $rel = $appendices[$k]
    $body = ReadU8 (Join-Path $skill $rel)
    $parts += ($sep + '# Appendix ' + $k + ' - ' + ($rel -replace '\\', '/') + "`n`n" + $body)
}

# The output schema lives at repo root, outside the skill folder. Including it keeps the
# single-file build self-contained: a reader can validate results without cloning.
$schemaRel = 'schemas\review-output.schema.json'
$schemaText = (ReadU8 (Join-Path $root $schemaRel)).Trim()
$parts += ($sep + '# Appendix I - schemas/review-output.schema.json' + "`n`n" +
    'Normative output contract, enforced by `scripts/validate-output.ps1`.' + "`n`n" +
    '```json' + "`n" + $schemaText + "`n" + '```')

$text = ($parts -join "`n")
[System.IO.File]::WriteAllText($out, $text, $utf8)

Write-Output ("version=" + $ver)
Write-Output ("written=" + $out)
Write-Output ("bytes=" + (Get-Item -LiteralPath $out).Length)

Write-Output '--- verbatim check ---'
$full = ReadU8 $out
$bad = 0
foreach ($rel in (@('SKILL.md') + ($appendices.Values | ForEach-Object { $_ }))) {
    $body = (ReadU8 (Join-Path $skill $rel)).Trim()
    if ($full.Contains($body)) {
        Write-Output ('  VERBATIM_OK  ' + $rel)
    }
    else {
        Write-Output ('  MISMATCH     ' + $rel)
        $bad++
    }
}
if ($full.Contains($schemaText)) {
    Write-Output ('  VERBATIM_OK  ' + $schemaRel)
}
else {
    Write-Output ('  MISMATCH     ' + $schemaRel)
    $bad++
}
Write-Output ('mismatches=' + $bad)
if ($bad -gt 0) { exit 1 }
Write-Output 'BUILD_OK'
