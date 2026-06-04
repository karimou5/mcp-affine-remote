# syntax=docker/dockerfile:1

FROM node:22-slim

# Upstream MCP server version to install. Override at build time:
#   docker build --build-arg AFFINE_MCP_VERSION=1.2.3 .
ARG AFFINE_MCP_VERSION=latest

# Install the AFFiNE MCP server globally from npm.
RUN npm install -g affine-mcp-server@${AFFINE_MCP_VERSION} \
    && npm cache clean --force

# Run the HTTP transport so the server is reachable as a remote MCP endpoint.
# HOST=0.0.0.0 ensures it binds on all interfaces inside the container (not just localhost),
# otherwise Coolify / the reverse proxy can't reach it.
ENV NODE_ENV=production \
    MCP_TRANSPORT=http \
    HOST=0.0.0.0

# The server listens on 3000 in HTTP mode. The MCP endpoint is served at /mcp.
EXPOSE 3000

# /healthz and /readyz are exposed by the server in HTTP mode.
# Uses Node's global fetch (Node 22) so no extra packages are needed.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Drop privileges.
USER node

CMD ["affine-mcp"]
