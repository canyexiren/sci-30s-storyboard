#!/usr/bin/env bash
# Install the 30s science storyboard skill into any agent that can consume it.
#
#   ./install.sh                      # DSH + Claude Code (skill dirs)
#   ./install.sh dsh claude codex gemini
#   ./install.sh all --project ~/work/video-project
#
# Skill-style targets copy SKILL.md + references/ + scripts/ into a skills dir.
# Rule-style targets write one generated file into the path the agent reads.
# Global instruction files (AGENTS.md, GEMINI.md) get a marked block, so
# re-running the installer replaces the block instead of duplicating it.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLUG="sci-30s-storyboard"
PROJECT="$PWD"
TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(dsh claude)
fi

if [ "${TARGETS[0]}" = "all" ]; then
  TARGETS=(dsh claude codex gemini cursor windsurf cline copilot continue)
fi

if [ ! -d "$REPO/dist" ]; then
  echo "dist/ missing. Run build.ps1 (PowerShell) or copy the files from the release archive."
  exit 1
fi

install_skill_dir() {
  local root="$1"
  local dest="$root/$SLUG"
  mkdir -p "$dest"
  cp "$REPO/SKILL.md" "$dest/"
  for sub in references scripts; do
    [ -d "$REPO/$sub" ] && cp -R "$REPO/$sub" "$dest/"
  done
  echo "  skill  $dest"
}

install_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp "$REPO/dist/$src" "$dest"
  echo "  file   $dest"
}

install_block() {
  local src="$1" dest="$2"
  local begin='<!-- sci-30s-storyboard:begin -->'
  local end='<!-- sci-30s-storyboard:end -->'
  mkdir -p "$(dirname "$dest")"

  # Strip any previous block, then trailing blank lines. Pure awk: python is not
  # guaranteed to exist (Git Bash on Windows ships without it).
  local tmp
  tmp="$(mktemp)"
  if [ -f "$dest" ]; then
    awk -v b="$begin" -v e="$end" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip    { print }
    ' "$dest" | awk '
      { line[NR] = $0 }
      END {
        last = 0
        for (i = 1; i <= NR; i++) if (line[i] ~ /[^[:space:]]/) last = i
        for (i = 1; i <= last; i++) print line[i]
      }
    ' > "$tmp"
  fi

  {
    if [ -s "$tmp" ]; then
      cat "$tmp"
      echo
    fi
    echo "$begin"
    cat "$REPO/dist/$src"
    echo "$end"
  } > "$dest"

  rm -f "$tmp"
  echo "  block  $dest"
}

for t in "${TARGETS[@]}"; do
  echo "[$t]"
  case "$t" in
    dsh)      install_skill_dir "$HOME/.dsh/skills" ;;
    claude)   install_skill_dir "$HOME/.claude/skills" ;;
    codex)    install_block AGENTS.md "$HOME/.codex/AGENTS.md" ;;
    gemini)   install_block gemini.md "$HOME/.gemini/GEMINI.md" ;;
    cursor)   install_file cursor.mdc "$PROJECT/.cursor/rules/$SLUG.mdc" ;;
    windsurf) install_file windsurf.md "$PROJECT/.windsurf/rules/$SLUG.md" ;;
    cline)    install_file cline.md "$PROJECT/.clinerules/$SLUG.md" ;;
    copilot)  install_file copilot.instructions.md "$PROJECT/.github/instructions/$SLUG.instructions.md" ;;
    continue) install_file continue.md "$PROJECT/.continue/rules/$SLUG.md" ;;
    *) echo "  unknown target: $t" ;;
  esac
done

echo "DONE - restart the agent session so it picks up the new instructions."
