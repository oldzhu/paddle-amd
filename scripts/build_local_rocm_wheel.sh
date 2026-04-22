#!/usr/bin/env bash

set -euo pipefail

paddle_root="${1:-/home/oldzhu/paddle-amd/paddlerepos/Paddle}"
mode="${2:-configure}"
build_dir_name="${BUILD_DIR_NAME:-build-rocm-local}"
python_bin="${PYTHON_BIN:-$(command -v python3)}"
default_c_compiler="$(command -v clang || true)"
default_cxx_compiler="$(command -v clang++ || true)"

if [[ -x /opt/rocm/llvm/bin/clang ]]; then
  default_c_compiler=/opt/rocm/llvm/bin/clang
fi
if [[ -x /opt/rocm/llvm/bin/clang++ ]]; then
  default_cxx_compiler=/opt/rocm/llvm/bin/clang++
fi

c_compiler="${C_COMPILER:-$default_c_compiler}"
cxx_compiler="${CXX_COMPILER:-$default_cxx_compiler}"

case "$mode" in
  configure|build)
    ;;
  *)
    echo "usage: $0 [paddle_root] [configure|build]" >&2
    exit 2
    ;;
esac

if [[ ! -d "$paddle_root" ]]; then
  echo "missing Paddle source tree: $paddle_root" >&2
  exit 1
fi

if [[ -z "$c_compiler" || -z "$cxx_compiler" ]]; then
  echo "could not locate C/C++ compiler" >&2
  exit 1
fi

build_root="$paddle_root/$build_dir_name"
compat_root="$build_root/rocm-compat"
configure_log="$build_root/paddle_rocm_local_configure.log"
build_log="$build_root/paddle_rocm_local_build.log"

python_version="$($python_bin - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"

rocm_root="${ROCM_PATH:-/opt/rocm}"
hip_legacy_cmake_dir=""
declare -a rocm_package_args=()
packages=(miopen rocblas hipblaslt hiprand rocrand rccl rocthrust hipcub rocprim hipsparse rocsparse rocfft rocsolver)
for candidate in \
  "$rocm_root/lib/cmake/hip" \
  /opt/rocm-6.4.2/lib/cmake/hip \
  /opt/rocm/hip/cmake; do
  if [[ -f "$candidate/FindHIP.cmake" ]]; then
    hip_legacy_cmake_dir="$candidate"
    break
  fi
done

if [[ -z "$hip_legacy_cmake_dir" ]]; then
  echo "could not locate FindHIP.cmake" >&2
  exit 1
fi

mkdir -p "$build_root"
rm -rf "$compat_root"
mkdir -p "$compat_root/hip/include/hip" "$compat_root/include" "$compat_root/include/cuda" "$compat_root/lib" "$compat_root/lib/cmake"

for entry in bin hip llvm; do
  if [[ -e "$rocm_root/$entry" && ! -e "$compat_root/$entry" ]]; then
    ln -s "$rocm_root/$entry" "$compat_root/$entry"
  fi
done

if [[ -d "$rocm_root/include" ]]; then
  for item in "$rocm_root"/include/*; do
    [[ -e "$item" ]] || continue
    name="$(basename "$item")"
    if [[ ! -e "$compat_root/include/$name" ]]; then
      ln -s "$item" "$compat_root/include/$name"
    fi
  done
fi

if [[ -d "$rocm_root/lib" ]]; then
  for item in "$rocm_root"/lib/*; do
    [[ -e "$item" ]] || continue
    name="$(basename "$item")"
    if [[ ! -e "$compat_root/lib/$name" ]]; then
      ln -s "$item" "$compat_root/lib/$name"
    fi
  done
fi

for package_name in "${packages[@]}"; do
  if [[ -d "$rocm_root/include/$package_name" ]]; then
    mkdir -p "$compat_root/$package_name"
    if [[ ! -e "$compat_root/$package_name/include" ]]; then
      ln -s "$rocm_root/include/$package_name" "$compat_root/$package_name/include"
    fi
  fi

  if [[ -d "$rocm_root/lib/cmake/$package_name" ]]; then
    mkdir -p "$compat_root/lib/cmake"
    if [[ ! -e "$compat_root/lib/cmake/$package_name" ]]; then
      ln -s "$rocm_root/lib/cmake/$package_name" "$compat_root/lib/cmake/$package_name"
    fi
    rocm_package_args+=("-D${package_name}_DIR=$rocm_root/lib/cmake/$package_name")
  fi
done

if [[ ! -e "$compat_root/hip/include/hip/hip_version.h" ]] && [[ -f "$rocm_root/include/hip/hip_version.h" ]]; then
  ln -s "$rocm_root/include/hip/hip_version.h" "$compat_root/hip/include/hip/hip_version.h"
fi
if [[ ! -e "$compat_root/include/rccl.h" ]] && [[ -f /opt/rocm-6.4.2/include/rccl/rccl.h ]]; then
  ln -s /opt/rocm-6.4.2/include/rccl/rccl.h "$compat_root/include/rccl.h"
fi

if [[ ! -e "$compat_root/include/cuda/__cccl_config" ]]; then
  cat >"$compat_root/include/cuda/__cccl_config" <<'EOF'
#pragma once

/*
 * Minimal CCCL compatibility shim for ROCm Thrust host-side includes.
 * ROCm 6.4.x ships thrust/detail/config/config.h that includes
 * <cuda/__cccl_config> even on the HIP path, but the header is not present
 * in this environment.
 */
EOF
fi

cd "$build_root"

configure_cmd=(
  cmake ..
  -G Ninja
  -DCMAKE_C_COMPILER="$c_compiler"
  -DCMAKE_CXX_COMPILER="$cxx_compiler"
  -DCMAKE_BUILD_TYPE=Release
  -DWITH_ROCM=ON
  -DWITH_GPU=OFF
  -DWITH_PYTHON=ON
  -DWITH_TESTING=OFF
  -DWITH_CPP_TEST=OFF
  -DWITH_DISTRIBUTE=OFF
  -DWITH_GLOO=OFF
  -DWITH_RCCL=OFF
  -DWITH_MKL=OFF
  -DWITH_AVX=ON
  -DWITH_CINN=OFF
  -DWITH_TENSORRT=OFF
  -DWITH_ONNXRUNTIME=OFF
  -DWITH_INFERENCE_API_TEST=OFF
  -DWITH_SHARED_PHI=OFF
  -DWITH_STRIP=OFF
  -DON_INFER=OFF
  -DBUILD_WHL_PACKAGE=ON
  -DPADDLE_SKIP_FLASHATTN=ON
  "-DPADDLE_HIP_OFFLOAD_ARCHES=gfx906;gfx1100"
  -DCMAKE_MODULE_PATH="$hip_legacy_cmake_dir"
  -DCMAKE_PREFIX_PATH="$compat_root;$rocm_root;$rocm_root/lib/cmake"
  -DROCM_PATH="$compat_root"
  -DPYTHON_EXECUTABLE="$python_bin"
  -DPY_VERSION:STRING="$python_version"
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

configure_cmd+=("${rocm_package_args[@]}")

printf '%q ' "${configure_cmd[@]}"
echo
"${configure_cmd[@]}" 2>&1 | tee "$configure_log"

if [[ "$mode" == "build" ]]; then
  cmake --build . --target paddle_copy -j"$(nproc)" 2>&1 | tee "$build_log"
fi