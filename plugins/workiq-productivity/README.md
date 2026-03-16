# WorkIQ Productivity

> **9 read-only skills** — email, meetings, Teams, SharePoint, projects, and people — powered by the local WorkIQ CLI MCP server only. No remote MCP server dependencies.

## What It Does

WorkIQ Productivity connects to your Microsoft 365 environment through the local WorkIQ CLI (`npx @microsoft/workiq mcp`) to provide read-only productivity insights:

- **action-item-extractor** — Extract action items with owners, deadlines, and priorities from meeting content
- **daily-outlook-triage** — Quick summary of inbox and calendar for the day
- **email-analytics** — Analyze email patterns — volume, senders, response times
- **meeting-cost-calculator** — Calculate time and cost spent in meetings
- **org-chart** — Visual ASCII org chart for any person
- **multi-plan-search** — Search tasks across all Planner plans
- **site-explorer** — Browse SharePoint sites, lists, and libraries
- **channel-audit** — Audit channels for inactivity and cleanup
- **channel-digest** — Summarize activity across multiple channels

## Setup

This plugin only requires the local WorkIQ CLI. The `.mcp.json` file ships pre-configured:

```json
{
  "workiq": {
    "command": "npx",
    "args": ["-y", "@microsoft/workiq@latest", "mcp"],
    "tools": ["*"]
  }
}
```

## Skills

| Skill | Description |
|-------|-------------|
| [**action-item-extractor**](./skills/action-item-extractor/SKILL.md) | Extract action items with owners, deadlines, priorities |
| [**daily-outlook-triage**](./skills/daily-outlook-triage/SKILL.md) | Quick summary of inbox and calendar for the day |
| [**email-analytics**](./skills/email-analytics/SKILL.md) | Analyze email patterns — volume, senders, response times |
| [**meeting-cost-calculator**](./skills/meeting-cost-calculator/SKILL.md) | Calculate time and cost spent in meetings |
| [**org-chart**](./skills/org-chart/SKILL.md) | Visual ASCII org chart for any person |
| [**multi-plan-search**](./skills/multi-plan-search/SKILL.md) | Search tasks across all Planner plans |
| [**site-explorer**](./skills/site-explorer/SKILL.md) | Browse SharePoint sites, lists, and libraries |
| [**channel-audit**](./skills/channel-audit/SKILL.md) | Audit channels for inactivity and cleanup |
| [**channel-digest**](./skills/channel-digest/SKILL.md) | Summarize activity across multiple channels |

## MCP Servers

This plugin uses **only** the local WorkIQ CLI MCP server:

| Server | Command | Capabilities |
|--------|---------|-------------|
| **workiq** | `npx -y @microsoft/workiq@latest mcp` | Natural language queries across all M365 data (emails, meetings, files, Teams, people). Handles its own auth. |

No remote `WorkIQ-*` MCP servers (agent365.svc.cloud.microsoft) are required.

## Platform Support

Supported on `win_x64`, `win_arm64`, `linux_x64`, `linux_arm64`, `osx_x64`, and `osx_arm64`.

## License

See the root [LICENSE](../../LICENSE) file.
