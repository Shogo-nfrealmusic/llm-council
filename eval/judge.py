#!/usr/bin/env python3
"""Blind judge v2: normalize both answers, then score them without knowing which is which.

usage: python3 eval/judge.py <results_dir> [--rounds N] [--cases id1,id2]

For each case in eval/cases.json:
  1. Normalize. A neutral `claude -p` session (Sonnet, no tools) rewrites each answer
     (<dir>/<case>/{baseline,council}/visible.txt) into the SAME plain template and the
     SAME length budget, keeping its substance and removing process artifacts (section
     headers, advisor names, rankings, file paths). It also classifies the recommendation
     as GO / CHANGE / NO-GO. Cached in normalized-{baseline,council}.json.
  2. Judge. A fresh `claude -p` session (no tools) sees the question and the two
     normalized answers as "Advice 1" / "Advice 2" in random order and scores both on
     5 neutral criteria (0-10). N rounds per case (default 3), each with its own order.
  3. Verdict correctness: the recommendation class (council: its VERDICT token;
     baseline: the normalizer's class) against the case's pre-registered right_call.
  4. Raw readability (NOT blind, reported separately): one extra call per case that sees
     both raw outputs and scores only terminal readability.
Writes <dir>/<case>/judge2-<k>.json, <dir>/judge2-summary.json, prints a table.
(The earlier v1 judge, which scored raw outputs on a rubric mirroring the chairman's
fields, is kept as eval/judge_v1.py for the record.)
"""
import json, os, random, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = tempfile.mkdtemp(prefix="llm-council-judge-")

CRITERIA = [
    ("useful", "Usefulness: if a smart, experienced friend gave you this advice about this decision, how useful would it be?"),
    ("right_call", "Correct call: given only the facts in the question, is the recommendation right? Penalize both going along with a bad idea and blocking a good one."),
    ("actionable", "Actionability: could the person act on it this week and know whether it worked?"),
    ("honest", "Honesty: calibrated, does not invent facts or numbers as if given, names what is unknown, neither flatters nor reflexively opposes the asker."),
    ("clear", "Clarity: easy to follow; no padding; says what to do plainly."),
]

NORMALIZE = """You are a neutral editor. Rewrite the ADVICE below into the exact template, in the same language as the QUESTION ({lang}).

Rules:
- Keep the substance: the recommendation, the reasons, the risks, the unknowns, and the concrete steps with their numbers, dates and thresholds.
- Do not add, correct, improve, or soften anything. If something is missing, leave it missing.
- Remove process artifacts only: section headers like "== ... ==", labels such as VERDICT / BRIEF / Removed framing, names of advisors or roles, rankings, votes, mentions of a council, red team, reviewers or chairman, file paths and notes about saved files.
- Keep within {budget}. If the advice is longer, compress it evenly, keeping the most decision-relevant points.
- Then classify the recommendation: GO = proceed with the asker's plan as proposed (possibly with safeguards); CHANGE = do a materially different plan (different size, timing, target or method); NO-GO = do not do it.

QUESTION:
<<<
{question}
>>>

ADVICE:
<<<
{advice}
>>>

Reply with ONLY a JSON object: {{"class": "GO" | "CHANGE" | "NO-GO", "text": "<the rewritten advice, using \\n for new lines>"}}

Template for "text" ({lang}):
{template}
"""

TEMPLATE = {
    "en": "Recommendation: <one or two sentences>\nWhy:\n- <point>\n- <point>\nRisks and unknowns:\n- <point>\nNext steps:\n1. <step>\n2. <step>\n3. <step>",
    "ja": "結論: <1〜2文>\n理由:\n- <要点>\n- <要点>\nリスクと不明点:\n- <要点>\n次の一手:\n1. <行動>\n2. <行動>\n3. <行動>",
}
BUDGET = {"en": "220 words", "ja": "550 Japanese characters"}

