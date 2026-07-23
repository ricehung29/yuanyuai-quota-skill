---
name: yuanyuai-quota
description: 即時查詢同監控 YuanyuAI API Key 嘅用量限制 (rate limit / quota)
---

# YuanyuAI Quota — API Key 用量監控

即時查詢同監控 YuanyuAI API Key 嘅用量限制。

## 用法

- `/quota` — 查詢已儲存嘅 API Key 用量
- `/quota sk-xxxxx` — 用指定 Key 查詢
- `/quota --save sk-xxxxx` — 儲存 Key 並查詢
- `/quota --check` — 用已儲存 Key 查詢（完整報告）
- `/quota --oneline` — 單行輸出（百分比 + 速率 + 重置倒數）
- `/quota --hook` — Hook 模式（用於自動提醒）
- `/quota --interval 30` — 每 30 秒自動刷新監控
- `/quota --help` — 顯示完整幫助

## 自動用量提醒（推薦）

設定 `post_tool_use` hook，每次工具呼叫後自動檢查用量：

在 `.claude/settings.local.json` 加入：

```json
{
  "hooks": {
    "post_tool_use": [
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
```

## Web UI (GitHub Pages)

即開即用嘅用量監控面板，唔需要 CLI：

**網址：** `https://ricehung.github.io/yuanyuai-quota-skill/`

三種用法：

1. **直接打開** — 輸入 API Key 後按儲存
2. **快速查詢** — `https://ricehung.github.io/yuanyuai-quota-skill/?key=sk-xxxxx`（貼上即自動查詢）
3. **捷徑 bookmarlet** — 瀏覽器網址列貼上 `https://ricehung.github.io/yuanyuai-quota-skill/?key=sk-xxxxx` 一鍵查詢

功能：
- 用量百分比 + 剩餘次數（點擊切換顯示）
- 計費 / 實際請求數、倍率影響
- 消耗速率、預估超限時間
- 下次重置倒數
- 每 60 秒自動刷新
- 支援 PWA 安裝到手機主畫面

## Key 儲存位置

- 路徑: `~/.config/peanutking/yuanyuai_key`
- 權限: `chmod 600`（僅 owner 可讀寫）
- 安全: 不在 repo 內，唔會被 git 追蹤
- 自動儲存: 首次使用時自動儲存，之後可用 `--check` 或 `--oneline` 直接查詢