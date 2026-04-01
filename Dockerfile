ARG WORKIQ_VERSION=0.2.8

FROM node:22-slim

ARG WORKIQ_VERSION

LABEL org.opencontainers.image.title="WorkIQ MCP Server" \
      org.opencontainers.image.description="Self-contained Docker image for the Microsoft WorkIQ MCP server" \
      org.opencontainers.image.source="https://github.com/microsoft/work-iq-mcp" \
      org.opencontainers.image.version="${WORKIQ_VERSION}"

# Install the WorkIQ package globally
RUN npm install -g @microsoft/workiq@${WORKIQ_VERSION} && \
    npm cache clean --force

# Create non-root user
RUN groupadd -r workiq && useradd -r -g workiq -m workiq

# Prepare token cache directory for optional volume mount
RUN mkdir -p /home/workiq/.mcp-auth && chown workiq:workiq /home/workiq/.mcp-auth
VOLUME /home/workiq/.mcp-auth

# OAuth callback port for manual browser authentication
EXPOSE 3334

# Copy entrypoint
COPY --chown=workiq:workiq docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER workiq
WORKDIR /home/workiq

# Runtime configuration
ENV WORKIQ_TENANT_ID=common

ENTRYPOINT ["docker-entrypoint.sh"]
