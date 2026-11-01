<#
.SYNOPSIS
  Install the 30s science storyboard skill into any agent that can consume it.

.DESCRIPTION
  Skill-style targets copy SKILL.md + references/ + scripts/ into a skills
  directory. Rule-style targets drop a single generated file into the path that
  agent reads, or append a marked block to a global instruction file.

  Targets:
    dsh        ~/.dsh/skills/sci-30s-storyboard/          (DSH)
    claude     ~/.claude/skills/sci-30s-storyboard/       (Claude Code)
    codex      ~/.codex/AGENTS.md                         (Codex / Jules / Amp / opencode)
    gemini     ~/.gemini/GEMINI.md                        (Gemini CLI)
    cursor     <project>/.cursor/rules/*.mdc              (Cursor)
    windsurf   <project>/.windsurf/rules/*.md             (Windsurf)
    cline      <project>/.clinerules/*.md                 (Cline)
    copilot    <project>/.github/instructions/*.instructions.md
    continue   <project>/.continue/rules/*.md             (Continue)
    all        every target above

.EXAMPLE
  .\install.ps1 -Target dsh,claude

.EXAMPLE
  .\install.ps1 -Target all -Project "D:\work\my-video-project"
#>
[CmdletBinding()]
param(
    [ValidateSet('dsh', 'claude', 'codex', 'gemini', 'cursor', 'windsurf', 'cline', 'copilot', 'continue', 'all')]
    [string[]]$Target = @('dsh', 'claude'),

    [string]$Project = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [string]$Repo = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$slug = 'sci-30s-storyboard'

if ($Target -contains 'all') {
    $Target = @('dsh', 'claude', 'codex', 'gemini', 'cursor', 'windsurf', 'cline', 'copilot', 'continue')
}

if (-not (Test-Path (Join-Path $Repo 'dist'))) {
    Write-Output 'dist/ missing, running build.ps1'
    & (Join-Path $Repo 'build.ps1') -Repo $Repo | Out-Null
}

function Install-SkillDir {
    param([string]$Root)

    $dest = Join-Path $Root $slug
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item (Join-Path $Repo 'SKILL.md') $dest -Force
    foreach ($sub in @('references', 'scripts')) {
        $from = Join-Path $Repo $sub
        if (Test-Path $from) {
            Copy-Item $from $dest -Recurse -Force
        }
    }
    Write-Output "  skill  $dest"
}

function Install-File {
    param([string]$SourceFile, [string]$DestPath)

    $dir = Split-Path $DestPath -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item (Join-Path $Repo "dist\$SourceFile") $DestPath -Force
    Write-Output "  file   $DestPath"
}

function Install-MarkedBlock {
    param([string]$SourceFile, [string]$DestPath)

    $begin = '<!-- sci-30s-storyboard:begin -->'
    $end = '<!-- sci-30s-storyboard:end -->'
    $block = (Get-Content (Join-Path $Repo "dist\$SourceFile") -Raw -Encoding UTF8).Trim()

    $existing = ''
    if (Test-Path $DestPath) {
        $existing = (Get-Content $DestPath -Raw -Encoding UTF8)
    }

    $pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
    $clean = [regex]::Replace($existing, $pattern, '').TrimEnd()

    $merged = if ($clean) { $clean + "`n`n" + $begin + "`n" + $block + "`n" + $end + "`n" }
    else { $begin + "`n" + $block + "`n" + $end + "`n" }

    $dir = Split-Path $DestPath -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [System.IO.File]::WriteAllText($DestPath, $merged, $utf8)
    Write-Output "  block  $DestPath"
}

foreach ($t in $Target) {
    Write-Output "[$t]"
    switch ($t) {
        'dsh' { Install-SkillDir (Join-Path $HomeRoot '.dsh\skills') }
        'claude' { Install-SkillDir (Join-Path $HomeRoot '.claude\skills') }
        'codex' { Install-MarkedBlock 'AGENTS.md' (Join-Path $HomeRoot '.codex\AGENTS.md') }
        'gemini' { Install-MarkedBlock 'gemini.md' (Join-Path $HomeRoot '.gemini\GEMINI.md') }
        'cursor' { Install-File 'cursor.mdc' (Join-Path $Project ".cursor\rules\$slug.mdc") }
        'windsurf' { Install-File 'windsurf.md' (Join-Path $Project ".windsurf\rules\$slug.md") }
        'cline' { Install-File 'cline.md' (Join-Path $Project ".clinerules\$slug.md") }
        'copilot' { Install-File 'copilot.instructions.md' (Join-Path $Project ".github\instructions\$slug.instructions.md") }
        'continue' { Install-File 'continue.md' (Join-Path $Project ".continue\rules\$slug.md") }
    }
}

Write-Output 'DONE - restart the agent session so it picks up the new instructions.'