JUDGE = """You are a strict evaluator of decision advice. A person asked the question below. Two advisors answered; both answers were rewritten by a neutral editor into the same plain format and length, so judge the content, not the formatting. Score each answer independently, 0 to 10 per criterion (10 = excellent, 5 = mediocre, 0 = absent or wrong). Reserve 9-10 for advice a demanding expert would sign off on without changes.

QUESTION (verbatim, including the asker's framing):
<<<
{question}
>>>

ADVICE 1:
<<<
{a1}
>>>

ADVICE 2:
<<<
{a2}
>>>

CRITERIA:
{criteria}

Reply with ONLY a JSON object, no prose:
{{"advice_1": {{{keys}}}, "advice_2": {{{keys}}}, "better": 1 or 2, "why": "<one or two sentences>"}}
"""

RAWREAD = """Two raw terminal outputs answer the same question. Score ONLY how easy each is to read and act on in a terminal (0-10): length appropriate to the stakes, the answer easy to find, no clutter. Ignore whether the advice is right.

QUESTION:
<<<
{question}
>>>

OUTPUT 1:
<<<
{a1}
>>>

OUTPUT 2:
<<<
{a2}
>>>

Reply with ONLY a JSON object: {{"output_1": <0-10>, "output_2": <0-10>}}
"""


def claude_json(prompt, model=None, check=lambda r: True, tries=3):
    cmd = ["claude", "-p", prompt, "--tools", "", "--output-format", "json"]
    if model:
        cmd += ["--model", model]
    for _ in range(tries):
        r = subprocess.run(cmd, cwd=WORK, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=600)
        try:
            out = json.loads(r.stdout)
            m = re.search(r"\{.*\}", out.get("result", ""), re.S)
            res = json.loads(m.group(0))
        except (ValueError, AttributeError):
            continue
        if check(res):
            return res
    raise RuntimeError("no valid JSON from claude -p")


def normalized(rd, case, kind):
    path = os.path.join(rd, case["id"], f"normalized-{kind}.json")
    if os.path.exists(path):
        return json.load(open(path))
    raw = open(os.path.join(rd, case["id"], kind, "visible.txt")).read().strip()
    res = claude_json(NORMALIZE.format(lang=case["lang"], budget=BUDGET[case["lang"]], question=case["question"],
                                       advice=raw, template=TEMPLATE[case["lang"]]),
                      model="sonnet", check=lambda r: r.get("class") in ("GO", "CHANGE", "NO-GO") and len(r.get("text", "")) > 40)
    json.dump(res, open(path, "w"), ensure_ascii=False, indent=1)
    return res


def council_verdict(rd, case):
    t = open(os.path.join(rd, case["id"], "council", "visible.txt")).read()
    m = re.search(r"VERDICT:\s*(GO|NO-GO|CHANGE IT)", t)
    return {"CHANGE IT": "CHANGE"}.get(m.group(1), m.group(1)) if m else None


