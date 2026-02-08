#!/usr/bin/env bash
# 更新 Cloudflare Pages 的 UPSTREAM_ORIGIN 环境变量并重新部署
# 用法：bash update_upstream.sh <新的后端 URL>
# 示例：bash update_upstream.sh https://api.phatlas.top
set -euo pipefail

ATLASMAP_DIR="/home/ljx/bash_hub/atlasmap-sc"
FRONTEND_DIR="${ATLASMAP_DIR}/frontend"
NODE_BIN="${ATLASMAP_DIR}/.tools/node-v20.11.1/bin"
PAGES_PROJECT="phatlas"

export PATH="${NODE_BIN}:${PATH}"

if [ $# -lt 1 ]; then
    echo "用法: bash update_upstream.sh <后端URL>"
    echo "示例: bash update_upstream.sh https://api.phatlas.top"
    echo ""
    echo "当前 Pages 项目: ${PAGES_PROJECT}"
    exit 1
fi

NEW_UPSTREAM="$1"

echo "==> Updating UPSTREAM_ORIGIN to: ${NEW_UPSTREAM}"
echo ""

cd "${FRONTEND_DIR}"
echo "${NEW_UPSTREAM}" | npx wrangler pages secret put UPSTREAM_ORIGIN --project-name "${PAGES_PROJECT}"

echo ""
echo "==> Redeploying to apply new environment variable..."

if [ ! -d dist ] || [ ! -d functions ]; then
    echo "WARNING: dist/ 或 functions/ 不存在，先执行构建..."
    cd "${ATLASMAP_DIR}"
    make build-frontend
    cd "${FRONTEND_DIR}"
    if [ -d functions ]; then
        TRASH_DIR="/home/ljx/bash_hub/PH-map-online/.Trash"
        mkdir -p "${TRASH_DIR}"
        TS=$(date +%Y%m%d-%H%M%S)
        mv functions "${TRASH_DIR}/functions-${TS}"
    fi
    cp -r cloudflare/functions functions
    cp cloudflare/_routes.json dist/_routes.json
    cp cloudflare/_redirects dist/_redirects
fi

npx wrangler pages deploy dist --project-name "${PAGES_PROJECT}" --commit-dirty=true

echo ""
echo "==> Done! UPSTREAM_ORIGIN updated to: ${NEW_UPSTREAM}"
echo "    Pages URL: https://${PAGES_PROJECT}.pages.dev"
echo "    Custom domain: https://www.phatlas.top"
