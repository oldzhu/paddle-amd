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

## Instance Lifecycle Rule

Treat each Jupyter instance as ephemeral.

1. A newly created instance may not contain Paddle, PaddleX, or this control-plane repo.
2. Check every fresh instance first, then prepare only the missing or stale parts.
3. The preparation workflow must at least:
	- verify ROCm visibility
	- ensure the remote control-plane workspace exists and is up to date
	- ensure Paddle and PaddleX exist and are refreshed to the expected branch state
	- check whether Paddle is importable in the active Python environment
4. If Paddle is already available and acceptable for the task, do not reinstall it.
5. If Paddle is missing or the wrong build, record that state explicitly before starting validation or reproduction.

## Main Assets

- `scripts/jupyter_remote.py`
- `scripts/render_remote_bootstrap.sh`
- `scripts/remote_prepare_instance.sh`
- `docs/en/setup.md`
- `docs/zh/setup.md`

## Recommended Use

1. Check endpoint reachability first.
2. If auth is needed, request a token or password from the user.
3. Use `scripts/jupyter_remote.py login` to validate auth.
4. Use `scripts/jupyter_remote.py exec` for remote terminal command execution when possible.
5. Use `scripts/render_remote_bootstrap.sh` to produce the terminal commands for the current run.
6. Use `scripts/remote_prepare_instance.sh` to bootstrap every new instance.
7. Upload generated scripts through the Jupyter contents API if useful.
8. Record every real validation run in bilingual docs.