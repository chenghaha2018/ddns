#!/usr/bin/env bash
set -euo pipefail
# ==================================================
# 服务器管理合集脚本
# 包含：1. VLESS+REALITY  2. BBR+系统优化  3. DDNS
# 用法: bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/server-tools/main/setup.sh)
# ==================================================

# ── 颜色 ──────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }
title() { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}\n"; }
ask()   { echo -ne "${YELLOW}?${NC}  $*"; }

require_root() {
    [ "${EUID}" -eq 0 ] || error "请使用 root 运行此脚本。"
}

press_enter() {
    echo ""
    ask "按 Enter 继续..."
    read -r
}

# ══════════════════════════════════════════════════
# 主菜单
# ══════════════════════════════════════════════════
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║          服务器管理合集  v1.0.0               ║"
    echo "  ║          Server Setup Toolkit                 ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}1.${NC}  🚀  安装 / 管理 VLESS + REALITY"
    echo -e "  ${BOLD}2.${NC}  ⚡  开启 BBR + 系统网络优化"
    echo -e "  ${BOLD}3.${NC}  🌐  配置 Cloudflare DDNS"
    echo ""
    echo -e "  ${BOLD}0.${NC}  退出"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ask "请选择功能 [0-3]: "
    read -r MENU_CHOICE
}

# ══════════════════════════════════════════════════
# 功能 1：VLESS + REALITY
# ══════════════════════════════════════════════════

# ── 变量 ──────────────────────────────────────────
SCRIPT_VERSION='2.0.0'
XRAY_BIN='/usr/local/bin/xray'
XRAY_ETC='/etc/xray'
XRAY_SHARE='/usr/local/share/xray'
CONFIG_FILE='/etc/xray/config.json'
META_FILE='/etc/xray/vless-reality.meta'
SERVICE_FILE='/etc/systemd/system/xray.service'
INFO_FILE='/root/vless_reality_info.txt'
QR_FILE='/root/vless_reality_qr.png'
SERVICE_NAME='xray'

DEFAULT_TLS_CANDIDATES=(
    # Microsoft 二三级域名
    login.microsoft.com
    account.microsoft.com
    teams.microsoft.com
    azure.microsoft.com
    login.live.com
    # Apple 二三级域名
    icloud.com
    developer.apple.com
    support.apple.com
    itunes.apple.com
    # Bing 二三级域名
    cn.bing.com
    global.bing.com
    # Amazon 二三级域名
    aws.amazon.com
    s3.amazonaws.com
    # Cloudflare 二三级域名
    dash.cloudflare.com
    workers.cloudflare.com
    # Oracle 二三级域名
    cloud.oracle.com
    signup.oracle.com
)

vless_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║          VLESS + REALITY 管理                 ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 显示当前状态
    if systemctl is-active --quiet xray 2>/dev/null; then
        echo -e "  状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  状态: ${RED}● 未运行${NC}"
    fi
    [ -f "$INFO_FILE" ] && echo -e "  配置: ${GREEN}已安装${NC}" || echo -e "  配置: ${YELLOW}未安装${NC}"
    echo ""
    echo -e "  ${BOLD}1.${NC}  安装 / 重装"
    echo -e "  ${BOLD}2.${NC}  查看连接信息"
    echo -e "  ${BOLD}3.${NC}  启动 / 停止 / 重启服务"
    echo -e "  ${BOLD}4.${NC}  卸载"
    echo -e "  ${BOLD}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ask "请选择 [0-4]: "
    read -r V_CHOICE

    case "$V_CHOICE" in
        1) vless_install_interactive ;;
        2) vless_show_info ;;
        3) vless_service_menu ;;
        4) vless_uninstall_interactive ;;
        0) return ;;
        *) warn "无效选项"; sleep 1; vless_menu ;;
    esac
}

vless_show_info() {
    title "VLESS + REALITY 连接信息"
    if [ -f "$INFO_FILE" ]; then
        cat "$INFO_FILE"
        echo ""
        if command -v qrencode &>/dev/null && [ -f "$INFO_FILE" ]; then
            local url
            url=$(grep '^vless://' "$INFO_FILE" 2>/dev/null || true)
            if [ -n "$url" ]; then
                echo -e "${CYAN}━━━ 二维码 ━━━${NC}"
                qrencode -t ANSIUTF8 -m 2 -- "$url" 2>/dev/null || true
            fi
        fi
    else
        warn "未找到连接信息，请先安装。"
    fi
    press_enter
    vless_menu
}

vless_service_menu() {
    title "服务管理"
    echo -e "  ${BOLD}1.${NC}  启动"
    echo -e "  ${BOLD}2.${NC}  停止"
    echo -e "  ${BOLD}3.${NC}  重启"
    echo -e "  ${BOLD}4.${NC}  查看状态 / 日志"
    echo -e "  ${BOLD}0.${NC}  返回"
    echo ""
    ask "请选择 [0-4]: "
    read -r SC
    case "$SC" in
        1) systemctl start xray && info "已启动" || warn "启动失败" ;;
        2) systemctl stop xray && info "已停止" ;;
        3) systemctl restart xray && info "已重启" || warn "重启失败" ;;
        4) systemctl status xray --no-pager; echo ""; journalctl -u xray -n 30 --no-pager ;;
        0) vless_menu; return ;;
    esac
    press_enter
    vless_menu
}

