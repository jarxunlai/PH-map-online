#!/usr/bin/env bash
# AtlasMap 后端启动脚本（PH Atlas 正式项目）
# 用法：bash run_backend.sh [-p PORT]
#       PORT=9090 bash run_backend.sh
# 默认端口从 atlasmap/server.yaml 中读取（当前为 8080）
set -euo pipefail

ATLASMAP_DIR="/home/ljx/bash_hub/atlasmap-sc"
SERVER_CONFIG="/home/ljx/bash_hub/PH-map-online/atlasmap/server.yaml"

# 解析参数
while getopts ":p:" opt; do
    case ${opt} in
        p) PORT="${OPTARG}" ;;
        *) echo "用法: bash run_backend.sh [-p PORT]"; exit 1 ;;
    esac
done

# 读取默认端口
DEFAULT_PORT=$(grep -E '^\s+port:' "${SERVER_CONFIG}" | head -1 | awk '{print $2}')
PORT="${PORT:-${DEFAULT_PORT}}"

# 如果自定义端口，生成临时配置
ACTUAL_CONFIG="${SERVER_CONFIG}"
if [ "${PORT}" != "${DEFAULT_PORT}" ]; then
    TEMP_CONFIG=$(mktemp /tmp/phatlas-server-XXXXXX.yaml)
    sed "s/port: ${DEFAULT_PORT}/port: ${PORT}/" "${SERVER_CONFIG}" > "${TEMP_CONFIG}"
    ACTUAL_CONFIG="${TEMP_CONFIG}"
    trap 'rm -f "${TEMP_CONFIG}" 2>/dev/null' EXIT
fi

echo "==> Starting AtlasMap Go backend..."
echo "    Config: ${ACTUAL_CONFIG}"
echo "    Backend URL: http://localhost:${PORT}"
echo ""

cd "${ATLASMAP_DIR}"
export GOPROXY=https://goproxy.cn,direct
exec make dev-server SERVER_CONFIG="${ACTUAL_CONFIG}"
