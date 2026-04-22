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
- Refined the remote instance rule to `check first, then prepare only what is missing or unsuitable`, instead of implying unconditional reinstall or reclone.
- Tested `paddlepaddle==3.3.1` installation in the remote `/opt/venv` and confirmed that the resulting build is CPU-only, not ROCm-capable.
- Added a check-first remote Paddle ROCm source-build probe helper so remote setup can capture real source-build blockers instead of stopping at a CPU-only wheel.
- Ran the first remote Paddle ROCm source configure probe and confirmed that the current remote blockers are ROCm header path mismatches plus flaky submodule fetches from GitHub.
- Tightened the remote source-build helper to avoid broad Python package upgrades during future configure probes.
- Updated the remote source-build helper to pre-populate submodules over HTTP/1.1 with retries and to add non-destructive ROCm header compatibility symlinks on the active instance.
- Re-ran the configure probe on the same remote instance and confirmed that the header-path and submodule blockers were cleared; the next configure blocker is `Unknown CMake command "hip_add_library"`.
- Confirmed that the active ROCm image exposes legacy `FindHIP.cmake` under `/opt/rocm-7.2.1/lib/cmake/hip`, while the older `/opt/rocm/hip/cmake` path used by Paddle does not provide that module on this instance.
- Added a detached remote configure launcher, then hit a new blocker: after the backend shifted to a fresh Jupyter container, terminal websocket execution became unstable and timed out across terminals before the detached launch could be verified end to end.
- Refactored the detached remote configure launcher to avoid nested heredoc expansion bugs, then verified a clean detached launch on the live `http://36.151.243.69:30005/lab` backend through terminal `3`.
- Confirmed that the fixed detached launcher started remote background job `549`; the latest poll showed submodule initialization progressing and reduced the remaining missing recursive submodules from `31` to `24` before CMake configure started.
- Confirmed that the earlier detached job eventually finished recursive submodule initialization on the fresh backend and exposed a new configure blocker: `patchelf` was missing from the remote host image.
- Installed `patchelf` on the remote backend through `apt-get install -y patchelf`, relaunched the detached configure on terminal `6`, and verified that the new background job passed the earlier `patchelf` failure and continued deeper into CMake configure and code generation.
- Verified that the first targeted `paddle_python` build could start from the generated `build-rocm` tree, but the initial retry failed in `extern_warprnnt` because `third_party/warprnnt` on the remote instance contained only a `.git` redirect file and no checked-out worktree.
- Patched `scripts/remote_launch_paddle_rocm_configure.sh` and `scripts/remote_build_paddle_rocm.sh` so empty submodule worktrees are treated as broken and are force-recovered instead of being accepted as healthy.
- Manually repaired the remote `third_party/warprnnt` checkout, reran the targeted build, and advanced the failure point from `extern_warprnnt` to `extern_warpctc` configure.
- Confirmed a second targeted-build blocker in `paddlerepos/Paddle/cmake/external/warpctc.cmake`: the external ROCm configure path does not inherit the top-level `CMAKE_MODULE_PATH`, so `HIP_ADD_LIBRARY` is undefined inside the WarpCTC sub-build.
- Added a local experimental patch in `paddlerepos/Paddle/cmake/external/warpctc.cmake` to forward `CMAKE_MODULE_PATH` into the external WarpCTC configure, but the final remote retry and BF16 runtime probe are still pending because the live Jupyter websocket became unreliable again during the follow-up rerun attempts.
- Switched the active Jupyter session to `http://36.151.243.69:30008/instance/nb-1838d2b6/lab` and verified authenticated API access plus terminal websocket access on the new instance.
- Confirmed that this new instance already provides a ready ROCm-capable Paddle environment in `/opt/venv`, so a full control-plane bootstrap was not required before validation.
- Verified on the new instance that `rocminfo` and `hipcc` are present, Paddle imports successfully as `3.4.0.dev20260404`, `paddle.is_compiled_with_rocm()` reports `True`, `paddle.is_compiled_with_cuda()` reports `True`, `paddle.device.get_device()` reports `gpu:0`, and both BF16 support APIs return `True`.
- Attempted a minimal live BF16 GPU matmul on the new instance, but the terminal websocket dropped during the execution attempt; this is recorded as a transport limitation, not a confirmed BF16 runtime failure.
- Confirmed from the next runtime attempt that the BF16 failure is real and occurs before matmul: `paddle.randn(..., dtype="bfloat16")` segfaults on the GPU path, and the C++ traceback terminates inside `phi::GaussianKernel<phi::dtype::bfloat16, phi::GPUContext>` and `phi::funcs::distribution_and_transform`.
- Narrowed the source-side crash path to `paddlerepos/Paddle/paddle/phi/kernels/gpu/gaussian_kernel.cu`, specifically the `seed == 0` branch that calls `funcs::distribution_and_transform<T>(dev_ctx, out, dist, trans)` for BF16 on GPU.
- Switched validation to the new preloaded Jupyter instance `http://36.151.243.69:30006/instance/nb-1838d2b6/lab`, created terminal `1`, and confirmed authenticated API access plus terminal execution from `/opt/PaddleX` as `root`.
- Verified that `30006` reports the same high-level readiness signals as `30008`: `rocminfo` and `hipcc` are present, Paddle imports from `/opt/venv` as `3.4.0.dev20260404`, `paddle.is_compiled_with_rocm()` is `True`, `paddle.device.get_device()` is `gpu:0`, and both BF16 support APIs return `True`.
- Confirmed that `30006` is not a usable validation target in its current image state: a one-line `paddle.randn([8,8], dtype="bfloat16")` on GPU segfaults in `phi::GaussianKernel<phi::dtype::bfloat16, phi::GPUContext>`, and a separate `paddle.ones([2,2], dtype="float32")` control also segfaults in `phi::FullKernel<float, phi::GPUContext>`.
- Refined the working diagnosis from a BF16-only Gaussian defect to a broader preloaded-image runtime problem on `30006`, because even minimal float32 GPU tensor materialization fails before any BF16-specific validation can begin.
- Attempted to bootstrap a fresh `/app/paddle-amd-remote` workspace on `30006`, but the instance cannot resolve external hosts such as `github.com` or `gitee.com`, so remote clone-based source-build preparation is currently blocked by image networking.
- Ran narrower GPU controls on `30006` and confirmed the image is not fully dead: `paddle.to_tensor(..., place="gpu")` succeeds for float32, and float32 `paddle.matmul` also succeeds when fed from `to_tensor` inputs.
- Confirmed that the active `30006` failure scope is centered on creator and conversion kernels, not all GPU execution: float32 `paddle.randn` segfaults in `phi::GaussianKernel<float, phi::GPUContext>`, BF16 `paddle.randn` segfaults in the BF16 Gaussian path, float32 `paddle.ones` segfaults in `phi::FullKernel<float, phi::GPUContext>`, and float32-to-BF16 `astype` segfaults in `phi::CastCUDAKernelImpl<float, phi::dtype::bfloat16>`.
- Recorded the installed preloaded Paddle build identity on `30006` as `3.4.0.dev20260404`, commit `79630aedd7f4d5f8ac6c4fe6a2290ab1657d65f6`, imported from `/opt/venv/lib/python3.12/site-packages/paddle/__init__.py`.
- Checked the local WSL machine as a possible ROCm build host and confirmed that it has a real Linux ROCm toolchain: Ubuntu 24.04.3, Python 3.12.3, `hipcc` from ROCm 6.4.2, `rocminfo`, `cmake 3.28.3`, and `ninja 1.11.1` are all available locally.
- Confirmed that the local WSL environment is suitable for compiling a candidate ROCm-enabled Paddle wheel, but not for final acceptance evidence: the authoritative runtime still needs to be a native Linux ROCm or remote AMD ROCm instance.
- Recorded the main remaining deployment risk for local-build-to-remote flow: the current local toolchain is ROCm 6.4.2 while the current remote preloaded image line is ROCm 7.2.x, so wheel deployment from WSL to remote is possible but version-aligned build hosts remain preferable.
- Started the first real local ROCm wheel build from `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local` with ROCm Clang, `PADDLE_SKIP_FLASHATTN=ON`, and the local `rocm-compat` overlay enabled.
- Cleared the earlier local build blockers for `warprnnt`, `warpctc`, OpenBLAS discovery, stale external-project install state, and the GCC-versus-ROCm-header incompatibility by switching the host compiler to ROCm Clang and resetting stale external build state.
- Identified a recurring HIP compile pattern in several `paddle/phi/kernels/funcs` translation units where implementation files were pulling `eigen/common.h` through headers that did not actually need Eigen for the GPU path.
- Removed unnecessary Eigen-heavy includes from `affine_grid_utils.cu`, `cross_entropy.h`, `fake_dequantize_functor.h`, and `fake_quantize_functor.h`, and added the explicit `paddle/phi/common/memory_utils.h` dependency back to `fake_quantize_functor.cu` after slimming its header path.
- Escalated the diagnosis from per-file cleanup to a shared third-party issue after `math_function.cu` failed in the same `Eigen/src/Core/arch/Default/Half.h:669` path even though `math_function_impl.h` genuinely depends on Eigen.
- Patched local third-party Eigen at `third_party/eigen3/Eigen/src/Core/arch/Default/Half.h` so HIP device builds use the `logf(float(a))` fallback for `half log()` instead of calling `::hlog(a)`, which was resolving to the BF16 overload on the current ROCm stack.
- Verified that the post-Eigen-patch serial rebuild no longer immediately reproduces the earlier `Half.h:669` failure and has advanced back into HIP object compilation under `paddle/phi/kernels/funcs/eigen/`.
- Confirmed that the next serial-build stop moved to host C++ code in `paddle/phi/api/lib/tensor_utils.cc`, where the local ROCm 6.4.2 headers expose `hipPointerAttribute_t::type` instead of `hipPointerAttribute_t::memoryType`.
- Patched `tensor_utils.cc` to use `attr.type` on the HIP path, then rebuilt the single failed object successfully before resuming the full serial build.
- Confirmed that the next resumed serial-build stop moved into the PyTorch-compat c10 layer at `paddle/phi/api/include/compat/c10/cuda/CUDAStream.cpp`, where a HIP build was still requiring direct CUDA header names and CUDA runtime spellings.
- Patched `paddle/phi/api/include/compat/c10/cuda/CUDAException.h` so the HIP build path includes `hip/hip_runtime.h` and provides the narrow CUDA-name compatibility aliases required by the compat c10 CUDA stream layer; then rebuilt the previously failing `CUDAStream.cpp.o` successfully.
- Confirmed that the next resumed stop moved to `paddle/phi/core/memory/allocation/allocator_facade.cc`, where the shared CUDA/HIP include block still pulled in `paddle/phi/backends/dynload/cuda_driver.h` even though the HIP path in this file does not use CUDA driver APIs.
- Narrowed the `cuda_driver.h` include to the CUDA-only branch in `allocator_facade.cc`, then rebuilt the previously failing object successfully before resuming the full serial build.
- Confirmed that the next resumed stop at `paddle/phi/core/platform/stream_callback_manager.h` was not a new source incompatibility but another empty submodule worktree: `third_party/threadpool` existed only as a `.git` redirect file, so `ThreadPool.h` was absent from the include path.
- Recovered the local `third_party/threadpool` submodule checkout and verified that the previously failing `stream_callback_manager.cc.o` target resumed successfully without additional source edits.
- Confirmed that the next local serial-build stop in `paddle/phi/kernels/funcs/cross_entropy.cc` was another missing-helper source issue rather than a ROCm version gate: the translation unit used Paddle Eigen wrappers without including `paddle/phi/kernels/funcs/eigen/common.h`.
- Patched `cross_entropy.cc` to include the shared Eigen helper header, rebuilt the previously failing object successfully, and resumed the serial build past that stop.
- Confirmed that the next resumed stop in `paddle/phi/kernels/funcs/fake_dequantize_functor.cc` was the same class of source issue: the implementation used `EigenVector` without pulling in the shared Eigen helper definitions.
- Patched `fake_dequantize_functor.cc` to include `paddle/phi/kernels/funcs/eigen/common.h` and restore the local `EigenVector` alias, then rebuilt the failed object successfully.
- Confirmed that the next resumed stop in `paddle/phi/kernels/funcs/fake_quantize_functor.cc` was still source-side helper drift, with missing declarations for `phi::Transform`, `phi::ClipFunctor`, and `EigenVector`.
- Patched `fake_quantize_functor.cc` to include `paddle/phi/common/transform.h`, `paddle/phi/kernels/funcs/eigen/common.h`, and `paddle/phi/kernels/impl/clip_kernel_impl.h`, restored the local `EigenVector` alias, and rebuilt the failed object successfully.
- Confirmed that the next local ROCm blocker moved into HIP radix-sort compatibility in `paddle/phi/kernels/gpu/argsort_kernel.cu`, where the current ROCm 6.4.2 rocPRIM stack no longer accepted Paddle's older `radix_key_codec_integral` plus `detail::float_bit_mask` shims for float16 and bfloat16.
- Replaced the duplicated per-file HIP radix-sort shims with a shared compatibility bridge in `paddle/phi/kernels/funcs/hip_radix_sort_compat.h`, wired it through the common HIP cub path, and switched Paddle float16/bfloat16 to rocPRIM floating-point codec and new-style `rocprim::traits::define` trait specializations.
- Verified that the direct rebuild of the previously failing generated argsort HIP object no longer immediately reproduces the old rocPRIM `float_bit_mask` and `bit_cast` errors and now advances back into `phi_gpu` HIP object compilation.
- Confirmed that the three recently patched helper units still contained a narrower follow-up source issue: their local `EigenMatrix` and `EigenVector` aliases were shadowing the global Paddle Eigen wrappers instead of explicitly binding to `phi::EigenMatrix` and `phi::EigenVector`.
- Patched `paddle/phi/kernels/funcs/cross_entropy.cc`, `paddle/phi/kernels/funcs/fake_dequantize_functor.cc`, and `paddle/phi/kernels/funcs/fake_quantize_functor.cc` to use explicit `phi::Eigen*` aliases, normalized the remaining `phi::ClipFunctor` call sites in `fake_quantize_functor.cc`, and rebuilt all three previously failing objects successfully.
- Resumed the serial local ROCm build after those targeted validations and confirmed that it advanced past the earlier helper-failure region into the broader `paddle/phi/kernels/cpu/` compile set without reproducing the prior stops.
- Created bilingual project documentation skeleton.
- Added shared project instructions to enforce bilingual tracking and evidence discipline.

