[中文版](../zh/decision-log.md)

# Decision Log

## 2026-04-08 - Use this repo as a coordination repo

- Status: accepted
- Context: the task spans Paddle, PaddleX, cross-environment validation, and submission artifacts.
- Decision: keep this repo as a documentation, patch, and evidence control plane instead of embedding upstream source trees.
- Consequence: Paddle and PaddleX will be developed in separate clones, while this repo remains stable and focused.

## 2026-04-08 - Native Linux ROCm is the validation authority

- Status: accepted
- Context: local work is in WSL and AMD GPU execution there is not considered reliable enough yet.
- Decision: use WSL for editing and orchestration, but rely on native Linux ROCm hardware or a remote ROCm machine for authoritative validation.
- Consequence: scripts and patch flow must support cross-machine execution.

## 2026-04-09 - Remote Jupyter execution uses API plus websocket automation

- Status: accepted
- Context: the AMD cluster exposes Jupyter Lab over HTTP, instance creation is manual, authenticated API access is available, and terminal websocket access is available for command execution.
- Decision: support remote validation through a hybrid workflow: manual instance creation plus scripted Jupyter API access and terminal websocket execution when the remote terminal endpoint is live.
- Consequence: future remote test runs should still record which steps were automated and which required manual intervention.

## Entry Template

- Date:
- Status:
- Context:
- Decision:
- Consequence: