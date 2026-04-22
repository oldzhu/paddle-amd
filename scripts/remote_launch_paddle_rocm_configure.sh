#!/usr/bin/env bash

set -euo pipefail

terminal_name="${1:-1}"
remote_root="${2:-/app/paddle-amd-remote}"
python_bin="${PYTHON_BIN:-/opt/venv/bin/python}"
build_dir_name="${BUILD_DIR_NAME:-build-rocm}"

tmp_script="$(mktemp)"
cleanup() {
  rm -f "$tmp_script"
}
trap cleanup EXIT

{
  printf 'set -euo pipefail\n\n'
  printf 'remote_root=%q\n' "$remote_root"
  printf 'python_bin=%q\n' "$python_bin"
  printf 'build_dir_name=%q\n\n' "$build_dir_name"
  cat <<'EOF'
paddle_root="${remote_root}/paddlerepos/Paddle"
build_root="${paddle_root}/${build_dir_name}"
log_root="${remote_root}/evidence/remote-build"
launch_script="${log_root}/paddle_rocm_configure_bg.sh"

if [[ ! -d "${paddle_root}" ]]; then
  echo "remote Paddle source tree not found: ${paddle_root}" >&2
  exit 1
fi

mkdir -p "${log_root}"
mkdir -p /opt/rocm/hip/include/hip
if [[ ! -e /opt/rocm/hip/include/hip/hip_version.h ]] && [[ -f /opt/rocm/include/hip/hip_version.h ]]; then
  ln -sf /opt/rocm/include/hip/hip_version.h /opt/rocm/hip/include/hip/hip_version.h
fi
if [[ ! -e /opt/rocm-7.2.1/include/rccl.h ]] && [[ -f /opt/rocm-7.2.1/include/rccl/rccl.h ]]; then
  ln -sf /opt/rocm-7.2.1/include/rccl/rccl.h /opt/rocm-7.2.1/include/rccl.h
fi

hip_legacy_cmake_dir=""
for candidate in /opt/rocm/lib/cmake/hip /opt/rocm-7.2.1/lib/cmake/hip /opt/rocm/hip/cmake; do
  if [[ -f "${candidate}/FindHIP.cmake" ]]; then
    hip_legacy_cmake_dir="${candidate}"
    break
  fi
done

if [[ -z "${hip_legacy_cmake_dir}" ]]; then
  echo "could not locate FindHIP.cmake in expected ROCm CMake directories" >&2
  exit 1
fi

{
  printf 'set -euo pipefail\n\n'
  printf 'paddle_root=%q\n' "${paddle_root}"
  printf 'build_root=%q\n' "${build_root}"
  printf 'log_root=%q\n' "${log_root}"
  printf 'python_bin=%q\n' "${python_bin}"
  printf 'hip_legacy_cmake_dir=%q\n\n' "${hip_legacy_cmake_dir}"
  cat <<'BGEOF'
retry() {
  local attempts="${1}"
  shift
  local try_index=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "${try_index}" -ge "${attempts}" ]]; then
      return 1
    fi
    echo "retry ${try_index}/${attempts} failed for: $*" >&2
    try_index="$((try_index + 1))"
  done
}

run_submodule_update() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 600 "$@"
  else
    "$@"
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
  git config --file .gitmodules --get-regexp path | awk '{print $2}' | while read -r submodule; do
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
        git submodule status --recursive | awk '/^-/ {print $2}'
        collect_broken_submodules
      } | awk 'NF && !seen[$0]++'
    )
    if [[ "${#missing_submodules[@]}" -eq 0 ]]; then
      echo "all submodules initialized after pass ${pass_index}" >>"${log_root}/paddle_rocm_submodules.log"
      return 0
    fi
    echo "submodule recovery pass ${pass_index}: ${#missing_submodules[@]} missing" >>"${log_root}/paddle_rocm_submodules.log"
    for submodule in "${missing_submodules[@]}"; do
      echo "retrying submodule: ${submodule}" >>"${log_root}/paddle_rocm_submodules.log"
      rm -rf "${paddle_root}/${submodule}"
      retry 3 run_submodule_update git -c http.version=HTTP/1.1 -c submodule.fetchJobs=1 submodule update --init --recursive "${submodule}" >>"${log_root}/paddle_rocm_submodules.log" 2>&1
    done
  done

  mapfile -t missing_submodules < <(
    {
      git submodule status --recursive | awk '/^-/ {print $2}'
      collect_broken_submodules
    } | awk 'NF && !seen[$0]++'
  )
  if [[ "${#missing_submodules[@]}" -gt 0 ]]; then
    echo "submodule recovery exhausted with ${#missing_submodules[@]} entries still missing" >>"${log_root}/paddle_rocm_submodules.log"
    printf '%s\n' "${missing_submodules[@]}" >>"${log_root}/paddle_rocm_submodules.log"
    return 1
  fi
}

cd "${paddle_root}"
git -c http.version=HTTP/1.1 submodule sync --recursive >"${log_root}/paddle_rocm_submodules.log" 2>&1
populate_submodules
mkdir -p "${build_root}"
cd "${build_root}"
"${python_bin}" -m pip install wheel distro pyyaml jinja2 >/dev/null
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_ROCM=ON \
  -DWITH_GPU=OFF \
  -DWITH_PYTHON=ON \
  -DWITH_TESTING=OFF \
  -DWITH_CPP_TEST=OFF \
  -DWITH_DISTRIBUTE=OFF \
  -DWITH_GLOO=OFF \
  -DWITH_MKL=OFF \
  -DWITH_AVX=ON \
  -DWITH_CINN=OFF \
  -DWITH_TENSORRT=OFF \
  -DWITH_ONNXRUNTIME=OFF \
  -DWITH_INFERENCE_API_TEST=OFF \
  -DWITH_SHARED_PHI=OFF \
  -DWITH_STRIP=OFF \
  -DON_INFER=OFF \
  -DCMAKE_MODULE_PATH="${hip_legacy_cmake_dir};/opt/rocm/hip/cmake" \
  -DROCM_PATH=/opt/rocm \
  -DPYTHON_EXECUTABLE="${python_bin}" \
  -DPY_VERSION=3.10 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  >"${log_root}/paddle_rocm_configure.log" 2>&1
BGEOF
} > "${launch_script}"

chmod +x "${launch_script}"
nohup bash "${launch_script}" >"${log_root}/paddle_rocm_launch.log" 2>&1 < /dev/null &
pid="$!"

echo "launched_pid: ${pid}"
echo "launch_script: ${launch_script}"
echo "launch_log: ${log_root}/paddle_rocm_launch.log"
echo "submodule_log: ${log_root}/paddle_rocm_submodules.log"
echo "configure_log: ${log_root}/paddle_rocm_configure.log"
EOF
} > "$tmp_script"

echo "[local] launching remote Paddle ROCm configure on terminal ${terminal_name}"
python3 scripts/jupyter_remote.py exec --terminal "$terminal_name" --command-file "$tmp_script"