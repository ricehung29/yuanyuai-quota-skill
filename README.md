# YuanyuAI Quota Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Claude Code skill for monitoring YuanyuAI API key usage (rate limit / quota) — uses the official [`/api/query-quota`](https://yuanyuaicloud.cn/api/query-quota) endpoint.

**✅ 2026-11-11 — 本 skill 已恢復運作。** 官方重新開放 `GET /api/query-quota`，repo 解封並同步更新。

即時查詢 YuanyuAI API Key 嘅用量限制，支援自動用量提醒。

## What's New

- **2026-11-11 · 解除封存** — 官方 API 查詢恢復，repo 重新上線（詳見 [Changelog](#changelog)）
- **API 查詢回歸** — 官方已開放 `GET /api/query-quota`（免登入，只需 `Authorization: Bearer`），skill 解除封存
- **週限額顯示** — 新增 `weeklyLimit` / `weeklyBilled` / `nextWeeklyReset` 支援（週限月卡、svip 計劃）
- **30 秒刷新** — 跟隨官方建議嘅查詢頻率（`--interval 30`）
- **Web 面板轉向** — GitHub Pages 舊面板因 CORS 同源限制，改為跳轉官方 [`yuanyuaicloud.cn/query-quota`](https://yuanyuaicloud.cn/query-quota)

## Features

- 📊 **完整報告** — 用量統計、消耗速率、時間資訊
- 📝 **單行輸出** — 百分比 + 倍率 + 重置倒數
- ⚠️ **自動提醒** — 用量超過 30% 時自動提示
- 🔒 **安全儲存** — Key 唔會存喺 repo 內
- ⏱️ **快取機制** — 15 分鐘內唔重複查詢，唔 spam API
- 🌐 **官方網頁面板** — [`yuanyuaicloud.cn/query-quota`](https://yuanyuaicloud.cn/query-quota)（本 repo 嘅 GitHub Pages 舊面板已改為跳轉）

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
git clone https://github.com/ricehung29/yuanyuai-quota-skill.git .claude/skills/yuanyuai-quota --depth 1
```

Claude Code 會自動由 `.claude/skills/<name>/SKILL.md` 載入，用 `/yuanyuai-quota` 呼叫。

### 3. 自動用量提醒（可選）

在 `.claude/settings.local.json` 加入 hook：

```json
{
  "hooks": {
    "PostToolUse": [
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
| `/yuanyuai-quota --interval 30` | 監控模式（預設每 30 秒刷新，官方建議值） |

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
  🔑 Key: kimi-k3-1000次-k8pw87
  ● ✓ 正常

  剩餘額度
   25%  剩餘 750 次
  ／ 1,000 次總額度 · 已用 250 次

  📊 詳細數據
  │ 計費請求    │ 250 │ 實際請求 │ 125 │ 當前倍率 │ ×2 │

  📅 本週額度
  已用 1,851 / 12,000 次 · 剩餘 10,149 次
  週重置: 11/16 00:00
```

**單行模式：**
```
25.0% used (250/1000) ×2 (13:00-18:59) - reset in 03:44
```

**自動提醒（> 30%）：**
```
⚠️  YuanyuAI 用量提醒
   35.2% used (1056/3000) ×2 (13:00-18:59)
   Reset in: 1h 20m
```

## 測試

```bash
./test.sh   # 用 stub curl 跑 4 個 case，唔會打真 API
```

## Web UI

官方面板：[`https://yuanyuaicloud.cn/query-quota`](https://yuanyuaicloud.cn/query-quota)

> 本 repo 嘅 GitHub Pages 舊面板已停用 —— API 嘅 `Access-Control-Allow-Origin` 鎖定為 `https://yuanyuaicloud.cn`，第三方 domain 嘅瀏覽器請求會被封鎖。`docs/index.html` 現時只做轉向。
> CLI / skill 唔受影響：`curl` 唔受 CORS 限制。

## 安全

- API 只查詢該 Key 對應嘅套餐，唔會回傳帳號餘額、訂單或其他 Key
- 官方建議每 30 秒查詢一次
- API Key 儲存喺 `~/.config/peanutking/yuanyuai_key`
- 權限 `chmod 600`，僅 owner 可讀寫
- 唔會被 git 追蹤

## Changelog

### 2026-11-11 — 解除封存，skill 回歸 ✅

官方重新支援 API 查詢額度，免登入：

```bash
curl 'https://yuanyuaicloud.cn/api/query-quota' \
  -H 'Authorization: Bearer YOUR_API_KEY'
```

- 🟢 **Skill 恢復運作** — repo 由封存狀態復原，`/yuanyuai-quota` 可正常查詢
- 🟢 **修好 `billedCalls`** — 舊版只讀 `windowCalls`，API 改欄位後 hook 模式靜默失效；現以 `billedCalls` 優先，`windowCalls` 作 fallback
- 🟢 **新增週限額** — 顯示 `weeklyLimit` / `weeklyBilled` / `nextWeeklyReset`（週限月卡、svip 計劃）
- 🟢 **修好不限量計劃** — `rateLimit: 0` 唔再除零，顯示「不限量」（svip）
- 🟢 **`test.sh`** — 4 個離線 stub case（有上限 / 不限量 / 舊欄位 / API 錯誤），唔會打真 API
- 🟡 **Web 面板改為轉向** — CORS 仍鎖定 `https://yuanyuaicloud.cn`，GitHub Pages 無法直接查詢，`docs/index.html` 改為跳轉官方面板；CLI 用 `curl` 唔受 CORS 影響，所以 skill 照用
- 🟡 **文件修正** — hook event `post_tool_use` → `PostToolUse`，指令 `/quota` → `/yuanyuai-quota`

### 2026-08-04 — 封存

YuanyuAI 將 API CORS 鎖為同源，第三方頁面無法跨域查詢，repo 一度封存。
事後確認：受影響嘅只有瀏覽器面板，`curl` 一直無問題 —— 所以 11-11 官方重開 API 後即刻復原。

## License

MIT License - 自由使用、修改、分享

## Author

Made by [Rice Hung](https://github.com/ricehung)