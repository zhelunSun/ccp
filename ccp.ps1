#!/usr/bin/env pwsh
<#
.SYNOPSIS
  ccp - Claude Code Provider CLI (v1.0.0)
  Secure API key management for Claude Code with DPAPI encryption.

.DESCRIPTION
  Manages LLM provider profiles for Claude Code.
  Keys are encrypted at rest with Windows DPAPI (current-user scope).
  Only the ANTHROPIC_AUTH_TOKEN field is encrypted; URLs and models are plaintext.

.LINK
  https://github.com/zhelunsun/ccp
#>

# --- constants ---------------------------------------------------------
$script:Version     = "1.0.0"
$script:ProfileDir  = Join-Path (Join-Path $env:USERPROFILE ".claude") "profiles"
$script:SettingsFile = Join-Path (Join-Path $env:USERPROFILE ".claude") "settings.json"
$script:EncryptedKeyField = "ANTHROPIC_AUTH_TOKEN"

# --- preset table ------------------------------------------------------
$script:Presets = @{
    anthropic = @{
        Provider = "Anthropic"
        BaseUrl  = "https://api.anthropic.com"
        Sonnet   = "claude-sonnet-4-20250514"
        Opus     = "claude-opus-4-20250514"
        Haiku    = "claude-haiku-4-5-20251001"
    }
    zhipu = @{
        Provider = "Zhipu"
        BaseUrl  = "https://open.bigmodel.cn/api/anthropic"
        Sonnet   = "glm-5.1"
        Opus     = "glm-5.1"
        Haiku    = "glm-4.5-air"
    }
    deepseek = @{
        Provider = "DeepSeek"
        BaseUrl  = "https://api.deepseek.com/anthropic"
        Sonnet   = "deepseek-chat"
        Opus     = "deepseek-chat"
        Haiku    = "deepseek-chat"
    }
    aliyun = @{
        Provider = "Aliyun"
        BaseUrl  = "https://dashscope.aliyuncs.com/compatible-mode/anthropic"
        Sonnet   = "qwen-max"
        Opus     = "qwen-max"
        Haiku    = "qwen-turbo"
    }
    paratera = @{
        Provider = "Paratera"
        BaseUrl  = "https://llmapi.paratera.com"
        Sonnet   = "claude-sonnet-4-20250514"
        Opus     = "claude-sonnet-4-20250514"
        Haiku    = "claude-sonnet-4-20250514"
    }
}

# --- helpers -----------------------------------------------------------

function Get-ActiveSlug {
    if (-not (Test-Path $script:SettingsFile)) { return $null }
    try {
        $settings = Get-Content $script:SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $settingsUrl = $settings.env.ANTHROPIC_BASE_URL
        if (-not $settingsUrl) { return $null }
        foreach ($f in (Get-ChildItem $script:ProfileDir -Filter "*.json")) {
            try {
                $p = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($p.env.ANTHROPIC_BASE_URL -eq $settingsUrl -and
                    $p.env.ANTHROPIC_DEFAULT_SONNET_MODEL -eq $settings.env.ANTHROPIC_DEFAULT_SONNET_MODEL) {
                    return $f.BaseName
                }
            } catch { continue }
        }
    } catch { return $null }
    return $null
}

function ConvertTo-DpapiBlob {
    param([string]$PlainText)
    $ss = ConvertTo-SecureString $PlainText -AsPlainText -Force
    $encrypted = $ss | ConvertFrom-SecureString
    return $encrypted
}

function ConvertFrom-DpapiBlob {
    param([string]$EncryptedBlob)
    try {
        $ss = ConvertTo-SecureString $EncryptedBlob
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        return $plain
    } catch {
        return $null
    }
}

