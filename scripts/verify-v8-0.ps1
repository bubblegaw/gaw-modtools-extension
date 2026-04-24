<#
.SYNOPSIS
    Verify v8.0 Team Productivity release artifacts.
.DESCRIPTION
    Runs static checks covering manifest + modtools + worker + migration 013 +
    shared-flags + dashboard PRIVACY, plus grep-gate banned-pattern enforcement
    in the v8.0 TEAM PRODUCTIVITY REGION only. Enforces Amendment A (request
    correlation headers + emitEvent), Amendment B (evidence-backed AI schema +
    client-side gating + precedent citation rule/outcome only), and Amendment
    B.4 (daily AI scan -> ai_suspect_queue migration). Optionally runs live
    worker auth-gate probes when -LiveWorker is passed. Exits 0 on full pass,
    2 on any failure. ASCII-only, UTF-8 BOM. Parse-clean on PS 5.1 and PS 7.
.PARAMETER NoPause
    Skip the final Read-Host prompt.
.PARAMETER LiveWorker
    Also run live HTTP probes against the deployed worker (regression probes
    on existing v7.x endpoints + v8.0 endpoint presence checks).
.EXAMPLE
    pwsh -NoProfile -File D:\AI\_PROJECTS\verify-v8-0.ps1
.EXAMPLE
    pwsh -NoProfile -File D:\AI\_PROJECTS\verify-v8-0.ps1 -LiveWorker
.NOTES
    Version: 1.0.0
    Requires: PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [switch]$NoPause,
    [switch]$LiveWorker
)

$ErrorActionPreference = 'Continue'
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Requires PowerShell 5.1+. Found $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit 1
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$log = New-Object System.Collections.Generic.List[string]
function Say {
    param([string]$Text, [string]$Color = 'Cyan')
    Write-Host $Text -ForegroundColor $Color
    $log.Add($Text) | Out-Null
}

$t0 = Get-Date
$RepoRoot   = 'D:\AI\_PROJECTS'
$ExtDir     = Join-Path $RepoRoot 'modtools-ext'
$ModTools   = Join-Path $ExtDir 'modtools.js'
$BgJs       = Join-Path $ExtDir 'background.js'
$PopupJs    = Join-Path $ExtDir 'popup.js'
$Manifest   = Join-Path $ExtDir 'manifest.json'
$WorkerJs   = Join-Path $RepoRoot 'cloudflare-worker\gaw-mod-proxy-v2.js'
$MigSql     = Join-Path $RepoRoot 'cloudflare-worker\migrations\013_team_productivity.sql'
$SetupTeam  = Join-Path $RepoRoot 'setup-team-productivity.ps1'
$SharedVer  = Join-Path $RepoRoot 'gaw-mod-shared-flags\version.json'
$Privacy    = Join-Path $RepoRoot 'gaw-dashboard\public\PRIVACY.md'

$results = @()
$pass = 0
$fail = 0

function Check {
    param(
        [int]$Num,
        [string]$Name,
        [bool]$Ok,
        [string]$Detail = ''
    )
    if ($Ok) {
        Say ("  [{0:D2}] PASS - {1}" -f $Num, $Name) 'Green'
        if ($Detail) { Say ("         {0}" -f $Detail) 'DarkGray' }
        $script:pass++
    } else {
        Say ("  [{0:D2}] FAIL - {1}" -f $Num, $Name) 'Red'
        if ($Detail) { Say ("         {0}" -f $Detail) 'Yellow' }
        $script:fail++
    }
    $script:results += [pscustomobject]@{ n=$Num; name=$Name; ok=$Ok; detail=$Detail }
}

function ReadText($p) {
    if (Test-Path $p) { return [IO.File]::ReadAllText($p) } else { return $null }
}

function ReadLines($p) {
    if (Test-Path $p) { return [IO.File]::ReadAllLines($p) } else { return @() }
}

# Locate v8.0 TEAM PRODUCTIVITY REGION in modtools.js by BEGIN/END markers.
function Find-V80Region($lines) {
    $begin = -1
    $end = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($begin -lt 0 -and $lines[$i] -match 'v8\.0 TEAM PRODUCTIVITY REGION BEGIN') { $begin = $i + 1 }
        elseif ($begin -ge 0 -and $lines[$i] -match 'v8\.0 TEAM PRODUCTIVITY REGION END') { $end = $i + 1; break }
    }
    return @($begin, $end)
}

