# GAW ModTools - Chrome Web Store Submission v8.1.4

> **Status:** READY TO SUBMIT. One prerequisite remaining: publish the privacy policy at a public URL (see Section 6). Everything else is paste-and-go.
>
> **Package:** `D:\AI\_PROJECTS\dist\gaw-modtools-chrome-store-v8.1.4.zip`
> **Size:** 221,926 bytes (216.7 KB)
> **SHA-256:** `999059763dbd0df6874d230fc1058ff293e2c6259f2ec719b5d13cb4968eac83`
> **Contents verified:** manifest.json, modtools.js, popup.js, popup.html, popup.css, background.js, icons/{16,48,128}.png (9 files)

---

## 1. Listing metadata (paste into CWS form fields)

### Extension name (45 char max)
```
GAW ModTools
```
(12 chars. Keep it short and brandable.)

### Summary (132 char max)
```
Moderator console for greatawakening.win: unified actions, shared flags, audit trail, Death Row queue, and team collaboration.
```
(131 chars. Under the limit. Names the site explicitly so Google reviewers know the single audience.)

### Detailed description (16,000 char max)

Paste exactly what's between the two `---` markers below:

---
GAW ModTools is a professional moderation console built for the volunteer moderator team at greatawakening.win. It replaces the site's native per-action dialogs with a unified Mod Console that surfaces user context, audit history, and the most common actions - ban, remove, warn, flair, lock, message - in a single view, so decisions can be made quickly and consistently.

**Team coordination, built in.** ModTools keeps the mod team in sync. A shared audit log records every moderator action with timestamp, target, reason, and actor identity - verified server-side, not read from the page. Team-shared flags let any mod tag a user for follow-up and have every teammate see the tag immediately. The Shadow Queue surfaces AI-triaged suggestions on queue items so obvious cases get a one-glance badge and moderators can focus their judgment where it counts. Nothing the AI suggests is ever applied automatically - every action still requires two explicit keystrokes from a human moderator.

**Park and escalate without losing context.** The Park button lets any moderator hand off an unclear case to a senior mod with a note. The original moderator receives a Discord notification when it's resolved, and the team never loses track of a pending decision. Proposals let moderators suggest a ban, removal, or lock that a second mod confirms before it takes effect - the audit trail records both the proposer and the confirmer.

**Precedent-citing ban messages.** When banning a user, ModTools can auto-cite relevant prior moderation outcomes (by rule reference and aggregate count only - never by user identifier), making team decisions defensible and consistent. Precedents are maintained by the lead moderator and cross-referenced into the ban message automatically.

**AI assistance, kept server-side.** ModTools integrates with Claude (Anthropic), Grok (xAI), and Llama 3 (via Cloudflare Workers AI) through a private Cloudflare Worker. API keys never touch the browser. Every AI response rendered to a moderator carries a "Why this?" affordance revealing the model, prompt version, and generation timestamp. Moderators can select which engine they prefer per action.

**Death Row queue.** A delayed-ban queue lets moderators schedule bans with a configurable delay (72h, 96h, one week). Bans are idempotent server-side, so they cannot fire twice even under rapid tab switches or double-clicks.

**Security-minded.** Moderation state does not mirror to the page's localStorage - a compromised site script cannot read it. Worker authentication tokens live only in the extension's background service worker, isolated from page context. Destructive actions are server-verified, and every audit entry attributes actions to the moderator's server-side identity, not to a DOM-scraped username.

GAW ModTools is a private team tool for moderators of greatawakening.win. It does not operate on any other website, does not track moderator browsing activity, and does not transmit data to third parties beyond the two services required to run it (the team's private Cloudflare Worker and, when a moderator selects an AI engine, that engine's API routed through the worker). Full details: see the privacy policy linked below.

Support and bug reports: catsfive@yahoo.com

Source and release notes are maintained in the internal mod-tools repository. Current version: v8.1.4.
---

(Character count: approximately 3,100 - well under the 16,000 limit.)

### Category
```
Productivity
```
Rationale: This is a workflow tool for a specific professional role (volunteer content moderators). It's not "Social & Communication" (not user-to-user), not "Developer Tools" (moderators are not developers). Productivity is the honest fit.

### Language
```
English
```

