#!/usr/bin/env bash
# Tests for v2 behaviour of scripts/anonymize.sh:
#   - expected answer count as first argument (3 quick, 5 standard, 6 with red team)
#   - labels A-F
#   - masking hits persona self-references only, not ordinary words
#   - answers are kept (with personas) in a private file for the notes
# Run: bash tests/test_mask_and_counts.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../plugins/llm-council/skills/llm-council/scripts/anonymize.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; cd "$WORK"
# stdin: the script's stdout; prints the packet file's content
packet_of() { f="$(sed -n 's/^### PACKET FILE: //p')"; [ -n "$f" ] && [ -f "$f" ] && cat "$f"; }

SIX='=== ROLE: contrarian ===
POSITION: NO-GO — M1
=== ROLE: first-principles ===
POSITION: CHANGE — M2
=== ROLE: expansionist ===
POSITION: GO — M3
=== ROLE: outsider ===
POSITION: CHANGE — M4
=== ROLE: executor ===
POSITION: CHANGE — M5
=== ROLE: red-team ===
POSITION: GO — M6'

out="$(printf '%s\n' "$SIX" | bash "$SCRIPT" 6)"; rc=$?
[ $rc -eq 0 ] && ok "6 answers accepted when 6 expected" || bad "6 answers accepted when 6 expected (rc $rc)"
pk="$(printf '%s\n' "$out" | packet_of)"
for L in A B C D E F; do
  printf '%s\n' "$pk" | grep -q "^=== ANSWER $L ===$" && ok "6-answer packet has $L" || bad "6-answer packet has $L"
done
printf '%s\n' "$out" | grep -q '^F = ' && ok "key has F" || bad "key has F"
printf '%s\n' "$pk" | grep -qi 'red[- ]team' && bad "red-team role not leaked" || ok "red-team role not leaked"

THREE="$(printf '%s\n' "$SIX" | sed -n '1,4p;9,10p')"
printf '%s\n' "$THREE" | bash "$SCRIPT" 3 >/dev/null 2>&1 && ok "3 answers accepted when 3 expected" || bad "3 answers accepted when 3 expected"
printf '%s\n' "$THREE" | bash "$SCRIPT" 5 >/dev/null 2>&1 && bad "3 answers rejected when 5 expected" || ok "3 answers rejected when 5 expected"
printf '%s\n' "$SIX" | bash "$SCRIPT" 7 >/dev/null 2>&1 && bad "expected count above 6 rejected" || ok "expected count above 6 rejected"

# Ordinary uses of persona words must survive.
ORD='=== ROLE: contrarian ===
Name an executor for the estate before signing.
Outsiders to the industry rarely read the fine print.
A contrarian bet on price only works with runway.
Reasoning from first principles, cost per shoot is fixed.
Serve as the executor of the estate.
Take the outsider view on pricing.
A contrarian take is useful here.
Outsider: nobody reads the terms.
この業界は部外者です。
=== ROLE: first-principles ===
x
=== ROLE: expansionist ===
x
=== ROLE: outsider ===
x
=== ROLE: executor ===
x'
opk="$(printf '%s\n' "$ORD" | bash "$SCRIPT" 5 | packet_of)"
for phrase in "Name an executor for the estate" "Outsiders to the industry" "A contrarian bet on price" "from first principles, cost" \
    "Serve as the executor of the estate" "Take the outsider view" "A contrarian take is useful" "Outsider: nobody reads" "この業界は部外者です"; do
  printf '%s\n' "$opk" | grep -qF "$phrase" && ok "ordinary phrase kept: $phrase" || bad "ordinary phrase kept: $phrase"
done

# Self-references must be masked.
SELF='=== ROLE: contrarian ===
As the Contrarian, I think this fails.
Executor here: ship on Monday.
The Expansionist in me sees upside.
First-principles view: the core assumption is wrong.
Speaking as an outsider, this sounds odd.
My role as the red team is to argue the other side.
OUTSIDER: plain words test.
=== ROLE: first-principles ===
x
=== ROLE: expansionist ===
x
=== ROLE: outsider ===
x
=== ROLE: executor ===
x'
spk="$(printf '%s\n' "$SELF" | bash "$SCRIPT" 5 | packet_of)"
if printf '%s\n' "$spk" | grep -qiE 'contrarian|expansionist|outsider|executor|first[- ]principles|red[- ]team'; then
  bad "self-references masked"; printf '%s\n' "$spk" | grep -niE 'contrarian|expansionist|outsider|executor|first[- ]principles|red[- ]team' | sed 's/^/        /'
else ok "self-references masked"; fi
printf '%s\n' "$spk" | grep -qF "I think this fails." && ok "rest of masked line kept" || bad "rest of masked line kept"

# Japanese self-references masked, Japanese text intact.
JA='=== ROLE: contrarian ===
逆張り役として言うと、この広告は失敗する。
実行役の立場から、来週は5万円だけ試す。
部外者の目線で見ると、説明が分かりにくい。
=== ROLE: first-principles ===
x
=== ROLE: expansionist ===
x
=== ROLE: outsider ===
x
=== ROLE: executor ===
x'
jpk="$(printf '%s\n' "$JA" | bash "$SCRIPT" 5 | packet_of)"
if printf '%s\n' "$jpk" | grep -qE '逆張り役|実行役|部外者'; then bad "Japanese self-references masked"; else ok "Japanese self-references masked"; fi
printf '%s\n' "$jpk" | grep -qF "この広告は失敗する。" && ok "Japanese text intact" || bad "Japanese text intact"

# The packet lives in ./.llm-council-work/<id>/packet.md, next to nothing else
# (so a reviewer that can read it cannot stumble on the key).
pf="$(printf '%s\n' "$SIX" | bash "$SCRIPT" 6 | sed -n 's/^### PACKET FILE: //p')"
case "$pf" in "$WORK"/.llm-council-work/*/packet.md) ok "packet file under ./.llm-council-work (absolute path)";; *) bad "packet file under ./.llm-council-work ($pf)";; esac
d="$(dirname "$pf")"
[ "$(ls -A "$d" | tr '\n' ' ')" = "packet.md " ] && ok "work dir holds only the packet" || bad "work dir holds only the packet ($(ls -A "$d" | tr '\n' ' '))"
[ "$(cat "$WORK/.llm-council-work/.gitignore" 2>/dev/null)" = "*" ] && ok "work dir is git-ignored" || bad "work dir is git-ignored"
grep -q '^[A-F] = ' "$pf" && bad "packet file has no key" || ok "packet file has no key"
out="$(printf '%s\n' "$SIX" | bash "$SCRIPT" 6)"
printf '%s\n' "$out" | grep -q '^=== ANSWER' && bad "answers not echoed to stdout" || ok "answers not echoed to stdout"

echo "passed: $PASS  failed: $FAIL"
[ $FAIL -eq 0 ]
