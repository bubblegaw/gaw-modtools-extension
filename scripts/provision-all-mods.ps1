<#
.SYNOPSIS
    Batch-provision GAW ModTools tokens for an arbitrary number of mods.

.DESCRIPTION
    Loops: prompts for a GAW username, generates a 32-byte base64url token,
    registers it in the gaw-audit D1 mod_tokens table via wrangler, repeats
    until you type "done" or press Enter on an empty prompt.

    At the end:
      - Writes a pretty list of {username, token} to a text file.
      - Copies that same list to your clipboard (pocket reference).
      - Writes the FULL debug log to a separate log file.
      - E-C-G beep + Read-Host.

    Uses $env:CLOUDFLARE_API_TOKEN (already set on this machine) for wrangler
    auth. No interactive OAuth, no lead-token paste.

.PARAMETER NoPause
    Skip the final Read-Host. For scripted runs.

.NOTES
    Requires: PowerShell 5.1+ (works on powershell.exe and pwsh.exe).
    Requires: node.js + npx on PATH.
    Requires: $env:CLOUDFLARE_API_TOKEN set (user scope) with D1:Edit on
              account a2f2d0e4f0508cb93f3342b3e586b7bb.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File D:\AI\_PROJECTS\provision-all-mods.ps1
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$D1_NAME    = 'gaw-audit'
$WorkerUrl  = 'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev'
$ProjectDir = 'D:\AI\_PROJECTS\cloudflare-worker'
$LogsDir    = 'D:\AI\_PROJECTS\logs'

if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

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
    if ($s.Length -le 8) { return '(short ' + $s.Length + 'c)' }
    return $s.Substring(0,6) + '...' + $s.Substring($s.Length - 4)
}
function NewToken {
    $bytes = New-Object 'System.Byte[]' 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
}

$started = Get-Date

# per-mod results
$mods = New-Object System.Collections.Generic.List[object]

