#!/usr/bin/env bash
set -euo pipefail
# ==================================================
# Cloudflare DDNS 交互式一键安装脚本
# 用法: bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/ddns/main/install.sh)
# ==================================================

INSTALL_DIR="/root/ddns"
DDNS_SCRIPT="${INSTALL_DIR}/ddns.sh"
LOG_FILE="${INSTALL_DIR}/cloudflare-ddns.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }
title() { echo -e "\n${BOLD}${BLUE}$*${NC}"; }
ask()   { echo -e "${YELLOW}?${NC}  $*"; }

# ── Banner ────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║     Cloudflare DDNS 一键安装脚本          ║"
echo "  ║     支持 IPv4 (A) / IPv6 (AAAA)           ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 工具函数 ──────────────────────────────────────
prompt() {
    # prompt "提示文字" "默认值（可空）" -> 结果存入 REPLY
    local msg="$1" default="${2:-}"
    if [[ -n "$default" ]]; then
        ask "${msg} ${YELLOW}[默认: ${default}]${NC}: "
    else
        ask "${msg}: "
    fi
    read -r REPLY
    REPLY="${REPLY:-$default}"
}

prompt_password() {
    local msg="$1"
    ask "${msg}: "
    read -rs REPLY
    echo ""   # 换行（密码输入不回显）
}

confirm() {
    # confirm "提示" -> 返回 0=yes 1=no
    ask "$1 (y/n) [默认: y]: "
    read -r ans
    ans="${ans:-y}"
    [[ "$ans" =~ ^[Yy] ]]
}

# ══════════════════════════════════════════════════
# 步骤 1：选择记录类型
# ══════════════════════════════════════════════════
title "步骤 1/4：选择 DNS 记录类型"
echo "  1) IPv4  - A 记录    （最常用）"
echo "  2) IPv6  - AAAA 记录"
echo "  3) 双栈  - IPv4 + IPv6"
echo ""
ask "请输入选项 [默认: 1]: "
read -r TYPE_CHOICE
TYPE_CHOICE="${TYPE_CHOICE:-1}"

case "$TYPE_CHOICE" in
    1) ENABLE_V4=true;  ENABLE_V6=false; echo -e "  ${GREEN}已选择: IPv4 (A 记录)${NC}" ;;
    2) ENABLE_V4=false; ENABLE_V6=true;  echo -e "  ${GREEN}已选择: IPv6 (AAAA 记录)${NC}" ;;
    3) ENABLE_V4=true;  ENABLE_V6=true;  echo -e "  ${GREEN}已选择: 双栈 IPv4 + IPv6${NC}" ;;
    *) error "无效选项，请输入 1、2 或 3" ;;
esac

# ══════════════════════════════════════════════════
# 步骤 2：填写 IPv4 配置
# ══════════════════════════════════════════════════
if [[ "$ENABLE_V4" == true ]]; then
    title "步骤 2/4：IPv4 (A 记录) 配置"

    while true; do
        prompt_password "Cloudflare API Token（输入不可见）"
        CF_TOKEN1="$REPLY"
        [[ -n "$CF_TOKEN1" ]] && break
        warn "Token 不能为空，请重新输入"
    done

    while true; do
        prompt "根域名（例如 111288.xyz）" ""
        ZONE_NAME1="$REPLY"
        [[ -n "$ZONE_NAME1" ]] && break
        warn "根域名不能为空，请重新输入"
    done

    prompt "子域名前缀（例如 cmhk，留空则更新根域名本身）" ""
    RECORD_NAME1="$REPLY"

    prompt "是否开启 Cloudflare 代理（橙色云朵）" "false"
    PROXIED1="$REPLY"
else
    CF_TOKEN1=""; ZONE_NAME1=""; RECORD_NAME1=""; PROXIED1="false"
fi

