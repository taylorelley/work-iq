# MCP Server Plugin Integration

This guide explains how to integrate Model Context Protocol (MCP) servers as actions in your Microsoft 365 Copilot agent using JSON manifests. It covers both unauthenticated and OAuth-authenticated MCP servers.

> **⛔ SINGLE FILE ONLY:** MCP plugins require exactly **ONE file** — the plugin manifest (`{name}-plugin.json`). Tool descriptions are inlined directly in the manifest's `mcp_tool_description.tools` array. **Do NOT create a separate `{name}-mcp-tools.json` file.** There is no `"file"` property — only `"tools": [...]`.

## Overview

MCP servers expose tools that can be consumed by your agent. Unlike OpenAPI-based plugins, MCP plugins use a `RemoteMCPServer` runtime type and embed the tool descriptions directly in the plugin manifest.

> **⚠️ IMPORTANT:** `atk add action` does NOT support MCP servers — it only supports `--api-plugin-type api-spec` for OpenAPI plugins. MCP plugins MUST be created manually following the steps below. This is NOT a violation of the "Always Use `atk add action`" rule — that rule applies only to OpenAPI/REST API plugins.

## Prerequisites

- MCP server URL (must be accessible via HTTP/HTTPS)
- Node.js installed (for `mcp-remote` authentication helper)
- Logo images for the agent (color.png 192×192 and outline.png 32×32) — see [Step 5: Logo Images](#step-5-logo-images)

---

## Scaffold the Agent Project First

Before adding an MCP plugin, you **must** have a scaffolded agent project. Run `atk new` if you haven't already:

```bash
atk new \
  -n my-agent \
  -c declarative-agent \
  -i false
```

This creates `m365agents.yml` (and `m365agents.local.yml`) with the **5 required lifecycle steps**:

| Step | Lifecycle Action | What it does |
|------|-----------------|--------------|
| 1 | `teamsApp/create` | Registers the Teams app |
| 2 | `teamsApp/zipAppPackage` | Packages manifest + icons into a zip |
| 3 | `teamsApp/validateAppPackage` | Validates the package (icons, schema, etc.) |
| 4 | `teamsApp/update` | Uploads the package to Teams |
| 5 | `teamsApp/extendToM365` | **Extends the app to M365 Copilot** — generates `M365_TITLE_ID` |

**What breaks without `extendToM365`:** If this step is missing, `atk provision` will register the Teams app and generate `TEAMS_APP_ID`, but the agent will **never appear in Copilot Chat** because no `M365_TITLE_ID` is generated. This is the most common reason for "provision succeeded but agent not found" failures.

> **If you already have a project** but are missing `teamsApp/extendToM365`, add it to the `provision` lifecycle in `m365agents.yml` after `teamsApp/update`. See [deployment.md](deployment.md) for the full provisioning reference.

---

## Step-by-Step Integration

### Step 1: Get MCP Server URL

Ask the user for the MCP server URL. Example: `https://learn.microsoft.com/api/mcp`

Derive the **server root** (scheme + host only): e.g., `https://learn.microsoft.com`

### Step 2: Detect Authentication Requirements

Before discovering tools, determine if the MCP server requires OAuth authentication.

**Probe both well-known endpoints in parallel:**

```bash
curl -s <SERVER_ROOT>/.well-known/oauth-authorization-server
curl -s <SERVER_ROOT>/.well-known/openid-configuration
```

**Decision:**
- **OAuth metadata found** (either endpoint returns valid JSON with `authorization_endpoint`) → the server requires authentication. Follow [authentication.md](authentication.md) Steps 1-3 to discover endpoints, obtain credentials, and configure `oauth/register` in both `m365agents.yml` and `m365agents.local.yml`. Then continue to [Step 3](#step-3-discover-mcp-tools-mandatory) below for authenticated tool discovery.
- **No OAuth metadata** (both return 404 or non-JSON) → the server is unauthenticated. Skip directly to [Step 3](#step-3-discover-mcp-tools-mandatory) for unauthenticated tool discovery.

### Step 3: Discover MCP Tools (MANDATORY)

🚨 **THIS STEP IS MANDATORY — DO NOT SKIP**

You MUST discover tools via the MCP protocol directly. Tool discovery uses HTTP POST requests to the MCP server URL.

#### 3a. Authenticate (OAuth servers only)

If the server requires OAuth (detected in Step 2), perform a one-time authentication:

Tell the user:
> "I need to authenticate with [name]'s MCP server. A browser window will open — please sign in."

```bash
npx -p mcp-remote@latest mcp-remote-client <MCP_SERVER_URL> --port 3334
```

> **WSL / headless environments:** `mcp-remote` starts a local HTTP server for the OAuth callback and tries to open a browser. In WSL, the browser opens on the Windows host but the `http://127.0.0.1:3334/...` callback URL may not route back to WSL. If the browser opens but authentication seems stuck:
> 1. After signing in, copy the full callback URL from the browser (it will show an error or blank page)
> 2. Run `curl '<callback-url>'` inside WSL to deliver the auth code to mcp-remote
> 3. Alternatively, run `export BROWSER=wslview` before the command so WSL's browser opener is used, which handles the redirect correctly

Wait for it to complete. The token is cached at `~/.mcp-auth/mcp-remote-*/{hash}_tokens.json`.

**Read the cached access token:**

```bash
ls ~/.mcp-auth/mcp-remote-*/
```

Find the token file (pattern: `{url-hash}_tokens.json`), read it, and extract `access_token`.

**⛔ Security:** Do NOT print the token value in your output. Extract it silently and use it only in subsequent HTTP calls. Do NOT write it to any file or create copies.

#### 3b. MCP Session Handshake

Run three sequential HTTP calls to discover tools.

**⛔ Security:** Suppress raw HTTP responses that may contain tokens. Only extract the fields you need (`mcp-session-id`, tool definitions). Do NOT display Authorization headers or token values to the user.

**Call 1 — Initialize:**

```bash
curl -s -X POST <MCP_SERVER_URL> \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  [-H "Authorization: Bearer <access_token>"] \
  -D - \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"m365-agent-skill","version":"1.0.0"}}}'
```

Extract `mcp-session-id` from the response headers. Omit the `Authorization` header for unauthenticated servers.

**Call 2 — Initialized notification:**

```bash
curl -s -X POST <MCP_SERVER_URL> \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: <session_id>" \
  [-H "Authorization: Bearer <access_token>"] \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'
```

**Call 3 — List tools (with pagination):**

```bash
curl -s -X POST <MCP_SERVER_URL> \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: <session_id>" \
  [-H "Authorization: Bearer <access_token>"] \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
```

If the response contains `nextCursor`, repeat with `{"params":{"cursor":"<nextCursor>"}}` until no cursor remains. Collect all tools.

**Extracting tools from the response:**

Save the raw tools/list response to a file, then use this script to extract the tools array:

```bash
python3 << 'EXTRACT_TOOLS'
import json, sys

with open("/tmp/mcp-tools-response.json") as f:
    data = json.load(f)

tools = data.get("result", {}).get("tools", [])
with open("/tmp/mcp-tools.json", "w") as out:
    json.dump(tools, out, indent=2)

print(f"Extracted {len(tools)} tools")
for t in tools:
    print(f"  - {t['name']}: {t.get('description', '')[:80]}")
EXTRACT_TOOLS
```

> **⛔ Do NOT use inline Python inside command substitutions** (e.g., `$(python3 -c '...')`). The shell security policy blocks nested command substitutions. Always use heredoc scripts (`<< 'EOF'`) or standalone `.py` files instead.

**Expected output structure:**
```json
{
  "result": {
    "tools": [
      {
        "name": "tool_name",
        "description": "Tool description",
        "inputSchema": {
          "type": "object",
          "properties": { ... },
          "required": [...]
        }
      }
    ]
  }
}
```

#### 3c. Use All Discovered Tools

**Include ALL tools** returned by `tools/list` in the plugin manifest. Do NOT filter or exclude tools unless the developer explicitly asks to limit the tool set.

Tell the user how many tools were discovered and confirm they will all be included.

#### 3d. Clean Up Cached Tokens

After tool discovery is complete and you have all the information needed, **immediately** delete the cached tokens:

```bash
rm -rf ~/.mcp-auth
```

**⛔ Security:** Do NOT leave tokens behind. The `~/.mcp-auth` directory must be removed as soon as tool discovery finishes — before proceeding to manifest creation.

### Step 4: Create the Plugin Manifest

Create `{name}-plugin.json` in the `appPackage` folder:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json",
  "schema_version": "v2.4",
  "name_for_human": "{NAME-FOR-HUMAN}",
  "description_for_human": "{DESCRIPTION-FOR-HUMAN}",
  "namespace": "simplename",
  "functions": [],
  "runtimes": []
}
```

**Required fields:**
| Field | Description |
|-------|-------------|
| `name_for_human` | Display name shown to users (max 20 characters) |
| `description_for_human` | Brief description of the plugin (max 100 characters) |
| `namespace` | Unique identifier, lowercase alphanumeric only (no hyphens, no underscores) |

### Step 4a: Add Functions from Discovered Tools

For EACH discovered tool from Step 3, add a function entry with `name`, `description`, and `capabilities` only. Do **NOT** duplicate `parameters`/`inputSchema` in the function — all tool schema data lives exclusively in `mcp_tool_description.tools[]` (see Step 6).

```json
{
  "functions": [
    {
      "name": "microsoft_docs_search",
      "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query."
    }
  ]
}
```

**🚨 CRITICAL: Preserve ALL tool properties when creating function entries:**

| MCP tools/list Output | Plugin Manifest (`functions[]`) |
|---|---|
| `name` | `name` — copy EXACTLY, do not rename |
| `description` | `description` — use the **full** description text, do NOT abbreviate or summarize |
| `inputSchema` | Do NOT add to `functions[]` — this goes in `mcp_tool_description.tools[]` only |

**Why this matters:** The model uses `description` from functions to decide when to invoke each tool. The runtime uses the full tool definitions from `mcp_tool_description.tools[]` (including `inputSchema`) to actually call the MCP server. Do not duplicate schema data in both places.

### Step 4b: Add Response Semantics

**ALWAYS** add `capabilities.response_semantics` to every function — even if no title or URL fields can be identified. Never omit it.

For each tool:
1. Check the tool's `outputSchema` field (optional in MCP — present on some servers). If present, read field names from it directly.
2. If `outputSchema` is absent (common), reason from the tool's `description` text to identify which fields are returned. Look for mentions of URL fields (`url`, `link`, `href`) and title fields (`title`, `name`, `label`).
3. If you can confidently identify BOTH a title-like field AND a navigable URL field → use the **rich pattern**.
4. Otherwise → use the **default pattern**.

**Rich pattern** (when title + URL field are identified):
```json
{
  "name": "tool_name",
  "description": "...",
  "capabilities": {
    "response_semantics": {
      "data_path": "$.items",
      "properties": {
        "title": "$.title",
        "url": "$.url"
      },
      "static_template": {
        "type": "AdaptiveCard",
        "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.6",
        "body": [
          {
            "type": "TextBlock",
            "text": "[${title}](${url})",
            "wrap": true,
            "maxLines": 2
          }
        ]
      }
    }
  }
}
```

**Default pattern** (when title or URL cannot be confidently identified):
```json
{
  "name": "tool_name",
  "description": "...",
  "capabilities": {
    "response_semantics": {
      "data_path": "$",
      "properties": {},
      "static_template": {
        "type": "AdaptiveCard",
        "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.6",
        "body": []
      }
    }
  }
}
```

**Response semantics rules:**
- `$schema`: always `https://adaptivecards.io/schemas/adaptive-card.json` (not `http://`)
- `version`: always `"1.6"`
- Rich template body is always `"[${title}](${url})"` — the title IS the hyperlink
- Source name comes from `name_for_human` automatically — do NOT add it as a TextBlock
- `data_path` and field paths are connector-specific — derive them from the tool's actual response structure

### Step 5: Logo Images

Logo images are **required** for all agent packages. You need two formats:

- **`color.png`** — 192×192 px, full colour
- **`outline.png`** — 32×32 px, white-on-transparent

Ask the user:
> "Do you have logo images for [name]? I need two formats:
> - **color.png** — 192×192 px, full colour
> - **outline.png** — 32×32 px, white-on-transparent
>
> You can provide a URL to download from, provide local file paths, or I can download the official logo automatically."

**Resolving logo inputs — check in this order:**

1. **URL**: If the user provides a URL, download the image with `curl -L -o <tempfile> <url>`.
2. **Local file path**: If the user provides a path, use it directly.
3. **Auto-download**: If the user provides nothing, search the web for the official logo of [name], find a square colour logo, and download it.

**Handling missing formats:**
- If the user provides only one image, ask: "I have your [color/outline] logo. For the [other format], would you like to provide it, or shall I generate it automatically?"
- If the user says to generate it, derive it from the provided image using jimp.
- If the user says the provided images already meet the size requirements, skip processing and use them directly.

**Processing with jimp** (only when resizing or conversion is needed):

```javascript
// Install: npm install jimp (in a temp directory)
// Import: const { Jimp } = require('jimp');

// color.png: resize to 192x192
// outline.png: resize to 32x32, convert all non-transparent pixels to white on transparent background
```

Output files: `appPackage/color.png` (192×192) and `appPackage/outline.png` (32×32 white-on-transparent).

Show the resulting icon(s) to the user for approval before proceeding. If the user rejects, ask them to provide their own images and do NOT proceed until approved.

### Step 6: Configure the Runtime

Add the `RemoteMCPServer` runtime with the tools inlined in `mcp_tool_description.tools`:

**For authenticated servers** (see [authentication.md](authentication.md)):
```json
{
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": {
        "type": "OAuthPluginVault",
        "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}"
      },
      "spec": {
        "url": "{MCP_SERVER_URL}",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "function_name_1",
              "description": "Full tool description from tools/list output",
              "inputSchema": {
                "type": "object",
                "properties": { "..." : "..." },
                "required": ["..."]
              }
            }
          ]
        }
      },
      "run_for_functions": [
        "function_name_1",
        "function_name_2"
      ]
    }
  ]
}
```

**For unauthenticated servers:**
```json
{
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": {
        "type": "None"
      },
      "spec": {
        "url": "{MCP_SERVER_URL}",
        "mcp_tool_description": {
          "tools": [ ... ]
        }
      },
      "run_for_functions": [ ... ]
    }
  ]
}
```

> **⚠️ IMPORTANT:**
> - The `mcp_tool_description.tools` array must contain the **complete** tool definitions from the tools/list output (Step 3). Do NOT use a `file` reference — inline the tools directly.
> - For authenticated servers, both `m365agents.yml` and `m365agents.local.yml` must include the `oauth/register` step — see [authentication.md](authentication.md).

### Step 7: Register Plugin in Agent Manifest

Add the plugin to your `declarative-agent.json`:

```json
{
  "actions": [
    {
      "id": "mcpPlugin",
      "file": "{name}-plugin.json"
    }
  ]
}
```

---

## Complete Workflow Checklist

```
□ Step 0: Scaffold agent project with `atk new` (if not already scaffolded)      ← MANDATORY
□ Step 1: Get MCP server URL from user
□ Step 2: Detect authentication requirements (probe well-known endpoints)
□       → If OAuth: follow authentication.md (discover endpoints, get creds, configure oauth/register)
□ Step 3: Discover tools via MCP protocol (initialize → tools/list)               ← MANDATORY
□       → Include ALL tools (do not filter unless developer explicitly requests it)
□ Step 4: Create {name}-plugin.json with functions + response_semantics
□ Step 5: Process logo images (color.png 192×192, outline.png 32×32)
□ Step 6: Add runtime with RemoteMCPServer type (OAuthPluginVault or None)
□ Step 7: Register plugin in declarativeAgent.json
□ Step 8: Run atk validate --env local
□ Step 9: Run atk provision --env local --interactive false
```

---

## Complete Example — Unauthenticated Server

For the Microsoft Learn MCP server at `https://learn.microsoft.com/api/mcp`:

### `appPackage/docs-plugin.json`

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json",
  "schema_version": "v2.4",
  "name_for_human": "Microsoft Docs",
  "description_for_human": "Search and fetch Microsoft Learn documentation",
  "namespace": "msdocs",
  "functions": [
    {
      "name": "microsoft_docs_search",
      "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query.",
      "capabilities": { "response_semantics": { "data_path": "$.results", "properties": { "title": "$.title", "url": "$.url" }, "static_template": { "type": "AdaptiveCard", "$schema": "https://adaptivecards.io/schemas/adaptive-card.json", "version": "1.6", "body": [{ "type": "TextBlock", "text": "[${title}](${url})", "wrap": true, "maxLines": 2 }] } } }
    },
    {
      "name": "microsoft_docs_fetch",
      "description": "Fetch and convert a Microsoft Learn documentation page to markdown format.",
      "capabilities": { "response_semantics": { "data_path": "$", "properties": {}, "static_template": { "type": "AdaptiveCard", "$schema": "https://adaptivecards.io/schemas/adaptive-card.json", "version": "1.6", "body": [] } } }
    }
  ],
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "None" },
      "spec": {
        "url": "https://learn.microsoft.com/api/mcp",
        "mcp_tool_description": {
          "tools": [
            { "name": "microsoft_docs_search", "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query.", "inputSchema": { "type": "object", "properties": { "query": { "description": "A query or topic about Microsoft/Azure products", "type": "string" } } } },
            { "name": "microsoft_docs_fetch", "description": "Fetch and convert a Microsoft Learn documentation page to markdown format.", "inputSchema": { "type": "object", "properties": { "url": { "description": "URL of the Microsoft documentation page to read", "type": "string" } }, "required": ["url"] } }
          ]
        }
      },
      "run_for_functions": ["microsoft_docs_search", "microsoft_docs_fetch"]
    }
  ]
}
```

Register in `declarative-agent.json`: `{ "actions": [{ "id": "docsPlugin", "file": "docs-plugin.json" }] }`

---

## Complete Example — Authenticated Server

For an OAuth-protected MCP server at `https://mcp.example.com/mcp`. See [authentication.md](authentication.md) for the full `oauth/register` template (must be added to both `m365agents.yml` and `m365agents.local.yml`).