# ── 辅助函数 ──────────────────────────────────────
v_log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
v_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
v_err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
v_die()  { v_err "$*"; exit 1; }

validate_port()        { [[ "$1" =~ ^[0-9]{1,5}$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
validate_server_name() { [[ "$1" =~ ^[A-Za-z0-9.-]+$ ]]; }
validate_dest()        { [[ "$1" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || [[ "$1" =~ ^\[[0-9a-fA-F:]+\]:[0-9]{1,5}$ ]]; }
validate_uuid()        { [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; }

format_uri_host() {
    local h="$1"
    [[ "$h" == *:* ]] && [[ "$h" != \[*\] ]] && printf '[%s]' "$h" || printf '%s' "$h"
}

slugify_remark() {
    local s; s="$(printf '%s' "$1" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')"
    [ -z "$s" ] && s='vless-reality'
    printf '%s' "$s"
}

port_is_free() {
    ss -Hltn "( sport = :$1 )" 2>/dev/null | grep -q . && return 1
    ss -Hltn6 "( sport = :$1 )" 2>/dev/null | grep -q . && return 1
    return 0
}

pick_random_free_port() {
    for p in $(shuf -i 20000-40000 -n 256); do
        port_is_free "$p" && printf '%s' "$p" && return 0
    done
    return 1
}

tls_host_ok() {
    getent ahosts "$1" >/dev/null 2>&1 || return 1
    timeout 8 openssl s_client -servername "$1" -connect "${1}:443" -brief </dev/null >/dev/null 2>&1 || return 1
    timeout 6 curl -fsSL --connect-timeout 4 --max-time 6 -o /dev/null "https://${1}/" >/dev/null 2>&1 || return 1
    return 0
}

pick_random_tls_host() {
    local ok_hosts=() host
    while read -r host; do
        [ -n "$host" ] || continue
        if tls_host_ok "$host"; then
            ok_hosts+=("$host")
            [ "${#ok_hosts[@]}" -ge 4 ] && break
        fi
    done < <(printf '%s\n' "${DEFAULT_TLS_CANDIDATES[@]}" | shuf)
    [ "${#ok_hosts[@]}" -gt 0 ] || return 1
    printf '%s' "${ok_hosts[$((RANDOM % ${#ok_hosts[@]}))]}"
}

get_public_ipv4() {
    local ip
    ip="$(curl -4 -fsSL --connect-timeout 5 https://api.ipify.org 2>/dev/null || true)"
    [ -z "$ip" ] && ip="$(curl -4 -fsSL --connect-timeout 5 https://ipv4.icanhazip.com 2>/dev/null || true)"
    printf '%s' "$ip"
}

get_public_ipv6() {
    local ip
    ip="$(curl -6 -fsSL --connect-timeout 5 https://api6.ipify.org 2>/dev/null || true)"
    [ -z "$ip" ] && ip="$(curl -6 -fsSL --connect-timeout 5 https://ipv6.icanhazip.com 2>/dev/null || true)"
    printf '%s' "$ip"
}

detect_arch() {
    local arch; arch="$(dpkg --print-architecture)"
    case "$arch" in
        amd64) printf 'Xray-linux-64.zip' ;;
        arm64) printf 'Xray-linux-arm64-v8a.zip' ;;
        *) v_die "不支持的架构: $arch" ;;
    esac
}

# ── [修复] 从 xray x25519 输出中提取密钥 ──────────
# 兼容多种 xray 版本输出格式：
#   旧版: "Private key: xxx" / "Public key: xxx"
#   新版(26.x): "PrivateKey: xxx" / "Password (PublicKey): xxx"
parse_xray_private_key() {
    printf '%s\n' "$1" \
        | grep -i 'privatekey\|private key' \
        | grep -iv 'public' \
        | sed 's/^[^:]*://;s/^[[:space:]]*//;s/[[:space:]]*$//'
}

parse_xray_public_key() {
    printf '%s\n' "$1" \
        | grep -i 'publickey\|public key\|password' \
        | sed 's/^[^:]*://;s/^[[:space:]]*//;s/[[:space:]]*$//'
}

vless_install_interactive() {
    title "安装 VLESS + REALITY"

    # 检测已有安装
    if [ -f "$CONFIG_FILE" ] || [ -x "$XRAY_BIN" ]; then
        warn "检测到已有安装！"
        ask "是否覆盖重装？(y/n) [默认: n]: "
        read -r ans; ans="${ans:-n}"
        [[ "$ans" =~ ^[Yy] ]] || { warn "已取消"; press_enter; vless_menu; return; }
    fi

    # ── 全自动参数（无需用户输入）──────────────────
    # 端口：随机空闲端口
    local PORT_IN; PORT_IN="$(pick_random_free_port)"

    # SNI：联网测试候选列表，选出可用域名
    v_log "自动探测可用 TLS 域名，请稍候..."
    local SNI_IN
    if SNI_IN="$(pick_random_tls_host 2>/dev/null)"; then
        v_log "探测到可用 SNI: ${SNI_IN}"
    else
        SNI_IN='www.microsoft.com'
        warn "自动探测失败，回退到: ${SNI_IN}"
    fi

    # Dest：跟随 SNI
    local DEST_IN="${SNI_IN}:443"

    # 连接地址：优先独立公网 IPv4，否则 IPv6
    local v4; v4="$(get_public_ipv4)"
    local v6; v6="$(get_public_ipv6)"
    local IP_IN="$v4"
    [ -z "$IP_IN" ] && IP_IN="$v6"
    [ -z "$IP_IN" ] && IP_IN="YOUR_SERVER_IP"

    # 备注：固定默认值
    local REMARK_IN='vless-reality'

    # ── 显示配置摘要，确认后再安装 ──────────────────
    echo ""
    echo -e "${BOLD}━━━ 自动配置摘要（直接回车确认）━━━${NC}"
    echo -e "  端口:   ${BOLD}${PORT_IN}${NC}"
    echo -e "  SNI:    ${BOLD}${SNI_IN}${NC}"
    echo -e "  Dest:   ${BOLD}${DEST_IN}${NC}"
    echo -e "  地址:   ${BOLD}${IP_IN}${NC}"
    echo -e "  备注:   ${BOLD}${REMARK_IN}${NC}"
    echo ""
    echo -e "  ${YELLOW}如需修改某项，请输入对应数字，否则直接回车开始安装:${NC}"
    echo -e "  1) 修改端口  2) 修改SNI  3) 修改连接地址  4) 修改备注"
    echo ""
    ask "选择 [直接回车=开始安装]: "
    read -r MODIFY_C

    case "${MODIFY_C:-}" in
        1)
            ask "监听端口: "; read -r PORT_IN
            validate_port "$PORT_IN" || { warn "端口格式错误"; press_enter; vless_install_interactive; return; }
            ;;
        2)
            ask "SNI 域名: "; read -r SNI_IN
            validate_server_name "$SNI_IN" || { warn "域名格式错误"; press_enter; vless_install_interactive; return; }
            DEST_IN="${SNI_IN}:443"
            ;;
        3)
            ask "连接地址: "; read -r IP_IN
            ;;
        4)
            ask "节点备注: "; read -r REMARK_IN
            REMARK_IN="$(slugify_remark "$REMARK_IN")"
            ;;
        '')
            : # 直接回车，使用自动配置
            ;;
        *)
            warn "无效选项，使用自动配置"
            ;;
    esac

    echo ""
    ask "确认安装？(y/n) [默认: y]: "
    read -r CONFIRM; CONFIRM="${CONFIRM:-y}"
    [[ "$CONFIRM" =~ ^[Yy] ]] || { warn "已取消"; press_enter; vless_menu; return; }

    # ── 执行安装 ──
    echo ""
    v_log "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y -qq
    apt-get install -y -qq curl unzip openssl ca-certificates tar iproute2 procps
    apt-get install -y -qq qrencode 2>/dev/null || warn "qrencode 安装失败，将跳过二维码"

    v_log "下载 Xray..."
    local pkg; pkg="$(detect_arch)"
    local tmpdir; tmpdir="$(mktemp -d)"
    curl -fL --retry 3 --connect-timeout 15 \
        "https://github.com/XTLS/Xray-core/releases/latest/download/${pkg}" \
        -o "$tmpdir/xray.zip"
    unzip -qo "$tmpdir/xray.zip" -d "$tmpdir/xray"
    [ -f "$tmpdir/xray/xray" ] || { rm -rf "$tmpdir"; v_die "Xray 解压失败"; }
    install -d -m 755 "$XRAY_SHARE" "$XRAY_ETC"
    install -m 755 "$tmpdir/xray/xray" "$XRAY_BIN"
    [ -f "$tmpdir/xray/geoip.dat" ]   && install -m 644 "$tmpdir/xray/geoip.dat"   "$XRAY_SHARE/" || true
    [ -f "$tmpdir/xray/geosite.dat" ] && install -m 644 "$tmpdir/xray/geosite.dat" "$XRAY_SHARE/" || true
    rm -rf "$tmpdir"

    # ── [修复] 生成密钥 ────────────────────────────
    v_log "生成密钥..."
    local UUID; UUID="$("$XRAY_BIN" uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)"

    # 先捕获原始输出，便于调试
    local key_out
    key_out="$("$XRAY_BIN" x25519 2>&1)" || true

    # 使用健壮的 grep+sed 解析，兼容各版本 xray 输出格式
    local PRIVATE_KEY; PRIVATE_KEY="$(parse_xray_private_key "$key_out")"
    local PUBLIC_KEY;  PUBLIC_KEY="$(parse_xray_public_key  "$key_out")"

    # 若解析失败则打印原始输出方便排查，再退出
    if [ -z "$PRIVATE_KEY" ]; then
        v_err "生成私钥失败，xray x25519 原始输出如下："
        printf '%s\n' "$key_out" >&2
        v_die "请检查 xray 二进制是否完整（运行 ${XRAY_BIN} version）"
    fi
    if [ -z "$PUBLIC_KEY" ]; then
        v_err "生成公钥失败，xray x25519 原始输出如下："
        printf '%s\n' "$key_out" >&2
        v_die "请检查 xray 二进制是否完整（运行 ${XRAY_BIN} version）"
    fi

    local SHORT_ID; SHORT_ID="$(openssl rand -hex 8)"

    v_log "写入配置..."
    [ -f "$CONFIG_FILE" ] && cp -a "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    cat > "$CONFIG_FILE" << CFGJSON
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [{ "type": "field", "protocol": ["bittorrent"], "outboundTag": "block" }]
  },
  "inbounds": [
    {
      "tag": "vless-in-v4", "listen": "0.0.0.0", "port": ${PORT_IN},
      "protocol": "vless",
      "settings": { "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision", "email": "default" }], "decryption": "none" },
      "streamSettings": {
        "network": "tcp", "security": "reality",
        "realitySettings": {
          "show": false, "dest": "${DEST_IN}", "xver": 0,
          "serverNames": ["${SNI_IN}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
    },
    {
      "tag": "vless-in-v6", "listen": "::", "port": ${PORT_IN},
      "protocol": "vless",
      "settings": { "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision", "email": "default" }], "decryption": "none" },
      "streamSettings": {
        "network": "tcp", "security": "reality",
        "realitySettings": {
          "show": false, "dest": "${DEST_IN}", "xver": 0,
          "serverNames": ["${SNI_IN}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
CFGJSON
    chmod 600 "$CONFIG_FILE"

    cat > "$SERVICE_FILE" << 'SVC'
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
SVC

    "$XRAY_BIN" run -test -config "$CONFIG_FILE" >/dev/null || v_die "配置验证失败"

    # UFW
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q 'active'; then
        ufw allow "${PORT_IN}/tcp" >/dev/null 2>&1 && v_log "UFW 已放行 TCP ${PORT_IN}" || warn "UFW 放行失败，请手动操作"
    fi

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null
    systemctl restart "$SERVICE_NAME"
    sleep 2

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        journalctl -u "$SERVICE_NAME" -n 30 --no-pager
        v_die "Xray 启动失败，请查看以上日志"
    fi

    # 写入信息文件
    local uri_host; uri_host="$(format_uri_host "$IP_IN")"
    local VLESS_URL="vless://${UUID}@${uri_host}:${PORT_IN}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_IN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#${REMARK_IN}"

    cat > "$INFO_FILE" << INFO
=== VLESS + REALITY 连接信息 ===
地址: ${IP_IN}
端口: ${PORT_IN}
UUID: ${UUID}
Flow: xtls-rprx-vision
Security: reality
SNI: ${SNI_IN}
Public Key: ${PUBLIC_KEY}
Short ID: ${SHORT_ID}
Fingerprint: chrome

=== VLESS URL ===
${VLESS_URL}
INFO
    chmod 600 "$INFO_FILE"

    # 显示结果
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      VLESS + REALITY 安装完成 ✅             ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}${VLESS_URL}${NC}"
    echo ""
    if command -v qrencode &>/dev/null; then
        qrencode -t ANSIUTF8 -m 2 -- "$VLESS_URL" 2>/dev/null || true
    fi
    echo -e "  地址: ${BOLD}${IP_IN}${NC}  端口: ${BOLD}${PORT_IN}${NC}"
    echo -e "  SNI:  ${BOLD}${SNI_IN}${NC}"
    echo -e "  PBK:  ${BOLD}${PUBLIC_KEY}${NC}"
    echo -e "  SID:  ${BOLD}${SHORT_ID}${NC}"
    echo ""
    echo "注意: 请确认云厂商安全组已放行 TCP ${PORT_IN}"

    press_enter
    vless_menu
}

vless_uninstall_interactive() {
    title "卸载 VLESS + REALITY"
    ask "是否彻底卸载（含配置和二进制）？(y/n) [默认: n]: "
    read -r PURGE_ANS; PURGE_ANS="${PURGE_ANS:-n}"

    ask "确认卸载？(y/n) [默认: n]: "
    read -r CONF_ANS; CONF_ANS="${CONF_ANS:-n}"
    [[ "$CONF_ANS" =~ ^[Yy] ]] || { warn "已取消"; press_enter; vless_menu; return; }

    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload 2>/dev/null || true

    if [[ "$PURGE_ANS" =~ ^[Yy] ]]; then
        rm -f "$XRAY_BIN" "$CONFIG_FILE" "$META_FILE" "$INFO_FILE" "$QR_FILE"
        rm -f "$XRAY_SHARE/geoip.dat" "$XRAY_SHARE/geosite.dat"
        rmdir "$XRAY_ETC" "$XRAY_SHARE" 2>/dev/null || true
        info "已彻底卸载"
    else
        info "服务已停止，配置文件已保留"
    fi

    press_enter
    vless_menu
}

# ══════════════════════════════════════════════════
# 功能 2：BBR + 系统优化
# ══════════════════════════════════════════════════
bbr_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║          BBR + 系统网络优化                   ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 当前状态
    local current_cc; current_cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '未知')"
    local current_qd; current_qd="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo '未知')"
    local kernel_ver; kernel_ver="$(uname -r)"
    echo -e "  内核版本:     ${BOLD}${kernel_ver}${NC}"
    echo -e "  拥塞控制:     ${BOLD}${current_cc}${NC}"
    echo -e "  队列调度:     ${BOLD}${current_qd}${NC}"
    echo ""
    echo -e "  ${BOLD}1.${NC}  一键开启 BBR + fq"
    echo -e "  ${BOLD}2.${NC}  应用全套网络参数优化"
    echo -e "  ${BOLD}3.${NC}  查看当前网络参数"
    echo -e "  ${BOLD}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ask "请选择 [0-3]: "
    read -r B_CHOICE

    case "$B_CHOICE" in
        1) bbr_enable ;;
        2) bbr_full_optimize ;;
        3) bbr_show_params ;;
        0) return ;;
        *) warn "无效选项"; sleep 1; bbr_menu ;;
    esac
}

