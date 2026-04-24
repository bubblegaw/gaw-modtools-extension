<#
.SYNOPSIS
    Tests the CLOUDFLARE_API_TOKEN environment variable against the Cloudflare API
    and confirms wrangler can use it to reach D1, Workers, and KV.
.NOTES
    Requires: PowerShell 5.1+ (works on both powershell.exe and pwsh.exe)
    Node.js with npx available on PATH for the wrangler smoke test.
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# --- log buffer -------------------------------------------------------------
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

$started = Get-Date
$results = @{
    envVarFound       = $false
    tokenValid        = $false
    accountsFound     = 0
    d1Accessible      = $false
    workersAccessible = $false
    kvAccessible      = $false
    wranglerWorks     = $false
    errors            = New-Object System.Collections.Generic.List[string]
}

try {
    SayHeader 'Cloudflare API Token Smoke Test'
    Say "Started: $($started.ToString('yyyy-MM-dd HH:mm:ss'))"

    # --- Step 1: env var presence --------------------------------------------
    SayHeader 'Step 1: Environment variable check'
    $tok = $env:CLOUDFLARE_API_TOKEN
    if ([string]::IsNullOrWhiteSpace($tok)) {
        Say '  CLOUDFLARE_API_TOKEN: BLANK' Red
        $results.errors.Add('CLOUDFLARE_API_TOKEN is not set. Run SetEnvironmentVariable and restart PowerShell.')
        throw 'CLOUDFLARE_API_TOKEN not set'
    }
    $results.envVarFound = $true
    $masked = if ($tok.Length -gt 8) { $tok.Substring(0, 4) + '...' + $tok.Substring($tok.Length - 4) } else { '(short)' }
    Say "  CLOUDFLARE_API_TOKEN: present ($masked, $($tok.Length) chars)" Green

    $tok2 = $env:CF_API_TOKEN
    if (-not [string]::IsNullOrWhiteSpace($tok2)) {
        if ($tok2 -eq $tok) {
            Say '  CF_API_TOKEN: same as CLOUDFLARE_API_TOKEN (OK)' DarkGray
        } else {
            Say '  CF_API_TOKEN: DIFFERENT value (informational only; wrangler uses CLOUDFLARE_API_TOKEN first)' Yellow
        }
    }

    # --- Step 2: token verify endpoint ---------------------------------------
    SayHeader 'Step 2: Cloudflare /user/tokens/verify'
    $headers = @{ 'Authorization' = "Bearer $tok"; 'Content-Type' = 'application/json' }
    try {
        $verify = Invoke-RestMethod -Uri 'https://api.cloudflare.com/client/v4/user/tokens/verify' -Headers $headers -Method GET
        if ($verify.success -eq $true -and $verify.result.status -eq 'active') {
            Say "  Token status: ACTIVE" Green
            Say "  Token id:     $($verify.result.id)" DarkGray
            if ($verify.result.expires_on) {
                Say "  Expires:      $($verify.result.expires_on)" Yellow
            } else {
                Say "  Expires:      never" Green
            }
            $results.tokenValid = $true
        } else {
            Say "  Token verify returned unexpected payload." Red
            Say "  Raw: $(ConvertTo-Json $verify -Depth 3 -Compress)" DarkGray
            $results.errors.Add("Token verify non-success: $(ConvertTo-Json $verify -Compress)")
        }
    } catch {
        Say "  Token verify FAILED: $($_.Exception.Message)" Red
        $results.errors.Add("Token verify: $($_.Exception.Message)")
        throw
    }

    # --- Step 3: list accounts ----------------------------------------------
    SayHeader 'Step 3: Cloudflare /accounts'
    try {
        $accts = Invoke-RestMethod -Uri 'https://api.cloudflare.com/client/v4/accounts' -Headers $headers -Method GET
        if ($accts.success -eq $true) {
            $results.accountsFound = $accts.result.Count
            Say "  Accounts visible: $($accts.result.Count)" Green
            foreach ($a in $accts.result) {
                Say "    - $($a.name)  [id: $($a.id)]" DarkGray
            }
            if ($accts.result.Count -gt 0) {
                $script:accountId = $accts.result[0].id
            }
        } else {
            Say "  Accounts list non-success." Red
            $results.errors.Add('Accounts list non-success')
        }
    } catch {
        Say "  Accounts list FAILED: $($_.Exception.Message)" Red
        $results.errors.Add("Accounts list: $($_.Exception.Message)")
    }

    if (-not $script:accountId) {
        Say '  No account id available; skipping D1/Workers/KV checks.' Yellow
    } else {
        # --- Step 4: D1 databases ---------------------------------------------
        SayHeader 'Step 4: D1 databases (Account:D1:Edit)'
        try {
            $d1 = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$($script:accountId)/d1/database" -Headers $headers -Method GET
            if ($d1.success -eq $true) {
                $results.d1Accessible = $true
                Say "  D1 databases: $($d1.result.Count)" Green
                foreach ($db in $d1.result) {
                    Say "    - $($db.name)  [id: $($db.uuid)]" DarkGray
                }
            } else {
                Say "  D1 list non-success." Red
                $results.errors.Add('D1 list non-success')
            }
        } catch {
            Say "  D1 list FAILED: $($_.Exception.Message)" Red
            $results.errors.Add("D1: $($_.Exception.Message)")
        }

        # --- Step 5: Workers scripts -----------------------------------------
        SayHeader 'Step 5: Workers scripts (Account:Workers Scripts:Edit)'
        try {
            $wk = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$($script:accountId)/workers/scripts" -Headers $headers -Method GET
            if ($wk.success -eq $true) {
                $results.workersAccessible = $true
                Say "  Worker scripts: $($wk.result.Count)" Green
                foreach ($s in $wk.result) {
                    Say "    - $($s.id)" DarkGray
                }
            } else {
                Say "  Workers list non-success." Red
                $results.errors.Add('Workers list non-success')
            }
        } catch {
            Say "  Workers list FAILED: $($_.Exception.Message)" Red
            $results.errors.Add("Workers: $($_.Exception.Message)")
        }

        # --- Step 6: KV namespaces -------------------------------------------
        SayHeader 'Step 6: KV namespaces (Account:Workers KV:Edit)'
        try {
            $kv = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$($script:accountId)/storage/kv/namespaces" -Headers $headers -Method GET
            if ($kv.success -eq $true) {
                $results.kvAccessible = $true
                Say "  KV namespaces: $($kv.result.Count)" Green
                foreach ($n in $kv.result) {
                    Say "    - $($n.title)  [id: $($n.id)]" DarkGray
                }
            } else {
                Say "  KV list non-success." Red
                $results.errors.Add('KV list non-success')
            }
        } catch {
            Say "  KV list FAILED: $($_.Exception.Message)" Red
            $results.errors.Add("KV: $($_.Exception.Message)")
        }
    }

    # --- Step 7: wrangler smoke ---------------------------------------------
    SayHeader 'Step 7: wrangler whoami (via npx)'
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Say '  node not found on PATH; skipping wrangler smoke test.' Yellow
    } else {
        try {
            $raw = & npx --yes wrangler@latest whoami 2>&1
            $out = ($raw | Out-String).Trim()
            Say $out DarkGray
            if ($LASTEXITCODE -eq 0 -and $out -match '(?i)logged in|authenticated|associated|getting user info') {
                $results.wranglerWorks = $true
                Say '  wrangler whoami: SUCCESS' Green
            } else {
                Say "  wrangler whoami exited with code $LASTEXITCODE" Red
                $results.errors.Add("wrangler whoami exit $LASTEXITCODE")
            }
        } catch {
            Say "  wrangler whoami FAILED: $($_.Exception.Message)" Red
            $results.errors.Add("wrangler: $($_.Exception.Message)")
        }
    }
}
catch {
    Say ''
    Say "FATAL: $($_.Exception.Message)" Red
}
finally {
    $ended = Get-Date
    $dur = [int]($ended - $started).TotalSeconds

    SayHeader 'Final Report'
    Say "Duration: ${dur}s"
    Say "  env var found:        $($results.envVarFound)"
    Say "  token valid:          $($results.tokenValid)"
    Say "  accounts visible:     $($results.accountsFound)"
    Say "  D1 accessible:        $($results.d1Accessible)"
    Say "  Workers accessible:   $($results.workersAccessible)"
    Say "  KV accessible:        $($results.kvAccessible)"
    Say "  wrangler works:       $($results.wranglerWorks)"
    Say ''
    if ($results.errors.Count -gt 0) {
        Say 'Errors:' Red
        $i = 0
        foreach ($e in $results.errors) {
            $i++
            Say "  [$i] $e" Red
        }
    } else {
        Say 'No errors. Token is ready for publish-and-test-v8.ps1.' Green
    }

    # persist log
    $logDir = 'D:\AI\_PROJECTS\logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir ("test-cf-token-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    $script:log -join "`r`n" | Set-Content -Path $logFile -Encoding UTF8
    Say ''
    Say "log saved to: $logFile" DarkGray

    # clipboard
    try {
        $script:log -join "`r`n" | Set-Clipboard
        Say '[log copied to clipboard]' DarkGreen
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
