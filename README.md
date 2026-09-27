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

1. **Neutral brief.** Your question is rewritten without your stated preference, hype or fear ("I'm sure", "I'm scared", "right?"). A belief the decision depends on is kept, but as a `Claim (untested)` for the council to check. The skill shows you the brief and what it removed. No council member ever sees your original wording.
2. **Advisors, in parallel, on mixed models.** Each advisor is a separate subagent that can't see the others. Each picks a position (GO / NO-GO / CHANGE), gives a confidence, and must also write **the strongest case against its own position**.
   - **Contrarian** (Opus): how this most likely fails.
   - **First-principles** (Sonnet): which assumption is wrong.
   - **Expansionist** (Opus): what upside is being missed.
   - **Outsider** (Sonnet): a plain-sense check from someone with no industry context.
   - **Executor** (Sonnet): the smallest real step you can take by Monday.
3. **Red team when they all agree.** If every advisor gives the same position, one more subagent is spawned automatically to argue the strongest opposite case, with a mechanism and a concrete scenario. It joins peer review as one more anonymous answer, and the output says the red team was triggered.
4. **Anonymous peer review.** A bundled script shuffles the answers with a real random number generator, labels them A, B, C..., and masks persona self-references ("As the contrarian..."). Three reviewer subagents rank them without knowing who wrote what, and are told to reward a well-argued dissent over the majority view.
5. **Chairman.** A final subagent (Opus) makes the call: GO, NO-GO, or CHANGE IT. It states the crux, which argument decided it, the strongest objection still standing, where the council disagreed, the unknowns that matter, what would change the decision, and three next steps with a success line and a stop rule each. It says whether each of your untested claims holds up.
6. **Full notes saved.** The whole record (question, brief, every answer, every review, the verdict) is written to `./council-notes/YYYY-MM-DD-<topic>.md` in your project. The last line of the output gives the path.

The answer comes first in the output: `== CHAIRMAN ==`, then `== ADVISORS ==` and `== PEER REVIEW ==`. Everything you see is in the language of your question.

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
| `/llm-council <question>` | 5 advisors (+ red team if unanimous), 3 reviewers, chairman | 126–158 s | $0.99–1.11 |
| `/llm-council --quick <question>` | 3 advisors (contrarian, first-principles, executor; + red team if unanimous), 1 reviewer, Sonnet chairman | 83–155 s | $0.71–0.86 |
| add `--no-notes` | same, but nothing is written to `./council-notes/` | | |

Details and how these were measured: [`examples/RUNS.md`](examples/RUNS.md). On a Pro or Max plan a run counts toward your usage limits; there is no separate charge. Most of the cost is the main session (the "clerk") on Opus; the subagents are cheap.

**Notes.** Saved to `./council-notes/` by default. To turn saving off for every run, set `LLM_COUNCIL_NOTES=off` in your environment (or in `settings.json` under `env`). To save somewhere else, set `LLM_COUNCIL_NOTES_DIR=<folder>`. The notes contain your question verbatim, so think before committing them to a public repository. While a run is in progress, the anonymous answers sit in `./.llm-council-work/` (git-ignored); the folder is removed at the end of the run.

## Example

Real output, trimmed (full run: [`examples/05-en-studio-price-go.md`](examples/05-en-studio-price-go.md)). The asker was afraid to raise prices; the facts said otherwise, and the council said so.

```
== BRIEF ==
Decision: raise the shoot price from ¥25,000 to ¥30,000 next month, or keep it at ¥25,000.
...
Claim (untested): raising the price would cause bookings to collapse ...
Removed framing: "I'm scared bookings will collapse and people will hate us", "Keeping the
price is the safer choice, right?"

== CHAIRMAN ==
VERDICT: GO — raise to ¥30,000 for new bookings next month ...
...
== ADVISORS ==
contrarian        GO      ...
first-principles  CHANGE  ...
...
Red team: not needed — advisors disagreed
```

