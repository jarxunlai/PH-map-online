# PH Atlas Online

基于 [AtlasMap-SC](https://github.com/atlasmap-sc) 的单细胞转录组在线可视化平台，将大规模单细胞图谱以地图瓦片方式呈现，支持多分辨率浏览与基因表达查询。

## 特性

- **地图式浏览** — 将 UMAP 散点图转化为多分辨率瓦片地图，支持缩放/平移
- **基因表达可视化** — 实时查询基因表达，viridis 色阶渲染
- **分类着色** — 支持按细胞类型等分类元数据着色
- **差异表达分析** — 内置 DE 分析 job 管理
- **BLAST 查询** — 支持序列比对任务提交
- **高性能** — Go 后端 + Zarr 瓦片存储，12 级缩放，50ms 级瓦片响应

## 在线访问

| 地址 | 说明 |
|------|------|
| **https://www.phatlas.top** | 前端（主域名） |
| https://phatlas.top | 前端（根域，同内容） |
| https://api.phatlas.top | 后端 API（Named Tunnel） |
| https://phatlas.pages.dev | Cloudflare Pages 默认域（国内可能不通） |

数据集参数：`?dataset=phatlas`（默认，可省略）

## 技术栈

| 层级 | 技术 |
|------|------|
| **后端** | Go (AtlasMap-SC server) |
| **前端** | TypeScript + Vite + Leaflet |
| **数据格式** | Zarr v3（多分辨率瓦片）、AnnData (.h5ad) |
| **托管** | Cloudflare Pages（前端）、Cloudflare Named Tunnel（后端） |
| **代理** | Cloudflare Pages Functions（`/api/*`、`/d/*` → 后端） |
| **异步任务** | SQLite（DE / BLAST job 管理） |
| **数据预处理** | Python ≥ 3.11 (atlasmap-sc preprocessing) |
| **项目管理** | uv + Git |

## 架构

```
用户浏览器
  ↓ HTTPS
Cloudflare Pages (www.phatlas.top)
  ├── 静态文件 → dist/ (Vite 构建产物)
  └── Pages Functions 代理 /api/* 和 /d/*
        ↓ UPSTREAM_ORIGIN = https://api.phatlas.top
      Cloudflare Named Tunnel (phatlas)
        ↓
      Go Backend (localhost:8080)
        ├── /api/*  → REST API
        ├── /d/*    → 瓦片数据
        ├── DE jobs → data/de_jobs.sqlite
        └── BLAST   → data/blast_jobs.sqlite
              ↓
      Zarr 数据 (data/phatlas/zarr/bins.zarr)
```

## 快速开始（首次部署）

> 以下步骤仅需在首次部署或环境重建时执行。

### 1. 克隆项目

```bash
cd /home/ljx/bash_hub
git clone <repo-url> PH-map-online
cd PH-map-online
```

### 2. 准备上游框架

确保 [atlasmap-sc](https://github.com/atlasmap-sc) 已克隆到同级目录：

```bash
ls /home/ljx/bash_hub/atlasmap-sc  # 应存在
```

### 3. 编译 Go 后端

```bash
cd /home/ljx/bash_hub/atlasmap-sc
GOPROXY=https://goproxy.cn,direct make build-server
```

### 4. 下载 cloudflared

```bash
cd /home/ljx/bash_hub/PH-map-online
wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared
```

### 5. 配置 Cloudflare Tunnel

```bash
./cloudflared tunnel login            # 浏览器授权
./cloudflared tunnel create phatlas   # 创建隧道
```

创建 `~/.cloudflared/config.yml`：

```yaml
tunnel: phatlas
credentials-file: ~/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: api.phatlas.top
    service: http://127.0.0.1:8080
  - service: http_status:404
```

在 Cloudflare DNS 中添加 CNAME 记录：`api.phatlas.top → <tunnel-id>.cfargotunnel.com`

### 6. 配置 wrangler（前端部署用）

```bash
export PATH="/home/ljx/bash_hub/atlasmap-sc/.tools/node-v20.11.1/bin:$PATH"
npx wrangler login
```

### 7. 准备数据

将 h5ad 数据传输到本地：

```bash
rsync -avz -P \
    -e "ssh -p 14071" \
    ljx@biotrainee.vip:/home/data/public_data/reference_map_PH/data/PH-Map/lung_atlas_light.h5ad \
    /home/ljx/bash_hub/PH-map-online/data/
```

执行预处理（见 [数据预处理](#数据预处理) 章节）。

### 8. 启动服务

```bash
bash start_tunnel.sh   # 生产模式
```

### 9. 部署前端

```bash
bash deploy_pages.sh
```

完成后访问 **https://www.phatlas.top** 验证。

---

## 运行项目

### 前置条件

- Go backend 二进制已编译（首次或代码更新后需要执行）：

```bash
cd /home/ljx/bash_hub/atlasmap-sc
GOPROXY=https://goproxy.cn,direct make build-server
```

- `cloudflared` 二进制存在于项目根目录（已下载）
- `~/.cloudflared/config.yml` 已配置 Named Tunnel `phatlas`
- `wrangler` 已登录（`npx wrangler login`，通过 atlasmap-sc 的 Node 工具链）

---

### 模式 A：生产部署（后端 + Tunnel → 公网可访问）

启动后端服务器并通过 Named Tunnel 暴露到 `api.phatlas.top`：

```bash
bash start_tunnel.sh              # 使用默认端口（server.yaml 中的 8080）
bash start_tunnel.sh -p 9090      # 指定自定义端口
PORT=9090 bash start_tunnel.sh    # 等效写法
```

脚本会：
1. 自动从 `atlasmap/server.yaml` 读取默认端口（支持 `-p` 或 `PORT` 覆盖）
2. 检查端口是否被占用，若占用则报错退出
3. 启动 Go 后端，并验证进程存活
4. 自动生成 cloudflared 临时配置（端口联动），启动 Named Tunnel
5. 退出时自动清理临时文件和子进程

**验证**：

```bash
curl http://localhost:8080/health          # 后端直连 → OK
curl https://api.phatlas.top/health        # Tunnel → OK
curl https://www.phatlas.top/api/datasets  # 前端代理 → JSON
```

**终止**：`Ctrl+C`（自动终止后端和 Tunnel 两个进程）

**后台运行**（适合服务器长期部署）：

```bash
nohup bash start_tunnel.sh > nohup.out 2>&1 &
echo $!   # 记录主进程 PID

# 使用自定义端口后台运行
nohup bash start_tunnel.sh -p 9090 > nohup.out 2>&1 &

# 查看实时日志
tail -f nohup.out
```

---

### 模式 B：本地开发（后端 + 前端 dev server）

同时启动后端和 Vite 前端 dev server，适合开发调试：

```bash
bash run_all.sh              # 使用默认端口
bash run_all.sh -p 9090      # 自定义后端端口
PORT=9090 bash run_all.sh    # 等效写法
```

| 服务 | 地址 |
|------|------|
| 后端 API | http://localhost:8080（或自定义端口） |
| 前端页面 | http://localhost:3000（或下一个可用端口） |
| Health Check | http://localhost:{PORT}/health |

前端 dev server 自动代理 `/api/*` 和 `/d/*` 到后端。

**终止**：`Ctrl+C`（自动终止两个进程）

也可以单独运行：

```bash
bash run_backend.sh              # 仅后端（默认端口）
bash run_backend.sh -p 9090     # 仅后端（自定义端口）
bash run_frontend.sh             # 仅前端（需后端已在运行）
bash run_frontend.sh -p 9090    # 仅前端（指定后端端口）
```

## 部署与更新前端

构建前端并发布到 Cloudflare Pages：

```bash
bash deploy_pages.sh
```

脚本会：
1. `make build-frontend` 构建 Vite 产物到 `atlasmap-sc/frontend/dist/`
2. 复制 Cloudflare Functions（`/api/*`、`/d/*` 代理）到 `dist/`
3. `wrangler pages deploy` 发布到 Pages 项目 `phatlas`

> 注意：环境变量 `UPSTREAM_ORIGIN` 变更后，需要重新部署才能生效。
> Named Tunnel 的 URL 是固定的 (`https://api.phatlas.top`)，一般不需要变更。

如果需要更新 `UPSTREAM_ORIGIN`：

```bash
bash update_upstream.sh https://api.phatlas.top
```

## API 端点

后端主要暴露以下 API（均支持通过前端 `/api/*` 代理访问）：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/api/datasets` | GET | 获取数据集列表 |
| `/api/datasets/{id}/metadata` | GET | 获取数据集元信息（细胞数、基因数、坐标类型等） |
| `/api/datasets/{id}/genes` | GET | 获取可查询基因列表 |
| `/api/datasets/{id}/categories` | GET | 获取分类元数据列表 |
| `/d/{dataset}/{z}/{x}/{y}.png` | GET | 获取瓦片图像（z=zoom, x/y=坐标） |

## 终止服务

| 场景 | 方法 |
|------|------|
| `start_tunnel.sh` 运行中 | 在对应终端按 `Ctrl+C` |
| `run_all.sh` 运行中 | 在对应终端按 `Ctrl+C` |
| `nohup` 后台运行中 | `kill <PID>`（PID 见启动时输出） |
| 后台进程需要手动终止 | `kill $(pgrep -f "server.*server.yaml")` 终止后端 |
| | `kill $(pgrep -f "cloudflared tunnel run")` 终止 Tunnel |
| 查看运行中的进程 | `ps aux \| grep -E "(server\|cloudflared)"` |

所有脚本都设置了 `trap cleanup EXIT INT TERM`，`Ctrl+C` 会自动清理子进程。

## 数据预处理

如果需要重新预处理原始数据（`data/lung_atlas_light.h5ad`）：

```bash
cd /home/ljx/bash_hub/atlasmap-sc
make preprocess \
    INPUT=/home/ljx/bash_hub/PH-map-online/data/lung_atlas_light.h5ad \
    OUTPUT=/home/ljx/bash_hub/PH-map-online/data/phatlas \
    ZOOM_LEVEL=12 \
    PREPROCESS_NO_SOMA=0 \
    PREPROCESS_ALL_EXPRESSED=1
```
```
atlasmap-preprocess run \
  -i /home/ljx/bash_hub/PH-map-online/data/lung_atlas_light.h5ad \
  -o /home/ljx/bash_hub/PH-map-online/data/phatlas \
  -z 9 -a --min-cells 3 --no-soma
```

```
atlasmap-preprocess visualize -i /home/ljx/bash_hub/PH-map-online/data/phatlas/zarr -o /home/ljx/bash_hub/PH-map-online/data/phatlas/figures -z 3,5,7 -g PIEZO1 -g PIEZO2
```

**参数说明**：

| 参数 | 值 | 说明 |
|------|------|------|
| `INPUT` | `data/lung_atlas_light.h5ad` | 输入的 AnnData h5ad 文件 |
| `OUTPUT` | `data/phatlas` | 输出目录 |
| `ZOOM_LEVEL` | `12` | 瓦片缩放层级数 |
| `PREPROCESS_NO_SOMA` | `1` | 不使用 TileDB-SOMA（直接 Zarr） |
| `PREPROCESS_ALL_EXPRESSED` | `0` | 不预聚合所有基因（按 N_GENES 限制） |
| `PREPROCESS_N_GENES` | `500` | 预聚合的基因数量 |

**产物**：`data/phatlas/zarr/` 下的 `bins.zarr/`、`metadata.json`、`gene_index.json`。

**当前数据规模**：

| 指标 | 值 |
|------|------|
| 细胞数 | 235,621 |
| 基因数 | 21,977 |
| 预聚合基因 | 500 |
| 缩放层级 | 12 |
| 坐标系 | X_umap |

## 目录结构

```
PH-map-online/
├── atlasmap/
│   └── server.yaml              # Go 后端配置（端口、数据路径、CORS、缓存）
├── data/
│   ├── lung_atlas_light.h5ad    # 原始 h5ad（gitignored）
│   ├── phatlas/zarr/            # 预处理产物（gitignored）
│   │   ├── bins.zarr/           #   多分辨率瓦片数据（12 zoom levels）
│   │   ├── metadata.json        #   数据集元信息
│   │   └── gene_index.json      #   基因名 → 索引映射
│   ├── de_jobs.sqlite           # 差异表达分析任务记录
│   └── blast_jobs.sqlite        # BLAST 任务记录
├── cloudflared                  # Cloudflare Tunnel 二进制（gitignored）
├── start_tunnel.sh              # 生产：后端 + Named Tunnel
├── deploy_pages.sh              # 构建并部署前端到 Cloudflare Pages
├── update_upstream.sh           # 更新 Pages UPSTREAM_ORIGIN 环境变量
├── run_all.sh                   # 开发：后端 + 前端 dev server
├── run_backend.sh               # 仅启动后端
├── run_frontend.sh              # 仅启动前端 dev server
├── jobs/                        # 任务/开发记录
├── nohup.out                    # 后台运行日志（gitignored）
├── .gitignore
├── pyproject.toml               # Python 项目元数据（uv 管理）
└── README.md
```

## 关键配置

### `atlasmap/server.yaml`

```yaml
server:
  port: 8080
  cors_origins:
    - "http://localhost:3000"
    - "http://localhost:5173"
  title: "PH Atlas"
data:
  phatlas:
    zarr_path: "/home/ljx/bash_hub/PH-map-online/data/phatlas/zarr/bins.zarr"
cache:
  tile_size_mb: 512       # 瓦片缓存上限
  tile_ttl_minutes: 10    # 缓存 TTL
render:
  tile_size: 256          # 瓦片像素尺寸
  default_colormap: viridis
```

### `~/.cloudflared/config.yml`

```yaml
tunnel: phatlas
credentials-file: ~/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: api.phatlas.top
    service: http://127.0.0.1:8080
  - service: http_status:404
```

### Cloudflare Pages 环境变量

| 变量 | 值 | 说明 |
|------|----|------|
| `UPSTREAM_ORIGIN` | `https://api.phatlas.top` | Pages Functions 代理目标 |

## 自定义端口

所有脚本均支持通过 `-p PORT` 参数或 `PORT` 环境变量指定后端端口，**默认端口从 `atlasmap/server.yaml` 中读取**（当前为 8080）。

```bash
# 方式 1：-p 参数
bash start_tunnel.sh -p 9090

# 方式 2：环境变量
PORT=9090 bash run_all.sh

# 方式 3：永久修改默认端口 — 编辑 server.yaml
#   将 port: 8080 改为 port: 9090，之后所有脚本自动使用新端口
```

当指定的端口与 `server.yaml` 中的默认值不同时，脚本会自动：
1. 生成临时 `server.yaml`（替换端口号）供后端使用
2. 在 `start_tunnel.sh` 中同时生成临时 cloudflared 配置（端口联动）
3. 退出时清理所有临时文件

> **注意**：如果永久修改了端口，`~/.cloudflared/config.yml` 中的 `service: http://127.0.0.1:8080` 也应同步更新。使用 `-p` 参数时则无需手动修改，脚本会自动处理。

## 脚本一览

| 脚本 | 用途 | 端口支持 | 使用场景 |
|------|------|----------|----------|
| `start_tunnel.sh` | 启动后端 + Cloudflare Tunnel | `-p PORT` | 生产部署 |
| `run_all.sh` | 启动后端 + 前端 dev server | `-p PORT` | 本地开发 |
| `run_backend.sh` | 仅启动 Go 后端 | `-p PORT` | 单独调试后端 |
| `run_frontend.sh` | 仅启动 Vite 前端 | `-p PORT`（后端端口） | 单独调试前端 |
| `deploy_pages.sh` | 构建前端 + 部署到 Cloudflare Pages | — | 前端更新发布 |
| `update_upstream.sh` | 更新 UPSTREAM_ORIGIN 环境变量 | — | 后端 URL 变更时 |

## 常见问题

**Q: `start_tunnel.sh` 报 "Go 后端二进制不存在"**
→ 需要先编译：`cd /home/ljx/bash_hub/atlasmap-sc && GOPROXY=https://goproxy.cn,direct make build-server`

**Q: `deploy_pages.sh` 报 wrangler 相关错误**
→ 检查 Node 是否可用：`/home/ljx/bash_hub/atlasmap-sc/.tools/node-v20.11.1/bin/node --version`
→ 检查 wrangler 是否登录：`PATH=... npx wrangler whoami`

**Q: `www.phatlas.top` 返回 522 错误**
→ 后端或 Tunnel 未运行。执行 `bash start_tunnel.sh` 启动。

**Q: `phatlas.pages.dev` 无法访问**
→ `*.pages.dev` 域名在国内可能被屏蔽，使用自定义域名 `www.phatlas.top` 访问即可。

**Q: 启动后端报 "address already in use"**
→ 端口 8080 已被占用。先终止旧进程：
```bash
kill $(pgrep -f "server.*server.yaml") 2>/dev/null
# 或查看占用情况
ss -tlnp | grep 8080
```

**Q: Tunnel 启动后 ICMP proxy 报 warning**
→ 这是 `cloudflared` 的 ICMP 代理权限警告，不影响 HTTP 隧道功能，可忽略。

**Q: 前端代理返回 502 / 504**
→ 后端未运行或响应超时。检查后端日志：
```bash
curl -v http://localhost:8080/health
```

**Q: 需要更换数据集**
→ 准备新的 h5ad 文件，重新运行预处理，更新 `atlasmap/server.yaml` 中的 `zarr_path`，重启后端。

**Q: 需要完全重启整个服务**

```bash
# 1. 终止所有相关进程
kill $(pgrep -f "server.*server.yaml") 2>/dev/null
kill $(pgrep -f "cloudflared tunnel run") 2>/dev/null

# 2. 重新启动
bash start_tunnel.sh
```

## 关联项目

| 项目 | 路径 / 链接 | 说明 |
|------|-------------|------|
| AtlasMap-SC | `/home/ljx/bash_hub/atlasmap-sc` / [GitHub](https://github.com/atlasmap-sc) | 上游框架（Go 后端 + 前端 + 预处理） |
| PH-map-online-test | `/home/ljx/bash_hub/PH-map-online-test` | 测试项目（使用测试数据） |
