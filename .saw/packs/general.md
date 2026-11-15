# SAW Pack: general
description: Practical general software workflow (balanced diverge/suppress brainstorm, clarity spec, dual-tension review, on-demand blind diagnosis)
rounds: spec=1, review_pre=1, work_fix=3, review_post=2, review_manual=2

| phase | lens | use | web | focus |
|---|---|---|---|---|
| brainstorm | incremental | active | no | lowest-cost high-leverage step on existing code |
| brainstorm | reframe | active | no | challenge assumptions and find an alternative angle |
| brainstorm | zoom | active | no | zoom-out (bigger picture/eliminate) and zoom-in (key bottleneck) |
| brainstorm | reality | active | no | suppressor: feasibility, cost vs payoff, anti-bloat |
| spec | clarity | active | no | ambiguity, missing edge cases, concrete verification criteria |
| review | critic | active | no | bugs, regressions, failure modes, missing tests |
| review | simplifier | active | no | codebase fit, anti-overengineering, human-reviewable minimal diff |
| work | diagnostician | on_demand | no | blind root-cause diagnosis from symptom and repro only |
