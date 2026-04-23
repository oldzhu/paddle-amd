[中文版](../zh/change-log.md)

# Change Log

## 2026-04-08

- initialized git repository
- created project structure

## 2026-04-09

- created ignored nested upstream workspace under `paddlerepos/`
- deleted unstable nested clones and recloned both repos cleanly
- verified local Paddle clone on `develop` and recorded its path and commit
- verified local PaddleX clone on `develop` and recorded its path and commit
- added bilingual workspace setup and reproduction guide
- added GitHub origin remote for the control-plane repo
- added remote AMD Jupyter workflow skill and helper scripts
- added Jupyter terminal websocket automation support
- recorded first authenticated remote ROCm environment inspection run
- added reusable per-instance remote preparation automation
- fixed remote bootstrap completion handling and verified per-instance bootstrap on the live Jupyter instance
- refined remote instance policy from unconditional prepare wording to check-first preparation wording
- recorded that `paddlepaddle==3.3.1` installs as a CPU-only wheel in the current remote environment
- added a check-first remote Paddle ROCm source-build probe helper
- recorded the first remote ROCm source configure blockers and reduced the helper's Python package mutation scope
- added HTTP/1.1 submodule retry handling and ROCm header compatibility symlinks to the remote source-build helper
- advanced the remote configure probe past header and submodule blockers to a new `hip_add_library` compatibility blocker
- added a detached remote configure launcher and recorded the current terminal-websocket instability on the fresh backend
- fixed the detached remote configure launcher to avoid nested heredoc expansion failures and verified a clean relaunch on terminal `3` of the live `30005` backend
- identified the next fresh-backend configure blocker as missing `patchelf`, installed it remotely, and relaunched detached configure past that blocker
- hardened the remote submodule recovery helpers so empty worktrees with only a `.git` redirect file are treated as broken
- repaired the remote `third_party/warprnnt` checkout and advanced the first targeted `paddle_python` build past the original `extern_warprnnt` failure
- identified a new remote build blocker in external WarpCTC ROCm configure: missing forwarded `CMAKE_MODULE_PATH` causes `HIP_ADD_LIBRARY` to be undefined
- added an experimental local Paddle patch to forward `CMAKE_MODULE_PATH` into `cmake/external/warpctc.cmake`
- verified a new preloaded `30008` AMD instance that already ships a ROCm-capable Paddle build with BF16 support APIs reporting ready on `gpu:0`
- recorded that a live BF16 matmul follow-up on that instance was limited by terminal websocket disconnects rather than a confirmed runtime failure
- recorded a confirmed BF16 GPU runtime crash on the same `30008` instance: `paddle.randn(..., dtype="bfloat16")` segfaults inside the Gaussian kernel path despite the BF16 support APIs returning `True`
- verified that the newer preloaded `30006` instance is not usable for validation: despite ROCm-ready and BF16-ready API signals, direct BF16 `randn` segfaults and even float32 GPU `ones` segfaults in `phi::FullKernel`
- refined the `30006` diagnosis: the image cannot clone externally, `to_tensor` plus float32 `matmul` still works, but GPU `full`, `gaussian`, and float32-to-BF16 `cast` paths segfault
- recorded that the local WSL machine has a usable ROCm build toolchain and can serve as a candidate local Paddle ROCm wheel build host, with explicit caution about ROCm 6.4.2 local versus ROCm 7.2.x remote version mismatch
- enabled the first local ROCm Paddle wheel build path with ROCm Clang, `PADDLE_SKIP_FLASHATTN=ON`, and the local `rocm-compat` overlay
- fixed local ROCm build blockers in `warprnnt`, `warpctc`, OpenBLAS detection, and stale external-project install state after the compiler switch
- removed unnecessary Eigen include paths from several HIP build units in `paddle/phi/kernels/funcs` and restored the explicit `memory_utils` include needed by `fake_quantize_functor.cu`
- patched local third-party Eigen `Half.h` so HIP half `log()` uses the float fallback instead of the broken `::hlog(a)` path on the current ROCm stack
- advanced the serial local ROCm build past the earlier repeated `Half.h:669` failures and back into HIP object compilation under `paddle/phi/kernels/funcs/eigen/`
- fixed the next local ROCm serial-build blocker in `paddle/phi/api/lib/tensor_utils.cc` by switching the HIP pointer attribute check from `memoryType` to the ROCm 6.4.2 field name `type`
- validated the `tensor_utils.cc` fix by rebuilding the previously failing object successfully before resuming the full serial build
- fixed the next resumed local ROCm serial-build blocker in the compat c10 CUDA layer by teaching `paddle/phi/api/include/compat/c10/cuda/CUDAException.h` to include HIP headers and provide the CUDA-name aliases needed by HIP builds
- validated the compat-layer fix by rebuilding the previously failing `paddle/phi/api/include/compat/c10/cuda/CUDAStream.cpp.o` successfully
- fixed the next resumed local ROCm serial-build blocker in `paddle/phi/core/memory/allocation/allocator_facade.cc` by restricting the `cuda_driver.h` include to the CUDA-only path
- validated the allocator-facade fix by rebuilding the previously failing `allocator_facade.cc.o` successfully
- recovered the empty `third_party/threadpool` submodule worktree after the resumed build failed on missing `ThreadPool.h` in `stream_callback_manager.h`
- validated the submodule recovery by rebuilding the previously failing `paddle/phi/core/platform/stream_callback_manager.cc.o` target successfully without new source edits
- added the missing shared Eigen helper include to `paddle/phi/kernels/funcs/cross_entropy.cc` so the local `EigenMatrix` wrapper and `Eigen::DSizes` usage resolve correctly during the ROCm serial build
- added the missing shared Eigen helper include and local `EigenVector` alias to `paddle/phi/kernels/funcs/fake_dequantize_functor.cc`
- added the missing `transform.h`, shared Eigen helper include, clip-kernel helper include, and local `EigenVector` alias to `paddle/phi/kernels/funcs/fake_quantize_functor.cc`
- added a shared HIP rocPRIM compatibility bridge in `paddle/phi/kernels/funcs/hip_radix_sort_compat.h` for Paddle float16 and bfloat16 radix-sort traits
- wired the shared HIP radix-sort compatibility bridge into `paddle/phi/kernels/funcs/cub.h` and `paddle/phi/kernels/funcs/top_k_function_cuda.h`
- removed stale per-file rocPRIM radix-sort shims from `paddle/phi/kernels/gpu/argsort_kernel.cu`, `paddle/phi/kernels/gpu/argsort_grad_kernel.cu`, and `paddle/phi/kernels/funcs/top_k_function_cuda.h`
- fixed a follow-up aliasing issue in `cross_entropy.cc`, `fake_dequantize_functor.cc`, and `fake_quantize_functor.cc` by binding the local Eigen helper aliases explicitly to `phi::EigenMatrix` and `phi::EigenVector`
- normalized the remaining `phi::ClipFunctor` call sites in `fake_quantize_functor.cc` and validated all three previously failing objects with targeted rebuilds
- resumed the serial local ROCm build after the targeted validations and advanced it past the earlier helper-failure region into the wider CPU-kernel compile set
- added bilingual planning, design, decision, validation, and development log documents
- added project-wide Copilot instructions for documentation and tracking discipline