### Store icon (128 x 128 PNG)
Path: `D:\AI\_PROJECTS\modtools-ext\icons\icon128.png`
**VERIFIED present** (864 bytes). Chrome Web Store will upload this automatically from the ZIP. No separate upload needed.

---

## 2. Single purpose description (required CWS field)

Paste exactly:
```
GAW ModTools helps volunteer moderators of greatawakening.win coordinate moderation actions, track a shared audit trail, and collaborate with teammates in real time.
```
(163 chars. Under the 180 limit. Single sentence. Single audience. Single clear purpose.)

---

## 3. Permission justifications

**Every permission in `manifest.json` is justified below.** Copy each block into the corresponding CWS justification field. Reviewers compare the declared permission against your justification - keep it specific.

### Permissions (from `manifest.permissions`)

#### `storage`
**Why we need it:** ModTools persists moderator-specific settings and a per-moderator authentication token on the moderator's own machine. This includes feature toggles, pattern lists for auto-detection of abusive usernames, the local cache of recently-viewed profile intel, and the worker token used to authenticate with our private backend.
**What we access:** `chrome.storage.local` and `chrome.storage.session` only. Keys are scoped to this extension and never shared with the host page.
**User visibility:** Moderators configure these settings through the extension's popup panel. Removing the extension clears all stored data.

#### `tabs`
**Why we need it:** When a moderator initiates an action from the extension popup (e.g., "open the current user's profile," "jump to the moderation queue"), ModTools needs to locate or create a tab on greatawakening.win. It also reads the current tab's URL to know which moderation context the popup should surface.
**What we access:** Tab URLs and IDs. We do not read tab content through this permission - content access is scoped strictly to greatawakening.win via `content_scripts` (see host permissions below).
**User visibility:** Tab navigation is initiated by the moderator from the popup. No background tab reads.

#### `alarms`
**Why we need it:** The background service worker uses a periodic alarm to (a) keep the extension's auto-update check alive, and (b) refresh the in-memory token vault so tokens survive service-worker suspension. Alarms are the Manifest V3 replacement for `setInterval` in background contexts.
**What we access:** A single named alarm owned by this extension.
**User visibility:** None. This is a background maintenance task with no UI surface.

### Host permissions (from `manifest.host_permissions`)

#### `*://greatawakening.win/*`  and  `*://*.greatawakening.win/*`
**Why we need it:** The extension's only purpose is moderating greatawakening.win. The content script runs on pages of this domain (and its subdomains) so moderators can read the page's rendered moderation context - usernames, post titles, comment bodies, modmail threads - and submit moderator actions against the site's existing endpoints using the moderator's own session.
**What we access:** The DOM and CSRF token of greatawakening.win pages the moderator is already viewing. No data from any other website.
**User visibility:** The extension overlays its Mod Console on the native page. All visible surfaces are initiated by the moderator.

#### `https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/*`
**Why we need it:** This is the extension's dedicated backend - a private Cloudflare Worker owned by the extension maintainer. The extension sends authenticated moderator actions, shared-flag reads/writes, audit log entries, and AI-recommendation requests here. It is the only remote host the extension talks to other than greatawakening.win itself.
**What we access:** Our own worker's endpoints, authenticated per-moderator.
**User visibility:** The moderator's worker token is configured through the popup's onboarding modal on first install.

### Content script matches (from `manifest.content_scripts`)

The content script at `modtools.js` runs only on `*://greatawakening.win/*` and `*://*.greatawakening.win/*`, at `document_end`, in the top frame only (`all_frames: false`). This is the same scope as the host permission above. It is required to overlay the Mod Console onto the native pages moderators already use.

---

## 4. Remote code / Remote resources

**Answer: NO, the extension does not execute remotely-fetched code.**

Paste this into the CWS "Remote code" justification field:
```
The extension is a fully static bundle. All executable code (modtools.js, popup.js, background.js) ships inside the uploaded ZIP. The extension communicates with its own private Cloudflare Worker via fetch() for data (JSON), but does not eval, import, or inject any remote script. The Content Security Policy declared in manifest.json restricts script execution to 'self' only.
```

