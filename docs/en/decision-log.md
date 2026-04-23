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

## 2026-04-09 - Every fresh Jupyter instance requires check-first preparation

- Status: accepted
- Context: the remote AMD cluster instances are ephemeral and a newly created instance may not include Paddle or the project workspace.
- Decision: treat remote instance setup as a required reusable check-first workflow: verify the environment, refresh the workspace as needed, and install or build Paddle only if it is missing or unsuitable.
- Consequence: remote test automation must always begin with environment verification and a Paddle availability check, but should avoid unnecessary reinstall work.

## 2026-04-09 - CPU-only pip Paddle is not an acceptable remote endpoint

- Status: accepted
- Context: installing `paddlepaddle==3.3.1` in the tested remote `/opt/venv` succeeds, but the resulting package reports `is_compiled_with_rocm() == False`.
- Decision: treat generic pip Paddle installation only as a quick availability probe. For this task, any remote Paddle build that does not report ROCm support is unsuitable and the next step must move to a source-build probe.
- Consequence: remote preparation now needs an explicit ROCm source configure or build path instead of relying on generic pip installation.

## 2026-04-10 - Remote submodule health must verify a real worktree, not only submodule metadata

- Status: accepted
- Context: the first targeted `paddle_python` build failed in `extern_warprnnt` even though earlier `git submodule status --recursive` checks reported no missing entries. On the live instance, `third_party/warprnnt` contained only the `.git` redirect file and no checked-out files.
- Decision: treat a submodule as healthy only when it has both submodule metadata and a non-empty worktree. Remote helper scripts must force-recover empty worktrees instead of trusting status output alone.
- Consequence: remote prepare and configure helpers now need an extra worktree-content validation pass, which is more important than keeping the old faster-but-weaker check.

## 2026-04-10 - BF16 support APIs are not sufficient validation evidence

- Status: accepted
- Context: on the new `30008` ROCm instance, Paddle reports `is_compiled_with_rocm() == True`, `paddle.device.is_bf16_supported() == True`, and `paddle.cuda.is_bf16_supported() == True`, but a live BF16 `paddle.randn` path still segfaults inside the GPU Gaussian kernel.
- Decision: treat BF16 capability APIs only as an initial readiness signal. Final task validation must include at least one real BF16 tensor creation and execution path, not just capability queries.
- Consequence: every future acceptance run for this task must include a concrete BF16 runtime op, and any API-only success must be labeled insufficient.

## 2026-04-10 - Preloaded ROCm images need a float32 GPU smoke test before BF16 validation

- Status: accepted
- Context: on `30006`, the preloaded image reports ROCm support, `gpu:0`, and BF16 support APIs as ready, but even `paddle.ones([2,2], dtype="float32")` segfaults on the GPU backend in `phi::FullKernel<float, phi::GPUContext>`.
- Decision: before spending time on BF16-specific validation for any preloaded image, run at least one minimal float32 GPU tensor materialization control such as `paddle.ones` or `paddle.full`.
- Consequence: an image that fails the float32 GPU smoke test is rejected immediately as a validation target, because any BF16-specific diagnosis on top of it would be confounded.

## 2026-04-10 - Distinguish creator-kernel failures from general GPU bring-up failures on preloaded images

- Status: accepted
- Context: on `30006`, `paddle.ones`, `paddle.randn`, and GPU float32-to-BF16 `astype` segfault, but `paddle.to_tensor(..., place="gpu")` and float32 `paddle.matmul` still succeed.
- Decision: after a preloaded image fails a creator-kernel smoke test, run one non-creator control such as `paddle.to_tensor(..., place="gpu")` and a simple float32 `matmul` before concluding that the whole GPU runtime is dead.
- Consequence: future triage can separate image-level kernel breakage from total GPU bring-up failure, which makes bug reports and workaround discussions more precise.

## 2026-04-11 - WSL local ROCm build is acceptable, but remote validation remains authoritative

- Status: accepted
- Context: the current local machine is WSL2 on Ubuntu 24.04.3 with Python 3.12.3, `hipcc` from ROCm 6.4.2, `rocminfo`, `cmake`, and `ninja` available. The current remote preloaded image line is using Python 3.12 and ROCm 7.2.x.
- Decision: allow local WSL to serve as a candidate Paddle ROCm build host when the toolchain is present, but keep native Linux ROCm or remote AMD ROCm execution as the only authoritative validation path.
- Consequence: local wheel build plus remote deploy-and-test is a valid workflow, but ROCm and Python version alignment between local build host and remote validation host should be treated as a compatibility requirement, not an afterthought.

## 2026-04-11 - Prefer a shared Eigen HIP compatibility fix over repeated per-TU workarounds

- Status: accepted
- Context: several local ROCm HIP compilation failures first appeared in unrelated translation units such as `affine_grid_utils.cu`, `cross_entropy.cu`, `fake_dequantize_functor.cu`, `fake_quantize_functor.cu`, and later `math_function.cu`, but the repeated terminal signature was the same Eigen failure at `Eigen/src/Core/arch/Default/Half.h:669` where `half log()` called `::hlog(a)` and the current ROCm stack resolved that call to the BF16 overload.
- Decision: use small per-file include cleanups where headers are clearly over-broad, but once a translation unit with a real Eigen dependency hits the same failure, switch to a minimal shared third-party fix in local Eigen instead of stacking more brittle file-local workarounds.
- Consequence: the active local build now depends on a narrow HIP-only compatibility patch in Eigen `Half.h`, and subsequent HIP compile progress should be interpreted as validation of the shared fix rather than as evidence that every remaining translation unit was independently repaired.

