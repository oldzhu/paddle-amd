# paddle-amd

Project control plane for the Hackathon task: AMD: enable HIP BF16 support in Paddle.

This repository is not intended to be the main Paddle or PaddleX source tree. It is used to track:

- bilingual planning and decision records
- design notes and root-cause analysis
- development and validation logs
- exported patches for Paddle and PaddleX
- issue and PR drafts
- screenshots and evidence required for submission

## Documentation

- English setup and repro guide: [docs/en/setup.md](docs/en/setup.md)
- 中文环境与复现指南: [docs/zh/setup.md](docs/zh/setup.md)
- English plan: [docs/en/plan.md](docs/en/plan.md)
- 中文计划: [docs/zh/plan.md](docs/zh/plan.md)
- English design: [docs/en/design.md](docs/en/design.md)
- 中文设计: [docs/zh/design.md](docs/zh/design.md)
- English development log: [docs/en/dev-log.md](docs/en/dev-log.md)
- 中文开发日志: [docs/zh/dev-log.md](docs/zh/dev-log.md)
- English decision log: [docs/en/decision-log.md](docs/en/decision-log.md)
- 中文决策日志: [docs/zh/decision-log.md](docs/zh/decision-log.md)
- English validation log: [docs/en/validation.md](docs/en/validation.md)
- 中文验证日志: [docs/zh/validation.md](docs/zh/validation.md)
- English change log: [docs/en/change-log.md](docs/en/change-log.md)
- 中文变更日志: [docs/zh/change-log.md](docs/zh/change-log.md)

## Expected Upstream Workspaces

Keep upstream source trees outside this repo:

- Paddle develop clone: `/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- PaddleX develop clone: `/home/oldzhu/paddle-amd/paddlerepos/PaddleX`

Current recorded clone state:

- Paddle branch: `develop`
- Paddle commit: `5ea0c3dddf415a7885560c6916e13491d6f597c6`
- PaddleX branch: `develop`
- PaddleX commit: `c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`

Recommended workflow:

1. Edit and document from this repo.
2. Implement and test in external Paddle or PaddleX clones.
3. Export patches and evidence back into this repo.
4. Use this repo to prepare upstream issues, PR summaries, and validation artifacts.

## Directory Layout

- `.github/`: project-wide Copilot instructions
- `docs/en/` and `docs/zh/`: bilingual tracking documents
- `scripts/`: repro, benchmark, environment capture, and patch helpers
- `patches/paddle/`: exported Paddle patch series
- `patches/paddlex/`: exported PaddleX patch series
- `evidence/`: screenshots, logs, benchmark tables, and submission materials

## Environment Strategy

Local development can happen in WSL, but authoritative ROCm validation should happen on native Linux ROCm hardware or a remote AMD ROCm machine. Treat WSL as editing and orchestration unless native AMD GPU execution is proven stable.