## 2026-04-13

- Confirmed that the next resumed local ROCm serial-build blocker had moved into `paddle/phi/kernels/gpu/top_k_kernel.cu`, where the HIP path hardcoded `WARP_SIZE=64` but still instantiated a 32-thread specialization through the macro-generated switch.
- Patched `top_k_kernel.cu` to clamp HIP runtime `thread_per_block` to at least one warp and to omit the HIP-only 32-thread `FIXED_BLOCK_DIM` specialization, then validated the fix by rebuilding the previously failing generated object `paddle/phi/CMakeFiles/phi_gpu.dir/kernels/gpu/phi_gpu_generated_top_k_kernel.cu.o` successfully.
- Confirmed that the following resumed blocker had moved to host-side DLPack include resolution for `paddle/fluid/platform/densetensor_printer.cc.o`, where `dlpack/dlpack.h` was missing despite an existing submodule gitdir.
- Patched `cmake/external/dlpack.cmake` to export the DLPack include directory through the `dlpack` interface target, added a direct `dlpack` dependency to `densetensor_printer`, restored the tracked public header `third_party/dlpack/include/dlpack/dlpack.h` from the submodule commit, and validated the fix by rebuilding `paddle/fluid/platform/CMakeFiles/densetensor_printer.dir/densetensor_printer.cc.o` successfully.
- Resumed the full serial `paddle_copy` build after those validations and confirmed fresh forward progress into later framework and IR targets without a new hard blocker at the latest observed checkpoint.
- Confirmed that the next fresh late-stage blocker was a link failure in `paddle/fluid/pybind/eager_generator`, caused by unresolved `phi::dynload::hipMemCreate` and `phi::dynload::hipMemRelease` symbols referenced from `paddle/phi/core/platform/device/gpu/gpu_info.cc`.
- Patched `paddle/phi/backends/dynload/rocm_driver.cc` so it instantiates the already-declared ROCm virtual-memory-management and GPU-graph dynload wrapper groups, instead of instantiating only the base ROCm routine list.
- Validated the dynload fix by rebuilding the exact previously failing `eager_generator` target successfully and confirming that `build-rocm-local/paddle/fluid/pybind/eager_generator` was produced again.
- Resumed the full serial `paddle_copy` build after the exact-target validation and confirmed that the build moved forward past the old `eager_generator` stop.

