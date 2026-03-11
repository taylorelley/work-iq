---
name: declarative-agent-developer
description: >
  Create, build, and deploy declarative agents for M365 Copilot and Teams. Scaffolds new M365 agent
  projects, authors JSON manifests, configures capabilities, and manages the full agent lifecycle.
  Use when creating a new agent, building a Teams agent, or working on any M365 Copilot declarative agent.
  Triggers: "create agent", "create a declarative agent", "new declarative agent",
  "create m365 agent", "create Teams agent", "build an agent", "build a declarative agent",
  "scaffold an agent", "new agent project", "make a copilot agent", "create a copilot agent",
  "add a capability", "add a plugin", "configure my agent", "deploy my agent",
  "provision my agent", "fix my agent manifest", "validate my agent", "edit my agent",
  "modify my agent", "update my agent instructions", "add conversation starters",
  "add a web search capability", "add graph connectors", "add an API plugin", "add an MCP plugin",
  "add OAuth to my plugin", "MCP authentication", "add logo to my agent"
---

# M365 Agent Developer

## ⛔ Workspace Check — MANDATORY FIRST STEP

**Before doing ANYTHING, run `atk validate --env local` to fingerprint the workspace:**

```bash
atk validate --env local
```

This single command tells you the project state. Interpret the output:

| Output | Meaning | Gate | Action |
|--------|---------|------|--------|
| Command not found | ATK CLI not installed | **Stop** | Tell the user to install ATK. Do NOT attempt to install it yourself. |
| Fails with "not a project" / no m365agents.yml | Not an ATK project | **Check** | Look for non-agent indicators (Express, React, etc.) → **Reject** or user wants new project → **Scaffold** |
| Reports validation errors | Manifest has issues | **Fix** | Detect → Inform → Ask (see below). Do NOT deploy. |
| Passes (with or without warnings) | Valid agent project | **Edit** | → [Editing Workflow](references/editing-workflow.md) |

**If `atk validate` cannot run**, fall back to manual checks:
1. Check for `appPackage/declarativeAgent.json` and `m365agents.yml`
2. Check for non-agent indicators (`package.json` with express/react/next, `src/index.js`, `app.py`, etc.)

**Then follow the decision gate:**

| Condition | Gate | Action |
|-----------|------|--------|
| Non-agent project files, no `appPackage/` | **Reject** | Text-only response. No files, no commands. |
| No manifest, user wants to edit/deploy | **Reject** | Text-only response. Explain manifest is missing. |
| No manifest, user wants new project | **Scaffold** | → [Scaffolding Workflow](references/scaffolding-workflow.md) |
| Manifest exists with errors | **Fix** | Detect → Inform → Ask (see below). Do NOT deploy. |
| Valid agent project | **Edit** | → [Editing Workflow](references/editing-workflow.md) |

> **Detailed gate rules, examples, and anti-patterns:** [Workspace Gates](references/workspace-gates.md)

### 🚫 HARD REJECTION RULES — No Exceptions

**These rules override ALL other instructions.** If any of these apply, you MUST stop immediately.

1. **NEVER create `declarativeAgent.json` yourself.** If the manifest is missing and the user asked to edit/modify/deploy, respond with text only: explain the manifest is missing, suggest `atk new` or starting from scratch. Do NOT create the file, do NOT create `appPackage/`, do NOT "help" by scaffolding implicitly.

2. **NEVER create files in a non-agent project.** If the workspace is an Express/React/Django/etc. app without `appPackage/`, your response must be text-only. Do NOT create any files, do NOT run any commands.

3. **NEVER deploy when errors exist.** If `atk validate --env local` reports errors, STOP. Do NOT run `atk provision` — not "to test", not "to demonstrate the error", not "to see what happens". Report the errors and ask the user how to proceed.

### 🔍 Detect → Inform → Ask (Error-Handling Protocol)

When you encounter ANY problem (missing files, malformed JSON, validation errors, incompatible features), you MUST follow this sequence **in order**:

1. **Detect** — Identify the specific problem. For JSON issues, attempt to parse the file and report syntax errors. For missing fields, run `atk validate --env local`.
2. **Inform** — Tell the user BEFORE taking any action. Describe exactly what is wrong ("declarativeAgent.json has malformed JSON: missing comma on line 12, unclosed array on line 18").
3. **Ask** — Wait for the user's response before making changes. Do NOT silently fix, auto-correct, or work around the problem.

**This protocol applies to:**
- Missing `declarativeAgent.json` → Detect (file not found) → Inform ("no manifest found") → Ask ("would you like to create a new agent?")
- Malformed JSON → Detect (parse errors) → Inform (list specific syntax issues) → Ask ("should I fix these syntax errors?")
- Validation errors → Detect (`atk validate` output) → Inform (list all errors) → Ask ("how would you like to fix these?")
- Version incompatibility → Detect (feature requires newer version) → Inform ("this feature requires v1.6, your agent is v1.4") → Ask ("should I upgrade?")

---

## Phase Routing