# Locate worker-side v8.0 region.
function Find-WorkerV80Region($lines) {
    $begin = -1
    $end = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($begin -lt 0 -and $lines[$i] -match 'v8\.0 Team Productivity .+ worker-side region BEGIN') { $begin = $i + 1 }
        elseif ($begin -ge 0 -and $lines[$i] -match 'v8\.0 Team Productivity .+ worker-side region END') { $end = $i + 1; break }
    }
    return @($begin, $end)
}

Say '=============================================================='
Say 'v8.0 verification -- Team Productivity (Shadow Queue + Park + Precedent)'
Say '=============================================================='

# ---- Load files once -------------------------------------------------------
$manifestText  = ReadText $Manifest
$modtoolsText  = ReadText $ModTools
$modtoolsLines = ReadLines $ModTools
$bgText        = ReadText $BgJs
$popupText     = ReadText $PopupJs
$workerText    = ReadText $WorkerJs
$workerLines   = ReadLines $WorkerJs
$migText       = ReadText $MigSql
$sharedVerTxt  = ReadText $SharedVer
$privacyText   = ReadText $Privacy

$region        = Find-V80Region $modtoolsLines
$regionStart   = [int]$region[0]
$regionEnd     = [int]$region[1]
$regionSlice   = ''
if ($regionStart -gt 0 -and $regionEnd -gt $regionStart) {
    $regionSlice = ($modtoolsLines[($regionStart-1)..($regionEnd-1)] -join "`n")
}
$workerRegion  = Find-WorkerV80Region $workerLines
$workerRegionStart = [int]$workerRegion[0]
$workerRegionEnd   = [int]$workerRegion[1]
$workerRegionSlice = ''
if ($workerRegionStart -gt 0 -and $workerRegionEnd -gt $workerRegionStart) {
    $workerRegionSlice = ($workerLines[($workerRegionStart-1)..($workerRegionEnd-1)] -join "`n")
}

Say ("  modtools v8.0 region: lines {0}..{1}" -f $regionStart, $regionEnd) 'DarkGray'
Say ("  worker   v8.0 region: lines {0}..{1}" -f $workerRegionStart, $workerRegionEnd) 'DarkGray'

# ---- STATIC CHECKS --------------------------------------------------------

# 01. manifest.json version === 8.0.0
$ok1 = $false; $detail1 = ''
if ($manifestText) {
    try {
        $j = $manifestText | ConvertFrom-Json
        $detail1 = "found: $($j.version)"
        $ok1 = ($j.version -eq '8.0.0')
    } catch { $detail1 = "parse error: $_" }
} else { $detail1 = 'file not found' }
Check 1 'manifest.json version == 8.0.0' $ok1 $detail1

# 02. modtools.js VERSION const === 'v8.0.0'
$ok2 = $false
if ($modtoolsText) { $ok2 = $modtoolsText -match "VERSION\s*=\s*'v8\.0\.0'" }
Check 2 "modtools.js VERSION == 'v8.0.0'" $ok2

# 03. shared-flags version.json version === 8.0.0
$ok3 = $false; $detail3 = ''
if ($sharedVerTxt) {
    try {
        $sv = $sharedVerTxt | ConvertFrom-Json
        $detail3 = "found: $($sv.version)"
        $ok3 = ($sv.version -eq '8.0.0')
    } catch { $detail3 = "parse error: $_" }
} else { $detail3 = 'file not found' }
Check 3 'shared-flags version.json == 8.0.0' $ok3 $detail3

# 04. migration 013 exists + all three v8.0 tables declared.
$ok4a = $false; $ok4b = $false; $ok4c = $false
if ($migText) {
    $ok4a = $migText -match 'CREATE TABLE IF NOT EXISTS shadow_triage_decisions'
    $ok4b = $migText -match 'CREATE TABLE IF NOT EXISTS parked_items'
    $ok4c = $migText -match 'CREATE TABLE IF NOT EXISTS ai_suspect_queue'
}
Check 4 'migration 013: shadow_triage_decisions + parked_items + ai_suspect_queue' ($ok4a -and $ok4b -and $ok4c) "shadow=$ok4a park=$ok4b ai_suspect=$ok4c"

