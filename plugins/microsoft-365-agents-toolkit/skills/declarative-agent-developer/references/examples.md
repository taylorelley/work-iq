# M365 JSON Agent Developer Examples

This document provides workflow examples for common M365 Copilot JSON-based agent development scenarios.

> **Note:** This guide is for JSON-based agents that use `.json` manifest files directly.

---

## Example 1: Validate JSON Manifest

Validate manifest files using the ATK CLI:

```bash
# Validate manifest with ATK CLI (the ONLY supported validation method)
atk validate --env local
```

**Use case:** Local validation of manifest schema and required fields before deployment.

---

## Example 2: Development and Provisioning

Complete workflow for provisioning a JSON-based agent to a development environment:

```bash
# Install dependencies (if any)
npm install

# Provision agent to development environment (no compile step needed for JSON agents)
atk provision --env local --interactive false
```

**Result:** Returns a test URL like `https://m365.cloud.microsoft/chat/?titleId=T_abc123xyz` to test the agent in Microsoft 365 Copilot.

**Use case:** Testing agent functionality in a live environment during development.

---

## Example 3: Provision and Share Agent

Workflow for provisioning and sharing an agent with your organization:

```bash
# Provision agent to target environment
atk provision --env dev --interactive false

# Share agent with tenant users
atk share --scope tenant --env dev
```

**Result:** Agent becomes available to all users in the Microsoft 365 tenant.

**Use case:** Deploying a shared agent for organizational use after testing and validation.

---

## Example 4: Package Agent for Distribution

Workflow for creating an agent package for distribution:

```bash
# Package agent for distribution
atk package --env prod
```

**Result:** Creates a distributable package file that can be uploaded to the Microsoft 365 admin center or shared externally.

**Use case:** Creating a final package for production deployment or external distribution.

---

## Example 5: Basic Declarative Agent JSON

A minimal declarative agent manifest file (`declarativeAgent.json`):

```json
{
  "version": "v1.6",
  "name": "My Support Agent",
  "description": "An agent to help with customer support inquiries",
  "instructions": "You are a helpful customer support agent. Help users find information about their issues and guide them to solutions. Be polite and professional at all times."
}
```

---

## Example 6: Agent with Capabilities

A declarative agent with SharePoint and Email capabilities:

```json
{
  "version": "v1.6",
  "name": "Knowledge Base Agent",
  "description": "An agent that searches company knowledge bases and emails",
  "instructions": "You help employees find information from our SharePoint knowledge base and relevant emails. Always cite your sources when providing information.",
  "capabilities": [
    {
      "name": "OneDriveAndSharePoint",
      "items_by_url": [
        {
          "url": "https://contoso.sharepoint.com/sites/KnowledgeBase/Documents"
        }
      ]
    },
    {
      "name": "Email"
    }
  ]
}
```

---

## Example 7: Agent with Conversation Starters

A declarative agent with helpful conversation starters:

```json
{
  "version": "v1.6",
  "name": "HR Assistant",
  "description": "An agent that helps employees with HR-related questions",
  "instructions": "You are an HR assistant helping employees with common HR questions about policies, benefits, and procedures.",
  "conversation_starters": [
    {
      "title": "Time Off Policy",
      "text": "What is our company's time off policy?"
    },
    {
      "title": "Benefits Overview",
      "text": "Can you explain our health insurance benefits?"
    },
    {
      "title": "Expense Reports",
      "text": "How do I submit an expense report?"
    }
  ]
}
```

---

## Example 8: Agent with API Plugin Action

A declarative agent connected to an external API:

```json
{
  "version": "v1.6",
  "name": "Repairs Agent",
  "description": "An agent that helps manage repair tickets",
  "instructions": "You help users create, find, and track repair tickets. Use the repairs API to search for existing tickets and create new ones when requested.",
  "actions": [
    {
      "id": "repairsPlugin",
      "file": "plugins/repairs-plugin.json"
    }
  ],
  "conversation_starters": [
    {
      "title": "My Repairs",
      "text": "What repairs are assigned to me?"
    },
    {
      "title": "Create Repair",
      "text": "I need to create a new repair ticket"
    }
  ]
}
```

---

## Example 9: API Plugin Manifest

A complete API plugin manifest file (`plugins/repairs-plugin.json`):

```json
{
  "schema_version": "v2.4",
  "name_for_human": "Repairs API",
  "namespace": "repairs",
  "description_for_human": "Search and manage repair tickets",
  "description_for_model": "Use this plugin to search for repair tickets, get details about specific repairs, and create new repair requests.",
  "functions": [
    {
      "name": "searchRepairs",
      "description": "Search for repair tickets by keyword or status"
    },
    {
      "name": "getRepair",
      "description": "Get details about a specific repair ticket",
      "parameters": {
        "type": "object",
        "properties": {
          "repairId": {
            "type": "string",
            "description": "The unique ID of the repair ticket"
          }
        },
        "required": ["repairId"]
      }
    },
    {
      "name": "createRepair",
      "description": "Create a new repair ticket",
      "parameters": {
        "type": "object",
        "properties": {
          "title": {
            "type": "string",
            "description": "Title of the repair"
          },
          "description": {
            "type": "string",
            "description": "Detailed description of the issue"
          }
        },
        "required": ["title", "description"]
      },
      "capabilities": {
        "confirmation": {
          "type": "AdaptiveCard",
          "title": "Create Repair?",
          "body": "Create a new repair ticket?"
        }
      }
    }
  ],
  "runtimes": [
    {
      "type": "OpenApi",
      "auth": {
        "type": "None"
      },
      "spec": {
        "url": "https://api.contoso.com/openapi.yaml"
      }
    }
  ]
}
```

---

## Example 10: Full Agent with All Features

A complete agent combining all features:

```json
{
  "version": "v1.6",
  "id": "customer-support-agent",
  "name": "Customer Support Agent",
  "description": "A comprehensive support agent for customer inquiries",
  "instructions": "You are a professional customer support agent for Contoso.\n\nResponsibilities:\n1. Search the knowledge base for relevant documentation\n2. Look up repair tickets and their status\n3. Create new repair tickets when requested\n4. Search support emails for context\n\nGuidelines:\n- Always be polite and professional\n- Cite sources when providing information\n- Ask clarifying questions when needed\n- Never share confidential information",
  "capabilities": [
    {
      "name": "OneDriveAndSharePoint",
      "items_by_url": [
        {
          "url": "https://contoso.sharepoint.com/sites/Support/Documents"
        }
      ]
    },
    {
      "name": "Email",
      "shared_mailbox": "support@contoso.com"
    },
    {
      "name": "WebSearch",
      "sites": [
        {
          "url": "https://docs.contoso.com"
        }
      ]
    }
  ],
  "actions": [
    {
      "id": "repairsApi",
      "file": "plugins/repairs-plugin.json"
    }
  ],
  "conversation_starters": [
    {
      "title": "Check Repair Status",
      "text": "What is the status of my repairs?"
    },
    {
      "title": "Search Knowledge Base",
      "text": "How do I troubleshoot connection issues?"
    },
    {
      "title": "Create New Ticket",
      "text": "I need to create a new support ticket"
    }
  ],
  "disclaimer": {
    "text": "This agent provides general support assistance. For urgent issues, please contact our support hotline."
  }
}
```
