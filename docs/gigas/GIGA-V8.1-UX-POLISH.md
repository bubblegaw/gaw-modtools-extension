# GIGA-V8.1-UX-POLISH

**Audience:** Claude Code session with blanket approval from Commander Cats.
**Target:** GAW ModTools v8.0.0 -> v8.1.0.
**Scope bias:** v8.0 delivered team productivity features (Shadow Queue, Park, Precedent-Citing Ban). v8.1 is a **pure UX polish release** -- no new features, no new worker endpoints, no new migrations, no new storage schemas. Every improvement is additive and gated behind a single new flag `features.uxPolish` (default OFF). Flag-off state is v8.0 byte-for-byte parity on every observable code path; flag-on state upgrades the experience across five dimensions: accessibility (WCAG 2.2 AA), skeleton loading states, empty states with CTAs, optimistic UI for high-frequency actions, and touch-target compliance (44x44 min).
**Non-negotiable:** `D:\AI\_PROJECTS\PERFORMANCE_STANDARDS.md` remains authoritative for every line of greenfield code. The v8.0 CHUNK 0 primitives (`CachedStore`, `DomScheduler`, `MasterHeartbeat`, `DerivedIndexes`, `regexCache`, `selectorCache`) are reused; no new observers, no new setIntervals, no new RegExp-in-loop. The source playbook for UI/UX rationale is `C:\Users\smoki\Downloads\Ultimate_App_Development_Best_Practices_Playbook.md`.

---

## MISSION

Ship v8.1 as a single coherent polish pass across five UX dimensions, in strict order:

1. **Area 1 -- Accessibility (WCAG 2.2 AA).** Focus traps on every modal, aria-live regions for snacks/errors, label-for associations on every input, documented keyboard Tab order, contrast-ratio audit + variable bumps.
2. **Area 2 -- Skeleton loading states.** `renderSkeleton(variant)` helper; IntelDrawer sections, Triage Console expansions, Queue page get shimmering placeholders instead of "loading..." text. Respects `prefers-reduced-motion`.
3. **Area 3 -- Empty states with CTAs.** `renderEmptyState({icon, headline, description, ctaLabel, ctaAction})` helper; sweep of every `(no|No) \w+\.` plain-text block with a proper empty-state card + inline SVG icon.
4. **Area 4 -- Optimistic UI for high-frequency actions.** `optimisticAction(params)` helper; applied to ban execute, draft save, and watchlist toggle. Immediate UI response, background worker call, rollback + error snack on failure.
5. **Area 5 -- Touch targets (44x44 min).** CSS audit + pad-without-shifting-layout for visually-small icons (status-bar), real size bumps for buttons that can afford it (modal close, row delete).

No D1 migrations. No new worker endpoints. No wrangler deploy. No git push. One PowerShell verification script (`verify-v8-1.ps1`), one manifest bump, one shared-flag version bump.

All v8.1 additions are delimited by sentinel comments in `modtools.js`: `// ===== v8.1 UX POLISH =====` and `// ===== END v8.1 =====`. Every feature sub-block is tagged `// --- v8.1 ux: <name> ---` and `// --- end v8.1 ux ---`. The verify script greps for banned patterns only within these delimited regions, leaving v7.x and v8.0 code untouched.

---

## DELIVERABLES

| Path | Purpose |
|---|---|
| `D:\AI\_PROJECTS\modtools-ext\modtools.js` | v8.1 region: 5 area helpers (`installFocusTrap`, `renderSkeleton`, `renderEmptyState`, `optimisticAction`, `linkLabel`); aria-live mounts; sweep of existing UI call-sites to invoke helpers when `features.uxPolish=true`; CSS additions for shimmer, empty state, hit-area padding, bumped contrast variables |
| `D:\AI\_PROJECTS\modtools-ext\manifest.json` | version 8.1.0 |
| `D:\AI\_PROJECTS\gaw-mod-shared-flags\version.json` | 8.1.0 |
| `D:\AI\_PROJECTS\verify-v8-1.ps1` | BOM+ASCII+4-step, static checks for all 5 areas including a contrast-ratio audit (PowerShell implementation of the luminance formula, no external deps) |

No new files beyond the verify script. No changes to `gaw-mod-proxy-v2.js`, no changes to any migration SQL, no changes to any dashboard file.

---

## AREA -> CHUNK MAP

| # | Area | Chunks |
|---|---|---|
| - | Flag wire + sentinel scaffold + gating helpers | **0** |
| A | Accessibility -- focus trap helper | 1 |
| A | Accessibility -- aria-live regions for snacks/errors | 2 |
| A | Accessibility -- label-for association sweep | 3 |
| A | Accessibility -- keyboard Tab-order audit + tabindex | 4 |
| A | Accessibility -- contrast-ratio audit + variable bumps | 5 |
| B | Skeleton -- `renderSkeleton` helper + CSS | 6 |
| B | Skeleton -- IntelDrawer + Triage + Queue integration | 7 |
| C | Empty states -- `renderEmptyState` helper + inline SVG icons | 8 |
| C | Empty states -- sweep of existing plain-text "no X" sites | 9 |
| D | Optimistic UI -- `optimisticAction` helper | 10 |
| D | Optimistic UI -- ban execute + draft save + watchlist toggle | 11 |
| E | Touch targets -- pad-without-shifting-layout CSS sweep | 12 |
| - | Verify + manifest + shared-flag bump | 13 |

14 chunks total. Each chunk is a single cohesive task with its own acceptance criterion; no chunk mixes two areas.

---

## ACCEPTANCE CRITERIA

### Part 1 -- Cross-cutting (every v8.1 chunk must satisfy)

- [ ] `node --check D:\AI\_PROJECTS\modtools-ext\modtools.js` exits 0 after every chunk.
- [ ] All v8.1 additions live inside `// ===== v8.1 UX POLISH =====` / `// ===== END v8.1 =====` sentinels.
- [ ] No new `MutationObserver`, no new `setInterval`, no new recurring `setTimeout` in v8.1 region. Any dynamic work routes through existing `DomScheduler.onProcess` or `MH.every`.
- [ ] No new `new RegExp(...)` in a loop in v8.1 region; use `compilePatternCached` if needed.
- [ ] No `innerHTML` on any string that originated from a network response; every node built via `el()` with `textContent` children.
- [ ] Every v8.1 DOM element has either semantic HTML (`<button>`, `<label>`, `<input>`, etc.) OR an explicit ARIA role.
- [ ] Every v8.1 CSS rule that animates respects `@media (prefers-reduced-motion: reduce)`.
- [ ] **Flag-off parity check:** with `features.uxPolish=false` (default), every v8.0 smoke-test user flow is byte-identical to v8.0.0 (snack text and animation, empty-state text, modal open/close DOM sequence, button dimensions). The verify script greps every v8.1 helper call site for the gating guard `__uxPolishOn() && __hardeningOn()` and fails on any un-gated call.

### Part 2 -- Area-specific