# ══════════════════════════════════════════════════
# 步骤 3：填写 IPv6 配置
# ══════════════════════════════════════════════════
if [[ "$ENABLE_V6" == true ]]; then
    title "步骤 3/4：IPv6 (AAAA 记录) 配置"

    if [[ "$ENABLE_V4" == true ]]; then
        if confirm "IPv6 是否使用与 IPv4 相同的 API Token 和域名？"; then
            CF_TOKEN2="$CF_TOKEN1"
            ZONE_NAME2="$ZONE_NAME1"
            prompt "IPv6 子域名前缀（留空则与 IPv4 相同: ${RECORD_NAME1:-根域名}）" "$RECORD_NAME1"
            RECORD_NAME2="$REPLY"
            PROXIED2="$PROXIED1"
            info "已复用 IPv4 配置"
        else
            prompt_password "IPv6 Cloudflare API Token（输入不可见）"
            CF_TOKEN2="$REPLY"
            prompt "IPv6 根域名" ""
            ZONE_NAME2="$REPLY"
            prompt "IPv6 子域名前缀（留空则更新根域名本身）" ""
            RECORD_NAME2="$REPLY"
            prompt "是否开启 Cloudflare 代理" "false"
            PROXIED2="$REPLY"
        fi
    else
        # 仅 IPv6 模式
        while true; do
            prompt_password "Cloudflare API Token（输入不可见）"
            CF_TOKEN2="$REPLY"
            [[ -n "$CF_TOKEN2" ]] && break
            warn "Token 不能为空，请重新输入"
        done
        while true; do
            prompt "根域名（例如 111288.xyz）" ""
            ZONE_NAME2="$REPLY"
            [[ -n "$ZONE_NAME2" ]] && break
            warn "根域名不能为空"
        done
        prompt "子域名前缀（留空则更新根域名本身）" ""
        RECORD_NAME2="$REPLY"
        prompt "是否开启 Cloudflare 代理" "false"
        PROXIED2="$REPLY"
    fi
else
    CF_TOKEN2=""; ZONE_NAME2=""; RECORD_NAME2=""; PROXIED2="false"
fi

# ══════════════════════════════════════════════════
# 步骤 4：其他设置
# ══════════════════════════════════════════════════
title "步骤 4/4：其他设置"

echo "  定时任务间隔："
echo "  1) 每 5 分钟"
echo "  2) 每 10 分钟  （推荐）"
echo "  3) 每 30 分钟"
echo "  4) 每小时"
echo ""
ask "请输入选项 [默认: 2]: "
read -r CRON_CHOICE
CRON_CHOICE="${CRON_CHOICE:-2}"
case "$CRON_CHOICE" in
    1) CRON_INTERVAL="*/5 * * * *"  ;;
    2) CRON_INTERVAL="*/10 * * * *" ;;
    3) CRON_INTERVAL="*/30 * * * *" ;;
    4) CRON_INTERVAL="0 * * * *"    ;;
    *) warn "无效选项，使用默认 10 分钟"; CRON_INTERVAL="*/10 * * * *" ;;
esac
info "定时间隔: ${CRON_INTERVAL}"

prompt "安装目录" "/root/ddns"
INSTALL_DIR="$REPLY"
DDNS_SCRIPT="${INSTALL_DIR}/ddns.sh"
LOG_FILE="${INSTALL_DIR}/cloudflare-ddns.log"

# ── 确认摘要 ──────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════ 配置摘要 ══════════════${NC}"
if [[ "$ENABLE_V4" == true ]]; then
    echo -e "  IPv4 域名  : ${GREEN}${RECORD_NAME1:+${RECORD_NAME1}.}${ZONE_NAME1}${NC}"
    echo -e "  IPv4 Token : ${GREEN}${CF_TOKEN1:0:8}****************${NC}"
fi
if [[ "$ENABLE_V6" == true ]]; then
    echo -e "  IPv6 域名  : ${GREEN}${RECORD_NAME2:+${RECORD_NAME2}.}${ZONE_NAME2}${NC}"
    echo -e "  IPv6 Token : ${GREEN}${CF_TOKEN2:0:8}****************${NC}"
fi
echo -e "  执行间隔   : ${GREEN}${CRON_INTERVAL}${NC}"
echo -e "  安装目录   : ${GREEN}${INSTALL_DIR}${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo ""

confirm "确认以上配置并开始安装？" || { echo "已取消安装。"; exit 0; }

# ══════════════════════════════════════════════════
# 开始安装
# ══════════════════════════════════════════════════
echo ""
echo ">>> 检查依赖..."
for dep in curl jq flock; do
    if command -v "$dep" &>/dev/null; then
        info "$dep 已安装"
    else
        warn "$dep 未安装，尝试自动安装..."
        if command -v apt &>/dev/null; then
            apt install -y "$dep" &>/dev/null && info "$dep 安装成功" || error "$dep 安装失败，请手动安装"
        elif command -v yum &>/dev/null; then
            yum install -y "$dep" &>/dev/null && info "$dep 安装成功" || error "$dep 安装失败，请手动安装"
        else
            error "无法自动安装 $dep，请手动安装后重试"
        fi
    fi
