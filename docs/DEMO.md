# Recording a demo

## Demo question

This question is short enough to type on screen. In v0.1 runs it produced either a split (a lone NO-GO against four CHANGE votes) or all five advisors agreeing. In v0.2, agreement triggers the red team, which shows up in the output as `Red team: triggered`. Either outcome makes the anti-yes-man point on camera.

For a Japanese demo, see `examples/04-ja-instagram-ads.md` (the red team changed the plan there).

```
/llm-council I'm raising my app's price from $9 to $19 a month next week. I'm sure users will pay. Good idea?
```

What the viewer sees:

1. `== BRIEF ==` appears within seconds. The line `Removed framing: "I'm sure users will pay", "Good idea?"` is the hook: the council never sees your hype.
2. Then about 2–2.5 minutes (126–158 s in tests) of subagent activity: 5 advisors, a red team if they all agree, 3 reviewers, then the chairman. **Speed this up in the edit.** `--quick` takes about 1.5 minutes (83–155 s).
3. The final report: `== CHAIRMAN ==` first (the answer), then `== ADVISORS ==` and `== PEER REVIEW ==`, and a last line with the path of the saved notes. About 45 lines in total.

Reference output: `examples/05-en-studio-price-go.md` (v0.2). `examples/03-demo-price-increase.md` is the same demo question on v0.1.

## Before recording

- Install the skill using either method in the README. Or, for a session-only load with no install, start Claude with `claude --plugin-dir ~/llm-council-skill/plugins/llm-council`.
- Start `claude` in a folder you have already trusted, so the trust dialog doesn't appear on camera.
- Set the terminal to at least 100 columns. Advisor lines are about 90 characters wide.
- Run it in a scratch folder, or add `--no-notes`, if you don't want a `council-notes/` folder created in your project.
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
Sleep 180s
```

`Sleep 180s` covers the observed run time of 126–158 s, plus margin. Trim or speed up the waiting section in post.
