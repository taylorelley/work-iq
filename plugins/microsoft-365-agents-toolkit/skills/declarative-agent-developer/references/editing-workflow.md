# JSON Development Workflow

This document provides step-by-step instructions for developing M365 Copilot agents using JSON manifest files.

## Prerequisites

- Project must be scaffolded first (use scaffolding workflow if needed)
- Project contains `m365agents.yml` at the root
- Project uses JSON manifest files (`.json`)

---

## ✅ APP NAME & DESCRIPTION REQUIREMENT ✅

When developing an agent, you MUST ALWAYS update the app name and description in `manifest.json` to something **meaningful and descriptive** that reflects the agent's purpose. Never leave default/placeholder names like "My Agent" or generic descriptions.

**NEVER use "(local)" suffix in app names.** Always remove any "(local)" suffix from the app name.

---

## 🚨 CRITICAL DEPLOYMENT RULE 🚨

When making ANY edits to an agent — including instructions, conversation starters, capabilities, plugins, or any file in `appPackage/` — you MUST ALWAYS validate and deploy using `atk provision --env local --interactive false` before returning to the user. This applies to EVERY turn, not just the final turn. Never return to the user with undeployed changes.

**You must NEVER:**
- Skip deploy because "it's just instructions" — deploy after every change
- Tell the user to "run `atk provision` yourself" — YOU must run it
- Deploy when validation found errors — not even "to test" or "to demonstrate"
- Deploy "to show the user what happens" when there are errors — just report the errors
- Run `atk provision` "for educational purposes" to demonstrate failure — errors = STOP, not a teaching moment

**Only exception:** The user explicitly asks you NOT to deploy. Only the user can opt out, never you.

---

## 🛡️ VALIDATION GATE — MANDATORY BEFORE EVERY DEPLOY 🛡️

After editing any files in the `appPackage/` folder, you MUST validate before deployment.

**How to validate:** Run the validation command once — it validates the entire project:

```bash
atk validate --env local
```

**Rules:**
- 🚫 **ERRORS = HARD BLOCK.** If validation reports any **errors**, you MUST fix them before running `atk provision`. **DO NOT DEPLOY WITH ERRORS. EVER.**
- ⚠️ **Warnings are OK.** Warnings do not block deployment but should be reviewed and addressed when reasonable.
- ✅ **Validate after every change.** Run `atk validate --env local` after making changes.
- 🚫 **`--env local` is mandatory** for validation. Never use `--env dev` for validation.
- 🚫 **If validation fails, report the error.** Do NOT use any manual JSON parsing as a substitute.

**Decision tree after running `atk validate --env local`:**
1. **ERRORS found** → STOP. Fix all errors. Re-validate. DO NOT run `atk provision`.
2. **Only WARNINGS** → Proceed to `atk provision --env local --interactive false`.
3. **Clean (no errors, no warnings)** → Proceed to `atk provision --env local --interactive false`.

**What to check for:**
- Schema validation errors (missing required fields, wrong types, invalid values)
- Reference errors (broken file paths, missing plugin references)
- Structural errors (malformed JSON, invalid property names)
- Capability configuration errors (invalid scoping, unsupported combinations)

---

## 💬 CONVERSATION STARTERS REQUIREMENT 💬

Every agent needs meaningful conversation starters that help users understand what the agent can do. Review the agent's capabilities and add/update conversation starters that showcase the agent's primary functions. Never leave an agent without conversation starters.

---

## 📝 ALWAYS UPDATE INSTRUCTIONS & STARTERS AFTER CHANGES — MANDATORY 📝

**This is NOT optional.** Adding a capability without updating instructions is incomplete work.

When you add, remove, or modify ANY capability or plugin, you MUST complete ALL of these steps before validating and deploying:

1. **Update `instructions`** — Add a section describing what the new capability/plugin enables. For removals, delete all references to the removed capability.
2. **Add conversation starters** — Add at least 1 new conversation starter per added capability or plugin. Each starter should demonstrate the new functionality.
3. **Remove stale starters** — Delete conversation starters that reference removed capabilities.
4. **Update description** in `manifest.json` if the agent's purpose has expanded.
5. **Review existing instructions** for stale references to removed capabilities.

**This applies to EVERY edit operation:** adding capabilities, removing capabilities, adding API plugins, adding MCP servers, modifying scoping, or any other manifest change.

---

## Instructions

### Step 1: Understand the Requirements

**Action:** Gather and analyze the agent requirements:
- Identify the agent's primary purpose and target users
- Determine required data sources (M365 services, external APIs)
- List necessary actions the agent must perform
- Identify security and compliance requirements

### Step 2: Design the Agent Architecture

