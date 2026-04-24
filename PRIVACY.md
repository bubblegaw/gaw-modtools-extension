# GAW ModTools — Privacy Policy

**Effective:** 2026-04-22
**Publisher:** GAW ModTools (an internal tool for greatawakening.win moderators)
**Contact:** catsfive@yahoo.com

## TL;DR

GAW ModTools is a moderator utility. It is only useful to logged-in moderators of `greatawakening.win`. It does not collect data from regular site visitors. It sends **no** data to third parties other than the services strictly required to run it (a private Cloudflare Worker and, for certain AI features, xAI's chat completion API — routed server-side through the Cloudflare Worker, never from the browser).

## What the extension reads

When an authenticated moderator is browsing `greatawakening.win`, the extension reads:

- Public content rendered by the site: usernames, post titles, comment text, timestamps, flair, modmail threads already visible to that moderator.
- The moderator's own session CSRF token (read from the page's existing cookie / meta / hidden form input), so that moderation actions the mod initiates can be submitted on the same terms the native site uses.
- The moderator's local extension settings (toggles, pattern lists, display preferences), which live in `chrome.storage.local` on the moderator's own machine.

The extension does **not** read or transmit the content of any user who is not already a moderator with legitimate access to that content.

## What the extension sends, and where

The extension communicates with exactly one backend:

- **Cloudflare Worker** (`https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev`) — a private worker owned by the tool's maintainer. Mod actions, shared flags, modmail enrichment requests, and AI requests go here. All traffic is authenticated with a per-moderator token.

The worker may, on the moderator's behalf:

- Call **Cloudflare Workers AI** (Llama 3 family) for username scoring and ban-reply drafts. Data stays within Cloudflare.
- Call **xAI's chat completion API** (`api.x.ai`) for the same kinds of requests when the moderator has selected the Grok engine. The xAI API key lives only as a Cloudflare secret; it is never exposed to the browser.

The extension does not send analytics, does not phone home to any other host, and does not include any tracking SDKs.

## What is stored, and for how long

- **On the moderator's machine** (`chrome.storage.local`): the moderator's worker token, lead-mod token (if applicable), feature toggles, pattern lists, local cache of recently viewed profile intel. Removing the extension clears this.
- **On the Cloudflare Worker** (D1, KV, R2): team-shared flags, audit log of moderation actions, cached profile intel, modmail enrichment results, evidence snapshots captured at action time. Retention: audit log kept indefinitely; cached intel and modmail enrichment expire automatically; evidence snapshots kept for the duration of the moderation review and then purged.

Raw personal data — email addresses, phone numbers, payment details, government IDs — is **not** collected, processed, or stored. The extension has no access to such data because greatawakening.win does not expose it to moderators in the first place.

## What the extension does not do

- Does not access or transmit data from websites other than `greatawakening.win` and its subdomains.
- Does not track moderator browsing activity.
- Does not sell, share, or hand over data to advertisers, data brokers, or any third party beyond the two services listed above.
- Does not bypass authentication or access content a moderator is not already entitled to see.
- Does not inject scripts into the host page that modify its native network APIs.

## Rights and requests

Because the extension is used by a small team of moderators, any question, correction, or deletion request should be sent to the contact address above. Deletion of a moderator's audit-log entries on request is supported (the tool's maintainer can remove rows by moderator ID).

## v7.0 data categories

v7.0 introduces two new worker-side data classes:

- **Precedent entries.** Moderator-authored structured notes tagged to resolved cases (kind, signature, title, optional rule reference, action taken, optional reason, optional source permalink, authoring mod username, timestamp). Purpose: cross-mod consistency. Retention: same class as the audit log (indefinite). Deletable by a lead mod via `/precedent/delete` on request or when a mod leaves the team.

- **AI context payloads.** When a moderator clicks "Generate recommendation" in the Intel Drawer, the worker sends the subject kind (User/Thread/Post/QueueItem), subject id, and a minimal context object (username, recent audit events, or post title + excerpt) to xAI's Grok model via the worker proxy. The xAI API key never leaves the Cloudflare secret store. No PII beyond what a moderator already sees in the extension is transmitted. Responses are not stored.

The Intel Drawer itself reads and writes only from existing data classes (profiles, audit log, modmail threads); opening a drawer does not create new records beyond the optional precedent mark.

## v7.1 data categories

v7.1 introduces four new transient data classes, all stored in the existing audit D1 or Cloudflare KV:

- **Proposals.** When a moderator clicks Propose Ban / Propose Remove / Propose Lock, a structured record is written to D1 `proposals` (kind, target, duration, reason, proposer, proposer_note, ai_note). Retained 30 days; auto-expired 4 hours after creation if no second mod acts. AI advisory notes use the existing `/ai/next-best-action` KV-budgeted path — no new model traffic.

- **Drafts.** Textarea contents are synced to D1 `drafts` with a 2-second debounce so a second moderator can pick up an unfinished reply. Retention: 24 hours from last edit. Deleted on successful send.

- **Presence (viewing).** When a moderator opens the Intel Drawer for any subject, a 10-minute TTL record lands in Cloudflare KV (`presence:viewing:<kind>:<id>`) naming the viewing mod. Used to warn a second mod before a destructive action. Never exposed outside the mod team.

- **Claims.** When a moderator opens a modmail thread, a 10-minute TTL record in D1 `claims` marks that thread as being handled. Other moderators see a "Mod X on this" badge so two people don't reply simultaneously. TTL refreshes on every interaction; expired claims are purged hourly.

None of the above contain user PII beyond what is already present in the moderator's normal working surface (usernames, post/thread ids, reason text the mod typed).

## v7.2 platform hardening — data movement

v7.2 introduces a set of changes to where moderation data lives and how it moves between the browser page, the extension, and the worker. These changes are **gated behind a feature flag** (`features.platformHardening`) which is **default OFF**. Moderators opt in via the extension settings panel. When the flag is off, the extension behaves exactly as v7.1.2 and none of the changes below apply.

When the flag is on:

- **Moderation state no longer mirrors to page localStorage.** The audit log, roster, Death Row queue, watchlist, user notes, and cached profile intel previously lived in two places at once: the extension's private storage AND the browser page's shared localStorage for `greatawakening.win`. v7.2 removes the page mirror. As a result, a compromised site script — or any other browser extension that can read the page's localStorage for that site — can no longer reach this moderation state. The data remains available to the extension itself through its own private storage.

- **Worker authentication tokens moved to the extension's background service worker.** Previously, the per-moderator token used to authenticate with the Cloudflare Worker lived in the content script, the part of the extension that runs inside the `greatawakening.win` page. A compromise of that page could in principle reach the token. v7.2 keeps tokens in a segregated service-worker RAM cache and in `chrome.storage.session`, both of which are isolated from the page context. The content script requests actions through the service worker and never handles the tokens directly.

- **Actor identity now verified server-side.** Before v7.2, when the extension performed a moderator action, it told the server which moderator was taking the action by reading the username from the page's DOM. That channel is removed. In v7.2 the server identifies the moderator from the verified authentication token alone. Audit trails and cross-moderator state (who banned whom, who claimed which modmail thread, who wrote which note) are therefore resistant to page spoofing: a malicious page can no longer cause an action to be attributed to a different moderator.

- **Destructive actions are now idempotent.** Death Row bans cannot fire twice for the same user, even under rapid tab visibility changes, poll overlaps, or double-clicks. A server-side uniqueness constraint enforces this at the database level, so a retry of the same action is recognized as a duplicate rather than applied a second time.

- **Invite claim no longer occurs from a URL alone.** Previously, visiting a URL containing `?mt_invite=<code>` would attempt to claim the invite automatically. v7.2 requires an explicit click on a "Claim invite" button in the extension popup after the moderator has reviewed the code. This closes a class of situations in which a malicious or mistakenly shared link could have caused an unintended claim.

- **Error messages to moderators no longer surface raw backend diagnostics.** If the server fails, moderators see a normalized, human-readable message such as "permission denied" or "rate limited". Stack traces and internal details are no longer shown in the moderator-facing UI; they appear only in the browser console for debugging purposes.

- **Page URL telemetry (bug reports) now strips URL fragments.** When the extension includes a page URL in a bug report, it previously stripped query parameters whose names looked like tokens. v7.2 additionally strips the `#fragment` portion of URLs in telemetry payloads. This closes a vector where an OAuth-style access token carried in a URL fragment could have been included in a bug report.

Together these changes reduce the trust placed in the host page: the extension treats `greatawakening.win` more like an untrusted surface, keeps its sensitive state and credentials outside of reach of page scripts, and relies on the server rather than the page to establish who is doing what. Moderators who have not opted in to the flag are not affected.

## v8.0 team productivity -- data categories

v8.0 introduces three new worker-side data classes, all gated behind the `features.teamBoost` flag (default OFF). When the flag is off, none of the data below is ever created or read. All classes live in the existing audit D1.

- **Shadow triage decisions.** Ephemeral AI-generated triage advisories for queue items, posts, and comments. Each row holds the subject kind, subject id, a pre-decided action (`APPROVE` | `REMOVE` | `WATCH` | `DO_NOTHING`), a confidence score, a short reason, a structured evidence payload the AI cited, the model + prompt version, and a created-at timestamp. Retention: 7 days from creation, purged daily by the existing audit cron. Purpose: let the UI badge obvious cases so moderators can focus on hard ones. Two human keystrokes are still required to commit an action -- the AI never finalizes a ban, remove, or watchlist write on its own. Never contains user PII beyond what the AI saw in the subject body.

- **Parked items.** Structured records of moderator-to-senior handoffs. Each row holds `kind`, `subject_id`, `note`, `parker` (original mod's username), `status` (`open` | `resolved`), `resolved_by`, `resolved_at`, `resolution_action`, and `resolution_reason`. Retention: while open; 30 days after resolution, then purged. Purpose: let any moderator escape-hatch an unclear case to a senior mod without losing context. When a senior resolves the item, the original parker receives a Discord direct message notifying them of the outcome.

- **AI suspect queue.** Replaces the pre-v8.0 behavior where the daily AI username scanner wrote directly to the watchlist. Now, any user the AI flags with `risk >= 70` lands in `ai_suspect_queue` with the AI risk score, the reason string, source label, model, and prompt version. A human moderator must explicitly review each suspect and choose a disposition (`watched` | `cleared` | `banned` | `ignored`). The AI never writes to the watchlist or actions table directly. Retention: persists until a moderator disposes of the row; disposed rows are kept for audit-log parity (indefinite, same class as the audit log).

Precedent-citing ban messages (a v8.0 feature) use the v7.0 `precedents` table unchanged; no new data class is introduced. Citations are rendered by `rule_ref` and aggregate outcome count only -- never by user identifier. The client-side guard refuses to render a precedent that contains an authored_by, source_ref, user_id, or username field, and the worker's precedent-count SQL returns aggregates only.

Every AI response rendered to a moderator (Shadow Queue badge, ban-draft header, Intel Drawer recommendation) carries a "Why this?" affordance that reveals the model, provider, prompt version, rules version, and generation timestamp. No AI verdict is shown without this provenance stamp.

## Changes

This policy is versioned with the extension. Material changes will ship alongside a version bump and a release note. The current source of truth is the file at this URL.
