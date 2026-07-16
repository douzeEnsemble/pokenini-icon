# Workflow A Correlation ID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `pokenini-back` find the exact GitHub Actions run a specific button click started, by having `update-images.yml` accept a `correlation_id` input and echo it in the run's display title.

**Architecture:** Add a `workflow_dispatch` input and a `run-name` to the existing, already-merged `update-images.yml`. No other file changes — Workflow B is unchanged (it's matched by `head_sha`, not by anything it declares).

**Tech Stack:** GitHub Actions YAML.

## Global Constraints

- Do not touch `.github/workflows/publish-images-to-resources.yml` or any Makefile target — this plan only adds an input/run-name to one existing workflow.
- Companion spec: `../pokenini-web/docs/superpowers/specs/2026-07-15-image-pipeline-status-tracking-design.md`.

---

### Task 1: Add `correlation_id` input and `run-name` to Workflow A

**Files:**
- Modify: `.github/workflows/update-images.yml`

**Interfaces:**
- Produces: the `workflow_dispatch` API call `pokenini-back` makes must now include `"inputs": {"correlation_id": "<value>"}` in its request body — this is the exact key name `pokenini-back`'s `GithubActionsApiService::dispatchWorkflow()` will send.

- [ ] **Step 1: Add the input and run-name**

Change the top of `.github/workflows/update-images.yml` from:

```yaml
name: Update Pokémon images

on:
  workflow_dispatch: {}
```

to:

```yaml
name: Update Pokémon images

on:
  workflow_dispatch:
    inputs:
      correlation_id:
        required: true
        type: string

run-name: "Update images (${{ inputs.correlation_id }})"
```

Nothing else in the file changes.

- [ ] **Step 2: Validate the YAML parses and the structure is correct**

Run:
```bash
python3 -c "
import yaml
doc = yaml.safe_load(open('.github/workflows/update-images.yml'))
trigger_key = True if True in doc else 'on'
inputs = doc[trigger_key]['workflow_dispatch']['inputs']
assert inputs['correlation_id']['required'] is True
assert inputs['correlation_id']['type'] == 'string'
assert doc['run-name'] == 'Update images (\${{ inputs.correlation_id }})'
print('STRUCTURE OK')
"
```
Expected: `STRUCTURE OK` printed, no `AssertionError`/`KeyError`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/update-images.yml
git commit -m "Add correlation_id input and run-name so runs can be matched to a specific dispatch"
```

---

### Task 2: End-to-end validation (manual, needs a real dispatch)

This can only be done once `pokenini-back`'s companion plan (which sends the `correlation_id` input) is implemented — do this after, not as part of implementing this repo's change in isolation.

- [ ] **Step 1: Dispatch with a correlation id and confirm the run name**

```bash
gh workflow run update-images.yml --repo douzeEnsemble/pokenini-icon -f correlation_id=test-12345
gh run list --repo douzeEnsemble/pokenini-icon --workflow update-images.yml --limit 1 --json displayTitle --jq '.[0].displayTitle'
```
Expected: output is `Update images (test-12345)`, confirming the run is findable by correlation id via the GitHub API's `display_title` field (or `name`, depending on API version — check both if the first doesn't show it).
