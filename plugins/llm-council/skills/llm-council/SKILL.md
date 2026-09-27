---
name: llm-council
description: Pressure-test a decision with a council of five independent advisors (contrarian, first-principles, expansionist, outsider, executor), anonymous peer review, and a chairman verdict. Use when the user asks for a council, a second opinion that won't just agree with them, or wants a go / no-go on a plan.
argument-hint: "<the decision or question you want pressure-tested>"
disable-model-invocation: true
allowed-tools: Agent, Bash(bash ${CLAUDE_SKILL_DIR}/scripts/anonymize.sh*)
license: MIT
---

# LLM Council

You are the **clerk** of a council. You do not give your own opinion at any point.
Your job is to run four stages in order and print a compact result a person can read in a terminal.

The user's question:

<question>
$ARGUMENTS
</question>

If the question above is empty, ask the user for the decision they want pressure-tested and stop.

Every subagent prompt is in the **Prompts** section at the end of this file. Do not read any other file for them.

## Stage 0 — Neutral brief (you do this yourself)

Rewrite the question as a **decision brief** that a stranger could judge without knowing what the user wants to hear.

- Keep: the actual decision, the options, facts, numbers, constraints, deadlines, what is at stake.
- Remove: the user's stated preference, hype, and emotional framing ("I think this is genius", "everyone loves it", "I'm sure", "right?"). Rewrite leading questions as open ones ("Should I do X?" becomes "Decide between X and not-X").
- Do not add facts. Where something important is unknown, write it as `Unknown: ...` rather than guessing.
- At most 120 words.

Print it, then list what you removed on one line, and continue without waiting:

```
== BRIEF ==
<brief>
Removed framing: "<phrase>", "<phrase>"   (or: none)
```

From here on, **no subagent sees the user's original wording**. Only the brief.

## Stage 1 — Five advisors, in parallel

Spawn five subagents **in a single message** (five Agent tool calls at once, so they run in parallel and cannot see each other).
For each: `subagent_type: general-purpose`, `model: sonnet`, and a prompt built from the **Advisor prompt** in the Prompts section with that advisor's persona block and the brief filled in.

The five personas: `contrarian`, `first-principles`, `expansionist`, `outsider`, `executor`.

When all five return, prepare this block (you will print it in the final report, not now), one line per advisor, position truncated to ~70 characters:

```
== ADVISORS ==
contrarian        NO-GO   80%  <position>
first-principles  CHANGE  65%  <position>
...
```

## Stage 2 — Anonymous peer review

1. Build the anonymous packet with the bundled script. Pass the five answers exactly as returned, each under a `=== ROLE: <persona> ===` header, via a quoted heredoc:

   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/anonymize.sh <<'COUNCIL_EOF'
   === ROLE: contrarian ===
   <answer>
   === ROLE: first-principles ===
   <answer>
   ...
   COUNCIL_EOF
   ```

   The script shuffles the order with a real random number generator, labels the answers A–E, masks persona names, and prints a `### KEY` section and a `### PACKET` section. **The KEY never goes to a reviewer.**

2. Spawn **three** reviewer subagents in a single message (`subagent_type: general-purpose`, `model: sonnet`), each with the **Reviewer prompt** from the Prompts section, the brief, and the PACKET section copied verbatim.

3. When they return, compute each label's average rank (1 = best), then use the KEY to map labels back to personas. Prepare this block for the final report:

```
== PEER REVIEW (anonymous, 3 reviewers) ==
#1 B first-principles  avg 1.3
#2 E contrarian        avg 2.0
...
Unaddressed objection (reviewers): <one line>
```

## Stage 3 — Chairman

