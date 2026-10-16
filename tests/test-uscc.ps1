<#
.SYNOPSIS
  Unit tests for scripts/validate-uscc.ps1 (GB 32100-2015 check digit).
.DESCRIPTION
  Beyond the standard example, this suite proves the property that matters:
  every single-character mutation of a valid code must be rejected. A check-digit
  scheme that passes its own example but misses mutations is useless in practice.
#>
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $repoRoot 'scripts\validate-uscc.ps1'
$Charset = '0123456789ABCDEFGHJKLMNPQRTUWXY'

$fail = 0
$pass = 0
function Check([string]$name, [bool]$ok) {
    if ($ok) { Write-Output ('  ok    ' + $name); $script:pass++ }
    else     { Write-Output ('  FAIL  ' + $name); $script:fail++ }
}

Write-Output '=== standard example (GB 32100-2015) ==='
$base = '91350100M000100Y43'
$r = & $validator -Code $base
Check ('accepts ' + $base) ($r.Valid -eq $true)

Write-Output '=== length and charset rejection ==='
Check 'rejects 17 chars' ((& $validator -Code '91350100M000100Y4').Valid -ne $true)
Check 'rejects 19 chars' ((& $validator -Code ($base + '0')).Valid -ne $true)
Check 'rejects letter O'  ((& $validator -Code '91350100M000100Y4O').Valid -ne $true)
Check 'rejects letter I'  ((& $validator -Code '91350100M000100Y4I').Valid -ne $true)
Check 'rejects letter S'  ((& $validator -Code '91350100M000100Y4S').Valid -ne $true)

Write-Output '=== single-character mutation must always be caught ==='
$missed = 0
$tested = 0
$chars = $base.ToCharArray()
for ($pos = 0; $pos -lt 18; $pos++) {
    foreach ($ch in $Charset.ToCharArray()) {
        if ([string]$ch -eq [string]$chars[$pos]) { continue }
        $mutated = ($chars[0..($pos - 1)] -join '') + [string]$ch + ($chars[($pos + 1)..17] -join '')
        $tested++
        $res = & $validator -Code $mutated
        if ($res.Valid) {
            $missed++
            Write-Output ('    UNCAUGHT  pos ' + ($pos + 1) + ' -> ' + $mutated)
        }
    }
}
Check ('all ' + $tested + ' single-char mutations rejected (missed=' + $missed + ')') ($missed -eq 0)

Write-Output '=== case-insensitive input normalisation ==='
Check 'accepts lowercase input' ((& $validator -Code '91350100m000100y43').Valid -eq $true)
Check 'accepts surrounding spaces' ((& $validator -Code ('  ' + $base + ' ')).Valid -eq $true)

Write-Output '=== summary ==='
Write-Output ('passed=' + $pass + ' failed=' + $fail)
if ($fail -gt 0) { Write-Output 'TESTS=FAIL'; exit 1 }
Write-Output 'TESTS=PASS'
exit 0