function Test-IsEncrypted {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return $false }
    try {
        $null = ConvertTo-SecureString $Value -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-ProfileApiKey {
    param([hashtable]$Profile)
    $token = $Profile.env.($script:EncryptedKeyField)
    if ([string]::IsNullOrEmpty($token)) { return $null }
    if (Test-IsEncrypted $token) {
        return ConvertFrom-DpapiBlob $token
    }
    return $token
}

function Set-ProfileAcl {
    param([string]$FilePath)
    try {
        $acl = Get-Acl $FilePath -ErrorAction Stop
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "Allow"
        )
        $acl.SetAccessRuleProtection($true, $false)
        $acl.AddAccessRule($rule)
        Set-Acl -Path $FilePath -AclObject $acl -ErrorAction Stop
    } catch {
        Write-Verbose "ACL set skipped: $_"
    }
}

function Read-SecureKey {
    param([string]$Prompt = "API Key")
    $secureKey = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    return $plain
}

function Get-Slug {
    param([string]$Name)
    return (($Name -replace '[^a-zA-Z0-9_-]', '-').ToLower())
}

function Ensure-ProfileDir {
    if (-not (Test-Path $script:ProfileDir)) {
        New-Item -ItemType Directory -Path $script:ProfileDir -Force | Out-Null
    }
}

# --- commands ----------------------------------------------------------

