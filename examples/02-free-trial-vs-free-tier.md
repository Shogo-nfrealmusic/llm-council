== BRIEF ==
A habit-tracker app has a 7-day free trial. 4% of trial users convert to the $4.99/month paid plan. Decide between (a) keeping the trial and (b) removing it and adding a permanent free tier capped at 3 habits, with paid unlocking more. Unknown: monthly trial starts and current revenue. Unknown: retention and churn of paid users. Unknown: how many habits a typical user tracks, which decides how many would stay under the 3-habit cap. Unknown: what free users cost to serve. Unknown: whether the change can be A/B tested or rolled back. Unknown: acquisition channels and how app-store ranking would respond.
Removed framing: "I'm pretty sure", "way better"

== ADVISORS ==
contrarian        NO-GO   68%  The 3-habit free tier cuts conversion; the trial's deadline did the work
first-principles  CHANGE  68%  Not a binary choice; A/B test a metered free tier against the trial
expansionist      CHANGE  68%  Replace the trial with a free tier, but ship it as an A/B test
outsider          CHANGE  60%  Switch to a free tier, but only if you can turn it back off
executor          NO-GO   68%  Don't remove the trial yet; measure habits per user first

== PEER REVIEW (anonymous, 3 reviewers) ==
#1 D first-principles  avg 1.3
#2 B executor          avg 1.7
#3 C outsider          avg 3.0
#4 E expansionist      avg 4.3
#5 A contrarian        avg 4.7
Unaddressed objection (reviewers): a permanent free tier is a one-way door. Even as an A/B test, users already on it can't be moved back cleanly.

== CHAIRMAN ==
VERDICT: NO-GO. Keep the 7-day trial for now, and first find out whether a 3-habit cap would even affect most users.

DECIDED BY: The outsider's point that the risks aren't equal. A trial ends on its own. A permanent free tier has to be taken back from users, which brings backlash and bad reviews. The executor and first-principles advisors added that the key unknown, how many habits users track, is already in the database. So we can learn it cheaply before making a change that is hard to undo.

STRONGEST OBJECTION STILL STANDING: Habit counts won't tell us whether the 4% comes from the trial deadline or from hitting a feature limit. And every month on the trial, users who let it lapse are lost for good, where a free tier would keep them reachable (expansionist).

WHERE THE COUNCIL DISAGREED:
- Contrarian vs expansionist: whether the deadline or the long free relationship drives conversion.
- Outsider vs executor/first-principles: whether an A/B test of a free tier can really be undone once users have it.

WHAT WOULD CHANGE THIS DECISION: At least 40% of trial users building 4+ habits in week one, and a soft-cap test that holds conversion at 4% or better.

NEXT 3 STEPS:
1. Pull the habit-count spread for recent trial users. You'll know it worked when you have the median and the share with 4+ habits.
2. Show a simulated 3-habit upgrade prompt to 20% of new trials for 10 days. You'll know by comparing conversion against the other 80%.
3. Confirm the app can grandfather existing free users behind a feature flag. You'll know when a test rollback runs cleanly.

Full advisor answers and reviews: ask "show the council notes".
