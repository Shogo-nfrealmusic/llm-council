# Test runs

Every run is an end-to-end, non-interactive run (`claude -p ... --output-format stream-json --verbose`), checked with `tests/inspect_run.py`. Setup: Claude Code 2.1.283, main session model Opus 5.5, advisors and reviewers on Sonnet 5.

Cost is what Claude Code reports in `total_cost_usd`: token usage priced at **API list prices**. These runs were on a Max subscription, so no money was charged. The main session carried a large tool and MCP setup, which inflates the Opus share; a lighter setup should cost less.

| File | Install method | Invoked as | Wall time | Cost (list) | Inspector |
|---|---|---|---|---|---|
| `01-quit-job.md` | `--plugin-dir` | `/llm-council` | 169 s | $1.67 (Opus $1.2 + Sonnet $0.5) | all checks pass |
| `02-free-trial-vs-free-tier.md` | copied to `.claude/skills/` | `/llm-council` | 202 s | $1.77 | all checks pass |
| `03-demo-price-increase.md` (earlier version, since replaced) | `--plugin-dir` | `/llm-council:llm-council` | 189 s | $1.71 | all checks pass |
| `03-demo-price-increase.md` (current, final skill version) | `--plugin-dir` | `/llm-council` | 170 s | $1.73 | all checks pass |

Notes:
- Runs 01 and 02 were made before the review fixes: the random heredoc delimiter, CRLF handling, boundary escaping, and shorter advisor lines. Run 03 (current) is on the final `SKILL.md`.
- With `--plugin-dir`, both `/llm-council` and the namespaced `/llm-council:llm-council` resolved to the plugin skill.
- The first run of the plugin failed. The skill read its prompts from a separate file outside the working directory, which needs a permission. The prompts were then moved into `SKILL.md`.
- In the next two runs, the ADVISORS and PEER REVIEW blocks were missing from the visible output. The orchestrator writes no text between tool calls. The fix: all blocks now go in one final report.
