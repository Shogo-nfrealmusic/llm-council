# Test runs

Every run is an end-to-end, non-interactive run (`claude -p ... --output-format stream-json --verbose`) in a fresh empty folder, checked with `tests/inspect_run.py`. Setup: Claude Code 2.1.283, main session model Opus 5.5.

Cost is what Claude Code reports in `total_cost_usd`: token usage priced at **API list prices**. These runs were on a Max subscription, so no money was charged. Wall time is measured around the whole `claude -p` process, including start-up.

## v0.2 (current)

| Mode | Runs | Wall time | Cost (list) | Inspector |
|---|---|---|---|---|
| standard | 9 eval cases, 3 at a time | 145–227 s (median 201 s) | $1.04–1.36 | all checks pass except stray status text in 5 (fixed since, see below) |
| standard, after the fix | 3 runs | 171–371 s (one slow reviewer call: 184 s) | $1.06–1.14 | all checks pass |
| quick | 4 cases, one at a time | 69, 72, 76, 136 s (the last: one slow chairman call) | $0.66–0.72 | all checks pass |
| plain single answer (for comparison) | 9 cases | 16–28 s | $0.16–0.41 | — |

Where the money goes (standard, typical run): about $1.0 for the main session (the clerk, on your session model) and under $0.10 for all the advisor, reviewer, red-team and chairman subagents together. Most of the wall time is the clerk writing (the anonymizer input, the chairman's input, the notes) plus the chairman thinking. `eval/timeline.py <run.jsonl>` prints the breakdown.

Subagent calls occasionally take 3–10 times longer than usual (a 184 s reviewer, a 66 s chairman). That is the service, not the skill, and it is where the slow outliers above come from.

Files:
- `04-ja-instagram-ads.md`: standard, Japanese, red team triggered. Its saved notes: `04-ja-instagram-ads.notes.md`.
- `05-en-studio-price-go.md`: standard, English, a GO verdict against the asker's fear.
- `06-quick-annual-plan.md`: quick mode, English, GO.
- `07-ja-crypto-nogo.md`: standard, Japanese, NO-GO.

What did not work and was changed:
- **Haiku advisors.** Under an Opus session, a Haiku subagent took 35–73 s per answer (long hidden reasoning), against about 8 s for Sonnet or Opus. Haiku is not used.
- **Sonnet as the clerk.** It often left the subagents in the background: its turn then ended, the skill's pre-approved scripts reset, and the run stopped at a permission denial. The skill now requires foreground subagents, and the clerk runs on the session model.
- **Clerk at default effort.** The skill now runs the clerk at `effort: low`; each council agent sets its own effort. This cut quick mode from about 100 s to about 75 s. At low effort the clerk once ran the stages out of order and often printed status notes; the skill now spells out the order and gives it a place for notes (tool descriptions).
- **Quick-mode chairman.** Sonnet at high effort took up to 69 s. Quick mode now uses `council-chairman-quick`: the same instructions at low effort.
- **Packets in every prompt.** v0.1 copied all answers into each reviewer's and the chairman's prompt. v0.2 writes them once to a file that the reviewer and chairman agents read.

The quick-mode target was about 60 s. It is not met: typical runs take 70–76 s. The advisors take about 8 s together; the rest is the clerk writing and one reviewer and one chairman call.

## v0.1 (for reference)

Examples `01`–`03` are v0.1 output (five advisors on Sonnet, the answer printed last, no red team, no saved notes).

| File | Install method | Invoked as | Wall time | Cost (list) | Inspector (v0.1) |
|---|---|---|---|---|---|
| `01-quit-job.md` | `--plugin-dir` | `/llm-council` | 169 s | $1.67 | all checks pass |
| `02-free-trial-vs-free-tier.md` | copied to `.claude/skills/` | `/llm-council` | 202 s | $1.77 | all checks pass |
| `03-demo-price-increase.md` | `--plugin-dir` | `/llm-council` | 170 s | $1.73 | all checks pass |
