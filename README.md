# YuanyuAI Quota Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Claude Code skill for monitoring YuanyuAI API key usage (rate limit / quota)

即時查詢 YuanyuAI API Key 嘅用量限制，支援自動用量提醒。

## Features

- 📊 **完整報告** — 用量統計、消耗速率、時間資訊
- 📝 **單行輸出** — 百分比 + 倍率 + 重置倒數
- ⚠️ **自動提醒** — 用量超過 30% 時自動提示
- 🔒 **安全儲存** — Key 唔會存喺 repo 內
- ⏱️ **快取機制** — 15 分鐘內唔重複查詢，唔 spam API

## Quick Start

### 1. 安裝前置工具

```bash
# macOS
brew install jq bc

# Linux
sudo apt install jq bc
```

### 2. 安裝 Skill

```bash
# Clone 到你的專案
cd your-project
git clone https://github.com/ricehung/yuanyuai-quota-skill.git .claude/skills/yuanyuai-quota --depth 1
```

### 3. 設定 Claude Code

在 `.claude/settings.local.json` 加入：

```json
{
  "skills": {
    "yuanyuai-quota": {
      "name": "yuanyuai-quota",
      "description": "即時查詢同監控 YuanyuAI API Key 嘅用量限制",
      "directory": ".claude/skills/yuanyuai-quota",
      "trigger": "yuanyuai-quota"
    }
  },
  "hooks": {
    "post_tool_use": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/skills/yuanyuai-quota/yuanyuai-quota.sh --hook"
          }
        ]
      }
    ]
  }
}
```

### 4. 儲存 API Key

```
/yuanyuai-quota --save sk-xxxxx
```

## 用法

| 命令 | 說明 |
|---|---|
| `/yuanyuai-quota` | 互動模式 |
| `/yuanyuai-quota --save sk-xxxxx` | 儲存 Key 並查詢 |
| `/yuanyuai-quota --check` | 完整報告 |
| `/yuanyuai-quota --oneline` | 單行輸出 |
| `/yuanyuai-quota --interval 30` | 監控模式（每 30 秒刷新） |

## 自動用量提醒

設定 hook 後，每次對話自動檢查：

| 用量 | 行為 |
|---|---|
| > 30% | 顯示黃色提醒 ⚠️ |
| ≤ 30% | 靜默，唔干擾 |

快取 15 分鐘，唔會每次都打 API。

## 範例輸出

**完整報告：**
```
╔════════════════════════════════════════════════╗
║        YuanyuAI Token 用量監控              ║
╚════════════════════════════════════════════════╝

  🔑 Key: glm5.2-3000次-iN01tv
  ● ✓ 正常
  剩餘額度:  19%  剩餘 2,441 次
  ／ 3,000 次總額度 · 已用 559 次
  ...
```

**單行模式：**
```
25.9% used (779/3000) ×2 (13:00-18:59) - reset in 02:36
```

**自動提醒（> 30%）：**
```
⚠️  YuanyuAI 用量提醒
   35.2% used (1056/3000) ×2 (13:00-18:59)
   Reset in: 1h 20m
```

## 安全

- API Key 儲存喺 `~/.config/peanutking/yuanyuai_key`
- 權限 `chmod 600`，僅 owner 可讀寫
- 唔會被 git 追蹤

## License

MIT License - 自由使用、修改、分享

## Author

Made by [Rice Hung](https://github.com/ricehung)