- [ ] **A1 focus trap.** With `features.uxPolish=true`, opening IntelDrawer, Mod Console popover, Park modal, `askTextModal`, bug-report modal, or any modal surfaced by `showModal()` installs a focus trap that: (a) moves focus to the first focusable child on open, (b) traps Tab + Shift-Tab within the modal root, (c) restores focus to the opener element on close, (d) closes on `Escape` via the existing v7.0 Escape delegate (no new keydown listeners). Tested via `document.activeElement` assertions at each modal entry. Flag-off -> zero `installFocusTrap` calls fire, zero behavior change.
- [ ] **A2 aria-live.** Exactly two live regions mount on boot when `features.uxPolish=true`: `<div id="gam-live-polite" aria-live="polite" aria-atomic="true" class="gam-sr-only">` and `<div id="gam-live-assertive" aria-live="assertive" aria-atomic="true" class="gam-sr-only">`. `snack(msg, kind)` routes to polite for `info`/`success`/`warn`, to assertive for `error`. The existing snack visual is unchanged. Flag-off -> regions never mount, snack routes nowhere live.
- [ ] **A3 labels.** Every `<label>` + `<input>` / `<textarea>` / `<select>` pair inside a v8.1-touched modal has a matching `for=` attribute linking to a unique `id=`. `linkLabel(labelEl, inputEl)` generates a deterministic id (`gam-f-<counter>`) to avoid DOM collisions. Verify grep: zero `<label>` tags without `for=` inside v8.1-touched modal builders. Flag-off -> no id injection, legacy DOM unchanged.
- [ ] **A4 keyboard.** Each of the following modals has a Tab-order comment block in its builder function documenting the ordered focusable set: IntelDrawer (6 sections), Mod Console popover, Park modal, `askTextModal`, bug-report modal. `tabindex="0"` added to every non-button interactive element that currently requires a mouse. Verify grep: zero `tabindex="-1"` on interactive elements in v8.1-touched code (except the outer modal container, which is standard). Flag-off -> no tabindex attribute modifications at runtime.
- [ ] **A5 contrast.** Current `--gam-muted-text` value audited against background `--gam-bg-dark`. Luminance-contrast ratio computed; if < 4.5:1, bumped to nearest passing value. All other CSS variable pairs (button text on button bg, link text on card bg, warning-chip text on warning-chip bg) audited the same way. **The verify script implements the WCAG contrast formula in PowerShell** and fails if any v8.1 variable pair is below 4.5:1. Dark theme aesthetic preserved (no hue shifts, only luminance bumps). Flag-off -> the bumped variable values still apply (CSS overrides are always-on; the only flag-gated piece is the sweep of which classes USE the new variables vs the old ones). **Clarification:** variable values are updated once globally; sites that reference the new pass-grade variable always get it, whether flag is on or off. This is acceptable because contrast improvements cannot cause visual regressions in dark-theme moderation UI.
- [ ] **B skeleton.** `renderSkeleton(variant)` returns a DOM node matching the requested shape (`text-line`, `paragraph`, `row`, `card`, `avatar`). CSS: single keyframe `gam-skeleton-shimmer` at 2s linear infinite, wrapped in `@media (prefers-reduced-motion: no-preference)`. Default state (reduced-motion, or motion preference unset) renders a static gray block, no animation. IntelDrawer: each of the 6 sections calls `renderSkeleton('paragraph')` during initial render, swapped via `el()` on network resolve. Triage Console row expansion: calls `renderSkeleton('card')` while awaiting profile intel. Queue page: calls `renderSkeleton('row')` x3 while initial list loads. Flag-off -> zero skeleton calls, legacy "loading..." text unchanged.
- [ ] **C empty states.** `renderEmptyState({icon, headline, description, ctaLabel, ctaAction})` returns a `<div class="gam-empty-card">` with structured children. `icon` is a key into an inline SVG map (`inbox-empty`, `users-empty`, `rules-empty`, `actions-empty`, `modmail-empty`); no external image/font dependency. At minimum the following call sites use the helper when flag on: Auto-DR rules panel, C5 Command Center mods-online list, presence HUD users list, AI drafts pending panel, "No modmail threads" section. Verify grep: zero plain-text `>No [A-Z]` or `>no [a-z]` strings inside v8.1-touched render functions when flag would be on. Flag-off -> plain text rendered as in v8.0.
- [ ] **D optimistic UI.** `optimisticAction({apply, revert, doWork, onErrorSnack})` immediately calls `apply()`, kicks off `doWork()` (returns a Promise), and on rejection calls `revert()` + shows `onErrorSnack`. Helper is pure, no global state. **Ban execute flow:** clicking Execute closes the modal immediately, shows a `<span class="gam-status-chip">Banning @user...</span>` mounted at the existing status-chip rail, flips to `<span class="gam-status-chip gam-ok">Banned @user</span>` on success or rolls back (modal not reopened; snack error) on failure. **Draft save flow:** clicking Save disables button + changes label to `Saved (undo)` for 4s, then reverts to `Save`; on network failure the label flips to `Save` and an error snack fires. **Watchlist toggle flow:** the watch icon visually flips immediately; on failure flips back + error snack. Flag-off -> all three flows use v8.0 synchronous behavior.
- [ ] **E touch targets.** Every `.gam-*-btn` / `.gam-*-icon` class that currently renders below 44x44 has either (a) its visible size bumped to >= 32x32 AND a padded hit area of >= 44x44, OR (b) a transparent-padding wrapper yielding 44x44 clickable bounds without shifting adjacent layout. Specific fixes: status-bar icons (`gam-bar-icon`) get 11px padding each side (22px visible + 22px pad = 44x44 hit); modal close `x` bumped to 32px visible + 12px pad for 44 total; Triage Console delete icon bumped to 32px visible + 12px pad. Layout regression check: the status bar total width stays within 2px of v8.0 via CSS `margin` adjustment to absorb the added padding. Verify grep: every `.gam-*-icon` class in the v8.1 CSS block has a computed hit area >= 44x44 (via a simple PowerShell parser that reads `width` + `padding` from the CSS block). Flag-off -> all new CSS rules are scoped under `.gam-ux-polish-on` body class; flag-off = body lacks class, old rules win.
- [ ] `verify-v8-1.ps1` exits 0 with every check PASS. BOM + ASCII + 4-step ending.
- [ ] `manifest.json` version === 8.1.0. `gaw-mod-shared-flags\version.json` === 8.1.0.

---

## BAKED-IN DESIGN DECISIONS (not up for re-litigation)

