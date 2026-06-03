# 🧠 EphemeralMLP v7.24 — Chat Log & Integration Test Report

**Branch:** `feat/v7.24-ephemeral-mlp-transformer`
**Date:** 2025-07-10
**Specimen Format:** `ephemeral-mlp-v1.2` / `grugbot420-specimen-v2.7`
**Test Result:** ✅ **77/77 PASSED**

---

## Overview

This session delivers the **user-editable observation threshold** and **SelfObserver store wiring** for EphemeralMLP. The `OBSERVATION_THRESHOLD` constant has been replaced with a mutable field on `EphemeralMLPState`, accessible via `set_observation_threshold!(n)` / `get_observation_threshold()`. The global `_MLP_OBSERVER_STORE` is now wired into `process_mission` in Main.jl, feeding `selfobserver_count` from the real SelfObserver store instead of a hardcoded `0`.

---

## What Changed

### EphemeralMLP.jl

1. **Removed `const OBSERVATION_THRESHOLD = 5`** — replaced with mutable field
2. **Added `observation_threshold::Int`** to `EphemeralMLPState` struct (default: `5`)
3. **Added `set_observation_threshold!(n::Int)`** — validates `n >= 0`, updates state, auto-enables adjustments if threshold already met
4. **Added `get_observation_threshold()::Int`** — thread-safe getter
5. **Updated `transform_vote_list`** — uses `st.observation_threshold` instead of const
6. **Updated `get_mlp_status()`** — includes `"observation_threshold"` key
7. **Updated `to_specimen_dict()` / `from_specimen_dict!()`** — serializes/deserializes `observation_threshold` (backward-compat: defaults to 5 for v1.1 specimens)
8. **Specimen version bumped** — `1.1` → `1.2` (`ephemeral-mlp-v1.2`)
9. **Bug fix: `vote_text` in `transform_vote_list`** — now appends `user_input` to the pattern-matching text and wraps with `String()` to avoid `SubString{String}` MethodError with `activate_rules_by_pattern!`

### Main.jl

1. **Added `_MLP_OBSERVER_STORE`** — global `SelfObserver.SubconsciousStore()` instance
2. **Wired `selfobserver_count`** — now calls `SelfObserver.store_size(_MLP_OBSERVER_STORE)` instead of `0`
3. **Added `SelfObserver.observe!` call** — after MLP transform, records activation type, novelty score, directive quality, adjustments status, active rule count, and input hash (tag: `:meta`)
4. **Added `/mlpThreshold <n>` CLI command** — sets observation threshold with confirmation message
5. **Added `/mlpObserver` CLI command** — shows observer store stats (total entries, key count, write stats)
6. **Updated `/mlpStatus`** — shows observer threshold, observer count, adjustments enabled
7. **Updated `/status`** — MLP section includes observer data
8. **Updated help menu** — documents new CLI commands
9. **Updated specimen save/load** — includes `mlp_observer_store` key with `total_entries` and `key_count`
10. **Specimen version bumped** — `2.6` → `2.7` (`grugbot420-specimen-v2.7`)

---

## Bug Fixes Discovered During Testing

### 1. `SubString{String}` MethodError in `activate_rules_by_pattern!`

**Root cause:** The `vote_text` variable was constructed using `strip()` which returns `SubString{String}`, but `activate_rules_by_pattern!` has a method signature expecting `String`. Julia's type dispatch doesn't automatically convert `SubString{String}` → `String`.

**Fix:** Wrapped the `strip()` call in `String()`: `vote_text = String(strip(join([...], " ") * " " * user_input))`

### 2. Rule pattern matching against `vote_data` only (not `user_input`)

**Root cause:** The original `vote_text` was constructed from `get(v, "action", "")` fields in `vote_data`, which don't include the user's input text. Rules with patterns like `"consciousness"` would never match because the user_input `"what is consciousness?"` was never part of the pattern-matching text.

**Fix:** Appended `user_input` to `vote_text`: `vote_text = String(strip(join([get(v, "action", "") for v in vote_data], " ") * " " * user_input))`

### 3. SelfObserver reinforcement semantics