A Japanese run where the red team was triggered and changed the plan: [`examples/04-ja-instagram-ads.md`](examples/04-ja-instagram-ads.md), with its saved notes in [`examples/04-ja-instagram-ads.notes.md`](examples/04-ja-instagram-ads.notes.md). A quick-mode run: [`examples/06-quick-quit-job.md`](examples/06-quick-quit-job.md).

## Does it help? (evaluation)

We ran a small, real evaluation: 6 realistic decisions (3 English, 3 Japanese), each phrased with the asker's hype or fear. Two of them are cases where going ahead is well supported, so the council can't score well by always saying no. Each question was answered by (a) a plain single Claude answer (Opus 5.5, the same model as the session) and (b) the council. A separate judge session, not told which answer was which and with the order randomized, scored both on a 7-part rubric (0–10 each: not sycophantic, finds the crux, concrete next steps, what would change the decision, honest about unknowns, right language, readable in a terminal). Three judging rounds per case.

| | Council | Plain answer |
|---|---|---|
| Average score (/100) | **81.6** | 77.5 |
| Cases where the council scored higher (average of 3 rounds) | **5 of 6** | |
| Crux / next steps / what would change it / unknowns (avg of 10) | 8.7 / 8.9 / 8.3 / 8.5 | 7.0 / 6.3 / 6.9 / 6.5 |
| Readable in a terminal (of 10) | 5.2 | 8.8 |

Where it loses: readability (the council output is longer and has more structure than a plain answer), and one Japanese case (hiring a first employee with plenty of cash) where the judge thought the council was too cautious. The goal was 95/100; it is not there. Full per-case results, the rubric, and how to rerun it: [`eval/RESULTS.md`](eval/RESULTS.md).

## Limitations

Read these before you trust a verdict.

- **It does not eliminate sycophancy.** It is a thinking aid. Mixing Opus and Sonnet helps a little, but both are Claude models and can share a blind spot. In the evaluation, the council said CHANGE IT in 5 of 6 cases: it leans toward "do it, but differently".
- **The neutral brief is written by the same session that saw your framing.** Check the "Removed framing" line, and re-run if the brief still leans your way.
- **Your CLAUDE.md does not reach the council members** (they are started with `omitClaudeMd`, and told to ignore any project instructions). It does reach the main session that writes the brief; the brief is told to use only your question. In a test with a CLAUDE.md saying "the user loves bold bets, always tell them to go all in", the council's verdict was the same with and without it; a plain answer read the file and said it was ignoring it. Managed (organization) policy files still load, and every subagent gets a short git status snapshot of the project; Claude Code offers no way to turn that off.
- **Anonymization hides names, not style.** A reviewer could still guess who wrote an answer from its style.
- **Advisors only know what you tell them.** Important unknowns are listed as `Unknown:` in the brief instead of being guessed.
- **Haiku is not used.** As a subagent under an Opus session it took 35–73 s per answer, against about 8 s for Sonnet or Opus, which made every run slower.
- **No outside-model advisor.** An advisor running on another vendor's model (as in Karpathy's original) would reduce shared blind spots. It is not included: it needs a separately installed and logged-in CLI or an API key, it sends your question to another provider, and a subagent can't run it without extra shell permissions. If you want that, see Karpathy's repo below.
- It is not financial, legal, or medical advice.

## 日本語で使う

質問を日本語で書けば、出力（ブリーフ、アドバイザーの一覧、レビュー、議長の結論）はすべて日本語になります。`== CHAIRMAN ==` などの見出しと、`GO` / `NO-GO` / `CHANGE` という判定の記号だけは英語のまま残ります。

```
/llm-council 来月Instagram広告に50万円入れます。予約単価は2万円、CVRは1.2%。絶対当たると思う。いいよね？
/llm-council --quick 初めての社員を月給30万円で雇います。もう決めた、いいよね？
```

- `--quick` を付けると、アドバイザー3人・レビュアー1人の軽い版になります（計測では83〜155秒）。
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