bbr_enable() {
    title "开启 BBR"

    # 检查内核版本 >= 4.9
    local kver_major kver_minor
    kver_major=$(uname -r | cut -d. -f1)
    kver_minor=$(uname -r | cut -d. -f2)
    if [ "$kver_major" -lt 4 ] || ([ "$kver_major" -eq 4 ] && [ "$kver_minor" -lt 9 ]); then
        warn "当前内核 $(uname -r) 低于 4.9，BBR 可能不支持"
        warn "建议升级内核后再试"
        press_enter; bbr_menu; return
    fi

    # 检查是否支持 BBR
    if ! modprobe tcp_bbr 2>/dev/null; then
        warn "加载 tcp_bbr 模块失败，内核可能不支持 BBR"
    fi

    # 写入 sysctl
    cat >> /etc/sysctl.conf << 'SYSCTL'

# BBR 配置（由 setup.sh 添加）
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
SYSCTL

    sysctl -p >/dev/null 2>&1

    local cc; cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
    if [ "$cc" = "bbr" ]; then
        info "BBR 已成功开启！"
        echo -e "  拥塞控制: ${GREEN}${BOLD}bbr${NC}"
        echo -e "  队列调度: ${GREEN}${BOLD}fq${NC}"
    else
        warn "BBR 设置可能未生效，当前值: ${cc}"
        warn "部分 VPS 需要重启后才能生效"
    fi

    press_enter
    bbr_menu
}

