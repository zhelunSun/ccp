<div align="center">

# ccp

**Claude Code Provider CLI** — 切换 API Key，磁盘上加密存储。

`27 KB` · `单文件` · `DPAPI 加密` · `PowerShell 5.1`

[English](README.md)

</div>

---

## 这个问题

用 Claude Code 接第三方 API 的人都有过这个经历：每次切换 Provider 要手动改 `~/.claude/settings.json`，把 Key 明文贴进去。Key 就这么躺在磁盘上，同一用户下任何程序都能读。

ccp 把这件事收拢成六个命令。Key 在写入磁盘前会用 Windows DPAPI 加密。

```
# 以前
notepad ~/.claude/settings.json     # 粘贴 key，祈祷别泄露

# 现在
ccp add openrouter                  # 加密存储
ccp switch openrouter               # 安全更新 settings.json
```

## 什么时候用 ccp（什么时候不用）

ccp 是一个 27 KB 的 PowerShell 脚本。它只做一件事：在 Windows 上用加密方式管理 Claude Code 的 API Key。

**如果你需要** 跨平台桌面应用、Provider 健康监控、MCP 管理、会话历史、费用统计、代理转发 — 用 [CC Switch](https://github.com/farion1231/cc-switch)。它很好，96k stars 不是白来的。

**如果你想要** 一个 30 秒就能读完源码的单文件、用和 Windows 凭据管理器同一种加密方式保护 Key、在任何 Windows 机器上零配置运行 — ccp。

| | ccp | CC Switch | switch-claude-cli | claudecode-switch |
|---|---|---|---|---|
| Key 加密 | DPAPI | SQLite (本地) | 明文 JSON | 明文 |
| 体积 | 27 KB | ~100 MB | ~10 MB (npm) | ~5 KB (bash) |
| 依赖 | 无 (PS 5.1) | Tauri + Rust + React | Node.js 18+ | bash + Node |
| 安装 | `irm ... \| iex` | .msi 安装包 | `npm i -g` | shell script |
| 跨平台 | 仅 Windows | Win / Mac / Linux | Win / Mac / Linux | Mac / Linux |
| 管理范围 | Claude Code | 7 个工具, MCP, 会话 | Claude Code | Claude Code |
| 连通性测试 | DNS → TCP → API | 内置代理 | 健康检查 | 无 |

ccp 用功能范围换简洁。这是取舍，不是缺陷。

## 快速开始

```powershell
# 一行安装
irm https://raw.githubusercontent.com/zhelunSun/ccp/main/ccp.ps1 | iex

# 添加 Provider
ccp add openrouter

# 切换并启动
ccp switch openrouter
claude
```

## 命令

| 命令 | 功能 |
|------|------|
| `ccp add {name}` | 添加 Provider（交互式或 `--key --url`） |
| `ccp switch {name}` | 切换当前 Provider |
| `ccp list` | 列出所有 Provider |
| `ccp test {name}` | DNS → TCP → API 三层连通性测试 |
| `ccp remove {name}` | 删除 Provider |
| `ccp migrate` | 加密已有的明文配置 |
| `ccp update` | 从 GitHub 自更新 |

### 示例

```powershell
# 交互式 — 输入 key（不回显）
ccp add openrouter

# 非交互式 — 适合脚本
ccp add my-proxy --key sk-xxx --url https://api.example.com --model gpt-4

# 三层连通性测试
ccp test zhipu
# DNS: open.bigmodel.cn → 39.156.xx.xx
# TCP: port 443 connected (0.3s)
# API: /v1/models → 200 OK

# 切换 Provider
ccp switch deepseek
```

## 内置预设

只需名称和 Key，URL 和默认模型自动填充：

| 预设名 | Provider | Base URL |
|--------|----------|----------|
| `anthropic` | Anthropic (官方) | `api.anthropic.com` |
| `openrouter` | OpenRouter | `openrouter.ai/api/v1` |
| `zhipu` | 智谱 | `open.bigmodel.cn/api/anthropic` |
| `deepseek` | DeepSeek | `api.deepseek.com/anthropic` |
| `aliyun` | 阿里云 | `dashscope.aliyuncs.com` |
| `paratera` | Paratera | `llmapi.paratera.com` |

想加 Groq、Together AI 或其他 Provider？用非交互模式：

```powershell
ccp add groq --url https://api.groq.com/openai/v1 --key gsk_xxx
```

## 安全

这是 ccp 真正在意的事。

Key 用 **Windows DPAPI** 加密 — 和 Windows 凭据管理器用的是同一套加密。加密绑定到你的 Windows 用户账户。没有第三方加密库，没有明文文件，没有环境变量里的 Key。

| 层 | 实现 |
|----|------|
| 输入 | `Read-Host -AsSecureString` — 屏幕上不显示 key |
| 存储 | DPAPI（`ConvertFrom-SecureString`），用户范围 |
| 文件 ACL | 移除继承权限，仅当前用户可读 |
| 内存 | `SecureString` → `BSTR` → 使用后 `ZeroFreeBSTR` |
| 日志 | Key 不出现在 stdout、stderr 或日志文件中 |

活跃的 `settings.json`（`~/.claude/` 下）确实包含明文 Key — 因为 Claude Code 直接读这个文件。ccp 设置了 ACL，但请在你的机器上确认权限正确。

## 系统要求

- Windows 10 / 11
- PowerShell 5.1+（系统自带）
- Claude Code CLI

## 工作原理

```
~/.claude/profiles/zhipu.json      加密配置（DPAPI blob）
~/.claude/settings.json            活跃配置（Claude Code 读这个）

ccp switch zhipu
  1. 从配置文件解密 Key
  2. 读取现有 settings.json（保留 effortLevel、permissions 等）
  3. 只覆写 ANTHROPIC_* 字段
  4. 写回
```

## 配置格式

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

## 许可证

[Apache 2.0](LICENSE)

---

<div align="center">

by [zhelunSun](https://github.com/zhelunSun) · 单文件，不折腾

</div>
