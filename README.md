<div align="center">

# ccp

**Claude Code Provider CLI** — switch API keys, encrypted at rest.

`27 KB` · `1 file` · `DPAPI` · `PowerShell 5.1`

[中文](README_CN.md)

</div>

---

## the problem

You use Claude Code with a third-party API provider. Every time you switch, you're hand-editing `~/.claude/settings.json` and pasting keys in plaintext. Your API key sits there, readable by anything running under your user account.

ccp wraps this into six commands. Keys are encrypted with Windows DPAPI before they touch disk.

```
# before
notepad ~/.claude/settings.json     # paste key, hope for the best

# after
ccp add openrouter                  # encrypted at rest
ccp switch openrouter               # update settings.json safely
```

## when to use ccp (and when not to)

ccp is a 27 KB PowerShell script. It does one thing: manage API keys for Claude Code on Windows, with encryption.

**If you need** a cross-platform desktop app, provider health monitoring, MCP management, session history, cost tracking, or proxy support — use [CC Switch](https://github.com/farion1231/cc-switch). It's excellent and has 96k stars for good reason.

**If you want** a single file you can read in 30 seconds, that encrypts keys with the same mechanism as Windows Credential Manager, and runs on any Windows machine with zero setup — ccp.

| | ccp | CC Switch | switch-claude-cli | claudecode-switch |
|---|---|---|---|---|
| Key encryption | DPAPI | SQLite (local) | plaintext JSON | plaintext |
| File size | 27 KB | ~100 MB | ~10 MB (npm) | ~5 KB (bash) |
| Dependencies | none (PS 5.1) | Tauri + Rust + React | Node.js 18+ | bash + Node |
| Install | `irm ... \| iex` | .msi installer | `npm i -g` | shell script |
| Cross-platform | Windows only | Win / Mac / Linux | Win / Mac / Linux | Mac / Linux |
| What it manages | Claude Code | 7 tools, MCP, sessions | Claude Code | Claude Code |
| Connectivity test | DNS → TCP → API | built-in proxy | health check | — |

ccp trades scope for simplicity. That's the tradeoff.

## quick start

```powershell
# install (one line)
irm https://raw.githubusercontent.com/zhelunSun/ccp/main/ccp.ps1 | iex

# add a provider
ccp add zhipu

# switch and launch
ccp switch zhipu
claude
```

## commands

| Command | What it does |
|---------|-------------|
| `ccp add {name}` | Add provider (interactive or `--key --url`) |
| `ccp switch {name}` | Set active provider |
| `ccp list` | Show all providers |
| `ccp test {name}` | DNS → TCP → API connectivity check |
| `ccp remove {name}` | Delete a provider |
| `ccp migrate` | Encrypt existing plaintext profiles |
| `ccp update` | Self-update from GitHub |

### examples

```powershell
# interactive — asks for key (masked input)
ccp add openrouter

# non-interactive — for scripts
ccp add my-proxy --key sk-xxx --url https://api.example.com --model gpt-4

# three-tier connectivity test
ccp test zhipu
# DNS: open.bigmodel.cn → 39.156.xx.xx
# TCP: port 443 connected (0.3s)
# API: /v1/models → 200 OK

# switch provider
ccp switch deepseek
```

## built-in presets

Add these with just a name and key. URL and default model are pre-filled.

| Preset | Provider | Base URL |
|--------|----------|----------|
| `anthropic` | Anthropic (official) | `api.anthropic.com` |
| `openrouter` | OpenRouter | `openrouter.ai/api/v1` |
| `zhipu` | Zhipu (智谱) | `open.bigmodel.cn/api/anthropic` |
| `deepseek` | DeepSeek | `api.deepseek.com/anthropic` |
| `aliyun` | Aliyun (阿里云) | `dashscope.aliyuncs.com` |
| `paratera` | Paratera | `llmapi.paratera.com` |

Want to add Groq, Together AI, or another provider? Use the non-interactive mode:

```powershell
ccp add groq --url https://api.groq.com/openai/v1 --key gsk_xxx
```

## security

This is the part ccp actually cares about.

Keys are encrypted with **Windows DPAPI** — the same system that backs Windows Credential Manager. The encryption is tied to your Windows user account. No third-party crypto libraries, no plaintext files in your home directory, no keys in environment variables.

| Layer | How it works |
|-------|-------------|
| Input | `Read-Host -AsSecureString` — key never visible on screen |
| Storage | DPAPI via `ConvertFrom-SecureString`, user scope |
| File ACL | Inherited permissions stripped, current-user-only |
| Memory | `SecureString` → `BSTR` → `ZeroFreeBSTR` after use |
| Logging | Keys never appear in stdout, stderr, or log files |

The active `settings.json` in `~/.claude/` does contain a plaintext key — Claude Code reads it directly. This file should be user-private (ccp sets the ACL, but verify on your machine).

## requirements

- Windows 10 / 11
- PowerShell 5.1+ (ships with Windows)
- Claude Code CLI

## how it works

```
~/.claude/profiles/zhipu.json      encrypted profile (DPAPI blob)
~/.claude/settings.json            active config (Claude Code reads this)

ccp switch zhipu
  1. decrypt key from profile
  2. read existing settings.json (keep effortLevel, permissions, etc.)
  3. overwrite ANTHROPIC_* fields only
  4. write back
```

## profile format

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

## license

[Apache 2.0](LICENSE)

---

<div align="center">

built by [zhelunSun](https://github.com/zhelunSun) · single file, no fuss

</div>
