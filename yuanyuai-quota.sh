#!/usr/bin/env bash
# ====================================================
# yuanyuai-quota.sh — YuanyuAI API Key 用量查詢工具
# ====================================================
# 用法:
#   ./yuanyuai-quota.sh                    # 互動模式 (輸入 API Key)
#   ./yuanyuai-quota.sh sk-xxxx           # 直接傳入 API Key
#   ./yuanyuai-quota.sh --save sk-xxxx    # 儲存 Key 並查詢
#   ./yuanyuai-quota.sh --check           # 用已儲存 Key 查詢
#   ./yuanyuai-quota.sh --oneline         # 單行輸出
#   ./yuanyuai-quota.sh --hook            # Hook 模式 (超過 30% 提醒)
#   ./yuanyuai-quota.sh --interval 30     # 每 30 秒自動刷新
# ====================================================

set -euo pipefail

API_BASE="https://yuanyuaicloud.cn"
CONFIG_FILE="$HOME/.config/peanutking/yuanyuai_key"
CACHE_FILE="$HOME/.config/peanutking/yuanyuai_cache"
CACHE_TTL=900  # 15 分鐘
DRY_RUN=false

# ---- 顏色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ---- 工具函數 ----
fm() {
    local n="$1"
    if [[ -z "$n" || "$n" == "null" ]]; then
        echo "--"
    else
        echo "$n" | LC_NUMERIC=en_US.UTF-8 awk '{printf "%\047d\n", $1}'
    fi
}

# ---- 讀取已儲存 Key ----
load_key() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    fi
}

# ---- 快取管理 ----
get_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_time cache_pct cache_data
        cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local age=$((now - cache_time))
        
        if [[ $age -lt $CACHE_TTL ]]; then
            cat "$CACHE_FILE"
            return 0
        fi
    fi
    return 1
}

set_cache() {
    local pct="$1"
    local windowCalls="$2"
    local rateLimit="$3"
    local multiplierLabel="$4"
    local nextResetTime="$5"
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "${pct}|${windowCalls}|${rateLimit}|${multiplierLabel}|${nextResetTime}" > "$CACHE_FILE"
}

# ---- 查詢 API ----
query_quota() {
    local api_key="$1"
    local key_for_header="${api_key#sk-}"

    local response
    response=$(curl -s -w "\n%{http_code}" "$API_BASE/api/query-quota" \
        -H "Authorization: Bearer $key_for_header" \
        -H "Content-Type: application/json" 2>/dev/null)

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        echo "{\"error\":\"HTTP $http_code\",\"body\":$(echo "$body" | jq -R -s .)}"
        return
    fi

    echo "$body"
}

