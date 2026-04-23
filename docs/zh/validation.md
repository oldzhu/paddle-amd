[English Version](../en/validation.md)

# 验证日志

## 验证清单

- 已记录环境信息
- 已记录 Paddle commit
- 已记录 PaddleX commit
- 已记录 ROCm 版本
- 已记录 GPU 型号
- 已记录精确命令
- 已保存输出日志
- 如需要，已保存截图

## 计划中的验收证据

1. HIP 上 BF16 算子级测试结果
2. PaddleOCR-VL-1.5 在 AMD GPU 上成功执行 BF16
3. 正确性证据与截图
4. 简明的 FP32 与 BF16 显存和运行时间对比

## 运行记录

### 2025-05-27 — **通过（PASS）**：PaddleOCR-VL-1.5 完整 BF16 端对端流水线验证（gfx1100/ROCm 7.2，`30001` 实例）

- 验证目标：`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`
- 环境：
  - OS：Ubuntu 24.04.3 LTS
  - GPU：AMD Radeon RX 7900 GRE（gfx1100）
  - ROCm：7.2.0
  - Paddle：3.4.0.dev20260408（ROCm wheel — `paddlepaddle_dcu`）
  - PaddleX：3.4.3（可编辑安装 `/workspace/PaddleX`，已应用所有补丁）
  - Python：3.12
  - LD_LIBRARY_PATH：`/opt/rocm-compat:/opt/rocm/lib:/opt/rocm/lib64`
  - SONAME 垫片：`libamdhip64.so.6 → libamdhip64.so.7`
- 测试脚本：`/workspace/PaddleX/test_paddleocr_vl_bf16.py`
- 命令：
  ```bash
  cd /workspace/PaddleX
  LD_LIBRARY_PATH=/opt/rocm-compat:/opt/rocm/lib:/opt/rocm/lib64 \
    timeout 600 /opt/venv/bin/python test_paddleocr_vl_bf16.py 2>&1 | tee /tmp/bf16_v6.log
  ```
- 结果：
  - 流水线加载用时 14.6s
  - 推理完成用时 202.8s
  - 输出：版面检测识别出 5 个块（段落标题 + 文本），OCR 文本内容正确
  - 最终 JSON：
    ```json
    {
      "status": "PASS",
      "model": "PaddleOCR-VL-1.5",
      "device": "dcu:0",
      "precision": "bfloat16",
      "gpu": "gfx1100",
      "rocm": "7.2.0",
      "paddle_version": "3.4.0.dev20260408",
      "load_time_s": 14.6,
      "infer_time_s": 202.8,
      "output_items": 1
    }
    ```
- 算子级 BF16 测试（全部通过）：
  - `is_compiled_with_rocm()` = True
  - `is_bfloat16_available('dcu:0')` = True
  - `_keep_in_fp32_modules` = None（已移除）
  - BF16 conv2d SNR = 44.0 dB
  - BF16 matmul 通过
- 证据文件：`evidence/bf16_pipeline_validation_gfx1100.log`
- 截图：`evidence/bf16_pipeline_validation_gfx1100.png`
- 已提交：
  - Paddle Issue：https://github.com/PaddlePaddle/Paddle/issues/78759
  - Paddle PR：https://github.com/PaddlePaddle/Paddle/pull/78760
  - PaddleX Issue：https://github.com/PaddlePaddle/PaddleX/issues/5111
  - PaddleX PR：https://github.com/PaddlePaddle/PaddleX/pull/5112
- 已应用 PaddleX 修复（共 5 处）：
  1. `paddlex/utils/misc.py`：在 `is_bfloat16_available()` 白名单中添加 `"dcu"`
  2. `paddlex/inference/models/common/static_infer.py`：合并 `delete_pass` 块 + 添加 `FLAGS_conv_workspace_size_limit` 默认值
  3. `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`：移除 `_keep_in_fp32_modules = ["visual", "mlp_AR"]`
  4. `paddlex/inference/models/common/transformers/utils.py`：在 `device_guard()` 中添加 `dcu→gpu` 映射
  5. `paddlex/inference/models/doc_vlm/modeling/paddleocr_vl/_paddleocr_vl.py`：添加 `LayerNorm.forward` BF16→FP32 兼容垫片（待 Paddle C++ 内核修复合并后可删除）
- 已提交 Paddle C++ 修复（上游 PR）：
  1. `paddle/phi/kernels/gpu/layer_norm_kernel.cu`：在 HIP `PD_REGISTER_KERNEL` 中添加 `phi::bfloat16`
  2. `paddle/fluid/pir/transforms/gpu/conv2d_add_act_fuse_pass.cc`：添加 `#ifdef PADDLE_WITH_HIP` 守卫
  3. `paddle/fluid/pir/transforms/gpu/conv2d_add_fuse_pass.cc`：添加 `#ifdef PADDLE_WITH_HIP` 守卫
- 总体结论：**PaddleOCR-VL-1.5 在 AMD gfx1100 + ROCm 7.2.0 上以 BF16 精度成功运行。3 个原始 workaround 全部移除，另有 2 个额外修复已应用。模型输出 OCR 结果正确。**

---

### 2026-04-22 — **通过（PASS）**：Paddle GPU 静态推理——conv2d 融合 Pass Bug 确认与修复方案验证（`30001` 实例）

- 验证目标：`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`（终端 2）
- 环境：
  - OS：Ubuntu 24.04.3 LTS
  - GPU：gfx1100（AMD Radeon Graphics，单 GPU）
  - ROCm：7.2.0（`/opt/rocm-7.2.0`）
  - Paddle：3.4.0.dev20260408（本地编译 ROCm wheel — `paddlepaddle_dcu`）
  - Python：3.12.3
  - LD_LIBRARY_PATH：`/opt/rocm-compat:/opt/rocm/lib`（SONAME 兼容符号链接：`libamdhip64.so.6 → libamdhip64.so.7`）
- 前置条件：已安装 `libopenblas0-pthread`、已创建 SONAME 兼容符号链接、已强制安装 ROCm Paddle wheel 覆盖仅 CPU 的 Paddle 3.1.1
- 测试脚本：`scripts/test_conv2d_hip_pass.py` 上传并从 `/workspace/PaddleX/` 执行
- 测试结果：
  - `paddle.is_compiled_with_rocm()`：**True** — ROCm Paddle 验证通过
  - `paddle.amp.is_bfloat16_supported()`：**True**
  - **测试 1（Bug 复现——不删除 Pass）**：Bug 已确认
    - 错误：`RuntimeError: The kernel fused_conv2d_add_act is not registered`
    - 根因：`conv2d_add_act_fuse_pass` 将 `conv2d+BN+relu` 融合为 `fused_conv2d_add_act` op，但 `fused_conv2d_add_act_kernel.cu` 被 `#ifdef PADDLE_WITH_CUDA` 包裹，HIP 下不存在该 kernel
  - **测试 2（修复方案——删除 Pass）**：通过
    - `config.delete_pass("conv2d_add_act_fuse_pass")` + `config.delete_pass("conv2d_add_fuse_pass")`
    - 推理输出形状：`(1, 16, 32, 32)`，无崩溃
    - 等价于 Paddle `#ifdef PADDLE_WITH_HIP` 编译时守卫的效果
  - **测试 3（BF16 动态图）**：通过
    - `auto_cast(dtype="bfloat16")` + `Conv2D` 动态图推理：输出 shape `[1, 16, 32, 32]`，无错误
- 复现命令：
  ```bash
  export LD_LIBRARY_PATH=/opt/rocm-compat:/opt/rocm/lib:$LD_LIBRARY_PATH
  export FLAGS_conv_workspace_size_limit=32
  python3 test_conv2d_hip_pass.py
  ```
