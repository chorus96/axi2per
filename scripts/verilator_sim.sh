#!/usr/bin/env bash
# Verilator simulation script for axi2per
# Uses bender to resolve all source files and include directories
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build/verilator"

# -----------------------------------------------------------------------
# Command-line options
# -----------------------------------------------------------------------
TOP_MODULE="${TOP_MODULE:-axi2per}"
VLT_ARGS="${VLT_ARGS:-}"
CLEAN=0
LINT_ONLY=0

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -t, --top <MODULE>    Top module name (default: ${TOP_MODULE})
  -c, --clean           Remove build directory before compiling
  -l, --lint-only       Run lint only (--lint-only flag to Verilator)
  -h, --help            Print this help message

Environment variables:
  TOP_MODULE            Override top module name
  VLT_ARGS              Extra arguments passed to Verilator

Examples:
  $0                          # Compile default top module
  $0 --top axi2per_req_channel
  $0 --lint-only              # Lint check only
  $0 --clean                  # Clean build and recompile
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--top)       TOP_MODULE="$2"; shift 2 ;;
    -c|--clean)     CLEAN=1; shift ;;
    -l|--lint-only) LINT_ONLY=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# -----------------------------------------------------------------------
# Sanity checks
# -----------------------------------------------------------------------
command -v verilator >/dev/null 2>&1 || { echo "ERROR: verilator not found in PATH"; exit 1; }
command -v bender    >/dev/null 2>&1 || { echo "ERROR: bender not found in PATH";    exit 1; }

echo "=== Verilator Simulation Build ==="
echo "  Top module : ${TOP_MODULE}"
echo "  Build dir  : ${BUILD_DIR}"
echo "  Verilator  : $(verilator --version | head -1)"
echo "  Bender     : $(bender --version)"
echo ""

# -----------------------------------------------------------------------
# Clean
# -----------------------------------------------------------------------
if [[ ${CLEAN} -eq 1 ]]; then
  echo "--- Cleaning build directory ---"
  rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"

# -----------------------------------------------------------------------
# Generate filelist with bender
# -----------------------------------------------------------------------
echo "--- Generating Verilator filelist with bender ---"
cd "${REPO_ROOT}"
bender script verilator > "${BUILD_DIR}/bender.f"
echo "    Filelist: ${BUILD_DIR}/bender.f"

# Also refresh scripts/verilator.f as a reference copy
bender script verilator > "${SCRIPT_DIR}/verilator.f"

# -----------------------------------------------------------------------
# Run Verilator
# -----------------------------------------------------------------------
echo ""
echo "--- Running Verilator ---"

VLT_CMD=(
  verilator
  --sv
  --top-module "${TOP_MODULE}"
  -f "${BUILD_DIR}/bender.f"
  --Mdir "${BUILD_DIR}/obj_dir"
  -Wall
  --Wno-fatal
  # Suppress noisy warnings from third-party dependencies
  --Wno-DECLFILENAME
  --Wno-PINCONNECTEMPTY
  --Wno-UNUSEDSIGNAL
  --Wno-UNUSEDPARAM
  --Wno-MULTIDRIVEN
  --Wno-UNOPTFLAT
  --Wno-GENUNNAMED
  --Wno-CMPCONST
  --error-limit 50
)

if [[ ${LINT_ONLY} -eq 1 ]]; then
  VLT_CMD+=(--lint-only)
  echo "    Mode: lint-only"
else
  VLT_CMD+=(--binary --trace)
  echo "    Mode: full compile + trace"
fi

# Append extra user-supplied args
if [[ -n "${VLT_ARGS}" ]]; then
  # word-split intentional here
  # shellcheck disable=SC2206
  VLT_CMD+=(${VLT_ARGS})
fi

echo "    Running: ${VLT_CMD[*]}"
echo ""
"${VLT_CMD[@]}"

if [[ ${LINT_ONLY} -eq 1 ]]; then
  echo ""
  echo "=== Lint passed successfully ==="
else
  echo ""
  echo "=== Build complete ==="
  echo "    Binary: ${BUILD_DIR}/obj_dir/V${TOP_MODULE}"
  echo ""
  echo "To run the simulation:"
  echo "  ${BUILD_DIR}/obj_dir/V${TOP_MODULE}"
fi