**Behavior discovered:** When `observe!` is called with the same key + tag + provenance, the existing entry is **reinforced** (weight boosted, payload merged, timestamp refreshed) rather than creating a new `Microlog` entry. `total_entries` only increments on genuinely new entries. This is by design — it's how "I keep noticing X" sticks — but it means the test needed to account for this behavior.

**Fix:** Updated test 4.5 to verify reinforcement (store size stays the same for same key+tag) and added test 4.5b that verifies a different tag on the same key creates a new entry.

---

## Test Results — Full Breakdown

### Section 1: Observation Threshold (8 tests)

| Test | Description | Result |
|------|-------------|--------|
| 1.1 | Default threshold is 5 | ✅ PASS |
| 1.2 | Status has observation_threshold key | ✅ PASS |
| 1.3 | Status observation_threshold == 5 | ✅ PASS |
| 1.4 | Set threshold to 3 | ✅ PASS |
| 1.5 | Set threshold to 0 | ✅ PASS |
| 1.6 | Adjustments enabled when threshold=0 | ✅ PASS |
| 1.7 | Reset threshold to 5 | ✅ PASS |
| 1.8 | Negative threshold throws error | ✅ PASS |

### Section 2: SelfObserver Gate Integration (6 tests)

| Test | Description | Result |
|------|-------------|--------|
| 2.1 | Adjustments disabled when observer_count=0 | ✅ PASS |
| 2.2 | Adjustments disabled when observer_count=4 | ✅ PASS |
| 2.3 | Adjustments enabled when observer_count=5 | ✅ PASS |
| 2.4 | Adjustments enabled when observer_count=10 | ✅ PASS |
| 2.5 | With threshold=2, observer_count=2 enables adjustments | ✅ PASS |
| 2.6 | With threshold=2, observer_count=1 blocks adjustments (fresh state) | ✅ PASS |

### Section 3: Sigmoid/ReLU Activation Pipeline (5 tests)

| Test | Description | Result |
|------|-------------|--------|
| 3.1 | Novel input → ReLU activation | ✅ PASS |
| 3.2 | Novel input → high novelty score | ✅ PASS |
| 3.3 | Familiar input → Sigmoid activation | ✅ PASS |
| 3.4 | Familiar input → low novelty score | ✅ PASS |
| 3.5 | Transform counter increments | ✅ PASS |

### Section 4: SelfObserver Store Integration (8 tests)

| Test | Description | Result |
|------|-------------|--------|
| 4.1 | Create SubconsciousStore | ✅ PASS |
| 4.2 | Fresh store size == 0 | ✅ PASS |
| 4.3 | After observe!, store size == 1 | ✅ PASS |
| 4.4 | After 2 observations with different keys, key_count == 2 | ✅ PASS |
| 4.5 | Same key+tag reinforces (store size stays 2) | ✅ PASS |
| 4.6 | key_count still 2 (same key reused) | ✅ PASS |
| 4.5b | Same key+diff tag adds entry (store size == 3) | ✅ PASS |
| 4.7 | With observer_count=3, adjustments_enabled=true | ✅ PASS |

### Section 5: Feedback Mechanisms (4 tests)

| Test | Description | Result |
|------|-------------|--------|
| 5.1 | No-arg right feedback increments counter | ✅ PASS |
| 5.2 | No-arg wrong feedback increments counter | ✅ PASS |
| 5.3 | Right feedback with quality=0.95 | ✅ PASS |
| 5.4 | Wrong feedback with quality=0.3 | ✅ PASS |

### Section 6: Rule Management (6 tests)

| Test | Description | Result |
|------|-------------|--------|
| 6.1 | Add solid rule | ✅ PASS |
| 6.2 | Add fuzzy rule | ✅ PASS |
| 6.3 | Lookup rule by ID | ✅ PASS |
| 6.4 | Drop rule | ✅ PASS |
| 6.5 | Drop non-existent rule returns false | ✅ PASS |
| 6.6 | Pattern-matching rule fires | ✅ PASS |

### Section 7: Specimen Round-Trip (14 tests)