bbr_full_optimize() {
    title "全套网络参数优化"
    warn "此操作将修改 /etc/sysctl.conf，是否继续？"
    ask "确认 (y/n) [默认: n]: "
    read -r ANS; ANS="${ANS:-n}"
    [[ "$ANS" =~ ^[Yy] ]] || { warn "已取消"; press_enter; bbr_menu; return; }

    # 备份
    cp /etc/sysctl.conf "/etc/sysctl.conf.bak.$(date +%Y%m%d_%H%M%S)"
    info "已备份原配置"

    cat >> /etc/sysctl.conf << 'SYSCTL'

# ── 网络优化（由 setup.sh 添加）─────────────────────
# BBR
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP 缓冲区
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.netdev_max_backlog=250000

# TCP 连接优化
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=5000

# 端口范围
net.ipv4.ip_local_port_range=10000 65000

# 文件描述符
fs.file-max=1000000
SYSCTL

    sysctl -p >/dev/null 2>&1
    info "全套优化已应用！"
    echo ""
    sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc net.core.rmem_max net.core.wmem_max

    press_enter
    bbr_menu
}

bbr_show_params() {
    title "当前网络参数"
    echo -e "${BOLD}拥塞控制相关:${NC}"
    sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc 2>/dev/null
    echo ""
    echo -e "${BOLD}缓冲区:${NC}"
    sysctl net.core.rmem_max net.core.wmem_max 2>/dev/null
    echo ""
    echo -e "${BOLD}内核版本:${NC} $(uname -r)"
    echo ""
    echo -e "${BOLD}可用拥塞控制算法:${NC}"
    cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo "无法读取"

    press_enter
    bbr_menu
}

