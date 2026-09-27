# Recording a demo

## Demo question

This question is short enough to type on screen, and it produced a clean run with a real split: a lone NO-GO against four CHANGE votes, which the chairman surfaced.

```
/llm-council I'm raising my app's price from $9 to $19 a month next week. I'm sure users will pay. Good idea?
```

What the viewer sees:

1. `== BRIEF ==` appears within seconds. The line `Removed framing: "I'm sure users will pay", "Good idea?"` is the hook: the council never sees your hype.
2. Then roughly 3 minutes of subagent activity: 5 advisors, then 3 reviewers, then the chairman. **Speed this up in the edit.**
3. The final report: `== ADVISORS ==`, `== PEER REVIEW ==`, then `== CHAIRMAN ==`, about 35 lines in total.

Reference output: `examples/03-demo-price-increase.md`.

## Before recording

- Install the skill using either method in the README. Or, for a session-only load with no install, start Claude with `claude --plugin-dir ~/llm-council-skill/plugins/llm-council`.
- Start `claude` in a folder you have already trusted, so the trust dialog doesn't appear on camera.
- Set the terminal to at least 100 columns. Advisor lines are about 90 characters wide.
- No permission prompts are expected. The skill pre-approves its subagent calls and its one bundled script.

## VHS tape

```tape
Output council.mp4
Set FontSize 18
Set Width 1400
Set Height 900
Set Theme "Dracula"
Set TypingSpeed 35ms

Type "claude"
Enter
Sleep 4s
Type "/llm-council I'm raising my app's price from $9 to $19 a month next week. I'm sure users will pay. Good idea?"
Sleep 500ms
Enter
Sleep 220s
```

`Sleep 220s` covers the observed run time of 169–202 s, plus margin. Trim or speed up the waiting section in post.