- 总体结论：**Bug 已在 gfx1100/ROCm 7.2.0 上确认。Pass 删除（= 编译时守卫）完全修复 GPU 静态推理。Paddle `#ifdef PADDLE_WITH_HIP` 修复方案验证通过。**

---

### 2026-04-22 — **通过（PASS）**：应用 PaddleX BF16 补丁后全量 64/64 基准测试（`30001` 一键实例）

- 验证目标：`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`
- 测试补丁：`patches/paddlex-remove-rocm-workaround.patch`，应用至 `/workspace/PaddleX/` 与 `/opt/venv/lib/python3.12/site-packages/paddlex/`
- 变更内容：(1) `misc.py` 中 `is_bfloat16_available()` 白名单新增 `"dcu"`；(2) `static_infer.py` 中 4 处 `delete_pass("conv2d_add_act_fuse_pass")` / `delete_pass("conv2d_add_fuse_pass")` ROCm 临时绕路代码已全部删除
- 功能测试：`remote_test_paddlex_patch.py` 5/5 全部通过
- 基准测试结果（通过）：
  - `success_count`：64 / 64（100%）
  - `total_pages`：64
  - `total_time_sec`：351.83
  - `pages_per_sec`：0.182
  - 运行窗口：`2026-04-22T00:20:30+00:00` → `2026-04-22T00:26:22+00:00`
- 备注：远端 Paddle 3.1.1 仅 CPU，布局检测仍回退到 CPU。吞吐率 0.182 pps（略高于 0.164 基准，因缓存已预热）。删除临时绕路代码后无回归。
- 总体结论：**PaddleX 临时绕路代码删除后无回归，BF16 补丁端对端验证通过。**

---

### 2026-04-22 — **通过（PASS）**：PaddleOCR-VL-1.5 在 AMD ROCm 上完成 BF16 端对端验证（`30001` 一键实例）

- 验证目标：`http://36.151.243.69:30001/instance/nb-1838d2b6/lab`（新端口 30001）
- 访问方式：认证后的 Jupyter API + terminal websocket
- 容器镜像：一键式 PaddleOCR-VL Notebook（与 30008 不同，本镜像在 `oneclick_entrypoint.sh` 中自动启动 vLLM）
- 环境信息：
  - ROCm：7.2.0（`/opt/rocm-7.2.0`）
  - GPU agents 可见数：4（通过 `rocminfo` 确认）
  - vLLM：`0.14.0rc1.dev2+g7d9f6663a.d20260121`
  - 模型：PaddleOCR-VL-1.5-0.9B
  - dtype：`torch.bfloat16` — BF16 已在 vLLM 启动日志中确认
  - ROCm 注意力后端：`Using Triton Attention backend on V1 engine`
  - PaddleX 版本：3.4.3
  - Python：3.12（`/opt/venv`）
- 压测方式：
  - 容器启动时已自动运行 `paddlex_genai_server`；首次检查时 vLLM 已处于 READY 状态
  - 本镜像无 `verify_inference.sh`
  - 通过 PaddleX Python API（`create_pipeline`）使用 `PaddleOCR-VL-1_5_vllm.yaml` 配置做端对端流水线推理
  - 配置：`PP-DocLayoutV3` 版面检测 + `PaddleOCR-VL-1.5-0.9B` VL 识别（通过 vLLM-server 后端，端点 `http://0.0.0.0:8118/v1/`）
  - 输入：`/opt/paddlex/datasets/omni1_5_pdfs` 中的 64 个 PDF（共 1355 个可用）
  - 脚本：`/tmp/paddle_amd_speed_bench.py`，通过 `/tmp/paddle_amd_bench.sh` 以后台方式运行
- 结果（**通过**）：
  - `success_count`：64 / 64（100%）
  - `total_pages`：64
  - `total_time_sec`：391.03
  - `pages_per_sec`：0.164（单线程顺序处理；服务端批处理下吞吐量更高）
  - `BENCH_RC`：0
  - 运行时间窗口：`2026-04-21T23:40:55+00:00` → `2026-04-21T23:47:33+00:00`
- BF16 证据（来自 vLLM 日志）：
  - `dtype=torch.bfloat16`
  - `Using Triton Attention backend on V1 engine`（ROCm 路径）
  - `Application startup complete` 约于 23:34 UTC 确认
  - 模型权重加载：1.9727 GiB，用时 2.5 秒
- 吞吐量说明：0.164 pps 是单线程顺序处理的基线值。若使用 PaddleX HPS（Triton gRPC）服务端并发模式，吞吐量可显著提升。
- 总体结论：**PaddleOCR-VL-1.5 已在 AMD ROCm 硬件上以 BF16 推理方式完整运行，64 个 PDF 页全部处理成功，无任何错误。**
### 2026-04-20 - `30008` 恢复后执行“先就绪再集成”续跑，但控制面立即回退（中断）

- 验证目标：`http://36.151.243.69:30008/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal websocket
- 动作与观测：
	- 用户确认实例已启动后，`login/info/list-terminals` 首轮恢复成功（`version 2.17.0`，可见终端 `1`）
	- 在终端 `1` 启动“先就绪再跑集成”的续跑序列：
		- 先固定 resolver 到公共 DNS，并设置低超时与 `ndots:1`
		- 先校验模型源域名（`www.modelscope.cn`、`paddle-model-ecology.bj.bcebos.com`）
		- 先预检/启动 `paddlex_genai_server`，最长 `600s` 等待 `/v1/models`
		- 再执行 `verify_inference.sh --mode speed-vllm --device dcu`，并落盘日志/rc 制品
	- 长命令过程中命令流中断，返回 `Connection to remote host was lost`，未能在该次流中完整回收终态输出
	- 紧接着重试 `login`、`info`、`list-terminals`，均持续返回 `HTTP 503`
- 当前解释：
	- 本窗口归类为“执行中基础设施中断”，不计为验证通过或失败结论
	- 当前未出现与既有判别结论冲突的新证据；既有证据（`STATUS=READY`、`READY_AT_SEC=348`）仍支持“冷启动就绪预算不足”这一判断

### 2026-04-20 - `30008` 再次恢复后，“先就绪再集成”续跑已跨过就绪门限并进入 speed 压测（进行中）

- 验证目标：`http://36.151.243.69:30008/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal websocket
- 本轮执行方式：
	- 通过后台脚本 `/tmp/paddle_amd_speed_vllm_readyfirst.sh` 执行，降低 websocket 丢流对收敛判定的影响
	- 先把 resolver 固定到公共 DNS，并使用 `timeout:1 attempts:2 ndots:1`
	- 启动前先校验模型源域名解析（`www.modelscope.cn`、`paddle-model-ecology.bj.bcebos.com`）
	- 先执行最长 `600s` 的 vLLM 就绪门，再调用 `verify_inference.sh --mode speed-vllm --device dcu`
- 已捕获的实时证据：
	- 状态文件仍在运行：`/tmp/paddle_amd_speed_vllm_readyfirst.status` 为 `STATUS=RUNNING`
	- 后台脚本标记已出现就绪成功：`VLLM_READY_AT_SEC=358`
	- verify 日志已越过 preflight 与 server gate：
		- `[server] vLLM server already running at http://127.0.0.1:8118/v1`
		- speed benchmark 已进入 `/opt/paddlex/benchmarks/ocr-vlm-benchmark-f29cfe4/e2e`
	- vLLM server 日志显示正在稳定处理请求（`/v1/chat/completions` 返回 `200 OK`）
- 当前解释：
	- 本轮已在运行中跨过此前冷启动就绪瓶颈（约 358 秒就绪）
	- speed-vllm 的最终通过/失败与 rc 仍待当前压测结束后收敛
	- 在 `2026-04-20T07:45:21+00:00` 快照点，runner 仍为 `STATUS=RUNNING`，且 rc 尚未产出；后台脚本与 verify 进程均在运行
	- 随后执行长等待命令时再次丢流（`Connection to remote host was lost`），紧接着 API 重试回退为持续 `HTTP 503`
	- 因此本轮在最终 rc 回收前再次被基础设施中断