# 05. setup-team-productivity.ps1 exists + parses clean.
$ok5 = $false; $detail5 = ''
if (Test-Path $SetupTeam) {
    $errs = $null
    try {
        [System.Management.Automation.Language.Parser]::ParseFile($SetupTeam, [ref]$null, [ref]$errs) | Out-Null
        if ($errs -and $errs.Count -gt 0) {
            $detail5 = "parse errors: " + (($errs | ForEach-Object { "L$($_.Extent.StartLineNumber):$($_.Message)" }) -join '; ')
        } else {
            $ok5 = $true
            $detail5 = 'parse OK'
        }
    } catch { $detail5 = "parse threw: $_" }
} else { $detail5 = 'file not found' }
Check 5 'setup-team-productivity.ps1 exists + parses clean' $ok5 $detail5

# 06. modtools.js v8.0 REGION BEGIN / END markers.
$ok6 = ($regionStart -gt 0 -and $regionEnd -gt $regionStart)
Check 6 'modtools.js has v8.0 TEAM PRODUCTIVITY REGION markers' $ok6 "begin=$regionStart end=$regionEnd"

# 07. All v8.0 feature flag defaults = false.
$ok7a = $false; $ok7b = $false; $ok7c = $false; $ok7d = $false
if ($modtoolsText) {
    $ok7a = $modtoolsText -match "'features\.teamBoost'\s*:\s*false"
    $ok7b = $modtoolsText -match "'features\.shadowQueue'\s*:\s*false"
    $ok7c = $modtoolsText -match "'features\.park'\s*:\s*false"
    $ok7d = $modtoolsText -match "'features\.precedentCiting'\s*:\s*false"
}
Check 7 'all four v8.0 feature flags default false' ($ok7a -and $ok7b -and $ok7c -and $ok7d) "teamBoost=$ok7a shadowQueue=$ok7b park=$ok7c precedentCiting=$ok7d"

# 08. window.__v80 surface helpers are wired.
$ok8 = $false
$missing8 = @()
if ($modtoolsText) {
    $syms = @('__teamBoostOn','__v80EmitEvent','__v80InferFeatureFromPath','__v80BuildCorrelationHeaders','__v80ShadowTriageFetch','__v80BuildShadowBadge')
    foreach ($s in $syms) {
        if ($modtoolsText -notmatch [regex]::Escape($s)) { $missing8 += $s }
    }
    $ok8 = ($missing8.Count -eq 0) -and ($modtoolsText -match 'window\.__v80\s*=\s*\{')
}
Check 8 '__v80 helpers wired (emitEvent, correlation headers, shadow triage fetch, shadow badge)' $ok8 ("missing: " + ($missing8 -join ','))