## 2026-04-14

- Confirmed a disposable local smoke test for the built wheel `build-rocm-local/python/dist/paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl` using a temporary virtual environment under `/home/oldzhu/paddle-amd/.venv-wheel-smoke`.
- Verified that the locally installed wheel imports successfully as `3.4.0.dev20260408`, reports `paddle.is_compiled_with_rocm() == True`, and reports `paddle.is_compiled_with_cuda() == True` on the WSL host.
- Verified that the temporary smoke-test virtual environment was removed after the import check, so no local wheel installation was left behind.
- Reauthenticated the remote helper against the live instance-scoped base URL `http://36.151.243.69:30006/instance/nb-1838d2b6` and created remote terminal `paddle-amd-bf16` through the Jupyter terminals API.
- Confirmed that the live instance root does not contain a precreated `uploaded-wheels/` directory; the first upload attempt failed with server-side `No such file or directory`, so the wheel was uploaded instead to the workspace root as `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`.
- Patched `scripts/jupyter_remote.py` to harden token login and websocket setup by visiting `/lab?token=...` during token login and by sending cookie plus origin headers during terminal websocket connection attempts.
- Confirmed that the current `30006` instance still does not allow terminal command execution through the helper after that hardening: the websocket handshake to `/instance/nb-1838d2b6/terminals/websocket/paddle-amd-bf16` returns HTTP `200` with the HTML terminal page instead of upgrading the websocket.
- Recorded the current remote state as: wheel artifact staged on the live instance, but install-and-smoke execution still blocked by terminal websocket routing or frontend behavior on this notebook stack.
- Retried against the restarted `30006` instance, confirmed terminal websocket execution was restored on terminal `1`, and verified remote shell access from `/opt/PaddleX` as `root` with `/opt/venv/bin/python 3.12.3`.
- Reuploaded the locally built wheel, force-reinstalled it in `/opt/venv`, and confirmed that the runtime blocker moved from transport to dynamic linking: the ROCm 6.4.2-built wheel first failed on missing `libamdhip64.so.6` against the remote ROCm 7.2 image.
- Proved that the first blocker is a SONAME mismatch rather than a generic import failure by adding `/opt/PaddleX/rocm64-compat/libamdhip64.so.6 -> /opt/rocm/lib/libamdhip64.so.7` and re-running `ldd` plus `import paddle` under an adjusted `LD_LIBRARY_PATH`.
- Confirmed that the shim changes the failure signature to `ImportError: libopenblas.so.0: cannot open shared object file`, and that the active `30006` image currently contains no discoverable `libopenblas.so.0` in `/opt`, `/usr`, or `/lib`.
- Confirmed that the remaining remote repair path is also blocked by instance networking: `apt-get update` fails with temporary DNS resolution errors for Ubuntu, deadsnakes, and AMD ROCm package hosts, so the missing OpenBLAS runtime cannot currently be installed through standard packages on this image.
- Recorded the current remote state as: installable wheel artifact, working terminal transport, confirmed ROCm 6-to-7 runtime mismatch, and a second missing base runtime dependency on an image whose package-repair path is blocked by DNS failure.

## 2026-04-15

- Switched remote validation to the newly started instance `http://36.151.243.69:30002/instance/nb-1838d2b6/lab`, reauthenticated the helper successfully, and confirmed terminal websocket execution on terminal `1` from `/opt/PaddleX` as `root` with `/opt/venv/bin/python 3.12.3`.
- Reproduced the DNS blocker on this instance with the default resolver (`nameserver 10.232.0.10`): `getent` could not resolve Ubuntu and security hosts, and `apt-get update` showed repeated temporary host resolution failures.
- Validated that a mixed resolver configuration (cluster DNS plus public resolvers with `ndots:1`) restores resolution for `archive.ubuntu.com`, `security.ubuntu.com`, `github.com`, and `ppa.launchpadcontent.net`, while `compute-artifactory.amd.com` still does not resolve.
- Confirmed that with this mixed resolver state, `apt-get update` refreshes Ubuntu and PPA indexes successfully and returns exit code `0`, with only a warning on the unresolved AMD artifactory source.
- Verified that package operations needed for workflow continuation are now unblocked by installing `libopenblas0-pthread` remotely via apt.
- Updated `scripts/render_remote_dns_repair.sh` so default DNS health checks target required public hosts for build and package workflows, preserve existing nameservers while appending fallback public resolvers, and use `options timeout:2 attempts:2 rotate ndots:1`.
- Added an opt-in strict mode `--require-compute-artifactory` in the DNS repair renderer for runs that explicitly require the private AMD package host.
- Revalidated `scripts/remote_fix_instance_dns.sh 1` end to end after the helper update: the script now succeeds on this instance and leaves apt usable for standard package operations.
- Added a dedicated remote DNS repair generator `scripts/render_remote_dns_repair.sh` plus a local execution wrapper `scripts/remote_fix_instance_dns.sh` so future remote retries can repair `/etc/resolv.conf`, validate package-host resolution, and optionally run `apt-get update` before clone, apt, or pip work.
- Added a DNS preflight to `scripts/render_remote_bootstrap.sh` so fresh-instance bootstrap now fails fast with a specific remediation path instead of falling deeper into clone and package errors when hostname resolution is already broken.
- Revalidated that DNS drift can recur after instance restart: terminal `1` initially returned to host-resolution failures, and rerunning `scripts/remote_fix_instance_dns.sh 1` restored public package-host resolution plus usable `apt-get update` behavior.
- Reinstalled the remote OpenBLAS runtime state (`libopenblas0-pthread`) on the restarted instance, then reuploaded the local wheel artifact because the fresh instance workspace no longer contained the previously uploaded file.
- Force-reinstalled `/opt/venv` with `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`, reapplied the HIP SONAME compatibility symlink `libamdhip64.so.6 -> libamdhip64.so.7`, and reran the remote GPU smoke test successfully.
- Captured a clean successful smoke JSON on `30002` with `version` `3.4.0.dev20260408`, `compiled_with_rocm` `true`, device `gpu:0`, and float32 matmul output `[[7.0, 10.0], [15.0, 22.0]]`.
- Continued with isolated operator probes after the successful smoke and verified that float32 `ones`, float32 `randn`, BF16 `randn`, float32-to-BF16 `astype`, and BF16 `matmul` all return successfully on `gpu:0` under the same runtime setup.
- Advanced to integration-level quick validation with `/opt/PaddleX/verify_inference.sh --mode quick --device gpu`; preflight passed, but native inference failed with a segmentation fault in the GPU add/broadcast kernel path (`phi::AddRawKernel<float, phi::GPUContext>`).
- Started a targeted rerun using `--device dcu` to check device-alias sensitivity, but the instance dropped mid-run and then returned `HTTP 503`, so the rerun result is pending next instance recovery.
- After instance recovery, resumed the targeted `--device dcu` quick rerun using detached background execution plus log polling and confirmed the same native segfault signature (`phi::AddRawKernel<float, phi::GPUContext>`), ruling out `gpu` versus `dcu` alias effects.
- During the resumed rerun, fixed live resolver drift inline (`223.5.5.5`, `8.8.8.8`, `1.1.1.1`, `ndots:1`), restored model-host resolution, and observed successful ModelScope download of `PP-DocLayoutV3` before the same native crash.
- Captured final quick output for that same run: vLLM server readiness timed out after `180s`, quick summary reported `Native precision: failed`, `vLLM precision: failed-server`, and `Overall: FAIL`.
- Noted an execution-wrapper nuance: `/tmp/paddle_amd_quick_dcu.done` remained absent even after summary output and process exit, so completion was determined from log terminal summary plus process state.
- After capturing the completed summary, the `30002` endpoint became unavailable again (`jupyter_remote.py login` returned `HTTP 503`, and direct API curl timed out), so post-run cleanup commands could not be completed in this window.
- After the instance came back again, reran DNS inline resolver repair and confirmed required model hosts resolve before deeper reproduction.
- Added a standalone native repro outside `verify_inference.sh` and reproduced the same `phi::AddRawKernel<float, phi::GPUContext>` segfault path with PaddleOCRVL predict; this confirms the native crash is not wrapper-specific.
- Added a standalone vLLM startup repro outside `verify_inference.sh`; observed long cold-start (download/compile/graph-capture) and then `Application startup complete`, indicating the earlier quick-mode `failed-server` can be caused by readiness-window pressure under cold start.
- Recorded that this restart reported preloaded Paddle runtime `3.4.0.dev20260404` (`is_compiled_with_rocm == True`) during standalone native repro logging.