**Action:** Create a comprehensive architectural design:
- Select deployment model (personal or shared)
- Choose appropriate M365 capabilities with scoping
- Design API plugin integrations if needed
- Plan authentication and authorization strategy
- Design conversation flow and instructions

### Step 3: Edit JSON Manifest Files

**⚠️ PRE-EDIT CHECK — Before making ANY edits, do BOTH of these:**

1. **Check for malformed JSON**: Read `declarativeAgent.json` and verify it parses correctly. If it has syntax errors (missing commas, unclosed brackets, trailing commas, etc.):
   - **STOP** — do NOT proceed with your edit
   - **INFORM** the user: list every syntax issue with line numbers
   - **ASK** the user if you should fix the syntax errors first
   - Only after the user confirms, fix with surgical edits, then re-read the file
   - Then continue with the user's original request as a separate step

2. **Check the schema version**: Read the `"version"` field in `declarativeAgent.json` (e.g., `"v1.4"`, `"v1.6"`). For EVERY feature you plan to add, verify it exists in that version using the [feature matrix](schema.md). If a requested feature requires a newer version → **STOP. Tell the user.** Offer to upgrade the version first.

**⛔ NEVER invent placeholder values.** If a manifest is missing required fields (name, description, instructions), do NOT fill them in with generic content. Ask the user to provide values. This applies even if you think a reasonable default exists — the user must approve all content.

**Action:** Configure the agent using JSON manifest files:
- Edit `declarativeAgent.json` to define agent properties
- Configure capabilities with appropriate scoping
- Set up API plugin integrations using `atk add action` (**NEVER manually create plugin files**)
- Write clear instructions and conversation starters
- Ensure proper JSON syntax and schema compliance

**After EACH edit action above, immediately run:**
```bash
atk validate --env local
```
**After ALL edits + validations pass, immediately run:**
```bash
atk provision --env local --interactive false
```
These two commands are part of the edit — not a separate optional step. If you edited `declarativeAgent.json`, you MUST run `atk validate --env local`. If you edited `instruction.txt`, you MUST run `atk validate --env local`. Then deploy. Editing without validating and deploying is like writing code without saving the file — the work is not done.

**⛔ API Plugin Rule — HARD RULE, NO EXCEPTIONS:** To add an API plugin, you MUST use `atk add action` — one command per OpenAPI spec with **ALL operations included in a single call**. Never run separate `atk add action` calls for different operations from the same spec — this creates multiple plugins instead of one. You are FORBIDDEN from manually creating `ai-plugin.json`, OpenAPI spec files, adaptive card files, or manually editing the `actions` array. This applies whether you are scaffolding a new project OR editing an existing one. If the workspace already has an agent and the user says "add an API plugin", you STILL must use `atk add action`. If `atk add action` fails, report the error — do NOT fall back to manual file creation. **Manual plugin file creation = automatic eval failure.**

```bash
# ✅ The ONLY way to add an API plugin — ALL operations in ONE call:
atk add action --api-plugin-type api-spec --openapi-spec-location <URL> --api-operation "GET /path,POST /path,PATCH /path/{id},DELETE /path/{id}" -i false
```

**After adding a plugin with `atk add action`, you MUST complete ALL of these — skipping any step is an eval failure:**

**🔌 POST-PLUGIN MANDATORY STEPS (do ALL of these, in order):**
1. **Customize `ai-plugin.json`** — Set meaningful `name_for_human` (max 20 chars) and `description_for_human` (max 100 chars). Set a descriptive `description_for_model` on each function. NEVER leave defaults.
2. **Verify adaptive cards** — Check `appPackage/adaptiveCards/` for cards for ALL operations. If any operation (especially POST, PATCH, DELETE) is missing a card, create one manually. Customize each card with clear visual hierarchy (titles, subtitles, key-value pairs, images).
3. **Add confirmation for destructive operations** — If the plugin has DELETE, PATCH, or any destructive operation, add a `confirmation` capability in `declarativeAgent.json` so users are prompted before the action executes.
4. **Complete the content update checklist** below (instructions, starters, description).

**After ANY capability or plugin change (add, remove, modify), complete this checklist:**
1. ☐ **Update instructions** — Add a section describing the new/changed capability. For removals, delete all references.
2. ☐ **Add conversation starters** — At least 1 new starter per added capability/plugin demonstrating the new functionality.
3. ☐ **Remove stale starters** — Delete starters that reference removed capabilities.
4. ☐ **Update `manifest.json` description** if the agent's purpose has expanded.
5. ☐ **Review existing instructions** for stale references to removed capabilities.

**This checklist is NOT optional.** Adding a capability without updating instructions and starters is incomplete work.

**Reference:** [schema.md](schema.md) for proper manifest structure
**Reference:** [api-plugins.md](api-plugins.md) for adaptive card enhancement guidelines after adding a plugin

