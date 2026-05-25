#!/usr/bin/env bash
# Install Verilator and Bender for axi2per development
set -euo pipefail

echo "=== Installing Verilator ==="
sudo apt-get update -qq
sudo apt-get install -y verilator
verilator --version

echo ""
echo "=== Installing Bender (build from source) ==="
BENDER_REPO="https://github.com/pulp-platform/bender.git"
BENDER_BUILD_DIR="/tmp/bender-src"

if [ -d "$BENDER_BUILD_DIR" ]; then
  rm -rf "$BENDER_BUILD_DIR"
fi

git clone --depth 1 "$BENDER_REPO" "$BENDER_BUILD_DIR"
cd "$BENDER_BUILD_DIR"
cargo build --release
sudo cp target/release/bender /usr/local/bin/bender
cd -
rm -rf "$BENDER_BUILD_DIR"

bender --version

echo ""
echo "=== Fetching project dependencies with Bender ==="
bender update

echo ""
echo "All tools installed successfully!"
echo "  Verilator: $(verilator --version)"
echo "  Bender:    $(bender --version)"
