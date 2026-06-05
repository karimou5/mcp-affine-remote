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
| `AFFINE_MCP_AUTH_MODE` | yes | `oauth`, `bearer` or `none` (see Auth below) |
| `AFFINE_MCP_HTTP_TOKEN` | if `bearer` | Long random secret required as `Authorization: Bearer …` |
| `AFFINE_MCP_PUBLIC_BASE_URL` | if `oauth` | Public HTTPS URL of this container, e.g. `https://affine-mcp.karimou.me` |
| `AFFINE_OAUTH_ISSUER_URL` | if `oauth` | OIDC issuer that signs the access tokens, e.g. `https://mcp-auth.karimou.me` |
| `AFFINE_MCP_HTTP_ALLOWED_ORIGINS` | if `oauth` | Comma-separated browser origins (`ALLOW_ALL_ORIGINS` is rejected in oauth mode) |

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
| Claude **web** (claude.ai connector) | `oauth` | Full OAuth 2.1 discovery flow against an external OIDC issuer (below). The web dialog cannot send a static bearer header. |
| Claude **Code** / **Desktop** | `oauth` (works too) or `bearer` | Either the same OAuth flow, or `Authorization: Bearer <AFFINE_MCP_HTTP_TOKEN>` in bearer mode |

### Claude web custom connector (`AFFINE_MCP_AUTH_MODE=oauth`)

How it works: claude.ai probes `/mcp`, gets `401 + WWW-Authenticate: resource_metadata=…`,
reads `/.well-known/oauth-protected-resource`, discovers the authorization server, registers
itself via **Dynamic Client Registration**, runs the browser OAuth flow, then calls `/mcp`
with a **JWT access token** that `affine-mcp-server` (≥ 2.0) validates against the issuer's
JWKS (`iss` + `aud` checks).

The issuer is a small Cloudflare Worker — repo **`karimou5/mcp-auth-worker`**, deployed at
`https://mcp-auth.karimou.me` — implementing authorize/token/register/jwks with an
**email + OTP login** (UniOne) restricted to an allowlist (`ALLOWED_EMAILS` var on the Worker).

Deploy this container with:

```env
AFFINE_MCP_AUTH_MODE=oauth
AFFINE_MCP_PUBLIC_BASE_URL=https://affine-mcp.karimou.me
AFFINE_OAUTH_ISSUER_URL=https://mcp-auth.karimou.me
AFFINE_MCP_HTTP_ALLOWED_ORIGINS=https://claude.ai,https://claude.com
```

Gotchas:
- `AFFINE_MCP_HTTP_ALLOW_ALL_ORIGINS=true` and `AFFINE_MCP_HTTP_TOKEN` are **rejected** in oauth mode.
- The Cloudflare zone must **not block AI bots** ("AI Scrapers and Crawlers" / bot management):
  claude.ai's backend calls with the `Claude-User` user-agent and gets a 403 at the edge otherwise.

In Claude web → **Add custom connector** → URL `https://affine-mcp.karimou.me/mcp`.
No OAuth client ID/secret needed (DCR). Login = allowlisted email + emailed code.
Sharing: add the person's email to the Worker's `ALLOWED_EMAILS`.

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
