#!/usr/bin/env bash

set -euo pipefail

target_python_version="${TARGET_PYTHON_VERSION:-3.12}"
target_rocm_prefix="${TARGET_ROCM_PREFIX:-7.2}"

have_command() {
  command -v "$1" >/dev/null 2>&1
}

print_status() {
  local label="$1"
  local value="$2"
  printf '%-24s %s\n' "$label" "$value"
}

extract_python_version() {
  python3 - <<'PY'
import platform
print(platform.python_version())
PY
}

extract_python_soabi() {
  python3 - <<'PY'
import sysconfig
print(sysconfig.get_config_var("SOABI") or "unknown")
PY
}

extract_hip_version() {
  hipcc --version 2>/dev/null | awk '/HIP version:/ {print $3; exit}'
}

main() {
  local host_kernel
  local host_os
  local local_python_version
  local local_python_major_minor
  local local_soabi
  local local_hip_version="missing"
  local status_ok=true

  host_kernel="$(uname -a)"
  host_os="$(. /etc/os-release && printf '%s %s' "$NAME" "$VERSION_ID")"
  local_python_version="$(extract_python_version)"
  local_python_major_minor="${local_python_version%.*}"
  local_soabi="$(extract_python_soabi)"

  if have_command hipcc; then
    local_hip_version="$(extract_hip_version)"
  else
    status_ok=false
  fi

  print_status host_os "$host_os"
  print_status kernel "$host_kernel"
  print_status python "$local_python_version"
  print_status soabi "$local_soabi"
  print_status hipcc "$(command -v hipcc || echo missing)"
  print_status rocminfo "$(command -v rocminfo || echo missing)"
  print_status cmake "$(command -v cmake || echo missing)"
  print_status ninja "$(command -v ninja || echo missing)"
  print_status local_rocm "$local_hip_version"
  print_status target_python "$target_python_version"
  print_status target_rocm_prefix "$target_rocm_prefix"
  echo

  if [[ "$local_python_major_minor" != "$target_python_version" ]]; then
    echo "WARN: local Python $local_python_major_minor does not match target Python $target_python_version"
    status_ok=false
  fi

  if [[ "$local_hip_version" == "missing" ]]; then
    echo "WARN: hipcc is missing; this host is not ready for a local ROCm Paddle build"
  elif [[ "$local_hip_version" != ${target_rocm_prefix}* ]]; then
    echo "WARN: local ROCm $local_hip_version does not match target ROCm prefix $target_rocm_prefix"
    echo "WARN: local build plus remote deploy may still work, but version alignment is preferable"
  fi

  for required_tool in rocminfo cmake ninja git; do
    if ! have_command "$required_tool"; then
      echo "WARN: missing required tool: $required_tool"
      status_ok=false
    fi
  done

  echo
  if [[ "$status_ok" == true ]]; then
    echo "Result: local host is a plausible candidate for local build plus remote deploy."
  else
    echo "Result: local host needs attention before relying on it for a remote-deployable ROCm build."
  fi
}

main "$@"