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
- uploading helper scripts into the remote workspace
- generating copy-paste bootstrap and repro command bundles for the remote terminal

## Important Constraint

This workflow does not guarantee full remote shell automation from VS Code. The Jupyter Lab UI is password or token protected, and terminal command execution requires terminal websocket control. The supported path in this repo is:

1. user creates or revives the remote instance
2. scripts authenticate to the Jupyter API if credentials are available
3. scripts generate or upload shell command bundles
4. commands are executed and verified in the Jupyter terminal

## Main Assets

- `scripts/jupyter_remote.py`
- `scripts/render_remote_bootstrap.sh`
- `docs/en/setup.md`
- `docs/zh/setup.md`

## Recommended Use

1. Check endpoint reachability first.
2. If auth is needed, request a token or password from the user.
3. Use `scripts/jupyter_remote.py login` to validate auth.
4. Use `scripts/render_remote_bootstrap.sh` to produce the terminal commands for the current run.
5. Upload generated scripts through the Jupyter contents API if useful.
6. Record every real validation run in bilingual docs.