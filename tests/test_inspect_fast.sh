#!/usr/bin/env bash
# The run inspector recognises a fast-path run and checks it (synthetic transcript, no model calls).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
mk() { # $1 = final answer text, $2 = solo reply
python3 - "$1" "$2" > "$T/run.jsonl" <<'PY'
import json, sys
final, solo = sys.argv[1], sys.argv[2]
ev = [
 {"type":"system","subtype":"init","model":"claude-opus-5-5"},
 {"type":"assistant","message":{"id":"m1","content":[{"type":"text","text":"== BRIEF ==\nRemoved framing: \"keep the peace\"\nRoute: fast — council skipped: free, reversible, one clear answer. Use --full for the whole council."}]}},
 {"type":"assistant","message":{"id":"m2","content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"subagent_type":"llm-council:council-solo","model":"opus","run_in_background":False,"description":"fast answer","prompt":"Language: en\nTriage: free\n\nDecision brief:\nDecide whether to require 2FA."}}]}},
 {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":solo}]}},
 {"type":"assistant","message":{"id":"m3","content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"bash /x/scripts/save_notes.sh require-2fa none <<'E'\nnotes\nE"}}]}},
 {"type":"assistant","message":{"id":"m4","content":[{"type":"text","text":final}]}},
 {"type":"result","total_cost_usd":0.3},
]
for e in ev: print(json.dumps(e, ensure_ascii=False))
PY
}
GOOD='== ANSWER ==
VERDICT: GO — Require 2FA for all 12 accounts this week.
WHY:
- Ten minutes each, free, and reversible.
BIGGEST RISK: Someone gets locked out.
NEXT STEPS:
1. Turn it on — success: 12/12 by Friday / stop if: a lockout lasts over a day.
WOULD CHANGE IT: Nothing in the brief.

Council skipped (simple question). Full notes: council-notes/2026-09-28-require-2fa.md'
SOLO='VERDICT: GO — Require 2FA.
---DETAILS---
CRUX: cost vs risk'
mk "$GOOD" "$SOLO"
out="$(python3 "$HERE/inspect_run.py" "$T/run.jsonl" "keep the peace" --lang en --json "$T/r.json")"; rc=$?
[ $rc -eq 0 ] && ok "fast-path run passes the inspector" || { bad "fast-path run passes the inspector"; echo "$out" | grep FAIL; }
python3 -c "import json;r=json.load(open('$T/r.json'));assert r['route']=='fast' and r['verdict']=='GO'" 2>/dev/null && ok "inspector reports route=fast and the verdict" || bad "inspector reports route=fast and the verdict"

mk "${GOOD/== ANSWER ==/}" "$SOLO"
python3 "$HERE/inspect_run.py" "$T/run.jsonl" "keep the peace" --lang en >/dev/null; [ $? -ne 0 ] && ok "missing == ANSWER == fails" || bad "missing == ANSWER == fails"
mk "$GOOD
---DETAILS---
CRUX: x" "$SOLO"
python3 "$HERE/inspect_run.py" "$T/run.jsonl" "keep the peace" --lang en >/dev/null; [ $? -ne 0 ] && ok "printed details fail" || bad "printed details fail"
echo "passed: $PASS  failed: $FAIL"
[ $FAIL -eq 0 ]
