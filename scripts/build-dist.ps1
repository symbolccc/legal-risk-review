<#
.SYNOPSIS
  Rebuild single-file distribution builds for every skill in the repository.
.DESCRIPTION
  One build per skill directory under skills/. Each skill's references/, assets/ and
  examples/ are discovered automatically, so adding a file needs no change here.
  Version comes from each SKILL.md frontmatter, so output names follow each skill's own
  version (they are allowed to diverge).

  Every source file is verified to appear verbatim in its build; any mismatch exits 1.

  Keep this file pure ASCII.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$skillsRoot = Join-Path $root 'skills'
$distDir = Join-Path $root 'dist'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function ReadU8($p) { return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }

# Schemas that belong to a specific skill (JSON envelope contracts are not universal).
$skillSchemas = @{
    'oa-supplier-review' = 'schemas\supplier-review-output.schema.json'
}

New-Item -ItemType Directory -Path $distDir -Force | Out-Null

$totalBad = 0
$built = @()

foreach ($skillDir in Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name) {
    $skillName = $skillDir.Name
    $skillMd = Join-Path $skillDir.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd)) {
        Write-Output ('SKIP (no SKILL.md) ' + $skillName)
        continue
    }

    $skillText = ReadU8 $skillMd
    $ver = [regex]::Match($skillText, '(?m)^version:\s*(\S+)\s*$').Groups[1].Value
    if (-not $ver) {
        Write-Output ('ERROR: ' + $skillName + ' SKILL.md has no version: in frontmatter')
        $totalBad++
        continue
    }
    $out = Join-Path $distDir ($skillName + '-v' + $ver + '.md')

    $parts = @()
    $parts += (ReadU8 (Join-Path $PSScriptRoot 'dist-header.md')).Replace('{{SKILL}}', $skillName)
    $parts += $skillText

    $sources = @()
    $sep = "`n`n---`n`n"
    $letter = [char]'A'
    foreach ($sub in @('references', 'assets', 'examples')) {
        $subDir = Join-Path $skillDir.FullName $sub
        if (-not (Test-Path -LiteralPath $subDir)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $subDir -Filter '*.md' -File | Sort-Object Name) {
            $rel = $sub + '/' + $f.Name
            $body = ReadU8 $f.FullName
            $parts += ($sep + '# Appendix ' + $letter + ' - ' + $rel + "`n`n" + $body)
            $sources += @{ Rel = $rel; Text = $body.Trim() }
            $letter = [char]([int]$letter + 1)
        }
    }

    if ($skillSchemas.ContainsKey($skillName)) {
        $srel = $skillSchemas[$skillName]
        $spath = Join-Path $root $srel
        if (Test-Path -LiteralPath $spath) {
            $stext = (ReadU8 $spath).Trim()
            $parts += ($sep + '# Appendix ' + $letter + ' - ' + ($srel -replace '\\', '/') + "`n`n" +
                       'Normative output contract, enforced by `scripts/validate-output.ps1`.' + "`n`n" +
                       '```json' + "`n" + $stext + "`n" + '```')
            $sources += @{ Rel = $srel; Text = $stext }
        }
    }

    $text = ($parts -join "`n")
    [System.IO.File]::WriteAllText($out, $text, $utf8)

    Write-Output ('=== ' + $skillName + ' v' + $ver + ' ===')
    Write-Output ('  written=' + (Split-Path -Leaf $out) + ' bytes=' + (Get-Item -LiteralPath $out).Length)

    $full = ReadU8 $out
    $bad = 0
    foreach ($s in $sources) {
        if ($full.Contains($s.Text)) {
            Write-Output ('  VERBATIM_OK  ' + $s.Rel)
        }
        else {
            Write-Output ('  MISMATCH     ' + $s.Rel)
            $bad++
        }
    }
    Write-Output ('  mismatches=' + $bad)
    $totalBad += $bad
    $built += $out
}

# Remove builds whose skill/version no longer exists, so stale vulnerable builds
# cannot linger next to fresh ones.
$keep = @($built | ForEach-Object { (Split-Path -Leaf $_) })
foreach ($existing in Get-ChildItem -LiteralPath $distDir -Filter '*.md' -File) {
    if ($keep -notcontains $existing.Name) {
        Write-Output ('  STALE_BUILD  ' + $existing.Name)
        $totalBad++
    }
}

Write-Output ('skills_built=' + $built.Count + ' total_mismatches=' + $totalBad)
if ($totalBad -gt 0) { exit 1 }
Write-Output 'BUILD_OK'
# Explicit success code: a script that falls off the end leaves $LASTEXITCODE unset,
# which a caller cannot distinguish from failure.
exit 0
