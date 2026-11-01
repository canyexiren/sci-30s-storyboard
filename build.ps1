<#
.SYNOPSIS
  Generate per-agent distributions from the canonical SKILL.md.

.DESCRIPTION
  SKILL.md is the single source of truth. This script strips its YAML
  frontmatter and prepends the header each agent ecosystem expects, writing
  everything into dist/.

  Headers live in templates/headers.json so this script stays pure ASCII:
  Windows PowerShell 5.1 decodes BOM-less .ps1 files as ANSI, which would
  corrupt any CJK literal written inline here.

  Tokens: __DESC__ is replaced with the skill description.

.EXAMPLE
  .\build.ps1
#>
[CmdletBinding()]
param(
    [string]$Repo = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$skillPath = Join-Path $Repo 'SKILL.md'
$tplPath = Join-Path $Repo 'templates\headers.json'
foreach ($p in @($skillPath, $tplPath)) {
    if (-not (Test-Path $p)) { throw "missing required file: $p" }
}

$text = ([System.IO.File]::ReadAllText($skillPath, $utf8)) -replace "`r`n", "`n"
if (-not $text.StartsWith("---`n")) { throw 'SKILL.md must start with a --- frontmatter fence' }

$end = $text.IndexOf("`n---", 4)
if ($end -lt 0) { throw 'frontmatter fence not closed' }

$fm = $text.Substring(4, $end - 4)
$body = $text.Substring($end + 4).Trim()

$descLine = ($fm -split "`n" | Where-Object { $_ -match '^\s*description\s*:' } | Select-Object -First 1)
if (-not $descLine) { throw 'description missing from frontmatter' }
$desc = ($descLine -replace '^\s*description\s*:\s*', '').Trim().Trim('"', "'")

$headers = [System.IO.File]::ReadAllText($tplPath, $utf8) | ConvertFrom-Json

$dist = Join-Path $Repo 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

Write-Output 'Building distributions from SKILL.md'
$count = 0
foreach ($prop in $headers.PSObject.Properties) {
    $file = $prop.Name
    $header = $prop.Value.Replace('__DESC__', $desc)
    $content = $header + $body + "`n"
    [System.IO.File]::WriteAllText((Join-Path $dist $file), $content, $utf8)
    Write-Output ("  {0,-30} {1} KB" -f $file, [math]::Round($content.Length / 1024, 1))
    $count++
}

Write-Output ("DONE {0} files in {1}" -f $count, $dist)