1. **Single flag, not five.** `features.uxPolish` gates all five areas at once. Five sub-flags would create 32 user-facing matrix states; one flag keeps the rollout story simple ("UX polish on or off") and the regression surface small. Commander dogfoods the whole pack before rolling.
2. **Flag-off is v8.0 byte-for-byte parity.** Every helper call site checks `__uxPolishOn() && __hardeningOn()`. The hardening gate is inherited because several polishes depend on v7.2's `el()`-only discipline and the existing Escape delegate; if hardening is off, uxPolish is effectively off too.
3. **Contrast bumps are globally applied.** See A5 acceptance criterion -- bumping a CSS variable's luminance is non-destructive in a dark moderation UI; there is no sensible "flag-off path" for a contrast fix. If we kept the failing variable behind the flag, flag-off users would still be non-compliant. The verify script audits the bumped values, not the flag state.
4. **`renderSkeleton` respects reduced motion by default.** The shimmer animation only runs when the user has explicitly NOT set `prefers-reduced-motion: reduce`. On reduced-motion systems, a static gray block renders. This matches the Ultimate Playbook's accessibility-first default.
5. **`renderEmptyState` icons are inline SVG strings.** No webfont, no image sprite, no external CDN. Each icon is a string constant in a `UX_SVG` map; `renderEmptyState` parses the string once and clones the resulting node. Total payload: ~2 KB for all five icons combined.
6. **`optimisticAction` applies to exactly three flows in v8.1.** Ban execute, draft save, watchlist toggle. Other candidate flows (queue filter change, rule reorder, modmail archive) are explicitly deferred to v8.2 -- see OUT OF SCOPE. Keeping the scope tight means the verify script can grep for exactly three `optimisticAction(` call sites.
7. **Touch-target CSS lives in a single block scoped to `.gam-ux-polish-on`.** `document.body.classList.toggle('gam-ux-polish-on', __uxPolishOn() && __hardeningOn())` runs on boot. Flag-off -> the class is absent, every touch-target rule is un-matched, v8.0 CSS wins. No rule rewrites for v8.0 classes; only new rules are added.
8. **`installFocusTrap(rootEl)` returns a cleanup function.** The caller (modal builder) stores the cleanup function on `rootEl._gamFocusCleanup`; the existing modal-close path invokes it. No new global listener registry.
9. **aria-live regions are the ONLY mechanism for screen-reader announcements in v8.1.** No `role="alert"` dynamic injection, no `aria-describedby` dance. Two regions at boot (`polite` + `assertive`), text nodes swapped in on snack. Debounced 50ms so rapid-fire snacks don't spam.
10. **`linkLabel` never mutates labels that already have `for=` set.** It only fills the gap. This keeps the sweep safe against accidentally re-linking an already-correct pair.
11. **Keyboard audit is documentation-first.** The deliverable for chunk 4 is Tab-order comments and a minimal set of `tabindex="0"` additions -- not a full keyboard-navigation rewrite. The Escape delegate stays v7.0's; arrow-key navigation is OUT OF SCOPE (v8.2).
12. **No retrofit of v8.0 snack sites to use aria-live directly.** v8.0 snacks keep their current visual; the aria-live wiring happens inside `snack()`, so every existing `snack(...)` call automatically routes. This is the minimum-change path -- no sweep of 50+ call sites needed.
13. **Verify script's contrast audit is self-contained PowerShell.** No Node, no Python, no external lib. The WCAG relative-luminance formula is ~20 lines of PowerShell; running it inline keeps the verify script dependency-free and parse-clean on both PS 5.1 and PS 7. See CHUNK 13 for the formula implementation.
14. **No changes to the existing snack DOM structure.** v8.1 only adds aria-live mount points and routing logic inside `snack()`. The snack's own `<div class="gam-snack">` stays byte-identical. This preserves any CSS and screenshot-based tests.
15. **CSS variables for contrast bumps are renamed forward, not in place.** Old `--gam-muted-text` becomes `--gam-muted-text-legacy` (kept for any v7.x code that still reads it); the new passing value is `--gam-muted-text`. Any v8.1-touched component references `var(--gam-muted-text)` and gets the passing value automatically. v7.x code that references `--gam-muted-text-legacy` is untouched.

---

## CHUNK 0 -- Flag wire + sentinel scaffold + gating helpers

File: `modtools.js`. Insert the v8.1 sentinel block at the bottom of the v8.0 additions (above any feature-specific v8.0 IIFEs), then wire the flag default and the gating helpers.

### What to add

1. Sentinel open: `// ===== v8.1 UX POLISH =====`
2. Flag default: in `DEFAULT_SETTINGS` add `'features.uxPolish': false`.
3. Gating helpers:
   ```js
   function __uxPolishOn() {
     return !!(stores.settings.load() || {})['features.uxPolish'];
   }
   // __hardeningOn() is v7.2's existing helper -- reused, not re-declared.
   function __uxOn() {
     return __uxPolishOn() && __hardeningOn();
   }
   ```
4. Body-class sync (runs on boot after settings are loaded, and on any settings flush via `stores.settings.onFlush`):
   ```js
   function __syncUxBodyClass() {
     try { document.body.classList.toggle('gam-ux-polish-on', __uxOn()); } catch {}
   }
   stores.settings.onFlush(__syncUxBodyClass);
   // initial sync deferred to first DomScheduler tick to guarantee body exists
   ```
5. Sentinel close (placed after the last v8.1 sub-block in later chunks, NOT now): `// ===== END v8.1 =====`

No user-visible change in this chunk. Flag defaults false -> `__uxOn()` returns false -> body class never applied -> v8.0 behavior.

**Success condition:** `node --check modtools.js` exits 0. Grep for `'features.uxPolish': false` returns 1 hit. Grep for `// ===== v8.1 UX POLISH =====` returns 1 hit.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 1 -- Focus trap helper + sweep

File: `modtools.js`. Inside the v8.1 sentinel region, add a `// --- v8.1 ux: focus-trap ---` sub-block.

### Helper

```js
// --- v8.1 ux: focus-trap ---
function installFocusTrap(rootEl) {
  if (!__uxOn() || !rootEl) return () => {};
  const FOCUSABLE = 'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]):not([type="hidden"]),select:not([disabled]),[tabindex]:not([tabindex="-1"])';
  const prevActive = document.activeElement;
  const getItems = () => Array.from(rootEl.querySelectorAll(FOCUSABLE)).filter(el => !el.hasAttribute('aria-hidden'));
  const onKey = (e) => {
    if (e.key !== 'Tab') return;
    const items = getItems();
    if (!items.length) { e.preventDefault(); return; }
    const first = items[0], last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) { last.focus(); e.preventDefault(); }
    else if (!e.shiftKey && document.activeElement === last) { first.focus(); e.preventDefault(); }
  };
  rootEl.addEventListener('keydown', onKey);
  // Move focus to first focusable on next microtask (ensures DOM painted)
  queueMicrotask(() => { const items = getItems(); if (items.length) items[0].focus(); });
  // Cleanup
  const cleanup = () => {
    rootEl.removeEventListener('keydown', onKey);
    try { if (prevActive && prevActive.focus) prevActive.focus(); } catch {}
  };
  rootEl._gamFocusCleanup = cleanup;
  return cleanup;
}
// --- end v8.1 ux ---
```

### Sweep

Inside these builders, insert `installFocusTrap(rootEl)` immediately after the modal is appended to the DOM, and call `rootEl._gamFocusCleanup?.()` in the matching close path:

1. `IntelDrawer.open` (drawer root element)
2. `buildModConsole` (popover root)
3. `openParkModal` (v8.0 addition)
4. `askTextModal` (generic prompt)
5. `openBugReportModal`
6. Any other `showModal(...)` wrapper

Each sweep site gated on `__uxOn()` -- the function early-returns a no-op cleanup when flag is off.

