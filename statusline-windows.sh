#!/usr/bin/env bash
# Windows version — no `jq` dependency (parses JSON with grep/sed).
# Runs under Git Bash / MSYS2, which ship GNU `date` and bash 4+.
set -f

input=$(cat)
[ -z "$input" ] && { printf "Claude"; exit 0; }

# ── Colors ──────────────────────────────────────────────
c_dir='\033[38;2;0;153;255m'
c_model='\033[38;2;230;200;0m'
c_ctx='\033[38;2;86;182;194m'
green='\033[38;2;0;175;80m'
orange='\033[38;2;255;176;85m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
sep_color='\033[2m'
dim='\033[2m'
reset='\033[0m'

sep=" ${sep_color}│${reset} "

# ── JSON helper (no jq needed) ─────────────────────────
# Extract a value by key path using grep/sed. For nested keys like
# "model.display_name" it matches on the leaf key ("display_name").
json_val() {
    local key="$1" default="$2"
    local leaf="${key##*.}"
    local val
    val=$(printf '%s' "$input" | grep -o "\"${leaf}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/^"//;s/"[[:space:]]*$//')
    val="${val%\"}"
    val="${val#\"}"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        printf '%s' "$default"
    else
        printf '%s' "$val"
    fi
}

# ── Helpers ─────────────────────────────────────────────
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$orange"
    else printf "$green"
    fi
}

build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local c
    c=$(color_for_pct "$pct")
    local bar="$c"
    for ((i=0; i<filled; i++)); do bar+="━"; done
    bar+="${dim}"
    for ((i=0; i<empty; i++)); do bar+="─"; done
    bar+="${reset}"
    printf "%b" "$bar"
}

fmt_tokens() {
    local n=$1
    if [ "$n" -ge 1000 ]; then
        awk "BEGIN { printf \"%.0fk\", $n/1000 }"
    else
        printf "%d" "$n"
    fi
}

fmt_reset_5h() {
    local epoch=$1
    [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ] && return
    date -d "@${epoch}" +"%-l:%M%P" 2>/dev/null | sed 's/^ //'
}

fmt_reset_7d() {
    local epoch=$1
    [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ] && return
    date -d "@${epoch}" +"%b %-d, %-l:%M%P" 2>/dev/null | sed 's/^ //; s/  / /' | tr '[:upper:]' '[:lower:]'
}

# ── Extract data ────────────────────────────────────────
model_name=$(json_val "display_name" "Claude")
cwd_raw=$(json_val "cwd" "")
dirname=$(basename "$cwd_raw")
[ -z "$dirname" ] || [ "$dirname" = "." ] && dirname=""

ctx_size=$(json_val "context_window_size" "200000")
[ "$ctx_size" -eq 0 ] 2>/dev/null && ctx_size=200000

input_tokens=$(json_val "input_tokens" "0")
cache_creation=$(json_val "cache_creation_input_tokens" "0")
cache_read=$(json_val "cache_read_input_tokens" "0")
cur_in=$(( input_tokens + cache_creation + cache_read ))

# Isolate the rate_limits object first, then split into five_hour / seven_day
# blocks. This avoids the `context_window.used_percentage` field (added to the
# schema later) from being mistaken for a rate-limit value by a global grep.
num_after() {  # num_after <key> <text>  → first number following "key":
    printf '%s' "$2" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*[0-9.]*" | head -1 | sed 's/.*:[[:space:]]*//'
}

# Flatten to one line so sed-based block isolation works whether the input
# arrives compact (real Claude Code) or pretty-printed.
flat=$(printf '%s' "$input" | tr '\n' ' ')
case "$flat" in
    *'"rate_limits"'*) rl_block=$(printf '%s' "$flat" | sed 's/.*"rate_limits"//') ;;
    *)                 rl_block="" ;;   # no rate-limit data (API key / 3rd-party auth)
esac
five_block=$(printf '%s' "$rl_block" | sed 's/.*"five_hour"//; s/"seven_day".*//')
seven_block=$(printf '%s' "$rl_block" | sed 's/.*"seven_day"//')

rate_5h=$(num_after used_percentage "$five_block"); rate_5h=${rate_5h%.*}; rate_5h=${rate_5h:-0}
rate_7d=$(num_after used_percentage "$seven_block"); rate_7d=${rate_7d%.*}; rate_7d=${rate_7d:-0}
reset_5h=$(num_after resets_at "$five_block"); reset_5h=${reset_5h%.*}; reset_5h=${reset_5h:-0}
reset_7d=$(num_after resets_at "$seven_block"); reset_7d=${reset_7d%.*}; reset_7d=${reset_7d:-0}

# ── Line 1: project │ model │ context ──────────────────
ctx_used=$(fmt_tokens "$cur_in")
ctx_total=$(fmt_tokens "$ctx_size")
ctx_pct=$(( cur_in * 100 / ctx_size ))
ctx_color=$(color_for_pct "$ctx_pct")

line1="${c_dir}${dirname}${reset}"
line1+="${sep}${c_model}${model_name}${reset}"
line1+="${sep}${c_ctx}${ctx_used}${reset}${dim}/${ctx_total}${reset}"

# ── Line 2: 5h rate limit ─────────────────────────────
five_bar=$(build_bar "$rate_5h" 12)
five_color=$(color_for_pct "$rate_5h")
five_reset=$(fmt_reset_5h "$reset_5h")

line2="${white}current${reset}  ${five_bar} ${five_color}$(printf "%3d" "$rate_5h")%${reset}"
[ -n "$five_reset" ] && line2+="  ${dim}⟳ ${reset}${white}${five_reset}${reset}"

# ── Line 3: 7d rate limit ─────────────────────────────
seven_bar=$(build_bar "$rate_7d" 12)
seven_color=$(color_for_pct "$rate_7d")
seven_reset=$(fmt_reset_7d "$reset_7d")

line3="${white}weekly${reset}   ${seven_bar} ${seven_color}$(printf "%3d" "$rate_7d")%${reset}"
[ -n "$seven_reset" ] && line3+="  ${dim}⟳ ${reset}${white}${seven_reset}${reset}"

# ── Output ──────────────────────────────────────────────
printf '%b\n\n%b\n%b' "$line1" "$line2" "$line3"

exit 0
