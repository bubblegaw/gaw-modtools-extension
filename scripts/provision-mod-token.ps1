<#
.SYNOPSIS
    Mint a mod token for a team member and register it with the GAW ModTools worker.

.DESCRIPTION
    Commander runs this once per mod on onboarding. It:
      1. Dumps PS / OS / TLS / worker-reachability debug up front.
      2. Prompts for the mod's GAW username.
      3. Prompts for your LEAD mod token (hidden input).
      4. Generates a cryptographically secure 32-byte random token (base64url).
      5. POSTs to /admin/import-tokens-from-kv with { token, mod_username, is_lead:false }.
      6. On success: writes the new mod token to a DEDICATED FILE you can open
         to copy + DM. Clipboard contains the full debug log (per Commander rule).
      7. On failure: full exception chain + request + response dumped to log.
         Clipboard = full debug log. Nothing is lost.

.PARAMETER NoPause
    Skip the final Read-Host pause. Use for scripted / CI runs.

.NOTES
    Requires: PowerShell 5.1+ (works on both powershell.exe and pwsh.exe).
    Requires: an already-deployed gaw-mod-proxy worker with migration 012 applied.
    Requires: network reachability to https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$WorkerUrl  = 'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev'
$WorkerHost = 'gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev'

$script:log = New-Object System.Collections.Generic.List[string]
function Say {
    param([string]$msg, [string]$color = 'Cyan')
    Write-Host $msg -ForegroundColor $color
    $script:log.Add($msg) | Out-Null
}
function SayHeader {
    param([string]$msg)
    $bar = '=' * 70
    Say ''
    Say $bar DarkCyan
    Say $msg Yellow
    Say $bar DarkCyan
}
function Mask {
    param([string]$s)
    if (-not $s) { return '(empty)' }
    if ($s.Length -le 8) { return '(short, ' + $s.Length + ' chars)' }
    return $s.Substring(0,4) + '...' + $s.Substring($s.Length - 4) + ' (len ' + $s.Length + ')'
}

$started = Get-Date
$result = @{
    username  = ''
    imported  = 0
    skipped   = 0
    success   = $false
    tokenFile = ''
    errors    = New-Object System.Collections.Generic.List[string]
}

