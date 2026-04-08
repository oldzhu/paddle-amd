[中文版](../zh/design.md)

# Design

## Scope

This document tracks the technical design for enabling HIP BF16 in Paddle and the dependency boundary between Paddle and PaddleX.

## Design Principles

1. Fix the root cause in Paddle first.
2. Keep the Paddle patch reviewable and narrow.
3. Treat PaddleX changes as downstream cleanup only.
4. Require evidence before expanding scope beyond the first failing operator path.

## Initial Suspected Areas

- HIP-only BF16 type iteration or dispatch gates
- ROCm BF16 datatype mapping gaps
- GPUDNN or MIOpen conv and conv-transpose registration excluding BF16
- additional HIP BF16 operator gaps revealed by PaddleOCR-VL execution traces

## Expected Validation Chain

1. operator-level regression test
2. framework-level smoke validation on ROCm
3. PaddleOCR-VL-1.5 BF16 inference without the current PaddleX workaround

## Open Questions

- Which exact operator fails first when the workaround is removed?
- Is the conv fuse-pass disablement independent from the BF16 task?
- Are there multiple blockers after conv is fixed?

## Design Updates

Add dated entries here as the technical understanding evolves.