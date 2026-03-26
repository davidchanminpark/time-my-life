---
name: Refactor
about: Code improvement without behavior change
labels: refactor
---

## What to refactor
<!-- What code needs cleaning up -->

## Why
<!-- Performance, readability, technical debt -->

## What should NOT change
<!-- Behavior that must stay identical -->

## Files involved
<!-- Specific files or components -->
```

---

## Pro Tips for Claude

**Write issues like you're briefing a contractor** — the more specific, the better Claude's output:
```
❌  "Add login screen"

✅  "Add Sign in with Apple to LoginView.swift.
    Store JWT in Keychain. On success navigate 
    to HomeView. Follow existing AuthViewModel pattern."