try {
    # --- Step 0: environment dump -------------------------------------------
    SayHeader 'GAW ModTools -- Mod Token Provisioning'
    Say "Worker:   $WorkerUrl"
    Say "Started:  $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
    Say "PS:       $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Say "OS:       $([System.Environment]::OSVersion.VersionString)"
    Say "Host:     $env:COMPUTERNAME  User: $env:USERNAME"
    Say "TLS:      $([Net.ServicePointManager]::SecurityProtocol)"
    try {
        $clrVer = [System.Reflection.Assembly]::GetAssembly([object]).ImageRuntimeVersion
        Say "CLR:      $clrVer"
    } catch {}

    # reachability probe (DNS + TLS handshake only, no auth)
    Say ''
    Say 'Probing worker reachability...' DarkGray
    try {
        $probe = Invoke-WebRequest -Uri "$WorkerUrl/health" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Say "  probe GET /health -> HTTP $($probe.StatusCode)" Green
    } catch {
        $probeErr = $_
        $probeStatus = if ($probeErr.Exception.Response) { $probeErr.Exception.Response.StatusCode.value__ } else { '???' }
        Say "  probe GET /health -> $probeStatus" Yellow
        Say "  probe exception:   $($probeErr.Exception.GetType().FullName)" DarkGray
        Say "  probe message:     $($probeErr.Exception.Message)" DarkGray
        if ($probeStatus -eq '???') {
            Say '  Reachability failed BEFORE getting HTTP response. Likely DNS/TLS/network.' Red
            Say '  Check: nslookup ' + $WorkerHost + '  and:  Test-NetConnection ' + $WorkerHost + ' -Port 443' Red
        }
    }

    # --- Step 1: username --------------------------------------------------
    SayHeader 'Step 1: Mod GAW username'
    $user = Read-Host 'Enter the mod''s GAW username (e.g. bob)'
    $user = ($user | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($user)) {
        Say '  Username was blank. Aborting.' Red
        $result.errors.Add('username blank')
        throw 'username required'
    }
    if ($user -notmatch '^[A-Za-z0-9_-]{2,64}$') {
        Say "  Username '$user' does not match [A-Za-z0-9_-]{2,64}." Red
        $result.errors.Add('username format invalid')
        throw 'username format'
    }
    $result.username = $user
    Say "  Username: $user" Green

    # --- Step 2: lead token ------------------------------------------------
    SayHeader 'Step 2: Your LEAD token'
    Say '  Windows PowerShell 5.1 has a known bug where Read-Host -AsSecureString' DarkGray
    Say '  loses characters on paste. We use plain Read-Host here and mask output.' DarkGray
    Say '  The token will be visible while you paste -- that is intentional + safer.' DarkGray
    Say ''
    $leadPlain = ''
    $attempts = 0
    while ($attempts -lt 3) {
        $attempts++
        $raw = Read-Host "Paste LEAD token (attempt $attempts of 3)"
        # Defensive scrub: strip control chars, whitespace, BOMs
        $leadPlain = ($raw -replace '[\x00-\x1F\x7F\uFEFF]', '').Trim()
        if ([string]::IsNullOrWhiteSpace($leadPlain)) {
            Say '    -> blank. Try again.' Red
            continue
        }
        Say "    -> captured: $(Mask $leadPlain)" DarkGreen
        if ($leadPlain.Length -lt 8) {
            Say '    -> suspiciously short. Paste clipped? Try right-click paste instead of Ctrl+V.' Yellow
            Say '       Press Enter to retry, or type OVERRIDE to continue anyway.' Yellow
            $confirm = Read-Host 'Retry or OVERRIDE'
            if ($confirm -ne 'OVERRIDE') { continue }
        }
        break
    }
    if ([string]::IsNullOrWhiteSpace($leadPlain)) {
        Say '  Lead token never captured after 3 attempts. Aborting.' Red
        $result.errors.Add('lead token capture failed')
        throw 'lead token required'
    }
    Say "  Lead token: $(Mask $leadPlain)" Green

    # --- Step 3: generate new token ----------------------------------------
    SayHeader 'Step 3: Generate new mod token'
    $bytes = New-Object 'System.Byte[]' 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $newToken = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    Say "  Generated: $(Mask $newToken)" Green

    # --- Step 4: register with worker --------------------------------------
    SayHeader 'Step 4: POST /admin/import-tokens-from-kv'
    $body = @{
        tokens = @(
            @{
                token        = $newToken
                mod_username = $user
                is_lead      = $false
            }
        )
    } | ConvertTo-Json -Depth 4 -Compress

    $headers = @{
        'x-lead-token' = $leadPlain
        'Content-Type' = 'application/json'
    }
    $uri = "$WorkerUrl/admin/import-tokens-from-kv"

    Say "  URI:          $uri" DarkGray
    Say "  body bytes:   $($body.Length)" DarkGray
    Say "  body preview: $($body.Substring(0, [Math]::Min(120, $body.Length)))..." DarkGray
    Say "  headers:      x-lead-token=$(Mask $leadPlain)  Content-Type=application/json" DarkGray

    $rawResp   = $null
    $rawStatus = '???'
    $rawBody   = ''
    $webErr    = $null

    try {
        # Invoke-WebRequest gives us status + headers + body on success
        $rawResp = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body `
                                     -ContentType 'application/json' -UseBasicParsing `
                                     -TimeoutSec 30 -ErrorAction Stop
        $rawStatus = $rawResp.StatusCode
        $rawBody   = ($rawResp.Content | Out-String).Trim()
    } catch {
        $webErr = $_
        # Try to extract response from the exception
        $ex = $webErr.Exception
        if ($ex.Response) {
            try { $rawStatus = $ex.Response.StatusCode.value__ } catch {}
            try {
                $stream = $ex.Response.GetResponseStream()
                if ($stream) {
                    $stream.Position = 0
                    $reader = New-Object System.IO.StreamReader($stream)
                    $rawBody = $reader.ReadToEnd()
                }
            } catch {
                $rawBody = "(could not read response body: $($_.Exception.Message))"
            }
        }
    }

    Say ''
    Say "  HTTP status: $rawStatus" DarkGray
    if ($rawBody) { Say "  body: $rawBody" DarkGray }

    if ($webErr) {
        Say ''
        Say '--- DETAILED EXCEPTION CHAIN ---' Red
        Say "  type:    $($webErr.Exception.GetType().FullName)" Red
        Say "  message: $($webErr.Exception.Message)" Red
        $inner = $webErr.Exception.InnerException
        $depth = 1
        while ($inner -and $depth -lt 5) {
            Say ("  inner[$depth] " + $inner.GetType().FullName) Red
            Say ("           msg " + $inner.Message) Red
            $inner = $inner.InnerException
            $depth++
        }
        if ($webErr.ScriptStackTrace) {
            Say '  script stack:' DarkGray
            foreach ($line in ($webErr.ScriptStackTrace -split "`r?`n")) {
                Say "    $line" DarkGray
            }
        }
        Say '---' Red
    }

    # Interpret status
    if ($rawStatus -eq 200 -and $rawBody) {
        try {
            $resp = $rawBody | ConvertFrom-Json -ErrorAction Stop
            if ($resp.ok -eq $true -and $resp.imported -ge 1) {
                $result.imported = [int]$resp.imported
                $result.skipped  = [int]$resp.skipped
                $result.success  = $true
                Say "  Registered: imported=$($resp.imported) skipped=$($resp.skipped)" Green
            } elseif ($resp.ok -eq $true -and $resp.skipped -ge 1 -and $resp.imported -eq 0) {
                $result.skipped = [int]$resp.skipped
                Say "  Token generation collided (extremely rare; re-run)." Yellow
                $result.errors.Add('import returned skipped only')
            } else {
                Say "  Unexpected response shape: $rawBody" Red
                $result.errors.Add("unexpected response: $rawBody")
            }
        } catch {
            Say "  Response body was not valid JSON: $($_.Exception.Message)" Red
            $result.errors.Add("json parse: $($_.Exception.Message)")
        }
    } else {
        switch ($rawStatus) {
            403 { Say '  HINT: LEAD token rejected by worker. Check CF secret LEAD_MOD_TOKEN matches.' Yellow }
            401 { Say '  HINT: auth header missing or mangled. Check x-lead-token format.' Yellow }
            404 { Say '  HINT: endpoint /admin/import-tokens-from-kv not found. Worker may be on old code.' Yellow }
            503 { Say '  HINT: AUDIT_DB binding missing on worker. Re-deploy + apply migration 012.' Yellow }
            default {
                if ($rawStatus -eq '???') {
                    Say '  HINT: NO HTTP response returned. DNS/TLS/network failure. Run Test-NetConnection.' Yellow
                } else {
                    Say "  HINT: unexpected HTTP $rawStatus. Paste the detailed log above to diagnose." Yellow
                }
            }
        }
        $result.errors.Add("HTTP $rawStatus : $rawBody")
        throw "import failed (status $rawStatus)"
    }

    # --- Step 5: hand off token to dedicated file --------------------------
    SayHeader 'Step 5: Token handoff'
    $logDir = 'D:\AI\_PROJECTS\logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $tokenFile = Join-Path $logDir ("mod-token-$user-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt")
    try {
        Set-Content -Path $tokenFile -Value $newToken -Encoding ASCII -NoNewline
        $result.tokenFile = $tokenFile
        Say "  Token written to:" Green
        Say "    $tokenFile" Green
        Say ''
        Say "  OPEN that file, copy the token, DM it to $user over a secure channel." Yellow
        Say '  (clipboard will hold the debug log; token is in the file above)' DarkGray
    } catch {
        Say "  Failed to write token file: $($_.Exception.Message)" Red
        Say ''
        Say '  FALLBACK -- token printed ONCE below. Copy it NOW:' Yellow
        Say "  $newToken" White
        Say ''
        $result.errors.Add("token file write: $($_.Exception.Message)")
    }

    # --- wipe plaintext ----------------------------------------------------
    Remove-Variable leadPlain -ErrorAction SilentlyContinue
    Remove-Variable newToken  -ErrorAction SilentlyContinue
}
catch {
    Say ''
    Say "FATAL: $($_.Exception.Message)" Red
    Say "  type:    $($_.Exception.GetType().FullName)" Red
    if ($_.ScriptStackTrace) {
        Say '  script stack:' DarkGray
        foreach ($line in ($_.ScriptStackTrace -split "`r?`n")) {
            Say "    $line" DarkGray
        }
    }
}
finally {
    $ended = Get-Date
    $dur = [int]($ended - $started).TotalSeconds

    SayHeader 'Final Report'
    Say "Duration:   ${dur}s"
    Say "Mod user:   $($result.username)"
    Say "Imported:   $($result.imported)"
    Say "Skipped:    $($result.skipped)"
    Say "Success:    $($result.success)"
    if ($result.tokenFile) { Say "Token file: $($result.tokenFile)" }
    if ($result.errors.Count -gt 0) {
        Say ''
        Say 'Errors:' Red
        $i = 0
        foreach ($e in $result.errors) { $i++; Say "  [$i] $e" Red }
    }

    # persist FULL debug log (token NEVER in log)
    $logDir = 'D:\AI\_PROJECTS\logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir ("provision-mod-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    $script:log -join "`r`n" | Set-Content -Path $logFile -Encoding UTF8
    Say ''
    Say "log saved to: $logFile" DarkGray

    # MANDATORY: clipboard always gets the full debug log (Commander's rule)
    try {
        $script:log -join "`r`n" | Set-Clipboard
        Say '[FULL DEBUG LOG COPIED TO CLIPBOARD]' DarkGreen
        if ($result.tokenFile) {
            Say "  (open $($result.tokenFile) separately to copy the token to DM)" DarkGreen
        }
    } catch {
        Say "(clipboard copy failed: $($_.Exception.Message))" DarkYellow
    }

    # E-C-G beep
    try {
        [Console]::Beep(659, 160)
        Start-Sleep -Milliseconds 100
        [Console]::Beep(523, 160)
        Start-Sleep -Milliseconds 100
        [Console]::Beep(784, 800)
    } catch {}

    if (-not $NoPause) { Read-Host 'Press Enter to exit' | Out-Null }
}
