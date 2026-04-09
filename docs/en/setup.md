[中文版](../zh/setup.md)

# Setup And Reproduction Guide

## Purpose

This guide defines how to use this control-plane repository together with the nested local Paddle and PaddleX clones, and how to prepare the first HIP BF16 reproduction run.

## Workspace Layout

- Control-plane repo: `/home/oldzhu/paddle-amd`
- Nested Paddle repo: `/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- Nested PaddleX repo: `/home/oldzhu/paddle-amd/paddlerepos/PaddleX`

The `paddlerepos/` directory is intentionally ignored by the control-plane repo. Each nested repo keeps its own git history, remotes, branches, and PR workflow.

## Recorded Clone State

- Paddle branch: `develop`
- Paddle commit: `5ea0c3dddf415a7885560c6916e13491d6f597c6`
- PaddleX branch: `develop`
- PaddleX commit: `c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`

## Recommended Working Model

1. Keep planning, notes, evidence, and patch exports in this control-plane repo.
2. Make framework changes in the nested Paddle and PaddleX repos.
3. Export patches back into `patches/paddle/` and `patches/paddlex/` when needed.
4. Update bilingual docs in the same change window as meaningful technical progress.

## Environment Roles

### WSL

- editing and code review
- lightweight scripting
- patch preparation
- issue and PR drafting

### Native Linux ROCm Or Remote AMD ROCm Host

- authoritative build validation
- operator test execution
- PaddleOCR-VL BF16 reproduction and acceptance validation

## Remote AMD Cluster Jupyter Environment

Known entry points:

- cluster page: `http://36.151.243.69:30081`
- Jupyter Lab instance pattern: `http://36.151.243.69:30005/lab`

Current operating model:

1. you create or revive the remote instance manually
2. this repo can prepare commands and interact with Jupyter APIs if a token or password is available
3. this repo can execute commands through the Jupyter terminal websocket when the terminal endpoint is available
4. results still need to be verified and logged as real validation evidence

Important instance rule:

1. treat every new Jupyter instance as ephemeral
2. do not assume Paddle is installed in a fresh instance
3. check each new instance first, then prepare only what is missing or outdated
4. if Paddle is already present and usable, do not reinstall it

Remote helper assets:

- `scripts/jupyter_remote.py` for Jupyter API login, terminal listing or creation, session listing, file upload, and terminal websocket execution
- `scripts/render_remote_bootstrap.sh` for generating a terminal-ready bootstrap script to clone or refresh this repo, Paddle, and PaddleX on the remote host
- `scripts/render_remote_env_check.sh` for generating a remote environment inspection script
- `scripts/remote_prepare_instance.sh` for executing the remote bootstrap workflow against the active Jupyter terminal
- `.github/skills/remote-rocm-jupyter/SKILL.md` for future Copilot workflow reuse

Example login flow with a token:

```bash
python3 scripts/jupyter_remote.py login \
	--url http://36.151.243.69:30005 \
	--token YOUR_TOKEN
```

Example login flow with a password:

```bash
python3 scripts/jupyter_remote.py login \
	--url http://36.151.243.69:30005 \
	--password YOUR_PASSWORD
```

Example terminal management and upload:

```bash
python3 scripts/jupyter_remote.py list-terminals
python3 scripts/jupyter_remote.py create-terminal
python3 scripts/jupyter_remote.py upload scripts/repro_checklist.sh repro_checklist.sh
```

Example websocket terminal execution:

```bash
python3 scripts/jupyter_remote.py exec --command "bash paddle_amd_remote_env_check.sh"
python3 scripts/jupyter_remote.py exec --command-file /tmp/remote_bootstrap.sh
```

Example per-instance preparation:

```bash
scripts/remote_prepare_instance.sh 1 /app/paddle-amd-remote
```

Example command bundle generation for manual execution in the remote terminal:

```bash
scripts/render_remote_bootstrap.sh > /tmp/remote_bootstrap.sh
```

You can then upload that script to Jupyter, paste the generated output into a remote terminal, or execute it through `scripts/jupyter_remote.py exec`.

## First Reproduction Checklist

1. Capture the environment with `scripts/capture_env.sh` on the ROCm validation machine.
2. Record the exact Paddle and PaddleX commits used for the run.
3. Confirm the current PaddleX workaround behavior on ROCm.
4. Run the target BF16 flow with the workaround present.
5. Remove or bypass the workaround and identify the first failing operator or code path.
6. Save logs, commands, and screenshots under `evidence/`.
7. Update `docs/en/validation.md`, `docs/zh/validation.md`, `docs/en/dev-log.md`, and `docs/zh/dev-log.md`.

## Current PaddleX Workaround Areas To Review First

- `paddlex/inference/utils/misc.py`
- `paddlex/inference/models/common/static_infer.py`
- `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`

## Current Paddle Areas To Review First

- `paddle/fluid/framework/data_type.h`
- `paddle/phi/backends/gpu/rocm/miopen_desc.h`
- `paddle/phi/backends/gpu/rocm/miopen_helper.h`
- `paddle/phi/kernels/gpudnn/conv_kernel.cu`
- `paddle/phi/kernels/gpudnn/conv_transpose_kernel.cu`

## Notes

If a finding is not yet confirmed by a real ROCm run, mark it as a hypothesis in both languages.