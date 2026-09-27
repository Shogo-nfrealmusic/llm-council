#!/usr/bin/env bash
# Tests for scripts/save_notes.sh. Run: bash tests/test_save_notes.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../plugins/llm-council/skills/llm-council/scripts/save_notes.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
TODAY="$(date +%F)"

mkdir -p "$WORK/.llm-council-work"; printf '*\n' > "$WORK/.llm-council-work/.gitignore"
ans="$WORK/.llm-council-work/run.test1"; mkdir -p "$ans"
printf '=== ANSWER A ===\nPOSITION: NO-GO — fails\n=== ANSWER B ===\nPOSITION: CHANGE — test small\n' > "$ans/packet.md"

out="$(printf '# Council notes\n\n## Advisors\n@@ANSWERS@@\n\n## Chairman\nVERDICT: CHANGE IT\n' | bash "$SCRIPT" "Raise price to \$19!" "$ans")"; rc=$?
[ $rc -eq 0 ] && ok "exits 0" || bad "exits 0 ($rc)"
f="council-notes/$TODAY-raise-price-to-19.md"
[ "$out" = "NOTES: $f" ] && ok "prints path ($out)" || bad "prints path (got '$out', want 'NOTES: $f')"
[ -f "$f" ] && ok "file written" || bad "file written"
grep -q '^### Answer A$' "$f" && grep -q 'POSITION: NO-GO — fails' "$f" && ok "answers inserted with headings" || bad "answers inserted with headings"
grep -q '@@ANSWERS@@' "$f" && bad "marker replaced" || ok "marker replaced"
grep -q '^VERDICT: CHANGE IT$' "$f" && ok "rest of notes kept" || bad "rest of notes kept"
[ ! -e "$ans" ] && ok "work dir removed after use" || bad "work dir removed after use"
[ ! -e "$WORK/.llm-council-work" ] && ok "empty .llm-council-work removed" || bad "empty .llm-council-work removed"

# A file that is not one of ours is never deleted.
keep="$WORK/important"; mkdir -p "$keep"; printf "=== ANSWER A ===\ny\n" > "$keep/packet.md"
printf "@@ANSWERS@@\n" | bash "$SCRIPT" "keep test" "$keep" >/dev/null
[ -e "$keep" ] && ok "foreign file not deleted" || bad "foreign file not deleted"

# Same slug on the same day does not overwrite.
out2="$(printf 'second\n' | bash "$SCRIPT" "Raise price to \$19!")"
[ "$out2" = "NOTES: council-notes/$TODAY-raise-price-to-19-2.md" ] && ok "no overwrite (-2 suffix)" || bad "no overwrite (got '$out2')"
grep -q '^VERDICT' "$f" && ok "first file untouched" || bad "first file untouched"

# Non-ASCII or empty slug falls back to 'council'; long slugs are cut.
out3="$(printf 'x\n' | bash "$SCRIPT" "広告に50万円")"
[ "$out3" = "NOTES: council-notes/$TODAY-50.md" ] && ok "non-ASCII stripped ($out3)" || bad "non-ASCII stripped (got '$out3')"
out4="$(printf 'x\n' | bash "$SCRIPT" "日本語だけ")"
[ "$out4" = "NOTES: council-notes/$TODAY-council.md" ] && ok "empty slug -> council" || bad "empty slug -> council (got '$out4')"
out5="$(printf 'x\n' | bash "$SCRIPT" "$(printf 'a%.0s' $(seq 1 100))")"
base="$(basename "${out5#NOTES: }" .md)"
[ ${#base} -le 61 ] && ok "long slug cut (${#base} chars)" || bad "long slug cut (${#base} chars)"
out6="$(printf 'x\n' | bash "$SCRIPT" "../../etc/passwd")"
case "$out6" in "NOTES: council-notes/$TODAY-etc-passwd.md") ok "path traversal neutralised";; *) bad "path traversal neutralised ($out6)";; esac

# --discard removes the work dir without writing notes (used with --no-notes).
mkdir -p "$WORK/.llm-council-work/run.test2"; printf 'x\n' > "$WORK/.llm-council-work/run.test2/packet.md"
out10="$(bash "$SCRIPT" --discard "$WORK/.llm-council-work/run.test2" < /dev/null)"
[ "$out10" = "NOTES: off" ] && [ ! -e "$WORK/.llm-council-work/run.test2" ] && ok "--discard removes work dir" || bad "--discard removes work dir ($out10)"
ls council-notes | grep -q discard && bad "--discard writes no notes" || ok "--discard writes no notes"

# Can be turned off.
out7="$(printf 'x\n' | LLM_COUNCIL_NOTES=off bash "$SCRIPT" "off test")"
[ "$out7" = "NOTES: off" ] && [ ! -e "council-notes/$TODAY-off-test.md" ] && ok "LLM_COUNCIL_NOTES=off writes nothing" || bad "LLM_COUNCIL_NOTES=off writes nothing ($out7)"

# Directory can be changed.
out8="$(printf 'x\n' | LLM_COUNCIL_NOTES_DIR="$WORK/elsewhere" bash "$SCRIPT" "dir test")"
[ -f "$WORK/elsewhere/$TODAY-dir-test.md" ] && ok "LLM_COUNCIL_NOTES_DIR respected" || bad "LLM_COUNCIL_NOTES_DIR respected ($out8)"

# A missing answers file is not fatal (notes still saved, marker says so).
out9="$(printf 'A\n@@ANSWERS@@\nB\n' | bash "$SCRIPT" "missing" "$WORK/nope")"; rc=$?
[ $rc -eq 0 ] && grep -q 'not available' "council-notes/$TODAY-missing.md" && ok "missing answers file tolerated" || bad "missing answers file tolerated ($rc, $out9)"

echo "passed: $PASS  failed: $FAIL"
[ $FAIL -eq 0 ]