**Success condition:** grep for `installFocusTrap(` returns >= 6 hits (1 helper definition + 5 call sites). `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 2 -- aria-live regions for snacks/errors

File: `modtools.js`. Inside the v8.1 sentinel region, sub-block `// --- v8.1 ux: aria-live ---`.

### Helper

```js
// --- v8.1 ux: aria-live ---
const SR_ONLY_CSS = '.gam-sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0;}';
function __mountAriaLive() {
  if (!__uxOn()) return;
  if (document.getElementById('gam-live-polite')) return;
  const polite = document.createElement('div');
  polite.id = 'gam-live-polite';
  polite.className = 'gam-sr-only';
  polite.setAttribute('aria-live', 'polite');
  polite.setAttribute('aria-atomic', 'true');
  const assertive = document.createElement('div');
  assertive.id = 'gam-live-assertive';
  assertive.className = 'gam-sr-only';
  assertive.setAttribute('aria-live', 'assertive');
  assertive.setAttribute('aria-atomic', 'true');
  document.body.appendChild(polite);
  document.body.appendChild(assertive);
}
let __liveDebounce = 0;
function __announce(kind, msg) {
  if (!__uxOn()) return;
  const id = kind === 'error' ? 'gam-live-assertive' : 'gam-live-polite';
  const el = document.getElementById(id);
  if (!el) return;
  clearTimeout(__liveDebounce);
  __liveDebounce = setTimeout(() => { el.textContent = ''; el.textContent = String(msg || '').slice(0, 200); }, 50);
}
// --- end v8.1 ux ---
```

### Snack wiring

Inside the existing `snack(msg, kind)` body, add ONE line at the very top:
```js
__announce(kind === 'error' ? 'error' : 'polite', msg);
```

