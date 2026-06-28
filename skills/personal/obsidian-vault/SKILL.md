---
name: obsidian-vault
description: Search, create, and manage notes in the Obsidian vault with wikilinks and index notes. Multi-device aware (MacBook Pro / Mac mini / Windows). Use when user wants to find, create, or organize notes in Obsidian.
---

# Obsidian Vault

## Vault location (multi-device)

> **优先级**：`OBSIDIAN_VAULT_PATH` 环境变量 > 自动检测 > 交互式询问

### 设备路径映射

| 设备 | 默认路径 | 检测方式 |
|------|----------|----------|
| **MacBook Pro** | `~/Obsidian/AlexCai/` | `uname -n` = `MacBook-Pro` |
| **Mac mini** | `~/Documents/Obsidian/AlexCai/` | `uname -n` = `Mac-mini` 或路径存在 |
| **Windows** | `D:\Obsidian知识库\Alex Cai\AlexCai` | `uname -o` = `Msys` / `Cygwin` / `Windows` |

### 路径解析逻辑

```bash
# 1. 优先读取环境变量
if [[ -n "$OBSIDIAN_VAULT_PATH" ]]; then
    VAULT_PATH="$OBSIDIAN_VAULT_PATH"
# 2. 自动检测设备
elif [[ -d "$HOME/Documents/Obsidian/AlexCai" ]]; then
    VAULT_PATH="$HOME/Documents/Obsidian/AlexCai"
elif [[ -d "$HOME/Obsidian/AlexCai" ]]; then
    VAULT_PATH="$HOME/Obsidian/AlexCai"
elif [[ -d "/mnt/d/Obsidian知识库/Alex Cai/AlexCai" ]]; then
    VAULT_PATH="/mnt/d/Obsidian知识库/Alex Cai/AlexCai"
# 3. 兜底：询问用户
else
    echo "未检测到 Obsidian vault，请设置 OBSIDIAN_VAULT_PATH 环境变量"
fi
```

### 设置环境变量（推荐）

在 `~/.zshrc` / `~/.bashrc` / PowerShell profile 中添加：

```bash
# macOS
export OBSIDIAN_VAULT_PATH="$HOME/Documents/Obsidian/AlexCai"

# Windows (PowerShell)
$env:OBSIDIAN_VAULT_PATH = "D:\Obsidian知识库\Alex Cai\AlexCai"
```

## Naming conventions

- **Index notes**: aggregate related topics (e.g., `Skills Index.md`, `RAG Index.md`, `AI-MUD Index.md`)
- **Title case** for all note names
- Flat structure with 8-zone architecture (`00-Inbox/`, `10-Projects/`, `20-Areas/`, `30-Resources/`, `40-Archives/`, `50-Self/`, `88-审计/`, `99-System/`)
- Use links and index notes instead of folders for organization

## Vault Structure

> **注意**：OB 知识库结构是动态演化的，不在 skill 中硬编码。实际结构以 vault 中 `AGENTS.md` 或 `README.md` 为准。skill 只提供通用原则。

### 结构发现原则

1. **运行时读取**：agent 应读取 vault 根目录的 `AGENTS.md` 或 `README.md` 获取当前结构
2. **动态检测**：使用 `find` / `ls` 命令发现实际目录结构，而非依赖硬编码
3. **配置优先**：用户可在 `OBSIDIAN_VAULT_CONFIG` 环境变量中指定结构配置文件路径

### 通用原则（不依赖具体结构）

- **Zone 命名**：通常以数字前缀排序（`00-`, `10-`, `20-` 等），但具体 zone 名称和数量会变化
- **Frontmatter**：笔记通常包含 YAML frontmatter，字段名可能变化，但 `status`、`type`、`tags` 较常见
- **链接**：使用 `[[wikilinks]]` 语法连接相关笔记
- **索引**：Index notes / MOC (Map of Content) 用于聚合主题

## Linking

- Use Obsidian `[[wikilinks]]` syntax: `[[Note Title]]`
- Notes link to dependencies/related notes at the bottom
- Index notes are just lists of `[[wikilinks]]`

## Workflows

### Resolve vault path

```bash
# 优先使用环境变量
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-$HOME/Documents/Obsidian/AlexCai}"

# 验证路径存在
if [[ ! -d "$VAULT_PATH" ]]; then
    echo "❌ Vault not found at $VAULT_PATH"
    echo "请设置 OBSIDIAN_VAULT_PATH 环境变量"
    exit 1
fi
```

### Search for notes

```bash
# Search by filename
find "$VAULT_PATH" -name "*.md" | grep -i "keyword"

# Search by content
grep -rl "keyword" "$VAULT_PATH" --include="*.md"
```

Or use Grep/Glob tools directly on the vault path.

### Create a new note

1. Use **Title case** for filename
2. Write content with YAML frontmatter (`status`, `type`, `tags`, `created`, `modified`)
3. Add `[[wikilinks]]` to related notes at the bottom
4. Place in correct zone (00-Inbox for raw, 20-Areas for long-term)

### Find related notes

Search for `[[Note Title]]` across the vault to find backlinks:

```bash
grep -rl "\[\[Note Title\]\]" "$VAULT_PATH"
```

### Find index notes

```bash
find "$VAULT_PATH" -name "*Index*" -o -name "*MOC*"
```