function Show-Help {
    Write-Host ""
    Write-Host "  ccp v$script:Version - Claude Code Provider CLI" -ForegroundColor Cyan
    Write-Host "  Secure API key management with DPAPI encryption" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Commands:" -ForegroundColor Yellow
    Write-Host "    ccp add    {slug} [--preset name] [--key k] [--url u] [--model m]"
    Write-Host "    ccp switch {slug}"
    Write-Host "    ccp list"
    Write-Host "    ccp remove {slug} [--force]"
    Write-Host "    ccp test   {slug}"
    Write-Host "    ccp update"
    Write-Host "    ccp migrate"
    Write-Host "    ccp help"
    Write-Host ""
    Write-Host "  Presets:" -ForegroundColor Yellow
    foreach ($key in ($script:Presets.Keys | Sort-Object)) {
        $p = $script:Presets[$key]
        $line = "    {0,-12} {1,-30} {2}" -f $key, $p.BaseUrl, $p.Sonnet
        Write-Host $line -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  Examples:" -ForegroundColor Yellow
    Write-Host "    ccp add zhipu                        # interactive, auto-fill from preset"
    Write-Host "    ccp add my-api --key sk-xxx --url https://api.example.com"
    Write-Host "    ccp add --preset deepseek            # only asks for key"
    Write-Host "    ccp switch zhipu                     # switch active provider"
    Write-Host "    ccp list                             # show all profiles"
    Write-Host ""
}

function Invoke-Add {
    param(
        [string]$Slug,
        [string]$Preset,
        [string]$Key,
        [string]$Url,
        [string]$Model,
        [string]$OpusModel,
        [string]$HaikuModel,
        [string]$ProviderName
    )

    Ensure-ProfileDir

    # -- resolve slug --
    if (-not $Slug -and -not $Preset) {
        $Slug = Read-Host -Prompt "  Provider slug (e.g. zhipu, deepseek, or custom name)"
    }
    if (-not $Slug -and $Preset) {
        $Slug = $Preset
    }
    if (-not $Slug) {
        Write-Host "  [ERROR] 名称不能为空" -ForegroundColor Red
        return
    }
    $Slug = Get-Slug $Slug

    # -- resolve preset --
    $presetData = $null
    if ($Preset -and $script:Presets.ContainsKey($Preset)) {
        $presetData = $script:Presets[$Preset]
    } elseif ($script:Presets.ContainsKey($Slug)) {
        $presetData = $script:Presets[$Slug]
    }

    # -- resolve provider name --
    if (-not $ProviderName) {
        if ($presetData) {
            $ProviderName = $presetData.Provider
        } else {
            $ProviderName = (Get-Culture).TextInfo.ToTitleCase($Slug)
        }
    }

    # -- resolve API key --
    if (-not $Key) {
        Write-Host ""
        Write-Host "  [1] API Key" -ForegroundColor Yellow
        if ($presetData) {
            Write-Host "  Provider: $ProviderName ($($presetData.BaseUrl))" -ForegroundColor Gray
        }
        Write-Host "  输入你的 API Key (不回显):" -ForegroundColor Gray
        $Key = Read-SecureKey "  API Key"
        if (-not $Key) {
            Write-Host "  [ERROR] Key 不能为空" -ForegroundColor Red
            return
        }
    }

    # -- resolve base URL --
    if (-not $Url) {
        if ($presetData) {
            $Url = $presetData.BaseUrl
        } else {
            Write-Host ""
            Write-Host "  [2] Base URL" -ForegroundColor Yellow
            Write-Host "  示例: https://api.anthropic.com, https://open.bigmodel.cn/api/anthropic" -ForegroundColor Gray
            $Url = Read-Host -Prompt "  Base URL"
        }
    }
    if (-not $Url) {
        Write-Host "  [ERROR] URL 不能为空" -ForegroundColor Red
        return
    }

    # -- resolve models --
    if (-not $Model) {
        if ($presetData) {
            $Model = $presetData.Sonnet
            if (-not $OpusModel) { $OpusModel = $presetData.Opus }
            if (-not $HaikuModel) { $HaikuModel = $presetData.Haiku }
        } else {
            Write-Host ""
            Write-Host "  [3] Default Model (Sonnet)" -ForegroundColor Yellow
            $Model = Read-Host -Prompt "  Sonnet model"
        }
    }
    if (-not $Model) {
        Write-Host "  [ERROR] Model 不能为空" -ForegroundColor Red
        return
    }
    if (-not $OpusModel) { $OpusModel = $Model }
    if (-not $HaikuModel) { $HaikuModel = $Model }

    # -- encrypt key --
    $encryptedKey = ConvertTo-DpapiBlob $Key

    # -- build profile --
    $profile = [ordered]@{
        slug     = $Slug
        provider = $ProviderName
        added_at = (Get-Date -Format "yyyy-MM-dd")
        env      = [ordered]@{
            ANTHROPIC_AUTH_TOKEN           = $encryptedKey
            ANTHROPIC_BASE_URL             = $Url
            ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
            ANTHROPIC_DEFAULT_OPUS_MODEL   = $OpusModel
            ANTHROPIC_DEFAULT_HAIKU_MODEL  = $HaikuModel
            API_TIMEOUT_MS                 = "3000000"
        }
    }

    # -- check overwrite --
    $profilePath = Join-Path $script:ProfileDir "$Slug.json"
    if (Test-Path $profilePath) {
        $over = Read-Host -Prompt "  Profile '$Slug' 已存在，覆盖? (y/n)"
        if ($over -ne 'y' -and $over -ne 'Y') {
            Write-Host "  已取消" -ForegroundColor Yellow
            return
        }
    }

    # -- write --
    $profile | ConvertTo-Json -Depth 3 | Set-Content -Path $profilePath -Encoding UTF8
    Set-ProfileAcl $profilePath

    Write-Host ""
    Write-Host "  OK Provider '$Slug' added!" -ForegroundColor Green
    Write-Host "     Model: $Model" -ForegroundColor Gray
    Write-Host "     URL:   $Url" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Switch with: ccp switch $Slug" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-List {
    Ensure-ProfileDir

    $activeSlug = Get-ActiveSlug
    $profiles = @(Get-ChildItem $script:ProfileDir -Filter "*.json")

    if ($profiles.Count -eq 0) {
        Write-Host ""
        Write-Host "  暂无 Provider。使用 ccp add 添加。" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    Write-Host ""
    $header = "  {0,-18} {1,-12} {2,-24} {3,-36} {4}" -f "Slug", "Provider", "Sonnet Model", "Base URL", "Active"
    Write-Host $header -ForegroundColor Cyan
    $sep = "  {0,-18} {1,-12} {2,-24} {3,-36} {4}" -f ("-" * 16), ("-" * 10), ("-" * 22), ("-" * 34), ("-" * 6)
    Write-Host $sep -ForegroundColor DarkGray

    foreach ($f in ($profiles | Sort-Object Name)) {
        try {
            $p = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $slug = if ($p.slug) { $p.slug } else { $f.BaseName }
            $provider = if ($p.provider) { $p.provider } else { $slug }
            $model = $p.env.ANTHROPIC_DEFAULT_SONNET_MODEL
            $url = $p.env.ANTHROPIC_BASE_URL
            $isActive = ($slug -eq $activeSlug)

            $displayUrl = $url
            if ($displayUrl.Length -gt 36) { $displayUrl = $displayUrl.Substring(0, 33) + "..." }

            $line = "  {0,-18} {1,-12} {2,-24} {3,-36}" -f $slug, $provider, $model, $displayUrl
            if ($isActive) {
                Write-Host $line -ForegroundColor Green -NoNewline
                Write-Host "  * active" -ForegroundColor Green
            } else {
                Write-Host $line -ForegroundColor White
            }
        } catch {
            Write-Host "  $($f.BaseName)  (parse error)" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "  Total: $($profiles.Count) profiles" -ForegroundColor Gray
    Write-Host ""
}

function Invoke-Switch {
    param([string]$Slug)

    if (-not $Slug) {
        Write-Host ""
        Write-Host "  Usage: ccp switch {slug}" -ForegroundColor Yellow
        Write-Host ""
        Invoke-List
        return
    }

    $Slug = Get-Slug $Slug
    $profilePath = Join-Path $script:ProfileDir "$Slug.json"

    if (-not (Test-Path $profilePath)) {
        Write-Host ""
        Write-Host "  [ERROR] Profile '$Slug' does not exist" -ForegroundColor Red
        Write-Host "  Use ccp list to see available profiles" -ForegroundColor Gray
        return
    }

    # Load profile
    $profile = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Decrypt key
    $plainKey = Get-ProfileApiKey @{ env = $profile.env }
    if (-not $plainKey) {
        Write-Host "  [ERROR] Cannot decrypt API key. Re-add this profile." -ForegroundColor Red
        return
    }

    # Build settings.json - preserve non-env fields from existing settings
    $output = [ordered]@{}

    if (Test-Path $script:SettingsFile) {
        try {
            $existing = Get-Content $script:SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $existing.PSObject.Properties) {
                if ($prop.Name -ne "env") {
                    $output[$prop.Name] = $prop.Value
                }
            }
        } catch { }
    }

    # Build env block from profile
    $envBlock = [ordered]@{
        ANTHROPIC_AUTH_TOKEN           = $plainKey
        ANTHROPIC_BASE_URL             = $profile.env.ANTHROPIC_BASE_URL
        ANTHROPIC_DEFAULT_SONNET_MODEL = $profile.env.ANTHROPIC_DEFAULT_SONNET_MODEL
        ANTHROPIC_DEFAULT_OPUS_MODEL   = $profile.env.ANTHROPIC_DEFAULT_OPUS_MODEL
        ANTHROPIC_DEFAULT_HAIKU_MODEL  = $profile.env.ANTHROPIC_DEFAULT_HAIKU_MODEL
        API_TIMEOUT_MS                 = "3000000"
    }

    # Preserve extra env vars from existing settings (e.g. ENABLE_TOOL_SEARCH)
    if (Test-Path $script:SettingsFile) {
        try {
            $existing = Get-Content $script:SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $coreEnvKeys = @(
                "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
                "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL",
                "ANTHROPIC_DEFAULT_HAIKU_MODEL", "API_TIMEOUT_MS"
            )
            if ($existing.env) {
                foreach ($prop in $existing.env.PSObject.Properties) {
                    if ($prop.Name -notin $coreEnvKeys) {
                        $envBlock[$prop.Name] = $prop.Value
                    }
                }
            }
        } catch { }
    }

    $output["env"] = $envBlock

    $output | ConvertTo-Json -Depth 5 | Set-Content -Path $script:SettingsFile -Encoding UTF8

    Write-Host ""
    Write-Host "  OK Switched to '$Slug'" -ForegroundColor Green
    $modelStr = $profile.env.ANTHROPIC_DEFAULT_SONNET_MODEL
    $urlStr = $profile.env.ANTHROPIC_BASE_URL
    Write-Host "     Model: $modelStr" -ForegroundColor Gray
    Write-Host "     URL:   $urlStr" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Restart terminal and run: claude" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-Remove {
    param(
        [string]$Slug,
        [switch]$Force
    )

    if (-not $Slug) {
        Write-Host ""
        Write-Host "  Usage: ccp remove {slug}" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    $Slug = Get-Slug $Slug
    $profilePath = Join-Path $script:ProfileDir "$Slug.json"

    if (-not (Test-Path $profilePath)) {
        Write-Host ""
        Write-Host "  [ERROR] Profile '$Slug' does not exist" -ForegroundColor Red
        return
    }

    if (-not $Force) {
        $confirm = Read-Host -Prompt "  Confirm delete '$Slug'? (y/n)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "  Cancelled." -ForegroundColor Yellow
            return
        }
    }

    Remove-Item $profilePath -Force
    Write-Host ""
    Write-Host "  OK Profile '$Slug' deleted." -ForegroundColor Green
    Write-Host ""
}

function Invoke-Test {
    param([string]$Slug)

    if (-not $Slug) {
        Write-Host ""
        Write-Host "  Usage: ccp test {slug}" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    $Slug = Get-Slug $Slug
    $profilePath = Join-Path $script:ProfileDir "$Slug.json"

    if (-not (Test-Path $profilePath)) {
        Write-Host ""
        Write-Host "  [ERROR] Profile '$Slug' does not exist" -ForegroundColor Red
        return
    }

    $profile = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $baseUrl = $profile.env.ANTHROPIC_BASE_URL
    Write-Host ""
    Write-Host "  Testing '$Slug' -> $baseUrl" -ForegroundColor Cyan

    # Try to parse URL
    try {
        $uri = [System.Uri]$baseUrl
    } catch {
        Write-Host "  [FAIL] Invalid URL: $baseUrl" -ForegroundColor Red
        return
    }

    # Tier 1: DNS resolve
    $dnsOk = $false
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($uri.Host)
        $dnsOk = $true
        $dnsIp = $resolved[0].IPAddressToString
        $hostStr = $uri.Host
        Write-Host "  [DNS]  OK $hostStr -> $dnsIp" -ForegroundColor Green
    } catch {
        $hostStr = $uri.Host
        Write-Host "  [DNS]  FAIL Cannot resolve $hostStr" -ForegroundColor Red
    }

    # Tier 2: TCP connect
    $tcpOk = $false
    if ($dnsOk) {
        $port = if ($uri.Port -gt 0) { $uri.Port } else { 443 }
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $asyncResult = $tcp.BeginConnect($uri.Host, $port, $null, $null)
            $waited = $asyncResult.AsyncWaitHandle.WaitOne(3000, $false)
            if ($waited -and $tcp.Connected) {
                $tcpOk = $true
                $tcpMsg = "  [TCP]  OK $($uri.Host):$port" -replace ':', ' port '
                Write-Host "  [TCP]  OK connected to $($uri.Host) port $port" -ForegroundColor Green
            } else {
                Write-Host "  [TCP]  FAIL timeout connecting to $($uri.Host) port $port" -ForegroundColor Red
            }
            $tcp.Close()
        } catch {
            $errMsg = $_.Exception.Message
            Write-Host "  [TCP]  FAIL $errMsg" -ForegroundColor Red
        }
    }

    # Tier 3: Optional API probe
    if ($tcpOk) {
        $plainKey = Get-ProfileApiKey @{ env = $profile.env }
        try {
            $headers = @{
                "x-api-key" = $plainKey
                "anthropic-version" = "2023-06-01"
                "Content-Type" = "application/json"
            }

            $ProgressPreference = 'SilentlyContinue'
            $null = Invoke-RestMethod -Uri "$baseUrl/v1/models" -Headers $headers -Method Get -TimeoutSec 3 -ErrorAction Stop
            Write-Host "  [API]  OK API endpoint responded" -ForegroundColor Green
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($statusCode -eq 401 -or $statusCode -eq 403) {
                Write-Host "  [API]  WARN Endpoint reachable, auth failed (HTTP $statusCode)" -ForegroundColor Yellow
            } elseif ($statusCode -eq 404) {
                Write-Host "  [API]  WARN No /v1/models endpoint, connectivity OK" -ForegroundColor Yellow
            } else {
                $errMsg = $_.Exception.Message
                Write-Host "  [API]  WARN Cannot verify API: $errMsg" -ForegroundColor Yellow
            }
        }
    }

    # Summary
    Write-Host ""
    if ($dnsOk -and $tcpOk) {
        Write-Host "  Result: Basic connectivity OK" -ForegroundColor Green
    } else {
        Write-Host "  Result: Connectivity test FAILED" -ForegroundColor Red
    }
    Write-Host ""
}

function Invoke-Update {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.PSCommandPath
    }

    Write-Host ""
    Write-Host "  ccp v$script:Version" -ForegroundColor Cyan
    Write-Host ""

    # TODO: replace with actual GitHub raw URL once repo is created
    $updateUrl = "https://raw.githubusercontent.com/zhelunsun/ccp/main/ccp.ps1"

    Write-Host "  Checking for updates..." -ForegroundColor Yellow
    try {
        $ProgressPreference = 'SilentlyContinue'
        $latest = Invoke-RestMethod -Uri $updateUrl -TimeoutSec 5 -ErrorAction Stop
        if ($latest -match '\$script:Version\s*=\s*"([^"]+)"') {
            $latestVersion = $Matches[1]
            if ($latestVersion -eq $script:Version) {
                Write-Host "  Already up to date (v$script:Version)" -ForegroundColor Green
                return
            }
            Write-Host "  New version available: v$latestVersion (current: v$script:Version)" -ForegroundColor Yellow
            $latest | Set-Content -Path $scriptPath -Encoding UTF8
            Write-Host "  OK Updated to v$latestVersion" -ForegroundColor Green
        } else {
            Write-Host "  WARN Downloaded content is not a valid ccp script" -ForegroundColor Red
        }
    } catch {
        Write-Host "  WARN Cannot check for updates (repo may not exist yet)" -ForegroundColor Yellow
        Write-Host "  Manual update: download from $updateUrl" -ForegroundColor Gray
    }
    Write-Host ""
}

function Invoke-Migrate {
    Ensure-ProfileDir

    $profiles = @(Get-ChildItem $script:ProfileDir -Filter "*.json")

    $migrated = 0
    foreach ($f in $profiles) {
        try {
            $p = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

            # Skip if already migrated (has slug field = v2 format)
            if ($p.slug) { continue }

            $token = $p.env.ANTHROPIC_AUTH_TOKEN
            if (-not $token) { continue }

            # Skip if already encrypted
            if (Test-IsEncrypted $token) { continue }

            # Encrypt the key
            $encryptedKey = ConvertTo-DpapiBlob $token

            # Build new format
            $slug = $f.BaseName
            $providerName = $slug
            foreach ($presetKey in $script:Presets.Keys) {
                if ($slug -like "$presetKey*") {
                    $providerName = $script:Presets[$presetKey].Provider
                    break
                }
            }

            $newProfile = [ordered]@{
                slug     = $slug
                provider = $providerName
                added_at = "2026-06-10"
                env      = $p.env
            }
            $newProfile.env.ANTHROPIC_AUTH_TOKEN = $encryptedKey

            # Write back
            $newProfile | ConvertTo-Json -Depth 3 | Set-Content -Path $f.FullName -Encoding UTF8
            Set-ProfileAcl $f.FullName

            Write-Host "  OK Migrated: $slug -> DPAPI encrypted" -ForegroundColor Green
            $migrated++
        } catch {
            $name = $f.BaseName
            $errMsg = $_.Exception.Message
            Write-Host "  WARN Migration failed: $name - $errMsg" -ForegroundColor Red
        }
    }

    if ($migrated -eq 0) {
        Write-Host "  All profiles already encrypted, nothing to migrate." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  Migrated $migrated profiles." -ForegroundColor Cyan
    }
}

# --- main router -------------------------------------------------------

function Main {
    param(
        [Parameter(Position=0)]
        [string]$Command,

        [Parameter(Position=1)]
        [string]$Arg1,

        [string]$Preset,
        [string]$Key,
        [string]$Url,
        [string]$Model,
        [string]$OpusModel,
        [string]$HaikuModel,
        [string]$Provider,
        [switch]$Force,
        [switch]$Help
    )

    if ($Help -or -not $Command) {
        Show-Help
        return
    }

    switch ($Command.ToLower()) {
        "add" {
            Invoke-Add -Slug $Arg1 -Preset $Preset -Key $Key -Url $Url -Model $Model `
                       -OpusModel $OpusModel -HaikuModel $HaikuModel -ProviderName $Provider
        }
        "switch"   { Invoke-Switch $Arg1 }
        "list"     { Invoke-List }
        "remove"   { Invoke-Remove -Slug $Arg1 -Force:$Force }
        "test"     { Invoke-Test $Arg1 }
        "update"   { Invoke-Update }
        "help"     { Show-Help }
        "migrate"  { Invoke-Migrate }
        default {
            Write-Host ""
            Write-Host "  [ERROR] Unknown command: $Command" -ForegroundColor Red
            Write-Host "  Run ccp help for usage." -ForegroundColor Gray
            Write-Host ""
        }
    }
}

# --- entry point -------------------------------------------------------
# Parse all args manually for flexible flag handling
if ($MyInvocation.InvocationName -ne '.') {
    $cmdArgs = @($args)

    # Simple arg parser
    $posArgs = @()
    $namedArgs = @{}
    $switchArgs = @{}
    $i = 0
    while ($i -lt $cmdArgs.Count) {
        $arg = $cmdArgs[$i]
        if ($arg -match '^--(\w+)') {
            $flagName = $Matches[1]
            $flagName = $flagName.Substring(0,1).ToUpper() + $flagName.Substring(1)
            # Check if next arg is a value (not another flag)
            if ($i + 1 -lt $cmdArgs.Count -and $cmdArgs[$i+1] -notmatch '^--') {
                $namedArgs[$flagName] = $cmdArgs[$i+1]
                $i += 2
            } else {
                $switchArgs[$flagName] = $true
                $i++
            }
        } elseif ($arg -match '^-(\w)') {
            $flagName = $Matches[1].ToUpper()
            $switchArgs[$flagName] = $true
            $i++
        } else {
            $posArgs += $arg
            $i++
        }
    }

    $command = if ($posArgs.Count -gt 0) { $posArgs[0] } else { "" }
    $arg1 = if ($posArgs.Count -gt 1) { $posArgs[1] } else { "" }

    # Map short flags
    if ($switchArgs.ContainsKey("F")) { $switchArgs["Force"] = $true }
    if ($switchArgs.ContainsKey("H")) { $switchArgs["Help"] = $true }

    Main -Command $command -Arg1 $arg1 @namedArgs @switchArgs
}
