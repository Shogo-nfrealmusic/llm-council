# Test runs

Every run is an end-to-end, non-interactive run (`claude -p ... --output-format stream-json --verbose`) in a fresh empty folder, checked with `tests/inspect_run.py`. Setup: Claude Code 2.1.283, main session model Opus 5.5.

Cost is what Claude Code reports in `total_cost_usd`: token usage priced at **API list prices**. These runs were on a Max subscription, so no money was charged. Wall time is measured around the whole `claude -p` process, including start-up.

## v0.2 (current)

| Mode | Runs | Wall time | Cost (list) | Inspector |
|---|---|---|---|---|
| standard | 6 eval cases (3 run at a time) | 126–158 s (median about 138 s) | $0.99–1.11 | all checks pass (6 of 6) |
| quick, no red team | `06-quick-quit-job.md` | 100 s | $0.75 | all checks pass |
| quick, red team triggered | Japanese ¥500k ads case | 155 s | $0.86 | all checks pass |
| quick, CLAUDE.md leak test (clean folder) | 1 | 101 s | $0.76 | — |
| plain single answer (for comparison) | 6 eval cases | 16–28 s | $0.16–0.41 | — |

Where the money goes (standard, typical run): about $0.93 for the main session (the clerk, on Opus) and about $0.08 for all the advisor, reviewer, red-team and chairman subagents together. Most of the wall time is the clerk writing: the anonymizer input, the chairman's input, the notes, and the final report. `eval/timeline.py <run.jsonl>` prints the breakdown.

Files:
- `04-ja-instagram-ads.md`: standard, Japanese, red team triggered and it changed the plan. Its saved notes: `04-ja-instagram-ads.notes.md`.
- `05-en-studio-price-go.md`: standard, English, a GO verdict against the asker's fear.
- `06-quick-quit-job.md`: quick mode, English.

What did not work and was changed:
- **Haiku advisors.** Under an Opus session, a Haiku subagent took 35–73 s per answer (long hidden reasoning), against about 8 s for Sonnet or Opus. It held up every run, so Haiku is no longer used.
- **Sonnet as the clerk.** About $0.70 per run instead of $1.0, but not faster, and it often left the subagents in the background: its turn then ended, the skill's pre-approved scripts reset, and the run stopped at a permission denial. The skill now requires foreground subagents, and the clerk runs on the session model.
- **Packets in every prompt.** v0.1 copied all answers into each reviewer's and the chairman's prompt. v0.2 writes them once to a file that the reviewer and chairman agents read.

The quick-mode target was about 1 minute. It is not met: the three advisors take about 10 s together, but the clerk's own writing takes most of the remaining 90 s or more.

## v0.1 (for reference)

Examples `01`–`03` are v0.1 output (five advisors on Sonnet, the answer printed last, no red team, no saved notes).

| File | Install method | Invoked as | Wall time | Cost (list) | Inspector (v0.1) |
|---|---|---|---|---|---|
| `01-quit-job.md` | `--plugin-dir` | `/llm-council` | 169 s | $1.67 | all checks pass |
| `02-free-trial-vs-free-tier.md` | copied to `.claude/skills/` | `/llm-council` | 202 s | $1.77 | all checks pass |
| `03-demo-price-increase.md` | `--plugin-dir` | `/llm-council` | 170 s | $1.73 | all checks pass |