### 2026-04-17 - 切换到 `30008` 并在固定解析器后恢复 `speed-vllm` 续跑（进行中）

- 验证目标：`http://36.151.243.69:30008/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal websocket
- 恢复与终端状态：
	- 登录与 API info 探测成功（`version 2.17.0`）
	- 终端清点并在终端 `2` 上恢复稳定执行
	- 仍存在间歇性 stale-terminal websocket/命令流不稳，因此改为在同一新终端上拆分短命令执行
- 启动前解析器与主机校验：
	- `/etc/resolv.conf` 固定为：
		- `nameserver 223.5.5.5`
		- `nameserver 8.8.8.8`
		- `nameserver 1.1.1.1`
		- `options timeout:1 attempts:2 ndots:1`
	- 已验证以下主机可解析：
		- `www.modelscope.cn`
		- `paddle-model-ecology.bj.bcebos.com`
		- `git.aistudio.baidu.com`
		- `huggingface.co`
- 启动与当前运行状态：
	- 在移除会自杀的 kill 步骤后，已成功重新后台启动：
		- `timeout 2400s bash ./verify_inference.sh --mode speed-vllm --device dcu > /tmp/paddle_amd_speed_vllm.log 2>&1; echo $? > /tmp/paddle_amd_speed_vllm.rc`
	- 观测到活跃进程：
		- `timeout ... verify_inference.sh --mode speed-vllm --device dcu`
		- `paddlex_genai_server --model_name PaddleOCR-VL-1.5-0.9B --backend vllm --port 8118`
	- 当前状态仍为 `RC=PENDING`
	- runner 尾部仍停留在就绪等待：
		- `[server] Waiting for vLLM server at http://127.0.0.1:8118/v1 (up to 180s)...`
	- server 尾部当前显示官方模型准备启动信息；在本次 `30008` 续跑窗口中暂未出现新的即时 `NameResolutionError`
- 当前解释：
	- 已在 `30008` 上以“解析器已校验”状态恢复续跑
	- 后续轮询已在 runner 日志捕获终态汇总：
		- `Speed benchmark: failed-server`
		- `Overall: FAIL`
	- 就绪门限在 `180s` 处失败（`[server] ERROR: vLLM server did not become ready within 180s`）；同一窗口中也出现了模型下载/处理与 API server 启动日志
	- 汇总抓取后的进程终态：未见存活的 `verify_inference.sh --mode speed-vllm` 或 `paddlex_genai_server` 工作进程
	- 标记细节仍存在：最终抓取时 `/tmp/paddle_amd_speed_vllm.rc` 仍缺失，因此本轮完成性以“明确汇总 + 进程退出证据”判定
	- 在紧接着执行独立诊断复验时，端点可用性再次回退（`jupyter_remote.py login/info/list-terminals` 返回 `HTTP 503`，直接 API 探测超时），因此当前无法在实例内继续完成细分诊断
	- 在 2026-04-19 续跑中，已在 `30008` 先完成 DNS 固定与主机解析校验后启动“直接 vLLM 600s 就绪判别”命令，但命令 websocket 在运行中断开，随后端点立刻回退为 `HTTP 503` + API 超时；该判别运行结果在本次中断窗口内无法回收
	- 在下一次 `30008` 恢复后，改为“后台脚本 + 结果文件”方式重跑直接判别，并拿到终态：
		- `/tmp/paddle_amd_vllm_direct.status`：`STATUS=READY`
		- `/tmp/paddle_amd_vllm_direct.ready`：`READY_AT_SEC=348`
		- 直接 server 日志出现 `Application startup complete`，并对 `GET /v1/models` 返回 `200 OK`
	- 判别结论：
		- vLLM 后端在该实例上可以启动到健康态
		- `verify_inference.sh` 中的 `failed-server` 主要符合“固定 180s 就绪窗口小于真实冷启动耗时（本次约 348s）”这一原因

### 2026-04-16 - `30002` 上 `speed-vllm` 在解析器回退后的续跑（进行中）

- 验证目标：`http://36.151.243.69:30002/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal websocket（使用终端 `1` 与 `4` 进行重启与轮询）
- 背景与动作：
	- 从进行中的 `speed-vllm` 续跑时发现 `/etc/resolv.conf` 已回退到集群默认（`nameserver 10.232.0.10`、`ndots:5`），模型源主机不可解析
	- 内联强制改写 resolver 为 `223.5.5.5`、`8.8.8.8`、`1.1.1.1`，并设置 `options timeout:1 attempts:2 ndots:1`
	- 已验证以下主机恢复解析：
		- `www.modelscope.cn`
		- `paddle-model-ecology.bj.bcebos.com`
		- `git.aistudio.baidu.com`
		- `huggingface.co`
	- 已用新日志与 rc 标记重启后台压测：
		- `timeout 2400s bash /opt/PaddleX/verify_inference.sh --mode speed-vllm --device dcu > /tmp/paddle_amd_speed_vllm.log 2>&1; echo $? > /tmp/paddle_amd_speed_vllm.rc`
- 最新轮询状态：
	- `SPEED_VLLM_DONE=PENDING`（`/tmp/paddle_amd_speed_vllm.rc` 尚未写出）
	- 活跃进程包含：
		- `timeout ... verify_inference.sh --mode speed-vllm --device dcu`
		- `paddlex_genai_server --model_name PaddleOCR-VL-1.5-0.9B --backend vllm --port 8118`
	- runner 日志停留在服务就绪等待行：
		- `[server] Waiting for vLLM server at http://127.0.0.1:8118/v1 (up to 180s)...`
	- server 日志当前显示启动和官方模型下载路径提示；在本轮续跑窗口内未再看到此前 ModelScope/BOS 的 `NameResolutionError`
- 当前解释：
	- 本轮续跑中的 DNS/模型源解析阻塞已被缓解
	- `speed-vllm` 最终通过/失败结果仍待完成；当前证据更接近“冷启动/模型准备耗时偏长”，而不是“立即 DNS 失败”
	- 随后控制面在终端 `2` 的命令流以 `Connection to remote host was lost` 结束，后续 API 复检返回 `HTTP 503` / 超时；因此本轮暂归类为“端点可用性中断”，而不是“测试已出最终结论”
	- 在短暂恢复窗口中创建新终端并继续探测后，端点可用性再次回退（`jupyter_remote.py login/info/list-terminals` 返回 `HTTP 503`，直接 API 探测超时），本窗口仍无法收敛 speed 最终结果

### 2026-04-15 - 在 `30002` 上执行 PaddleOCR-VL quick 集成验证（失败，随后实例下线）

