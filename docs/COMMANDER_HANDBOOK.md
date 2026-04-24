# Commander's Handbook — GAW ModTools + AI-Tools Bot

> **STATUS: WORK IN PROGRESS.** Captures everything you (Commander) need to
> operate the GAW ModTools ecosystem end-to-end. Append sections as you learn
> new ops or hit new problems. Last updated: v5.7.0 deployment session
> (Apr 2026).

---

## 1. Quick Reference — `/gm` Bot Commands (in Discord `#ai-tools`)

All commands live under the single `/gm` parent (so they never collide with
other server bots like Midjourney).

| Command | Model | Cost | Use case |
|---|---|---|---|
| `/gm ask <question>` | Grok-3-mini | ~$0.003/call | Default. May delegate to Llama for code lookups — you see `🧠 Boss → 🔧 Worker` in thread |
| `/gm g3 <question>` | Grok-3 full | ~$0.07/call | Important questions where quality matters |
| `/gm l3 <question>` | Llama 3.3 70B | FREE | Simple questions, unlimited use |
| `/gm propose <summary>` | Grok-3-mini + DB | ~$0.01 | Mod files a feature request → Grok refines → opens poll (48h, 2-mod quorum) |
| `/gm vote <feature_id> <1-4>` | — | free | Cast a vote on a feature poll |
| `/gm status` | — | free | Budget today, active polls, recent proposals |
| `/gm finalize <id>` | Grok-3 full | ~$0.10 | **Lead only.** Emits Claude-Code-ready prompt + DMs it to Commander |
| `/gm help` | — | free | Command list |

### Budget

- Hard cap: **$5/day** on Grok (tracked in KV: `bot:grok:budget:YYYY-MM-DD`)
- Llama is FREE and unlimited (Cloudflare Workers AI)
- Check with `/gm status`
- When exhausted: `/gm ask` falls back to Llama silently; `/gm g3` rejects with clear error

### Delegation pattern to watch for

When Grok-3-mini needs a codebase lookup, you'll see two extra messages in the channel:
```
🧠 Boss → 🔧 Worker: find all callers of setSetting
🔧 → 🧠 Found 23 usages at L2341, L3892, ...
```
Then Grok's final answer is posted. Normal flow.

---

## 2. System State — What's Deployed Where

### Chrome Extension — `modtools-ext/`
- **Current version**: v5.7.0
- **Installer**: `D:\AI\_PROJECTS\update-modtools.ps1` (646 KB)
- **Installer mirror**: `https://raw.githubusercontent.com/catsfive1/gaw-mod-shared-flags/main/update-modtools.ps1`
- **Source**: `D:\AI\_PROJECTS\modtools-ext\modtools.js` (~8700 lines)
- **Manifest version source of truth**: `D:\AI\_PROJECTS\modtools-ext\manifest.json`
- **Sha256** (v5.7.0): `3053baeb3ff4a53ae7897b9632d1fca203af613c2f3986e369f05417416cfbf9`