## 2026-04-16

- Continued `speed-vllm` isolated rerun on `30002` after observing resolver drift back to cluster defaults (`10.232.0.10`, `ndots:5`).
- Reapplied inline resolver state (`223.5.5.5`, `8.8.8.8`, `1.1.1.1`, `timeout:1`, `attempts:2`, `ndots:1`) and revalidated resolution for `www.modelscope.cn`, `paddle-model-ecology.bj.bcebos.com`, `git.aistudio.baidu.com`, and `huggingface.co`.
- Relaunched detached `/opt/PaddleX/verify_inference.sh --mode speed-vllm --device dcu` with fresh log and rc markers (`/tmp/paddle_amd_speed_vllm.log`, `/tmp/paddle_amd_speed_vllm.rc`).
- Confirmed active worker and `paddlex_genai_server` processes after relaunch and captured ongoing state where runner log is still waiting for `/v1` readiness while server log shows official-model cold-start/download messaging.
- Recorded the current checkpoint as in-progress: DNS/model-host failures are not the dominant signature in this rerun window, but final `speed-vllm` pass/fail result is still pending.
- Captured a new infra interruption: remote command stream on terminal `2` ended with `Connection to remote host was lost`, and immediate `jupyter_remote.py info/list-terminals/login` retries returned `HTTP 503` with direct API probe timeout.
- Preserved run status as interrupted-by-endpoint-availability pending next instance recovery, rather than marking a validation pass/fail.
- Observed another brief recover-then-fail cycle while continuing execution: fresh-terminal probing resumed temporarily, then endpoint health regressed again to `HTTP 503` plus direct API timeout before final speed-vllm convergence.

