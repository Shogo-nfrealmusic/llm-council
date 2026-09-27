#!/usr/bin/env bash
# save_notes.sh — save the full council record as Markdown in the current project.
#
# usage: bash save_notes.sh <slug> [answers_file] < notes.md
#   slug:          short title; reduced to [a-z0-9-], max 50 chars ("council" if empty)
#   answers_file:  the private file anonymize.sh printed as "### ANSWERS FILE:".
#                  Its answers (with personas) replace the line "@@ANSWERS@@" in the
#                  notes. It is deleted afterwards.
# stdout: "NOTES: <path>", or "NOTES: off" when turned off.
#
# Turn off:        LLM_COUNCIL_NOTES=off   (also 0 / false / no)
# Other folder:    LLM_COUNCIL_NOTES_DIR=<dir>   (default ./council-notes)
set -eu

slug_in="${1:-}"
answers="${2:-}"

cleanup() {
  # Only ever delete the private temp file anonymize.sh created.
  case "$(basename -- "${answers:-x}")" in
    llm-council-answers.*) [ -f "$answers" ] && rm -f -- "$answers" ;;
  esac
  return 0
}

case "$(printf '%s' "${LLM_COUNCIL_NOTES:-on}" | tr '[:upper:]' '[:lower:]')" in
  off|0|false|no)
    cat >/dev/null
    cleanup
    echo "NOTES: off"
    exit 0
    ;;
esac

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
  if [ -n "$answers" ] && [ -f "$answers" ]; then
    awk '
      /^=== ROLE: .* ===$/ { r=$0; sub(/^=== ROLE: /, "", r); sub(/ ===$/, "", r); printf "\n### %s\n\n", r; next }
      { print }
    ' "$answers"
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