| Scenario | Workflow Reference |
|----------|-------------------|
| Creating a NEW project from scratch | [Scaffolding Workflow](references/scaffolding-workflow.md) |
| Working with existing `.json` manifests | [Editing Workflow](references/editing-workflow.md) |
| Adding an API plugin | [API Plugins](references/api-plugins.md) |
| Adding an MCP server | [MCP Plugin](references/mcp-plugin.md) |
| Adding OAuth to an MCP or API plugin | [Authentication](references/authentication.md) |
| Writing agent instructions | [Conversation Design](references/conversation-design.md) |

---

## ATK CLI Setup

Before running any ATK commands, check if the ATK CLI is available by running `atk --version`. If not found, **STOP and tell the user** — do NOT attempt to install it yourself.

All commands use `atk` directly (e.g., `atk provision --env local`).

---

## Critical Rules

### 1. Validate + Deploy After EVERY Edit

After ANY change to files in `appPackage/`, you MUST run both steps before responding:

```bash
# Step 1: Validate (REQUIRED — always use --env local for validation)
atk validate --env local

# Step 2: Deploy (REQUIRED — skip ONLY if validation found errors)
atk provision --env local
```

- Only `atk validate --env local` counts — no other validation method is acceptable
- If validation finds errors → **STOP. Fix errors. Re-validate. Do NOT deploy.**
- Warnings are OK — they don't block deployment
- Exception: user explicitly asks you not to deploy → validate only

### 2. Never Invent Content or Create Missing Files

- Do NOT invent placeholder names, descriptions, or instructions
- Do NOT create `declarativeAgent.json` or `appPackage/` if they don't exist — this is a REJECT scenario, not a "help by creating" scenario
- If required fields are missing, run `atk validate --env local`, report the gaps, and ASK the user
- If JSON is malformed, follow Detect → Inform → Ask: parse the file first, tell the user what's broken, then ask before fixing. Use surgical edits (not rewrites)

### 3. Schema Version Compatibility

Before adding ANY feature, read the `version` field in `declarativeAgent.json` and check the [Schema](references/schema.md) feature matrix. If the feature isn't supported in that version, **refuse** and offer to upgrade.

Key version gates:
- `sensitivity_label`, `worker_agents`, `EmbeddedKnowledge` → **v1.6 only**
- `Meetings` → **v1.5+**
- `ScenarioModels`, `behavior_overrides`, `disclaimer` → **v1.4+**
- `Dataverse`, `TeamsMessages`, `Email`, `People` → **v1.3+**

### 4. Use `atk add action` for API Plugins — NEVER Create Plugin Files Manually

You are **forbidden** from manually creating `ai-plugin.json`, OpenAPI specs, adaptive cards, or editing the `actions` array. Use the CLI:

```bash
# ⛔ Always list ALL operations in a single call — NEVER run separate calls per operation
atk add action --api-plugin-type api-spec --openapi-spec-location URL --api-operation "GET /path,POST /path,PATCH /path/{id},DELETE /path/{id}" -i false
```

Run a **single** `atk add action` call per OpenAPI spec, listing **all** operations as a comma-separated list in `--api-operation`. Never run separate `atk add action` calls for different operations from the same spec — this creates multiple plugins instead of one. If `atk add action` fails, report the error; do NOT fall back to manual creation.

> **Exception:** MCP servers are not supported by `atk add action`. Use the [MCP Plugin workflow](references/mcp-plugin.md) instead.

### 5. MCP Server Integration

When the user mentions an MCP server URL, follow the [MCP Plugin workflow](references/mcp-plugin.md). You MUST discover tools via the MCP protocol handshake (initialize → notifications/initialized → tools/list) — **NEVER fabricate tool names/descriptions**. For authenticated MCP servers, follow the [authentication guide](references/authentication.md) to configure OAuth.

### 6. Always Update Instructions & Starters After Changes

Adding a capability or plugin without updating instructions is incomplete. After ANY change:
1. Update instructions to describe the new/changed functionality
2. Add at least 1 conversation starter per added capability/plugin
3. Remove starters that reference removed capabilities

### 7. App Name Requirement

Always update the app name and description to something meaningful. Never leave defaults like "My Agent".

---

## References

### Shared
- **[Authentication](references/authentication.md)** — OAuth discovery, credentials, oauth/register lifecycle, OAuthPluginVault
- **[Best Practices](references/best-practices.md)** — Security, performance, testing, compliance
- **[Conversation Design](references/conversation-design.md)** — Instructions and conversation starters
- **[Deployment](references/deployment.md)** — ATK CLI workflows, environments, CI/CD
- **[Workspace Gates](references/workspace-gates.md)** — Detailed gate rules, examples, anti-patterns

### Scaffolding
- **[Scaffolding Workflow](references/scaffolding-workflow.md)** — Step-by-step scaffolding instructions, naming rules, error handling

### JSON Development
- **[Editing Workflow](references/editing-workflow.md)** — Step-by-step JSON development instructions
- **[Schema](references/schema.md)** — Official JSON schema for agent manifests
- **[API Plugins](references/api-plugins.md)** — OpenAPI integration for JSON agents
- **[MCP Plugin](references/mcp-plugin.md)** — MCP server integration with RemoteMCPServer, OAuth, response semantics, logo handling
- **[Examples](references/examples.md)** — JSON manifest examples
