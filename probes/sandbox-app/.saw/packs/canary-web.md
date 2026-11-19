# SAW Pack: canary-web
description: Canary pack testing subagent web lookup (extends general, isolates a single web-enabled brainstorm lens)
extends: general

| phase | lens | use | web | focus |
|---|---|---|---|---|
| brainstorm | incremental | off | no | - |
| brainstorm | reframe | off | no | - |
| brainstorm | zoom | off | no | - |
| brainstorm | reality | off | no | - |
| brainstorm | canary-web-check | active | yes | Use live web lookup (do NOT answer from memory) to retrieve the exact current stable Python release version and documentation URL from docs.python.org. End with SAW-DONE |