done

echo ""
echo ">>> 创建目录..."
mkdir -p "${INSTALL_DIR}/.cache"
chmod 700 "${INSTALL_DIR}/.cache"
info "目录创建完成: ${INSTALL_DIR}"

echo ""
echo ">>> 写入 DDNS 脚本..."
cat > "$DDNS_SCRIPT" << 'DDNS_EOF'
#!/usr/bin/env bash
set -euo pipefail
# Cloudflare DDNS v3.1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/ddns.conf"

if [[ ! -f "$CONF" ]]; then echo "错误: 找不到配置文件 $CONF"; exit 1; fi
local_perm=$(stat -c%a "$CONF" 2>/dev/null || stat -f%p "$CONF" 2>/dev/null | tail -c 4 | head -c 3)
if [[ "$local_perm" != "600" && "$local_perm" != "400" ]]; then
    echo "错误: 配置文件权限不安全，请执行: chmod 600 \"$CONF\""; exit 1
fi
source "$CONF"

logfile="${logfile:-${SCRIPT_DIR}/cloudflare-ddns.log}"
max_log_size="${max_log_size:-1048576}"
CACHE_DIR="${SCRIPT_DIR}/.cache"

exec 9>/tmp/cloudflare-ddns.lock
if ! flock -n 9; then
    echo "$(date '+%F %T') [System] 另一个实例正在运行，退出" >> "$logfile"; exit 0
fi

log() {
    local ts; ts=$(date '+%F %T')
    echo -e "$ts $*" >> "$logfile"
    [ -t 2 ] && echo -e "$ts $*" >&2
    if [[ -f "$logfile" ]]; then
        local sz; sz=$(stat -c%s "$logfile" 2>/dev/null || stat -f%z "$logfile" 2>/dev/null || echo 0)
        if (( sz > max_log_size )); then
            local tmp; tmp=$(mktemp "${logfile}.XXXXXX")
            tail -n 100 "$logfile" > "$tmp" && mv "$tmp" "$logfile"; chmod 640 "$logfile"
        fi
    fi
}

fetch_ip() {
    local rt="$1" curl_opt ip_pattern
    local -a providers=()
    if [[ "$rt" == "AAAA" ]]; then
        curl_opt="-6"; ip_pattern='^([0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{0,4}$'
        providers=("https://v6.ident.me" "https://api6.ipify.org" "https://ipv6.icanhazip.com" "https://v6.ip.sb")
    else
        curl_opt="-4"; ip_pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
        providers=("https://v4.ident.me" "https://api.ipify.org" "https://ipv4.icanhazip.com" "https://v4.ip.sb")
    fi
    declare -A votes=()
    for url in "${providers[@]}"; do
        local raw
        raw=$(curl $curl_opt -s --max-time 5 --fail --proto '=https' --tlsv1.2 "$url" 2>/dev/null | tr -d '[:space:]' || true)
        if [[ -n "$raw" ]] && echo "$raw" | grep -qE "$ip_pattern"; then
            votes["$raw"]=$(( ${votes["$raw"]:-0} + 1 ))
        fi
    done
    local best_ip="" best=0
    for ip in "${!votes[@]}"; do
        (( votes[$ip] > best )) && best=${votes[$ip]} && best_ip="$ip"
    done
    if (( best < 2 )); then
        log "[fetch_ip] 警告: 无法从多个来源取得一致的 $rt 地址，跳过"; echo ""; return
    fi
    echo "$best_ip"
}

update_dns() {
    local token="$1" zone="$2" record="$3" type="$4" ip="$5" proxied="$6"
    local api="https://api.cloudflare.com/client/v4"
    local curl_base=(curl -s --fail --proto '=https' --tlsv1.2
        -H "Authorization: Bearer ${token}" -H "Content-Type: application/json")
    local zoneid
    zoneid=$("${curl_base[@]}" -X GET "${api}/zones?name=${zone}" 2>/dev/null | jq -r '.result[0].id // empty' || true)
    [[ -z "$zoneid" || "$zoneid" == "null" ]] && { log "[$zone] 错误: 取得 ZoneID 失败"; return 1; }
    local rec_name; rec_name=$([[ -z "$record" ]] && echo "$zone" || echo "${record}.${zone}")
    local recid
    recid=$("${curl_base[@]}" -X GET "${api}/zones/${zoneid}/dns_records?type=${type}&name=${rec_name}" 2>/dev/null | jq -r '.result[0].id // empty' || true)
    [[ -z "$recid" || "$recid" == "null" ]] && { log "[$rec_name] 错误: 取得记录 ID 失败，请先在 CF 面板创建 $type 记录"; return 1; }
    local resp success
    resp=$("${curl_base[@]}" -X PUT "${api}/zones/${zoneid}/dns_records/${recid}" \
        --data "{\"type\":\"${type}\",\"name\":\"${rec_name}\",\"content\":\"${ip}\",\"ttl\":1,\"proxied\":${proxied}}" 2>/dev/null || true)
    success=$(echo "$resp" | jq -r '.success // false')
    if [[ "$success" == "true" ]]; then
        log "[$rec_name] $type 成功更新为: $ip"
    else
        local err; err=$(echo "$resp" | jq -r '.errors[]?.message' 2>/dev/null || true)
        log "[$rec_name] 错误: $type 更新失败: ${err:-未知错误}"; return 1
    fi
}

process_group() {
    local token="$1" zone="$2" record="$3" type="$4" proxied="$5"
    [[ -z "$token" || -z "$zone" ]] && return 0
    local current_ip; current_ip=$(fetch_ip "$type")
    [[ -z "$current_ip" ]] && { log "[$zone] 错误: 获取 $type IP 失败，跳过"; return 1; }
    local cache="${CACHE_DIR}/ip_${type}_${zone}_${record:-root}.txt"
    local old_ip=""; [[ -f "$cache" ]] && old_ip=$(cat "$cache")
    [[ "$current_ip" == "$old_ip" ]] && return 0
    if update_dns "$token" "$zone" "$record" "$type" "$current_ip" "$proxied"; then
        echo "$current_ip" > "$cache" && chmod 600 "$cache" || log "[$zone] 警告: 写入缓存失败"
    fi
}

touch "$logfile"; chmod 640 "$logfile"
process_group "${apitoken1:-}" "${zonename1:-}" "${recordname1:-}" "${recordtype1:-A}"    "${proxied1:-false}"
process_group "${apitoken2:-}" "${zonename2:-}" "${recordname2:-}" "${recordtype2:-AAAA}" "${proxied2:-false}"
DDNS_EOF

chmod 700 "$DDNS_SCRIPT"
info "DDNS 脚本写入完成"

echo ""
echo ">>> 写入配置文件..."
CONF_FILE="${INSTALL_DIR}/ddns.conf"
touch "$CONF_FILE"; chmod 600 "$CONF_FILE"
cat > "$CONF_FILE" << CONF_EOF
# Cloudflare DDNS 配置文件（自动生成，请勿泄露）
# 权限必须为 600，否则脚本拒绝运行

# ── IPv4 (A 记录) ──────────────────────────────────
apitoken1="${CF_TOKEN1}"
zonename1="${ZONE_NAME1}"
recordname1="${RECORD_NAME1}"
recordtype1="A"
proxied1="${PROXIED1}"

# ── IPv6 (AAAA 记录) ───────────────────────────────
apitoken2="${CF_TOKEN2}"
zonename2="${ZONE_NAME2}"
recordname2="${RECORD_NAME2}"
recordtype2="AAAA"
proxied2="${PROXIED2}"

# ── 日志设置 ───────────────────────────────────────
logfile="cloudflare-ddns.log"
max_log_size=1048576
CONF_EOF
info "配置文件写入完成"

echo ""
echo ">>> 设置定时任务..."
CRON_JOB="${CRON_INTERVAL} /bin/bash ${DDNS_SCRIPT}"
if crontab -l 2>/dev/null | grep -qF "$DDNS_SCRIPT"; then
    warn "定时任务已存在，跳过"
else
    ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
    info "定时任务添加完成"
fi

echo ""
echo ">>> 执行测试运行..."
bash "$DDNS_SCRIPT" && info "测试运行成功" || warn "测试运行失败，请查看日志: $LOG_FILE"

echo ""
echo -e "${BOLD}${GREEN}══════════════ 安装完成 ══════════════${NC}"
echo ""
echo -e "  查看日志:  ${YELLOW}tail -f ${LOG_FILE}${NC}"
echo -e "  手动执行:  ${YELLOW}bash ${DDNS_SCRIPT}${NC}"
echo -e "  查看任务:  ${YELLOW}crontab -l${NC}"
echo -e "  卸载方式:  ${YELLOW}crontab -l | grep -v ddns.sh | crontab -${NC}"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════${NC}"
