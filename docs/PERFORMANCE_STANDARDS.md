# GAW ModTools — Performance Standards

**Effective:** 2026-04-23
**Authority:** Non-negotiable. Every GIGA spec from this date forward must reference this file and every new feature must pass the acceptance checklist at the bottom.
**Source material:** Two cat-choir performance autopsies of v7.1.2 (Downloads/GAW_ModTools_Extreme_Performance_Optimization_Report.md and modtools_v7_1_2_performance_autopsy.md), convergent findings.

---

## Core principles

1. **State lives in RAM. Persistence is debounced, not synchronous.** `localStorage` and `chrome.storage.local` are write-back caches. Hot paths read from memory.
2. **Indexes, not scans.** Any O(N) lookup over mod log / roster / Death Row / watchlist that happens per-user-interaction MUST be pre-indexed as `Map` or `Set`.
3. **One observer. One tick.** No new `MutationObserver`s without hooking into the shared `DomScheduler`. No new `setInterval`s without hooking into the `MasterHeartbeat` via tick-modulo.
4. **Incremental, not rescan.** Observer callbacks process `mutations.addedNodes` only. They never re-`querySelectorAll` the document.
5. **Batch DOM writes.** `DocumentFragment` or string-array-join with one `innerHTML` write. Never iterative `appendChild` inside a loop.
6. **Route by page.** Subsystems only boot on pages they serve. The feed-page runtime does not arm the users-page triage observers.
7. **Delegate, do not multiply.** One document-level click handler reads `data-gam-action` from the bubbled target. Never per-row event listeners.
8. **Cache what costs.** Compiled regex, resolved selectors, parsed settings — all live in a `Map` keyed by the source string.

---

## MUST NOT (banned patterns)

| Pattern | Why |
|---|---|
| `localStorage.getItem(key)` + `JSON.parse` inside hot paths | Synchronous main-thread block. Read once at boot; after that, use in-memory cache. |
| `new RegExp(pattern)` inside a loop | Regex compilation is expensive. Compile at rule-load time, keep the `RegExp` object. |
| `document.addEventListener('mouseover', …)` with DOM traversal per event | Fires on every mouse tick (gaming mice ~1000Hz). Throttle with `requestAnimationFrame` or use CSS `:hover` + a single dwell timer. |
| New `MutationObserver` with `subtree:true` that calls page-wide `querySelectorAll` in its callback | O(N×M) DOM thrash. Consolidate into the shared scheduler and process only `addedNodes`. |
| Per-row / per-element event listeners added in render loops | Closure explosion, no cleanup, duplicated work. Delegate from a stable parent. |
| `log.filter(e => e.user === name)` for a single-user lookup | Full-log scan per call. Use `indexes.getUserHistory(name)` which is a `Map` lookup. |
| `dr.find(d => d.username === name)` | Linear array scan. Use `indexes.isDeathRowWaiting(name)` which is a `Set.has()`. |
| Iterative `container.appendChild(el)` or `container.innerHTML += …` inside a render loop | Forces reflow per iteration. Build a fragment or an array, commit once. |
| Calling `getSetting(key)` inside a tight loop when the key doesn't change | Re-reads the cached settings object unnecessarily. Hoist the read above the loop. |
| Multiple independent passes over the same selector on the same page (e.g., four separate `a[href^="/u/"]` scanners) | Each pass is independent I/O. Unify into a single overlay engine. |

---

## MUST USE (required patterns)

### `CachedStore` — in-memory store with debounced persistence

