# MCP Server Plugin Integration

This guide explains how to integrate Model Context Protocol (MCP) servers as actions in your Microsoft 365 Copilot agent using JSON manifests.

> **⛔ SINGLE FILE ONLY:** MCP plugins require exactly **ONE file** — the plugin manifest (`{name}-plugin.json`). Tool descriptions are inlined directly in the manifest's `mcp_tool_description.tools` array. **Do NOT create a separate `{name}-mcp-tools.json` file.** There is no `"file"` property — only `"tools": [...]`.

## Overview

MCP servers expose tools that can be consumed by your agent. Unlike OpenAPI-based plugins, MCP plugins use a `RemoteMCPServer` runtime type and embed the tool descriptions directly in the plugin manifest.

> **⚠️ IMPORTANT:** `atk add action` does NOT support MCP servers — it only supports `--api-plugin-type api-spec` for OpenAPI plugins. MCP plugins MUST be created manually following the steps below. This is NOT a violation of the "Always Use `atk add action`" rule — that rule applies only to OpenAPI/REST API plugins.

## Prerequisites

- MCP server URL (must be accessible via HTTP/HTTPS)
- Node.js installed (for MCP Inspector)

---

## Scaffold the Agent Project First

Before adding an MCP plugin, you **must** have a scaffolded agent project. Run `atk new` if you haven't already:

```bash
npx -p @microsoft/m365agentstoolkit-cli@latest atk new \
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

### Step 2: Discover MCP Tools (MANDATORY)

🚨 **THIS STEP IS MANDATORY - DO NOT SKIP**

Run the MCP Inspector to discover the available tools:

```bash
npx --yes @modelcontextprotocol/inspector@0.20.0 --cli {MCP_SERVER_URL} --transport http --method tools/list
```

**Example:**
```bash
npx --yes @modelcontextprotocol/inspector@0.20.0 --cli https://learn.microsoft.com/api/mcp --transport http --method tools/list
```

**⚠️ IMPORTANT:** You MUST run this command to discover the tools. The output contains the tool definitions that you will inline directly into the plugin manifest's `mcp_tool_description.tools` array.

**Expected output structure:**
```json
{
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
```

### Step 3: Create the Plugin Manifest

Create `{name}-plugin.json` in the `appPackage` folder:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json",
  "schema_version": "v2.4",
  "name_for_human": "{NAME-FOR-HUMAN}",
  "description_for_human": "{DESCRIPTION-FOR-HUMAN}",
  "contact_email": "publisher-email@example.com",
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
| `namespace` | Unique identifier, lowercase alphanumeric only |
| `contact_email` | Publisher contact email |

### Step 4: Add Functions from Inspector Output

Read the output from the MCP Inspector (Step 2). For EACH tool in the `tools` array, add a corresponding function entry that preserves **ALL** tool properties:

```json
{
  "functions": [
    {
      "name": "microsoft_docs_search",
      "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query.",
      "parameters": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "A query or topic about Microsoft/Azure products"
          }
        },
        "required": ["query"]
      }
    },
    {
      "name": "microsoft_docs_fetch",
      "description": "Fetch and convert a Microsoft Learn documentation page to markdown format.",
      "parameters": {
        "type": "object",
        "properties": {
          "url": {
            "type": "string",
            "description": "URL of the Microsoft documentation page to read"
          }
        },
        "required": ["url"]
      }
    }
  ]
}
```

**🚨 CRITICAL: Preserve ALL tool properties when mapping from the Inspector output:**

| MCP Inspector Output (`inputSchema`) | Plugin Manifest (`functions[]`) |
|-------------------------------|-------------------------------|
| `name` | `name` — copy EXACTLY, do not rename |
| `description` | `description` — use the **full** description text, do NOT abbreviate or summarize |
| `inputSchema` | `parameters` — copy the entire `inputSchema` object as the `parameters` value |
| `inputSchema.properties` | `parameters.properties` — include ALL properties with their `type`, `description`, and any `enum` values |
| `inputSchema.required` | `parameters.required` — include the full required array |

**Why this matters:** The model uses `description` and `parameters` from the plugin manifest to decide when and how to invoke each tool. If descriptions are shortened or parameters are omitted, the model loses context about what each tool does and what inputs it accepts, leading to incorrect or failed tool calls.

### Step 5: Configure the Runtime

Add the `RemoteMCPServer` runtime with the tools inlined in `mcp_tool_description.tools`:

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
          "tools": [
            {
              "name": "function_name_1",
              "description": "Full tool description from MCP Inspector output",
              "inputSchema": {
                "type": "object",
                "properties": { ... },
                "required": [...]
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

> **⚠️ IMPORTANT:**
> - The `mcp_tool_description.tools` array must contain the **complete** tool definitions from the MCP Inspector output (Step 2). Do NOT use a `file` reference — inline the tools directly.

### Step 6: Register Plugin in Agent Manifest

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
□ Step 0: Scaffold agent project with `atk new` (if not already scaffolded)  ← MANDATORY
□ Step 1: Get MCP server URL from user
□ Step 2: Run MCP Inspector to discover tools                    ← MANDATORY
□ Step 3: Create {name}-plugin.json with basic structure
□ Step 4: Add functions array (one entry per tool from Inspector output)
□ Step 5: Add runtime with RemoteMCPServer type and inline tools in mcp_tool_description.tools
□ Step 6: Register plugin in declarative-agent.json
□ Step 7: Run atk validate --env local
□ Step 8: Run atk provision --env local
```

