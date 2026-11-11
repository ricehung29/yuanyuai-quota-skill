---
name: yuanyuai-quota
description: 即時查詢同監控 YuanyuAI API Key 嘅用量限制 (rate limit / quota)
---

# YuanyuAI Quota — API Key 用量監控

即時查詢同監控 YuanyuAI API Key 嘅用量限制。

## 用法

- `/yuanyuai-quota` — 查詢已儲存嘅 API Key 用量
- `/yuanyuai-quota sk-xxxxx` — 用指定 Key 查詢
- `/yuanyuai-quota --save sk-xxxxx` — 儲存 Key 並查詢
- `/yuanyuai-quota --check` — 用已儲存 Key 查詢（完整報告）
- `/yuanyuai-quota --oneline` — 單行輸出（百分比 + 速率 + 重置倒數）
- `/yuanyuai-quota --hook` — Hook 模式（用於自動提醒）
- `/yuanyuai-quota --interval 30` — 每 30 秒自動刷新監控
- `/yuanyuai-quota --help` — 顯示完整幫助

## 自動用量提醒（推薦）

設定 `PostToolUse` hook，每次工具呼叫後自動檢查用量：

在 `.claude/settings.local.json` 加入：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/yuanyuai-quota.sh --hook"
          }
        ]
      }
    ]
  }
}
```

效果：
- 每 15 分鐘查詢一次（有快取，唔會 spam API）
- 用量超過 30% 時，自動在對話中顯示提醒
- 用量低於 30% 時，靜默執行，唔干擾你

## 必要工具

```bash
brew install jq bc       # macOS
sudo apt install jq bc   # Linux
```

## API 端點

```
GET https://yuanyuaicloud.cn/api/query-quota
Authorization: Bearer <api_key_without_sk->
Content-Type: application/json
```

- 免登入，只查詢此 Key 對應嘅套餐
- 唔回傳帳號餘額、訂單或其他 Key
- 官方建議每 30 秒查詢一次（`--interval 30`）

回傳欄位（`data`）：`name`、`rateLimit`、`billedCalls`、`realCalls`、`windowRemain`、
`currentMultiplier`、`multiplierLabel`、`nextResetTime`、`expiredTime`，
以及週限計劃嘅 `weeklyLimit`、`weeklyBilled`、`nextWeeklyReset`、
`quotaType: "codingplan"`。舊欄位 `windowCalls` 仍可能出現，已用 `billedCalls` 優先。

## Web UI

官方面板：`https://yuanyuaicloud.cn/query-quota`

> GitHub Pages 舊面板已停用：API CORS 鎖定為 `https://yuanyuaicloud.cn`，第三方 domain 嘅瀏覽器請求會被封鎖。
> CLI / skill 用 `curl`，唔受 CORS 限制，繼續可用。

## Key 儲存位置

- 路徑: `~/.config/peanutking/yuanyuai_key`
- 權限: `chmod 600`（僅 owner 可讀寫）
- 安全: 不在 repo 內，唔會被 git 追蹤
- 自動儲存: 首次使用時自動儲存，之後可用 `--check` 或 `--oneline` 直接查詢