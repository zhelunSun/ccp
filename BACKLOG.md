# ccp — Backlog

Future features considered but cut from v1.0.

## v1.1 — Export Adapters

```
ccp export aider      →  generate .env file
ccp export openint    →  generate export commands
ccp export continue   →  generate ~/.continue/config.json
ccp export cursor     →  generate Cursor config
```

**Why deferred:** Single tool focus. Claude Code has the strongest need; other tools have their own UIs or don't need CLI management.

## v1.2 — Preset Repository

```
ccp add --preset deepseek   # auto-fills URL + models from built-in table
```

Currently 5 built-in presets. Could add community presets via a JSON file or GitHub-hosted registry.

**Why deferred:** 5 presets cover 90% of use cases. Add more when users ask.

## v1.x — Bilingual Aliases

```
ccp 添加      # alias for ccp add
ccp 切换      # alias for ccp switch
ccp 列表      # alias for ccp list
```

**Why deferred:** English commands are standard in CLI tools. Chinese aliases add complexity without clear benefit.

## v1.x — PowerShell Module

Publish as a proper PowerShell module (`Install-Module ccp`) with tab completion.

**Why deferred:** Single-file script is simpler to install, audit, and modify. Module packaging adds infrastructure without changing functionality.

## Never — Local Key Server

`ccp serve` — a local microservice that dispenses keys on demand.

**Why not:** This is the domain of 1Password CLI, envchain, AWS Secrets Manager, etc. ccp's job is Key → Config for Claude Code, not becoming a secrets manager.