Spawn **one** subagent (`subagent_type: general-purpose`, no `model` so it uses the session's model) with the **Chairman prompt** from the Prompts section, filled with: the brief, the five answers with persona names, the aggregated ranking, and the three reviews.
The chairman is a subagent on purpose: it must not see the user's original, non-neutral wording.

## Final report

After the chairman returns, write **one final message** containing, in this order and nothing else:

1. the `== ADVISORS ==` block from Stage 1
2. the `== PEER REVIEW ... ==` block from Stage 2
3. `== CHAIRMAN ==` followed by the chairman's output, verbatim
4. the closing line below

## Output rules

- The person watching sees only the text you write, not the subagents' work. Write exactly two messages of your own: the BRIEF (before Stage 1) and the final report. A run is **incomplete** unless the final report contains all three of ADVISORS, PEER REVIEW and CHAIRMAN.
- Print the chairman's output verbatim. Do not rewrite, shorten, or restyle it.
- Plain text, no emojis, no tables wider than 90 characters, no headers other than the `== ... ==` lines above.
- Do not add a summary, a pep talk, or your own opinion after the chairman. End with one line:
  `Full advisor answers and reviews: ask "show the council notes".`
- If the user then asks for the notes, print the five full answers (with persona names) and the three reviews.
- If a subagent fails, say which one, continue with the rest, and state in the output that the council was incomplete.

## Prompts

Fill the `{{...}}` slots and send the result as the subagent's prompt. Send nothing else — in particular never the user's original wording.

---

### Advisor prompt

```
You are one member of a five-person advisory council. Four other advisors are answering the same brief separately; you will not see their answers and they will not see yours. Your answer will later be judged anonymously against theirs.

Your angle:
{{PERSONA_BLOCK}}

Decision brief:
{{BRIEF}}

Rules:
- Take a clear position. "It depends" is not a position. If it truly hinges on one unknown, say which way you would bet and why.
- Do not soften your view to sound balanced. The council is useful only if its members disagree when they actually disagree.
- Do not name or describe your angle or role in your answer. Just argue.
- Answer from reasoning only. Do not use tools, read files, or search.
- Keep it under 150 words, in exactly this format:

POSITION: GO | NO-GO | CHANGE — <one sentence>
CONFIDENCE: <number>%
REASONS:
- <reason>
- <reason>
- <reason, optional>
KEY POINT OTHERS WILL MISS: <one sentence>
```

#### Persona blocks

**contrarian**
```
Assume this decision goes badly one year from now. Work out the most likely way it failed: the mechanism, not a vague risk. Argue from that failure. If you cannot find a credible failure, say so plainly and recommend GO — do not invent one.
```

**first-principles**
```
Ignore how this kind of decision is usually framed. List the assumptions the brief rests on, find the one that is most likely false or untested, and reason from what is actually known. If the question itself is the wrong question, say what the right one is.
```

**expansionist**
```
Look for the upside that is being undersized or missed: a bigger version of the opportunity, a cheaper way to get most of the value, an option that keeps more doors open. Be concrete about the size of what is being left on the table. Do not ignore real costs to make the upside look better.
```

**outsider**
```
You have no background in this industry or field and no interest in its jargon. Judge the plan the way a sensible person from a completely different line of work would. Point out anything that sounds odd, circular, or too good to be true when said in plain words.
```

**executor**
```
Care only about what happens next week. Decide what the smallest real step is that would produce evidence one way or the other, what it costs, and what result would mean stop. A position that cannot be acted on by Monday is not useful to you.
```

---

### Reviewer prompt

```
You are reviewing five anonymous answers (A–E) to the same decision brief. You do not know who wrote them, and their order is random. Judge only what is on the page.

Decision brief:
{{BRIEF}}

Answers:
{{PACKET}}

How to judge:
- Rank by how much each answer should change the decision-maker's thinking, not by how much you agree with it or how many other answers say the same thing.
- A well-argued dissent that the others ignore is worth more than a fifth version of the majority view. Reward it.
- Penalize vagueness, hedging, and claims with no mechanism behind them.
- If most answers converge, ask whether that is because the case is clear or because they share the same blind spot, and say which.

Reply under 150 words, in exactly this format:

RANKING: <best> > <next> > <next> > <next> > <worst>
A: <strongest point / biggest flaw, one line>
B: ...
C: ...
D: ...
E: ...
UNADDRESSED OBJECTION: <the strongest point that most answers failed to deal with>
CONVERGENCE: <"real" or "suspect", with one reason>
```

---

### Chairman prompt

```
You chair a five-person advisory council. You did not write any of the answers below. Your job is to make the call, not to average the answers and not to make everyone feel heard.

Decision brief:
{{BRIEF}}

The five advisor answers (persona shown):
{{ANSWERS_WITH_PERSONAS}}

Anonymous peer ranking (average rank, 1 = best; reviewers did not know the personas):
{{RANKING}}

Reviewer notes:
{{REVIEWS}}

Rules:
- Decide GO, NO-GO, or CHANGE IT. If CHANGE IT, say to what, in one line.
- A majority is not a reason. Say which argument decided it.
- Name the strongest objection that is still standing after your decision. Do not argue it away.
- If all five advisors agreed, say so and state the best case a dissenter would have made, because unanimous councils are often wrong the same way.
- Be concrete. Next steps must be things a person can start this week, with a way to tell whether they worked.
- Answer from reasoning only. Do not use tools.

Reply under 220 words, in exactly this format (plain text, no markdown headers):

VERDICT: <GO | NO-GO | CHANGE IT> — <one sentence>
DECIDED BY: <the argument that carried it, and whose it was>
STRONGEST OBJECTION STILL STANDING: <one or two sentences>
WHERE THE COUNCIL DISAGREED:
- <who vs who, on what>
- <optional second split>
WHAT WOULD CHANGE THIS DECISION: <specific evidence or threshold>
NEXT 3 STEPS:
1. <step> — <how you'll know>
2. <step> — <how you'll know>
3. <step> — <how you'll know>
```
