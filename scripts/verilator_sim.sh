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
SIM=0          # build & run testbench (tb_axi2per)

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -t, --top <MODULE>    Top module name (default: ${TOP_MODULE})
  -s, --sim             Build and run tb_axi2per testbench simulation
  -c, --clean           Remove build directory before compiling
  -l, --lint-only       Run lint only (--lint-only flag to Verilator)
  -h, --help            Print this help message

Environment variables:
  TOP_MODULE            Override top module name
  VLT_ARGS              Extra arguments passed to Verilator

Examples:
  $0 --lint-only              # Lint RTL only (no sim sources)
  $0 --sim                    # Build and run tb_axi2per
  $0 --sim --clean            # Clean build then simulate
  $0 --top axi2per_req_channel --lint-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--top)       TOP_MODULE="$2"; shift 2 ;;
    -s|--sim)       SIM=1; TOP_MODULE="tb_axi2per"; shift ;;
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
echo "  Sim mode   : ${SIM}"
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

if [[ ${SIM} -eq 1 ]]; then
  # Include simulation sources (per_slave_model + tb_axi2per)
  bender script verilator -t simulation > "${BUILD_DIR}/bender.f"
  bender script verilator -t simulation > "${SCRIPT_DIR}/verilator_sim.f"
  echo "    Filelist (sim): ${BUILD_DIR}/bender.f"
else
  bender script verilator > "${BUILD_DIR}/bender.f"
  bender script verilator > "${SCRIPT_DIR}/verilator.f"
  echo "    Filelist (rtl): ${BUILD_DIR}/bender.f"
fi

# -----------------------------------------------------------------------
# Build Verilator command
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
  --Wno-TIMESCALEMOD
  --error-limit 50
)

if [[ ${LINT_ONLY} -eq 1 ]]; then
  VLT_CMD+=(--lint-only)
  echo "    Mode: lint-only"
elif [[ ${SIM} -eq 1 ]]; then
  VLT_CMD+=(--binary --trace --timing)
  echo "    Mode: simulation (tb_axi2per)"
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

# -----------------------------------------------------------------------
# Run simulation if requested
# -----------------------------------------------------------------------
if [[ ${LINT_ONLY} -eq 1 ]]; then
  echo ""
  echo "=== Lint passed successfully ==="
elif [[ ${SIM} -eq 1 ]]; then
  echo ""
  echo "=== Build complete — running simulation ==="
  SIM_BIN="${BUILD_DIR}/obj_dir/Vtb_axi2per"
  mkdir -p "${REPO_ROOT}/sim"
  cd "${REPO_ROOT}"
  "${SIM_BIN}" 2>&1
  echo ""
  if [[ -f "${REPO_ROOT}/sim/tb_axi2per.vcd" ]]; then
    echo "    Waveform: sim/tb_axi2per.vcd"
  fi
else
  echo ""
  echo "=== Build complete ==="
  echo "    Binary: ${BUILD_DIR}/obj_dir/V${TOP_MODULE}"
  echo ""
  echo "To run the simulation:"
  echo "  ${BUILD_DIR}/obj_dir/V${TOP_MODULE}"
fi
