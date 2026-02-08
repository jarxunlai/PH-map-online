#!/usr/bin/env bash
# AtlasMap 前端启动脚本（PH Atlas 正式项目）
# 用法：bash run_frontend.sh [-p BACKEND_PORT]
#       PORT=9090 bash run_frontend.sh
# 前端 dev server 会将 /api/* 和 /d/* 代理到后端端口
# 默认后端端口从 atlasmap/server.yaml 中读取（当前为 8080）
set -euo pipefail

ATLASMAP_DIR="/home/ljx/bash_hub/atlasmap-sc"
SERVER_CONFIG="/home/ljx/bash_hub/PH-map-online/atlasmap/server.yaml"

# 解析参数
while getopts ":p:" opt; do
    case ${opt} in
        p) PORT="${OPTARG}" ;;
        *) echo "用法: bash run_frontend.sh [-p BACKEND_PORT]"; exit 1 ;;
    esac
done

# 读取默认端口
DEFAULT_PORT=$(grep -E '^\s+port:' "${SERVER_CONFIG}" | head -1 | awk '{print $2}')
PORT="${PORT:-${DEFAULT_PORT}}"

echo "==> Starting AtlasMap Vite frontend..."
echo "    Frontend URL: http://localhost:3000 (or next available port)"
echo "    Proxy: /api -> http://localhost:${PORT}"
echo "    Proxy: /d/  -> http://localhost:${PORT}"
echo ""

cd "${ATLASMAP_DIR}"
exec make dev-frontend BACKEND_PORT="${PORT}"
