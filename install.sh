#!/bin/sh
set -e

REPO="followrabbit-ai/homebrew-tap"
BINARY_NAME="followrabbit"

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unsupported"; return 1 ;;
  esac
}

# Detect architecture
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) echo "unsupported"; return 1 ;;
  esac
}

# Get latest stable release version
get_latest_version() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | \
    grep '"tag_name"' | \
    sed 's/.*"v\([^"]*\)".*/\1/'
}

main() {
  OS=$(detect_os)
  ARCH=$(detect_arch)

  if [ "$OS" = "unsupported" ] || [ "$ARCH" = "unsupported" ]; then
    echo "Error: Unsupported platform $(uname -s)/$(uname -m)" >&2
    exit 1
  fi

  echo "Detected platform: ${OS}/${ARCH}"

  # Get version (from arg or latest)
  VERSION="${1:-$(get_latest_version)}"
  if [ -z "$VERSION" ]; then
    echo "Error: Could not determine latest version. Specify a version as an argument." >&2
    echo "Usage: $0 [version]" >&2
    exit 1
  fi
  echo "Installing followrabbit v${VERSION}..."

  # Build download URL
  EXT="tar.gz"
  if [ "$OS" = "windows" ]; then
    EXT="zip"
  fi
  URL="https://github.com/${REPO}/releases/download/v${VERSION}/${BINARY_NAME}_${VERSION}_${OS}_${ARCH}.${EXT}"
  CHECKSUM_URL="https://github.com/${REPO}/releases/download/v${VERSION}/checksums.txt"

  # Create temp directory
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  # Download archive and checksums
  echo "Downloading ${URL}..."
  curl -fsSL -o "${TMPDIR}/archive.${EXT}" "$URL"
  curl -fsSL -o "${TMPDIR}/checksums.txt" "$CHECKSUM_URL"

  # Verify checksum
  EXPECTED=$(grep "${BINARY_NAME}_${VERSION}_${OS}_${ARCH}.${EXT}" "${TMPDIR}/checksums.txt" | awk '{print $1}')
  if [ -n "$EXPECTED" ]; then
    if command -v sha256sum > /dev/null 2>&1; then
      ACTUAL=$(sha256sum "${TMPDIR}/archive.${EXT}" | awk '{print $1}')
    elif command -v shasum > /dev/null 2>&1; then
      ACTUAL=$(shasum -a 256 "${TMPDIR}/archive.${EXT}" | awk '{print $1}')
    else
      echo "Warning: sha256sum/shasum not found, skipping checksum verification"
      ACTUAL="$EXPECTED"
    fi

    if [ "$ACTUAL" != "$EXPECTED" ]; then
      echo "Error: Checksum verification failed!" >&2
      echo "  Expected: ${EXPECTED}" >&2
      echo "  Got:      ${ACTUAL}" >&2
      exit 1
    fi
    echo "Checksum verified."
  else
    echo "Warning: Could not find checksum for this archive, skipping verification"
  fi

  # Extract
  if [ "$EXT" = "tar.gz" ]; then
    tar -xzf "${TMPDIR}/archive.${EXT}" -C "${TMPDIR}" "$BINARY_NAME"
  else
    unzip -o "${TMPDIR}/archive.${EXT}" "$BINARY_NAME.exe" -d "${TMPDIR}"
    BINARY_NAME="${BINARY_NAME}.exe"
  fi

  # Install
  INSTALL_DIR="/usr/local/bin"
  if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="${HOME}/.local/bin"
    mkdir -p "$INSTALL_DIR"
    echo "Note: Installing to ${INSTALL_DIR} (add to PATH if needed)"
  fi

  cp "${TMPDIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
  chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

  echo "followrabbit v${VERSION} installed to ${INSTALL_DIR}/${BINARY_NAME}"

  # Verify
  if command -v followrabbit > /dev/null 2>&1; then
    echo ""
    followrabbit version
  else
    echo ""
    echo "Add ${INSTALL_DIR} to your PATH to use followrabbit globally:"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
  fi
}

main "$@"