- 验证目标：`http://36.151.243.69:30002/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal websocket
- 使用的运行时准备：
	- 通过 `bash scripts/remote_fix_instance_dns.sh 2` 应用 DNS 修复
	- 启用兼容运行时路径：`LD_LIBRARY_PATH=/opt/PaddleX/rocm64-compat:$LD_LIBRARY_PATH`
	- 集成命令：`bash /opt/PaddleX/verify_inference.sh --mode quick --device gpu`
- 观测到的集成行为：
	- preflight 通过：Paddle ROCm 编译状态为 `True`，`PaddleOCRVL` 导入 `OK`
	- quick 原生推理阶段出现进程段错误
	- C++ 回溯终止在 GPU 元素加法广播路径：
		- `phi::AddRawKernel<float, phi::GPUContext>`
		- `phi::funcs::BroadcastKernel...`
	- quick vLLM 阶段随后进入 server 启动/等待流程，但由于 native 失败，本轮不判定为成功
	- 日志总结为 `Overall: FAIL`
- 后续尝试：
	- 已启动一次按脚本默认设备别名（`--device dcu`）的定向复验，用于排除 device 参数别名因素
	- 复验过程中 websocket 传输中断，随后实例不可用（API 探测超时，登录返回 `HTTP 503`）
	- 实例恢复后，已在 terminal `1` 上以“后台执行 + 日志轮询”方式重新执行 `--device dcu` quick 复验
	- quick native 阶段仍在同一路径段错误（广播加法内 `phi::AddRawKernel<float, phi::GPUContext>`），说明该失败并非 `--device gpu` 别名特有
	- 本次复验中，`git.aistudio.baidu.com` 初始解析失败；通过内联修复 resolver（`223.5.5.5`、`8.8.8.8`、`1.1.1.1`、`ndots:1`）后恢复主机解析，并可继续走 ModelScope 回退下载
	- `PP-DocLayoutV3` 已成功从 ModelScope 下载完成，随后仍在 native 推理阶段段错误
	- 运行随后进入 quick vLLM 阶段并启动 `paddlex_genai_server`，但服务就绪等待超时（`180s`），quick vLLM 结果为 `FAILED (server did not start)`
	- quick 汇总已输出到终端：
		- `Native precision: failed`
		- `vLLM precision: failed-server`
		- `Overall: FAIL`
	- 说明：即使汇总已输出且相关进程已退出，`/tmp/paddle_amd_quick_dcu.done` 仍未写出，判断为包装脚本标记行为问题，而非 quick 仍在运行
	- 补充独立 native 复现（不经过 `verify_inference.sh`）：
		- 命令形态：`/opt/venv/bin/python -c "... PaddleOCRVL(device='dcu').predict('/opt/PaddleX/test/paddleocr_vl_demo.png') ..."`
		- 结果：复现同一路径 GPU 段错误（`phi::AddRawKernel<float, phi::GPUContext>` 广播加法路径）
		- 本次重启实例上的运行时快照为 `paddle_version 3.4.0.dev20260404`，`compiled_with_rocm True`
	- 补充独立 vLLM 启动复现（不经过 `verify_inference.sh`）：
		- 命令形态：`paddlex_genai_server --model_name PaddleOCR-VL-1.5-0.9B --backend vllm --port 8118`
		- 观测到冷启动长路径（模型加载、torch.compile、图捕获）后，API 服务达到 `Application startup complete`
		- 解释：此前 quick 模式的 `failed-server` 更可能是冷启动下就绪窗口不足导致，而非必现的即时启动崩溃
- 结论：
	- 当前 wheel/运行时配置下，算子级 BF16 验证仍然通过，但该实例上的 quick PaddleOCR-VL 集成验证尚未通过（native 路径段错误）
	- `dcu` 参数复验已确认与 `gpu` 相同的 native 崩溃签名，可排除 device 参数别名作为主因
	- 同一轮复验也确认 quick vLLM 路径当前未通过（`failed-server`）
	- 独立 vLLM 启动证据显示另有“启动/就绪时间预算”问题，但 native 段错误仍是当前主阻塞

### 2026-04-15 - 在重启后的 `30002` 上完成 BF16 算子级验证成功

- 验证目标：`http://36.151.243.69:30002/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal `1` websocket 命令执行
- 运行时准备：
	- 重启后重新执行 `bash scripts/remote_fix_instance_dns.sh 1`
	- 确认 `libopenblas0-pthread` 已安装
	- 重新上传并强制重装 `paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
	- 应用兼容软链接 `ln -sfn /opt/rocm/lib/libamdhip64.so.7 /opt/PaddleX/rocm64-compat/libamdhip64.so.6`
	- 使用 `LD_LIBRARY_PATH=/opt/PaddleX/rocm64-compat:$LD_LIBRARY_PATH`
- 精确探测用例：
	- 导入与能力查询
	- float32 `ones`
	- float32 `randn`
	- BF16 `randn`
	- float32 到 BF16 `astype`
	- BF16 `matmul`
- 已验证结果（所有用例 `RC=0`）：
	- `version`: `3.4.0.dev20260408`
	- `commit`: `5ea0c3dddf415a7885560c6916e13491d6f597c6`
	- `compiled_with_rocm`: `true`
	- `compiled_with_cuda`: `true`
	- `bf16_dev`: `true`
	- `bf16_cuda`: `true`
	- BF16 `randn` 成功，dtype 为 `paddle.bfloat16`
	- float32 到 BF16 `astype` 成功
	- BF16 `matmul` 成功，dtype 为 `paddle.bfloat16`，结果为 `[[7.0, 10.0], [15.0, 22.0]]`
- 结论：
	- 在先执行 DNS 修复与运行时兼容配置后，重启后的 `30002` 上已跑通该本地 wheel 的 BF16 算子级运行时验证

### 2026-04-15 - 在重启后的 `30002` 上重新部署并完成 GPU 冒烟成功验证

- 验证目标：`http://36.151.243.69:30002/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal `1` websocket 命令执行
- 被测 wheel：
	- `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local/python/dist/paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- 精确验证流程：
	- `bash scripts/remote_fix_instance_dns.sh 1`
	- `python3 scripts/jupyter_remote.py upload ... paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
	- 在 `/opt/venv` 中卸载旧包并强制重装 wheel
	- 重建兼容软链接 `ln -sfn /opt/rocm/lib/libamdhip64.so.7 /opt/PaddleX/rocm64-compat/libamdhip64.so.6`
	- 在 `LD_LIBRARY_PATH=/opt/PaddleX/rocm64-compat:$LD_LIBRARY_PATH` 下执行 GPU 冒烟脚本
- 已验证结果：
	- DNS 故障在实例重启后确实复发，重新执行 DNS 修复脚本后再次恢复到 apt 可用状态
	- wheel 重新上传成功，远程文件大小为 `253496058`
	- wheel 重装成功，`/opt/venv` 中生效版本为 `paddlepaddle-dcu 3.4.0.dev20260408`
	- 冒烟输出：
		- `commit`: `5ea0c3dddf415a7885560c6916e13491d6f597c6`
		- `compiled_with_rocm`: `true`
		- `compiled_with_cuda`: `true`
		- `device`: `gpu:0`
		- `matmul_dtype`: `paddle.float32`
		- `matmul_value`: `[[7.0, 10.0], [15.0, 22.0]]`
		- `version`: `3.4.0.dev20260408`
- 结论：
	- 在先执行 DNS 修复与兼容运行时配置的前提下，“本地改动 -> 远程部署/测试”路径已在重启后的 `30002` 上跑通
	- 本轮已形成该 wheel 的远程 GPU 冒烟成功检查点

### 2026-04-15 - 新 `30002` 实例上的远程 DNS 解阻验证

- 验证目标：`http://36.151.243.69:30002/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API + terminal `1` 的 websocket 命令执行
- 远程环境：
	- Python：`/opt/venv/bin/python` `3.12.3`
	- 初始解析器状态：`nameserver 10.232.0.10`，`search default.svc.amd.gpu.dc ...`，`ndots:5`
- 精确验证流程：
	- `python3 scripts/jupyter_remote.py login --url http://36.151.243.69:30002/instance/nb-1838d2b6 --token amd-oneclick`
	- `python3 scripts/jupyter_remote.py exec --terminal 1 --command 'pwd && whoami && /opt/venv/bin/python --version'`
	- 通过 `getent` 与 `apt-get update` 执行限时 DNS/apt 探测
	- 试验“内部 DNS + 公共 DNS + ndots:1”混合解析配置
	- 在混合解析后重新验证 `apt-get update`
	- 执行 `apt-cache search '^libopenblas0'` 与 `apt-get install -y libopenblas0-pthread`
	- 在 helper 更新后重新执行 `bash scripts/remote_fix_instance_dns.sh 1`