# 09. data-gam-action='park' + data-gam-shadow-action emitted.
$ok9a = $false; $ok9b = $false
if ($modtoolsText) {
    $ok9a = $modtoolsText -match "data-gam-action=`"park`""
    $ok9b = $modtoolsText -match 'data-gam-shadow-action'
}
Check 9 'modtools emits data-gam-action="park" and data-gam-shadow-action' ($ok9a -and $ok9b) "park=$ok9a shadow=$ok9b"

# 10. IX.getPrecedentCount accessor present (CHUNK 8 precedent prefetch).
$ok10 = $false
if ($modtoolsText) { $ok10 = $modtoolsText -match 'IX\.getPrecedentCount' }
Check 10 'IX.getPrecedentCount accessor present (precedent prefetch)' $ok10

# 11. worker routes for /ai/shadow-triage + /parked/{create,list,resolve}.
$ok11a = $false; $ok11b = $false; $ok11c = $false; $ok11d = $false
if ($workerText) {
    $ok11a = $workerText -match "'/ai/shadow-triage'"
    $ok11b = $workerText -match "'/parked/create'"
    $ok11c = $workerText -match "'/parked/list'"
    $ok11d = $workerText -match "'/parked/resolve'"
}
Check 11 'worker router includes all v8.0 endpoints' ($ok11a -and $ok11b -and $ok11c -and $ok11d) "shadow=$ok11a create=$ok11b list=$ok11c resolve=$ok11d"

# 12. PRIVACY.md has v8.0 data categories section.
$ok12 = $false
if ($privacyText) { $ok12 = $privacyText -match 'v8\.0 .+data categories' }
Check 12 'gaw-dashboard PRIVACY.md has v8.0 data categories section' $ok12

# 13. workerCall attaches correlation headers (Amendment A.1).
$ok13a = $false; $ok13b = $false; $ok13c = $false
if ($modtoolsText) {
    $ok13a = $modtoolsText -match "'X-GAM-Request-Id'"
    $ok13b = $modtoolsText -match "'X-GAM-Session-Id'"
    $ok13c = $modtoolsText -match "'X-GAM-Feature'"
}
Check 13 'workerCall attaches X-GAM-Request-Id / Session-Id / Feature' ($ok13a -and $ok13b -and $ok13c) "req=$ok13a sess=$ok13b feat=$ok13c"

# 14. Shadow triage response (worker) emits all Amendment B.2 fields.
$ok14 = $false; $detail14 = ''
$req14 = @('decision','confidence','evidence','counterarguments','rule_refs','prompt_version','model','provider','rules_version','generated_at')
if ($workerText -and $workerRegionSlice) {
    $missingInResp = @()
    # Field names must all appear inside a payload-construction block within the
    # handleAiShadowTriage function. Use a coarse region-level check.
    foreach ($f in $req14) {
        if ($workerRegionSlice -notmatch [regex]::Escape($f)) { $missingInResp += $f }
    }
    $ok14 = ($missingInResp.Count -eq 0)
    $detail14 = if ($missingInResp.Count -eq 0) { 'all 10 fields present in v8.0 region' } else { 'missing: ' + ($missingInResp -join ',') }
}
Check 14 'shadow-triage response schema has all Amendment B.2 fields' $ok14 $detail14

# 15. Client-side shadow triage gating: confidence >= 0.85 AND evidence non-empty.
$ok15a = $false; $ok15b = $false
if ($regionSlice) {
    $ok15a = $regionSlice -match 'conf\s*>=\s*0\.85'
    $ok15b = $regionSlice -match 'payload\.evidence\s*\)\s*&&\s*payload\.evidence\.length\s*>\s*0'
}
Check 15 'client-side gate confidence>=0.85 AND evidence.length>0' ($ok15a -and $ok15b) "confGate=$ok15a evidenceGate=$ok15b"

# 16. Precedent citation in modtools.js carries no user-id leak.
# Scope: the citation-building block that constructs the ban message from the
# precedent count. Anchor on the call to workerCall('/precedent/find' and scan
# the next 60 lines -- that span is the CHUNK 8/9 citation block. Disallow
# authored_by/source_ref inside that block (user_id/username as bare words
# would still be allowed in parameter-name context elsewhere; we anchor on
# the two identifier-shaped column names that would leak).
$ok16 = $true
$ok16Detail = ''
$bad16 = @()
if ($modtoolsText) {
    for ($i = 0; $i -lt $modtoolsLines.Length; $i++) {
        if ($modtoolsLines[$i] -match "workerCall\(\s*'/precedent/find'") {
            $lo = $i
            $hi = [math]::Min($modtoolsLines.Length - 1, $i + 60)
            for ($j = $lo; $j -le $hi; $j++) {
                $line = $modtoolsLines[$j]
                $trim = $line.TrimStart()
                if ($trim.StartsWith('//')) { continue }
                # Leak indicators: authored_by concatenated into a string, or
                # p.user_id / p.username field access on a row variable, or
                # bare source_ref usage.
                if ($line -match '\bauthored_by\b|\bsource_ref\b|\.user_id\b|\.username\b') {
                    $bad16 += ("L" + ($j + 1))
                }
            }
        }
    }
    if ($bad16.Count -gt 0) {
        $ok16 = $false
        $ok16Detail = 'user-id fields inside citation block: ' + ($bad16 -join ',')
    } else {
        $ok16Detail = 'no authored_by/source_ref/.user_id/.username inside the /precedent/find consumption block'
    }
}
Check 16 'precedent citation: no authored_by/source_ref/user_id/username leak' $ok16 $ok16Detail

# 17. Worker v8.0 additions: SELECT FROM precedents returns aggregates only.
# Scope is the worker v8.0 region only -- the pre-existing v7.0 /precedent/find
# endpoint is a generic read-through endpoint and out of v8.0 scope. The v8.0
# additions (shadow-triage / next-best-action with ban_draft_with_precedent)
# MAY reference precedents but MUST do so via aggregate count only (or delegate
# to the client-side filter).
$ok17 = $true
$ok17Detail = ''
$bad17 = @()
if ($workerRegionSlice) {
    $workerRegionLinesArr = $workerRegionSlice -split "`n"
    for ($i = 0; $i -lt $workerRegionLinesArr.Length; $i++) {
        $line = $workerRegionLinesArr[$i]
        if ($line -match 'FROM\s+precedents' -and $line -notmatch '^\s*//') {
            $lo = [math]::Max(0, $i - 8)
            $selBlock = ($workerRegionLinesArr[$lo..$i] -join ' ')
            if ($selBlock -match 'SELECT[^;]*(authored_by|\buser_id\b|\busername\b)') {
                $bad17 += ("region L+" + ($i + 1))
            }
        }
    }
    if ($bad17.Count -gt 0) {
        $ok17 = $false
        $ok17Detail = 'precedents SELECT with user-id columns at: ' + ($bad17 -join ',')
    } else {
        $ok17Detail = 'no user-id columns in any SELECT ... FROM precedents inside v8.0 region'
    }
} else {
    $ok17Detail = 'worker v8.0 region empty'
}
Check 17 'worker v8.0 region: SELECT FROM precedents returns aggregates only' $ok17 $ok17Detail

