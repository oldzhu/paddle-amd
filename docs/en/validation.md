[中文版](../zh/validation.md)

# Validation

## Validation Checklist

- environment captured
- Paddle commit recorded
- PaddleX commit recorded
- ROCm version recorded
- GPU model recorded
- exact command recorded
- output log saved
- screenshot saved if required

## Planned Acceptance Evidence

1. operator-level BF16 test results on HIP
2. successful PaddleOCR-VL-1.5 BF16 execution on AMD GPU
3. correctness evidence and screenshots
4. concise FP32 versus BF16 comparison for memory and runtime

## Run Log

### 2026-04-09 - Remote Jupyter environment inspection

- Validation target: AMD cluster Jupyter instance at `http://36.151.243.69:30005/lab`
- Access mode: authenticated Jupyter API plus terminal websocket
- Remote terminal: `1`
- Command path: uploaded `/app/paddle_amd_remote_env_check.sh`
- Execution command: `python3 scripts/jupyter_remote.py exec --terminal 1 --command "bash /app/paddle_amd_remote_env_check.sh"`
- OS: Ubuntu 22.04.5 LTS
- Python: `/opt/venv/bin/python`, version `3.10.12`
- pip: `/opt/venv/bin/pip`, version `26.0.1`
- ROCm evidence:
	- `/opt/rocm` and `/opt/rocm-7.2.1` present
	- `rocminfo` succeeded
	- GPU agent detected as `gfx1100`
	- `rocm-smi` succeeded
	- `hipcc` present at `/opt/rocm/bin/hipcc`
	- HIP version reported as `7.2.1`
- Paddle evidence:
	- `import paddle` failed with `ModuleNotFoundError: No module named 'paddle'`
	- `pip list` showed no installed Paddle package in the active environment
- Preliminary conclusion:
	- The remote instance is suitable for ROCm-based validation work.
	- Paddle must be installed or built in the remote environment before framework reproduction can begin.