## 2026-04-13

- fixed the local HIP top-k build blocker in `paddle/phi/kernels/gpu/top_k_kernel.cu` by clamping HIP runtime block selection to one warp or larger and removing the HIP 32-thread specialization from the generated dispatch
- validated the top-k fix with a clean rebuild of `paddle/phi/CMakeFiles/phi_gpu.dir/kernels/gpu/phi_gpu_generated_top_k_kernel.cu.o`
- fixed DLPack include propagation in `cmake/external/dlpack.cmake` by exporting the interface include directory for the `dlpack` target
- added a direct `dlpack` dependency to `paddle/fluid/platform/densetensor_printer`
- restored the tracked public header `third_party/dlpack/include/dlpack/dlpack.h` after discovering the submodule repository metadata existed but its worktree was missing the header file
- validated the DLPack-side fix with a clean rebuild of `paddle/fluid/platform/CMakeFiles/densetensor_printer.dir/densetensor_printer.cc.o`
- resumed the full local serial `paddle_copy` build and advanced it into later framework and IR targets after the two exact-target validations
- fixed the late-stage ROCm dynload linker blocker in `paddle/phi/backends/dynload/rocm_driver.cc` by instantiating the already-declared VMM and GPU-graph wrapper groups alongside the base ROCm wrapper list
- validated the dynload fix with a clean rebuild of the previously failing `eager_generator` target and a regenerated `build-rocm-local/paddle/fluid/pybind/eager_generator` executable
- resumed the full local serial `paddle_copy` build after the exact-target dynload validation and advanced it past the earlier `eager_generator` stop

## 2026-04-14