The relevant manifest clause is already locked down:
```json
"content_security_policy": {
  "extension_pages": "script-src 'self'; object-src 'self'; base-uri 'self';"
}
```

---

## 5. Data usage disclosure

The CWS data-usage page asks you to check each category. Answers below match what `PRIVACY.md` already states - do not deviate.

| Category | Answer | Notes |
|---|---|---|
| Personally identifiable information | **No** | Usernames are public site data; no real names, emails, phone numbers, or addresses are collected. |
| Health information | **No** | None. |
| Financial and payment information | **No** | None. |
| Authentication information | **Yes** | Per-moderator worker token stored in `chrome.storage.local` / `chrome.storage.session` so the moderator can authenticate with the private Cloudflare Worker. The token is never transmitted to any party other than the worker itself. |
| Personal communications | **No** | The extension reads modmail threads the moderator already has permission to see; it does not collect or transmit those threads outside the mod team. |
| Location | **No** | None. |
| Web history | **No** | The extension does not track moderator browsing. Its content script runs only on greatawakening.win. |
| User activity | **Yes** | The moderator's own moderation actions (bans, removes, flair changes, notes) are logged to the team's shared audit log so the team can coordinate and review. This is the moderator's work product, not surveillance of third parties. |
| Website content | **Yes** | The content script reads the greatawakening.win pages the moderator views so it can surface context for moderation decisions. No content from any other site is read. |

### Three required certifications (check all three)

- **[CHECK]** I do not sell or transfer user data to third parties, apart from the approved use cases.
- **[CHECK]** I do not use or transfer user data for purposes unrelated to my item's single purpose.
- **[CHECK]** I do not use or transfer user data to determine creditworthiness or for lending purposes.

All three are accurate. The privacy policy corroborates them.

---

## 6. Privacy policy URL

**Current status:** The privacy policy lives at `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md`. It is comprehensive and up-to-date for v8.1.4 (covers v7.0, v7.1, v7.2, v8.0 data categories). It is **NOT** currently published at a public URL. Chrome Web Store REQUIRES a public URL.

**Recommended action (fastest path to submit tonight):** Serve it from the existing Cloudflare Worker at `https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/privacy`. The worker is already authorized in the manifest, already deployed, and already has the infrastructure.

### Worker code snippet

Add this route near the top of the `fetch` handler in `gaw-mod-proxy-v2.js` (before the `checkModToken` gates). It serves the markdown as sanitized HTML and requires no secrets:

```javascript
// Public privacy policy -- no auth required.
if (url.pathname === '/privacy' && request.method === 'GET') {
  const md = PRIVACY_MD_INLINE; // see below - paste the PRIVACY.md contents into this constant
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>GAW ModTools - Privacy Policy</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font: 16px/1.55 -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
         max-width: 740px; margin: 2em auto; padding: 0 1em; color: #1a1a1a; }
  h1, h2, h3 { line-height: 1.25; }
  h1 { border-bottom: 2px solid #2a2f38; padding-bottom: .35em; }
  h2 { border-bottom: 1px solid #e0e0e0; padding-bottom: .2em; margin-top: 2em; }
  code { background: #f3f4f6; padding: .15em .35em; border-radius: 3px; font-size: 0.92em; }
  a { color: #2563eb; }
</style>
</head>
<body>
<pre style="white-space: pre-wrap; font: inherit;">${md
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')}</pre>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=300',
      'x-content-type-options': 'nosniff',
    },
  });
}
```

Then, near the top of the worker file (with the other constants), add:

```javascript
// Keep in sync with D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md on every update.
const PRIVACY_MD_INLINE = `# GAW ModTools -- Privacy Policy
// ... full contents of PRIVACY.md pasted here as a template literal ...
`;
```

**Why inline rather than fetching from GitHub:** Fetching at request time adds latency and a second point of failure. The privacy policy changes rarely (once per version bump); inlining it keeps the worker self-contained and guaranteed-available.

### Privacy policy URL to paste into CWS form

```
https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/privacy
```

**Verification step Commander should run before hitting Submit:**
```
Open in browser: https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/privacy
Confirm: page loads, shows the policy, status 200.
```

### Alternative if the worker update is blocked

