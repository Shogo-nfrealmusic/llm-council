# LLM Council for Claude Code

`/llm-council` pressure-tests a decision. Instead of one assistant telling you your idea sounds great, five independent advisors argue it from different angles. Their answers are then reviewed anonymously, and a chairman makes the call.

```
/llm-council I'm raising my app's price from $9 to $19 a month next week. I'm sure users will pay. Good idea?
```

## Why

A study published in *Science* on 26 March 2026 (Cheng et al., Stanford, "Sycophantic AI decreases prosocial intentions and promotes dependence") tested 11 AI models. On average, the models affirmed users' actions 49% more often than humans did. That figure is an average across all 11 models, not a measurement of any one model. Claude was among the less sycophantic models tested.
Paper: https://doi.org/10.1126/science.aec8352

This skill doesn't fix that. It is a structure that makes agreeing with you harder:

1. **Neutral brief.** Your question is rewritten without your stated preference ("I think this is genius", "I'm sure"). The skill shows you the brief and lists what it removed. From then on, no advisor sees your original wording.
2. **Five advisors, in parallel.** Each advisor is a separate subagent with its own context, and none can see the others. Each must pick a position (GO / NO-GO / CHANGE) and give a confidence.
   - **Contrarian**: how this most likely fails.
   - **First-principles**: which assumption is wrong.
   - **Expansionist**: what upside is being missed.
   - **Outsider**: a plain-sense check from someone with no industry context.
   - **Executor**: the smallest real step you can take by Monday.
3. **Anonymous peer review.** A bundled script shuffles the five answers with a real random number generator, labels them A–E, and masks the persona names. Three reviewer subagents then rank them without knowing who wrote what. Reviewers are told to reward the strongest well-argued dissent, not the majority view.
4. **Chairman.** A final subagent makes the call, on your session model unless you have set a default subagent model: GO, NO-GO, or CHANGE IT. It gives the strongest objection still standing, where the council disagreed, what evidence would change the decision, and three next steps. The chairman also never sees your original wording.

The advisors don't debate each other. Research on multi-agent debate shows it can collapse into premature consensus (arXiv:2509.23055). Anonymizing answers reduces identity-driven deference (arXiv:2510.07517). So this design keeps the advisors independent, rewards dissent in review, and requires the chairman to report disagreement instead of averaging it away.

## Install

### Option A: as a plugin (recommended)

In Claude Code:

```
/plugin marketplace add Shogo-nfrealmusic/llm-council
/plugin install llm-council@llm-council
```

Then run it as `/llm-council:llm-council <your question>`. Plugin skills are namespaced by the plugin name. In testing, typing `/llm-council` also resolved to the plugin skill when no other skill had that name.

### Option B: copy the skill folder

```bash
git clone https://github.com/Shogo-nfrealmusic/llm-council.git
cp -R llm-council/plugins/llm-council/skills/llm-council ~/.claude/skills/
```

Then run it as `/llm-council <your question>`. To use it in one project only, copy the folder into that project's `.claude/skills/` instead.

## Example

This is real output from `examples/03-demo-price-increase.md`, trimmed. Full runs are in [`examples/`](examples/).

```
== ADVISORS ==
contrarian        CHANGE  72%  Grandfather at $9; $19 for new signups only
first-principles  CHANGE  72%  No blind hike; test $19 on new signups only
expansionist      CHANGE  68%  $19 for new users; grandfather base; 14-day lock
outsider          CHANGE  70%  Grandfather at $9; don't double price for all
executor          CHANGE  72%  $19 for new signups Monday; revert if conv -30%

== PEER REVIEW (anonymous, 3 reviewers) ==
#1 D contrarian        avg 1.0
#2 A executor          avg 2.7
...
Convergence: all 3 reviewers called it suspect (a textbook grandfather-and-test answer).

== CHAIRMAN ==
VERDICT: CHANGE IT — Charge $19 to new signups next week; existing users stay at $9 for now.
...
STRONGEST OBJECTION STILL STANDING: New-signup data only shows whether new users will pay
$19, not whether existing ones will. If $9 loses money, grandfathering just delays
insolvency.

WHERE THE COUNCIL DISAGREED:
- All five agreed, only differing in detail. The best dissent: raise everyone to $19 with
  30 days' notice and roll back if churn spikes. That tests the real base and protects
  the runway.
...
```

Every advisor agreed here. The reviewers flagged that agreement as suspect, and the chairman wrote out the strongest dissent rather than treating the agreement as proof. That is the behavior the design aims for.

## Time and cost

One run makes 9 subagent calls: 5 advisors and 3 reviewers on Sonnet, plus the chairman on your session's model. In our tests, a run took about **3 minutes** (166–202 s; see [`examples/RUNS.md`](examples/RUNS.md)).

Token usage came to about **$1.7 per run at API list prices**, with an Opus main session and a large tool setup. A lighter setup, or Sonnet as the main model, will probably cost less. On a Pro or Max plan, a run counts toward your usage limits; there is no separate charge.

To make it cheaper, change `model: sonnet` to `model: haiku` for the advisors in `SKILL.md`.

## Limitations

Read these before you trust a verdict.

- **It does not eliminate sycophancy.** It is a thinking aid. All advisors run on the same model family, so they can share the same blind spot. In the pricing example above, all five advisors reached the same fix independently.
- **The neutral brief is written by the same session that saw your framing.** Check the "Removed framing" line, and re-run if the brief still leans your way.
- **Your `CLAUDE.md` still reaches the advisors.** Built-in subagents load your `CLAUDE.md`, so any preferences you have written there can reach them.
- **Anonymization hides names, not style.** A reviewer could still guess who wrote an answer from its style. The masking is a plain word replacement, so ordinary uses of words like "executor" or "outsider" in an answer are masked too.
- **Advisors only know what you tell them.** Important unknowns are listed as `Unknown:` in the brief instead of being guessed. The verdict is only as good as the facts you give.
- It is not financial, legal, or medical advice.

A multi-model mode like Karpathy's original, where different vendors' models answer through OpenRouter, is not included. It would reduce the shared-blind-spot problem, but it needs an API key and sends your question to more providers. If you want that, see Karpathy's repo below.

## Credits

- **Andrej Karpathy, [llm-council](https://github.com/karpathy/llm-council)**: the original idea. Multiple LLMs answer, review each other anonymously, and a chairman synthesizes.
- **Community Claude Code skills** that popularized the five-persona version: [okjpg/llm-council](https://github.com/okjpg/llm-council), [tenfoldmarc/llm-council-skill](https://github.com/tenfoldmarc/llm-council-skill), and [aiwithremy/claude-skills-llm-council](https://github.com/aiwithremy/claude-skills-llm-council).

This repository was written from scratch and contains no code or text from any of these projects.

## Development

```bash
bash tests/test_anonymize.sh                       # unit tests for the shuffle/anonymize script
claude plugin validate .                           # marketplace manifest
claude plugin validate ./plugins/llm-council       # plugin manifest
```

For an end-to-end check with evidence, run the skill non-interactively and inspect the log:

```bash
claude -p "/llm-council <question>" --plugin-dir ./plugins/llm-council \
  --output-format stream-json --verbose > run.jsonl
python3 tests/inspect_run.py run.jsonl "<a phrase from your original framing>"
```

The inspector checks five things:
- the 5 advisors were separate subagents launched in parallel
- the reviewer prompts contain no persona names and no key
- no subagent saw your original framing
- the chairman was called without a model override, so it uses the session model unless you have set a default subagent model
- the visible output has all four sections

## License

MIT. See [LICENSE](LICENSE).