try {
    # --- Step 0: preflight ---------------------------------------------------
    SayHeader 'GAW ModTools -- Batch Mod Token Provisioning'
    Say "Started:  $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
    Say "PS:       $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Say "D1:       $D1_NAME"
    Say "Worker:   $WorkerUrl"
    Say ''

    if ([string]::IsNullOrWhiteSpace($env:CLOUDFLARE_API_TOKEN)) {
        Say 'ERROR: $env:CLOUDFLARE_API_TOKEN is not set.' Red
        Say 'Fix: close PowerShell, reopen, verify: $env:CLOUDFLARE_API_TOKEN' Red
        throw 'no CLOUDFLARE_API_TOKEN'
    }
    Say "CLOUDFLARE_API_TOKEN: $(Mask $env:CLOUDFLARE_API_TOKEN)" Green

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Say 'ERROR: node not found on PATH.' Red
        throw 'no node'
    }
    if (-not (Test-Path $ProjectDir)) {
        Say "ERROR: worker dir not found: $ProjectDir" Red
        throw 'worker dir missing'
    }

    Say ''
    Say 'HOW THIS WORKS:' DarkGray
    Say '  Enter a GAW username.         Token gets minted + saved to D1.' DarkGray
    Say '  Type "done" (or empty Enter)  Stop and print the summary.' DarkGray
    Say '  Duplicate usernames           Overwrite the old token (INSERT OR REPLACE).' DarkGray

    # --- Loop ----------------------------------------------------------------
    $n = 0
    while ($true) {
        SayHeader ("Mod " + ($n + 1))
        $user = Read-Host 'GAW username (or "done")'
        $user = ($user | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($user) -or $user -eq 'done' -or $user -eq 'quit' -or $user -eq 'exit') {
            Say 'Exiting loop.' DarkGray
            break
        }
        if ($user -notmatch '^[A-Za-z0-9_-]{2,64}$') {
            Say "  '$user' -> does not match [A-Za-z0-9_-]{2,64}. Skipping." Yellow
            continue
        }

        $tok = NewToken
        $now = [int64]((Get-Date) - (Get-Date '1970-01-01T00:00:00Z').ToUniversalTime()).TotalMilliseconds
        $isLead = 0
        $sql = "INSERT OR REPLACE INTO mod_tokens (token, mod_username, is_lead, created_at, last_used_at) VALUES ('$tok', '$user', $isLead, $now, NULL)"

        Say "  user:  $user" DarkGray
        Say "  token: $(Mask $tok) (len $($tok.Length))" DarkGray
        Say '  wrangler d1 execute ...' DarkGray

        Push-Location $ProjectDir
        $status = 'unknown'
        try {
            $out = & npx --yes wrangler@latest d1 execute $D1_NAME --remote --command=$sql 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Say "  wrangler exit $LASTEXITCODE" Red
                foreach ($line in ($out -split "`r?`n" | Select-Object -Last 8)) {
                    if ($line) { Say "    $line" DarkGray }
                }
                $status = "FAIL exit $LASTEXITCODE"
            } elseif ($out -match '"success"\s*:\s*true' -or $out -match 'Executed 1 command') {
                Say "  [OK] registered" Green
                $status = 'OK'
            } else {
                Say "  unexpected output (see log)" Yellow
                $status = 'unexpected'
                foreach ($line in ($out -split "`r?`n" | Select-Object -Last 6)) {
                    if ($line) { Say "    $line" DarkGray }
                }
            }
        } catch {
            Say "  EXCEPTION: $($_.Exception.Message)" Red
            $status = "EXC $($_.Exception.Message)"
        } finally {
            Pop-Location
        }

        $mods.Add([pscustomobject]@{
            Username = $user
            Token    = $tok
            Status   = $status
            At       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }) | Out-Null

        $n++
    }

    # --- Summary ------------------------------------------------------------
    SayHeader 'Summary'
    $ok    = ($mods | Where-Object { $_.Status -eq 'OK' }).Count
    $fail  = ($mods | Where-Object { $_.Status -ne 'OK' }).Count
    Say "Total attempted: $($mods.Count)"
    Say "Succeeded:       $ok" Green
    if ($fail -gt 0) { Say "Failed:          $fail" Red } else { Say "Failed:          0" DarkGray }
    Say ''

    if ($mods.Count -eq 0) {
        Say 'No mods provisioned. Exiting.' Yellow
    } else {
        # Build the pocket reference
        $pocket = New-Object System.Collections.Generic.List[string]
        $pocket.Add('GAW ModTools -- Mod Token Reference')       | Out-Null
        $pocket.Add("Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
        $pocket.Add("Worker:    $WorkerUrl")                     | Out-Null
        $pocket.Add('-' * 70)                                    | Out-Null
        $pocket.Add('')                                          | Out-Null
        foreach ($m in $mods) {
            $line = ('  ' + $m.Username.PadRight(24) + '  ' + $m.Token + '   [' + $m.Status + ']')
            $pocket.Add($line) | Out-Null
        }
        $pocket.Add('')                                          | Out-Null
        $pocket.Add('INSTRUCTIONS FOR EACH MOD:')                | Out-Null
        $pocket.Add('  1. Install the extension (v8.1.1 ZIP, load unpacked in Chrome dev mode).') | Out-Null
        $pocket.Add('  2. Open greatawakening.win; ModTools overlay will show the token modal.') | Out-Null
        $pocket.Add('  3. Paste your token above. Save.')        | Out-Null
        $pocket.Add('  4. You are authenticated.')               | Out-Null

        # Pretty print to console
        Say 'POCKET REFERENCE:' Yellow
        foreach ($line in $pocket) { Say $line }

        # Write text file
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $pocketFile = Join-Path $LogsDir ("mods-provisioned-$stamp.txt")
        $pocket -join "`r`n" | Set-Content -Path $pocketFile -Encoding UTF8
        Say ''
        Say "Pocket reference written to: $pocketFile" Green

        # Clipboard = pocket reference (Commander's explicit request on this script)
        try {
            $pocket -join "`r`n" | Set-Clipboard
            Say '[POCKET REFERENCE COPIED TO CLIPBOARD]' DarkGreen
        } catch {
            Say "(clipboard copy failed: $($_.Exception.Message))" DarkYellow
        }
    }
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

    # ALWAYS write full debug log to disk (separate from pocket reference)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $debugLog = Join-Path $LogsDir ("provision-batch-$stamp.log")
    $script:log -join "`r`n" | Set-Content -Path $debugLog -Encoding UTF8

    Say ''
    Say "Duration:        ${dur}s"
    Say "Full debug log:  $debugLog" DarkGray

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
