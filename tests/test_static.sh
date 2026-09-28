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

for a in council-advisor council-red-team council-reviewer council-chairman council-chairman-quick; do
  fm "$P/agents/$a.md" | grep -q "^effort: " && ok "$a sets its own effort (not the clerk's low effort)" || bad "$a sets its own effort"
done
grep -q -- '---DETAILS---' "$P/agents/council-chairman.md" && grep -q 'Never print part 2' "$SK" \
  && ok "chairman details go only to the notes" || bad "chairman details go only to the notes"
grep -q 'red team | `opus`, only if all advisors gave the same token | none |' "$SK" && ok "no red team in quick mode" || bad "no red team in quick mode"

body() { awk 'BEGIN{n=0} /^---$/{n++; if(n==2){f=1; next}} f' "$1"; }
[ "$(body "$P/agents/council-chairman.md")" = "$(body "$P/agents/council-chairman-quick.md")" ] \
  && ok "quick chairman has the same instructions as the chairman" || bad "quick chairman has the same instructions as the chairman"
fm "$P/agents/council-chairman-quick.md" | grep -qx "omitClaudeMd: true" && ok "quick chairman starts without CLAUDE.md" || bad "quick chairman starts without CLAUDE.md"

# v3: triage / fast path
S="$P/agents/council-solo.md"
[ -f "$S" ] && ok "fast-path agent council-solo exists" || bad "fast-path agent council-solo exists"
fm "$S" 2>/dev/null | grep -qx "name: council-solo" && ok "council-solo: name matches file" || bad "council-solo: name matches file"
fm "$S" 2>/dev/null | grep -qx "omitClaudeMd: true" && ok "council-solo: starts without CLAUDE.md" || bad "council-solo: starts without CLAUDE.md"
fm "$S" 2>/dev/null | grep -qx "tools: \[\]" && ok "council-solo: no tools" || bad "council-solo: no tools"
fm "$S" 2>/dev/null | grep -q "^effort: " && ok "council-solo sets its own effort" || bad "council-solo sets its own effort"
grep -qi "ignore them" "$S" 2>/dev/null && ok "council-solo: told to ignore project instructions" || bad "council-solo: told to ignore project instructions"
grep -q '^ESCALATE:' "$S" 2>/dev/null && grep -q 'ESCALATE' "$SK" && ok "fast path can hand back to the full council (ESCALATE)" || bad "fast path can hand back to the full council (ESCALATE)"
grep -q '## Stage 0.5 — Triage' "$SK" && ok "SKILL.md has a triage stage" || bad "SKILL.md has a triage stage"
grep -q -- '--full' "$SK" && grep -q -- '--fast' "$SK" && ok "--full / --fast flags documented" || bad "--full / --fast flags documented"
grep -q 'council-solo' "$SK" && ok "SKILL.md uses council-solo" || bad "SKILL.md uses council-solo"
grep -q 'Route: fast' "$SK" && grep -q '経路: 簡易' "$SK" && ok "fast route is announced (en/ja)" || bad "fast route is announced (en/ja)"
grep -q 'VERDICT:' "$S" 2>/dev/null && ok "fast path uses the same VERDICT format" || bad "fast path uses the same VERDICT format"
# v3: chairman tests the asker's own plan first and answers the red team
grep -q "Start from the person's own plan" "$P/agents/council-chairman.md" && ok "chairman tests the asker's plan before the votes" || bad "chairman tests the asker's plan before the votes"
grep -q "which fact defeats it" "$P/agents/council-chairman.md" && ok "chairman must answer a rejected red team with a fact" || bad "chairman must answer a rejected red team with a fact"
grep -q "Start from the person's own plan" "$S" 2>/dev/null && ok "fast path runs the same plan-first test" || bad "fast path runs the same plan-first test"

grep -q 'bash "${CLAUDE_SKILL_DIR}/scripts/save_notes.sh" <slug> none <<' "$SK" && ok "fast path gives the literal save command (pre-approved pattern)" || bad "fast path gives the literal save command (pre-approved pattern)"
grep -q 'more than 14 non-empty lines' "$SK" && ok "fast answer over-length triggers one retry" || bad "fast answer over-length triggers one retry"
echo "passed: $PASS  failed: $FAIL"
[ $FAIL -eq 0 ]