# 18. Daily AI scan migration to ai_suspect_queue.
$ok18a = $false; $ok18b = $false
if ($modtoolsText) {
    $ok18a = $modtoolsText -match 'window\.__v80\.aiSuspect\.enqueue'
    # Legacy direct watchlist write must only appear in the flag-off else branch
    # adjacent to the __v80 enqueue call.
    $ok18b = $modtoolsText -match "v80AiSuspectOn"
}
Check 18 'daily AI scan routes to ai_suspect_queue when teamBoost on' ($ok18a -and $ok18b) "enqueueCall=$ok18a flagCheck=$ok18b"

# 19. Worker emits structured event logs for v8.0 endpoints.
$ok19 = $false
if ($workerText) { $ok19 = $workerText -match 'v80LogEvent\s*\(' }
Check 19 'worker emits v80LogEvent on v8.0 paths' $ok19

# 20. Worker cron purges shadow (7d) + resolved parked (30d).
$ok20a = $false; $ok20b = $false
if ($workerText) {
    $ok20a = $workerText -match "DELETE\s+FROM\s+shadow_triage_decisions"
    $ok20b = $workerText -match "DELETE\s+FROM\s+parked_items\s+WHERE\s+status='resolved'"
}
Check 20 'cron purges shadow_triage_decisions and resolved parked_items' ($ok20a -and $ok20b) "shadow=$ok20a parked=$ok20b"

# ---- GREP GATES (within v8.0 REGION of modtools.js) -----------------------

# 21. No new `new RegExp(` in v8.0 region (must go through compilePatternCached).
$ok21 = $true
$ok21Detail = ''
if ($regionSlice) {
    if ($regionSlice -match 'new\s+RegExp\s*\(') {
        $ok21 = $false
        $ok21Detail = 'new RegExp( inside v8.0 region (use compilePatternCached)'
    } else {
        $ok21Detail = 'no new RegExp( in v8.0 region'
    }
}
Check 21 'no new RegExp( in v8.0 region' $ok21 $ok21Detail

# 22. No innerHTML = ... template-literal in v8.0 region.
$ok22 = $true
$ok22Detail = ''
if ($regionSlice) {
    if ($regionSlice -match 'innerHTML\s*=\s*[^;]*\$\{') {
        $ok22 = $false
        $ok22Detail = 'innerHTML template-literal found in v8.0 region'
    } else {
        $ok22Detail = 'no innerHTML template-literal assignments in region'
    }
}
Check 22 'no innerHTML = ... ${} in v8.0 region' $ok22 $ok22Detail

