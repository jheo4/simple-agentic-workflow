# SAW Pack: general
description: Practical general software workflow (balanced diverge/suppress brainstorm, clarity spec, dual-tension review, on-demand blind diagnosis)
rounds: spec=1, review_pre=1, work_fix=3, review_post=2, review_manual=2

| phase | lens | use | web | focus |
|---|---|---|---|---|
| brainstorm | incremental | active | no | lowest-cost high-leverage step on existing work |
| brainstorm | reframe | active | no | challenge assumptions and find alternative angles, including at least one pattern borrowed from another field |
| brainstorm | zoom | active | no | zoom-out (bigger picture/eliminate) and zoom-in (key bottleneck) |
| brainstorm | reality | active | yes | suppressor: feasibility, cost vs payoff, anti-bloat |
| spec | clarity | active | yes | ambiguity, missing edge cases, concrete verification criteria |
| review | critic | active | yes | defects, ripple effects, failure modes, missing checks |
| review | simplifier | active | no | fit with existing work, anti-overengineering, human-reviewable minimal diff |
| work | diagnostician | on_demand | yes | blind root-cause diagnosis from symptom and repro only |
| diff | concept | active | no | macro problem, abstractions, boundaries, and alignment map |
| diff | direction | active | no | mid-level approach, structure, flow, and trade-off differences |
| diff | detail | active | no | concrete logic/data/doc drift, contradictions, missing items, risks |

*(Note: `review` is shared by `/saw-review`, `/saw-work`, `/saw-run`, and `/saw-diff-commit`; `diff` applies to `/saw-diff-files`.)*