- verified the locally built `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl` with a disposable virtualenv smoke test and removed the virtualenv afterward
- recorded that the local wheel imports as `3.4.0.dev20260408` and reports both ROCm and CUDA compilation flags as `True` on the WSL host
- hardened `scripts/jupyter_remote.py` token login and websocket setup to establish browser-style cookies during token login and send cookie plus origin headers during terminal websocket attempts
- created remote terminal `paddle-amd-bf16` on the live `30006` instance-scoped Jupyter endpoint
- recorded that uploading to `uploaded-wheels/` fails on the live instance because the directory does not exist under the Jupyter contents root
- uploaded the built wheel successfully to the live remote workspace root as `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- recorded the current remote blocker: terminal websocket execution against the live `30006` notebook stack returns the HTML terminal page instead of a websocket upgrade, so remote install and smoke execution remain pending
- retried on the restarted `30006` instance and confirmed that terminal websocket execution recovered on remote terminal `1`
- force-reinstalled the built wheel remotely and verified that the preloaded `paddlepaddle-dcu 3.4.0.dev20260404` was replaced by `3.4.0.dev20260408`
- confirmed the first remote runtime blocker is the ROCm SONAME mismatch `libamdhip64.so.6` versus the image-provided `libamdhip64.so.7`
- proved the SONAME diagnosis with a narrow compatibility shim under `/opt/PaddleX/rocm64-compat`, which moved the next import failure forward to missing `libopenblas.so.0`
- confirmed the active `30006` image has no discoverable OpenBLAS runtime and that package-based repair is blocked because `apt-get update` fails on outbound DNS resolution
- recorded the final state of this retry as an unsuitable validation image rather than a transport problem: terminal execution works, wheel install works, but the remote runtime is incomplete for this wheel

## 2026-04-15

- switched remote operations to the new instance at `http://36.151.243.69:30002/instance/nb-1838d2b6/lab`, verified helper login, and confirmed terminal websocket execution on terminal `1`
- reproduced the default DNS failure and verified that `apt-get update` fails under the original resolver state
- validated a mixed resolver strategy (existing cluster DNS plus public DNS fallback with `ndots:1`) that restores Ubuntu/security/PPA/GitHub resolution
- confirmed `apt-get update` now refreshes Ubuntu and PPA indexes successfully (with warning only on unresolved `compute-artifactory.amd.com`)
- confirmed apt package operations are unblocked by successfully installing `libopenblas0-pthread` on the remote instance
- updated `scripts/render_remote_dns_repair.sh` to preserve existing nameservers, append fallback resolvers, default to public-host DNS readiness checks, and add opt-in strict flag `--require-compute-artifactory`
- validated the updated helper end to end with `scripts/remote_fix_instance_dns.sh 1`
- added `scripts/render_remote_dns_repair.sh` to generate a targeted remote resolver repair flow for broken Jupyter instances
- added `scripts/remote_fix_instance_dns.sh` to run that DNS repair flow through the active Jupyter terminal
- added a DNS preflight to `scripts/render_remote_bootstrap.sh` so remote bootstrap fails fast with a specific remediation step when required hosts do not resolve
- documented the DNS repair workflow in the bilingual setup guides
- confirmed DNS regression recurs after instance restart and that rerunning `scripts/remote_fix_instance_dns.sh 1` restores package-host resolution on `30002`
- reuploaded the local wheel to the restarted `30002` instance and force-reinstalled it in `/opt/venv`
- re-applied the HIP SONAME compatibility symlink under `/opt/PaddleX/rocm64-compat`
- completed a successful remote GPU smoke run with `paddlepaddle-dcu 3.4.0.dev20260408` on `gpu:0`, including correct float32 matmul output
- completed BF16 operator-level probes on the same restarted `30002` instance, with successful BF16 `randn`, float32-to-BF16 `astype`, and BF16 `matmul`
- executed integration quick validation via `/opt/PaddleX/verify_inference.sh --mode quick --device gpu`; preflight passed but native inference failed with a GPU-kernel segmentation fault (`phi::AddRawKernel<float, phi::GPUContext>` path)
- started a targeted `--device dcu` rerun, but the instance dropped and then returned `HTTP 503`, leaving that rerun pending
- resumed the targeted `--device dcu` rerun after instance recovery and confirmed the same native segfault path as `--device gpu`, ruling out simple device-alias effects
- applied inline resolver repair on the live instance (`223.5.5.5`, `8.8.8.8`, `1.1.1.1`, `ndots:1`), restored model-host resolution, and observed successful ModelScope download of `PP-DocLayoutV3` before the native crash
- captured final quick result for the resumed `--device dcu` run: native failed with segfault, vLLM failed-server after 180s readiness timeout, and summary reported `Overall: FAIL`
- recorded marker nuance: wrapper done file `/tmp/paddle_amd_quick_dcu.done` was not emitted despite completed summary output and exited worker processes
- recorded post-capture infra blocker: endpoint `30002` dropped again (`HTTP 503` and API timeout), preventing final cleanup commands in the same window
- after the next instance recovery, re-applied inline DNS repair and confirmed public model-host resolution
- added standalone native repro outside `verify_inference.sh` and reproduced the same `phi::AddRawKernel<float, phi::GPUContext>` segfault path
- added standalone vLLM startup repro outside `verify_inference.sh`; observed successful API startup (`Application startup complete`) after a long cold-start path
- recorded interpretation split: native path remains a hard crash blocker; vLLM quick failure appears sensitive to cold-start readiness budget

