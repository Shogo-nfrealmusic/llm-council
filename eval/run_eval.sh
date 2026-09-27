#!/usr/bin/env bash
# Run the whole eval for real: baseline + council for every case, then inspect.
# usage: eval/run_eval.sh <results_dir> [parallel=3]
# Each run happens in its own fresh folder with no CLAUDE.md.
set -u
rd="$1"; par="${2:-3}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$rd"
jobs_file="$rd/jobs.txt"; : > "$jobs_file"
python3 - "$HERE/cases.json" "$rd" > "$jobs_file" <<'PY'
import json, sys
for c in json.load(open(sys.argv[1])):
    for kind in ("baseline", "council"):
        print("\t".join([c["id"], kind, c["question"]]))
PY
run_one() {
  id="$1"; kind="$2"; q="$3"
  out="$rd/$id/$kind"
  [ -f "$out/meta.json" ] && { echo "skip $id $kind"; return; }
  "$HERE/run_council.sh" "$out" "$kind" "$q" > "$out.log" 2>&1
  echo "done $id $kind $(cat "$out/meta.json" 2>/dev/null)"
}
while IFS=$'\t' read -r id kind q; do
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$par" ]; do sleep 2; done
  mkdir -p "$rd/$id"
  run_one "$id" "$kind" "$q" &
done < "$jobs_file"
wait
python3 - "$HERE/cases.json" "$rd" "$HERE/../tests/inspect_run.py" <<'PY'
import json, subprocess, sys
cases, rd, insp = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
for c in cases:
    out = f"{rd}/{c['id']}/council"
    r = subprocess.run(["python3", insp, f"{out}/run.jsonl", c["phrase"], "--lang", c["lang"], "--json", f"{out}/inspect.json"],
                       capture_output=True, text=True)
    fails = [l for l in r.stdout.splitlines() if "FAIL" in l]
    j = json.load(open(f"{out}/inspect.json"))
    m = json.load(open(f"{out}/meta.json"))
    print(f"{c['id']:18s} inspector={'PASS' if j['ok'] else 'FAIL'} wall={m['wall_s']}s cost=${(m['cost_usd_list'] or 0):.2f} "
          f"positions={j.get('positions')} red_team={j.get('red_team')} verdict={j.get('verdict')}")
    for l in fails: print("    " + l)
PY