Mount the live regions on boot: add `__mountAriaLive()` as a DomScheduler first-tick callback (re-using v8.0's DS infrastructure). Also add `SR_ONLY_CSS` to the existing style injection block.

**Success condition:** grep for `__announce(` returns >= 2 hits (snack + at least one feature-code direct invoke is OK too but not required). Grep for `aria-live="polite"` returns 1 hit, `aria-live="assertive"` returns 1 hit. `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 3 -- Label-for association sweep

File: `modtools.js`. Sub-block `// --- v8.1 ux: label-for ---`.

### Helper

```js
// --- v8.1 ux: label-for ---
let __labelCounter = 0;
function linkLabel(labelEl, inputEl) {
  if (!__uxOn() || !labelEl || !inputEl) return;
  if (labelEl.hasAttribute('for') && inputEl.id) return; // already linked
  const id = inputEl.id || ('gam-f-' + (++__labelCounter));
  if (!inputEl.id) inputEl.id = id;
  labelEl.setAttribute('for', id);
}
// --- end v8.1 ux ---
```

### Sweep

Identify every `<label>` + adjacent input in v8.1-touched modal builders (same modal list as CHUNK 1 + the Auto-DR rule form + the draft editor + the Park note textarea + the bug-report title/body fields). For each pair, after both nodes are built but before append, call:
```js
linkLabel(labelEl, inputEl);
```

If the current code builds the label as a `<span>` (ambient text, not a semantic label), replace with a `<label>` element. This is a surgical replacement, one node at a time.

**Success condition:** grep for `linkLabel(` returns >= 10 hits (1 helper + >= 9 sweep sites). No `<label>` tag in v8.1-touched builders lacks a `for=` attribute after the sweep. `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 4 -- Keyboard Tab-order audit + tabindex

File: `modtools.js`. Sub-block `// --- v8.1 ux: kbd-audit ---`.

No new helper. This chunk is a documentation + minor tabindex sweep.

### Documentation blocks

Above each of these builders, add a comment block listing the intended Tab order:

```
// v8.1 ux kbd-audit: IntelDrawer Tab order
//   1. Close (X) button
//   2. Section 1 (Profile) primary action
//   3. Section 2 (Mod Log) -- scrollable, tabindex=0 on wrapper
//   4. Section 3 (Auto-DR Hits) primary action
//   5. Section 4 (Watchlist) primary action
//   6. Section 5 (Death Row) primary action
//   7. Section 6 (Precedents) primary action
```

Five blocks total: IntelDrawer, Mod Console popover, Park modal, `askTextModal`, bug-report modal.

### tabindex additions

For every non-button interactive element in these modals (e.g., scrollable sections that should receive focus, clickable cards that currently have no tabindex), add `tabindex="0"` via `el()` props. Example:

```js
const section = el('div', { class: 'gam-drawer-section', tabindex: '0', 'aria-label': 'Mod log for this user' }, ...);
```

Gate EVERY tabindex addition on `__uxOn()` by conditionally spreading the prop:
```js
const ax = __uxOn() ? { tabindex: '0', role: 'region', 'aria-label': '...' } : {};
const section = el('div', { class: 'gam-drawer-section', ...ax }, ...);
```

This keeps flag-off behavior byte-identical.

**Success condition:** grep for `v8.1 ux kbd-audit:` returns 5 hits. Grep for `__uxOn() ? { tabindex` or equivalent conditional-spread pattern returns >= 8 hits. `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 5 -- Contrast-ratio audit + variable bumps

File: `modtools.js` (CSS block). Sub-block `// --- v8.1 ux: contrast ---`.

### Audit targets

The existing CSS has roughly these variable pairs that render text-on-background in the moderation UI (exact names may differ -- use the actual names from v8.0):

- `--gam-muted-text` on `--gam-bg-dark`
- `--gam-muted-text` on `--gam-bg-card`
- `--gam-link` on `--gam-bg-card`
- `--gam-warn-text` on `--gam-warn-bg`
- `--gam-ok-text` on `--gam-ok-bg`
- `--gam-danger-text` on `--gam-danger-bg`

### Sweep action

1. For each pair, compute current luminance ratio using the WCAG 2.1 formula (see CHUNK 13 verify implementation).
2. If < 4.5:1, bump the **text** value's luminance up (lighter) toward passing. Preserve hue. The bump is typically 10-20 L\* units in LCH space, or approximately a `#xxx -> #yyy` hex change.
3. Rename the old variable to `--<name>-legacy` (kept in CSS for v7.x references); assign the new value to `--<name>`.
4. Document every change inline:
   ```css
   /* v8.1 ux contrast: --gam-muted-text bumped from #7a7a80 (3.9:1) to #9ba0a6 (4.8:1) on --gam-bg-dark #1a1a1e */
   ```

### Scope note

Contrast variable updates are **not** flag-gated (see Decision #3). The sweep applies globally; flag-off users also benefit. This is the ONE exception to flag-off parity in v8.1, justified by WCAG compliance being non-negotiable and non-destructive in a dark theme.

**Success condition:** the verify script's contrast audit (CHUNK 13) reports 0 failures. Every variable pair >= 4.5:1. `node --check` exits 0. Grep for `v8.1 ux contrast:` in CSS comments returns >= 3 hits.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 6 -- renderSkeleton helper + CSS

File: `modtools.js`. Sub-block `// --- v8.1 ux: skeleton ---`.

### Helper

```js
// --- v8.1 ux: skeleton ---
function renderSkeleton(variant) {
  if (!__uxOn()) return null;
  const V = {
    'text-line': { cls: 'gam-sk-line', count: 1 },
    'paragraph': { cls: 'gam-sk-line', count: 3 },
    'row':       { cls: 'gam-sk-row', count: 1 },
    'card':      { cls: 'gam-sk-card', count: 1 },
    'avatar':    { cls: 'gam-sk-avatar', count: 1 },
  };
  const cfg = V[variant] || V['text-line'];
  const wrap = document.createElement('div');
  wrap.className = 'gam-skeleton-wrap';
  wrap.setAttribute('aria-busy', 'true');
  wrap.setAttribute('aria-live', 'off');
  for (let i = 0; i < cfg.count; i++) {
    const n = document.createElement('div');
    n.className = cfg.cls + ' gam-skeleton-shimmer';
    wrap.appendChild(n);
  }
  return wrap;
}
// --- end v8.1 ux ---
```

### CSS

```css
/* v8.1 ux: skeleton */
.gam-skeleton-wrap { display:flex; flex-direction:column; gap:8px; padding:8px 0; }
.gam-sk-line    { height:12px; border-radius:4px; background:#2a2a30; }
.gam-sk-row     { height:36px; border-radius:6px; background:#2a2a30; }
.gam-sk-card    { height:120px; border-radius:8px; background:#2a2a30; }
.gam-sk-avatar  { width:32px; height:32px; border-radius:50%; background:#2a2a30; }
@media (prefers-reduced-motion: no-preference) {
  .gam-skeleton-shimmer {
    background: linear-gradient(90deg, #2a2a30 0%, #3a3a42 50%, #2a2a30 100%);
    background-size: 200% 100%;
    animation: gam-skeleton-shimmer 2s linear infinite;
  }
  @keyframes gam-skeleton-shimmer {
    0%   { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }
}
/* end v8.1 ux skeleton */
```

CSS scoped under `.gam-ux-polish-on` body class.

**Success condition:** grep for `function renderSkeleton(` returns 1 hit. Grep for `@keyframes gam-skeleton-shimmer` returns 1 hit. `@media (prefers-reduced-motion` surrounds the animation block. `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 7 -- Skeleton integration (IntelDrawer, Triage, Queue)

File: `modtools.js`. No new sentinel sub-block; integrate directly in existing render paths behind `__uxOn()`.

### Integration sites

1. **IntelDrawer six sections.** In each section's initial render (before the network resolve fills it), replace the existing `el('div', {}, 'loading...')` with:
   ```js
   const placeholder = __uxOn() ? renderSkeleton('paragraph') : el('div', {}, 'loading...');
   section.appendChild(placeholder);
   ```
   On network resolve, clear the section and append real content.
2. **Triage Console row expansion.** When a row expands and fires `/ai/next-best-action`, mount `renderSkeleton('card')` in the expanded area while awaiting.
3. **Queue page.** On initial list load, mount 3 `renderSkeleton('row')` nodes.

Each site conditionally uses `renderSkeleton` on flag; flag-off falls through to v8.0 text.

**Success condition:** grep for `renderSkeleton(` returns >= 4 hits (1 helper + 3 integration sites). `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 8 -- renderEmptyState helper + inline SVG icons

File: `modtools.js`. Sub-block `// --- v8.1 ux: empty-state ---`.

### Icon map (all inline SVG strings)

```js
const UX_SVG = {
  'inbox-empty':    '<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M3 12l3-7h12l3 7v7H3z"/><path d="M3 12h5l1 2h6l1-2h5"/></svg>',
  'users-empty':    '<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><circle cx="17" cy="9" r="2.2"/><path d="M15 20a4 4 0 0 1 6 0"/></svg>',
  'rules-empty':    '<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M8 9h8M8 13h8M8 17h5"/></svg>',
  'actions-empty':  '<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M12 3v18M3 12h18"/></svg>',
  'modmail-empty':  '<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></svg>',
};
```

### Helper

```js
// --- v8.1 ux: empty-state ---
function renderEmptyState(opts) {
  if (!__uxOn()) return null;
  const { icon, headline, description, ctaLabel, ctaAction } = opts || {};
  const card = document.createElement('div');
  card.className = 'gam-empty-card';
  card.setAttribute('role', 'status');
  if (icon && UX_SVG[icon]) {
    const iw = document.createElement('div');
    iw.className = 'gam-empty-icon';
    iw.innerHTML = UX_SVG[icon]; // STATIC string, not fetched -- XSS-safe per playbook §7
    card.appendChild(iw);
  }
  if (headline) {
    const h = document.createElement('div');
    h.className = 'gam-empty-headline';
    h.textContent = String(headline);
    card.appendChild(h);
  }
  if (description) {
    const d = document.createElement('div');
    d.className = 'gam-empty-desc';
    d.textContent = String(description);
    card.appendChild(d);
  }
  if (ctaLabel && typeof ctaAction === 'function') {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'gam-empty-cta';
    btn.textContent = String(ctaLabel);
    btn.addEventListener('click', (e) => { try { ctaAction(e); } catch {} });
    card.appendChild(btn);
  }
  return card;
}
// --- end v8.1 ux ---
```

### CSS

```css
/* v8.1 ux: empty-state */
.gam-empty-card     { display:flex; flex-direction:column; align-items:center; gap:12px; padding:32px 20px; background:#1f1f24; border-radius:8px; text-align:center; color:var(--gam-muted-text); }
.gam-empty-icon     { color:#5a5a62; }
.gam-empty-headline { font-size:15px; font-weight:600; color:#e5e5e8; }
.gam-empty-desc     { font-size:13px; color:var(--gam-muted-text); max-width:320px; line-height:1.5; }
.gam-empty-cta      { margin-top:4px; padding:8px 16px; background:#3a3a42; color:#e5e5e8; border:none; border-radius:6px; cursor:pointer; font-size:13px; min-height:44px; min-width:44px; }
.gam-empty-cta:hover { background:#4a4a52; }
```

**XSS note:** the SVG strings in `UX_SVG` are static compile-time constants, never fetched, never user-controlled. Per playbook §7 (XSS), `innerHTML` on a static constant is safe. All other content (headline/description) uses `textContent`. The verify script greps for `innerHTML.*UX_SVG` and allows it (whitelisted); `innerHTML.*${` in v8.1 region fails as always.

**Success condition:** grep for `function renderEmptyState(` returns 1 hit. Grep for `const UX_SVG =` returns 1 hit. Grep for `innerHTML` in v8.1 region returns exactly 1 hit (inside `renderEmptyState`). `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 9 -- Empty-state sweep of existing sites

File: `modtools.js`. No new sub-block; edit existing render paths.

### Sites to sweep

For each site, replace the plain-text "No X" rendering with a `renderEmptyState` call behind the flag. Flag-off retains plain text.

1. Auto-DR rules panel "No rules. Add one below."
   ```js
   if (__uxOn()) {
     container.appendChild(renderEmptyState({
       icon: 'rules-empty',
       headline: 'No automod rules yet',
       description: 'Add your first rule to auto-flag comments that match a pattern.',
       ctaLabel: 'Add rule',
       ctaAction: () => focusAddRuleInput(),
     }));
   } else {
     container.appendChild(el('div', {}, 'No rules. Add one below.'));
   }
   ```
2. C5 Command Center "No mods online." -> icon `users-empty`, headline "No other mods online", description "You're solo -- flags will fire through to your queue.", no CTA.
3. Presence HUD "No users online." -> icon `users-empty`, headline "Presence channel quiet", description "No other mods have this page open right now.", no CTA.
4. AI drafts pending panel (currently renders nothing) -> icon `actions-empty`, headline "No AI drafts waiting", description "When the AI queues a draft ban message, it shows here.", no CTA.
5. Modmail empty state (if present) -> icon `modmail-empty`, headline "No modmail threads", description "Incoming modmail appears here.", no CTA.

### Sweep

Grep for plain-text strings matching the pattern `/>No [A-Z][a-z]+/` within render functions; each hit in v8.1-touched code must be swapped to the conditional form above.

**Success condition:** grep for `renderEmptyState(` returns >= 6 hits (1 helper + >= 5 sweep sites). `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 10 -- optimisticAction helper

File: `modtools.js`. Sub-block `// --- v8.1 ux: optimistic ---`.

### Helper

```js
// --- v8.1 ux: optimistic ---
function optimisticAction(params) {
  if (!__uxOn()) {
    // Flag-off: do the work synchronously, caller handles UI reveal.
    return Promise.resolve(params.doWork()).then(r => {
      if (params.applySuccess) params.applySuccess(r);
      return r;
    }).catch(err => {
      if (params.onErrorSnack) snack(params.onErrorSnack(err), 'error');
      throw err;
    });
  }
  // Flag-on: apply immediately, work in background, rollback on failure.
  try { params.apply && params.apply(); } catch {}
  return Promise.resolve(params.doWork()).then(r => {
    try { params.applySuccess && params.applySuccess(r); } catch {}
    return r;
  }).catch(err => {
    try { params.revert && params.revert(); } catch {}
    const msg = params.onErrorSnack ? params.onErrorSnack(err) : 'Action failed';
    snack(msg, 'error');
    throw err;
  });
}
// --- end v8.1 ux ---
```

Contract:
- `apply()` -- immediate UI update (flag-on only).
- `doWork()` -- returns Promise doing the network call.
- `applySuccess(result)` -- fires after `doWork` resolves (both paths).
- `revert()` -- rolls back `apply()` on failure (flag-on only).
- `onErrorSnack(err)` -> string -- snack text on failure.

**Success condition:** grep for `function optimisticAction(` returns 1 hit. Helper is pure (no global state). `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 11 -- Optimistic UI: ban execute + draft save + watchlist toggle

File: `modtools.js`. Edit three existing flows.

### 1. Ban execute

In the Ban tab's Execute click handler:
```js
const chipRail = document.querySelector('.gam-status-chip-rail') || document.body;
const chip = document.createElement('span');
chip.className = 'gam-status-chip gam-pending';
chip.textContent = 'Banning @' + userName + '...';

optimisticAction({
  apply: () => {
    closeModConsole(); // close immediately
    chipRail.appendChild(chip);
  },
  doWork: () => fetchBanEndpoint({ user: userName, reason: reasonText, ... }),
  applySuccess: () => {
    chip.className = 'gam-status-chip gam-ok';
    chip.textContent = 'Banned @' + userName;
    setTimeout(() => chip.remove(), 3000);
  },
  revert: () => { chip.remove(); },
  onErrorSnack: (err) => 'Ban failed: ' + (err && err.message || 'unknown'),
});
```

### 2. Draft save

In the draft editor's Save click handler:
```js
const btn = saveButtonEl;
const originalLabel = btn.textContent;
optimisticAction({
  apply: () => {
    btn.disabled = true;
    btn.textContent = 'Saved (undo)';
  },
  doWork: () => saveDraftToWorker(draftBody),
  applySuccess: () => {
    setTimeout(() => { btn.disabled = false; btn.textContent = originalLabel; }, 4000);
  },
  revert: () => {
    btn.disabled = false;
    btn.textContent = originalLabel;
  },
  onErrorSnack: (err) => 'Save failed: ' + (err && err.message || 'retry'),
});
```

### 3. Watchlist toggle

In the watch-icon click handler:
```js
const currentlyWatched = iconEl.classList.contains('gam-watched');
optimisticAction({
  apply: () => {
    iconEl.classList.toggle('gam-watched');
  },
  doWork: () => (currentlyWatched ? removeFromWatch(uid) : addToWatch(uid)),
  revert: () => {
    iconEl.classList.toggle('gam-watched');
  },
  onErrorSnack: () => 'Watchlist update failed',
});
```

Each site gated on `__uxOn()` via `optimisticAction`'s flag-off branch (which executes synchronously, matching v8.0 behavior). No separate `if (__uxOn())` check needed at call sites -- the helper handles both paths.

**Success condition:** grep for `optimisticAction(` returns exactly 4 hits (1 helper + 3 call sites). `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 12 -- Touch-target CSS sweep

File: `modtools.js` (CSS block). Sub-block `// --- v8.1 ux: touch-targets ---`.

### Approach

All touch-target fixes are new CSS rules scoped under `body.gam-ux-polish-on`. Flag-off -> class absent -> zero match, v8.0 rules win.

### CSS

```css
/* v8.1 ux: touch-targets (scoped to .gam-ux-polish-on) */

/* Status-bar icon buttons: 22px visible, 11px pad each side -> 44x44 hit */
body.gam-ux-polish-on .gam-bar-icon {
  padding: 11px;
  background: transparent;
  border-radius: 4px;
  box-sizing: content-box; /* keep visible icon 22x22 */
}
body.gam-ux-polish-on .gam-bar-icon:hover { background: rgba(255,255,255,0.05); }

/* Status-bar container: compensate margins so overall width drift stays <= 2px */
body.gam-ux-polish-on .gam-statusbar { gap: 0; }
body.gam-ux-polish-on .gam-statusbar > * + * { margin-left: 0; }

/* Action strip buttons on post rows */
body.gam-ux-polish-on .gam-action-btn {
  min-height: 44px;
  min-width: 44px;
  padding: 10px 12px;
}

/* Modal close (x): 32px visible + 12px pad each side = 44px hit */
body.gam-ux-polish-on .gam-modal-close {
  width: 32px; height: 32px;
  padding: 6px;
  min-width: 44px; min-height: 44px;
  font-size: 20px;
}

/* Triage Console row delete: 32px visible + 12px pad */
body.gam-ux-polish-on .gam-row-delete {
  width: 32px; height: 32px;
  padding: 6px;
  min-width: 44px; min-height: 44px;
}
```

### Body class toggler

Add to the existing boot flow (inside `__syncUxBodyClass` from CHUNK 0):
```js
// already in CHUNK 0: document.body.classList.toggle('gam-ux-polish-on', __uxOn());
```
(confirmed single source of truth in CHUNK 0).

**Success condition:** grep for `body.gam-ux-polish-on .gam-bar-icon` returns 1 hit. Grep for `min-height: 44px` returns >= 3 hits. `node --check` exits 0. The verify script's hit-area calculation (width + L-pad + R-pad) reports >= 44 for every matched selector.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 13 -- verify-v8-1.ps1 + version bump

File: `D:\AI\_PROJECTS\verify-v8-1.ps1`. BOM + ASCII, 4-step ending, parse-check on both engines.

### Static checks

```
 1. manifest.json version === 8.1.0.
 2. gaw-mod-shared-flags/version.json === 8.1.0.
 3. modtools.js contains `// ===== v8.1 UX POLISH =====` (open sentinel) exactly once.
 4. modtools.js contains `// ===== END v8.1 =====` (close sentinel) exactly once.
 5. modtools.js contains `'features.uxPolish': false` exactly once in DEFAULT_SETTINGS.
 6. modtools.js contains `function __uxOn()` exactly once.
 7. modtools.js contains `function installFocusTrap(`.
 8. modtools.js contains `function renderSkeleton(`.
 9. modtools.js contains `function renderEmptyState(`.
10. modtools.js contains `function optimisticAction(`.
11. modtools.js contains `function linkLabel(`.
12. modtools.js contains `function __announce(`.
13. modtools.js contains `aria-live="polite"` exactly once.
14. modtools.js contains `aria-live="assertive"` exactly once.
15. modtools.js contains `@keyframes gam-skeleton-shimmer` exactly once.
16. modtools.js contains `@media (prefers-reduced-motion: no-preference)` wrapping the shimmer keyframes.
17. modtools.js contains `body.gam-ux-polish-on` at least once in the CSS block.
18. modtools.js contains 5 `v8.1 ux kbd-audit:` comment blocks (Tab-order docs).
19. node --check modtools.js exits 0.
```

### Sentinel-scoped banned-pattern greps (every hit inside sentinel region fails the ship)

```
20. `new MutationObserver\(` -- 0 hits inside sentinel region.
21. `setInterval\(` -- 0 hits inside sentinel region.
22. `new RegExp\(` -- 0 hits inside sentinel region.
23. `innerHTML\s*=\s*[^;]*\$\{` -- 0 hits inside sentinel region (template-literal into innerHTML).
24. `innerHTML\s*=` outside the single whitelisted `UX_SVG[icon]` assignment -- 0 hits inside sentinel region.
25. Call-site ungated grep: every `renderSkeleton(`, `renderEmptyState(`, `installFocusTrap(`, `optimisticAction(` call site either (a) has `__uxOn()` in the same function body within 30 lines above, OR (b) is the helper's own definition. Script fails if neither condition is met.
```

### Contrast-ratio audit (PowerShell inline)

```powershell
# WCAG 2.1 relative luminance + contrast ratio
function Get-Luminance([int]$r,[int]$g,[int]$b){
  $c = @($r,$g,$b) | ForEach-Object {
    $v = $_ / 255.0
    if ($v -le 0.03928) { $v / 12.92 } else { [Math]::Pow(($v + 0.055)/1.055, 2.4) }
  }
  return 0.2126*$c[0] + 0.7152*$c[1] + 0.0722*$c[2]
}
function Get-ContrastRatio($hex1,$hex2){
  $c1 = $hex1.TrimStart('#')
  $c2 = $hex2.TrimStart('#')
  $r1=[Convert]::ToInt32($c1.Substring(0,2),16); $g1=[Convert]::ToInt32($c1.Substring(2,2),16); $b1=[Convert]::ToInt32($c1.Substring(4,2),16)
  $r2=[Convert]::ToInt32($c2.Substring(0,2),16); $g2=[Convert]::ToInt32($c2.Substring(2,2),16); $b2=[Convert]::ToInt32($c2.Substring(4,2),16)
  $l1 = Get-Luminance $r1 $g1 $b1
  $l2 = Get-Luminance $r2 $g2 $b2
  $light = [Math]::Max($l1,$l2); $dark = [Math]::Min($l1,$l2)
  return ($light + 0.05) / ($dark + 0.05)
}
# Audit pairs (extract from modtools.js CSS block, pair them with their backgrounds)
$pairs = @(
  @{ fg='--gam-muted-text';    bg='--gam-bg-dark';   bgHex='#1a1a1e' },
  @{ fg='--gam-muted-text';    bg='--gam-bg-card';   bgHex='#1f1f24' },
  @{ fg='--gam-link';          bg='--gam-bg-card';   bgHex='#1f1f24' },
  @{ fg='--gam-warn-text';     bg='--gam-warn-bg';   bgHex='...' },
  @{ fg='--gam-ok-text';       bg='--gam-ok-bg';     bgHex='...' },
  @{ fg='--gam-danger-text';   bg='--gam-danger-bg'; bgHex='...' }
)
# For each pair: regex-extract the fg hex from modtools.js, compute ratio, require >= 4.5
```

Each pair below 4.5:1 prints a FAIL line and contributes to the script's exit code.

### Hit-area audit (PowerShell inline)

For every CSS rule inside the v8.1 region matching `.gam-*-icon` or `.gam-*-btn` or `.gam-modal-close` or `.gam-row-delete`:
- Parse `width`, `height`, `padding`, `min-width`, `min-height`.
- Compute effective hit area as `max(width, min-width) + 2*padding-x` (and same for height).
- Require >= 44 for both axes.

### Build gates

```
26. node --check modtools.js exits 0.
27. manifest.json parseable as JSON with version 8.1.0.
28. verify-v8-1.ps1 exits 0.
```

### Script skeleton (BOM + ASCII + 4-step ending)

```powershell
<#
.SYNOPSIS
  v8.1 UX Polish verification.
.DESCRIPTION
  Static checks + sentinel-scoped banned-pattern greps + contrast audit +
  hit-area audit. No network. No deploy.
#>
[CmdletBinding()]
param([switch]$NoPause)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 5) {
  Write-Host "Requires PS 5.1+." -ForegroundColor Red; exit 1
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$log = @()
function Say($t, $c='Cyan') { Write-Host $t -ForegroundColor $c; $script:log += $t }

$repo = $PSScriptRoot
$mt   = Join-Path $repo 'modtools-ext\modtools.js'
$mf   = Join-Path $repo 'modtools-ext\manifest.json'
$vf   = Join-Path $repo 'gaw-mod-shared-flags\version.json'

$failed = 0
function Gate($name, $cond) {
  if ($cond) { Say "PASS  $name" Green }
  else       { Say "FAIL  $name" Red; $script:failed++ }
}

# ... all 28 gates implemented as Gate calls ...

Say "--------------------------------" Cyan
Say "v8.1 VERIFY -- $(if ($failed -eq 0) { 'ALL PASS' } else { "$failed FAIL" })" $(if ($failed -eq 0) { 'Green' } else { 'Red' })
Say "--------------------------------" Cyan

# Mandatory 4-step ending
$logPath = "D:\AI\_PROJECTS\logs\verify-v8-1-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null
$log -join "`n" | Set-Content -Path $logPath -Encoding UTF8
$log -join "`n" | Set-Clipboard
Say "[log copied to clipboard]  ($logPath)" DarkGray
[Console]::Beep(659, 160); Start-Sleep -Milliseconds 100
[Console]::Beep(523, 160); Start-Sleep -Milliseconds 100
[Console]::Beep(784, 800)
if (-not $NoPause) { Read-Host 'Press Enter to exit' | Out-Null }
exit $(if ($failed -eq 0) { 0 } else { 2 })
```

Post-write: prepend UTF-8 BOM, strip non-ASCII (em-dash -> `--`, arrow -> `->`, etc.), parse-check with BOTH `powershell.exe` and `pwsh.exe` until `PARSE OK`. No PS 7-only syntax (no ternary -- note the `$(if () {} else {})` pattern above is PS 5.1-safe).

### Version bump

`D:\AI\_PROJECTS\modtools-ext\manifest.json`: bump `"version"` to `"8.1.0"`.
`D:\AI\_PROJECTS\gaw-mod-shared-flags\version.json`: bump to `"8.1.0"`.

**Success condition:** `pwsh -NoProfile -File verify-v8-1.ps1` exits 0 with all 28 gates PASS. Clipboard contains full log. ECG beep plays.
**If fails:** rewrite entire chunk from scratch.

---

## HARD RULES

1. `node --check D:\AI\_PROJECTS\modtools-ext\modtools.js` passes after every chunk. Not "after every area" -- after every chunk.
2. `features.uxPolish` defaults `false`. Flag-off state is v8.0 byte-for-byte parity on every observable code path except the one documented exception (contrast variable values; see BAKED-IN DECISION #3).
3. **No new worker endpoints.** **No D1 migrations.** **No wrangler deploy.** **No git push.** This is a pure client-side release.
4. XSS contract: every string rendered from a network response is wrapped by `el()` with `textContent` children. The only `innerHTML` usage in v8.1 is the one whitelisted assignment inside `renderEmptyState` for the static `UX_SVG[icon]` constant -- verified by gate #24.
5. No new `MutationObserver`, no new `setInterval`, no new recurring `setTimeout`. Existing `DomScheduler` (v8.0 CHUNK 0 primitive) and `MasterHeartbeat` handle any dynamic work. Verified by gates #20 and #21.
6. Every CSS animation respects `prefers-reduced-motion: reduce`. Verified by gate #16 and a manual audit.
7. Every new DOM element has semantic HTML (`<button>`, `<label>`, `<input>`, `<h1>`-`<h6>`) OR an appropriate ARIA role. The `renderEmptyState` card uses `role="status"`; live regions use `aria-live`. No `<div>`-as-button.
8. PowerShell verify script: BOM + ASCII sanitized + parse-clean on both `powershell.exe` (5.1) and `pwsh.exe` (7+) + 4-step ending (log to clipboard, persist to `D:\AI\_PROJECTS\logs\`, ECG beep, Read-Host pause unless `-NoPause`).
9. Feature-flag gating at every helper call site. The verify script's gate #25 enforces this programmatically.
10. No retrofit of v8.0 or v7.x code. v8.1 is strictly additive inside the sentinel region. Any touch to v8.0 code is a regression.

---

## VERIFICATION PROTOCOL (Commander runs these in order)

```
pwsh -NoProfile -File D:\AI\_PROJECTS\bump-version.ps1 -Version 8.1.0 -Notes "UX Polish: WCAG 2.2 AA pass (focus traps, aria-live, label-for, Tab-order, contrast), skeleton loading states, empty states with CTAs, optimistic UI for ban/draft/watch, 44x44 touch targets. All behind features.uxPolish (default OFF)."
pwsh -NoProfile -File D:\AI\_PROJECTS\build-chrome-store-zip.ps1
pwsh -NoProfile -File D:\AI\_PROJECTS\verify-v8-1.ps1
```

All three must exit 0. Commander handles any `wrangler deploy` separately -- this session does not deploy. (In practice, v8.1 has no worker changes, so no deploy is needed; the worker stays on v8.0.)

---

## ROLLOUT PROTOCOL (Commander owns this)

1. Ship v8.1 via GitHub auto-update. `features.uxPolish` defaults OFF -- every mod sees v8.0 behavior (except the global contrast bumps, which are non-regressive).
2. Commander enables `features.uxPolish` for himself only. Runs one shift. Checks:
   - Every modal traps focus correctly (Tab doesn't escape).
   - Ban/draft/watch actions feel instant.
   - Status-bar icons are comfortably clickable on touchscreen laptop.
   - No visual regressions in dark theme.
   - No console errors, no `node --check` failures.
3. If clean after 24h, roll per-mod (one mod at a time, one day apart). Collect feedback on the empty-state copy specifically -- that's the subjective piece.
4. After two weeks clean with all 5 mods running flag-on, v8.2 removes the flag (feature becomes default-on, fallback branches deleted).
5. At any point, flipping `features.uxPolish=false` in Settings restores v8.0 behavior instantly for that user (except contrast variables, which are global and non-regressive).

---

## IF A CHUNK FAILS 3x, ESCALATE TO COMMANDER

Stop implementation. Produce one message:
1. Chunk number and name.
2. Three unified diffs (git-diff format) of the attempts and how each failed.
3. The specific acceptance-criterion line that did not pass (including which verify gate triggered, if any).
4. One-sentence hypothesis of root cause.
5. Two proposed alternatives with tradeoffs.

Do not attempt a 4th autonomous rewrite.

---

## OUT OF SCOPE (v8.2+, each its own GIGA)

- Arrow-key navigation through modal sections and queue rows (beyond the existing Escape delegate).
- Per-sub-area flag split (separate `features.a11y`, `features.skeleton`, `features.emptyStates`, `features.optimistic`, `features.touchTargets`). v8.1 uses a single flag by design; multi-flag matrix is a v8.2 task only if a user-reported issue scopes to one area.
- `optimisticAction` applied to queue filter changes, rule reorder, modmail archive, or any flow beyond the three documented in CHUNK 11.
- Full keyboard-navigation rewrite of the Triage Console and IntelDrawer (v8.1 only adds documentation + minimal tabindex; full rewrite is a v8.3 task).
- Animation polish beyond skeleton shimmer (route transitions, modal slide-in, chip pop-in) -- v8.2.
- Light theme support (v8.1's contrast audit targets dark theme only; light theme is an entirely separate pass).
- High-contrast mode support (separate CSS variable set triggered by `@media (forced-colors: active)`).
- Screen reader walkthrough testing with NVDA / VoiceOver beyond the aria-live and label-for coverage (v8.2 QA task).
- Reduced-motion fallback for the optimistic UI status chip (currently a CSS transition; v8.2 may add `@media (prefers-reduced-motion: reduce)` wrap).
- Removal of flag fallback branches for uxPolish (v8.3 task after two weeks clean in production).
- Retrofit of v8.0 snack sites to directly route to aria-live (v8.1 wires via `snack()` only; direct-route retrofit is deferred to v8.2 as a minor optimization).
- `renderSkeleton` variants beyond the five documented (`text-line`, `paragraph`, `row`, `card`, `avatar`). New variants added on demand in their own mini-GIGA.
- Empty-state telemetry (click-through on CTAs to see if the empty-state CTAs actually help users recover). v8.2.
- A11y audit of the Mod Settings panel, the Help modal, and the About dialog -- v8.1 covers the active moderation modals only.
