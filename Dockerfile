# syntax=docker/dockerfile:1

FROM node:22-slim

# Upstream MCP server version to install. Override at build time:
#   docker build --build-arg AFFINE_MCP_VERSION=1.2.3 .
ARG AFFINE_MCP_VERSION=latest

# Install curl (Coolify's healthcheck needs curl or wget; node:slim ships neither)
# and the AFFiNE MCP server globally from npm.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g affine-mcp-server@${AFFINE_MCP_VERSION} \
    && npm cache clean --force

# Run the HTTP transport so the server is reachable as a remote MCP endpoint.
# AFFINE_MCP_HTTP_HOST=0.0.0.0 makes it bind on all interfaces inside the container
# (default is 127.0.0.1 / loopback only), otherwise Coolify / the reverse proxy can't reach it.
ENV NODE_ENV=production \
    MCP_TRANSPORT=http \
    AFFINE_MCP_HTTP_HOST=0.0.0.0

# The server listens on 3000 in HTTP mode. The MCP endpoint is served at /mcp.
EXPOSE 3000

# /healthz and /readyz are exposed by the server in HTTP mode.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3000/healthz || exit 1

# Drop privileges.
USER node

CMD ["affine-mcp"]