# ══════════════════════════════════════════════════
# 功能 3：Cloudflare DDNS
# ══════════════════════════════════════════════════
DDNS_INSTALL_DIR="/root/ddns"
DDNS_SCRIPT="${DDNS_INSTALL_DIR}/ddns.sh"
DDNS_CONF="${DDNS_INSTALL_DIR}/ddns.conf"
DDNS_LOG="${DDNS_INSTALL_DIR}/cloudflare-ddns.log"

ddns_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║          Cloudflare DDNS 管理                 ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 状态
    if [ -f "$DDNS_SCRIPT" ]; then
        echo -e "  状态: ${GREEN}已安装${NC}"
        crontab -l 2>/dev/null | grep -q "ddns.sh" && \
            echo -e "  定时: ${GREEN}已启用${NC}" || echo -e "  定时: ${YELLOW}未设置${NC}"
    else
        echo -e "  状态: ${YELLOW}未安装${NC}"
    fi
    echo ""
    echo -e "  ${BOLD}1.${NC}  安装 / 重新配置"
    echo -e "  ${BOLD}2.${NC}  手动执行一次"
    echo -e "  ${BOLD}3.${NC}  查看日志"
    echo -e "  ${BOLD}4.${NC}  卸载"
    echo -e "  ${BOLD}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ask "请选择 [0-4]: "
    read -r D_CHOICE

    case "$D_CHOICE" in
        1) ddns_install_interactive ;;
        2) ddns_run_once ;;
        3) ddns_show_log ;;
        4) ddns_uninstall ;;
        0) return ;;
        *) warn "无效选项"; sleep 1; ddns_menu ;;
    esac
}

