#!/usr/bin/env python3
"""Inspect a `claude -p --output-format stream-json --verbose` log of an /llm-council run.

Usage:
  python3 tests/inspect_run.py RUN.jsonl "phrase from the user's original wording"
      [--lang ja|en] [--no-notes] [--transcript OUT.md] [--json OUT.json]

Checks:
  - advisors: 3 (quick) or 5 (standard) subagent calls in ONE assistant message, on >= 2 models
  - red team: spawned exactly when every advisor gave the same POSITION token, and shown
  - reviewers: 1 (quick) or 3 (standard) in one message; no persona names, no KEY, all labels
  - chairman: standard = opus; quick = sonnet
  - no subagent prompt contains the user's original framing or the "Removed framing" line
  - every subagent is one of the plugin's council agents (they start without CLAUDE.md)
  - anonymize.sh returned a PACKET; save_notes.sh ran and the last line names the file
  - visible output has BRIEF, CHAIRMAN, ADVISORS, PEER REVIEW in order (exactly 2 messages)
  - --lang ja: brief, advisors and chairman are mostly Japanese; --lang en: no Japanese
"""
import json, re, sys

PERSONAS = re.compile(r"contrarian|first[- ]principles|expansionist|outsider|executor|red[- ]team", re.I)
TOKENS = re.compile(r"\b(NO-GO|GO|CHANGE)\b")
JA = re.compile(r"[぀-ヿ一-鿿]")
def kind(c):
    t = (c["input"].get("subagent_type") or "").split(":")[-1]
    return t.replace("council-", "") if t.startswith("council-") else "other:" + t


def load(path):
    return [json.loads(l) for l in open(path) if l.strip().startswith("{")]


def ja_ratio(s):
    letters = [c for c in s if c.isalpha()]
    return (len(JA.findall(s)) / len(letters)) if letters else 0.0


def section(text, start, end=None):
    i = text.find(start)
    if i < 0:
        return ""
    j = text.find(end, i + len(start)) if end else -1
    return text[i: j if j > 0 else len(text)]


