<div align="center">

# ccp

**Claude Code Provider CLI**

安全管理 Claude Code 第三方 API Key，DPAPI 加密存储。

`单文件` · `零依赖` · `DPAPI 加密` · `Windows 原生`

[English](README.md) · [中文](#功能)

</div>

---

## 为什么需要 ccp？

如果你用 Claude Code 接入第三方大模型 API（智谱、DeepSeek、阿里云等），你一定经历过：手动编辑 JSON、粘贴明文 Key、切换 Provider 全靠复制文件。

**ccp 解决这个问题：**

```
以前:  手动编辑 JSON → 粘贴明文 Key → 切换 = 复制文件 → Key 到处都是
现在:  ccp add zhipu → ccp switch zhipu → 搞定
```

### 竞品对比

| | ccp | claude-provider-switch | claudecode-switch |
|---|---|---|---|
| **Key 加密** | ✅ DPAPI (Windows 原生) | ❌ 明文存储 | ❌ 明文存储 |
| **文件权限** | ✅ 仅当前用户可读 | ❌ 未强制 | ❌ 未强制 |
| **单文件** | ✅ 无需编译/运行时 | ❌ 需要 Rust 编译 | ❌ Shell + wrapper |
| **连通性测试** | ✅ DNS → TCP → API | ❌ | ❌ |
| **内置预设** | ✅ 5 个常用 Provider | ❌ | ❌ |
| **非交互模式** | ✅ `--key --url` | ❌ | ❌ |

## 快速开始

```powershell
# 1. 一键安装
irm https://raw.githubusercontent.com/zhelunSun/ccp/main/ccp.ps1 | iex

# 2. 添加 Provider（只需输入名称 + Key）
ccp add zhipu

# 3. 切换并使用
ccp switch zhipu
claude
```

## 系统要求

- **Windows 10/11**
- **PowerShell 5.1+**（系统自带）
- **Claude Code CLI**

## 命令

| 命令 | 功能 |
|------|------|
| `ccp` | 显示帮助 |
| `ccp add {名称}` | 添加 Provider（交互式或 `--key --url`） |
| `ccp switch {名称}` | 切换当前 Provider |
| `ccp list` | 列出所有 Provider（高亮当前活跃） |
| `ccp test {名称}` | DNS → TCP → API 三层连通性测试 |
| `ccp remove {名称}` | 删除 Provider 配置 |
| `ccp migrate` | 加密已有的明文配置（一次性） |
| `ccp update` | 从 GitHub 自动更新 |

### 示例

```powershell
# 使用预设添加（只需输入 Key）
ccp add zhipu

# 完全非交互模式（适合脚本）
ccp add my-proxy --key sk-xxx --url https://api.example.com --model gpt-4

# 三层连通性测试
ccp test zhipu
# ✅ DNS: open.bigmodel.cn → 39.156.xx.xx
# ✅ TCP: port 443 connected (0.3s)
# ✅ API: /v1/models responded (200 OK)

# 切换 Provider
ccp switch deepseek
# ✅ Switched to deepseek
# 重新打开终端后执行: claude
```

## 内置预设

只需名称和 Key，URL 和模型自动填充：

| 预设名 | Provider | Base URL |
|--------|----------|----------|
| `anthropic` | Anthropic | `api.anthropic.com` |
| `zhipu` | 智谱 | `open.bigmodel.cn/api/anthropic` |
| `deepseek` | DeepSeek | `api.deepseek.com/anthropic` |
| `aliyun` | 阿里云 | `dashscope.aliyuncs.com` |
| `paratera` | Paratera | `llmapi.paratera.com` |

## 安全机制

Key 使用 **Windows DPAPI** 加密存储——和 Windows 凭据管理器使用相同的加密机制。只有当前 Windows 用户可以解密，无需第三方库，无明文文件。

| 属性 | 实现 |
|------|------|
| Key 输入 | `Read-Host -AsSecureString`（不回显） |
| 存储 | DPAPI 加密（当前用户范围） |
| 文件权限 | 仅当前用户可读（移除继承权限） |
| 内存安全 | `SecureString` → `BSTR` → `ZeroFreeBSTR` 清理 |
| 日志安全 | Key 永不出现在 stdout/stderr/日志文件 |

> **注意：** `settings.json` 包含明文 Key，因为 Claude Code 需要直接读取。该文件位于 `~/.claude/`，应确保仅当前用户可访问。

## 工作原理

```
~/.claude/profiles/zhipu.json     ← 加密配置（DPAPI blob）
~/.claude/settings.json           ← 活跃配置（Claude Code 读取此文件）

ccp switch zhipu
  1. 从配置文件解密 Key
  2. 读取现有 settings.json（保留 effortLevel、permissions 等）
  3. 仅更新 ANTHROPIC_* 环境变量
  4. 写回 settings.json
```

## 许可证

[Apache 2.0](LICENSE)

---

<div align="center">
Made with 🤖 by <a href="https://github.com/zhelunSun">zhelunSun</a> · 凌晨 1:00 由 Claude Code 自动开发
</div>