ddns_install_interactive() {
    title "配置 Cloudflare DDNS"

    # ── 记录类型 ──
    echo "  选择 DNS 记录类型："
    echo "  1) IPv4 (A 记录)       ← 默认"
    echo "  2) IPv6 (AAAA 记录)"
    echo "  3) 双栈 IPv4 + IPv6"
    echo ""
    ask "请选择 [默认: 1]: "
    read -r TYPE_C; TYPE_C="${TYPE_C:-1}"
    local ENABLE_V4=true ENABLE_V6=false
    case "$TYPE_C" in
        1) ENABLE_V4=true;  ENABLE_V6=false ;;
        2) ENABLE_V4=false; ENABLE_V6=true  ;;
        3) ENABLE_V4=true;  ENABLE_V6=true  ;;
        *) warn "无效选项，使用 IPv4"; ENABLE_V4=true; ENABLE_V6=false ;;
    esac

    # ── IPv4 配置 ──
    local CF_TOKEN1="" ZONE_NAME1="" RECORD_NAME1="" PROXIED1="false"
    local CF_TOKEN2="" ZONE_NAME2="" RECORD_NAME2="" PROXIED2="false"

    if [ "$ENABLE_V4" = true ]; then
        echo ""
        echo -e "${BOLD}IPv4 (A 记录) 配置:${NC}"
        ask "API Token（输入不显示）: "
        read -rs CF_TOKEN1; echo ""
        [ -n "$CF_TOKEN1" ] || { warn "Token 不能为空"; press_enter; ddns_install_interactive; return; }
        ask "根域名（如 111288.xyz）: "
        read -r ZONE_NAME1
        [ -n "$ZONE_NAME1" ] || { warn "根域名不能为空"; press_enter; ddns_install_interactive; return; }
        ask "子域名前缀（如 cmhk，留空更新根域名）: "
        read -r RECORD_NAME1
    fi

    if [ "$ENABLE_V6" = true ]; then
        echo ""
        echo -e "${BOLD}IPv6 (AAAA 记录) 配置:${NC}"
        if [ "$ENABLE_V4" = true ]; then
            ask "与 IPv4 使用相同 Token 和域名？(y/n) [默认: y]: "
            read -r SAME_ANS; SAME_ANS="${SAME_ANS:-y}"
            if [[ "$SAME_ANS" =~ ^[Yy] ]]; then
                CF_TOKEN2="$CF_TOKEN1"
                ZONE_NAME2="$ZONE_NAME1"
                ask "IPv6 子域名前缀 [默认: ${RECORD_NAME1:-根域名}]: "
                read -r RECORD_NAME2; RECORD_NAME2="${RECORD_NAME2:-$RECORD_NAME1}"
            else
                ask "IPv6 API Token（输入不显示）: "
                read -rs CF_TOKEN2; echo ""
                ask "IPv6 根域名: "; read -r ZONE_NAME2
                ask "IPv6 子域名前缀: "; read -r RECORD_NAME2
            fi
        else
            ask "API Token（输入不显示）: "
            read -rs CF_TOKEN2; echo ""
            ask "根域名: "; read -r ZONE_NAME2
            ask "子域名前缀: "; read -r RECORD_NAME2
        fi
    fi

    # ── 定时间隔 ──
    echo ""
    echo "  定时间隔："
    echo "  1) 每 5 分钟"
    echo "  2) 每 10 分钟  ← 推荐"
    echo "  3) 每 30 分钟"
    echo "  4) 每小时"
    ask "请选择 [默认: 2]: "
    read -r CRON_C; CRON_C="${CRON_C:-2}"
    local CRON_INTERVAL
    case "$CRON_C" in
        1) CRON_INTERVAL="*/5 * * * *"  ;;
        2) CRON_INTERVAL="*/10 * * * *" ;;
        3) CRON_INTERVAL="*/30 * * * *" ;;
        4) CRON_INTERVAL="0 * * * *"    ;;
        *) CRON_INTERVAL="*/10 * * * *" ;;
    esac

    # ── 确认 ──
    echo ""
    echo -e "${BOLD}━━━ 配置确认 ━━━${NC}"
    [ "$ENABLE_V4" = true ] && echo -e "  IPv4: ${BOLD}${RECORD_NAME1:+${RECORD_NAME1}.}${ZONE_NAME1}${NC}"
    [ "$ENABLE_V6" = true ] && echo -e "  IPv6: ${BOLD}${RECORD_NAME2:+${RECORD_NAME2}.}${ZONE_NAME2}${NC}"
    echo -e "  间隔: ${BOLD}${CRON_INTERVAL}${NC}"
    echo ""
    ask "确认安装？(y/n) [默认: y]: "
    read -r CONF; CONF="${CONF:-y}"
    [[ "$CONF" =~ ^[Yy] ]] || { warn "已取消"; press_enter; ddns_menu; return; }

    # ── 检查依赖 ──
    for dep in curl jq flock; do
        if ! command -v "$dep" &>/dev/null; then
            apt-get install -y -qq "$dep" && info "$dep 已安装" || { warn "$dep 安装失败"; press_enter; ddns_menu; return; }
        fi
    done

    # ── 创建目录 ──
    mkdir -p "${DDNS_INSTALL_DIR}/.cache"
    chmod 700 "${DDNS_INSTALL_DIR}/.cache"

    # ── 写入 DDNS 主脚本 ──
    cat > "$DDNS_SCRIPT" << 'DDNS_BODY'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/ddns.conf"
