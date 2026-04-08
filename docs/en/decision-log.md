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

## 2026-04-09 - Remote Jupyter execution is semi-automated

- Status: accepted
- Context: the AMD cluster currently exposes Jupyter Lab over HTTP, and instance creation is manual. API access is possible, but remote shell execution is not fully automated from the current VS Code tool surface.
- Decision: support remote validation through a hybrid workflow: manual instance creation, scripted Jupyter API access when credentials are available, and generated command bundles for terminal execution.
- Consequence: future remote test runs should record which steps were automated and which were executed manually inside Jupyter.

## Entry Template

- Date:
- Status:
- Context:
- Decision:
- Consequence: