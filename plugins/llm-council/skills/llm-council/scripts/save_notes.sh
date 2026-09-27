#!/usr/bin/env bash
# save_notes.sh — save the full council record as Markdown in the current project.
#
# usage: bash save_notes.sh <slug> <work_dir> < notes.md
#        bash save_notes.sh --discard <work_dir>        (no notes; just clean up)
#   slug:      short title; reduced to [a-z0-9-], max 50 chars ("council" if empty)
#   work_dir:  the folder of the "### PACKET FILE:" anonymize.sh printed. Its
#              packet.md replaces the line "@@ANSWERS@@" in the notes. The folder
#              is deleted afterwards.
# stdout: "NOTES: <path>", or "NOTES: off" when turned off / discarded.
#
# Turn off:        LLM_COUNCIL_NOTES=off   (also 0 / false / no)
# Other folder:    LLM_COUNCIL_NOTES_DIR=<dir>   (default ./council-notes)
set -eu

discard=0
if [ "${1:-}" = "--discard" ]; then discard=1; shift; set -- "" "${1:-}"; fi
slug_in="${1:-}"
work="${2:-}"

# Only ever delete a run folder that anonymize.sh created: <...>/.llm-council-work/run.*
# No "..", no "//", no symlinks anywhere in the last two steps.
safe_work() {
  w="$1"
  [ -n "$w" ] || return 1
  case "$w" in *..*|*//*) return 1 ;; esac
  [ -d "$w" ] && [ ! -L "$w" ] || return 1
  parent="$(dirname -- "$w")"
  [ ! -L "$parent" ] || return 1
  case "$(basename -- "$w")" in run.*) ;; *) return 1 ;; esac
  [ "$(basename -- "$parent")" = ".llm-council-work" ] || return 1
  return 0
}

cleanup() {
  if safe_work "$work"; then
    rm -rf -- "$work"
    parent="$(dirname -- "$work")"
    if [ "$(ls -A "$parent" 2>/dev/null)" = ".gitignore" ]; then rm -rf -- "$parent"; fi
  fi
  return 0
}

off=0
case "$(printf '%s' "${LLM_COUNCIL_NOTES:-on}" | tr '[:upper:]' '[:lower:]')" in
  off|0|false|no) off=1 ;;
esac
if [ $discard -eq 1 ] || [ $off -eq 1 ]; then
  [ $discard -eq 1 ] || cat >/dev/null
  cleanup
  echo "NOTES: off"
  exit 0
fi

slug="$(printf '%s' "$slug_in" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-50)"
slug="${slug%-}"
[ -n "$slug" ] || slug="council"

dir="${LLM_COUNCIL_NOTES_DIR:-council-notes}"
mkdir -p -- "$dir"
base="$dir/$(date +%F)-$slug"
path="$base.md"
k=2
while [ -e "$path" ]; do path="$base-$k.md"; k=$((k + 1)); done

render_answers() {
  if safe_work "$work" && [ -f "$work/packet.md" ]; then
    awk '
      /^=== ANSWER [A-F] ===$/ { printf "\n### Answer %s\n\n", $3; next }
      { print }
    ' "$work/packet.md"
  else
    echo "(advisor answers not available)"
  fi
}

tmp="$path.tmp.$$"
while IFS= read -r line || [ -n "$line" ]; do
  if [ "$line" = "@@ANSWERS@@" ]; then
    render_answers
  else
    printf '%s\n' "$line"
  fi
done > "$tmp"
mv -- "$tmp" "$path"
cleanup
echo "NOTES: $path"