def main():
    args = sys.argv[1:]
    path, phrase = args[0], args[1]
    opt = lambda k: args[args.index(k) + 1] if k in args else None
    lang, out, jout = opt("--lang"), opt("--transcript"), opt("--json")
    no_notes = "--no-notes" in args
    events = load(path)

    batches, texts, bash_calls = [], [], []
    for e in events:
        if e.get("type") != "assistant" or e.get("parent_tool_use_id"):
            continue
        content = e["message"].get("content", [])
        calls = [c for c in content if c.get("type") == "tool_use" and c["name"] in ("Agent", "Task")]
        if calls:
            batches.append((e["message"].get("id"), calls))
        for c in content:
            if c.get("type") == "tool_use" and c["name"] == "Bash":
                bash_calls.append(c["input"].get("command", ""))
            if c.get("type") == "text" and c["text"].strip():
                texts.append(c["text"].strip())
    merged, order = {}, []
    for mid, calls in batches:
        if mid not in merged:
            merged[mid] = []
            order.append(mid)
        merged[mid].extend(calls)
    groups = [merged[m] for m in order]
    allcalls = [c for g in groups for c in g]

    ok = True
    report = {"checks": []}

    def check(cond, msg):
        nonlocal ok
        print(("  ok   - " if cond else "  FAIL - ") + msg)
        report["checks"].append({"ok": bool(cond), "msg": msg})
        ok &= bool(cond)

    print(f"subagent call groups (per assistant message): {[len(g) for g in groups]}")
    for c in allcalls:
        i = c["input"]
        print(f"    - type={i.get('subagent_type')} model={i.get('model', '(inherit)')} desc={i.get('description')!r}")

    adv = next((g for g in groups if all(kind(c) == "advisor" for c in g)), None)
    adv = adv if adv and len(adv) in (3, 5) else None
    check(adv is not None, "advisors (3 or 5) issued in a single message (parallel)")
    quick = bool(adv) and len(adv) == 3
    mode = "quick" if quick else "standard"
    report["mode"] = mode
    if adv:
        models = {c["input"].get("model", "(inherit)") for c in adv}
        check(len(models) >= 2, f"advisors spread over >= 2 models {sorted(models)}")
    bg = [c["input"].get("description") for c in allcalls if c["input"].get("run_in_background") is not False]
    check(not bg, f"every subagent call passes run_in_background: false (one turn) {bg if bg else ''}")
    report["agent_types"] = sorted({c["input"].get("subagent_type") or "" for c in allcalls})

    redteam = [c for c in allcalls if kind(c) == "red-team"]
    n_rev = 1 if quick else 3
    rev = next((g for g in groups if len(g) == n_rev and all(kind(c) == "reviewer" for c in g)), None)
    check(rev is not None, f"{n_rev} reviewer subagent(s) issued in a single message")
    n_answers = (len(adv) if adv else 0) + len(redteam)
    labels = "ABCDEF"[:n_answers]
    if rev:
        for n, c in enumerate(rev, 1):
            p = c["input"].get("prompt", "")
            hits = sorted(set(m.lower() for m in PERSONAS.findall(p)))
            check(not hits, f"reviewer {n} prompt has no persona names {hits if hits else ''}")
            check("### KEY" not in p and not re.search(r"\b[A-F] = ", p), f"reviewer {n} prompt has no KEY")
            check(re.search(r"Answers file: \S+/\.llm-council-work/run\.\w+/packet\.md", p) is not None,
                  f"reviewer {n} prompt points at the packet file")
            check(all(L in p.split("Labels:")[1].split("\n")[0] for L in (labels[0], labels[-1])) if "Labels:" in p else False,
                  f"reviewer {n} told labels {labels[0]}-{labels[-1]}")

    chair = [c for c in allcalls if kind(c) == "chairman"]
    check(len(chair) == 1, "one chairman subagent issued")
    if chair:
        m = chair[0]["input"].get("model")
        if quick:
            check(m == "sonnet", f"quick chairman on sonnet (got {m})")
        else:
            check(m == "opus", f"standard chairman on opus (got {m})")

    leaked = [c["input"].get("description") for c in allcalls if phrase.lower() in c["input"].get("prompt", "").lower()]
    check(not leaked, f"no subagent prompt contains the original framing {phrase!r} {leaked if leaked else ''}")
    rf = [c["input"].get("description") for c in allcalls
          if re.search(r"removed framing|取り除いた言い回し", c["input"].get("prompt", ""), re.I)]
    check(not rf, f"no subagent prompt contains the 'Removed framing' line {rf if rf else ''}")
    other = [c["input"].get("subagent_type") for c in allcalls if kind(c).startswith("other:")]
    check(not other, f"every subagent is a council agent (no CLAUDE.md) {other if other else ''}")

    results = json.dumps([e for e in events if e.get("type") == "user"])
    check("### PACKET FILE:" in results, "anonymize.sh ran and wrote a packet file")

    alltext = "\n".join(texts)
    report["visible_messages"] = len(texts)
    check(len(texts) == 2, f"exactly 2 visible messages (BRIEF, final report) — got {len(texts)}")
    pos = [alltext.find(h) for h in ("== BRIEF ==", "== CHAIRMAN ==", "== ADVISORS ==", "== PEER REVIEW")]
    check(all(p >= 0 for p in pos) and pos == sorted(pos), f"visible output has BRIEF, CHAIRMAN, ADVISORS, PEER REVIEW in order {pos}")

    # Positions from the visible ADVISORS block.
    advblock = section(alltext, "== ADVISORS ==", "== PEER REVIEW")
    rows = [l for l in advblock.splitlines()[1:] if TOKENS.search(l) and re.search(r"\d+%", l)]
    red_rows = [l for l in rows if re.match(r"\s*(red-team|レッドチーム)\s", l)]
    main_rows = [l for l in rows if l not in red_rows]
    toks = [TOKENS.search(l).group(1) for l in main_rows]
    report["positions"] = toks
    unanimous = bool(toks) and len(set(toks)) == 1
    report["unanimous"] = unanimous
    report["red_team"] = bool(redteam)
    if adv:
        check(len(toks) == len(adv), f"ADVISORS block shows all {len(adv)} advisors (found {len(toks)})")
    check(bool(redteam) == unanimous, f"red team spawned iff unanimous (unanimous={unanimous}, spawned={bool(redteam)})")
    if redteam:
        check(len(red_rows) == 1, "red-team line shown in ADVISORS block")
        rt_tok = TOKENS.search(red_rows[0]).group(1) if red_rows else None
        check(rt_tok is not None and bool(toks) and rt_tok != toks[0],
              f"red team took a different position ({rt_tok} vs {toks[0] if toks else None})")
    check(bool(re.search(r"Red team:|レッドチーム:", advblock)), "ADVISORS block states red-team status")

    chairtext = section(alltext, "== CHAIRMAN ==", "== ADVISORS ==")
    vm = re.search(r"VERDICT:\s*(GO|NO-GO|CHANGE IT)", chairtext)
    report["verdict"] = vm.group(1) if vm else None
    check(vm is not None, f"chairman gave a verdict ({report['verdict']})")

    last = alltext.strip().splitlines()[-1] if alltext.strip() else ""
    if no_notes:
        saves = [b for b in bash_calls if "save_notes.sh" in b]
        check(bool(saves) and all("--discard" in b for b in saves), "with --no-notes, only save_notes.sh --discard ran")
    else:
        check(any("save_notes.sh" in b for b in bash_calls), "save_notes.sh ran")
        m = re.search(r"(council-notes/\S+\.md)", last)
        check(m is not None, f"last line names the notes file ({last[:80]!r})")
        report["notes"] = m.group(1) if m else None

    if lang:
        brief = section(alltext, "== BRIEF ==", "== CHAIRMAN ==")
        body = brief + advblock + chairtext
        body = re.sub(r"==[^=\n]+==|VERDICT|NO-GO|CHANGE IT|CHANGE|GO|red-team|Red team|council-notes/\S+|opus|sonnet|haiku", "", body)
        r = ja_ratio(body)
        report["ja_ratio"] = round(r, 2)
        if lang == "ja":
            check(r > 0.6, f"visible output is Japanese (ja ratio {r:.2f})")
        else:
            check(r < 0.02, f"visible output is not Japanese (ja ratio {r:.2f})")

    res = [e for e in events if e.get("type") == "result"]
    cost = max((e.get("total_cost_usd") or 0) for e in res) if res else None
    report["cost_usd_list"] = cost
    report["ok"] = ok
    print(f"results: {len(res)}  cost_usd(list)={cost}  mode={mode}  positions={toks}  red_team={bool(redteam)}  verdict={report['verdict']}")
    if out:
        with open(out, "w") as f:
            f.write("\n\n".join(texts) + "\n")
        print(f"transcript written: {out}")
    if jout:
        with open(jout, "w") as f:
            json.dump(report, f, ensure_ascii=False, indent=1)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