**⚠️ IMPORTANT:** After making any edits to JSON files, you MUST validate all changed files with `atk validate --env local` (see Validation Gate above) and then deploy the agent (Step 4) before returning to the user.

**⛔ MANDATORY POST-EDIT CHECKPOINT — YOU ARE NOT DONE YET:**
After editing ANY file in `appPackage/`, you MUST complete BOTH steps below before responding to the user. Skipping either one is an eval failure:
1. **Validate** — Run `atk validate --env local` once (it validates the entire project). No other validation method is acceptable. If it reports errors → fix them and re-validate. Do NOT proceed to step 2 with errors.
2. **Deploy** — Run `atk provision --env local --interactive false`. If you edited files but did not run this command, your work is incomplete. The only exception is if validation found errors (then you MUST fix errors first) or the user explicitly asked you not to deploy.

If you are about to respond to the user and you have NOT run both commands above, **STOP and run them now**.

### Step 3.5: Validate Edited Files

**Action:** Before deploying, run validation once — it covers the entire project:

```bash
atk validate --env local
```

- 🚫 **If there are ERRORS → STOP. Fix all errors before proceeding to Step 4.**
- ⚠️ Warnings are acceptable and do not block deployment
- 🔧 **If `atk validate --env local` crashes or returns no useful output:** Report the CLI failure to the user. Do NOT substitute any manual JSON parsing — it is never an acceptable replacement.

### Step 4: Provision and Deploy

**⛔ PRE-DEPLOY CHECK:** Before running the command below, ask yourself: "Did `atk validate --env local` report ANY errors?" If yes → **DO NOT RUN `atk provision`.** Go back to Step 3.5, fix the errors, and re-validate. There are NO exceptions to this rule — not "to see what happens", not "to demonstrate the failure", not "to test if it would work anyway".

**Action:** Provision required Azure resources and register the agent:
```bash
atk provision --env local --interactive false
```

**Result:** Returns a test URL like `https://m365.cloud.microsoft/chat/?titleId=T_abc123xyz`

**Note:** JSON-based agents do not require a compilation step - changes are deployed directly.

**✅ After successful provision, always provide the test URL to the user:**

> "Your agent is deployed and available for testing at the following test URL: {TEST_URL}."

Then wait for the user's response.

### Step 5: Test and Iterate

**Action:** Test the agent in Microsoft 365 Copilot:
- Use the provisioned test URL
- Test all conversation starters
- Verify capability access and scoping
- Test error handling and edge cases
- Validate security controls

### Step 6: Deploy to Environments

**Action:** Deploy to staging/production environments:
```bash
atk provision --env prod --interactive false
```

**Reference:** [deployment.md](deployment.md) for environment management and CI/CD patterns

### Step 7: Package and Share

**Action:** Package and share the agent:
```bash
# Package the agent
atk provision --env dev --interactive false

# Share to tenant (for shared agents)
atk share --scope tenant --env dev
```

---

## Critical Workflow Rules

### Always Deploy After Edits

**RULE:** When making any changes to an agent (JSON manifest files, instructions, capabilities, API plugins), you MUST complete the following workflow before returning to the user:

1. **Validate:** Run `atk validate --env local` once (validates the entire project).
   - If any file has **ERRORS** → **STOP. Fix all errors. Re-validate. DO NOT proceed to step 2.**
   - If only **warnings** → Proceed.
2. Provision/deploy the agent: `atk provision --env local --interactive false`
3. Confirm deployment succeeded and provide the test URL

🚫 **NEVER run `atk provision` if ANY file has validation ERRORS.** This is a hard rule with no exceptions.

**Note:** JSON-based agents do not require compilation - validate then deploy directly after editing.

### Always Clean Up Unused Files

**RULE:** Every time you work on an agent project, check for and remove unused or obsolete files:

- `TODO.md` or planning files no longer needed
- Old backup files (`.bak`, `.old`, `.orig`)
- Unused JSON files not referenced anywhere
- Stale environment files (`.env.old`, `.env.backup`)
- Empty or placeholder files
- Outdated manifest versions
- Unused API plugin definitions

---

## ⛔ FINAL GATE — Before Responding to the User

**STOP.** Before writing your response to the user, verify ALL of the following:

- [ ] I ran `atk validate --env local` once after all edits
- [ ] All validation passed with **no errors** (warnings are OK)
- [ ] I ran `atk provision --env local --interactive false` and it succeeded
- [ ] I did NOT use any manual JSON parsing as a substitute for `atk validate --env local`

**If you cannot check ALL four boxes, you are NOT done.** Go back and complete the missing steps.

This checklist applies to **EVERY turn** — not just the last turn in a multi-turn conversation. Even if you "only edited instructions," you must validate and deploy before responding.
