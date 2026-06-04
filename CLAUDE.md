# mcp-affine-remote

Docker wrapper that runs `affine-mcp-server` (npm) in **HTTP transport** mode so it can be used as a
**remote** MCP server. Built by GitHub Action → GHCR, deployed on Coolify, optionally fronted by
Cloudflare Access for the claude.ai web connector.

## Stack
- `Dockerfile` — `node:22-slim`, installs `affine-mcp-server` globally, runs `affine-mcp` with `MCP_TRANSPORT=http` on port 3000.
- `.github/workflows/build.yml` — build & push `ghcr.io/<owner>/<repo>:{latest,sha-…}` on push to `main`.
- `docker-compose.yml` — local/reference run.
- Runtime secrets live in **Coolify env vars**, never in the repo. See `.env.example`.

## Key facts
- The container is an API client → connects OUT to `AFFINE_BASE_URL` with `AFFINE_API_TOKEN`. One token = one AFFiNE identity for all clients.
- MCP endpoint: `/mcp`. Health: `/healthz`, `/readyz`. Port: 3000.
- Auth modes: `bearer` (Claude Code/Desktop) or `none` + Cloudflare Access (Claude web).

## Conventions
- Work directly on `main`.
- Commits anonymous — no assistant name or signature.
- Use `docker compose` (never `docker-compose`).
