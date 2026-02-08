#!/usr/bin/env bash
# AtlasMap 一键启动脚本（后端 + 前端）— PH Atlas 正式项目
# 用法：bash run_all.sh [-p PORT]
#       PORT=9090 bash run_all.sh
# 注意：Ctrl+C 会同时终止两个进程
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_CONFIG="${SCRIPT_DIR}/atlasmap/server.yaml"

# 解析参数
while getopts ":p:" opt; do
    case ${opt} in
        p) PORT="${OPTARG}" ;;
        *) echo "用法: bash run_all.sh [-p PORT]"; exit 1 ;;
    esac
done

# 读取默认端口
DEFAULT_PORT=$(grep -E '^\s+port:' "${SERVER_CONFIG}" | head -1 | awk '{print $2}')
PORT="${PORT:-${DEFAULT_PORT}}"

echo "============================================"
echo " PH Atlas — AtlasMap Online"
echo "============================================"
echo " Backend:  http://localhost:${PORT}"
echo " Frontend: http://localhost:3000 (or next available)"
echo " Health:   http://localhost:${PORT}/health"
echo "============================================"
echo ""

cleanup() {
    echo ""
    echo "==> Shutting down..."
    kill 0 2>/dev/null || true
    wait 2>/dev/null || true
    echo "==> Done."
}
trap cleanup EXIT INT TERM

PORT="${PORT}" bash "${SCRIPT_DIR}/run_backend.sh" &
BACKEND_PID=$!

sleep 3

PORT="${PORT}" bash "${SCRIPT_DIR}/run_frontend.sh" &
FRONTEND_PID=$!

echo ""
echo "==> Both servers running (backend PID: ${BACKEND_PID}, frontend PID: ${FRONTEND_PID})"
echo "==> Press Ctrl+C to stop all."
echo ""

wait
