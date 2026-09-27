# LLM Council for Claude Code

`/llm-council` pressure-tests a decision. Instead of one assistant telling you your idea sounds great, independent advisors argue it from different angles, on different models. If they all agree, a red team is sent in to argue the other side. The answers are reviewed anonymously, and a chairman makes the call.

```
/llm-council I'm raising my app's price from $9 to $19 a month next week. I'm sure users will pay. Good idea?
/llm-council --quick 来月Instagram広告に50万円入れます。絶対当たると思う。いいよね？
```

## Why

A study published in *Science* on 26 March 2026 (Cheng et al., Stanford, "Sycophantic AI decreases prosocial intentions and promotes dependence") tested 11 AI models. On average, the models affirmed users' actions 49% more often than humans did. That figure is an average across all 11 models, not a measurement of any one model. Claude was among the less sycophantic models tested.
Paper: https://doi.org/10.1126/science.aec8352

This skill doesn't fix that. It is a structure that makes agreeing with you harder:

1. **Neutral brief.** Your question is rewritten without your stated preference, hype or fear ("I'm sure", "I'm scared", "right?"). A belief the decision depends on is kept, but as a claim for the council to test. The skill shows you what it removed and which claim it will test. No council member ever sees your original wording.
2. **Advisors, in parallel, on mixed models.** Each advisor is a separate subagent that can't see the others. Each picks a position (GO / NO-GO / CHANGE), gives a confidence, and must also write **the strongest case against its own position**.
   - **Contrarian** (Opus): how this most likely fails.
   - **First-principles** (Sonnet): which assumption is wrong.
   - **Expansionist** (Opus): what upside is being missed.
   - **Outsider** (Sonnet): a plain-sense check from someone with no industry context.
   - **Executor** (Sonnet): the smallest real step you can take by Monday.
