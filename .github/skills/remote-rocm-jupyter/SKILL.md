---
name: remote-rocm-jupyter
description: "Use when: working with the AMD Radeon GPU cluster Jupyter Lab remote testing environment, preparing ROCm validation runs, accessing Jupyter APIs with a password or token, generating remote bootstrap commands, or uploading scripts for manual execution in the remote terminal."
---

# Remote ROCm Jupyter Workflow

Use this skill when the task depends on the remote AMD ROCm Jupyter Lab environment rather than the local WSL workspace.

## What This Skill Covers

- verifying the Jupyter endpoint is reachable
- documenting the manual instance-creation dependency
- authenticating to Jupyter APIs with a token or password
- listing or creating Jupyter terminals through the API when credentials are available
- executing commands in a Jupyter terminal over websocket when the endpoint is available
- uploading helper scripts into the remote workspace
- generating copy-paste bootstrap and repro command bundles for the remote terminal

## Important Constraint

This workflow does not guarantee full browser automation from VS Code. The Jupyter Lab UI is password or token protected, and terminal command execution depends on terminal websocket support. The supported path in this repo is:

1. user creates or revives the remote instance
2. scripts authenticate to the Jupyter API if credentials are available
3. scripts can generate or upload shell command bundles
4. scripts can execute terminal commands over websocket when the endpoint is available
5. results are still verified and recorded in the bilingual docs

## Main Assets

- `scripts/jupyter_remote.py`
- `scripts/render_remote_bootstrap.sh`
- `docs/en/setup.md`
- `docs/zh/setup.md`

## Recommended Use

1. Check endpoint reachability first.
2. If auth is needed, request a token or password from the user.
3. Use `scripts/jupyter_remote.py login` to validate auth.
4. Use `scripts/jupyter_remote.py exec` for remote terminal command execution when possible.
5. Use `scripts/render_remote_bootstrap.sh` to produce the terminal commands for the current run.
6. Upload generated scripts through the Jupyter contents API if useful.
7. Record every real validation run in bilingual docs.