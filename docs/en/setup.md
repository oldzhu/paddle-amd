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
- local candidate ROCm wheel builds are acceptable when the WSL distro has a working ROCm SDK and build toolchain

Current local WSL snapshot:

- Ubuntu 24.04.3 LTS
- Python 3.12.3
- `hipcc` from ROCm 6.4.2
- `rocminfo`, `cmake 3.28.3`, and `ninja 1.11.1` available

Current caveat:

- the current remote AMD preloaded image line is exposing ROCm 7.2.x, so a wheel built locally on ROCm 6.4.2 may deploy and run, but matching ROCm major or minor versions between build host and validation host is preferable
- always match the Python ABI of the target environment; the current remote preloaded images are using Python 3.12 in `/opt/venv`

Suggested local-build-to-remote workflow:

1. Verify that the local WSL build host still matches the intended remote target as closely as possible:

```bash
scripts/check_local_rocm_build_env.sh
```

2. If needed, override the expected target values explicitly:

```bash
TARGET_PYTHON_VERSION=3.12 TARGET_ROCM_PREFIX=7.2 scripts/check_local_rocm_build_env.sh
```

3. Build the candidate ROCm wheel locally in WSL.

Example local configure:

```bash
scripts/build_local_rocm_wheel.sh /home/oldzhu/paddle-amd/paddlerepos/Paddle configure
```

Example local wheel build:

```bash
scripts/build_local_rocm_wheel.sh /home/oldzhu/paddle-amd/paddlerepos/Paddle build
```

The helper currently:

- prepares the known ROCm compatibility symlinks for `hip_version.h` and `rccl.h`
- points CMake at the detected legacy HIP CMake module path
- configures a dedicated local build directory with `BUILD_WHL_PACKAGE=ON`
- builds the wheel-producing target `paddle_copy` in build mode

4. Upload the built wheel to the remote AMD ROCm instance.

Example wheel upload:

```bash
scripts/upload_remote_wheel.sh /path/to/paddle_whl.whl uploaded-wheels
```

5. Install the wheel into the remote `/opt/venv`.

Example remote install and smoke test:

```bash
scripts/install_remote_wheel.sh 1 uploaded-wheels/paddle_whl.whl
```

6. Run the authoritative HIP or BF16 tests only on the remote machine.

Stop conditions for this flow:

- local Python ABI does not match the remote target Python ABI
- local ROCm toolchain is missing or clearly incompatible with the target runtime
- the produced wheel depends on local-only libraries that are not present on the remote host

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
- `scripts/render_remote_dns_repair.sh` for generating a remote resolver repair script with optional `apt-get update` validation
- `scripts/remote_fix_instance_dns.sh` for executing that resolver repair against an active Jupyter terminal
- `scripts/render_remote_bootstrap.sh` for generating a terminal-ready bootstrap script to clone or refresh this repo, Paddle, and PaddleX on the remote host
- `scripts/render_remote_env_check.sh` for generating a remote environment inspection script
- `scripts/remote_prepare_instance.sh` for executing the remote bootstrap workflow against the active Jupyter terminal
- `scripts/remote_ensure_paddle.sh` for a check-first remote Paddle install attempt in `/opt/venv`
- `scripts/remote_build_paddle_rocm.sh` for a check-first remote Paddle ROCm source configure or build probe
- `scripts/remote_launch_paddle_rocm_configure.sh` for launching a detached remote Paddle ROCm configure job when websocket stability is poor
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

If remote clone, pip, or apt operations start failing with `Temporary failure resolving ...`, repair DNS first:

```bash
scripts/remote_fix_instance_dns.sh 1
```

By default this helper:

- checks whether the instance can resolve the package and clone hosts needed by this workflow
- rewrites `/etc/resolv.conf` with a short candidate nameserver list only when resolution is currently broken
- verifies hostname resolution after the rewrite
- runs `apt-get update` as part of the validation step

If you only want the resolver fix without running apt immediately:

```bash
scripts/remote_fix_instance_dns.sh 1 --no-apt-update
```

If your region or cluster requires different resolvers, pass them explicitly:

```bash
scripts/remote_fix_instance_dns.sh 1 223.5.5.5 223.6.6.6 1.1.1.1
```

Example per-instance preparation:

```bash
scripts/remote_prepare_instance.sh 1 /app/paddle-amd-remote
```

The generated bootstrap now performs a DNS preflight before any clone or fetch work. If the required hosts do not resolve, it stops early and points back to `scripts/remote_fix_instance_dns.sh`.

Example check-first Paddle provisioning:

```bash
scripts/remote_ensure_paddle.sh 1 paddlepaddle==3.3.1
```

This helper only installs Paddle when `import paddle` fails. After install, it prints whether the resulting build reports ROCm support.

Current finding:

- `scripts/remote_ensure_paddle.sh 1 paddlepaddle==3.3.1` installs a CPU-only wheel in the tested remote environment
- treat that path as a quick availability probe, not as a valid ROCm runtime for this task

Example check-first ROCm source configure probe:

```bash
scripts/remote_build_paddle_rocm.sh 1 /app/paddle-amd-remote configure
```

This helper skips work when the active Python environment already reports a ROCm-capable Paddle build. Otherwise it runs a remote source-build probe from `paddlerepos/Paddle`, records the detected GPU arch, warns when the checked-in ROCm target list does not include that arch, and executes a CMake configure step to capture the first real blocker.

If terminal websocket execution becomes unstable on a live instance, launch the configure in the background instead:

```bash
scripts/remote_launch_paddle_rocm_configure.sh 1 /app/paddle-amd-remote
```

This helper is meant for unstable terminals where a long configure run cannot stay attached long enough to complete cleanly over websocket.

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