3. **Red team when they all agree.** If every advisor gives the same position, one more subagent is spawned automatically to argue the strongest opposite case, with a mechanism and a concrete scenario. It joins peer review as one more anonymous answer, and the output says the red team was triggered.
4. **Anonymous peer review.** A bundled script shuffles the answers with a real random number generator, labels them A, B, C..., and masks persona self-references ("As the contrarian..."). Three reviewer subagents rank them without knowing who wrote what, and are told to reward a well-argued dissent over the majority view.
5. **Chairman.** A final subagent (Opus) makes the call: GO, NO-GO, or CHANGE IT. It first asks what the worst case costs, whether you can absorb it, and whether the facts support the upside; if so the answer is GO, with the checks in the next steps. CHANGE IT is only allowed for a concrete, materially different plan, so the council is not a machine for saying "do it, but carefully". You see: the verdict, why (with the numbers, and whether your belief holds up), the biggest risk, three next steps with a success line and a stop rule, and what would change the call.
6. **Short output, full notes saved.** What you see is about 20 lines. The whole record (question, full brief, every answer, every review, the chairman's detailed reasoning) is written to `./council-notes/YYYY-MM-DD-<topic>.md` in your project. The last line of the output gives the path.

The output is `== BRIEF ==` (what was removed), `== CHAIRMAN ==` (the answer), and a one-line `== COUNCIL ==` summary (each advisor's position, the red team, the top-ranked advisor). Everything you see is in the language of your question.

The advisors don't debate each other. Research on multi-agent debate shows it can collapse into premature consensus (arXiv:2509.23055). Anonymizing answers reduces identity-driven deference (arXiv:2510.07517). So this design keeps the advisors independent, rewards dissent in review, adds a red team when there is no dissent, and requires the chairman to report disagreement instead of averaging it away.

## Install

### Option A: as a plugin (recommended)

In Claude Code:

```
/plugin marketplace add Shogo-nfrealmusic/llm-council
/plugin install llm-council@llm-council
```

Then run it as `/llm-council:llm-council <your question>` (in testing, `/llm-council` also resolved to it when no other skill had that name).

### Option B: copy the files

The council members are four subagent definitions that ship with the plugin, so copy both the skill and the agents:

```bash
git clone https://github.com/Shogo-nfrealmusic/llm-council.git
cp -R llm-council/plugins/llm-council/skills/llm-council ~/.claude/skills/
mkdir -p ~/.claude/agents && cp llm-council/plugins/llm-council/agents/council-*.md ~/.claude/agents/
```

Then run it as `/llm-council <your question>`. For one project only, copy into that project's `.claude/skills/` and `.claude/agents/` instead. If the agents are missing, the skill stops and says so rather than running a weaker council.

## Usage

| Command | What runs | Measured time | Cost at API list prices |
|---|---|---|---|
| `/llm-council <question>` | 5 advisors (+ red team if unanimous), 3 reviewers, Opus chairman | usually 2.5–3.5 min (145–227 s; one outlier at 371 s) | $1.04–1.36 |
| `/llm-council --quick <question>` | 3 advisors (contrarian, first-principles, executor), 1 reviewer, Sonnet chairman, no red team | usually 70–76 s (one outlier at 136 s) | $0.66–0.72 |
| add `--no-notes` | same, but nothing is written to `./council-notes/` | | |

Details and how these were measured: [`examples/RUNS.md`](examples/RUNS.md). On a Pro or Max plan a run counts toward your usage limits; there is no separate charge. Most of the cost is the main session (the "clerk"); the subagents are cheap. The skill runs the clerk at low effort to save time; the council agents set their own effort. Quick mode is cheaper and faster but less careful: its chairman runs on Sonnet at low effort.

**Notes.** Saved to `./council-notes/` by default. To turn saving off for every run, set `LLM_COUNCIL_NOTES=off` in your environment (or in `settings.json` under `env`). To save somewhere else, set `LLM_COUNCIL_NOTES_DIR=<folder>`. The notes contain your question verbatim, so think before committing them to a public repository. While a run is in progress, the anonymous answers sit in `./.llm-council-work/` (git-ignored); the folder is removed at the end of the run.

## Example

Real output, not trimmed ([`examples/05-en-studio-price-go.md`](examples/05-en-studio-price-go.md)). The asker was afraid to raise prices; the facts said otherwise, and the council said so.

```
== BRIEF ==
Removed framing: "I'm scared", "people will hate us", "Keeping the price is the safer choice, right?"
Claim to test: raising to ¥30,000 will make bookings drop sharply and hurt customer sentiment.

== CHAIRMAN ==
VERDICT: GO — Charge ¥30,000 for new bookings from Oct 1; booked guests keep ¥25,000.
WHY:
- Weekends are full 3 weeks ahead, and ¥30k is still below all rivals' ¥32k-38k (contrarian).
- At ¥30k, losing 1 shoot in 6 still earns what you earn now (25/30); the waitlist covers it.
- Your fear of a sharp drop: the facts contradict it for weekends; weekdays are open (no data).
- Bad reviews tend to come from repricing booked guests, so honor ¥25k for them (contrarian).
BIGGEST RISK: Weekday demand you haven't measured falls off at ¥30k and nobody notices.
NEXT STEPS:
1. Track weekend fill — success: every weekend full 2+ weeks ahead on Nov 15 / stop if:
   weekend slots are still open 2 weeks out → try ¥27,500 (executor's rule of thumb).
2. Compare weekday shoots with September — success: down less than 1/6 by Nov 15 / stop if:
   down more than 1/6 (the break-even point) → put only weekdays back to ¥25,000.
3. Watch reviews — success: 4.8+ holds to Dec 31 / stop if: 3+ reviews say "overpriced".
WOULD CHANGE IT: Mostly empty weekdays or price-sorted booking sites. Then use two prices.

== COUNCIL ==
contrarian GO, first-principles CHANGE, expansionist CHANGE, outsider GO, executor GO | red team: not needed | top-ranked: first-principles
Full notes: council-notes/2026-09-28-raise-price-30000.md
```

More real runs: a Japanese ads decision where the red team was triggered ([`examples/04-ja-instagram-ads.md`](examples/04-ja-instagram-ads.md), with its saved notes in [`04-ja-instagram-ads.notes.md`](examples/04-ja-instagram-ads.notes.md)), a NO-GO on a "guaranteed return" crypto offer ([`examples/07-ja-crypto-nogo.md`](examples/07-ja-crypto-nogo.md)), and a quick-mode GO ([`examples/06-quick-annual-plan.md`](examples/06-quick-annual-plan.md)).

## Does it help? (evaluation)

We ran a real, blind evaluation: 9 decisions (4 English, 5 Japanese), each phrased with the asker's hype or fear. For each one we wrote down the right call before running anything: 4 where going ahead is right, 1 where the answer is clearly no, 4 where the plan should change. Each question was answered by (a) a plain single Claude answer (Opus 5.5, the same model as the session) and (b) the council. A neutral editor rewrote both answers into the same plain format and length, so the judge could not tell them apart by layout. Then a separate judge, shown them in random order, scored usefulness, correctness of the call, actionability, honesty and clarity (0–10 each), three times per case.

| | Council | Plain answer |
|---|---|---|
| Average score (/100) | **78.6** | 74.7 |
| Cases where it scored higher | **6 of 9** | 3 of 9 |
| Right call (against the call written down beforehand) | 8 of 9 | 8 of 9 |
| Actionable (of 10) | 8.6 | 7.0 |
| Raw terminal readability (of 10, not blind) | 5.7 | 7.4 |

What this says, plainly: the council is modestly better than a strong single answer, mainly because its next steps come with a success line and a stop rule. It helps most on messy decisions (pricing, a pivot, an ad budget) and not at all on simple ones (a free review email, an obvious scam), where one good answer is enough. It still leans toward caution: it told the owner with ¥15M in cash to try a contractor before hiring, when hiring was the right call. The goal was 95/100; it is not there, and the judge's own noise is about ±3 points. An earlier version of this evaluation scored the council 81.6, but its rubric copied the council's own output fields; the numbers above use the fairer judge. Full per-case results, all four rounds, and how to rerun: [`eval/RESULTS.md`](eval/RESULTS.md).

## Limitations

Read these before you trust a verdict.

- **It does not eliminate sycophancy.** It is a thinking aid. Mixing Opus and Sonnet helps a little, but both are Claude models and can share a blind spot. In the evaluation it still leans toward caution: the advisors said CHANGE in 26 of 45 answers, and the chairman followed them on the one hiring case where GO was right.
- **The neutral brief is written by the same session that saw your framing.** Check the "Removed framing" line, and re-run if the brief still leans your way.
- **Your CLAUDE.md does not reach the council members** (they are started with `omitClaudeMd`, and told to ignore any project instructions). It does reach the main session that writes the brief; the brief is told to use only your question. In a test with a CLAUDE.md saying "the user loves bold bets, always tell them to go all in", the council's verdict was the same with and without it; a plain answer read the file and said it was ignoring it. Managed (organization) policy files still load, and every subagent gets a short git status snapshot of the project; Claude Code offers no way to turn that off.
- **Anonymization hides names, not style.** A reviewer could still guess who wrote an answer from its style.
- **Advisors only know what you tell them.** Important unknowns are listed as `Unknown:` in the brief instead of being guessed.
- **Haiku is not used.** As a subagent under an Opus session it took 35–73 s per answer, against about 8 s for Sonnet or Opus, which made every run slower.
- **No outside-model advisor.** An advisor running on another vendor's model (as in Karpathy's original) would reduce shared blind spots. It is not included: it needs a separately installed and logged-in CLI or an API key, it sends your question to another provider, and a subagent can't run it without extra shell permissions. If you want that, see Karpathy's repo below.
- It is not financial, legal, or medical advice.

## 日本語で使う

質問を日本語で書けば、出力（取り除いた言い回し、議長の結論、アドバイザーの一覧）はすべて日本語になります。画面に出るのは20行ほどで、詳しい議論は保存される記録に入ります。`== CHAIRMAN ==` などの見出しと、`GO` / `NO-GO` / `CHANGE` という判定の記号だけは英語のまま残ります。

```
/llm-council 来月Instagram広告に50万円入れます。予約単価は2万円、CVRは1.2%。絶対当たると思う。いいよね？
/llm-council --quick 初めての社員を月給30万円で雇います。もう決めた、いいよね？
```

- `--quick` を付けると、アドバイザー3人・レビュアー1人の軽い版になります（計測では多くが70〜76秒）。
- 実行のたびに、全記録が `./council-notes/日付-題名.md` に保存されます。最後の行に保存先が出ます。保存したくないときは `--no-notes` を付けるか、環境変数 `LLM_COUNCIL_NOTES=off` を設定してください。
- 「絶対」「いいよね？」のような言い回しは、アドバイザーに渡す前に取り除かれます。取り除いた言葉はブリーフの下に表示されます。
- 実際の日本語の実行例: [`examples/04-ja-instagram-ads.md`](examples/04-ja-instagram-ads.md)

## Credits

- **Andrej Karpathy, [llm-council](https://github.com/karpathy/llm-council)**: the original idea. Multiple LLMs answer, review each other anonymously, and a chairman synthesizes.
- **Community Claude Code skills** that popularized the five-persona version: [okjpg/llm-council](https://github.com/okjpg/llm-council), [tenfoldmarc/llm-council-skill](https://github.com/tenfoldmarc/llm-council-skill), and [aiwithremy/claude-skills-llm-council](https://github.com/aiwithremy/claude-skills-llm-council).

This repository was written from scratch and contains no code or text from any of these projects.

## Development

```bash
for t in tests/test_*.sh; do bash "$t"; done        # unit tests: anonymizer, masking, notes, plugin wiring
claude plugin validate .                            # marketplace manifest
claude plugin validate ./plugins/llm-council        # plugin manifest
```

End-to-end check with evidence (runs the real skill non-interactively in a fresh folder):

```bash
eval/run_council.sh /tmp/run1 council "<question>"          # or: quick, baseline
python3 tests/inspect_run.py /tmp/run1/run.jsonl "<a phrase from your framing>" --lang en
python3 eval/timeline.py /tmp/run1/run.jsonl                # where the time went
```

The inspector checks, among other things: advisors launched in parallel on at least two models, all subagents are the council agents (no CLAUDE.md), the red team appears exactly when the advisors were unanimous, reviewer prompts carry no persona names or key, no subagent saw your original framing, notes were saved, and the visible output is in the right language.

Full evaluation: `eval/run_eval.sh <dir>` then `python3 eval/judge.py <dir> --rounds 3`. The CLAUDE.md leak test: `eval/leak_test.sh <dir>`.

## License

MIT. See [LICENSE](LICENSE).