if [[ ! -f "$CONF" ]]; then echo "错误: 找不到 $CONF"; exit 1; fi
local_perm=$(stat -c%a "$CONF" 2>/dev/null || echo "600")
if [[ "$local_perm" != "600" && "$local_perm" != "400" ]]; then
    echo "错误: 配置文件权限不安全，请执行: chmod 600 \"$CONF\""; exit 1
fi
source "$CONF"
logfile="${logfile:-${SCRIPT_DIR}/cloudflare-ddns.log}"
max_log_size="${max_log_size:-1048576}"
CACHE_DIR="${SCRIPT_DIR}/.cache"
exec 9>/tmp/cloudflare-ddns.lock
if ! flock -n 9; then echo "$(date '+%F %T') [System] 另一个实例正在运行" >> "$logfile"; exit 0; fi
log() {
    local ts; ts=$(date '+%F %T')
    echo -e "$ts $*" >> "$logfile"
    [ -t 2 ] && echo -e "$ts $*" >&2
    if [[ -f "$logfile" ]]; then
        local sz; sz=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
        if (( sz > max_log_size )); then
            local tmp; tmp=$(mktemp "${logfile}.XXXXXX")
            tail -n 100 "$logfile" > "$tmp" && mv "$tmp" "$logfile"; chmod 640 "$logfile"
        fi
    fi
}
fetch_ip() {
    local rt="$1" curl_opt ip_pattern; local -a providers=()
    if [[ "$rt" == "AAAA" ]]; then
        curl_opt="-6"; ip_pattern='^([0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{0,4}$'
        providers=("https://v6.ident.me" "https://api6.ipify.org" "https://ipv6.icanhazip.com" "https://v6.ip.sb")
    else
        curl_opt="-4"; ip_pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
        providers=("https://v4.ident.me" "https://api.ipify.org" "https://ipv4.icanhazip.com" "https://v4.ip.sb")
    fi
    declare -A votes=()
    for url in "${providers[@]}"; do
        local raw; raw=$(curl $curl_opt -s --max-time 5 --fail --proto '=https' --tlsv1.2 "$url" 2>/dev/null | tr -d '[:space:]' || true)
        if [[ -n "$raw" ]] && echo "$raw" | grep -qE "$ip_pattern"; then votes["$raw"]=$(( ${votes["$raw"]:-0} + 1 )); fi
    done
    local best_ip="" best=0
    for ip in "${!votes[@]}"; do (( votes[$ip] > best )) && best=${votes[$ip]} && best_ip="$ip"; done
    if (( best < 2 )); then log "[fetch_ip] 警告: 无法从多个来源取得一致的 $rt 地址，跳过"; echo ""; return; fi
    echo "$best_ip"
}
update_dns() {
    local token="$1" zone="$2" record="$3" type="$4" ip="$5" proxied="$6"
    local api="https://api.cloudflare.com/client/v4"
    local curl_base=(curl -s --fail --proto '=https' --tlsv1.2 -H "Authorization: Bearer ${token}" -H "Content-Type: application/json")
    local zoneid; zoneid=$("${curl_base[@]}" -X GET "${api}/zones?name=${zone}" 2>/dev/null | jq -r '.result[0].id // empty' || true)
    [[ -z "$zoneid" || "$zoneid" == "null" ]] && { log "[$zone] 错误: 取得 ZoneID 失败"; return 1; }
    local rec_name; rec_name=$([[ -z "$record" ]] && echo "$zone" || echo "${record}.${zone}")
    local recid; recid=$("${curl_base[@]}" -X GET "${api}/zones/${zoneid}/dns_records?type=${type}&name=${rec_name}" 2>/dev/null | jq -r '.result[0].id // empty' || true)
    [[ -z "$recid" || "$recid" == "null" ]] && { log "[$rec_name] 错误: 取得记录 ID 失败，请先在 CF 面板创建 $type 记录"; return 1; }
    local resp; resp=$("${curl_base[@]}" -X PUT "${api}/zones/${zoneid}/dns_records/${recid}" \
        --data "{\"type\":\"${type}\",\"name\":\"${rec_name}\",\"content\":\"${ip}\",\"ttl\":1,\"proxied\":${proxied}}" 2>/dev/null || true)
    local success; success=$(echo "$resp" | jq -r '.success // false')
    if [[ "$success" == "true" ]]; then log "[$rec_name] $type 成功更新为: $ip"
    else local err; err=$(echo "$resp" | jq -r '.errors[]?.message' 2>/dev/null || true); log "[$rec_name] 错误: $type 更新失败: ${err:-未知}"; return 1; fi
}
process_group() {
    local token="$1" zone="$2" record="$3" type="$4" proxied="$5"
    [[ -z "$token" || -z "$zone" ]] && return 0
    local current_ip; current_ip=$(fetch_ip "$type")
    [[ -z "$current_ip" ]] && { log "[$zone] 错误: 获取 $type IP 失败"; return 1; }
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
DDNS_BODY
    chmod 700 "$DDNS_SCRIPT"

    # ── 写入配置 ──
    touch "$DDNS_CONF"; chmod 600 "$DDNS_CONF"
    cat > "$DDNS_CONF" << DDNS_CONF_EOF
# Cloudflare DDNS 配置文件（权限必须为 600）
apitoken1="${CF_TOKEN1}"
zonename1="${ZONE_NAME1}"
recordname1="${RECORD_NAME1}"
recordtype1="A"
proxied1="${PROXIED1}"

apitoken2="${CF_TOKEN2}"
zonename2="${ZONE_NAME2}"
recordname2="${RECORD_NAME2}"
recordtype2="AAAA"
proxied2="${PROXIED2}"

logfile="cloudflare-ddns.log"
max_log_size=1048576
DDNS_CONF_EOF

    # ── 设置 cron ──
    local CRON_JOB="${CRON_INTERVAL} /bin/bash ${DDNS_SCRIPT}"
    if crontab -l 2>/dev/null | grep -qF "ddns.sh"; then
        # 替换旧的
        crontab -l 2>/dev/null | grep -v "ddns.sh" | { cat; echo "$CRON_JOB"; } | crontab -
        warn "已更新现有定时任务"
    else
        ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
        info "定时任务已添加"
    fi

    # ── 测试运行 ──
    echo ""
    info "执行测试运行..."
    bash "$DDNS_SCRIPT" && info "测试成功！" || warn "测试运行失败，请查看日志: $DDNS_LOG"

    echo ""
    info "DDNS 安装完成！"
    echo -e "  查看日志: ${BOLD}tail -f ${DDNS_LOG}${NC}"

    press_enter
    ddns_menu
}

