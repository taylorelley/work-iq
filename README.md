# Work IQ Docker

> Run [Microsoft Work IQ](https://github.com/microsoft/work-iq) as a self-contained Docker container — no Node.js installation required on the host.

Work IQ is an MCP (Model Context Protocol) server that connects AI assistants to your Microsoft 365 data. This fork packages it into a Docker image so you can build, run, and integrate it entirely through Docker.

> **Public Preview:** Features and APIs may change.

---

## What is Work IQ?

Work IQ lets you query Microsoft 365 using natural language through any MCP-compatible client:

| Data Type | Example Questions |
|-----------|-------------------|
| **Emails** | "What did John say about the proposal?" |
| **Meetings** | "What's on my calendar tomorrow?" |
| **Documents** | "Find my recent PowerPoint presentations" |
| **Teams** | "Summarize today's messages in the Engineering channel" |
| **People** | "Who is working on Project Alpha?" |

It uses the Microsoft 365 Copilot Chat API as its backend and requires delegated permissions granted by a tenant administrator.

---

## Prerequisites

- **Docker** (or Docker Desktop) — [Install Docker](https://docs.docker.com/get-docker/)
- **Microsoft 365 Copilot license** for each user
- **Tenant admin consent** — see the [Tenant Administrator Enablement Guide](./ADMIN-INSTRUCTIONS.md)

No Node.js, npm, or other runtime is needed on the host.

---

## Quick Start

```bash
# Build the image
docker build -t workiq-mcp .

# Run the MCP server (maps OAuth callback port for browser auth)
docker run -i --rm -p 3334:3334 workiq-mcp
```

---

## Building the Image

The Dockerfile installs `@microsoft/workiq` globally inside a `node:22-slim` base image and runs as a non-root `workiq` user.

```bash
# Build with the default version (0.2.8)
docker build -t workiq-mcp .

# Build with a specific version
docker build --build-arg WORKIQ_VERSION=0.2.8 -t workiq-mcp:0.2.8 .
```

### Multi-platform builds

Build for multiple architectures with `buildx`. Multi-platform images must be pushed to a registry (buildx cannot load multi-arch images locally):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/workiq-mcp --push .
```

To build for a single platform and load locally:

```bash
docker buildx build --platform linux/amd64 -t workiq-mcp --load .
```

---

## Running the MCP Server

The container starts the WorkIQ MCP server in stdio mode by default.

```bash
# Default tenant
docker run -i --rm -p 3334:3334 workiq-mcp

# With a specific Entra tenant
docker run -i --rm -p 3334:3334 -e WORKIQ_TENANT_ID=your-tenant-id workiq-mcp

# With token persistence (avoids re-authenticating on every run)
docker run -i --rm -p 3334:3334 -v ~/.mcp-auth:/home/workiq/.mcp-auth workiq-mcp
```

The entrypoint (`docker-entrypoint.sh`) defaults to `workiq mcp`. If `WORKIQ_TENANT_ID` is set to something other than `common`, it automatically prepends `--tenant-id`. You can override the command entirely:

```bash
docker run -i --rm workiq-mcp workiq ask -q "What meetings do I have today?"
```

---

## Authentication

Work IQ uses Microsoft OAuth for authentication. The container listens on port **3334** for the OAuth callback.

### Browser-based authentication

Use this when your host machine has a browser available.

1. Start the container with `-p 3334:3334` to expose the OAuth callback port
2. When authentication is required, the server outputs a sign-in URL
3. Open the URL in your browser and sign in with your Microsoft account
4. The browser redirects to `localhost:3334`, which reaches the container
5. Authentication completes automatically

To **persist tokens** across container restarts, mount the token cache directory:

```bash
docker run -i --rm -p 3334:3334 -v ~/.mcp-auth:/home/workiq/.mcp-auth workiq-mcp
```

### Headless authentication

Use this when your host has **no browser** (e.g. a remote server or VM). The built-in `auth` command runs an interactive paste-back flow — no port mapping is needed.

```bash
# One-time interactive authentication (requires -it for terminal input)
docker run -it --rm -v ~/.mcp-auth:/home/workiq/.mcp-auth workiq-mcp auth

# Or with Docker Compose
docker compose run --rm headless-auth
```

The `auth` command will:

1. Start WorkIQ and trigger the Microsoft OAuth flow
2. Display a sign-in URL — open it on **any device** with a browser (phone, laptop, etc.)
3. After signing in, the browser redirects to `localhost:3334` and shows an error or blank page — **this is expected**
4. Copy the **full URL** from the browser's address bar (it contains the authorization code)
5. Paste it into the container terminal
6. The script delivers the callback locally, completing authentication

Tokens are cached in `~/.mcp-auth/`. Once authenticated, run the MCP server normally without a browser:

```bash
docker run -i --rm -v ~/.mcp-auth:/home/workiq/.mcp-auth workiq-mcp
```

> **Note:** This method requires a human operator and is **not suitable for unattended CI pipelines**. Use pre-provisioned tokens or service-principal credentials for automated environments.

> **Note:** Microsoft OAuth refresh tokens expire periodically (typically 90 days). Re-run the `auth` command when tokens expire.

---

## Using with MCP Clients

Configure your MCP client (VS Code, Claude Code, etc.) to launch the container as a server:

```json
{
  "workiq": {
    "command": "docker",
    "args": ["run", "-i", "--rm", "-p", "3334:3334", "workiq-mcp"],
    "tools": ["*"]
  }
}
```

With a specific tenant and token persistence:

```json
{
  "workiq": {
    "command": "docker",
    "args": [
      "run", "-i", "--rm",
      "-p", "3334:3334",
      "-e", "WORKIQ_TENANT_ID=your-tenant-id",
      "-v", "/path/to/your/.mcp-auth:/home/workiq/.mcp-auth",
      "workiq-mcp"
    ],
    "tools": ["*"]
  }
}
```

> **Note:** Replace `/path/to/your/.mcp-auth` with the absolute path to your `.mcp-auth` directory (e.g. `/home/username/.mcp-auth` on Linux or `C:\Users\username\.mcp-auth` on Windows). Tilde (`~`) is not expanded in JSON config files.

---

## Docker Compose

The included `docker-compose.yml` defines two services:

| Service | Purpose |
|---------|---------|
| `workiq` | Main MCP server with OAuth port mapping and token persistence |
| `headless-auth` | One-time interactive authentication for headless environments |

```bash
# Run the MCP server
docker compose run --rm workiq

# Authenticate (headless, one-time)
docker compose run --rm headless-auth
```

Both services share a named volume (`mcp-auth`) for token persistence. To use a host bind-mount instead, edit `docker-compose.yml` and replace the named volume with:

```yaml
volumes:
  - ${HOME}/.mcp-auth:/home/workiq/.mcp-auth
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WORKIQ_TENANT_ID` | Microsoft Entra tenant ID for authentication | `common` |

### Build Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `WORKIQ_VERSION` | Version of `@microsoft/workiq` to install | `0.2.8` |

---

## Image Details

| Property | Value |
|----------|-------|
| Base image | `node:22-slim` |
| Runs as | Non-root `workiq` user |
| Exposed port | `3334` (OAuth callback) |
| Token cache | `/home/workiq/.mcp-auth` (volume mount point) |
| Entrypoint | `docker-entrypoint.sh` |
| Default command | `workiq mcp` |

---

## Tenant Administrator Setup

To access Microsoft 365 tenant data, a tenant administrator must grant consent to the Work IQ application. See the [Tenant Administrator Enablement Guide](./ADMIN-INSTRUCTIONS.md) for detailed instructions, including a one-click consent URL.

For more information, see Microsoft's [User and Admin Consent Overview](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/user-admin-consent-overview).

---

## Upstream

This project is a fork of [microsoft/work-iq](https://github.com/microsoft/work-iq). For plugin documentation, skill listings, and the Copilot CLI plugin marketplace, see the upstream repository.

---

## License

By using this package, you accept the license agreement. See [NOTICES.TXT](./NOTICES.TXT) and EULA within the package for legal terms.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos is subject to those third-party's policies.