## 2026-04-16

- continued `speed-vllm` rerun on `30002` after confirming resolver drift had returned to default cluster DNS state
- reapplied inline resolver settings with public fallbacks and validated model-host resolution for ModelScope, BOS, Aistudio, and Hugging Face domains
- relaunched detached `/opt/PaddleX/verify_inference.sh --mode speed-vllm --device dcu` with fresh `/tmp/paddle_amd_speed_vllm.log` and `/tmp/paddle_amd_speed_vllm.rc` markers
- confirmed active worker and `paddlex_genai_server` processes in the rerun window and captured logs showing vLLM readiness wait plus official-model cold-start/download progress
- recorded this checkpoint as still in progress: prior DNS `NameResolutionError` signatures are not currently dominant, and final speed-vllm pass/fail is pending
- captured a fresh endpoint outage while cleanup/monitoring commands were running: terminal stream reported `Connection to remote host was lost`, followed by `HTTP 503` and API timeout on health probes
- kept the run state as interrupted by infrastructure availability, pending next instance recovery
- captured another recover-then-outage cycle during continuation: endpoint briefly accepted new terminal operations, then returned to `HTTP 503` and API timeout before speed-vllm could produce a final rc

## 2026-04-17

- switched continuation endpoint to the newly started `30008` instance and re-established authenticated API access
- rebuilt remote terminal inventory and resumed execution on fresh terminal `2`
- reapplied resolver pinning (`223.5.5.5`, `8.8.8.8`, `1.1.1.1`, `timeout:1`, `attempts:2`, `ndots:1`) and revalidated model-host resolution for ModelScope, BOS, Aistudio, and Hugging Face domains
- identified a restart-script pitfall where self-matching kill patterns terminated the launch shell (`Terminated`), then switched to a non-self-matching launch path
- successfully relaunched detached `verify_inference.sh --mode speed-vllm --device dcu` and confirmed active worker plus `paddlex_genai_server` processes
- captured current result as in-progress (`RC=PENDING`) with runner at vLLM readiness wait and server at official-model preparation stage
- continued polling to terminal summary and recorded final result for this run window as `Speed benchmark: failed-server` with `Overall: FAIL`
- captured that readiness timeout at 180s still gates failure even when model download and API bootstrap messages appear later in the same log
- recorded completion-evidence nuance: no active speed-vllm worker/server remained, but `/tmp/paddle_amd_speed_vllm.rc` was not emitted
- attempted immediate standalone discriminator run after summary capture, but endpoint availability regressed to `HTTP 503` and direct API timeout, blocking further remote diagnostics in this window
- on 2026-04-19 continuation, reconnected `30008`, pinned DNS, and started the standalone direct-vLLM 600s readiness discriminator; websocket dropped mid-run and endpoint immediately returned to `HTTP 503` plus API timeout before artifact collection
- after the next recovery, reran the standalone direct-vLLM discriminator as a detached script with artifact files and captured `STATUS=READY` with `READY_AT_SEC=348`
- confirmed direct vLLM log reached `Application startup complete` and served `GET /v1/models` with `200 OK`
- recorded discriminator conclusion: `verify_inference.sh` `failed-server` is primarily a 180s readiness-budget mismatch under cold start, not a deterministic immediate backend init failure

## 2025-05-27

