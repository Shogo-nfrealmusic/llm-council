#!/usr/bin/env bash
# Run one real /llm-council (or plain baseline) in a fresh scratch folder and time it.
# usage: eval/run_council.sh <outdir> <council|quick|baseline> "<question>" [extra claude args...]
# The scratch folder has no CLAUDE.md unless the caller puts one there (see leak test).
set -u
out="$1"; kind="$2"; q="$3"; shift 3
REPO="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out/work"
cd "$out/work"
start=$(python3 -c 'import time;print(time.time())')
case "$kind" in
  council)  claude -p "/llm-council $q" --plugin-dir "$REPO/plugins/llm-council" --output-format stream-json --verbose "$@" < /dev/null > "$out/run.jsonl" 2> "$out/stderr.txt" ;;
  quick)    claude -p "/llm-council --quick $q" --plugin-dir "$REPO/plugins/llm-council" --output-format stream-json --verbose "$@" < /dev/null > "$out/run.jsonl" 2> "$out/stderr.txt" ;;
  baseline) claude -p "$q" --output-format stream-json --verbose "$@" < /dev/null > "$out/run.jsonl" 2> "$out/stderr.txt" ;;
esac
rc=$?
end=$(python3 -c 'import time;print(time.time())')
python3 - "$out" "$start" "$end" "$rc" <<'PY'
import json, sys
out, s, e, rc = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), int(sys.argv[4])
ev = [json.loads(l) for l in open(out + "/run.jsonl") if l.startswith("{")]
res = [x for x in ev if x.get("type") == "result"]
init = next((x for x in ev if x.get("type") == "system" and x.get("subtype") == "init"), {})
texts = []
for x in ev:
    if x.get("type") == "assistant" and not x.get("parent_tool_use_id"):
        for c in x["message"].get("content", []):
            if c.get("type") == "text" and c["text"].strip():
                texts.append(c["text"].strip())
open(out + "/visible.txt", "w").write("\n\n".join(texts) + "\n")
usage = {}
for r in res:
    for k, v in (r.get("modelUsage") or {}).items():
        usage[k] = v.get("costUSD")
meta = {"wall_s": round(e - s, 1), "rc": rc, "session_model": init.get("model"),
        "cost_usd_list": max((r.get("total_cost_usd") or 0) for r in res) if res else None,
        "cost_by_model": usage, "n_results": len(res)}
json.dump(meta, open(out + "/meta.json", "w"), indent=1)
print(json.dumps(meta))
PY