- 已验证结果：
	- 默认解析器无法解析所需公共主机，apt update 因解析失败不可用
	- 混合解析状态可解析 Ubuntu/security/PPA/GitHub 主机，并使 apt 索引刷新恢复可用
	- `apt-get update` 返回退出码 `0`，Ubuntu/PPA 索引拉取成功，仅 `compute-artifactory.amd.com` 仍不可解析
	- 已从 Ubuntu 仓库成功安装 `libopenblas0-pthread`，证明工作流所需的系统包操作已解除 DNS 阻塞
	- 更新后的 DNS helper 在该实例上可成功执行，并能在默认路径下保持 apt 可用
- 结论：
	- 当前实例上，“本地改动后远程 sync/build/deploy/test”路径的实际 DNS 阻塞已解除
	- 私有 AMD artifactory 域名仍不可解析，但已改为“按需严格检查”的可选条件，而非默认硬门槛

### 2026-04-14 - 重启后的 `30006` 远程安装重试与运行时依赖排查

- 验证目标：重启后的 AMD 集群 Jupyter 实例 `http://36.151.243.69:30006/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API，以及在远程终端 `1` 上恢复可用的 terminal websocket 命令执行
- 远程环境：
	- OS 系列：根据当前 apt 源推断为 Ubuntu 24.04 镜像线
	- Python：`/opt/venv/bin/python` `3.12.3`
	- ROCm 运行时线：`/opt/rocm` 指向 ROCm `7.2.x` 镜像，存在 `libamdhip64.so.7`，不存在 `libamdhip64.so.6`
- 被测 wheel：
	- `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local/python/dist/paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- 精确远程验证流程：
	- `python3 scripts/jupyter_remote.py login --url http://36.151.243.69:30006/instance/nb-1838d2b6 --token amd-oneclick`
	- `python3 scripts/jupyter_remote.py list-terminals`
	- `python3 scripts/jupyter_remote.py exec --terminal 1 --command 'pwd && whoami && /opt/venv/bin/python --version'`
	- `python3 scripts/jupyter_remote.py upload ... paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
	- `scripts/install_remote_wheel.sh 1 paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
	- 通过 `scripts/jupyter_remote.py exec` 继续执行远程 `ldd`、`ldconfig -p`、`find` 与 `apt-get update` 探测
- 已验证结果：
	- 重启后的实例已恢复 terminal websocket 命令执行能力
	- 远程 wheel 重装成功，已将预装的 `paddlepaddle-dcu 3.4.0.dev20260404` 替换为 `3.4.0.dev20260408`
	- 初始导入失败为 `ImportError: libamdhip64.so.6: cannot open shared object file: No such file or directory`
	- 远程运行时提供的是 `libamdhip64.so.7`，而不是 `libamdhip64.so.6`
	- 添加 `/opt/PaddleX/rocm64-compat/libamdhip64.so.6 -> /opt/rocm/lib/libamdhip64.so.7` 后，`ldd` 已能解析第一处缺失依赖
	- 在该兼容软链接生效后，导入失败继续前移为 `ImportError: libopenblas.so.0: cannot open shared object file: No such file or directory`
	- 在 `/opt`、`/usr` 与 `/lib` 下都未找到 `libopenblas.so.0`
	- 在刷新索引前，`apt-cache` 无法定位 OpenBLAS 包；而 `apt-get update` 又因无法解析 `archive.ubuntu.com`、`security.ubuntu.com`、`ppa.launchpadcontent.net` 与 `compute-artifactory.amd.com` 而失败
- 结论：
	- 重启后的 `30006` 实例已经不再受 terminal 传输层阻塞
	- 当前基于 ROCm 6.4.2 构建的本地 wheel 不能直接在这个 ROCm 7.2 远程镜像上运行，至少需要兼容层处理
	- 即使绕过了 HIP SONAME 错配，该镜像仍缺少基础 OpenBLAS 运行时，而且由于外部 DNS 解析失败，当前也无法通过 apt 自修复
	- 因此，这个实例目前仍不能作为该 wheel 的有效验收目标

### 2026-04-14 - 本地一次性 wheel 冒烟验证与 live `30006` 制品落盘

- 验证目标：本地 wheel 制品，以及 AMD 集群 live Jupyter 实例 `http://36.151.243.69:30006/instance/nb-1838d2b6/lab`
- 访问方式：
	- 本地 shell 用于一次性 wheel 冒烟验证
	- 认证后的 Jupyter API 用于远程登录、创建终端与上传文件
- 本地环境：
	- 操作系统：WSL2 下的 Ubuntu 24.04.3
	- Python：系统 `python3` `3.12.3`，用于创建临时冒烟虚拟环境
	- ROCm：`6.4.2`
- 被测 wheel：
	- `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local/python/dist/paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- 精确本地冒烟步骤：
	- 创建临时虚拟环境 `/home/oldzhu/paddle-amd/.venv-wheel-smoke`
	- `python -m pip install paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
	- `python -c 'import paddle; ...'`
	- 删除 `/home/oldzhu/paddle-amd/.venv-wheel-smoke`
- 已验证的本地结果：
	- `import paddle` 成功
	- `paddle.__version__` 报告为 `3.4.0.dev20260408`
	- `paddle.is_compiled_with_rocm()` 报告为 `True`
	- `paddle.is_compiled_with_cuda()` 报告为 `True`
	- 临时冒烟虚拟环境已在验证后删除
	- 导入过程中出现“本地无可用 GPU”的运行时 warning；这与当前 WSL 主机缺少运行时 GPU 一致，不影响该 wheel 的导入级冒烟结论
- 精确远程落盘命令：
	- `python3 scripts/jupyter_remote.py login --url http://36.151.243.69:30006/instance/nb-1838d2b6 --token amd-oneclick`
	- `python3 scripts/jupyter_remote.py create-terminal --name paddle-amd-bf16`
	- `python3 scripts/jupyter_remote.py upload ... paddlepaddle_dcu-3.4.0.dev20260408-cp312-cp312-linux_x86_64.whl`
- 已验证的远程结果：
	- 已成功对该实例级基地址完成认证 API 访问
	- 已通过 `/api/terminals` 成功创建远程终端 `paddle-amd-bf16`
	- 首次上传到 `uploaded-wheels/...` 失败，原因是 live Jupyter contents 根目录下不存在该目录
	- 同一 wheel 改为上传到工作区根目录后成功，远程返回的文件大小为 `253496058`
- 当前远程阻塞：
	- 在该 live 实例上仍无法恢复 terminal 命令执行
	- 对 `/instance/nb-1838d2b6/terminals/websocket/paddle-amd-bf16` 的 websocket 握手返回了 HTTP `200` 与 HTML terminal 页面，而不是协议升级
	- 因此，远程 wheel 安装与 GPU 冒烟执行目前仍待完成
- 结论：
	- 当前本地构建 wheel 已通过一次性导入冒烟验证，且没有留下持久化本地安装
	- wheel 制品已经成功放到 live `30006` 实例上
	- 当前剩余阻塞是该 notebook 栈上的远程 terminal 执行能力，而不是 wheel 构建或制品传输

### 2026-04-13 - 本地针对 ROCm dynload 链接修复的精确定向验证

- 验证目标：本地 WSL ROCm 构建树 `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local`
- 访问方式：本地 shell 构建验证
- 操作系统：WSL2 下的 Ubuntu 24.04.3
- Python：`/home/oldzhu/paddle-amd/.venv-rocm-build` 中的 `3.12.3`
- ROCm：`6.4.2`
- Paddle commit：`5ea0c3dddf4`
- 精确验证命令：
	- `cmake --build . --target eager_generator -j1`
- 已验证结果：
	- 此前 `phi::dynload::hipMemCreate` 与 `phi::dynload::hipMemRelease` 的未定义链接符号错误未再复现
	- 该精确定向重编译已成功完成
	- 重编译后 `build-rocm-local/paddle/fluid/pybind/eager_generator` 已重新存在
	- 在完成该精确定向验证后，已从同一构建树恢复完整串行 `cmake --build . --target paddle_copy -j1`
- 结论：
	- `eager_generator` 的后期停止点根因是 ROCm dynload wrapper 实例化缺失，当前定向修复已在本地验证通过
	- 完整本地串行构建已被解除阻塞，并能够越过此前的 `eager_generator` 失败点继续推进

### 2026-04-09 - 远程 Jupyter 环境检查

- 验证目标：AMD 集群 Jupyter 实例 `http://36.151.243.69:30005/lab`
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`1`
- 命令脚本路径：上传后的 `/app/paddle_amd_remote_env_check.sh`
- 执行命令：`python3 scripts/jupyter_remote.py exec --terminal 1 --command "bash /app/paddle_amd_remote_env_check.sh"`
- 操作系统：Ubuntu 22.04.5 LTS
- Python：`/opt/venv/bin/python`，版本 `3.10.12`
- pip：`/opt/venv/bin/pip`，版本 `26.0.1`
- ROCm 证据：
	- 存在 `/opt/rocm` 与 `/opt/rocm-7.2.1`
	- `rocminfo` 执行成功
	- 检测到 GPU agent 为 `gfx1100`
	- `rocm-smi` 执行成功
	- `hipcc` 位于 `/opt/rocm/bin/hipcc`
	- HIP 版本报告为 `7.2.1`
- Paddle 证据：
	- `import paddle` 失败，报错为 `ModuleNotFoundError: No module named 'paddle'`
	- `pip list` 未显示当前环境已安装 Paddle 包
- 初步结论：
	- 该远程实例适合作为基于 ROCm 的验证环境。
	- 在开始框架级复现之前，需要先在远程环境中安装或编译 Paddle。

### 2026-04-09 - 远程按实例 bootstrap 验证

- 验证目标：同一 AMD 集群 Jupyter 实例
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`2`
- 准备脚本：`scripts/remote_prepare_instance.sh 2 /app/paddle-amd-remote`
- 已验证结果：
	- 控制平面仓库已 clone 到 `/app/paddle-amd-remote`
	- Paddle 已 clone 到 `/app/paddle-amd-remote/paddlerepos/Paddle`
	- PaddleX 已 clone 到 `/app/paddle-amd-remote/paddlerepos/PaddleX`
	- 远程控制平面 commit：`7d037f0`
	- 远程 Paddle commit：`5ae373f`
	- 远程 PaddleX commit：`c18f2b0`
	- 环境采集结果已保存到 `/app/paddle-amd-remote/evidence/env/`
- 剩余阻塞：
	- `/opt/venv/bin/python` 中仍无法导入 Paddle
- 结论：
	- 可复用的按实例准备流程已经跑通。
	- 下一步远程环境任务是为当前 Python 环境安装或编译 Paddle。

### 2026-04-09 - 远程 pip Paddle 安装探测

- 验证目标：同一 AMD 集群 Jupyter 实例
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`3`
- 命令路径：`scripts/remote_ensure_paddle.sh 3 paddlepaddle==3.3.1`
- 已验证结果：
	- `paddlepaddle-3.3.1` 已成功安装到 `/opt/venv`
	- `paddle.__version__` 报告为 `3.3.1`
	- `paddle.is_compiled_with_rocm()` 报告为 `False`
	- `paddle.is_compiled_with_cuda()` 报告为 `False`
- 结论：
	- 通用 pip wheel 路径在当前远程环境中不能提供 ROCm 版 Paddle。
	- 下一步远程工作必须转向源码构建探测，而不能停留在 wheel 安装结果上。

### 2026-04-09 - 远程 Paddle ROCm 源码 configure 探测

- 验证目标：同一 AMD 集群 Jupyter 实例
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`3`
- 命令路径：`bash scripts/remote_build_paddle_rocm.sh 3 /app/paddle-amd-remote configure`
- 已验证结果：
	- 远程脚本检测到 GPU 架构为 `gfx1100`
	- Paddle 仓库 `cmake/hip.cmake` 中当前显式 ROCm target 列表不包含 `gfx1100`，已按“假设而非结论”记录
	- CMake 期望在 `/opt/rocm/hip/include/hip/hip_version.h` 找到 HIP 版本头文件，但真实文件位于 `/opt/rocm/include/hip/hip_version.h`
	- CMake 期望在 `/opt/rocm-7.2.1/include/rccl.h` 找到 RCCL 头文件，但真实文件位于 `/opt/rocm-7.2.1/include/rccl/rccl.h`
	- 由于部分 GitHub 抓取超时或出现 HTTP/2 framing error，Paddle 子模块补齐不完整，`third_party/glog` 和 `third_party/cccl` 等目录保持空目录状态
	- configure 步骤以退出码 `1` 结束
- 结论：
	- 远程源码构建路径已经复现到足以暴露具体阻塞点。
	- 下一步工作应先修正或绕过 ROCm 头文件路径假设，并提升子模块抓取稳健性，再重试构建。

### 2026-04-09 - 在实例侧修复后再次执行远程源码 configure

- 验证目标：同一 AMD 集群 Jupyter 实例
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`4`
- 命令路径：`bash scripts/remote_build_paddle_rocm.sh 4 /app/paddle-amd-remote configure`
- 已验证结果：
	- 脚本已为 `/opt/rocm/hip/include/hip/hip_version.h` 与 `/opt/rocm-7.2.1/include/rccl.h` 创建兼容软链接
	- 脚本已通过 HTTP/1.1 加重试机制补齐此前缺失的 `third_party/glog`、`third_party/cccl` 与 `third_party/flagcx/third-party/googletest` 等子模块
	- 本次运行已越过此前的 HIP 头文件与 RCCL 头文件路径失败点
	- 本次运行已越过此前的空子模块失败点
	- configure 最终推进到 `cmake/generic.cmake` 调用 `hip_add_library` 时失败，错误为 `Unknown CMake command "hip_add_library"`
- 结论：
	- 这次在当前远程实例上执行的两个实例侧解阻动作已经生效。
	- 下一步阻塞是 HIP CMake 兼容性问题；较大概率是 Paddle 依赖 legacy FindHIP 宏，而当前环境并未以相同方式提供这些宏。

### 2026-04-09 - 远程 HIP 模块路径检查与 backend 切换后的阻塞

- 验证目标：同一服务 URL 下后续切换出的 Jupyter backend
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 已验证结果：
	- 当前 ROCm 镜像在 `/opt/rocm-7.2.1/lib/cmake/hip/FindHIP.cmake` 提供了 `FindHIP.cmake`
	- Paddle 现有脚本使用的旧路径 `/opt/rocm/hip/cmake` 在这个 backend 上并不提供 `FindHIP.cmake`
	- 在 fresh backend 上，最小化恢复 Paddle clone 已经成功
	- 但 backend 切换后，terminal websocket 在多个终端上都开始超时，导致后台 configure 启动链路还无法完成端到端验证
- 当前阻塞：
	- 新 backend 上的远程命令传输稳定性不足，长时终端驱动验证目前不可靠
- 建议下一步：
	- 在稳定或新恢复的实例上继续，并在 websocket 退化之前优先使用后台 configure 启动脚本

### 2026-04-09 - 在 fresh `30005` backend 上修复并重试后台 configure 启动脚本

- 验证目标：`http://36.151.243.69:30005/lab` 对应的 Jupyter backend
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`3`
- 命令路径：`./scripts/remote_launch_paddle_rocm_configure.sh 3 /app/paddle-amd-remote`
- 已验证结果：
	- 已确认后台启动脚本本身存在嵌套 heredoc 变量提前展开问题，并已在本地修复后重试
	- 重试后成功启动远程后台任务 `549`
	- 脚本已在 fresh backend 上成功生成 `/app/paddle-amd-remote/evidence/remote-build/paddle_rocm_configure_bg.sh`
	- 日志轮询显示子模块初始化正在推进，未再出现后台启动脚本自身的 shell 级失败
	- 最新轮询时，递归缺失子模块数量已从 `31` 下降到 `24`
	- `paddle_rocm_configure.log` 在最新轮询时仍为空，说明 CMake configure 还未开始
- 结论：
	- 后台 configure 路径现在已经能在 fresh backend 上稳定启动
	- 当前剩余阻塞仍然是远程子模块补齐的速度与稳定性，而不是后台启动脚本自身

### 2026-04-10 - 安装 `patchelf` 并再次执行后台 configure

- 验证目标：`http://36.151.243.69:30005/lab` 对应的 Jupyter backend
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`3`、`6`
- 命令路径：
	- `python3 scripts/jupyter_remote.py exec --terminal 6 --command 'apt-get update && apt-get install -y patchelf ...'`
	- `./scripts/remote_launch_paddle_rocm_configure.sh 6 /app/paddle-amd-remote`
- 已验证结果：
	- 较早启动的后台任务最终在 fresh backend 上完成了递归子模块补齐
	- 下一条明确的 configure 阻塞为 `patchelf not found, please install it`
	- 已成功安装 `patchelf 0.14.3`，路径为 `/usr/bin/patchelf`
	- 重新后台启动后，新任务号为 `8824`
	- 最新轮询显示 `missing_count` 已为 `0`，并且日志记录了 `all submodules initialized after pass 1`
	- 最新 configure 日志已越过此前的 `patchelf` 失败点，并在最后一次轮询时仍持续输出 CMake 与代码生成日志
- 当前状态：
	- 安装 `patchelf` 后，尚未确认新的硬性 configure 阻塞
	- 后台 configure 在最后一次轮询时仍在进行中

### 2026-04-10 - configure 就绪后的首个定向 `paddle_python` 构建重试

- 验证目标：`http://36.151.243.69:30005/lab`
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`7`、`8`
- 构建树证据：
	- `/app/paddle-amd-remote/paddlerepos/Paddle/build-rocm/CMakeCache.txt` 已存在
	- `/app/paddle-amd-remote/paddlerepos/Paddle/build-rocm/build.ninja` 已存在
- 定向命令路径：
	- `cmake --build . --target paddle_python -j4`
	- 远程日志：`/app/paddle-amd-remote/evidence/remote-build/paddle_rocm_target_build_retry.log`
- 已验证结果：
	- 第一次重试确认远程实例上的 `third_party/warprnnt` 实际并未完整 checkout，尽管此前的子模块检查没有把它标记出来
	- `third_party/warprnnt` 初始状态只有 `.git` 文件，没有源码内容
	- 在手动执行 `git submodule update --init --recursive third_party/warprnnt` 之后，新的定向构建已越过此前的 `extern_warprnnt` patch 失败点
	- 下一条明确失败已经前移到 `extern_warpctc` configure
	- WarpCTC 的 configure 日志表明 ROCm 探测本身成功，但外部子构建内部 `HIP_ADD_LIBRARY` 未定义
	- 该外部 configure 缺陷的直接原因是 WarpCTC 外部构建没有继承顶层 `CMAKE_MODULE_PATH`
- 当前阻塞：
	- 首个定向 ROCm build/test 步骤仍未完成，因为构建在生成可用 Python 运行时之前就停在外部 WarpCTC configure
	- live Jupyter websocket 在后续重试阶段再次变得不稳定，因此实验性的 WarpCTC 修复尚未在远程实例上完成端到端复验

### 2026-04-10 - `30008` 预装 Paddle ROCm 实例验证

- 验证目标：`http://36.151.243.69:30008/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`1`
- 验证命令路径：
	- `python3 scripts/jupyter_remote.py login --url http://36.151.243.69:30008/instance/nb-1838d2b6 --token amd-oneclick`
	- `python3 scripts/jupyter_remote.py exec --terminal 1 --timeout 120 --command '...python BF16 support probe...'`
- 已验证结果：
	- 新实例 API 可正常响应，并已使用 `amd-oneclick` 成功认证
	- 活动 shell 初始落点在 `/workspace/PaddleX`，这说明该镜像已经为 Paddle 相关工作做了预装准备
	- 实例上存在 `rocminfo`
	- `hipcc` 位于 `/opt/rocm/bin/hipcc`
	- 当前 Python 环境为 `/opt/venv/bin/python`，版本 `3.12.3`
	- Paddle 可从预装环境中成功导入
	- `paddle.__version__` 报告为 `3.4.0.dev20260404`
	- `paddle.is_compiled_with_rocm()` 报告为 `True`
	- `paddle.is_compiled_with_cuda()` 报告为 `True`
	- `paddle.device.get_device()` 报告为 `gpu:0`
	- `paddle.device.is_bf16_supported()` 报告为 `True`
	- `paddle.cuda.is_bf16_supported()` 报告为 `True`
- 补充说明：
	- 随后尝试执行一个最小 BF16 GPU matmul，但 terminal websocket 在实时执行阶段断开
	- 该现象被观察为命令传输层问题，而不是该实例上已确认的 BF16 运行时失败
- 结论：
	- 与之前的临时容器相比，这个新的 `30008` 实例明显更适合作为后续验证环境，因为它已经提供了可用的 ROCm Paddle 构建，并且 BF16 支持 API 已报告 ready
	- 后续 BF16 运行时验证应继续基于该实例展开，并优先采用短命令或后台执行方式，以减少 websocket 不稳定带来的假阴性

### 2026-04-10 - 在 `30008` 上确认 BF16 Gaussian 随机生成功能存在运行时崩溃