```js
class CachedStore {
  constructor(namespace, defaults = {}) { this.ns = namespace; this.defaults = defaults; this.state = null; this.flushTimer = 0; this.dirty = false; }
  load() { if (this.state) return this.state;
    let parsed; try { parsed = JSON.parse(localStorage.getItem(this.ns) || 'null'); } catch { parsed = null; }
    this.state = parsed && typeof parsed === 'object' ? { ...this.defaults, ...parsed } : { ...this.defaults };
    return this.state; }
  get(k, fb) { const s = this.load(); return k in s ? s[k] : fb; }
  set(k, v) { const s = this.load(); if (Object.is(s[k], v)) return; s[k] = v; this.markDirty(); }
  mutate(fn) { fn(this.load()); this.markDirty(); }
  markDirty() { this.dirty = true; if (this.flushTimer) return;
    this.flushTimer = setTimeout(() => this.flush(), 250); }
  async flush() { if (!this.dirty || !this.state) { this.flushTimer = 0; return; }
    const snap = this.state; this.dirty = false; this.flushTimer = 0;
    try { localStorage.setItem(this.ns, JSON.stringify(snap)); } catch {}
    try { chrome?.storage?.local?.set?.({ [this.ns]: snap }).catch?.(() => {}); } catch {} }
}
```

### `DerivedIndexes` — O(1) lookups

Required getters on boot + after every mutation of underlying stores:

- `getUserHistory(username) → entries[]` (from `logByUser: Map<username, entry[]>`)
- `getBanCount(username) → number` (from `banCountByUser: Map<username, number>`)
- `isWatched(username) → bool` (from `watchSet: Set<username>`)
- `isDeathRowWaiting(username) → bool` (from `drWaitingSet: Set<username>`)
- `getRosterRec(username) → rec|null` (from `rosterByUser: Map<username, rec>`)
- `flagSeverityByUser.get(key) → 'red'|'yellow'|'watch'|undefined`
- `titlesByUser.get(key) → title[]|undefined`

Rebuild is debounced (same tick as `CachedStore` flush). All keys are lowercased.

### `DomScheduler` — single observer, rAF-batched handlers

```js
class DomScheduler {
  constructor() { this.pending = false; this.addedRoots = []; this.handlers = []; }
  onProcess(fn) { this.handlers.push(fn); }
  observe(root = document.body) {
    new MutationObserver(muts => {
      for (const m of muts) for (const n of m.addedNodes) if (n.nodeType === 1) this.addedRoots.push(n);
      this.request();
    }).observe(root, { childList: true, subtree: true });
    this.request(document.body);
  }
  request(seed) { if (seed) this.addedRoots.push(seed);
    if (this.pending) return; this.pending = true;
    requestAnimationFrame(() => { this.pending = false;
      const roots = this.addedRoots.splice(0);
      if (!roots.length) return;
      for (const fn of this.handlers) fn(roots); }); }
}
```

### `MasterHeartbeat` — single `setInterval`, modulo-dispatched subtasks

```js
const MH = { tick: 0, subs: [] };
MH.every = (seconds, fn) => MH.subs.push({ mod: seconds, fn });
setInterval(() => {
  if (document.visibilityState !== 'visible') return;
  MH.tick++;
  for (const s of MH.subs) if (MH.tick % s.mod === 0) { try { s.fn(); } catch {} }
}, 1000);
```

Subscribers: `MH.every(5, updateDrCounter)`, `MH.every(60, autoRefreshTick)`, `MH.every(120, pollSessionHealth)`, `MH.every(300, pullPatternsFromCloud)`, etc. No new `setInterval` calls.

### `regexCache` — compile once, reuse forever

```js
const regexCache = new Map();
function compilePatternCached(src) {
  if (regexCache.has(src)) return regexCache.get(src);
  let re = null; try { re = compilePattern(src); } catch {}
  regexCache.set(src, re);
  return re;
}
```

Rule-list boot pre-populates the cache; hot paths never call raw `new RegExp`.

### `selectorCache` — memoize winning fallback

```js
const selectorCache = new Map();
function trySelect(key, ctx = document) {
  if (selectorCache.has(key)) {
    const el = ctx.querySelector(selectorCache.get(key));
    if (el) return el;
    selectorCache.delete(key);
  }
  const fbs = _SEL_FB[key];
  if (!fbs) return ctx.querySelector(SELECTORS[key] || key);
  for (let i = 0; i < fbs.length; i++) {
    const el = ctx.querySelector(fbs[i]);
    if (el) { selectorCache.set(key, fbs[i]); if (i > 0) learnSelector(key, fbs[i]); return el; }
  }
  return null;
}
```

### Event delegation

Single document-level click handler. Every interactive element ships with `data-gam-action="<verb>"` and optional `data-gam-target="<id>"`. Handler uses `e.target.closest('[data-gam-action]')` and dispatches on the verb. No `addEventListener` calls inside render loops, ever.

### DOM batching

```js
// Bad
for (const row of rows) container.appendChild(makeRow(row));
// Good
const frag = document.createDocumentFragment();
for (const row of rows) frag.appendChild(makeRow(row));
container.appendChild(frag);
// Also good
container.innerHTML = rows.map(renderRowHTML).join('');
```

---

## Benchmarked wins (April 2026 cat-choir measurements)

| Pattern | Naive | Optimized | Speedup |
|---|---:|---:|---:|
| 50K log × 2K lookups — `filter()` vs `Map.get()` | 2983 ms | 11 ms | **~269×** |
| 100K setting reads — `JSON.parse` each vs cached object | 469 ms | 1.6 ms | **~297×** |
| 2K users × 800 DR — `Array.find()` vs `Set.has()` | 20.7 ms | 0.6 ms | **~34×** |
| 10 sequential async — vs bounded concurrency 4 | 1206 ms | 363 ms | **~3.3×** |
| Selector hot path 500× — vs memoized winner | 340 ms | 4 ms | **~85×** |
| `loadStats` 100× — 5 filter passes vs single pass | 92 ms | 11 ms | **~8.4×** |

These are the moves that buy orders-of-magnitude. Not micro-tricks — architecture.

---

## Acceptance checklist for every future GIGA

Every feature GIGA must append these criteria to its acceptance list. Verify scripts must check each:

- [ ] No new raw `localStorage.getItem` / `JSON.parse` / `localStorage.setItem` / `JSON.stringify` in hot paths. All persisted state uses an existing `CachedStore` or adds one.
- [ ] No new `MutationObserver` — feature hooks into the shared `DomScheduler` via `onProcess(fn)`.
- [ ] No new `setInterval` or recurring `setTimeout` — feature hooks into `MasterHeartbeat` via `MH.every(seconds, fn)`.
- [ ] Any per-user lookup over log / roster / watchlist / Death Row uses a `DerivedIndexes` getter.
- [ ] Any regex used in a loop is cached via `compilePatternCached` or equivalent.
- [ ] Event listeners are delegated from a stable parent, never attached per row/per element.
- [ ] DOM insertion of more than one element uses `DocumentFragment` or batched string `innerHTML`.
- [ ] Feature code is gated on `PAGE.<role>` (router) — only boots on pages where it's relevant.
- [ ] No new document-level `mouseover` / `mousemove` listeners without rAF throttle AND dwell-timer gate.
- [ ] `verify` script greps the new feature's source for banned patterns (see MUST NOT table) and fails on any hit.

---

## Retrofit plan (out of scope for feature work)

The existing v7.1.2 modtools.js violates several of these standards — not a shame, it's pre-standards code. Retrofit is deferred to a dedicated **v7.3 Performance Pass** GIGA (separate build, separate risk profile). Greenfield feature code from v8.0 forward MUST follow standards from the first line; legacy code gets migrated opportunistically when a feature touches the same path.

Separation of concerns: performance work never mixes with feature work in the same ship. Either build is a feature (risk: bugs in new behavior) or a retrofit (risk: regression in established behavior). Mixing both doubles the verification burden and hides which change caused which regression.

---

## What to do when the standards collide with "ship it"

If a feature genuinely cannot be built within these standards (novel pattern, infrastructure gap), the GIGA MUST include a **"Standards Exception"** section naming:
1. Which standard is violated
2. Why it's the only path
3. What the retrofit cost is
4. Commit to file the retrofit as a follow-up GIGA before the feature leaves flag-gating

No silent exceptions. No "I'll fix it later." The exception section is the fix-later commitment, in writing, reviewable.