| Test | Description | Result |
|------|-------------|--------|
| 7.1 | Specimen version is 1.2 | ✅ PASS |
| 7.2 | Specimen has observation_threshold | ✅ PASS |
| 7.3 | observation_threshold == 7 | ✅ PASS |
| 7.4 | Specimen has selfobserver_observations | ✅ PASS |
| 7.5 | Specimen has adjustments_enabled | ✅ PASS |
| 7.6 | Specimen has input_correlations | ✅ PASS |
| 7.7 | Specimen has last_user_input | ✅ PASS |
| 7.8 | last_user_input preserved | ✅ PASS |
| 7.9 | Round-trip observation_threshold preserved | ✅ PASS |
| 7.10 | Round-trip right_feedback preserved | ✅ PASS |
| 7.11 | Round-trip wrong_feedback preserved | ✅ PASS |
| 7.12 | Round-trip transforms preserved | ✅ PASS |
| 7.13 | Round-trip rules preserved | ✅ PASS |
| 7.14 | v1.1 specimen defaults observation_threshold to 5 | ✅ PASS |

### Section 8: get_mlp_status Completeness (20 tests)

All 20 expected keys verified present in status output, including the new `observation_threshold`, `selfobserver_observations`, `adjustments_enabled`, `input_correlations`, and `last_user_input` keys.

### Section 9: Edge Cases (6 tests)

| Test | Description | Result |
|------|-------------|--------|
| 9.1 | Empty vote list returns error or handles gracefully | ✅ PASS |
| 9.2 | Very high threshold blocks adjustments | ✅ PASS |
| 9.3 | Threshold=1, count=1 enables adjustments | ✅ PASS |
| 9.4 | Special characters in user_input don't crash | ✅ PASS |
| 9.5 | 20 rapid transforms: total=20 | ✅ PASS |
| 9.6 | Sigmoid+ReLU = total | ✅ PASS |

---

## New Public API

### EphemeralMLP

```julia
# Get current observation threshold
EphemeralMLP.get_observation_threshold()::Int

# Set observation threshold (n >= 0; auto-enables adjustments if threshold already met)
EphemeralMLP.set_observation_threshold!(n::Int)::Int
```

### CLI Commands (Main.jl)

```
/mlpThreshold <n>    — Set the MLP observation threshold (how many SelfObserver entries before adjustments are non-zero)
/mlpObserver          — Show SelfObserver store statistics (entries, keys, write/eviction stats)
```

---

## Architecture Notes

### One-Way Gate: `adjustments_enabled`

The `adjustments_enabled` flag on `EphemeralMLPState` is a **one-way gate**: once it transitions from `false` to `true` (when `selfobserver_observations >= observation_threshold`), it stays `true` for the rest of the session. This is by design — the MLP "wakes up" once the brain has accumulated enough self-observation data to justify making adjustments. It does not revert if the observation count later drops (e.g., due to eviction in the SelfObserver store).

### SelfObserver Reinforcement

When `observe!` is called with a key that already has entries with the same tag and provenance, the existing entry is **reinforced** rather than duplicated. This means:

- `store_size` (total_entries) does NOT increment on reinforcement
- The entry's `weight` is boosted by `REINFORCE_GAIN * salience`
- The `payload` is merged additively (new keys added, existing keys overwritten)
- The `timestamp` is refreshed

To create a genuinely new entry under the same key, use a different tag (e.g., `:timing` vs `:meta`).

### vote_text Now Includes user_input

The `vote_text` variable in `transform_vote_list` — which is passed to `activate_rules_by_pattern!` for rule matching — now concatenates both the vote `action` fields and the `user_input` string. This means rules with patterns like `"consciousness"` will correctly fire when the user's input contains that word, even if the vote actions don't.

---

## Files Modified

| File | Lines Changed | Description |
|------|---------------|-------------|
| `src/EphemeralMLP.jl` | ~1960 | User-editable threshold, vote_text fix, specimen v1.2 |
| `src/Main.jl` | ~6800 | SelfObserver wiring, CLI commands, specimen v2.7 |
| `test_mlp_v724_comprehensive.jl` | ~250 | New comprehensive integration test (77 assertions) |

---

## Summary

All 77 integration tests pass. The EphemeralMLP observation threshold is now user-editable at runtime, the SelfObserver store is fully wired into the mission processing pipeline, and two bugs were discovered and fixed during testing (SubString type dispatch issue, and rule pattern matching not including user_input). The chat log is committed alongside the code.
