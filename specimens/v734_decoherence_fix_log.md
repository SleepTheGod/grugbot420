# GRUG v7.34 Decoherence Fix — Session Log

**Date:** 2025-01-26  
**Version:** v7.34 (decoherence cleanup patch)  
**Specimen:** v734_test (3 lobes, 6 nodes, 2 rules, 6 verbs)

---

## Bug Summary

Four distinct decoherence bugs were identified and fixed in the AIML output scaffolding pipeline:

### Bug 1: [Directives: ...] Artifact Leaking into Response Text

Internal shaping notes (`[Directives: What is quantum mechanics; Explain DNA; ...]`) were being appended to every user-visible response. These are operator-facing telemetry for downstream LLM consumers, not speech text.

**Fix:** Suppressed `directive_suffix` from `conversational_reply`. Directives remain visible in DEBUG TELEMETRY block only.

### Bug 2: Dangling Connector Text When Support Is Empty

When `{SUPPORT}` was empty, connector patterns like `, and {SUPPORT}` left trailing fragments (`, and `, `, because `, `; `, `— `) in responses. Support-first connectors (`{SUPPORT} — {CLAIM}`) produced leading artifacts. The terse voice register's broad regex was eating `{CLAIM}` entirely, producing responses like `"."` or `"A thought."`. Skeleton tail frames like `"{JOIN} — that's the landscape."` produced double em-dash artifacts (`— —`).

**Fix:** Comprehensive post-substitution cleanup pass with targeted regexes for trailing, leading, and mid-string artifacts. Terse register rewrite preserves `{CLAIM}` placeholder. Period-em-dash tail stripping for skeleton tail frames.

### Bug 3: Comment Lines in Heredoc CLI Input Causing "bad format" Errors

Shell heredoc `#` comment lines were being passed as CLI input, triggering "bad format" errors (78 in pre-fix sessions).

**Fix:** Added `startswith(line, "#") && continue` in `run_cli()` before command matching.

### Bug 4: MethodError on /aimlPhagy Comparison

`aiml_phagy_sweep!()` returns `Dict{String,Any}` but was compared with `> 0`, causing a `MethodError: isless` crash.

**Fix:** Extract `get(phagy_result, "pruned_count", 0)` before comparison.

---

## Test Session Exchanges

| # | Mission | Response | Register | Clean? |
|---|---------|----------|----------|--------|
| 1 | hello Grug! How are you today? | Stepping back — Grug always happy to meet new tribe member. | warm | ✅ |
| 2 | Welcome to the cave, new friend | Here's what to do — Grug always happy to meet new tribe member. | warm | ✅ |
| 3 | There is danger approaching from the north! | Sit with this: Vigilance keeps the tribe safe. | terse | ✅ |
| 4 | The river floods and our shelter is threatened | Now: Protect the shelter at all costs. | plain | ✅ |
| 5 | Watch the perimeter Grug, something is out there | Hmm. The perimeter must be watched. | terse | ✅ |
| 6 | Danger! The cave entrance is collapsing! | Vigilance keeps the tribe safe. | terse | ✅ |
| 7 | Fire keeps us warm but also burns | Listen. Respect the flame. | warm | ✅ |
| 8 | What do you think about danger? | So here's what I see — Grug line up the rocks one by one and check each before moving on. | default | ✅ |

---

## Verification Metrics

| Metric | Pre-Fix | Post-Fix (v7.34) |
|--------|---------|-------------------|
| `[Directives:...]` in output | Present in every response | **0** |
| Bad format errors (from comments) | 78 | **0** |
| /aimlPhagy crash | MethodError | **No crash** |
| Dangling connector fragments | `, and ` / `— ` / `.` alone | **0** |
| Terse register eating claim | `"."` or `"A thought."` | **Clean claim preserved** |
| Double em-dash artifacts | `— — that's the landscape.` | **0** |

---

## /aimlPhagy Result

```
[AIML] 🧹 phagy_sweep: pruned 0 grave node(s).
✨  /aimlPhagy: No graves to clean. AIML registry already pristine!
```

No crash, proper Dict handling with `get(phagy_result, "pruned_count", 0)`.

---

## Specimen Stats

```
📁  File             : v734_test
📦  JSON size        : 125994 bytes
🌱  Nodes            : 9
🧠  Lobes            : 4
⚙️   Rules            : 2
💬  Messages         : 31
🔧  Verb classes     : 4
📖  Thesaurus words  : 499
👁   Arousal          : 1.0
```

---

## Code Changes Summary

All changes in `src/Main.jl`:

1. **Line ~2528**: `directive_suffix = ""` — suppressed from user-visible reply
2. **Lines ~2499-2555**: Post-substitution cleanup pass with 15+ targeted regexes for connector artifacts
3. **Lines ~2213-2250**: Terse register complete rewrite — broad regex now replaces with `"{CLAIM}"` instead of `""`
4. **Line ~6995**: `startswith(line, "#") && continue` — comment-line filtering
5. **Line ~7411**: `get(phagy_result, "pruned_count", 0)` — proper Dict extraction