def main():
    rd = sys.argv[1]
    rounds = int(sys.argv[sys.argv.index("--rounds") + 1]) if "--rounds" in sys.argv else 3
    only = sys.argv[sys.argv.index("--cases") + 1].split(",") if "--cases" in sys.argv else None
    cases = [c for c in json.load(open(os.path.join(HERE, "cases.json"))) if not only or c["id"] in only]
    keys = [k for k, _ in CRITERIA]
    crit_text = "\n".join(f"- {k}: {d}" for k, d in CRITERIA)
    kjson = ", ".join(f'"{k}": <0-10>' for k in keys)
    ok = lambda r: r.get("better") in (1, 2) and all(
        isinstance(r.get(a), dict) and all(isinstance(r[a].get(k), (int, float)) for k in keys) for a in ("advice_1", "advice_2"))
    rows, per_case = [], []
    for c in cases:
        nb, nc = normalized(rd, c, "baseline"), normalized(rd, c, "council")
        cv = council_verdict(rd, c)
        ctot, btot = [], []
        for k in range(rounds):
            council_first = random.Random(f"{c['id']}-v2-{k}").random() < 0.5
            a1, a2 = (nc["text"], nb["text"]) if council_first else (nb["text"], nc["text"])
            res = claude_json(JUDGE.format(question=c["question"], a1=a1, a2=a2, criteria=crit_text, keys=kjson), check=ok)
            cs, bs = (res["advice_1"], res["advice_2"]) if council_first else (res["advice_2"], res["advice_1"])
            rec = {"case": c["id"], "round": k, "council_was": 1 if council_first else 2, "council": cs, "baseline": bs,
                   "council_100": sum(cs[x] for x in keys) * 2, "baseline_100": sum(bs[x] for x in keys) * 2,
                   "judge_prefers": "council" if (res["better"] == 1) == council_first else "baseline", "why": res.get("why")}
            json.dump(rec, open(os.path.join(rd, c["id"], f"judge2-{k}.json"), "w"), ensure_ascii=False, indent=1)
            rows.append(rec)
            ctot.append(rec["council_100"]); btot.append(rec["baseline_100"])
        rawc = open(os.path.join(rd, c["id"], "council", "visible.txt")).read().strip()
        rawb = open(os.path.join(rd, c["id"], "baseline", "visible.txt")).read().strip()
        cf = random.Random(f"{c['id']}-raw").random() < 0.5
        rr = claude_json(RAWREAD.format(question=c["question"], a1=rawc if cf else rawb, a2=rawb if cf else rawc),
                         check=lambda r: isinstance(r.get("output_1"), (int, float)) and isinstance(r.get("output_2"), (int, float)))
        raw_c, raw_b = (rr["output_1"], rr["output_2"]) if cf else (rr["output_2"], rr["output_1"])
        pc = {"case": c["id"], "lang": c["lang"], "right_call": c["right_call"],
              "council_verdict": cv, "council_correct": cv in c["right_call"],
              "council_class_by_normalizer": nc["class"],
              "baseline_class": nb["class"], "baseline_correct": nb["class"] in c["right_call"],
              "council_100": round(sum(ctot) / rounds, 1), "baseline_100": round(sum(btot) / rounds, 1),
              "raw_readability_council": raw_c, "raw_readability_baseline": raw_b}
        per_case.append(pc)
        print(f"{c['id']:18s} right={'/'.join(c['right_call']):9s} council={cv or '-':7s}{'ok ' if pc['council_correct'] else 'X  '}"
              f"baseline={nb['class']:7s}{'ok ' if pc['baseline_correct'] else 'X  '}"
              f"score council {pc['council_100']:5.1f} vs {pc['baseline_100']:5.1f}  raw-read {raw_c} vs {raw_b}", flush=True)
    n = len(per_case)
    summary = {
        "cases": n, "rounds": rounds,
        "council_avg_100": round(sum(p["council_100"] for p in per_case) / n, 1),
        "baseline_avg_100": round(sum(p["baseline_100"] for p in per_case) / n, 1),
        "council_higher_cases": sum(p["council_100"] > p["baseline_100"] for p in per_case),
        "ties": sum(p["council_100"] == p["baseline_100"] for p in per_case),
        "judgements_council_higher": sum(r["council_100"] > r["baseline_100"] for r in rows),
        "judgements": len(rows),
        "judge_prefers_council": sum(r["judge_prefers"] == "council" for r in rows),
        "council_correct_calls": sum(p["council_correct"] for p in per_case),
        "baseline_correct_calls": sum(p["baseline_correct"] for p in per_case),
        "per_criterion_council": {k: round(sum(r["council"][k] for r in rows) / len(rows), 2) for k in keys},
        "per_criterion_baseline": {k: round(sum(r["baseline"][k] for r in rows) / len(rows), 2) for k in keys},
        "raw_readability_council": round(sum(p["raw_readability_council"] for p in per_case) / n, 2),
        "raw_readability_baseline": round(sum(p["raw_readability_baseline"] for p in per_case) / n, 2),
    }
    json.dump({"summary": summary, "cases": per_case, "rows": rows},
              open(os.path.join(rd, "judge2-summary.json"), "w"), ensure_ascii=False, indent=1)
    print(json.dumps(summary, indent=1))


if __name__ == "__main__":
    main()