### Cloudflare Worker — `gaw-mod-proxy`
- **URL**: `https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev`
- **Source file**: `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` (~2500 lines)
- **CF service name**: `gaw-mod-proxy` (reported as `version: 2.0` regardless of internal code version — don't confuse with code version)
- **Internal code version**: v5.7.0
- **Deploy method currently**: paste JS into CF dashboard editor (no `wrangler.toml` yet)

### D1 Database
- **Name**: `gaw-audit`
- **Binding**: `AUDIT_DB`
- **Migrations applied**:
  - `001_audit.sql` (actions, evidence, presence)
  - `002_inbox_intel.sql` (modmail_*)
  - `003_bot.sql` (bot_mods, bot_feature_requests, bot_polls, bot_poll_votes, bot_conversations, bot_ai_audit) ✅ v5.6.0
  - `004_firehose.sql` (gaw_posts, gaw_comments, gaw_users, gaw_crawl_state, gaw_ingest_audit + FTS5) ✅ v5.7.0

### Shared Repo — `gaw-mod-shared-flags`
- **Repo**: `https://github.com/catsfive1/gaw-mod-shared-flags`
- **Key files**:
  - `version.json` — bumped on every release
  - `update-modtools.ps1` — installer distributed from GitHub raw
  - `docs/ARCHITECTURE.md` — living project brain (Grok reads this every call)
  - `docs/CODEMAP.md` — auto-generated on push via `.github/workflows/update-codemap.yml`
  - `scripts/build-codemap.mjs` — the CI builder
  - `flags.json`, `profiles.json`, `manifest.json` — team shared state
- **Important**: structural changes (new endpoints, new D1 tables, new consent keys) MUST update `docs/ARCHITECTURE.md` in the same commit or Grok gives stale answers

### Discord
- **Server/Guild ID**: `738064128484311091`
- **Bot**: GAW ModTools Bot (installed with `applications.commands + bot` scopes)
- **Channel**: `#ai-tools`
- **Interactions Endpoint URL**: `https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/bot/discord/interactions`

---

## 3. Credentials & Tokens — What's Where

**Rule: the actual values never leave your machine.** Claude can reference them (by name) but not read them.

### Stored in Cloudflare Workers secrets (encrypted, write-only in dashboard)
| Secret | Purpose | How set |
|---|---|---|
| `GITHUB_PAT` | Write to shared-flags repo | Pre-existing |
| `MOD_TOKEN` | Team-shared bearer for mod endpoints | Pre-existing |
| `LEAD_MOD_TOKEN` | Commander-only admin endpoints | Regenerated this session (48 chars) |
| `XAI_API_KEY` | Grok access | Pre-existing |
| `DISCORD_BOT_TOKEN` | Bot identity | Set this session |
| `DISCORD_PUBLIC_KEY` | Ed25519 sig verify | Set this session |
| `DISCORD_APP_ID` | Slash command registration target | Set this session |
| `COMMANDER_DISCORD_ID` | DM target for finalized prompts | Set this session |
| `AI_TOOLS_CHANNEL_ID` | Channel scope enforcement | Set this session |

### Stored as Windows user env vars on your machine
| Env var | Purpose | Length |
|---|---|---|
| `GAW_LEAD_TOKEN` | Lets PowerShell call admin worker endpoints | 48 chars |
| `GAW_GUILD_ID` | Discord server ID | 18 digits |

Retrieve: `[System.Environment]::GetEnvironmentVariable('GAW_LEAD_TOKEN', 'User')`

### Where to put YOUR copy (backup)
Anywhere secure: password manager, 1Password, encrypted notes, etc. Never:
commits, cleartext files on disk, chat windows, screenshots shared online.

### If a token is ever compromised
Regenerate and update BOTH places:
```powershell
# Generate new
$newToken = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
[System.Environment]::SetEnvironmentVariable('GAW_LEAD_TOKEN', $newToken, 'User')
Set-Clipboard -Value $newToken
Write-Host "New token on clipboard. Now paste into CF dashboard -> LEAD_MOD_TOKEN secret -> Save and deploy."
```
Then in CF dashboard → Workers → gaw-mod-proxy → Settings → Variables and
Secrets → find `LEAD_MOD_TOKEN` → Edit → Ctrl+V → Save and deploy.

---

## 4. Daily Operations

### A. Monitoring the bot

In `#ai-tools`:
- `/gm status` — shows budget used today / $5 cap, active polls, recent proposals, mods enrolled

Budget at worker level:
```powershell
# If you want to see the raw KV counter (requires wrangler):
npx wrangler kv key get --binding=MOD_KV "bot:grok:budget:$(Get-Date -Format yyyy-MM-dd)"
```

### B. Checking AI audit log
Every AI call is logged in D1 `bot_ai_audit` table. To query:
```sql
-- In CF dashboard → D1 → gaw-audit → Console
SELECT ts, interaction, model, cost_cents, success, actor_id
  FROM bot_ai_audit
  ORDER BY ts DESC LIMIT 50;
```

### C. Checking firehose ingest
```sql
SELECT ts, kind, source, rows_in, rows_new, rows_updated, error
  FROM gaw_ingest_audit
  ORDER BY ts DESC LIMIT 20;

-- Total captured content:
SELECT (SELECT COUNT(*) FROM gaw_posts) AS posts,
       (SELECT COUNT(*) FROM gaw_comments) AS comments,
       (SELECT COUNT(*) FROM gaw_users) AS users;
```

### D. Search captured content
```powershell
$lead = [System.Environment]::GetEnvironmentVariable('GAW_LEAD_TOKEN','User')
# Replace LEAD with MOD_TOKEN for search (needs MOD_TOKEN, not LEAD)
# Get it from CF dashboard → MOD_TOKEN secret
$mod = 'PASTE_MOD_TOKEN_HERE'
Invoke-RestMethod "https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/gaw/search?q=someword&scope=both" -Headers @{'x-mod-token'=$mod}
```

---

## 5. Adding Mods to the Allowlist

Each mod needs a Discord user ID + their GAW username.

### PowerShell (single mod)
```powershell
$lead = [System.Environment]::GetEnvironmentVariable('GAW_LEAD_TOKEN','User')
$params = @{
    Uri         = 'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/bot/mods/add'
    Method      = 'POST'
    Headers     = @{ 'x-lead-token' = $lead }
    ContentType = 'application/json'
    Body        = (@{
        discord_id   = '123456789012345678'
        gaw_username = 'someuser'
        role         = 'mod'            # or 'lead'
    } | ConvertTo-Json -Compress)
}
Invoke-RestMethod @params
```

### View current allowlist
```powershell
$lead = [System.Environment]::GetEnvironmentVariable('GAW_LEAD_TOKEN','User')
Invoke-RestMethod "https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/bot/mods/list" -Headers @{'x-lead-token'=$lead}
```

### Roles
- `mod` — can use all commands except `/gm finalize`
- `lead` — can use all commands including `/gm finalize`
- `observer` — reserved for future (currently same as mod)

### Removing a mod
```powershell
$lead = [System.Environment]::GetEnvironmentVariable('GAW_LEAD_TOKEN','User')
Invoke-RestMethod -Method Post -Uri 'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/bot/mods/remove' `
    -Headers @{'x-lead-token'=$lead} -ContentType 'application/json' `
    -Body (@{ discord_id='123456789012345678' } | ConvertTo-Json -Compress)
```

---

## 6. Updating the System

### Updating the Chrome extension (new ModTools version)

1. Edit `D:\AI\_PROJECTS\modtools-ext\modtools.js`
2. Bump `VERSION` at line ~34
3. Bump `D:\AI\_PROJECTS\modtools-ext\manifest.json` → `"version"`
4. Bump `D:\AI\_PROJECTS\_build_installer.py` → `VERSION`
5. Run the build:
   ```powershell
   cd D:\AI\_PROJECTS
   python _build_installer.py
   ```
6. Copy installer to shared-flags repo:
   ```powershell
   Copy-Item update-modtools.ps1 gaw-mod-shared-flags\update-modtools.ps1
   ```
7. Update `gaw-mod-shared-flags\version.json` with new version + notes
8. Commit + push `gaw-mod-shared-flags`:
   ```powershell
   cd D:\AI\_PROJECTS\gaw-mod-shared-flags
   git add version.json update-modtools.ps1
   git commit -m "vX.Y.Z: <summary>"
   git push
   ```
9. In Chrome: `chrome://extensions` → **Reload** on GAW ModTools

### Deploying a new worker version

Currently no `wrangler.toml`, so manual:

1. Open `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` in Notepad
2. Ctrl+A, Ctrl+C
3. CF dashboard → Workers & Pages → gaw-mod-proxy → Edit Code
4. Select all in editor, Ctrl+V
5. **Save and Deploy**

### Applying a new D1 migration

When Claude (or you) add a new `migrations/XXX_*.sql` file:

```powershell
cd D:\AI\_PROJECTS\cloudflare-worker
npx wrangler d1 execute gaw-audit --remote --file=migrations/XXX_name.sql
```

Expected: `Executed N queries in Mms`. If errors: check that migration is idempotent (uses `IF NOT EXISTS`).

**If you want zero-typing migration runs**, re-run the wrangler-driven script:
```powershell
pwsh -File D:\AI\_PROJECTS\setup-db.ps1
```
(It lists DBs, picks by number, applies both new migrations. Re-applying old migrations is safe because of `IF NOT EXISTS`.)

---

## 7. Architecture Reference

### Runtime topology (simplified)

```
Chrome ext (modtools.js) → CF Worker (gaw-mod-proxy-v2.js) → D1 / KV / R2 / AI / Analytics
                                    ↘ xAI Grok
                                    ↘ AbuseIPDB, Brave Search, GitHub API

#ai-tools Discord → CF Worker /bot/discord/interactions → Grok/Llama → posts back to #ai-tools
                                                                    → DMs Commander (finalize)
```

### Full living documentation

- **Living brain**: `D:\AI\_PROJECTS\gaw-mod-shared-flags\docs\ARCHITECTURE.md` — Grok reads this + CODEMAP.md on every call. ~12KB. Update on structural changes.
- **Auto-generated index**: `docs/CODEMAP.md` — rebuilt by CI on every push. Don't edit by hand.

### Storage expectations

- **D1**: 5GB free tier, 25M reads/mo. Posts+comments projected ~1-2GB. Fine.
- **KV**: plenty of headroom for budget counters, cache
- **R2**: ~free tier, evidence blobs only
- **Workers AI (Llama)**: FREE within CF's generous limit (10k reqs/day free tier)

---

## 8. Troubleshooting

### Common errors we've hit + fixes

| Error | Cause | Fix |
|---|---|---|
| `The '<' operator is reserved for future use` | PowerShell saw `<placeholder>` as redirect | Replace placeholder with actual value OR use `Read-Host` wrapper |
| `Missing closing '}' in statement block` when running .ps1 | UTF-8 no BOM + non-ASCII chars in the script | Strip non-ASCII, prepend UTF-8 BOM, parse-verify |
| `Requests without any query are not supported` (D1 console) | Pasted SQL was all comments (header block) | Strip `--` header; start paste from first real statement |
| `incomplete input: SQLITE_ERROR` (D1 console) | Console split trigger on `;` mid-body | Use `npx wrangler d1 execute --file=` OR paste each statement individually from `_split.md` |
| `invalid lead token` (worker 403) | Local LEAD_MOD_TOKEN doesn't match CF secret | Regenerate fresh, update both sides |
| `Missing Access` code 50001 (Discord 403) | Bot not in server OR missing `applications.commands` scope | Re-install bot with BOTH `applications.commands + bot` scopes from dev portal Installation tab |
| Installer banner shows wrong version (mojibake) | Worker response body not decoded as UTF-8 | Already fixed in v5.4.1 via `fetchVersionJson` + `cleanRemoteNotes` |
| `/gm help` returns 404 in Discord | Worker not deployed (stale code) OR slash commands not registered | 1) Re-paste JS to CF dashboard + deploy; 2) Re-run `/bot/register-commands` curl |
| `SecureString` paste captures only 1 character | Terminal quirk on paste to hidden prompt | Use `Get-Clipboard`-based capture instead: `$plain = (Get-Clipboard).Trim()` |

