#!/usr/bin/env bash
# 构建前端并部署到 Cloudflare Pages（PH Atlas 正式项目）
# 用法：bash deploy_pages.sh
# 前提：已执行过 npx wrangler login
set -euo pipefail

ATLASMAP_DIR="/home/ljx/bash_hub/atlasmap-sc"
FRONTEND_DIR="${ATLASMAP_DIR}/frontend"
NODE_BIN="${ATLASMAP_DIR}/.tools/node-v20.11.1/bin"
PAGES_PROJECT="phatlas"

export PATH="${NODE_BIN}:${PATH}"

echo "==> Node version: $(node --version)"

# Step 1: 构建前端
echo "==> Building frontend..."
cd "${ATLASMAP_DIR}"
make build-frontend

# Step 2: 复制 Cloudflare Functions 和路由配置
echo "==> Copying Cloudflare Functions..."
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

echo "    Functions copied: $(ls functions/)"

# Step 3: 部署到 Pages
echo "==> Deploying to Cloudflare Pages (project: ${PAGES_PROJECT})..."
npx wrangler pages deploy dist --project-name "${PAGES_PROJECT}" --commit-dirty=true

echo ""
echo "==> Deployment complete!"
echo "    Pages URL: https://${PAGES_PROJECT}.pages.dev"
echo "    Custom domain: https://www.phatlas.top"
echo ""
echo "提示：如果需要更新 UPSTREAM_ORIGIN，请运行 update_upstream.sh"