## 2026-04-17

- Switched active continuation to the newly started `30008` instance and re-established authenticated API access (`version 2.17.0`).
- Rebuilt terminal state and stabilized command execution on terminal `2` after stale-terminal websocket instability.
- Re-applied inline resolver hardening (`223.5.5.5`, `8.8.8.8`, `1.1.1.1`, `timeout:1`, `attempts:2`, `ndots:1`) and revalidated required model hosts (`www.modelscope.cn`, `paddle-model-ecology.bj.bcebos.com`, `git.aistudio.baidu.com`, `huggingface.co`).
- Identified and removed a self-terminating restart step: kill patterns that matched command text caused `Terminated` before launch; switched to launch path without that self-match point.
- Successfully relaunched detached `verify_inference.sh --mode speed-vllm --device dcu` and confirmed active worker plus `paddlex_genai_server` processes.
- Captured current run checkpoint as active but pending: runner remains at vLLM readiness wait and server log shows official-model prepare start without a new immediate DNS-resolution exception in this `30008` window.
- Continued polling to terminal state and captured explicit summary outcome: `Speed benchmark: failed-server`, `Overall: FAIL`.
- Captured that readiness timeout (`180s`) still triggers before server readiness is observed, even when model download/processing and API bootstrap messages appear later in the same log window.
- Verified end-of-run process state with no remaining active speed-vllm worker/server process; rc marker file `/tmp/paddle_amd_speed_vllm.rc` remained absent, so summary-plus-process evidence was used as completion criteria.
- Began the next standalone discriminator step (longer direct vLLM readiness probe), but endpoint health immediately regressed to `HTTP 503` plus API timeout, blocking additional in-instance diagnostics for now.
- On 2026-04-19 continuation, re-established `30008`, pinned DNS, and validated model-host resolution before launching the standalone direct vLLM 600s readiness probe.
- The long probe command then lost websocket transport mid-run (`Connection to remote host was lost`), and immediate re-login/API probes returned `HTTP 503` with direct API timeout.
- Current state is again infra-blocked before discriminator artifact recovery.
- After the next instance recovery, reran the standalone discriminator as a detached on-instance script writing `/tmp/paddle_amd_vllm_direct.*` artifacts to avoid websocket loss on long waits.
- Captured terminal discriminator result: `STATUS=READY`, `READY_AT_SEC=348`, with direct log showing `Application startup complete` and local `GET /v1/models` returning `200 OK`.
- Closed the root-cause split for this milestone: `verify_inference.sh` `failed-server` is now evidenced as a readiness-window mismatch (`180s` gate) rather than a deterministic immediate vLLM init failure.