ddns_run_once() {
    title "手动执行 DDNS"
    if [ -f "$DDNS_SCRIPT" ]; then
        bash "$DDNS_SCRIPT" && info "执行成功" || warn "执行失败，请查看日志"
    else
        warn "DDNS 未安装，请先安装"
    fi
    press_enter
    ddns_menu
}

ddns_show_log() {
    title "DDNS 日志（最近 50 行）"
    if [ -f "$DDNS_LOG" ]; then
        tail -n 50 "$DDNS_LOG"
    else
        warn "日志文件不存在，可能尚未运行过"
    fi
    press_enter
    ddns_menu
}

ddns_uninstall() {
    title "卸载 DDNS"
    ask "确认卸载 DDNS？(y/n) [默认: n]: "
    read -r ANS; ANS="${ANS:-n}"
    [[ "$ANS" =~ ^[Yy] ]] || { warn "已取消"; press_enter; ddns_menu; return; }

    crontab -l 2>/dev/null | grep -v "ddns.sh" | crontab - 2>/dev/null || true
    rm -f "$DDNS_SCRIPT" "$DDNS_CONF"
    info "DDNS 已卸载（日志文件已保留: ${DDNS_LOG}）"

    press_enter
    ddns_menu
}

# ══════════════════════════════════════════════════
# 主入口
# ══════════════════════════════════════════════════
main() {
    require_root
    while true; do
        show_menu
        case "$MENU_CHOICE" in
            1) vless_menu ;;
            2) bbr_menu ;;
            3) ddns_menu ;;
            0) echo -e "\n${GREEN}再见！${NC}\n"; exit 0 ;;
            *) warn "无效选项，请输入 0-3"; sleep 1 ;;
        esac
    done
}

main "$@"