If for any reason the worker cannot be updated tonight, the second-fastest option is GitHub Pages on `catsfive1/gaw-mod-shared-flags`:
1. Copy `PRIVACY.md` to the repo root (or `docs/PRIVACY.md`).
2. In repo Settings > Pages: enable, source = main branch, path = `/` or `/docs`.
3. Privacy URL becomes: `https://catsfive1.github.io/gaw-mod-shared-flags/PRIVACY`
Takes ~2 minutes to propagate. Worker route is still preferred.

---

## 7. Screenshots - what Commander needs to capture

CWS requires at least 1 screenshot. **Submit 5 for a professional listing.** Each must be 1280x800 **or** 640x400 PNG/JPEG. Use 1280x800 - it looks sharper on the listing page.

Window-size tip: in Chrome DevTools, toggle Device Toolbar (Ctrl+Shift+M) and set custom dimensions 1280x800. Capture with the browser's built-in screenshot tool (three-dot menu in DevTools device toolbar > "Capture screenshot").

| # | Capture | Where to take it | Why it represents the product |
|---|---|---|---|
| 1 | **Intel Drawer open on a user profile** | `/u/<any-flagged-user>` - click the user's name, open the Drawer. Make sure audit history, precedent count, and the shared-flag badge are visible. | Headline feature. Shows "everything a moderator needs about a user in one place." |
| 2 | **Parked list with 2-3 items** | Popup > Parked tab (or the drawer's "Parked" section). Have at least two items with distinct notes and one with a "resolved" badge. | Shows team handoff. Demonstrates collaboration, not just a one-person tool. |
| 3 | **Shadow Queue badge on a queue row** | `/mod/queue` page with `features.teamBoost` enabled. Find a queue row that has a Shadow badge (APPROVE / REMOVE / WATCH). Hover the "Why this?" tooltip so the model and prompt version are visible. | Shows AI assistance with transparency - the "Why this?" stamp is the defensibility story. |
| 4 | **Proposal / vote embed in Discord** | Discord channel where proposals are posted. Screenshot the embed showing proposer, target, action, reason, and the "confirm" / "reject" reactions. | Proves the team-coordination loop works beyond the extension itself. |
| 5 | **Token onboarding modal** | Fresh install, first popup open. Modal should be in its clean empty state, prompting "Paste your worker token." | Reassures reviewers that users are explicitly onboarded, not surprise-enrolled. Also a clean UI shot. |

**Promo tile (440x280, optional but recommended):** Single-panel image with the ModTools logo, the tagline "Moderator console for greatawakening.win", and a subtle background color matching the extension's dark theme (#0f1114). No screenshots inside. Keeps the listing card visually clean.

**Important:** Do NOT include any real moderator's username, real user PII, or real ban reasons in the screenshots. Either use test accounts or blur/redact the visible text. Google reviewers will not reject for blur, but will reject for leaking a real user's identifiable info in a public listing image.

---

## 8. Submission walkthrough (do these in order)

1. Open: `https://chrome.google.com/webstore/devconsole/`
2. Sign in with the Google account that will own the listing (Commander's primary).
3. **First time only:** Pay the $5 one-time developer registration fee. Google will prompt.
4. Click **New Item**.
5. Upload the ZIP: `D:\AI\_PROJECTS\dist\gaw-modtools-chrome-store-v8.1.4.zip` (221,926 bytes, SHA-256 `999059763dbd0df6874d230fc1058ff293e2c6259f2ec719b5d13cb4968eac83`).
6. Wait for the upload to parse. Manifest version, name, description, and icons populate automatically.
7. **Store listing** tab: paste the Name, Summary, Detailed description, Category, and Language from Section 1. Upload the 5 screenshots from Section 7.
8. **Privacy practices** tab:
   a. Single-purpose description: paste from Section 2.
   b. Permission justifications: paste from Section 3, one per permission.
   c. Remote code disclosure: paste from Section 4.
   d. Data usage disclosures: check boxes per Section 5. Check all three required certifications.
   e. Privacy policy URL: paste from Section 6 (after confirming the URL is live).
9. **Distribution** tab: set Visibility to **Public** (or **Unlisted** if Commander prefers the install link stays shareable-only). Leave geographic distribution default (all regions).
10. Click **Save draft** in the top-right.
11. Click **Preview** to see the listing as reviewers will. Fix any red warnings.
12. Click **Submit for review**.
13. Confirmation email arrives within a few minutes. Status in the dashboard changes to "Pending review."
14. First-time review: ~3 business days. Google may email with questions - respond promptly from the Developer Dashboard messaging panel.
15. Once approved: the extension publishes to the public store at `https://chromewebstore.google.com/detail/<item-id>`. Commander sends that URL to the 14 mods; they click "Add to Chrome," then paste their per-moderator token into the onboarding modal on first popup.

**For future version updates:** Build the new ZIP, click "Package" in the Dashboard, upload, re-submit. Subsequent reviews are usually hours, not days.

---

## 9. Common rejection causes and how we pre-avoided them

| Cause | How we handled it |
|---|---|
| **Overbroad host permissions** | Host permissions are scoped to two domains only (greatawakening.win and our own Cloudflare Worker). No wildcards like `<all_urls>` or `*://*/*`. |
| **Vague permission justifications** | Section 3 explains each permission in 2-3 sentences with concrete behavior, not marketing prose. |
| **Misleading description** | Description claims only what the extension actually does. No "advanced AI," no "revolutionary," no medical or legal framing. |
| **Missing privacy policy** | Privacy policy is comprehensive, version-matched to v8.1.4, and will be published at a public URL (Section 6) before submission. |
| **Single-purpose violation** | Single purpose statement names one audience (greatawakening.win moderators) and one task (moderation coordination). All features trace back to that purpose. |
| **Remote code execution** | Explicit CSP `script-src 'self'` in the manifest. No eval, no remote imports, no dynamic code loading. Stated clearly in Section 4. |
| **Manifest V2 leftovers** | Manifest is already V3. Uses `action` (not `browser_action`), `service_worker` (not `background.scripts`), `host_permissions` (not merged with `permissions`). |
| **Data-usage form contradicts privacy policy** | Section 5 answers match Section 6 privacy policy verbatim. Reviewers cross-check these - any mismatch = instant rejection. |
| **Screenshots showing real user PII** | Section 7 instructs Commander to use test accounts or redact. Do not skip this - a real banned username in the store listing is a moderator-conduct issue as well as a CWS rejection. |

---

## 10. Post-submission checklist

- [ ] Confirmation email received from Chrome Web Store.
- [ ] Developer Dashboard shows status: **Pending review**.
- [ ] If reviewer requests changes: edit the listing, resubmit. Minor edits usually do not reset the review timer.
- [ ] Upon approval: note the public install URL at `https://chromewebstore.google.com/detail/<item-id>`.
- [ ] Share the URL with the 14 mods over Discord.
- [ ] Monitor first-week install count and any 1-star reviews. Respond publicly to any legitimate bug report within 48 hours.
- [ ] For v8.1.5 and beyond: ship through the same Dashboard with the new ZIP; update PRIVACY.md and the worker-served `/privacy` route if data categories change.

---

## Appendix A: open items before Commander can hit Submit

1. **Publish the privacy policy.** Follow Section 6 - add the `/privacy` route to `gaw-mod-proxy-v2.js`, deploy via wrangler, verify the URL loads. Est. 5 minutes.
2. **Take 5 screenshots.** Follow Section 7. Use test accounts or redact PII. Est. 10-15 minutes.
3. **(Optional) Promo tile.** 440x280 image per Section 7. Est. 5 minutes if using a template.

Everything else in this document is copy-paste ready.

## Appendix B: files touched in preparing this submission

- Read: `D:\AI\_PROJECTS\modtools-ext\manifest.json` (permission inventory)
- Read: `D:\AI\_PROJECTS\modtools-ext\modtools.js` (capability audit)
- Read: `D:\AI\_PROJECTS\modtools-ext\background.js` (permission justification for `alarms` and `storage.session`)
- Read: `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md` (data-usage alignment)
- Read: `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` (remote-code disclosure, privacy-route design)
- Verified ZIP: `D:\AI\_PROJECTS\dist\gaw-modtools-chrome-store-v8.1.4.zip` (221,926 bytes, SHA-256 verified)
- Verified icon: `D:\AI\_PROJECTS\modtools-ext\icons\icon128.png` (864 bytes, present)
