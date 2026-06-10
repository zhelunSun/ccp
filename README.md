<div align="center">

# ccp

**Claude Code Provider CLI**

Secure, encrypted API key management for Claude Code.

`Single file` · `Zero deps` · `DPAPI encrypted` · `Windows`

[English](#features) · [中文](README_CN.md)

</div>

---

## Why ccp?

If you use Claude Code with third-party LLM providers (Zhipu, DeepSeek, Aliyun, etc.), you're managing API keys by hand — editing JSON files, pasting keys in plaintext, hoping nothing leaks.

**ccp fixes this:**

```
Before:  Edit JSON → paste plaintext key → switch = copy files → key sprawl
After:   ccp add zhipu → ccp switch zhipu → done
```

### What makes it different

| | ccp | claude-provider-switch | claudecode-switch |
|---|---|---|---|
| **Key encryption** | ✅ DPAPI (Windows native) | ❌ Plaintext | ❌ Plaintext |
| **File permissions** | ✅ User-only ACL | ❌ Not enforced | ❌ Not enforced |
| **Single file** | ✅ 1 file, no runtime deps | ❌ Rust build required | ❌ Shell + wrapper |
| **Connectivity test** | ✅ DNS → TCP → API | ❌ | ❌ |
| **Preset providers** | ✅ 5 built-in | ❌ | ❌ |
| **Non-interactive mode** | ✅ `--key --url` | ❌ | ❌ |
| **Windows native** | ✅ PowerShell 5.1 | ❌ Rust/cargo | ❌ Bash only |

## Quick Start

```powershell
# 1. Download (one-liner)
irm https://raw.githubusercontent.com/zhelunSun/ccp/main/ccp.ps1 | iex

# 2. Add your provider (2 prompts: name + key)
ccp add zhipu

# 3. Switch and go
ccp switch zhipu
claude
```

## Requirements

- **Windows 10/11**
- **PowerShell 5.1+** (pre-installed)
- **Claude Code CLI**

## Commands

| Command | What it does |
|---------|-------------|
| `ccp` | Show help |
| `ccp add {slug}` | Add provider (interactive or `--key --url`) |
| `ccp switch {slug}` | Switch active provider |
| `ccp list` | Show all providers (active highlighted) |
| `ccp test {slug}` | DNS → TCP → API connectivity check |
| `ccp remove {slug}` | Delete a provider profile |
| `ccp migrate` | Encrypt existing plaintext profiles |
| `ccp update` | Self-update from GitHub |

### Examples

```powershell
# Add with preset (only asks for key)
ccp add zhipu

# Add fully non-interactive
ccp add my-proxy --key sk-xxx --url https://api.example.com --model gpt-4

# Three-tier connectivity test
ccp test zhipu
# ✅ DNS: open.bigmodel.cn → 39.156.xx.xx
# ✅ TCP: port 443 connected (0.3s)
# ✅ API: /v1/models responded (200 OK)

# Switch provider
ccp switch deepseek
# ✅ Switched to deepseek
# Restart terminal, then: claude
```

## Built-in Presets

Add any of these with just a name and key — URL and models are auto-filled:

| Preset | Provider | Base URL |
|--------|----------|----------|
| `anthropic` | Anthropic | `api.anthropic.com` |
| `zhipu` | Zhipu (智谱) | `open.bigmodel.cn/api/anthropic` |
| `deepseek` | DeepSeek | `api.deepseek.com/anthropic` |
| `aliyun` | Aliyun (阿里云) | `dashscope.aliyuncs.com` |
| `paratera` | Paratera | `llmapi.paratera.com` |

## Security

Keys are encrypted at rest using **Windows DPAPI** — the same encryption used by Windows Credential Manager. Only your Windows user account can decrypt them. No third-party libraries, no secrets in environment variables, no plaintext files.

| Property | Implementation |
|----------|---------------|
| Key input | `Read-Host -AsSecureString` (masked) |
| Storage | DPAPI (`ConvertFrom-SecureString`), user-scope |
| File ACL | Current-user-only (inherited permissions removed) |
| Memory | `SecureString` → `BSTR` → `ZeroFreeBSTR` cleanup |
| Logging | Keys never written to stdout/stderr/log files |

> **Note:** `settings.json` contains the plaintext key because Claude Code reads it directly. This file is in `~/.claude/` which should be user-private.

## How it works

```
~/.claude/profiles/zhipu.json     ← Encrypted profile (DPAPI blob)
~/.claude/settings.json           ← Active config (Claude Code reads this)

ccp switch zhipu
  1. Decrypt key from profile
  2. Read existing settings.json (preserve effortLevel, permissions, etc.)
  3. Update ANTHROPIC_* env vars only
  4. Write back settings.json
```

## Profile format

```json
{
  "slug": "zhipu",
  "provider": "Zhipu",
  "added_at": "2026-06-10",
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "01000000d08c9ddf... (DPAPI encrypted)",
    "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.1"
  }
}
```

## License

[Apache 2.0](LICENSE)

---

<div align="center">
Made with 🤖 by <a href="https://github.com/zhelunSun">zhelunSun</a> · Auto-developed by Claude Code at 1:00 AM
</div>