# ---- 渲染結果 ----
render_quota() {
    local json="$1"

    # 錯誤處理
    if echo "$json" | jq -e '.error' >/dev/null 2>&1; then
        local err_msg
        err_msg=$(echo "$json" | jq -r '.error // "unknown"')
        local err_body
        err_body=$(echo "$json" | jq -r '.body // ""')
        echo -e "\n${RED}❌ 查詢失敗: $err_msg${NC}"
        [[ -n "$err_body" && "$err_body" != "null" ]] && echo -e "${DIM}$err_body${NC}"
        return 1
    fi

    if ! echo "$json" | jq -e '.success' >/dev/null 2>&1; then
        local msg
        msg=$(echo "$json" | jq -r '.message // "查詢失敗"')
        echo -e "\n${RED}❌ $msg${NC}"
        return 1
    fi

    local data
    data=$(echo "$json" | jq '.data')
    local rateLimit billedCalls realCalls windowRemain
    local currentMultiplier multiplierLabel nextResetTime expiredTime name
    rateLimit=$(echo "$data" | jq -r '.rateLimit // 3000')
    billedCalls=$(echo "$data" | jq -r '.billedCalls // 0')
    realCalls=$(echo "$data" | jq -r '.realCalls // 0')
    windowRemain=$(echo "$data" | jq -r '.windowRemain // 0')
    currentMultiplier=$(echo "$data" | jq -r '.currentMultiplier // 1')
    multiplierLabel=$(echo "$data" | jq -r '.multiplierLabel // "×1"')
    nextResetTime=$(echo "$data" | jq -r '.nextResetTime // 0')
    expiredTime=$(echo "$data" | jq -r '.expiredTime // -1')
    name=$(echo "$data" | jq -r '.name // "--"')

    # 計算
    local pct burnRate burnRateNote
    pct=$(echo "scale=2; $billedCalls * 100 / $rateLimit" | bc 2>/dev/null || echo "0")
    pct=$(echo "$pct" | awk '{printf "%.1f", $1}')
    local pct_int
    pct_int=$(echo "$pct" | awk '{printf "%d", $1}')

    local mulImpact
    mulImpact=$((billedCalls - realCalls))
    [[ $mulImpact -lt 0 ]] && mulImpact=0

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        YuanyuAI Token 用量監控              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # API Key 名稱
    echo -e "  ${BOLD}🔑${NC} Key: ${DIM}${name}${NC}"

    # 狀態指示
    local dot_color dot_text
    if (( $(echo "$pct_int >= 90" | bc -l) )); then
        dot_color="${RED}●${NC}"
        dot_text="${RED}⚠ 即將耗盡${NC}"
    elif (( $(echo "$pct_int >= 65" | bc -l) )); then
        dot_color="${YELLOW}●${NC}"
        dot_text="${YELLOW}⚡ 用量偏高${NC}"
    else
        dot_color="${GREEN}●${NC}"
        dot_text="${GREEN}✓ 正常${NC}"
    fi
    echo -e "  ${dot_color} ${dot_text}"

    # 剩餘額度 (大數字)
    local remain_display
    if (( $(echo "$pct_int >= 90" | bc -l) )); then
        remain_display="${RED}"
    elif (( $(echo "$pct_int >= 65" | bc -l) )); then
        remain_display="${YELLOW}"
    else
        remain_display="${GREEN}"
    fi
    echo ""
    echo -e "  ${BOLD}剩餘額度${NC}"
    echo -e "  ${remain_display}${BOLD}$(echo "$pct" | awk '{printf "%3.0f", $1}')%${NC}  剩餘 $(fm "$windowRemain") 次"
    echo -e "  ${DIM}／ $(fm "$rateLimit") 次總額度 · 已用 $(fm "$billedCalls") 次${NC}"

    echo ""
    echo -e "  ${BOLD}📊 詳細數據${NC}"
    echo -e "  ┌──────────────────────┬──────────────────┐"
    echo -e "  │ 計費請求             │ $(printf "%-16s" "$(fm "$billedCalls")") │"
    echo -e "  │ 實際請求             │ $(printf "%-16s" "$(fm "$realCalls")") │"
    echo -e "  │ 當前倍率             │ $(printf "%-16s" "×${currentMultiplier}") │"
    echo -e "  │ 額外消耗 (加成)      │ $(printf "%-16s" "+$(fm "$mulImpact")") │"
    echo -e "  └──────────────────────┴──────────────────┘"

    # 消耗速率
    if [[ "$nextResetTime" != "0" && "$nextResetTime" != "null" ]]; then
        local now_s window_start elapsed_sec burn_per_min
        now_s=$(date +%s)
        window_start=$((nextResetTime - 5*3600))
        elapsed_sec=$((now_s - window_start))

        if (( elapsed_sec > 60 )); then
            burn_per_min=$(echo "scale=2; $billedCalls / ($elapsed_sec / 60)" | bc 2>/dev/null || echo "0")
            if (( $(echo "$burn_per_min < 1" | bc -l) )); then
                burnRateNote="<1 次/分"
            else
                burnRateNote="$(printf "%.0f" "$burn_per_min") 次/分"
            fi

            # 預估總消耗
            local estimated_total
            estimated_total=$(echo "scale=0; $billedCalls * 100 / (($elapsed_sec * 100) / (5*3600))" | bc 2>/dev/null || echo "0")
            if (( estimated_total > rateLimit )); then
                local over
                over=$((estimated_total - rateLimit))
                burnRateNote="${burnRateNote}  ${RED}⚠ 預估超限 +$(fm "$over")${NC}"
            else
                burnRateNote="${burnRateNote}  ${DIM}預估 $(fm "$estimated_total") 次${NC}"
            fi

            echo -e "\n  ${BOLD}⏱ 消耗速率${NC}"
            echo -e "  ${burnRateNote}"
        fi
    fi

    # 時間資訊
    echo ""
    echo -e "  ${BOLD}⏰ 時間資訊${NC}"
    if [[ "$nextResetTime" != "0" && "$nextResetTime" != "null" ]]; then
        local reset_date
        reset_date=$(date -r "$nextResetTime" "+%H:%M" 2>/dev/null || echo "--")
        echo -e "  ⏱ 重置時間: ${BOLD}${reset_date}${NC}"

        # 倒數
        local diff_secs
        diff_secs=$((nextResetTime - now_s))
        if (( diff_secs > 0 )); then
            local h m s
            h=$((diff_secs / 3600))
            m=$(((diff_secs % 3600) / 60))
            s=$((diff_secs % 60))
            printf "  ⏳ 距離重置:  ${BOLD}%02d:%02d:%02d${NC}\n" "$h" "$m" "$s"
        fi
    fi

    if [[ "$expiredTime" == "-1" || "$expiredTime" == "null" ]]; then
        echo -e "  📅 到期時間: ${GREEN}永久有效${NC}"
    else
        local expire_date
        expire_date=$(date -r "$expiredTime" "+%m/%d %H:%M" 2>/dev/null || echo "--")
        if (( $(date +%s) > expiredTime )); then
            echo -e "  📅 到期時間: ${RED}${expire_date} 已過期${NC}"
        else
            echo -e "  📅 到期時間: ${expire_date}"
        fi
    fi

    # AI 摘要
    echo ""
    echo -e "  ${BOLD}💡 摘要${NC}"
    if (( $(echo "$pct_int >= 90" | bc -l) )); then
        echo -e "  ${RED}已消耗 ${pct}%，即將達到上限。目前倍率 ×${currentMultiplier} 加速消耗中。${NC}"
    elif (( $(echo "$pct_int >= 65" | bc -l) )); then
        echo -e "  ${YELLOW}已消耗 ${pct}%。倍率 ×${currentMultiplier}，請留意請求頻率。${NC}"
    elif (( $(echo "$currentMultiplier > 1" | bc -l) )); then
        echo -e "  ${GREEN}用量正常（${pct}%）。倍率 ×${currentMultiplier}，實際請求 $(fm "$realCalls") 次。${NC}"
    else
        echo -e "  ${GREEN}用量正常（${pct}%）。尚有 $(fm "$windowRemain") 次可用額度。${NC}"
    fi

    echo ""
    return 0
}

