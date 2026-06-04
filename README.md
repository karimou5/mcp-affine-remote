# mcp-affine-remote

Self-hosted **remote** wrapper around [`affine-mcp-server`](https://github.com/DAWNCR0W/affine-mcp-server), packaged as a Docker container running the **HTTP transport** so it can be used as a remote MCP connector (Claude web, Claude Code, Claude Desktop, etc.).

The image is built by a GitHub Action and pushed to **GHCR**; it is deployed on **Coolify**.

## Architecture

```
Claude (web / code / desktop)
        │  HTTPS  (public URL you expose)
        ▼
  this MCP container            ← AFFINE_MCP_AUTH_MODE / AFFINE_MCP_HTTP_TOKEN
        │  HTTPS outbound       ← AFFINE_BASE_URL + AFFINE_API_TOKEN
        ▼
   AFFiNE Cloud (app.affine.pro)  — or your self-hosted AFFiNE
```

The container is just an **API client**: it connects *outward* to AFFiNE (cloud or self-hosted). Only this container needs to be reachable publicly — AFFiNE itself is reached by the container, not by Claude.

> **Single AFFiNE identity:** the container holds one `AFFINE_API_TOKEN`. Everyone who connects acts in AFFiNE **as that token's user**. For a second identity, deploy a second instance with a different token.

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `AFFINE_BASE_URL` | yes | AFFiNE instance, e.g. `https://app.affine.pro` |
| `AFFINE_API_TOKEN` | yes | Access token (`ut_…`) from AFFiNE → Settings → account → API/access tokens |
| `MCP_TRANSPORT` | yes | `http` (already set in the image) |
| `AFFINE_MCP_AUTH_MODE` | yes | `bearer` or `none` (see Auth below) |
| `AFFINE_MCP_HTTP_TOKEN` | if `bearer` | Long random secret required as `Authorization: Bearer …` |

See `.env.example`. The container listens on **port 3000**, MCP endpoint at **`/mcp`**, health at **`/healthz`** and **`/readyz`**.

## Build (GitHub Action → GHCR)

On every push to `main` (and via manual `workflow_dispatch`), `.github/workflows/build.yml` builds the image and pushes:

```
ghcr.io/<owner>/<repo>:latest
ghcr.io/<owner>/<repo>:sha-<short>
```

No secrets to configure — it authenticates to GHCR with the built-in `GITHUB_TOKEN`. After the first build, make the GHCR package **public** (or give Coolify a pull token) so Coolify can pull it.

## Deploy on Coolify

1. **+ New Resource → Docker Image**, image: `ghcr.io/<owner>/mcp-affine-remote:latest`.
2. **Ports exposes:** `3000`.
3. **Environment variables:** set everything from `.env.example` (real values).
4. Attach a domain (e.g. `https://affine-mcp.karimou.me`) → Coolify provisions HTTPS.
5. Health check path: `/healthz`.
6. Deploy. Redeploy on each new build (or wire Coolify's webhook to the Action).

Public MCP URL becomes: `https://affine-mcp.karimou.me/mcp`

## Auth: which mode?

| Client | Mode | How it authenticates |
|---|---|---|
| Claude **Code** / **Desktop** | `bearer` | Config sends `Authorization: Bearer <AFFINE_MCP_HTTP_TOKEN>` |
| Claude **web** (claude.ai connector) | `none` + **Cloudflare Access** | The web dialog only does OAuth — it can't send a static bearer. Run the MCP with `AFFINE_MCP_AUTH_MODE=none` and put **Cloudflare Access** in front of the domain; Access provides the OAuth the connector expects. |

### Claude web custom connector

1. Deploy with `AFFINE_MCP_AUTH_MODE=none`.
2. Protect `affine-mcp.karimou.me` with a **Cloudflare Access** application (OAuth/OIDC), policy = the emails allowed (you, your associate…).
3. In Claude web → **Add custom connector**:
   - **Name:** `AFFiNE`
   - **Remote MCP server URL:** `https://affine-mcp.karimou.me/mcp`
   - **Advanced → OAuth client ID / secret:** the credentials from the Cloudflare Access application.
4. Sharing: add the person's **email** to the Access policy — they add the same connector and log in as themselves. No credential pair is handed out per user.

### Claude Code config (bearer mode)

```json
{
  "mcpServers": {
    "affine": {
      "type": "http",
      "url": "https://affine-mcp.karimou.me/mcp",
      "headers": { "Authorization": "Bearer <AFFINE_MCP_HTTP_TOKEN>" }
    }
  }
}
```

## Local run

```bash
cp .env.example .env   # fill real values
docker compose up --build
# → http://localhost:3000/mcp
```