---

## Complete Example

For the Microsoft Learn MCP server at `https://learn.microsoft.com/api/mcp`:

### `appPackage/docs-plugin.json`

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json",
  "schema_version": "v2.4",
  "name_for_human": "Microsoft Docs",
  "description_for_human": "Search and fetch Microsoft Learn documentation",
  "contact_email": "publisher@example.com",
  "namespace": "msdocs",
  "functions": [
    {
      "name": "microsoft_docs_search",
      "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query.",
      "parameters": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "A query or topic about Microsoft/Azure products"
          }
        },
        "required": ["query"]
      }
    },
    {
      "name": "microsoft_docs_fetch",
      "description": "Fetch and convert a Microsoft Learn documentation page to markdown format.",
      "parameters": {
        "type": "object",
        "properties": {
          "url": {
            "type": "string",
            "description": "URL of the Microsoft documentation page to read"
          }
        },
        "required": ["url"]
      }
    },
    {
      "name": "microsoft_code_sample_search",
      "description": "Search for code snippets and examples in official Microsoft Learn documentation.",
      "parameters": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "A descriptive query, SDK name, method name or code snippet"
          },
          "language": {
            "type": "string",
            "description": "Programming language filter"
          }
        },
        "required": ["query"]
      }
    }
  ],
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": {
        "type": "None"
      },
      "spec": {
        "url": "https://learn.microsoft.com/api/mcp",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "microsoft_docs_search",
              "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "query": {
                    "description": "A query or topic about Microsoft/Azure products",
                    "type": "string"
                  }
                }
              }
            },
            {
              "name": "microsoft_docs_fetch",
              "description": "Fetch and convert a Microsoft Learn documentation page to markdown format.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "url": {
                    "description": "URL of the Microsoft documentation page to read",
                    "type": "string"
                  }
                },
                "required": ["url"]
              }
            },
            {
              "name": "microsoft_code_sample_search",
              "description": "Search for code snippets and examples in official Microsoft Learn documentation.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "query": {
                    "description": "A descriptive query, SDK name, method name or code snippet",
                    "type": "string"
                  },
                  "language": {
                    "description": "Programming language filter",
                    "type": "string"
                  }
                },
                "required": ["query"]
              }
            }
          ]
        }
      },
      "run_for_functions": [
        "microsoft_docs_search",
        "microsoft_docs_fetch",
        "microsoft_code_sample_search"
      ]
    }
  ]
}
```

### Register in `declarative-agent.json`

```json
{
  "actions": [
    {
      "id": "docsPlugin",
      "file": "docs-plugin.json"
    }
  ]
}
```

---

## MCP Inspector Commands

### List available tools
```bash
npx --yes @modelcontextprotocol/inspector@0.20.0 --cli {MCP_URL} --transport http --method tools/list
```

### Test a specific tool
```bash
npx --yes @modelcontextprotocol/inspector@0.20.0 --cli {MCP_URL} --transport http --method tools/call --tool-name {TOOL_NAME} --tool-arg key=value
```

### Get server info
```bash
npx --yes @modelcontextprotocol/inspector@0.20.0 --cli {MCP_URL} --transport http --method initialize
```

---

## Multiple MCP Servers

You can integrate multiple MCP servers by adding multiple runtimes, each with its own inline tools:

```json
{
  "functions": [
    {
      "name": "docs_search",
      "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query.",
      "parameters": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "A query or topic about Microsoft/Azure products"
          }
        },
        "required": ["query"]
      }
    },
    {
      "name": "github_search",
      "description": "Search GitHub repositories, issues, and pull requests for relevant results.",
      "parameters": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "Search query for GitHub"
          }
        },
        "required": ["query"]
      }
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
            {
              "name": "docs_search",
              "description": "Search official Microsoft/Azure documentation.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "query": { "type": "string", "description": "Search query" }
                },
                "required": ["query"]
              }
            }
          ]
        }
      },
      "run_for_functions": ["docs_search"]
    },
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "None" },
      "spec": {
        "url": "https://api.github.com/mcp",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "github_search",
              "description": "Search GitHub repositories, issues, and pull requests.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "query": { "type": "string", "description": "Search query" }
                },
                "required": ["query"]
              }
            }
          ]
        }
      },
      "run_for_functions": ["github_search"]
    }
  ]
}
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Plugin fails to load | Verify `{name}-plugin.json` exists and has correct `mcp_tool_description.tools` array |
| MCP Inspector fails | Ensure the server URL is correct and accessible |
| Tools not recognized | Verify function names match exactly between `functions[]` and `mcp_tool_description.tools[]` |
| Runtime errors | Check that `run_for_functions` includes all functions using that runtime |

---

## Best Practices

1. **Always run MCP Inspector first** - Discover tools before writing the plugin manifest
2. **Preserve ALL tool properties** - Copy the full `description` and complete `inputSchema` → `parameters` for every function; never abbreviate or omit fields
3. **Inline tools in `mcp_tool_description.tools`** - Do NOT use a separate tools file; embed the tools array directly in the runtime spec
4. **Match function names exactly** - Copy tool names directly from the Inspector output
5. **Test locally first** - Use MCP Inspector to verify tools work before integration
6. **Selective tool exposure** - Only include tools relevant to your agent's purpose, but for included tools always keep the full description and parameters
