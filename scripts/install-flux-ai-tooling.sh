#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'USAGE'
Install flux-operator and flux-operator-mcp binaries from the Flux Operator release.

Usage:
  install-flux-ai-tooling.sh [-d install-dir] [-v version]

Options:
  -d install-dir   Binary install directory (default: ${HOME}/.local/bin)
  -v version       Flux Operator release tag (default: v0.49.0)
  -h               Show this help message
USAGE
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

INSTALL_DIR="${HOME}/.local/bin"
VERSION="v0.49.0"

while getopts ":d:v:h" opt; do
    case "${opt}" in
        d) INSTALL_DIR="${OPTARG}" ;;
        v) VERSION="${OPTARG}" ;;
        h)
            usage
            exit 0
            ;;
        :)
            echo "Option -${OPTARG} requires an argument." >&2
            usage >&2
            exit 1
            ;;
        \?)
            echo "Invalid option: -${OPTARG}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "${VERSION}" != v* ]]; then
    VERSION="v${VERSION}"
fi

require_cmd curl
require_cmd tar

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

case "${UNAME_S}" in
    Linux) OS="linux" ;;
    Darwin) OS="darwin" ;;
    *)
        echo "Unsupported OS: ${UNAME_S}" >&2
        exit 1
        ;;
esac

case "${UNAME_M}" in
    x86_64 | amd64) ARCH="amd64" ;;
    arm64 | aarch64) ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: ${UNAME_M}" >&2
        exit 1
        ;;
esac

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${INSTALL_DIR}"

VERSION_NO_V="${VERSION#v}"
BASE_URL="https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/${VERSION}"

install_asset() {
    local asset_name="$1"
    local binary_name="$2"
    local asset_path="${TMP_DIR}/${asset_name}"

    echo "Downloading ${asset_name}..."
    curl -fsSL "${BASE_URL}/${asset_name}" -o "${asset_path}"

    tar -xzf "${asset_path}" -C "${TMP_DIR}" "${binary_name}"
    install -m 0755 "${TMP_DIR}/${binary_name}" "${INSTALL_DIR}/${binary_name}"

    echo "Installed ${binary_name} -> ${INSTALL_DIR}/${binary_name}"
}

install_asset "flux-operator_${VERSION_NO_V}_${OS}_${ARCH}.tar.gz" "flux-operator"
install_asset "flux-operator-mcp_${VERSION_NO_V}_${OS}_${ARCH}.tar.gz" "flux-operator-mcp"

echo "Flux AI tooling installed successfully (${VERSION})"
echo "Ensure ${INSTALL_DIR} is in PATH before running task agent:setup"
