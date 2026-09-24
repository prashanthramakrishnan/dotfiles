#!/bin/bash
# Claude Code status line: model, repo + git state, session context/lines/cost,
# and Claude.ai session (5-hour) + weekly (7-day) rate limits.
#
# The `rate_limits` object is only sent to status line scripts for Claude.ai Pro
# and Max subscribers, and only after the session's first API response -- so the
# limits row reads "after first reply" on a brand-new session until you send a
# message. Claude Code also drops a window once its resets_at time has passed.
#
# Field reference: https://code.claude.com/docs/en/statusline

input=$(cat)

IFS=$'\x1f' read -r MODEL DIR CTX CTX_SIZE COST DUR_MS ADDED REMOVED FIVE_PCT FIVE_AT WEEK_PCT WEEK_AT SPEND_PCT SPEND_AT <<EOF
$(printf '%s' "$input" | jq -r '[
  (.model.display_name // "?"),
  (.workspace.current_dir // .cwd // "?"),
  (.context_window.used_percentage // ""),
  (.context_window.context_window_size // ""),
  (.cost.total_cost_usd // 0),
  (.cost.total_duration_ms // 0),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  (.rate_limits.five_hour.used_percentage   // ""),
  (.rate_limits.five_hour.resets_at         // ""),
  (.rate_limits.seven_day.used_percentage   // ""),
  (.rate_limits.seven_day.resets_at         // ""),
  (.rate_limits.spend_limit.used_percentage // ""),
  (.rate_limits.spend_limit.resets_at       // "")
] | map(tostring) | join("\u001f")' 2>/dev/null)
EOF

DIM=$'\033[2m'; RESET=$'\033[0m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; BOLD=$'\033[1m'
CYAN=$'\033[36m'; MAGENTA=$'\033[35m'

# Colour by headroom: green under 50% used, yellow to 80%, red above.
hue() {
  awk -v p="$1" -v g="$GREEN" -v y="$YELLOW" -v r="$RED" \
    'BEGIN { print (p >= 80 ? r : (p >= 50 ? y : g)) }'
}

# Ten-cell meter, rounded up so any usage at all shows one filled cell.
bar() {
  awk -v p="$1" 'BEGIN {
    if (p < 0) p = 0; if (p > 100) p = 100
    n = int(p / 10); if (p > 0 && n == 0) n = 1
    for (i = 0; i < n; i++) printf "█"
    for (i = n; i < 10; i++) printf "░"
  }'
}

# "in 2h 14m" while the window is close, otherwise a wall-clock stamp.
resets() {
  local at=$1 now
  [ -z "$at" ] && return
  now=$(date +%s)
  local secs=$((at - now))
  if [ "$secs" -le 0 ]; then
    printf 'resetting'
  elif [ "$secs" -lt 3600 ]; then
    printf 'in %dm' $((secs / 60))
  elif [ "$secs" -lt 43200 ]; then
    printf 'in %dh %dm' $((secs / 3600)) $(((secs % 3600) / 60))
  else
    printf '%s' "$(date -r "$at" '+%a %H:%M')"
  fi
}

# One "label bar pct · resets" segment.
segment() {
  local label=$1 pct=$2 at=$3 unit=$4
  [ -z "$pct" ] && return
  printf '%s%s%s %s%s%s %s%.0f%s%s %s· %s%s' \
    "$DIM" "$label" "$RESET" \
    "$(hue "$pct")" "$(bar "$pct")" "$RESET" \
    "$BOLD" "$pct" "$unit" "$RESET" \
    "$DIM" "$(resets "$at")" "$RESET"
}

# --- last-known cache -------------------------------------------------------
# Claude Code sends `rate_limits` only after the session's first API response,
# so a freshly opened session has none. Remember the last values we saw and
# show them (marked stale) until this session gets its own numbers.
CACHE="$HOME/.claude/.rate-limits-cache"
STALE=""

if [ -n "$FIVE_PCT" ] || [ -n "$WEEK_PCT" ] || [ -n "$SPEND_PCT" ]; then
  printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
    "$FIVE_PCT" "$FIVE_AT" "$WEEK_PCT" "$WEEK_AT" "$SPEND_PCT" "$SPEND_AT" \
    > "$CACHE".tmp$$ 2>/dev/null && mv -f "$CACHE".tmp$$ "$CACHE" 2>/dev/null
elif [ -r "$CACHE" ]; then
  IFS=$'\x1f' read -r FIVE_PCT FIVE_AT WEEK_PCT WEEK_AT SPEND_PCT SPEND_AT < "$CACHE"
  STALE=1
  # Drop any window whose reset time has already passed -- its usage is zero now.
  NOW=$(date +%s)
  [ -n "$FIVE_AT" ]  && [ "$FIVE_AT"  -le "$NOW" ] 2>/dev/null && FIVE_PCT='' FIVE_AT=''
  [ -n "$WEEK_AT" ]  && [ "$WEEK_AT"  -le "$NOW" ] 2>/dev/null && WEEK_PCT='' WEEK_AT=''
  [ -n "$SPEND_AT" ] && [ "$SPEND_AT" -le "$NOW" ] 2>/dev/null && SPEND_PCT='' SPEND_AT=''
fi

# 120000 -> "120k", 1000000 -> "1M".
human() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { v = n / 1000000; printf (v == int(v) ? "%dM" : "%.1fM"), v }
    else if (n >= 1000) printf "%dk", n / 1000
    else printf "%d", n
  }'
}

# 2520000 ms -> "42m", 5400000 -> "1h 30m".
duration() {
  local m=$(($1 / 60000))
  if [ "$m" -ge 60 ]; then printf '%dh %dm' $((m / 60)) $((m % 60)); else printf '%dm' "$m"; fi
}

# --- line 1: where you are ---
printf '%s%s%s %s·%s %s' "$BOLD" "$MODEL" "$RESET" "$DIM" "$RESET" "$(basename "$DIR")"
# --no-optional-locks: never take index.lock, which would race a git command you run yourself.
BRANCH=$(git --no-optional-locks -C "$DIR" symbolic-ref --short -q HEAD 2>/dev/null \
  || git --no-optional-locks -C "$DIR" rev-parse --short HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
  if [ -z "$(git --no-optional-locks -C "$DIR" status --porcelain 2>/dev/null | head -1)" ]; then
    printf '  %s%s%s %s✓%s' "$MAGENTA" "$BRANCH" "$RESET" "$GREEN" "$RESET"
  else
    printf '  %s%s%s %s●%s' "$MAGENTA" "$BRANCH" "$RESET" "$YELLOW" "$RESET"
  fi
fi
[ "${DUR_MS:-0}" -ge 60000 ] 2>/dev/null && printf ' %s· %s%s' "$DIM" "$(duration "$DUR_MS")" "$RESET"
printf '\n'

# --- line 2: this session's work ---
if [ -n "$CTX" ]; then
  printf '%schat ctx%s %s%s%s %s%.0f%%%s' "$DIM" "$RESET" "$(hue "$CTX")" "$(bar "$CTX")" "$RESET" "$BOLD" "$CTX" "$RESET"
  if [ -n "$CTX_SIZE" ]; then
    USED=$(awk -v p="$CTX" -v s="$CTX_SIZE" 'BEGIN { printf "%d", p * s / 100 }')
    printf ' %s· %s/%s%s' "$DIM" "$(human "$USED")" "$(human "$CTX_SIZE")" "$RESET"
  fi
else
  printf '%schat ctx · after first reply%s' "$DIM" "$RESET"
fi
if [ "${ADDED:-0}" -gt 0 ] || [ "${REMOVED:-0}" -gt 0 ] 2>/dev/null; then
  printf ' %s·%s %s+%s%s %s−%s%s %slines%s' "$DIM" "$RESET" "$GREEN" "$ADDED" "$RESET" "$RED" "$REMOVED" "$RESET" "$DIM" "$RESET"
fi
awk -v c="$COST" -v d="$DIM" -v r="$RESET" -v cy="$CYAN" \
  'BEGIN { if (c > 0.005) printf " %s·%s %s$%.2f%s", d, r, cy, c, r }'
printf '\n'

# --- line 3: the limits ---
parts=()
[ -n "$FIVE_PCT" ]  && parts+=("$(segment session "$FIVE_PCT" "$FIVE_AT" '%')")
[ -n "$WEEK_PCT" ]  && parts+=("$(segment weekly  "$WEEK_PCT" "$WEEK_AT" '%')")
[ -n "$SPEND_PCT" ] && parts+=("$(segment spend   "$SPEND_PCT" "$SPEND_AT" '%')")

if [ ${#parts[@]} -eq 0 ]; then
  printf '%slimits · after first reply%s' "$DIM" "$RESET"
else
  sep=''
  [ -n "$STALE" ] && printf '%s~ %s' "$DIM" "$RESET"
  for p in "${parts[@]}"; do
    printf '%s%s' "$sep" "$p"
    sep='   '
  done
fi