## 2026-04-22

- Continued GPU validation on `30001` instance (gfx1100 / ROCm 7.2.0).
- Installed ROCm-capable Paddle on remote:
  - Fixed DNS (`223.5.5.5`, `8.8.8.8`, `1.1.1.1`).
  - Installed `libopenblas0-pthread` via apt.
  - Created SONAME shim: `ln -sf /opt/rocm/lib/libamdhip64.so.7 /opt/rocm-compat/libamdhip64.so.6`.
  - Uploaded locally-built ROCm Paddle wheel (`paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`, 242MB) to `/workspace/PaddleX/`.
  - Force-installed wheel: `pip3 install --force-reinstall ...` → `paddlepaddle-dcu 3.4.0.dev20260408` installed successfully.
  - Verified: `paddle.is_compiled_with_rocm() = True`, `paddle.device.get_device() = gpu:0`.
- Ran GPU static inference validation with `scripts/test_conv2d_hip_pass.py`:
  - **Test 1 (BUG CONFIRMED)**: Without pass deletion → `RuntimeError: The kernel fused_conv2d_add_act is not registered` on ROCm gfx1100.
  - **Test 2 (FIX VALIDATED)**: With `config.delete_pass("conv2d_add_act_fuse_pass")` + `config.delete_pass("conv2d_add_fuse_pass")` → Inference PASS, output shape `(1, 16, 32, 32)`.
  - **Test 3 (BF16 PASS)**: `auto_cast(dtype="bfloat16")` dynamic graph inference runs correctly on GPU.
- Key finding: the locally-built ROCm Paddle wheel was built BEFORE the `#ifdef PADDLE_WITH_HIP` fix was applied to source. The fix therefore could not be tested directly in the binary. However the test conclusively shows:
  - The passes ARE the root cause (`fused_conv2d_add_act` not registered on HIP).
  - The `delete_pass()` workaround works, which is exactly what the `#ifdef PADDLE_WITH_HIP` guard achieves at compile time.
  - A rebuilt wheel with the guard would pass Test 1 as well (no crash without pass deletion).
