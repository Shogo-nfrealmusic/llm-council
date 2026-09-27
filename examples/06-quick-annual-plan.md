<!-- v0.2 run, --quick mode. Question: Our SaaS has 300 customers on monthly plans at $49/month, and 40 of them have emailed asking for an annual plan. I want to offer annual billing at $490/year (two months free). Stripe supports it, so setup is about a day. My cofounder says discounts cheapen the brand and it's a terrible idea. I'm probably overthinking this and should just skip it, right? -->

```
== BRIEF ==
Removed framing: "I'm probably overthinking this", "should just skip it, right?"
Claim to test: The cofounder's claim that discounts cheapen the brand.

== CHAIRMAN ==
VERDICT: GO — offer $490/year, but only via private link to the 40 requesters first.
WHY:
- Worst case is small: $98/customer × 40 = $3,920/year (B's math), trivial one-day build cost; no cash-runway shown but even upper bound is negligible risk.
- Brand-cheapening claim: contradicted — none of the advisors, nor the reviewer, found evidence prepay-discount damages brand; keeping it unlisted removes the signaling risk entirely.
BIGGEST RISK: Churn is unknown, so if it's already near-zero, this is a pure discount with no retention benefit — track conversion to check.
NEXT STEPS:
1. Email annual link to the 40 requesters by Monday — success: link live within a week / stop if: build exceeds 1 day.
2. Track 2-week conversion (C's threshold) — success: ≥20 of 40 convert / stop if: <50% convert, don't expand.
3. Keep offer unlisted, not on pricing page — success: no public listing added / stop if: pressure to list before churn data exists.
WOULD CHANGE IT: If churn data later shows near-zero monthly churn, treat this as a pure discount and reconsider pricing.

== COUNCIL ==
contrarian GO, first-principles GO, executor GO | red team: off (quick) | top-ranked: executor
Full notes: council-notes/2026-09-28-annual-plan-490.md
```
