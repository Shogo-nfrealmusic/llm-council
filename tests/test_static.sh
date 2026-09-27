#!/usr/bin/env bash
# Static checks on the plugin: agent definitions and SKILL.md wiring.
# Run: bash tests/test_static.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
P="$HERE/../plugins/llm-council"
SK="$P/skills/llm-council/SKILL.md"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
fm() { awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f {print}' "$1"; }

for a in council-advisor council-red-team council-reviewer council-chairman; do
  f="$P/agents/$a.md"
  [ -f "$f" ] || { bad "$a exists"; continue; }
  fm "$f" | grep -qx "name: $a" && ok "$a: name matches file" || bad "$a: name matches file"
  fm "$f" | grep -qx "omitClaudeMd: true" && ok "$a: starts without CLAUDE.md" || bad "$a: starts without CLAUDE.md"
  grep -q "$a" "$SK" && ok "SKILL.md uses $a" || bad "SKILL.md uses $a"
  grep -qi "ignore them" "$f" && ok "$a: told to ignore project instructions" || bad "$a: told to ignore project instructions"
done
for a in council-advisor council-red-team; do
  fm "$P/agents/$a.md" | grep -qx "tools: \[\]" && ok "$a: no tools" || bad "$a: no tools"
done
for a in council-reviewer council-chairman; do
  fm "$P/agents/$a.md" | grep -qx "tools: Read" && ok "$a: Read only" || bad "$a: Read only"
done
for angle in contrarian first-principles expansionist outsider executor; do
  grep -q "^- \*\*$angle\*\*:" "$P/agents/council-advisor.md" && ok "advisor angle $angle defined" || bad "advisor angle $angle defined"
done
grep -q 'AGAINST MY POSITION:' "$P/agents/council-advisor.md" && grep -q 'AGAINST MY POSITION:' "$P/agents/council-red-team.md" \
  && ok "advisors and red team argue against themselves" || bad "advisors and red team argue against themselves"
head -8 "$SK" | grep -q 'scripts/anonymize.sh' && head -8 "$SK" | grep -q 'scripts/save_notes.sh' \
  && ok "allowed-tools pre-approves both scripts" || bad "allowed-tools pre-approves both scripts"
grep -q -- '--quick' "$SK" && grep -q -- '--no-notes' "$SK" && ok "flags documented in SKILL.md" || bad "flags documented in SKILL.md"
models="$(grep -o '`\(opus\|sonnet\|haiku\)`' "$SK" | sort -u | wc -l | tr -d ' ')"
[ "$models" -ge 2 ] && ok "SKILL.md spreads advisors over >= 2 models" || bad "SKILL.md spreads advisors over >= 2 models ($models)"

grep -q 'run_in_background: false' "$SK" && ok "subagents run in the foreground (one turn keeps pre-approvals)" || bad "subagents run in the foreground (one turn keeps pre-approvals)"

for a in council-advisor council-red-team council-reviewer council-chairman; do
  fm "$P/agents/$a.md" | grep -q "^effort: " && ok "$a sets its own effort (not the clerk's low effort)" || bad "$a sets its own effort"
done
grep -q -- '---DETAILS---' "$P/agents/council-chairman.md" && grep -q 'Never print part 2' "$SK" \
  && ok "chairman details go only to the notes" || bad "chairman details go only to the notes"
grep -q 'red team | `opus`, only if all advisors gave the same token | none |' "$SK" && ok "no red team in quick mode" || bad "no red team in quick mode"

echo "passed: $PASS  failed: $FAIL"
[ $FAIL -eq 0 ]