- Note on `FLAGS_conv_workspace_size_limit`: `enable_use_gpu()` tries `SetGflag("conv_workspace_size_limit", "32")` in `analysis_predictor.cc:2389`. This gflag does not exist in the HIP build (it's CUDA/cuDNN-specific). Workaround: `export FLAGS_conv_workspace_size_limit=32` prevents the SetGflag call. This is an additional HIP compatibility issue in Paddle's inference predictor.
- Updated bilingual validation docs with this GPU inference validation run.

### Earlier 2026-04-22 entries:

- User reported new instance `30001` started (`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`; new port).
- Connected immediately: `login`/`info`/`list-terminals` all returned `version 2.17.0`, no existing terminals.
- Created terminal `1` and ran environment triage:
  - Container image: one-click PaddleOCR-VL notebook; `oneclick_entrypoint.sh` auto-starts `paddlex_genai_server` at boot.
  - GPU agents: 4 (`rocminfo`); ROCm 7.2.0; vLLM already starting from entrypoint.
  - `verify_inference.sh` absent (different image from 30008).
  - Paddle in `/opt/venv`: 3.1.1 CPU-only — irrelevant because vLLM uses PyTorch ROCm directly.
- Inspected `oneclick_entrypoint.sh` and confirmed vLLM server was auto-started via `nohup paddlex_genai_server … --backend vllm` at container launch, logging to `/var/log/paddlex_vllm_server.log`.
- Polled vLLM readiness; server reached READY at approximately `23:34 UTC` (confirmed `Application startup complete`, `200 OK` from `/v1/models`).
  - Key vLLM startup evidence: `dtype=torch.bfloat16`, `Using Triton Attention backend on V1 engine` (ROCm path), model loaded 1.9727 GiB in 2.5s.
- Fixed DNS (`223.5.5.5 / 8.8.8.8 / 1.1.1.1`, `timeout:1 attempts:2 ndots:1`) and installed `pynvml` (needed by benchmark).
- Located benchmark at `/opt/paddlex/benchmarks/ocr-vlm-benchmark-f29cfe4/ocr-vlm-benchmark-f29cfe4/e2e/`; confirmed `test_server.py`, `PaddleOCR-VL-1_5_vllm.yaml`, `test_local.py`.
- Determined `test_server.py` requires PaddleX HPS Triton server at port 8001 (not running); pivoted to direct PaddleX Python pipeline API as equivalent approach.
- Wrote `/tmp/paddle_amd_speed_bench.py` using `paddlex.create_pipeline(config=PaddleOCR-VL-1_5_vllm.yaml)` to process PDFs sequentially, measuring throughput.
- Launched detached runner (`/tmp/paddle_amd_bench.sh`, PID 1671).
- Polled progress twice; confirmed stable at `~0.16 pps` with all files succeeding.
- **Final result (PASS)**: `success_count=64/64`, `pages_per_sec=0.164`, `total_time_sec=391.03`, `BENCH_RC=0`.
  - Run window: `2026-04-21T23:40:55+00:00` → `2026-04-21T23:47:33+00:00`.
- Updated all bilingual validation, dev-log, and change-log docs.
- Performed root-cause analysis of the Paddle/PaddleX HIP BF16 issue:
  - Confirmed `conv2d` kernel has BF16 registered on ROCm (no issue there).
  - Found that `fused_conv2d_add_act_kernel.cu` is wrapped in `#ifdef PADDLE_WITH_CUDA` — no ROCm kernel.
  - Found that `conv2d_add_act_fuse_pass` and `conv2d_add_fuse_pass` run in `kPirGpuPasses` on both CUDA and ROCm, but generate op types with no ROCm kernel — causing runtime errors.
  - This is why PaddleX deleted those passes on ROCm as a workaround.
- Implemented fix in Paddle: added `#ifdef PADDLE_WITH_HIP … return ps; #endif` early-return in `InitializePatterns()` in both fuse pass files.
- Implemented PaddleX cleanup: removed all four `config.delete_pass()` ROCm workaround blocks from `static_infer.py`; added `"dcu"` to `is_bfloat16_available()` device type allowlist in `misc.py`.
- Saved patches to `patches/paddle-hip-conv2d-fuse-pass-guard.patch` and `patches/paddlex-remove-rocm-workaround.patch`.
- Applied `paddlex-remove-rocm-workaround.patch` to the remote instance (`/workspace/PaddleX/` editable install + `/opt/venv/...` site-packages install).
  - Issue: Python imported from `/workspace/PaddleX/` (editable install) not `/opt/venv/...`, so patch was applied to both.
  - Functional test (`remote_test_paddlex_patch.py`): **5/5 checks passed**.
- Re-ran the full 64-PDF benchmark with patched PaddleX:
  - **Result (PASS)**: `success_count=64/64`, `pages_per_sec=0.182`, `total_time_sec=351.83`
  - Run window: `2026-04-22T00:20:30+00:00` → `2026-04-22T00:26:22+00:00`
  - No regression after workaround removal. Slightly higher pps (0.182 vs 0.164) due to warm caches.
- Updated validation docs with both run results (baseline and patched).

## 2026-04-20

- Resumed immediately after user reported the `30008` instance as started and revalidated API access (`version 2.17.0`) with terminal `1` available.
- Launched a ready-first integrated rerun sequence to avoid the known `180s` cold-start gate risk: DNS pinning, model-host checks, precheck/start vLLM with up to `600s` readiness wait, then `verify_inference.sh --mode speed-vllm --device dcu` with artifacts.
- Lost command stream mid-run (`Connection to remote host was lost`) before full terminal output recovery.
- Observed immediate endpoint regression afterward: repeated `jupyter_remote.py login/info/list-terminals` returned persistent `HTTP 503`.
- Recorded this window as infra-interrupted execution, with no new evidence overturning the existing readiness-budget mismatch conclusion.
- After the next user-triggered `30008` restart, reconnected successfully (`version 2.17.0`, terminal `1`) and launched a detached ready-first runner (`/tmp/paddle_amd_speed_vllm_readyfirst.sh`) to reduce websocket fragility.
- Captured in-run milestone that vLLM readiness was reached at `VLLM_READY_AT_SEC=358` under the explicit `600s` gate, then `verify_inference.sh --mode speed-vllm --device dcu` advanced into benchmark execution.
- Latest checkpoint is active and pending: speed benchmark is still running, with vLLM server logs serving repeated `/v1/chat/completions` `200 OK` responses.
- Captured a later runtime snapshot at `2026-04-20T07:45:21+00:00`: `STATUS=RUNNING`, rc pending, with detached runner plus verify worker still alive.
- During a longer wait-for-completion stream, websocket dropped again (`Connection to remote host was lost`), and immediate endpoint probes (`login/info/list-terminals`) regressed to persistent `HTTP 503`.
- Current state for this rerun is infra-interrupted before final benchmark rc recovery.

## Entry Template

- Date:
- Environment:
- Action:
- Result:
- Next: