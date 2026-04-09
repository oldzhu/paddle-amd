[中文版](../zh/dev-log.md)

# Development Log

## 2026-04-08

- Initialized the coordination repository.

## 2026-04-09

- Confirmed nested upstream workspace under `/home/oldzhu/paddle-amd/paddlerepos`.
- Deleted the earlier partial nested clones and recreated them cleanly.
- Recorded local Paddle clone at `/home/oldzhu/paddle-amd/paddlerepos/Paddle` on `develop` at `5ea0c3dddf415a7885560c6916e13491d6f597c6`.
- Recorded local PaddleX clone at `/home/oldzhu/paddle-amd/paddlerepos/PaddleX` on `develop` at `c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`.
- Verified both nested repos are clean worktrees.
- Added bilingual workspace setup and first-reproduction guide.
- Linked the local control-plane repo to GitHub remote `https://github.com/oldzhu/paddle-amd.git`.
- Added remote AMD ROCm Jupyter workflow assets, including a workspace skill, a Jupyter API helper, and a remote bootstrap command generator.
- Added Jupyter terminal websocket execution support to the remote helper.
- Authenticated to the remote Jupyter instance and verified terminal websocket execution against terminal `1`.
- Uploaded and executed the remote environment check script through the Jupyter terminal websocket.
- Confirmed ROCm is available on the remote host, but Paddle is not installed in the current Python environment.
- Added a reusable per-instance remote preparation wrapper for future ephemeral Jupyter instances.
- Fixed remote command-file execution so failing `set -e` scripts return a proper exit code instead of appearing to hang.
- Successfully bootstrapped the current remote instance under `/app/paddle-amd-remote`, including the control-plane repo, Paddle clone, and PaddleX clone.
- Created bilingual project documentation skeleton.
- Added shared project instructions to enforce bilingual tracking and evidence discipline.

## Entry Template

- Date:
- Environment:
- Action:
- Result:
- Next: