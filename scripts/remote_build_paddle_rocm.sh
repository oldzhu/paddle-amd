#!/usr/bin/env bash

set -euo pipefail

terminal_name="${1:-1}"
remote_root="${2:-/app/paddle-amd-remote}"
mode="${3:-configure}"
python_bin="${PYTHON_BIN:-/opt/venv/bin/python}"
build_dir_name="${BUILD_DIR_NAME:-build-rocm}"

case "$mode" in
  configure|build)
    ;;
  *)
    echo "usage: $0 [terminal] [remote_root] [configure|build]" >&2
    exit 2
    ;;
esac

tmp_script="$(mktemp)"
cleanup() {
  rm -f "$tmp_script"
}
trap cleanup EXIT

cat > "$tmp_script" <<EOF
set -euo pipefail

remote_root="${remote_root}"
python_bin="${python_bin}"
build_dir_name="${build_dir_name}"
mode="${mode}"

paddle_root="\${remote_root}/paddlerepos/Paddle"
build_root="\${paddle_root}/\${build_dir_name}"
log_root="\${remote_root}/evidence/remote-build"

if [[ ! -d "\${paddle_root}" ]]; then
  echo "remote Paddle source tree not found: \${paddle_root}" >&2
  exit 1
fi

mkdir -p "\${log_root}"
submodule_log="\${log_root}/paddle_rocm_submodules.log"

retry() {
  local attempts="\${1}"
  shift
  local try_index=1
  while true; do
    if "\$@"; then
      return 0
    fi
    if [[ "\${try_index}" -ge "\${attempts}" ]]; then
      return 1
    fi
    echo "retry \${try_index}/\${attempts} failed for: \$*" >&2
    try_index="\$((try_index + 1))"
  done
}

run_submodule_update() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 600 "\$@"
  else
    "\$@"
  fi
}

submodule_has_checkout() {
  local submodule="$1"
  local submodule_dir="${paddle_root}/${submodule}"
  [[ -e "${submodule_dir}/.git" ]] || return 1
  find "${submodule_dir}" -mindepth 1 -maxdepth 1 ! -name .git -print -quit | grep -q .
}

collect_broken_submodules() {
  local submodule
  git -C "${paddle_root}" config --file .gitmodules --get-regexp path | awk '{print $2}' | while read -r submodule; do
    if ! submodule_has_checkout "${submodule}"; then
      printf '%s\n' "${submodule}"
    fi
  done
}

populate_submodules() {
  local pass_index
  local missing_submodules=()
  for pass_index in 1 2 3 4; do
    mapfile -t missing_submodules < <(
      {
        git -C "${paddle_root}" submodule status --recursive | awk '/^-/ {print \$2}'
        collect_broken_submodules
      } | awk 'NF && !seen[$0]++'
    )
    if [[ "\${#missing_submodules[@]}" -eq 0 ]]; then
      echo "all submodules initialized after pass \${pass_index}" >>"\${submodule_log}"
      return 0
    fi
    echo "submodule recovery pass \${pass_index}: \${#missing_submodules[@]} missing" >>"\${submodule_log}"
    for submodule in "\${missing_submodules[@]}"; do
      echo "retrying submodule: \${submodule}"
      rm -rf "\${paddle_root}/\${submodule}"
      retry 3 run_submodule_update git -C "\${paddle_root}" -c http.version=HTTP/1.1 -c submodule.fetchJobs=1 submodule update --init --recursive "\${submodule}" >>"\${submodule_log}" 2>&1
    done
  done

  mapfile -t missing_submodules < <(
    {
      git -C "${paddle_root}" submodule status --recursive | awk '/^-/ {print \$2}'
      collect_broken_submodules
    } | awk 'NF && !seen[$0]++'
  )
  if [[ "\${#missing_submodules[@]}" -gt 0 ]]; then
    echo "submodule recovery exhausted with \${#missing_submodules[@]} entries still missing" >&2
    printf '%s\n' "\${missing_submodules[@]}" >&2
    return 1
  fi
}

echo "== remote Paddle ROCm source probe =="
echo "remote_root: \${remote_root}"
echo "paddle_root: \${paddle_root}"
echo "build_root: \${build_root}"
echo "mode: \${mode}"
echo "python_bin: \${python_bin}"

if "\${python_bin}" - <<'PY'
import sys
try:
    import paddle
except Exception:
    sys.exit(1)
sys.exit(0 if paddle.is_compiled_with_rocm() else 2)
PY
then
  echo "A ROCm-capable Paddle is already importable; skipping source probe"
  exit 0
else
  status="\$?"
  if [[ "\${status}" == "2" ]]; then
    echo "Existing Paddle import is present but not ROCm-capable; continuing with source probe"
  else
    echo "Paddle is not importable in the active Python environment; continuing with source probe"
  fi
fi

gpu_arch="\$(rocminfo 2>/dev/null | grep -o 'gfx[0-9]\+' | head -n 1 || true)"
if [[ -n "\${gpu_arch}" ]]; then
  echo "detected_gpu_arch: \${gpu_arch}"
  if ! grep -q -- "--offload-arch=\${gpu_arch}" "\${paddle_root}/cmake/hip.cmake"; then
    echo "warning: checked-in cmake/hip.cmake does not list \${gpu_arch} in its explicit offload target list"
    echo "warning: this is a hypothesis for a later build or runtime issue, not yet a confirmed root cause"
  fi
fi

command -v cmake >/dev/null
command -v ninja >/dev/null
"\${python_bin}" -m pip install wheel distro pyyaml jinja2 >/dev/null

echo "== preparing ROCm compatibility paths =="
mkdir -p /opt/rocm/hip/include/hip
if [[ ! -e /opt/rocm/hip/include/hip/hip_version.h ]] \
  && [[ -f /opt/rocm/include/hip/hip_version.h ]]; then
  ln -s /opt/rocm/include/hip/hip_version.h /opt/rocm/hip/include/hip/hip_version.h
fi
if [[ ! -e /opt/rocm-7.2.1/include/rccl.h ]] \
  && [[ -f /opt/rocm-7.2.1/include/rccl/rccl.h ]]; then
  ln -s /opt/rocm-7.2.1/include/rccl/rccl.h /opt/rocm-7.2.1/include/rccl.h
fi
ls -l /opt/rocm/hip/include/hip/hip_version.h /opt/rocm-7.2.1/include/rccl.h

hip_legacy_cmake_dir=""
for candidate in \
  /opt/rocm/lib/cmake/hip \
  /opt/rocm-7.2.1/lib/cmake/hip \
  /opt/rocm/hip/cmake; do
  if [[ -f "\${candidate}/FindHIP.cmake" ]]; then
    hip_legacy_cmake_dir="\${candidate}"
    break
  fi
done

if [[ -z "\${hip_legacy_cmake_dir}" ]]; then
  echo "could not locate FindHIP.cmake in expected ROCm CMake directories" >&2
  exit 1
fi

hip_module_path="\${hip_legacy_cmake_dir}"
if [[ -d /opt/rocm/hip/cmake && "/opt/rocm/hip/cmake" != "\${hip_legacy_cmake_dir}" ]]; then
  hip_module_path="\${hip_module_path};/opt/rocm/hip/cmake"
fi

echo "selected_hip_legacy_cmake_dir: \${hip_legacy_cmake_dir}"
echo "selected_cmake_module_path: \${hip_module_path}"

echo "== pre-populating Paddle submodules =="
git -C "\${paddle_root}" -c http.version=HTTP/1.1 submodule sync --recursive >"\${submodule_log}" 2>&1
populate_submodules
echo "remaining_missing_submodules:"
git -C "\${paddle_root}" submodule status --recursive | awk '/^-/ {print \$2}' || true

py_version="\$("\${python_bin}" - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"

mkdir -p "\${build_root}"
cd "\${build_root}"

configure_log="\${log_root}/paddle_rocm_configure.log"
build_log="\${log_root}/paddle_rocm_build.log"

configure_cmd=(
  cmake ..
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DWITH_ROCM=ON
  -DWITH_GPU=OFF
  -DWITH_PYTHON=ON
  -DWITH_TESTING=OFF
  -DWITH_CPP_TEST=OFF
  -DWITH_DISTRIBUTE=OFF
  -DWITH_GLOO=OFF
  -DWITH_MKL=OFF
  -DWITH_AVX=ON
  -DWITH_CINN=OFF
  -DWITH_TENSORRT=OFF
  -DWITH_ONNXRUNTIME=OFF
  -DWITH_INFERENCE_API_TEST=OFF
  -DWITH_SHARED_PHI=OFF
  -DWITH_STRIP=OFF
  -DON_INFER=OFF
  -DCMAKE_MODULE_PATH="\${hip_module_path}"
  -DROCM_PATH=/opt/rocm
  -DPYTHON_EXECUTABLE="\${python_bin}"
  -DPY_VERSION="\${py_version}"
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

echo "== running CMake configure =="
printf '%q ' "\${configure_cmd[@]}"
echo
if ! "\${configure_cmd[@]}" >"\${configure_log}" 2>&1; then
  echo "configure failed; showing tail of \${configure_log}" >&2
  tail -n 120 "\${configure_log}" >&2
  exit 1
fi

if [[ "\${mode}" == "build" ]]; then
  echo "== running CMake build =="
  if ! cmake --build . -j"\$(nproc)" >"\${build_log}" 2>&1; then
    echo "build failed; showing tail of \${build_log}" >&2
    tail -n 120 "\${build_log}" >&2
    exit 1
  fi
fi

echo
echo "submodule_log: \${submodule_log}"
echo "configure_log: \${configure_log}"
if [[ "\${mode}" == "build" ]]; then
  echo "build_log: \${build_log}"
fi
EOF

echo "[local] executing remote Paddle ROCm source ${mode} probe on terminal ${terminal_name}"
python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --command-file "$tmp_script"