- completed full BF16 end-to-end pipeline validation of PaddleOCR-VL-1.5 on gfx1100 / ROCm 7.2.0 with native Paddle ROCm wheel (not vLLM)
- identified and fixed 5 PaddleX compatibility issues for BF16 on ROCm:
  1. `is_bfloat16_available()` missing `"dcu"` in allowlist (workaround #1)
  2. `static_infer.py` missing consolidated `delete_pass` ROCm guard (workaround #2)
  3. `_paddleocr_vl.py` `_keep_in_fp32_modules` forcing visual encoder to FP32 (workaround #3)
  4. `device_guard()` not handling `"dcu"` device type (paddle.set_device would reject it)
  5. `LayerNorm.forward` BF16→FP32 shim needed because Paddle HIP wheel missing `bfloat16` layer_norm kernel
- identified 2 Paddle C++ root causes requiring upstream PR:
  - `conv2d_add_act_fuse_pass.cc` / `conv2d_add_fuse_pass.cc` missing `#ifdef PADDLE_WITH_HIP` guard
  - `layer_norm_kernel.cu` HIP `PD_REGISTER_KERNEL` missing `phi::bfloat16`
- saved combined Paddle C++ patch to `patches/paddle-hip-bf16-kernels.patch` (59 lines)
- saved validation evidence to `evidence/bf16_pipeline_validation_gfx1100.log`
- **PASS: PaddleOCR-VL-1.5 BF16 inference 202.8s, OCR output correct, EXIT:0**

## 2026-04-22

- reconnected to new instance `30001` (port change from previous `30008`)
- confirmed one-click container auto-starts vLLM; vLLM READY at first check with `dtype=torch.bfloat16` and ROCm Triton backend
- confirmed no `verify_inference.sh` in this container image; pivoted to direct PaddleX Python pipeline API for equivalent validation
- launched detached benchmark with `paddlex.create_pipeline` using `PaddleOCR-VL-1_5_vllm.yaml` (layout detection + vLLM-server VL recognition)
- **PASS: 64/64 PDFs processed, 0.164 pps, BENCH_RC=0** — first complete end-to-end BF16 validation pass on AMD ROCm
- updated bilingual validation, dev-log, and change-log documentation with pass result and full evidence
- identified root cause: `fused_conv2d_add_act` kernel is `#ifdef PADDLE_WITH_CUDA`-only; conv2d fuse passes generate it on ROCm causing runtime errors
- implemented Paddle fix: `#ifdef PADDLE_WITH_HIP` early return in `InitializePatterns()` of both `conv2d_add_act_fuse_pass.cc` and `conv2d_add_fuse_pass.cc`
- implemented PaddleX cleanup: removed 4x ROCm `config.delete_pass()` workaround blocks in `static_infer.py`; added `"dcu"` to `is_bfloat16_available()` allowlist in `misc.py`
- saved patches: `patches/paddle-hip-conv2d-fuse-pass-guard.patch`, `patches/paddlex-remove-rocm-workaround.patch`
- applied `paddlex-remove-rocm-workaround.patch` to `/workspace/PaddleX/` (editable install, imported by Python) and `/opt/venv/lib/python3.12/site-packages/paddlex/`
- ran `remote_test_paddlex_patch.py`: **5/5 checks passed** — "dcu" in allowlist, delete_pass workaround removed, create_pipeline imports OK
- re-ran full 64-PDF benchmark with patched PaddleX: **PASS: 64/64, 0.182 pps** — no regression after workaround removal

## 2026-04-20

- resumed on the newly reported `30008` instance and revalidated initial API access (`version 2.17.0`) with terminal `1`
- started a ready-first integrated rerun sequence (DNS pinning, model-host checks, precheck/start vLLM up to 600s, then `verify_inference.sh --mode speed-vllm --device dcu` with artifacts)
- lost terminal stream mid-run (`Connection to remote host was lost`) before full output collection
- observed immediate endpoint outage after the drop: repeated API retries returned `HTTP 503`
- recorded this window as infrastructure interruption rather than a finalized validation result
- after the next `30008` restart, reconnected successfully and launched a detached ready-first runner (`/tmp/paddle_amd_speed_vllm_readyfirst.sh`) with DNS pinning and host checks
- captured a new discriminator milestone in-run: vLLM readiness reached at `VLLM_READY_AT_SEC=358` under the explicit `600s` gate
- confirmed benchmark phase start after readiness (`verify_inference.sh --mode speed-vllm --device dcu` entered speed run against a running local vLLM endpoint)
- recorded current state as active and pending while benchmark output continues
- captured live running snapshot at `2026-04-20T07:45:21+00:00` with `STATUS=RUNNING`, pending rc, and active detached runner/verify processes
- during a longer completion-watch attempt, stream dropped again and endpoint health immediately regressed to persistent `HTTP 503`
- recorded latest state as infra-interrupted before final benchmark rc collection