# GAW ModTools — Incident Runbook

When something breaks at 2 AM, this is what to do. Each scenario has a one-line diagnosis, the immediate mitigation, and the postmortem step.

---

## 0. Triage tree

```
Is the worker reachable? curl https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/health
  → 200          : worker is alive; check D1 / specific endpoint
  → connection  : Cloudflare-side outage; check status.cloudflare.com
                   → if CF outage: nothing to do but wait, post status update
                   → if not CF:    check `wrangler tail` for errors
  → 5xx         : worker code panic; check `wrangler tail` immediately
```

```
Is D1 reachable?  npx wrangler d1 execute gaw-audit --remote --command="SELECT 1"
  → success     : D1 OK
  → fail        : Cloudflare D1 incident or quota exhaustion (check CF dashboard → D1 → metrics)
```

```
Is the extension working in browser?
  → Chrome console (F12) on greatawakening.win
  → look for [modtools] / [worker] errors
  → check storage:  chrome.storage.local.get('gam_settings').then(console.log)
```

---

## 1. D1 unreachable

**Diagnosis:** All write endpoints return 503 with `D1 not bound` or `database unavailable`. `wrangler d1 execute --remote` hangs or errors.

**Immediate mitigation:**
1. Check `https://www.cloudflarestatus.com/` for D1 incident → if listed, wait it out
2. If it's our quota: visit CF dashboard → Workers → D1 → `gaw-audit` → check usage. D1 free tier: 5M rows read/day, 100k written/day
3. Mods can still browse; only writes (bans, drafts, parks) will silently fail. Tell mods: "back-end paused, your actions are queued locally; do not retry."
4. The extension will queue actions in `chrome.storage.local` until the worker recovers (`gam_deathrow`, `gam_mod_log` are local-first)

**Postmortem:**
- Pull `wrangler tail` logs for the duration
- If quota: increase plan (Workers Paid is $5/mo + usage-based) or add caching
- If outage: nothing to fix on our side

---

## 2. Lead token (`LEAD_MOD_TOKEN`) compromised or leaked

**Diagnosis:** Lead-only endpoints (`/admin/import-tokens-from-kv`, `/profiles/write` at scale, `/bot/mods/*`, `/bot/register-commands`) called by someone who shouldn't have access. Audit log shows actions from an unfamiliar IP / pattern.

**Immediate mitigation:**
1. Generate new token: `python -c "import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('='))"`
2. Update CF Worker secret: `cd D:\AI\_PROJECTS\modtools-ext\worker && echo NEWTOKEN | npx wrangler secret put LEAD_MOD_TOKEN`
3. Update D1 row: `wrangler d1 execute gaw-audit --remote --command="UPDATE mod_tokens SET token='NEWTOKEN' WHERE mod_username='catsfive' AND is_lead=1"`
4. Update local storage on Commander's desktop: paste in service worker console:
   ```js
   chrome.storage.local.get('gam_settings').then(r => { const s=r.gam_settings||{}; s.workerModToken='NEWTOKEN'; s.leadModToken='NEWTOKEN'; chrome.storage.local.set({gam_settings:s}); });
   ```
5. Wait 30 seconds for CF edge propagation, verify with `curl -H 'x-mod-token: NEWTOKEN' https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/mod/whoami` → expect `{"username":"catsfive","is_lead":true}`

**Postmortem:**
- Audit recent admin endpoint hits in CF logs
- Rotate any other secret that may have leaked alongside it (`MOD_TOKEN`, `XAI_API_KEY`)
- File a postmortem in `/docs/postmortems/YYYY-MM-DD-lead-rotation.md`

---

## 3. AI provider down (xAI / Anthropic / Workers AI)

**Diagnosis:** `/ai/ban-suggest`, `/ai/grok-chat`, `/gm chat` all return 502 or `provider error`. v8.3 has fallback chain, so multi-provider failure is required for total outage.

**Immediate mitigation:**
1. Check provider statuses: `https://status.anthropic.com/` and `https://status.x.ai/`
2. The v8.3 circuit breaker auto-opens after 5 failures in 60s; wait 30s for retry
3. If a provider is genuinely down: AI features degrade silently, mods will see "AI temporarily unavailable" in the UI. Manual moderation continues to work.
4. If you want to force-prefer a specific working provider: temporarily set `env.AI_DEFAULT_PROVIDER=workers-ai` (Llama via CF, free, always up if CF is up)

**Postmortem:**
- Confirm fallback chain ran (`fallback_count > 0` in logged AI responses)
- If multi-provider outage: consider adding a 4th provider tier (e.g. open-router as escape hatch)

---

## 4. Mass-ban rollback (Death Row fires on wrong cohort)

**Diagnosis:** A bad auto-DR rule pattern matched legit users. Audit log shows N bans with `source: death-row` and `reason: 'manual rule: <bad_pattern>'`.

**Immediate mitigation:**
1. **STOP the bleeding first.** Disable the rule immediately on Commander's desktop:
   ```js
   // service worker console:
   chrome.storage.local.get('gam_settings').then(r => { const s=r.gam_settings||{}; s.autoDeathRowRules=(s.autoDeathRowRules||[]).map(rule => ({...rule, enabled: rule.pattern==='BAD_PATTERN_HERE' ? false : rule.enabled})); chrome.storage.local.set({gam_settings:s}); });
   ```
2. Force-push to cloud so other mods stop firing it:
   ```js
   // service worker console:
   (async () => { const s = (await chrome.storage.local.get('gam_settings')).gam_settings || {}; const r = await fetch('https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/profiles/write', { method:'POST', headers:{'Content-Type':'application/json','x-mod-token': s.workerModToken}, body: JSON.stringify({username:'__gaw_team_patterns__', profile:{autoDeathRowRules: s.autoDeathRowRules, autoTardRules: s.autoTardRules || [], updatedBy:'incident-rollback', updatedAt: new Date().toISOString()}})}); console.log('rule sync:', r.status); })();
   ```
3. Find affected users:
   ```sql
   SELECT target_user, ts, reason FROM actions
   WHERE action='ban' AND source='death-row' AND reason LIKE '%manual rule: BAD_PATTERN%'
     AND ts > '<timestamp_when_rule_added>'
   ```
4. Unban via GAW's mod tools (manual; we don't have a bulk-unban API yet — TODO for v8.4)

**Postmortem:**
- Add the bad pattern to a "known-bad" list in the rule editor with a warning
- Consider adding a 5-minute "armed" delay on new rules so a typo can be caught

---

## 5. Discord bot stops responding to /gm commands

**Diagnosis:** `/gm help`, `/gm chat`, `/gm scope` all silently fail. Worker tail shows no `/bot/discord/interactions` POSTs.

**Immediate mitigation:**
1. Verify Discord interaction endpoint URL in dev portal: `https://discord.com/developers/applications/1468666475991793797/information`
2. Endpoint URL must be: `https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/bot/discord/interactions`
3. Smoke-test the endpoint:  
   `curl -X POST -H "Content-Type: application/json" -d '{"type":1}' <endpoint>` → expect 401 `missing sig` (proves alive)
4. If endpoint URL is correct and worker is alive: the bot may have been removed from the server. Re-invite via OAuth URL in the Developer Portal.

**Postmortem:**
- Discord rotates verification keys when an app is reinstalled — if `DISCORD_PUBLIC_KEY` worker secret is stale, signatures fail. Re-fetch from Developer Portal → set as new secret.

---

## 6. Worker quota exhausted

**Diagnosis:** Workers free tier: 100k requests/day. Hitting the limit returns 429 from CF edge. CF dashboard → Workers → Metrics shows red bar.

**Immediate mitigation:**
1. Upgrade to Workers Paid: CF dashboard → Workers Plans → Paid ($5/mo + $0.30/M after 10M)
2. Until upgrade lands: temporarily disable `features.firehose` and `features.ai` worker-side via env var (cuts ~80% of traffic)

**Postmortem:**
- Add per-mod request budget telemetry (Analytics Engine query to surface heavy users)
- Consider read-cache layer in the worker for `/profiles/read` and `/parked/list`

---

## 7. Onboarding modal fires on a mod who's already onboarded

**Diagnosis:** Mod reports the welcome modal keeps reappearing despite previously entering token. Their debug snapshot shows `auth.onboardedOnce: false` despite a working token.

**Immediate mitigation:**
1. In their service worker console:
   ```js
   chrome.storage.local.get('gam_settings').then(r => { const s=r.gam_settings||{}; s.tokenOnboardedOnce=true; s.tokenOnboardedAs=PROMPT_FOR_THEIR_USERNAME; chrome.storage.local.set({gam_settings:s}); });
   ```
2. Or set the kill switch: `window.__GAM_KILL_MODAL = true` in any tab's DevTools

**Postmortem:**
- v8.2.5 added the flag check inside `showTokenOnboardingModal` — if the modal still fires, there's a 5th trigger site we missed
- Pull their `networkLog` from the debug snapshot to see what 401-ed

---

## 8. Mass extension breakage — entire extension stops working after GAW updates

**Diagnosis:** Mods report "ModTools not appearing on the page" or "yellow `expected element not found` warning."

**Immediate mitigation:**
1. F12 in browser console on greatawakening.win
2. Look for `[modtools] DOM health` warnings — they identify which selectors broke
3. Update the selector in `modtools.js` `K` map (top of file, ~line 100-150)
4. Hot-reload — drop new file in extension folder + click ↻ Reload

**Postmortem:**
- We have `learnedSelectors` infrastructure but no auto-update path; consider adding a worker endpoint that pushes new selector hints

---

## 9. Worker secret rotation (planned)

Quarterly or after any suspicion of leak. Rotate one at a time:

1. `LEAD_MOD_TOKEN` — see scenario 2
2. `MOD_TOKEN` — `wrangler secret put MOD_TOKEN` then redeploy
3. `XAI_API_KEY` — get new key from xAI dashboard, `wrangler secret put XAI_API_KEY`
4. `ANTHROPIC_API_KEY` — same pattern, console.anthropic.com → keys
5. `DISCORD_BOT_TOKEN` — Developer Portal → reset token → `wrangler secret put DISCORD_BOT_TOKEN`
6. `DISCORD_PUBLIC_KEY` — same source, secret name
7. `GITHUB_PAT` — github.com → settings → Developer settings → PATs → regenerate

After each, verify with the appropriate smoke test (`/health`, `/mod/whoami`, etc.).

---

## On-call escalation

- **Tier 1 (anyone with mod access):** check this runbook, attempt mitigation
- **Tier 2 (Commander Cats):** code-level changes, secret rotation, deploys
- **Tier 3 (Claude Code session):** worker code changes, agent-driven larger fixes

Discord channel `#ai-tools` is the primary incident comm thread. Use `/gm chat message:incident summary` for AI-assisted triage notes.

---

**Last updated:** 2026-04-25 (v8.3.0 release)