# ---- 儲存 Key ----
save_key() {
    local key="$1"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "$key" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓ API Key 已儲存到 $CONFIG_FILE${NC}"
}

# ---- 互動模式 ----
interactive_mode() {
    local saved_key
    saved_key=$(load_key || true)
    if [[ -n "$saved_key" ]]; then
        echo -e "${DIM}已儲存 Key: ${saved_key:0:8}...${NC}"
        echo -e "按 Enter 使用已儲存 Key，或輸入新 Key: "
        read -r input_key
        if [[ -z "$input_key" ]]; then
            echo "$saved_key"
            return
        fi
        echo "$input_key"
    else
        echo -e "請輸入 API Key (sk-...): "
        read -r input_key
        echo "$input_key"
    fi
}

# ---- 監控模式 ----
monitor_mode() {
    local api_key="$1"
    local interval="${2:-30}"

    echo -e "${CYAN}🔍 監控模式啟動 (每 ${interval} 秒刷新)${NC}"
    echo -e "${DIM}按 Ctrl+C 停止${NC}\n"

    while true; do
        local result
        result=$(query_quota "$api_key")
        clear
        render_quota "$result"
        echo -e "\n${DIM}下次刷新: ${interval} 秒後...${NC}"
        sleep "$interval"
    done
}

# ---- Hook 模式 ----
hook_mode() {
    local api_key
    api_key=$(load_key || true)
    
    if [[ -z "$api_key" ]]; then
        # 沒有儲存的 key，靜默退出
        exit 0
    fi
    
    # 檢查快取
    local cached
    if cached=$(get_cache); then
        # 使用快取
        local pct windowCalls rateLimit multiplierLabel nextResetTime
        IFS='|' read -r pct windowCalls rateLimit multiplierLabel nextResetTime <<< "$cached"
        
        # 即使有快取，也要檢查是否超過 30%
        local pct_int=${pct%%.*}
        if [[ "$pct_int" -ge 30 ]]; then
            echo ""
            echo -e "${YELLOW}⚠️  YuanyuAI 用量提醒${NC}"
            echo -e "   ${pct}% used (${windowCalls}/${rateLimit}) ${multiplierLabel}"
            if [[ -n "$nextResetTime" && "$nextResetTime" != "0" ]]; then
                local now_s diff_secs h m
                now_s=$(date +%s)
                diff_secs=$((nextResetTime - now_s))
                if (( diff_secs > 0 )); then
                    h=$((diff_secs / 3600))
                    m=$(((diff_secs % 3600) / 60))
                    echo -e "   Reset in: ${h}h ${m}m"
                fi
            fi
            echo ""
        fi
        exit 0
    fi
    
    # 沒有快取，查詢 API
    local result
    result=$(query_quota "$api_key")
    
    if ! echo "$result" | jq -e '.success' >/dev/null 2>&1; then
        # 查詢失敗，靜默退出
        exit 0
    fi
    
    local windowCalls rateLimit multiplierLabel pct nextResetTime
    windowCalls=$(echo "$result" | jq -r '.data.windowCalls // 0')
    rateLimit=$(echo "$result" | jq -r '.data.rateLimit // 1')
    multiplierLabel=$(echo "$result" | jq -r '.data.multiplierLabel // "×1"')
    nextResetTime=$(echo "$result" | jq -r '.data.nextResetTime // 0')
    pct=$(echo "scale=1; $windowCalls * 100 / $rateLimit" | bc 2>/dev/null || echo "0")
    
    # 存快取
    set_cache "$pct" "$windowCalls" "$rateLimit" "$multiplierLabel" "$nextResetTime"
    
    # 檢查是否超過 30%
    local pct_int=${pct%%.*}
    if [[ "$pct_int" -ge 30 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  YuanyuAI 用量提醒${NC}"
        echo -e "   ${pct}% used (${windowCalls}/${rateLimit}) ${multiplierLabel}"
        if [[ -n "$nextResetTime" && "$nextResetTime" != "0" ]]; then
            local now_s diff_secs h m
            now_s=$(date +%s)
            diff_secs=$((nextResetTime - now_s))
            if (( diff_secs > 0 )); then
                h=$((diff_secs / 3600))
                m=$(((diff_secs % 3600) / 60))
                echo -e "   Reset in: ${h}h ${m}m"
            fi
        fi
        echo ""
    fi
    
    exit 0
}

# ====================================================
# Main
# ====================================================

main() {
    local api_key=""
    local mode="once"
    local interval=30

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --save|-s)
                shift
                api_key="$1"
                save_key "$api_key"
                mode="once"
                ;;
            --check|-c)
                api_key=$(load_key || true)
                if [[ -z "$api_key" ]]; then
                    echo -e "${RED}❌ 未找到已儲存嘅 API Key${NC}"
                    echo -e "${DIM}請先用 --save 儲存，或直接傳入 Key${NC}"
                    exit 1
                fi
                mode="once"
                ;;
            --oneline|-1)
                api_key=$(load_key || true)
                if [[ -z "$api_key" ]]; then
                    echo -e "${RED}❌ 未找到已儲存嘅 API Key${NC}"
                    echo -e "${DIM}請先用 --save 儲存，或直接傳入 Key${NC}"
                    exit 1
                fi
                mode="oneline"
                ;;
            --hook)
                mode="hook"
                ;;
            --interval|-i)
                shift
                interval="${1:-30}"
                mode="monitor"
                ;;
            --help|-h)
                echo "YuanyuAI API Key 用量查詢工具"
                echo ""
                echo "用法:"
                echo "  yuanyuai-quota.sh                    # 互動模式"
                echo "  yuanyuai-quota.sh sk-xxxx           # 直接查詢"
                echo "  yuanyuai-quota.sh --save sk-xxxx    # 儲存並查詢"
                echo "  yuanyuai-quota.sh --check           # 用已儲存 Key 查詢"
                echo "  yuanyuai-quota.sh --oneline         # 單行輸出 (百分比)"
                echo "  yuanyuai-quota.sh --hook            # Hook 模式 (超過 30% 提醒)"
                echo "  yuanyuai-quota.sh --interval 30     # 監控模式"
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            *)
                api_key="$1"
                ;;
        esac
        shift
    done

    # Hook 模式特殊處理
    if [[ "$mode" == "hook" ]]; then
        hook_mode
    fi

    # 如果冇 key，嘗試互動模式
    if [[ -z "$api_key" ]]; then
        api_key=$(interactive_mode)
    fi

    # 確保有 key
    if [[ -z "$api_key" ]]; then
        echo -e "${RED}❌ 需要 API Key${NC}"
        exit 1
    fi

    # 確保有 sk- 前綴
    if [[ "$api_key" != sk-* ]]; then
        api_key="sk-${api_key}"
    fi

    # 自動儲存 (如果冇 save 過)
    local saved
    saved=$(load_key || true)
    if [[ -z "$saved" ]]; then
        save_key "$api_key"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] 會用 Key: ${api_key:0:12}...${NC}"
        echo -e "${DIM}[DRY RUN] 查詢 ${API_BASE}/api/query-quota${NC}"
        exit 0
    fi

    # 執行
    if [[ "$mode" == "oneline" ]]; then
        local result
        result=$(query_quota "$api_key")
        if echo "$result" | jq -e '.success' >/dev/null 2>&1; then
            local windowCalls rateLimit multiplierLabel pct nextResetTime now_s diff_secs
            windowCalls=$(echo "$result" | jq -r '.data.windowCalls // 0')
            rateLimit=$(echo "$result" | jq -r '.data.rateLimit // 1')
            multiplierLabel=$(echo "$result" | jq -r '.data.multiplierLabel // "×1"')
            nextResetTime=$(echo "$result" | jq -r '.data.nextResetTime // 0')
            pct=$(echo "scale=1; $windowCalls * 100 / $rateLimit" | bc 2>/dev/null || echo "0")
            if [[ "$nextResetTime" != "0" && "$nextResetTime" != "null" ]]; then
                now_s=$(date +%s)
                diff_secs=$((nextResetTime - now_s))
                if (( diff_secs > 0 )); then
                    local h m
                    h=$((diff_secs / 3600))
                    m=$(((diff_secs % 3600) / 60))
                    printf "%s%% used (%s/%s) %s - reset in %02d:%02d\n" "$pct" "$windowCalls" "$rateLimit" "$multiplierLabel" "$h" "$m"
                else
                    echo "${pct}% used (${windowCalls}/${rateLimit}) ${multiplierLabel} - resetting..."
                fi
            else
                echo "${pct}% used (${windowCalls}/${rateLimit}) ${multiplierLabel}"
            fi
        else
            echo "Error: failed to query quota"
            exit 1
        fi
    elif [[ "$mode" == "monitor" ]]; then
        monitor_mode "$api_key" "$interval"
    else
        local result
        result=$(query_quota "$api_key")
        render_quota "$result"
    fi
}

main "$@"