- 验证目标：`http://36.151.243.69:30008/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter 终端执行，加上用户从同一 live 实例提供的运行时输出
- 复现命令形态：
	- `paddle.set_device("gpu")`
	- `a = paddle.randn([4, 4], dtype="bfloat16")`
	- `b = paddle.randn([4, 4], dtype="bfloat16")`
	- `c = paddle.matmul(a, b)`
- 已验证结果：
	- 故障发生在 matmul 返回之前，具体是在 `paddle.randn` 创建 BF16 Tensor 的阶段
	- 运行时打印了 device `0` 的 GPU 信息，runtime 和 driver 版本均为 `70226.1`
	- 进程以 `FatalError: Segmentation fault` 终止
	- C++ traceback 包含：
		- `paddle::experimental::gaussian(...)`
		- `phi::GaussianKernel<phi::dtype::bfloat16, phi::GPUContext>`
		- `phi::funcs::distribution_and_transform<phi::dtype::bfloat16, ...>`
	- 这说明尽管 BF16 capability API 返回 `True`，BF16 Gaussian 随机数的 GPU 路径仍然存在真实运行时缺陷
- 源码对应：
	- `paddlerepos/Paddle/paddle/phi/kernels/gpu/gaussian_kernel.cu` 为 `gaussian` 注册了 GPU BF16 kernel
	- 该文件中，非复数 dtype 的 `seed == 0` 分支会调用 `funcs::distribution_and_transform<T>(dev_ctx, out, dist, trans)`
- 结论：
	- 当前实例上的活跃阻塞并不是“完全不支持 BF16”，而是 GPU 后端上的 BF16 Gaussian 随机生成路径存在确定性的运行时崩溃
	- 对本任务而言，仅靠 BF16 支持 API 不能作为最终验收证据

### 2026-04-13 - 本地 ROCm 对 HIP top-k 与 DLPack printer 修复的精确定向验证

- 验证目标：本地 WSL 构建主机 `/home/oldzhu/paddle-amd/paddlerepos/Paddle/build-rocm-local`
- 访问方式：先对精确失败对象做本地串行重编译验证，再恢复顶层构建
- 环境：
	- 操作系统：WSL2 上的 Ubuntu 24.04.3
	- Python：`3.12.3`
	- ROCm：`6.4.2`
	- Paddle commit：`5ea0c3dddf415a7885560c6916e13491d6f597c6`
- 精确验证命令：
	- `cmake --build . --target paddle/phi/CMakeFiles/phi_gpu.dir/kernels/gpu/phi_gpu_generated_top_k_kernel.cu.o -j1`
	- `cmake --build . --target paddle/fluid/platform/CMakeFiles/densetensor_printer.dir/densetensor_printer.cc.o -j1`
	- 恢复顶层构建：`cmake --build . --target paddle_copy -j1`
- 已验证结果：
	- 在应用 wave64 感知分派修复并移除 HIP 32 线程特化后，HIP top-k 对象已可干净重编译
	- DLPack printer 对象在仅完成 CMake 依赖连线后仍然失败，这说明问题并不只是 target 传播
	- 已确认 checkout 出来的 `third_party/dlpack` 工作树缺失 `include/dlpack/dlpack.h`，尽管子模块仓库元数据本身存在
	- 在恢复受跟踪头文件，并保留 `dlpack` interface include 导出和直接 target 依赖后，`densetensor_printer.cc.o` 已可干净重编译
	- 恢复后的串行 `paddle_copy` 构建已继续推进到更后面的 framework 与 IR 目标；最新观测点已进入 `140+ / 1141` 区间，且尚未出现新的硬性阻塞
- 结论：
	- 这两个新识别出的阻塞都已经在精确失败目标层面修复并验证成功，然后才恢复顶层构建
	- 当前仍未产出 wheel，因此这一轮只属于构建推进证据，还不是最终验收验证

### 2026-04-10 - 预装实例 `30006` 连最小 GPU Tensor 创建也会失败

- 验证目标：`http://36.151.243.69:30006/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`1`、`7`、`8`、`9`
- 验证命令路径：
	- `python3 scripts/jupyter_remote.py login --url http://36.151.243.69:30006/instance/nb-1838d2b6 --token amd-oneclick`
	- `python3 scripts/jupyter_remote.py create-terminal`
	- `python3 scripts/jupyter_remote.py exec --terminal 1 --timeout 120 --command '...Paddle 与 BF16 就绪探测...'`
	- `python3 scripts/jupyter_remote.py exec --terminal 7 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; paddle.set_device(\"gpu\"); x=paddle.randn([8,8], dtype=\"bfloat16\")"'`
	- `python3 scripts/jupyter_remote.py exec --terminal 8 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; paddle.set_device(\"gpu\"); a=paddle.ones([2,2], dtype=\"bfloat16\"); ..."'`
	- `python3 scripts/jupyter_remote.py exec --terminal 9 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; paddle.set_device(\"gpu\"); x=paddle.ones([2,2], dtype=\"float32\"); ..."'`
- 已验证结果：
	- 实例可正常认证，初始 shell 落点为 `/opt/PaddleX`
	- 存在 `rocminfo`，`hipcc` 位于 `/opt/rocm/bin/hipcc`
	- 当前 Python 环境为 `/opt/venv/bin/python`，版本 `3.12.3`
	- Paddle 可正常导入，版本报告为 `3.4.0.dev20260404`
	- `paddle.is_compiled_with_rocm()` 报告为 `True`
	- `paddle.is_compiled_with_cuda()` 报告为 `True`
	- `paddle.device.get_device()` 报告为 `gpu:0`
	- `paddle.device.is_bf16_supported()` 报告为 `True`
	- `paddle.cuda.is_bf16_supported()` 报告为 `True`
	- 直接执行 GPU BF16 `paddle.randn([8,8], dtype="bfloat16")` 会以退出码 `139` 触发段错误，C++ traceback 到达 `phi::GaussianKernel<phi::dtype::bfloat16, phi::GPUContext>`
	- 更宽的对照命令同样失败：GPU 上的 `paddle.ones([2,2], dtype="float32")` 也会以退出码 `139` 触发段错误，C++ traceback 到达 `phi::FullKernel<float, phi::GPUContext>`
- 结论：
	- 当前 `30006` 镜像不能作为有效验证目标，因为连 float32 的最小 GPU Tensor 物化都已经损坏
	- `30006` 上观察到的问题范围比 `30008` 上的 BF16 Gaussian 缺陷更广
	- 对任何预装镜像，除了 API ready 检查之外，还必须先补一条真实 GPU Tensor 创建对照用例，才能把该实例纳入任务验证

### 2026-04-10 - 对 `30006` 的后续细化验证收窄了故障范围

- 验证目标：`http://36.151.243.69:30006/instance/nb-1838d2b6/lab`
- 访问方式：认证后的 Jupyter API 加 terminal websocket
- 远程终端：`11`、`15`、`16`、`17`、`18`、`19`、`20`
- 验证命令路径：
	- 尝试 bootstrap：`scripts/remote_prepare_instance.sh 11 /app/paddle-amd-remote`
	- 包元数据采集：`python3 scripts/jupyter_remote.py exec --terminal 17 --timeout 60 --command '/opt/venv/bin/python -c "import paddle, paddle.version as pv, json; ..."'`
	- float32 上传对照：`python3 scripts/jupyter_remote.py exec --terminal 16 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; paddle.set_device(\"gpu\"); x=paddle.to_tensor(...)"'`
	- BF16 cast 对照：`python3 scripts/jupyter_remote.py exec --terminal 18 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; ... .astype(\"bfloat16\") ..."'`
	- float32 gaussian 对照：`python3 scripts/jupyter_remote.py exec --terminal 19 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; ... paddle.randn(..., dtype=\"float32\") ..."'`
	- float32 matmul 对照：`python3 scripts/jupyter_remote.py exec --terminal 20 --timeout 60 --command '/opt/venv/bin/python -c "import paddle; ... paddle.matmul(...) ..."'`
- 已验证结果：
	- `30006` 上基于 clone 的 bootstrap 目前被镜像网络条件阻塞：实例无法解析 `github.com` 与 `gitee.com`
	- 预装 Paddle 构建元数据为：
		- 版本 `3.4.0.dev20260404`
		- commit `79630aedd7f4d5f8ac6c4fe6a2290ab1657d65f6`
		- 导入路径 `/opt/venv/lib/python3.12/site-packages/paddle/__init__.py`
	- float32 的 `paddle.to_tensor(..., place="gpu")` 可以成功，并能正确拷回 CPU
	- 当两个输入都由 `paddle.to_tensor(..., place="gpu")` 创建时，float32 `paddle.matmul` 可以成功执行
	- float32 的 `paddle.randn` 仍会在 GPU 上触发段错误，traceback 到达 `phi::GaussianKernel<float, phi::GPUContext>`
	- GPU tensor 上的 float32 到 BF16 `astype` 会触发段错误，traceback 到达 `phi::CastCUDAKernelImpl<float, phi::dtype::bfloat16>`
- 结论：
	- `30006` 并不是“GPU 完全不可用”的镜像；基础上传与 float32 matmul 路径仍然可用
	- `30006` 当前的活跃故障主要集中在 Tensor 创建类与类型转换类 kernel，例如 `full`、`gaussian` 以及 GPU BF16 cast 路径
	- `30006` 仍然不能作为 BF16 验收验证目标，但仍可作为在线复现 kernel 级运行时故障的实例