# Project Instructions

This repository is the control plane for the AMD Hackathon task: enable HIP BF16 support in Paddle and remove the downstream PaddleX workaround after the upstream fix is validated.

## Core Rules

1. Bilingual documentation is mandatory for every important step and decision.
2. Every English document must link to its Chinese counterpart at the top.
3. Every Chinese document must link to its English counterpart at the top.
4. Important steps include: environment setup, reproduction, root-cause findings, implementation milestones, test results, validation runs, issue filing, PR submission, and review-driven changes.
5. Important decisions include: scope cuts, design choices, workaround strategy, test strategy, validation target choice, and any remaining known limitations.
6. Documentation must be updated in the same change window as the technical work when the work materially changes project status or understanding.

## Repository Role

1. Do not turn this repository into a nested Paddle or PaddleX source tree.
2. Keep upstream Paddle and PaddleX clones outside this repo.
3. Store exported patches, notes, evidence, and submission materials here.

## Documentation Policy

Maintain these bilingual documents in parallel:

- `docs/en/setup.md` and `docs/zh/setup.md`
- `docs/en/plan.md` and `docs/zh/plan.md`
- `docs/en/design.md` and `docs/zh/design.md`
- `docs/en/dev-log.md` and `docs/zh/dev-log.md`
- `docs/en/decision-log.md` and `docs/zh/decision-log.md`
- `docs/en/validation.md` and `docs/zh/validation.md`
- `docs/en/change-log.md` and `docs/zh/change-log.md`

When a finding is still preliminary, mark it clearly as hypothesis, not fact.

## Engineering Priorities

1. Prefer the smallest upstreamable Paddle fix that addresses the root cause.
2. Treat Paddle as the place for the real HIP BF16 enablement.
3. Treat PaddleX changes as cleanup work to remove temporary workarounds after upstream validation.
4. Do not mix unrelated ROCm optimizations into the core task unless they are required to unblock acceptance.
5. Use operator-level tests first, then integration-level validation.

## Validation Policy

1. WSL can be used for editing and coordination.
2. Final HIP BF16 validation must be run on native Linux ROCm hardware or a remote AMD ROCm machine.
3. Record the exact environment for every meaningful validation run: OS, ROCm version, GPU model, Paddle commit, PaddleX commit, Python version, and command line.
4. Save screenshots, logs, benchmark outputs, and reproduction commands under `evidence/` and summarize them in the bilingual validation docs.
5. For the AMD Radeon GPU cluster Jupyter environment, instance creation is manual by the user. Automation in this repo may prepare commands, authenticate to Jupyter APIs, create terminals, or upload files when credentials are available, but shell execution inside the remote instance must be treated as a separately verified step.

## Tracking Requirements

After each important milestone, update:

1. development log
2. change log
3. validation log if any test or benchmark was run
4. decision log if a technical or process tradeoff was made

## Official Task Requirements

Task URL: https://github.com/PaddlePaddle/community/blob/master/hackathon/hackathon_10th/【Hackathon_10th】文心合作伙伴任务合集.md#amd为-paddle-框架适配-hip-bf16-精度类型

### Task Goal

Enable HIP BF16 precision in Paddle so PaddleOCR-VL and similar models can natively use BF16 on ROCm without forcing the visual encoder (SigLIP) to FP32.

### Acceptance Criteria

PaddleOCR-VL-1.5 runs fully in BF16 on AMD GPU + ROCm and produces correct output.

### Three PaddleX Workarounds to Remove

Reference branch: `vivienfanghuagood:PaddleX:dev_rocm70`

| # | File | Workaround | Status |
|---|------|-----------|--------|
| 1 | `paddlex/utils/misc.py` | `is_bfloat16_available()` hardcodes ROCm as unsupported | ✅ Fixed: added "dcu" to allowlist |
| 2 | `paddlex/inference/models/doc_vlm/static_infer.py` | `delete_pass("conv2d_add_act_fuse_pass")` + `delete_pass("conv2d_add_fuse_pass")` | ✅ Fixed: Paddle gets `#ifdef PADDLE_WITH_HIP` guard; passes removed from PaddleX |
| 3 | `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py` | `_keep_in_fp32_modules = ["visual", "mlp_AR"]` (comment: "MIOpen bf16 conv has bugs") | ✅ Fixed: MIOpen BF16 conv validated correct on gfx1100/ROCm 7.2 (SNR 44-48 dB, 8/8 tests PASS); removed from PaddleX patch |

### Submission Instructions

1. Open GitHub Issue on `PaddlePaddle/Paddle` develop with reproduction steps.
2. Submit GitHub PR on `PaddlePaddle/Paddle` develop with fix + tests + AMD GPU screenshot.
3. Open GitHub Issue on `PaddlePaddle/PaddleX` develop describing workaround removal.
4. Submit GitHub PR on `PaddlePaddle/PaddleX` develop removing all three workarounds.
5. Send email with PR links and screenshots to: ext_paddle_oss@baidu.com  
   CC: Zijun.Wei@amd.com, Huaqiang.Fang@amd.com, bingqing.guo@amd.com

### Prize

Champion (code merged into develop): AMD Radeon 9070 XT 16GB OR PN54 AI 5 340 Mini PC (winner picks first).

## Submission Targets

The expected deliverables for the task are:

1. Paddle Issue on develop describing the HIP BF16 problem and reproduction.
2. Paddle PR on develop implementing the fix with tests.
3. PaddleX Issue on develop describing removal of the workaround.
4. PaddleX PR on develop removing the workaround after validation.
5. AMD GPU validation evidence, including screenshots and correct BF16 execution results for PaddleOCR-VL-1.5.

## Default Working Style

1. Keep notes concise and factual.
2. Separate confirmed findings from guesses.
3. When blocked, document the blocker, attempted path, and next proposed action in both languages.