### Sanity-check commands (paste one at a time)

```powershell
# Is worker live?
Invoke-RestMethod https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/

# Does worker have new endpoints?
try { Invoke-RestMethod "https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/gaw/search?q=test" -Headers @{'x-mod-token'='bogus'} } catch { $_.ErrorDetails.Message }

# Does the lead token work?
$lead = [System.Environment]::GetEnvironmentVariable('GAW_LEAD_TOKEN','User')
Invoke-RestMethod "https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev/bot/mods/list" -Headers @{'x-lead-token'=$lead}
```

---

## 9. PowerShell Canonical Rules

Claude has a rule file at `C:\Users\smoki\.claude\rules\common\powershell.md`
that prevents repeat mistakes. **Read that file** if Claude ever hands you a
broken script — it's the checklist Claude is supposed to follow before
shipping anything you'll paste.

Highlights that matter to YOU:
- Scripts should parse clean: `[System.Management.Automation.Language.Parser]::ParseFile('file.ps1', [ref]$null, [ref]$null)`
- No `<placeholder>` syntax in commands — always a `.ps1` with `Read-Host`, or explicit `$var = 'value'` first
- `.ps1` scripts written by Claude MUST have UTF-8 BOM + ASCII-only body

---

## 9b. Commander Review Loop (v5.8.0) — NEW

You personally approve/amend/punt/reject every feature request before it
reaches Claude Code.

### How it works end-to-end

1. Mod types `/gm propose <feature>` in `#ai-tools`
2. Grok-3-mini refines → opens poll (48h, 2-mod quorum)
3. Poll wins "Ship as-is" or "Ship w/ adjustments" → auto-finalize fires
4. Grok-3 full generates Claude-Code-ready prompt
5. **You get a DM** with the prompt + 4 buttons:
   - ✅ **Approve & Send** — one click. Prompt is DMed back clean (no buttons) so you can copy-paste into a fresh Claude Code session. `#ai-tools` gets a "shipping" notification.
   - ✏️ **Amend** — opens a text box. You write specific overrides ("use PostgreSQL instead of D1", "skip the migration step", whatever). Grok regenerates the prompt treating your comments as AUTHORITATIVE over the original spec. New DM arrives with new prompt + buttons. Iterate until you're happy.
   - ⤴️ **Punt to Mods** — opens text box. Write context/concerns. Bot reposts to `#ai-tools` with your comments AND opens a brand-new poll. Mods vote again. Back to step 3.
   - ❌ **Reject** — optional reason. Marks rejected, notifies `#ai-tools`, done.

### Why this matters

- **You keep final control** — no feature ships to Claude Code without your explicit approve click
- **No friction for obvious wins** — one button
- **Iteration is cheap** — amend reruns Grok-3 in ~10 seconds
- **Mods stay in the loop** — punt is transparent (they see your concerns)
- **Auditable** — every decision logged in `bot_commander_decisions`

