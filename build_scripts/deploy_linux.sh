#!/usr/bin/env bash
set -euo pipefail

build_dir="build"
generator=""
build_type="Release"
mpi_mode="auto"
run_tests=0
clean=0

usage() {
  cat <<'EOF'
Usage: bash build_scripts/deploy_linux.sh [options]

Options:
  --build-dir <dir>     Build directory, default: build
  --generator <name>    CMake generator, default: auto-detect Ninja
  --build-type <type>   Debug, Release, RelWithDebInfo, MinSizeRel
  --mpi <mode>          auto, on, off
  --run-tests           Run ctest after the build
  --clean               Remove the build directory before configuring
  --help                Show this message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-dir)
      build_dir="$2"
      shift 2
      ;;
    --generator)
      generator="$2"
      shift 2
      ;;
    --build-type)
      build_type="$2"
      shift 2
      ;;
    --mpi)
      mpi_mode="$2"
      shift 2
      ;;
    --run-tests)
      run_tests=1
      shift
      ;;
    --clean)
      clean=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_path="${repo_root}/${build_dir}"

command -v cmake >/dev/null 2>&1 || { echo "cmake not found in PATH" >&2; exit 1; }

use_ninja=0
if [[ -z "${generator}" ]] && command -v ninja >/dev/null 2>&1; then
  generator="Ninja"
  use_ninja=1
elif [[ "${generator}" == "Ninja" ]]; then
  command -v ninja >/dev/null 2>&1 || { echo "ninja not found in PATH" >&2; exit 1; }
  use_ninja=1
fi

if [[ "${clean}" -eq 1 ]]; then
  rm -rf "${build_path}"
fi

cmake_args=(-S "${repo_root}" -B "${build_path}")
if [[ -n "${generator}" ]]; then
  cmake_args+=(-G "${generator}")
fi
if [[ "${use_ninja}" -eq 1 || ( -n "${generator}" && "${generator}" != Visual* && "${generator}" != Xcode ) ]]; then
  cmake_args+=("-DCMAKE_BUILD_TYPE=${build_type}")
fi
case "${mpi_mode}" in
  on)
    cmake_args+=("-DSTRACK_ENABLE_MPI=ON")
    ;;
  off)
    cmake_args+=("-DSTRACK_ENABLE_MPI=OFF")
    ;;
  auto)
    ;;
  *)
    echo "invalid --mpi mode: ${mpi_mode}" >&2
    exit 1
    ;;
esac

echo "Configuring strack in ${build_path}"
cmake "${cmake_args[@]}"

echo "Building strack"
cmake --build "${build_path}"

if [[ "${run_tests}" -eq 1 ]]; then
  echo "Running validation"
  ctest --test-dir "${build_path}" --output-on-failure
fi

echo
echo "Build complete."
echo "Example run:"
echo "  ${build_path}/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml"
