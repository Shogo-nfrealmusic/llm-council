#!/usr/bin/env python3
"""Inspect a `claude -p --output-format stream-json --verbose` log of an /llm-council run.

Usage: python3 tests/inspect_run.py RUN.jsonl "phrase from the user's original wording" [--transcript OUT.md]

Checks:
  - advisors: 5 subagent calls issued in ONE assistant message (parallel, separate contexts)
  - reviewers: prompts contain no persona names and no KEY section
  - no subagent prompt contains the user's original framing phrase
  - chairman: one subagent call with no model override (inherits session model)
Writes a readable transcript (all assistant text in order) if --transcript is given.
"""
import json, re, sys

PERSONAS = re.compile(r"contrarian|first[- ]principles|expansionist|outsider|executor", re.I)

def load(path):
    return [json.loads(l) for l in open(path) if l.strip().startswith("{")]

def main():
    path, phrase = sys.argv[1], sys.argv[2]
    out = sys.argv[sys.argv.index("--transcript") + 1] if "--transcript" in sys.argv else None
    events = load(path)
    batches, texts = [], []
    for e in events:
        if e.get("type") != "assistant" or e.get("parent_tool_use_id"):
            continue
        content = e["message"].get("content", [])
        calls = [c for c in content if c.get("type") == "tool_use" and c["name"] in ("Agent", "Task")]
        if calls:
            batches.append((e["message"].get("id"), calls))
        for c in content:
            if c.get("type") == "text" and c["text"].strip():
                texts.append(c["text"].strip())
    # merge tool_use blocks that belong to the same API message id
    merged = {}
    order = []
    for mid, calls in batches:
        if mid not in merged:
            merged[mid] = []
            order.append(mid)
        merged[mid].extend(calls)
    groups = [merged[m] for m in order]

    ok = True
    def check(cond, msg):
        nonlocal ok
        print(("  ok   - " if cond else "  FAIL - ") + msg)
        ok &= bool(cond)

    print(f"subagent call groups (per assistant message): {[len(g) for g in groups]}")
    allcalls = [c for g in groups for c in g]
    for c in allcalls:
        i = c["input"]
        print(f"    - type={i.get('subagent_type')} model={i.get('model', '(inherit)')} desc={i.get('description')!r}")

    adv = next((g for g in groups if len(g) == 5), None)
    check(adv is not None, "5 advisor subagents issued in a single message (parallel)")
    rev = next((g for g in groups if len(g) == 3), None)
    check(rev is not None, "3 reviewer subagents issued in a single message")
    if rev:
        for n, c in enumerate(rev, 1):
            p = c["input"].get("prompt", "")
            hits = sorted(set(m.lower() for m in PERSONAS.findall(p)))
            check(not hits, f"reviewer {n} prompt has no persona names {hits if hits else ''}")
            check("### KEY" not in p and not re.search(r"^[A-E] = ", p, re.M), f"reviewer {n} prompt has no KEY")
            check(all(f"=== ANSWER {L} ===" in p for L in "ABCDE"), f"reviewer {n} prompt has answers A-E")
    chair = [c for g in groups if len(g) == 1 for c in g]
    check(len(chair) >= 1, "chairman subagent issued")
    if chair:
        check("model" not in chair[-1]["input"], "chairman inherits session model (no override)")
    leaked = [c["input"].get("description") for c in allcalls if phrase.lower() in c["input"].get("prompt", "").lower()]
    check(not leaked, f"no subagent prompt contains the original framing {phrase!r} {leaked if leaked else ''}")

    anon = [e for e in events if e.get("type") == "user"]
    bash_ok = any("### PACKET" in json.dumps(e) for e in anon)
    check(bash_ok, "anonymize.sh ran and returned a PACKET")

    alltext = "\n".join(texts)
    pos = [alltext.find(h) for h in ("== BRIEF ==", "== ADVISORS ==", "== PEER REVIEW", "== CHAIRMAN ==")]
    check(all(p >= 0 for p in pos) and pos == sorted(pos), f"visible output has BRIEF, ADVISORS, PEER REVIEW, CHAIRMAN in order {pos}")

    res = events[-1]
    print(f"result: {res.get('subtype')}  cost_usd(list)={res.get('total_cost_usd')}  duration_ms={res.get('duration_ms')}")
    if out:
        with open(out, "w") as f:
            f.write("\n\n".join(texts) + "\n")
        print(f"transcript written: {out}")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