### `appPackage/example-plugin.json`

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json",
  "schema_version": "v2.4",
  "name_for_human": "Example Service",
  "description_for_human": "Search and browse Example Service content",
  "namespace": "example",
  "functions": [
    {
      "name": "search",
      "description": "Search Example Service for content matching a query.",
      "capabilities": { "response_semantics": { "data_path": "$.items", "properties": { "title": "$.title", "url": "$.url" }, "static_template": { "type": "AdaptiveCard", "$schema": "https://adaptivecards.io/schemas/adaptive-card.json", "version": "1.6", "body": [{ "type": "TextBlock", "text": "[${title}](${url})", "wrap": true, "maxLines": 2 }] } } }
    }
  ],
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "OAuthPluginVault", "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}" },
      "spec": {
        "url": "https://mcp.example.com/mcp",
        "mcp_tool_description": {
          "tools": [
            { "name": "search", "description": "Search Example Service for content matching a query.", "inputSchema": { "type": "object", "properties": { "query": { "description": "Search query", "type": "string" } }, "required": ["query"] } }
          ]
        }
      },
      "run_for_functions": ["search"]
    }
  ]
}
```

---

## Multiple MCP Servers

You can integrate multiple MCP servers by adding multiple runtimes, each with its own auth type. Each runtime has its own `mcp_tool_description.tools` and `run_for_functions`:

```json
{
  "functions": [
    { "name": "docs_search", "description": "Search Microsoft docs.", "capabilities": { "response_semantics": { "data_path": "$", "properties": {}, "static_template": { "type": "AdaptiveCard", "$schema": "https://adaptivecards.io/schemas/adaptive-card.json", "version": "1.6", "body": [] } } } },
    { "name": "search", "description": "Search authenticated service.", "capabilities": { "response_semantics": { "data_path": "$", "properties": {}, "static_template": { "type": "AdaptiveCard", "$schema": "https://adaptivecards.io/schemas/adaptive-card.json", "version": "1.6", "body": [] } } } }
  ],
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "None" },
      "spec": { "url": "https://learn.microsoft.com/api/mcp", "mcp_tool_description": { "tools": [{ "name": "docs_search", "description": "Search Microsoft docs.", "inputSchema": { "type": "object", "properties": { "query": { "type": "string" } }, "required": ["query"] } }] } },
      "run_for_functions": ["docs_search"]
    },
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "OAuthPluginVault", "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}" },
      "spec": { "url": "https://mcp.example.com/mcp", "mcp_tool_description": { "tools": [{ "name": "search", "description": "Search authenticated service.", "inputSchema": { "type": "object", "properties": { "query": { "type": "string" } }, "required": ["query"] } }] } },
      "run_for_functions": ["search"]
    }
  ]
}
```

---

## Validation Notes

When running `atk validate --env local` on projects with MCP plugins, you may see:

- `Unrecognized member 'type' with value 'RemoteMCPServer'`
- `Unrecognized member 'auth'`
- `Unrecognized member 'spec'`

These are **known false positives** — the ATK validator schema predates `RemoteMCPServer` support. Safe to ignore; do NOT surface to the user as errors. Proceed to provision if these are the only issues.

---

## Common Issues

| Issue | Solution |
|---|---|
| Plugin fails to load | Verify `{name}-plugin.json` exists and has correct `mcp_tool_description.tools` array |
| Tools not recognized | Verify function names match exactly between `functions[]` and `mcp_tool_description.tools[]` |
| Runtime errors | Check that `run_for_functions` includes all functions using that runtime |
| OAuth token errors | Re-authenticate with `mcp-remote` — cached tokens may have expired |
| `<PREFIX>_MCP_AUTH_ID` empty | Check `oauth/register` step in both `m365agents.yml` and `m365agents.local.yml` and verify credentials |
| "Invalid redirect URI" | Ensure redirect URI in DCR is `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect` |

---

## Best Practices

1. **Always discover tools via MCP protocol** — run the full handshake (initialize → notifications/initialized → tools/list) before writing the plugin manifest. **NEVER fabricate tool names or descriptions.**
2. **Preserve ALL tool properties in `mcp_tool_description.tools`** — copy the full `description` and complete `inputSchema` for every tool; never abbreviate or omit fields. Do NOT duplicate `inputSchema` as `parameters` in `functions[]`.
3. **Inline tools in `mcp_tool_description.tools`** — do NOT use a separate tools file; embed the tools array directly in the runtime spec
4. **Match function names exactly** — copy tool names directly from the tools/list output
5. **Always add response semantics** — every function must have `capabilities.response_semantics`, even if using the default (empty body) pattern
6. **Include all tools by default** — inline every tool from `tools/list` unless the developer explicitly asks to limit the set; for all included tools always keep the full description and inputSchema
7. **Process logos before provisioning** — the agent package requires `color.png` (192×192) and `outline.png` (32×32) in `appPackage/`