# 23. No new setInterval( in v8.0 region (MasterHeartbeat is outside the region).
$ok23 = $true
$ok23Detail = ''
if ($regionSlice) {
    if ($regionSlice -match 'setInterval\s*\(') {
        $ok23 = $false
        $ok23Detail = 'setInterval( inside v8.0 region'
    } else {
        $ok23Detail = 'no setInterval( in v8.0 region'
    }
}
Check 23 'no raw setInterval( in v8.0 region' $ok23 $ok23Detail

# 24. No addEventListener('mouseover', ... without adjacent requestAnimationFrame.
$ok24 = $true
$ok24Detail = ''
if ($regionSlice) {
    $mm = [regex]::Matches($regionSlice, "addEventListener\(\s*['""]mouseover['""]")
    if ($mm.Count -gt 0) {
        # If any mouseover listener exists, require at least one rAF in the same region.
        if ($regionSlice -notmatch 'requestAnimationFrame\s*\(') {
            $ok24 = $false
            $ok24Detail = "mouseover listener(s) present but no rAF wrapper in region"
        } else {
            $ok24Detail = "mouseover listener(s) present; rAF usage confirmed in region"
        }
    } else {
        $ok24Detail = 'no mouseover listeners in region'
    }
}
Check 24 'no unthrottled mouseover listeners in v8.0 region' $ok24 $ok24Detail

# 25. Worker-side xAI calls in v8.0 region have adjacent budgetKey read.
$ok25 = $true
$ok25Detail = ''
if ($workerRegionSlice) {
    # Find each `api.x.ai` occurrence; for each, look 200 lines back for
    # `budgetKey` (budget key read + consumption are at function scope, not
    # necessarily adjacent to the fetch). Checking back to function entry is
    # sufficient because each v8.0 handler opens its own function scope.
    $workerRegionLines = $workerRegionSlice -split "`n"
    $bad25 = @()
    for ($i = 0; $i -lt $workerRegionLines.Length; $i++) {
        if ($workerRegionLines[$i] -match 'api\.x\.ai') {
            $lo = [math]::Max(0, $i - 200)
            $ctx = ($workerRegionLines[$lo..$i] -join "`n")
            if ($ctx -notmatch 'budgetKey') {
                $bad25 += ("L+" + ($i + 1))
            }
        }
    }
    if ($bad25.Count -gt 0) {
        $ok25 = $false
        $ok25Detail = 'xAI call without budgetKey context at region lines: ' + ($bad25 -join ',')
    } else {
        $ok25Detail = 'all xAI calls in v8.0 worker region preceded by budgetKey read'
    }
}
Check 25 'worker v8.0 region: xAI calls KV-budget gated' $ok25 $ok25Detail

# ---- BUILD / SYNTAX GATES -------------------------------------------------

# 26. node --check modtools.js.
$ok26 = $false; $detail26 = 'node not on PATH'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $out26 = & node --check $ModTools 2>&1
    if ($LASTEXITCODE -eq 0) { $ok26 = $true; $detail26 = 'node --check PASS' }
    else { $detail26 = 'node --check FAIL: ' + (($out26 | ForEach-Object { [string]$_ }) -join ' | ') }
}
Check 26 'node --check modtools.js' $ok26 $detail26

# 27. node --check gaw-mod-proxy-v2.js.
$ok27 = $false; $detail27 = 'node not on PATH'
if ($node) {
    $out27 = & node --check $WorkerJs 2>&1
    if ($LASTEXITCODE -eq 0) { $ok27 = $true; $detail27 = 'node --check PASS' }
    else { $detail27 = 'node --check FAIL: ' + (($out27 | ForEach-Object { [string]$_ }) -join ' | ') }
}
Check 27 'node --check gaw-mod-proxy-v2.js' $ok27 $detail27

# 28. CWS ZIP exists + under 220 KB compressed.
$ok28 = $false; $detail28 = ''
$DistDir = Join-Path $RepoRoot 'dist'
if (Test-Path $DistDir) {
    $zip = Get-ChildItem -Path $DistDir -Filter '*.zip' -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -match '8\.0\.0' } |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1
    if ($zip) {
        $kb = [math]::Round($zip.Length / 1024, 1)
        $ok28 = ($zip.Length -lt 220 * 1024)
        $detail28 = "$($zip.Name) ($kb KB)"
    } else {
        $detail28 = 'no v8.0.0 zip in dist/'
    }
} else {
    $detail28 = 'dist/ not found'
}
Check 28 'CWS ZIP present and under 220 KB' $ok28 $detail28