### Data you can query

```sql
-- Recent Commander decisions
SELECT d.ts, fr.summary_refined, d.decision, d.iteration, d.comments
  FROM bot_commander_decisions d
  JOIN bot_feature_requests fr ON fr.id = d.feature_id
  ORDER BY d.ts DESC LIMIT 20;

-- How many amend iterations did each feature need?
SELECT id, summary_refined, iteration_count, status
  FROM bot_feature_requests
  ORDER BY iteration_count DESC LIMIT 10;
```

### Commander identity = `@DropGun`

Currently `COMMANDER_DISCORD_ID` points to your primary Discord user. All
review DMs go there. If you want a DIFFERENT account (e.g. mods-only alt) to
receive the reviews, update the CF secret `COMMANDER_DISCORD_ID` accordingly.

---

## 10. TODO / Pending Work

### Immediate (to finish current deployment)
- [ ] Add yourself as `role=lead` in bot_mods allowlist
- [ ] Add other beta-tester mods with `role=mod`
- [ ] Smoke-test `/gm help` in `#ai-tools`
- [ ] Smoke-test `/gm ask question: <anything>` to verify Grok+Llama grounding works
- [ ] Verify firehose is capturing posts: check `gaw_posts` row count after an hour
- [ ] (optional) Enable server-side crawl cron: add `GAW_CRAWL_ENABLED=true` as CF env var

### Near-term features still to build
- [ ] **CHUNK 4** of INBOX INTEL — already shipped! enrichmentDrainTick now auto-drains the Llama queue every 5 min
- [ ] **CHUNK 13** — formal consent gate UI beyond the modal we have (toggle in popup Settings)
- [ ] **CHUNKs 5-12** of INBOX INTEL — 3-panel modmail UI, ban-from-thread, keyboard shortcuts
- [ ] Flag dots (🟡🔴🕐) on usernames (backend exists, UI missing)
- [ ] Watch/rate capability on `/u/*` and `/p/*` pages
- [ ] Mods-only note field on profile cards
- [ ] Ban-summarize-this-user flow (user asked in earlier session)

### Roadmap items discussed but not scoped yet
- [ ] Deleted-content archive (capture posts before removal via is_removed flag on re-fetch)
- [ ] Comment tree hydration (current firehose is posts-only)
- [ ] Mod log capture (who banned who, when, why)
- [ ] Report history capture
- [ ] Account-creation clustering (botnet detection view)
- [ ] User timeline rebuild UI (Triage Console panel)
- [ ] Web dashboard for browsing gaw_* + bot_* tables without D1 CLI
- [ ] `/gm addmod` slash command (so you don't have to curl)

### Operational improvements
- [ ] Generate a `wrangler.toml` so worker deploys become `wrangler deploy` instead of copy-paste
- [ ] Migrate to fully wrangler-based workflow for everything
- [ ] Add a `wrangler tail` watcher dashboard for live log viewing

---

## 11. Appendix: Things I Learned The Hard Way (this session)

- **PS 5.1 UTF-8 no-BOM parser bug** — https://learn.microsoft.com/en-us/answers/questions/3850223 — any `.ps1` I hand you gets a BOM prepended automatically now
- **D1 web console's dumb SQL splitter** — chokes on triggers. Use wrangler CLI.
- **Discord guild-scoped command registration requires `applications.commands` scope** at install time, not install-only `bot` scope
- **Cloudflare service version vs internal code version** — `version: 2.0` in the worker JSON reply is a constant string; the real version stepped 5.5.0→5.6.0→5.7.0 but the worker always reports 2.0
- **`Read-Host -AsSecureString` paste quirk** — single `*` shown regardless of length, AND on some terminals only captures one character. Prefer `Get-Clipboard`-based entry.

---

*Keep appending. This doc is the single source of truth when Claude is not
around, when a new session starts cold, or when a mod pulls you aside at 3am
with "the bot stopped responding."*
