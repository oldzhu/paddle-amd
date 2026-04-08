[中文版](../zh/plan.md)

# Plan

## Goal

Enable HIP BF16 support in Paddle on ROCm so PaddleOCR-VL-1.5 can run correctly in BF16 on AMD GPU, then remove the current PaddleX workaround and submit the required upstream issues and PRs.

## Recorded Local Upstream Paths

- Paddle: `/home/oldzhu/paddle-amd/paddlerepos/Paddle`
- Paddle branch: `develop`
- Paddle commit: `5ea0c3dddf415a7885560c6916e13491d6f597c6`
- PaddleX: `/home/oldzhu/paddle-amd/paddlerepos/PaddleX`
- PaddleX branch: `develop`
- PaddleX commit: `c18f2b02a1407d2bcdd4e7470dd62a629cf8b8cb`

## Milestones

1. Bootstrap this coordination repo and bilingual tracking system.
2. Reproduce the current ROCm BF16 limitation on a native Linux ROCm machine.
3. Identify the Paddle root cause and define the smallest upstreamable fix.
4. Implement the Paddle fix with focused tests.
5. Validate PaddleOCR-VL-1.5 BF16 execution on AMD GPU.
6. Remove the PaddleX workaround and submit the cleanup PR.
7. Package evidence for review and hackathon submission.

## Workstreams

### 1. Coordination Repo

- maintain bilingual docs and project instructions
- collect patches, evidence, and issue drafts
- track status across environments

### 2. Upstream Paddle Fix

- inspect HIP-only BF16 type gating and dispatch
- inspect GPUDNN and MIOpen conv-related BF16 support
- add tests and validate behavior on ROCm

### 3. PaddleX Cleanup

- remove BF16 disablement when upstream fix is ready
- remove forced FP32 fallback where no longer needed
- confirm any remaining ROCm limits are unrelated and documented separately

## Environment Strategy

- WSL: editing, scripting, patch preparation
- native Linux ROCm or remote AMD ROCm machine: authoritative validation

## Current Hypothesis

The most likely first root cause is that HIP BF16 support is partially present in Paddle helper layers but excluded or incomplete in conv-related GPUDNN and MIOpen registration or dispatch paths. This must be confirmed through reproduction before implementation.

## Immediate Next Steps

1. Prepare upstream clone locations and exact commit tracking.
2. Write reproducible environment capture and repro scripts.
3. Reproduce the BF16 failure with and without the current PaddleX workaround.