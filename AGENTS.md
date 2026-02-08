# Repository Guidelines

## Project Structure & Module Organization

```
PH-map-online/
├── atlasmap/          # Go backend configuration
│   └── server.yaml     # Server port, data paths, CORS settings
├── data/               # Data directory (gitignored)
│   ├── *.h5ad         # AnnData input files
│   └── phatlas/zarr/  # Preprocessed tile data
├── jobs/               # Development/task records
├── *.sh                # Deployment and run scripts
├── .gitignore
├── pyproject.toml      # Python project metadata
└── README.md
```

**Key Dependencies**: Requires `atlasmap-sc` in parent directory (`/home/ljx/bash_hub/atlasmap-sc`).

## Build, Test, and Development Commands

### Development Mode
```bash
bash run_all.sh           # Start backend + frontend dev server
bash run_backend.sh       # Start Go backend only
bash run_frontend.sh      # Start Vite frontend only
```

### Production Deployment
```bash
bash start_tunnel.sh      # Start backend + Cloudflare Tunnel
bash deploy_pages.sh      # Build and deploy to Cloudflare Pages
```

### Backend Build (Required after code changes)
```bash
cd /home/ljx/bash_hub/atlasmap-sc
GOPROXY=https://goproxy.cn,direct make build-server
```

### Data Preprocessing
```bash
make preprocess INPUT=... OUTPUT=... ZOOM_LEVEL=12
```

## Coding Style & Naming Conventions

- **Bash Scripts**: 4-space indentation, use `set -euo pipefail`, define `cleanup()` for trap
- **YAML**: 2-space indentation (server.yaml, cloudflared config)
- **File Naming**: kebab-case for scripts (`start_tunnel.sh`), camelCase for config keys
- **Environment Variables**: UPPERCASE with underscores (`UPSTREAM_ORIGIN`, `PORT`)

### Linting/Formatting
- No automated linting configured - follow existing code style in scripts

## Testing Guidelines

**Testing Approach**: Manual verification via live deployments.

**Verification Commands**:
```bash
curl http://localhost:8080/health           # Backend health check
curl https://api.phatlas.top/health         # Tunnel health check
curl https://www.phatlas.top/api/datasets   # Frontend proxy
```

**Test Data**: Use test project at `/home/ljx/bash_hub/PH-map-online-test` for validation.

## Commit & Pull Request Guidelines

### Commit Message Convention
- Format: `Brief description` (imperative mood, single line)
- Examples:
  - `Add port parameter support to start_tunnel.sh`
  - `Update upstream origin to new tunnel URL`

### Pull Request Requirements
- Link to related issue/feature description
- Include verification steps (curl commands, browser URLs)
- Test both development and production modes before submission
- Update README.md if user-facing changes are introduced

## Security & Configuration Tips

- **Sensitive Data**: All data files in `data/` are gitignored
- **Credentials**: Cloudflare tunnel credentials in `~/.cloudflared/` (not in repo)
- **Tunnel ID**: Update `~/.cloudflared/config.yml` and DNS CNAME when tunnel changes
- **Port Configuration**: Modify `atlasmap/server.yaml` for permanent port changes

## Agent-Specific Instructions

When contributing:
1. Ensure `atlasmap-sc` upstream is available at expected path
2. Test scripts with both default and custom ports (`-p` parameter)
3. Verify cloudflared binary exists before deployment commits
4. Keep `jobs/` directory for documentation of changes/tasks
5. Maintain backward compatibility with existing deployments
