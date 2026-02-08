#!/usr/bin/env bash
# 启动 Go 后端 + Cloudflare Named Tunnel（PH Atlas 正式项目）
# 用法：bash start_tunnel.sh [-p PORT]
#       PORT=9090 bash start_tunnel.sh
# 默认端口从 atlasmap/server.yaml 中读取（当前为 8080）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATLASMAP_DIR="/home/ljx/bash_hub/atlasmap-sc"
SERVER_BIN="${ATLASMAP_DIR}/server/bin/server"
SERVER_CONFIG="${SCRIPT_DIR}/atlasmap/server.yaml"
CLOUDFLARED="${SCRIPT_DIR}/cloudflared"
CLOUDFLARED_CONFIG="$HOME/.cloudflared/config.yml"
TUNNEL_NAME="phatlas"
TEMP_FILES=()

# ---------- 解析参数 ----------
while getopts ":p:" opt; do
    case ${opt} in
        p) PORT="${OPTARG}" ;;
        *) echo "用法: bash start_tunnel.sh [-p PORT]"; exit 1 ;;
    esac
done

# ---------- 读取默认端口 ----------
DEFAULT_PORT=$(grep -E '^\s+port:' "${SERVER_CONFIG}" | head -1 | awk '{print $2}')
PORT="${PORT:-${DEFAULT_PORT}}"

echo "==> 使用端口: ${PORT}（默认: ${DEFAULT_PORT}）"

# ---------- 检查依赖 ----------
if [ ! -x "${SERVER_BIN}" ]; then
    echo "ERROR: Go 后端二进制不存在: ${SERVER_BIN}"
    echo "请先编译: cd ${ATLASMAP_DIR} && GOPROXY=https://goproxy.cn,direct make build-server"
    exit 1
fi

if [ ! -x "${CLOUDFLARED}" ]; then
    echo "ERROR: cloudflared 不存在: ${CLOUDFLARED}"
    echo "请先下载: wget -O ${CLOUDFLARED} https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x ${CLOUDFLARED}"
    exit 1
fi

if [ ! -f "${SERVER_CONFIG}" ]; then
    echo "ERROR: 配置文件不存在: ${SERVER_CONFIG}"
    exit 1
fi

if [ ! -f "${CLOUDFLARED_CONFIG}" ]; then
    echo "ERROR: cloudflared 配置不存在: ${CLOUDFLARED_CONFIG}"
    exit 1
fi

# ---------- 检查端口是否已被占用 ----------
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    echo "ERROR: 端口 ${PORT} 已被占用："
    ss -tlnp | grep ":${PORT} "
    echo ""
    echo "请先终止占用进程："
    echo "  kill \$(pgrep -f 'server.*server.yaml')"
    echo "  或: ss -tlnp | grep ${PORT}  # 查看 PID 后 kill"
    exit 1
fi

# ---------- 生成临时配置（当端口与默认不同时） ----------
ACTUAL_SERVER_CONFIG="${SERVER_CONFIG}"
ACTUAL_CF_CONFIG="${CLOUDFLARED_CONFIG}"

if [ "${PORT}" != "${DEFAULT_PORT}" ]; then
    # 生成临时 server.yaml
    TEMP_SERVER_CONFIG=$(mktemp /tmp/phatlas-server-XXXXXX.yaml)
    sed "s/port: ${DEFAULT_PORT}/port: ${PORT}/" "${SERVER_CONFIG}" > "${TEMP_SERVER_CONFIG}"
    ACTUAL_SERVER_CONFIG="${TEMP_SERVER_CONFIG}"
    TEMP_FILES+=("${TEMP_SERVER_CONFIG}")
    echo "    临时后端配置: ${TEMP_SERVER_CONFIG}"
fi

# 始终生成临时 cloudflared 配置，确保端口一致
TEMP_CF_CONFIG=$(mktemp /tmp/phatlas-cf-XXXXXX.yml)
sed "s|service: http://127.0.0.1:[0-9]*|service: http://127.0.0.1:${PORT}|" "${CLOUDFLARED_CONFIG}" > "${TEMP_CF_CONFIG}"
ACTUAL_CF_CONFIG="${TEMP_CF_CONFIG}"
TEMP_FILES+=("${TEMP_CF_CONFIG}")

# ---------- 清理函数 ----------
cleanup() {
    echo ""
    echo "==> Shutting down..."
    kill 0 2>/dev/null || true
    wait 2>/dev/null || true
    # 清理临时文件
    for f in "${TEMP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null
    done
    echo "==> Done."
}
trap cleanup EXIT INT TERM

# ---------- 启动后端 ----------
echo "==> Starting Go backend (port ${PORT})..."
echo "    Config: ${ACTUAL_SERVER_CONFIG}"
"${SERVER_BIN}" -config "${ACTUAL_SERVER_CONFIG}" &
BACKEND_PID=$!

sleep 2

# 检查后端进程是否还存活
if ! kill -0 "${BACKEND_PID}" 2>/dev/null; then
    echo "ERROR: Go 后端启动失败（进程已退出）"
    echo "请检查上方错误日志。常见原因：端口被占用、配置文件错误。"
    exit 1
fi

if ! curl -sS --max-time 5 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    echo "WARNING: Backend health check failed (http://localhost:${PORT}/health)"
    echo "    后端进程在运行但 health check 未通过，继续启动 Tunnel..."
fi
echo "    Backend running (PID: ${BACKEND_PID}) on port ${PORT}"

# ---------- 启动 Named Tunnel ----------
echo ""
echo "==> Starting Cloudflare Named Tunnel (${TUNNEL_NAME})..."
echo "    后端 localhost:${PORT} → api.phatlas.top"
echo ""
"${CLOUDFLARED}" --config "${ACTUAL_CF_CONFIG}" tunnel run "${TUNNEL_NAME}" &
TUNNEL_PID=$!

echo ""
echo "==> Backend PID: ${BACKEND_PID}, Tunnel PID: ${TUNNEL_PID}"
echo "==> Press Ctrl+C to stop all."
echo ""

wait
