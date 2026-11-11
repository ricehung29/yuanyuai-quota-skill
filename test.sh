#!/usr/bin/env bash
# test.sh — offline check: stub curl, assert the render paths survive API shape changes
set -uo pipefail
cd "$(dirname "$0")"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/.config/peanutking"
echo "sk-test" > "$T/.config/peanutking/yuanyuai_key"

stub() { # stub <json>
  printf '#!/usr/bin/env bash\nprintf "%%s\\n%%s" %q 200\n' "$1" > "$T/bin/curl"
  chmod +x "$T/bin/curl"
  rm -f "$T/.config/peanutking/yuanyuai_cache"
}
run() { HOME="$T" PATH="$T/bin:$PATH" bash ./yuanyuai-quota.sh "$@" 2>&1; }
ok() { grep -q -- "$2" <<<"$1" || { echo "FAIL: expected '$2' in: $1"; exit 1; }; }

# 1. capped plan: billedCalls + weekly limit present
stub '{"success":true,"data":{"name":"t","rateLimit":1000,"billedCalls":420,"realCalls":200,"windowRemain":580,"currentMultiplier":2,"multiplierLabel":"x2","nextResetTime":9999999999,"expiredTime":-1,"weeklyLimit":12000,"weeklyBilled":5100,"weeklyRemain":6900,"nextWeeklyReset":9999999999}}'
out=$(run --oneline); ok "$out" "42.0% used (420/1000)"
out=$(run --check);   ok "$out" "本週額度"; ok "$out" "剩餘 6,900 次"

# 2. unlimited plan (rateLimit 0) must not divide by zero
stub '{"success":true,"data":{"name":"u","rateLimit":0,"billedCalls":900,"realCalls":300,"multiplierLabel":"x3","nextResetTime":9999999999,"expiredTime":-1}}'
out=$(run --oneline); ok "$out" "unlimited (900 used)"
out=$(run --check);   ok "$out" "不限量"

# 3. legacy windowCalls-only payload still works
stub '{"success":true,"data":{"name":"l","rateLimit":3000,"windowCalls":750,"realCalls":750,"windowRemain":2250,"expiredTime":-1}}'
out=$(run --oneline); ok "$out" "(750/3000)"

# 4. api error is reported, not swallowed
stub '{"success":false,"message":"API Key 无效"}'
out=$(run --check); ok "$out" "API Key 无效"

echo "all checks passed"