# ---- LIVE WORKER CHECKS (optional) ----------------------------------------

if ($LiveWorker) {
    $WorkerBase = 'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev'
    Say ''
    Say '-- live worker checks --'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    } catch {}

    function Probe {
        param([string]$path, [string]$method = 'POST')
        try {
            $u = $WorkerBase + $path
            if ($method -eq 'GET') {
                $resp = Invoke-WebRequest -Uri $u -Method GET -UseBasicParsing -ErrorAction Stop
            } else {
                $resp = Invoke-WebRequest -Uri $u -Method POST -Body '{}' -ContentType 'application/json' -UseBasicParsing -ErrorAction Stop
            }
            return @{ code = [int]$resp.StatusCode; body = [string]$resp.Content }
        } catch {
            $code = 0
            try { $code = [int]$_.Exception.Response.StatusCode } catch {}
            $body = ''
            try {
                $rs = $_.Exception.Response.GetResponseStream()
                if ($rs) {
                    $rdr = New-Object System.IO.StreamReader($rs)
                    $body = $rdr.ReadToEnd()
                }
            } catch {}
            return @{ code = $code; body = $body }
        }
    }

    # 29. /health -> 200
    $r29 = Probe '/health' 'GET'
    $ok29 = ($r29.code -eq 200)
    Check 29 "/health returns 200" $ok29 ("status=$($r29.code)")

    # 30. /features/team/read no-auth -> 401 (regression)
    $r30 = Probe '/features/team/read'
    $ok30 = ($r30.code -eq 401)
    Check 30 "/features/team/read rejects no-token (401)" $ok30 ("status=$($r30.code)")

    # 31. /ai/shadow-triage no-auth -> 401 OR 404 (404 if not yet deployed)
    $r31 = Probe '/ai/shadow-triage'
    $ok31 = ($r31.code -eq 401 -or $r31.code -eq 404)
    $d31 = "status=$($r31.code) (401=deployed+auth-gated; 404=pending deploy)"
    Check 31 "/ai/shadow-triage auth-gated or pending deploy" $ok31 $d31

    # 32. /parked/list no-auth -> 401 OR 404
    $r32 = Probe '/parked/list' 'GET'
    $ok32 = ($r32.code -eq 401 -or $r32.code -eq 404)
    $d32 = "status=$($r32.code) (401=deployed+auth-gated; 404=pending deploy)"
    Check 32 "/parked/list auth-gated or pending deploy" $ok32 $d32
}

# ---- Final report ----
$elapsed = [int]((Get-Date) - $t0).TotalSeconds
Say ''
Say '=============================================================='
Say 'SUMMARY'
Say '=============================================================='
Say ("  passed   : {0}" -f $pass) 'Green'
$failColor = 'Green'
if ($fail -gt 0) { $failColor = 'Red' }
Say ("  failed   : {0}" -f $fail) $failColor
Say ("  elapsed  : {0}s" -f $elapsed)
if ($fail -eq 0) {
    Say '  RESULT   : ALL STATIC CHECKS PASS' 'Green'
} else {
    Say '  RESULT   : FAILURES PRESENT' 'Red'
    foreach ($r in $results) {
        if (-not $r.ok) {
            Say ("    [{0:D2}] {1} -- {2}" -f $r.n, $r.name, $r.detail) 'Yellow'
        }
    }
}

# Log file.
$logDir = 'D:\AI\_PROJECTS\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logPath = Join-Path $logDir "verify-v8-0-$stamp.log"
try {
    $log | Out-File -FilePath $logPath -Encoding UTF8
    Say "  log file : $logPath"
} catch {}

# Clipboard.
try {
    $log -join "`n" | Set-Clipboard
    Say '[log copied to clipboard]' 'Green'
} catch {
    Say "clipboard copy failed: $_" 'Yellow'
}

# E-C-G beep.
try {
    [Console]::Beep(659, 160)
    Start-Sleep -Milliseconds 100
    [Console]::Beep(523, 160)
    Start-Sleep -Milliseconds 100
    [Console]::Beep(784, 800)
} catch {}

if (-not $NoPause) {
    Read-Host 'Press Enter to exit' | Out-Null
}

if ($fail -gt 0) { exit 2 } else { exit 0 }