## 2026-04-13 - Keep HIP top-k on wave64 and remove the invalid 32-thread specialization

- Status: accepted
- Context: the local ROCm build failed in generated top-k HIP code because the HIP path hardcoded `WARP_SIZE=64` while the dispatch macro still instantiated a 32-thread specialization, which produced zero-length shared arrays during compilation.
- Decision: keep the HIP implementation aligned with wave64 assumptions instead of trying to force wave32 behavior. Clamp HIP runtime block selection to at least one warp and omit the HIP-only 32-thread specialization from the generated dispatch.
- Consequence: the fix stays minimal and consistent with the current ROCm execution model, and the previously failing generated top-k object now rebuilds cleanly without introducing a broader launch-policy rewrite.

## 2026-04-14 - Treat remote artifact staging and remote execution as separate checkpoints on the live Jupyter stack

- Status: accepted
- Context: on the live `30006` instance, authenticated Jupyter API access, terminal creation, and contents upload all work with the instance-scoped base URL, but terminal websocket execution currently returns the HTML terminal page instead of upgrading the connection.
- Decision: record remote artifact transfer and remote command execution as separate validation checkpoints. When websocket execution is blocked but the contents API still works, stage the wheel on the instance immediately and keep the remaining gap explicitly labeled as a transport or notebook-stack blocker.
- Consequence: progress on live remote deployment is not lost when the terminal channel regresses, and the remaining unblock work is narrowed to command transport instead of being conflated with artifact availability.

## 2026-04-14 - Reject a remote validation image when base runtime repair is blocked after dependency triage

- Status: accepted
- Context: after the restarted `30006` instance restored terminal execution, the deployed local ROCm 6.4.2 wheel first failed on missing `libamdhip64.so.6`, then advanced to missing `libopenblas.so.0` after a narrow SONAME shim. The image has no discoverable OpenBLAS runtime, and `apt-get update` fails because the instance cannot resolve standard Ubuntu, deadsnakes, or AMD package hosts.
- Decision: once terminal transport is working again, continue dependency triage until either the wheel imports or the image is shown to be missing base runtime components that cannot be repaired through the normal package path. At that point, reject the image as a validation target instead of stacking deeper ad hoc runtime shims.
- Consequence: the current `30006` instance is now classified as unsuitable for acceptance of the locally built wheel, and the next useful validation target must provide either version-aligned ROCm runtime libraries plus base math dependencies, or working package/network access to install them cleanly.

## 2026-04-15 - Use public-package DNS readiness as the default gate and make private artifactory resolution opt-in

- Status: accepted
- Context: on the new `30002` instance, a mixed resolver setup restored Ubuntu/security/PPA/GitHub resolution and unblocked apt-based package operations, while `compute-artifactory.amd.com` remained unresolved.
- Decision: for the local-change sync/build/deploy/test workflow, treat public package host resolution and usable apt index refresh as the default DNS success criteria. Keep private AMD artifactory resolution as an explicit opt-in strict check only when that host is required by the current task.
- Consequence: DNS repair automation can now unblock standard package-dependent workflow steps on more instances, while still supporting strict private-host enforcement when needed.

## 2026-04-15 - Treat DNS repair as a required per-restart preflight on ephemeral instances

- Status: accepted
- Context: on `30002`, hostname resolution regressed again after restart even though the same instance had passed DNS checks earlier; rerunning DNS repair restored apt and runtime preparation paths.
- Decision: for every restarted or newly created Jupyter instance, run DNS repair and a short package-host resolution preflight before deployment or validation commands.
- Consequence: remote validation becomes restart-tolerant and avoids wasting runs on predictable resolver regressions.

## 2025-05-27 - Use Python monkey-patch for missing BF16 layer_norm kernel until upstream Paddle wheel ships the fix

- Status: accepted
- Context: The Paddle ROCm wheel (3.4.0.dev20260408) does not register `phi::bfloat16` in the `layer_norm` HIP `PD_REGISTER_KERNEL`. Recompiling the wheel was not feasible in the current validation timeline. The C++ fix for `layer_norm_kernel.cu` has been authored and will be submitted as an upstream PR.
- Decision: Apply a Python-level `LayerNorm.forward` monkey-patch in `_paddleocr_vl.py` (the VLM worker subprocess entry point) that casts BF16→FP32→BF16 around the layer_norm call. This shim is in the VLM subprocess file so it activates in the correct process context. The C++ fix goes into `patches/paddle-hip-bf16-kernels.patch` for the upstream PR.
- Consequence: Full BF16 pipeline validation passes without wheel recompilation. Once the upstream Paddle PR is merged and a new wheel ships, the Python shim can be deleted.

## 2025-05-27 - Fix FLAGS_conv_workspace_size_limit via os.environ.setdefault before create_predictor

- Status: accepted
- Context: `paddle.inference.create_predictor(config)` calls `SetGflags()` which tries to set `FLAGS_conv_workspace_size_limit` from the environment variable. That gflag does not exist in ROCm/HIP builds, causing a fatal error if the env var is absent.
- Decision: Call `os.environ.setdefault("FLAGS_conv_workspace_size_limit", "32")` in the ROCm block of `static_infer.py` before `create_predictor()`. Using `setdefault` avoids overwriting any user-provided value.
- Consequence: Paddle analysis predictor creation succeeds on ROCm. The gflag simply exists in the process environment; unused gflags on CUDA builds are harmless.

## Entry Template

- Date:
- Status:
- Context:
- Decision:
- Consequence: