#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'USAGE'
Install flux-operator and flux-operator-mcp binaries.

The installer prefers mise (with aqua package specs) when available and falls back to direct release downloads.

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

TMP_DIR=""
cleanup() {
    if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}
trap cleanup EXIT

install_from_release() {
    require_cmd curl
    require_cmd tar

    local uname_s uname_m os arch version_no_v base_url
    uname_s="$(uname -s)"
    uname_m="$(uname -m)"

    case "${uname_s}" in
        Linux) os="linux" ;;
        Darwin) os="darwin" ;;
        *)
            echo "Unsupported OS: ${uname_s}" >&2
            exit 1
            ;;
    esac

    case "${uname_m}" in
        x86_64 | amd64) arch="amd64" ;;
        arm64 | aarch64) arch="arm64" ;;
        *)
            echo "Unsupported architecture: ${uname_m}" >&2
            exit 1
            ;;
    esac

    TMP_DIR="$(mktemp -d)"

    version_no_v="${VERSION#v}"
    base_url="https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/${VERSION}"

    install_asset() {
        local asset_name="$1"
        local binary_name="$2"
        local asset_path="${TMP_DIR}/${asset_name}"

        echo "Downloading ${asset_name}..."
        curl -fsSL "${base_url}/${asset_name}" -o "${asset_path}"

        tar -xzf "${asset_path}" -C "${TMP_DIR}" "${binary_name}"
        install -m 0755 "${TMP_DIR}/${binary_name}" "${INSTALL_DIR}/${binary_name}"

        echo "Installed ${binary_name} -> ${INSTALL_DIR}/${binary_name}"
    }

    install_asset "flux-operator_${version_no_v}_${os}_${arch}.tar.gz" "flux-operator"
    install_asset "flux-operator-mcp_${version_no_v}_${os}_${arch}.tar.gz" "flux-operator-mcp"
}

install_with_mise() {
    if ! command -v mise >/dev/null 2>&1; then
        return 1
    fi

    local version_no_v cli_spec mcp_spec cli_path mcp_path
    version_no_v="${VERSION#v}"
    cli_spec="aqua:controlplaneio-fluxcd/flux-operator@${version_no_v}"
    mcp_spec="aqua:controlplaneio-fluxcd/flux-operator-mcp@${version_no_v}"

    echo "Attempting installation via mise (${cli_spec}, ${mcp_spec})..."
    if ! mise install "${cli_spec}" "${mcp_spec}"; then
        echo "mise install failed; falling back to direct release downloads."
        return 1
    fi

    if ! cli_path="$(mise which flux-operator 2>/dev/null)"; then
        echo "mise install succeeded but flux-operator binary could not be resolved; falling back to direct release downloads."
        return 1
    fi
    if ! mcp_path="$(mise which flux-operator-mcp 2>/dev/null)"; then
        echo "mise install succeeded but flux-operator-mcp binary could not be resolved; falling back to direct release downloads."
        return 1
    fi

    if [[ ! -x "${cli_path}" || ! -x "${mcp_path}" ]]; then
        echo "mise resolved flux binaries but they were not executable (${cli_path}, ${mcp_path}); falling back to direct release downloads."
        return 1
    fi

    install -m 0755 "${cli_path}" "${INSTALL_DIR}/flux-operator"
    install -m 0755 "${mcp_path}" "${INSTALL_DIR}/flux-operator-mcp"
    echo "Installed flux-operator -> ${INSTALL_DIR}/flux-operator"
    echo "Installed flux-operator-mcp -> ${INSTALL_DIR}/flux-operator-mcp"

    return 0
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

mkdir -p "${INSTALL_DIR}"
if ! install_with_mise; then
    install_from_release
fi

echo "Flux AI tooling installed successfully (${VERSION})"
echo "Ensure ${INSTALL_DIR} is in PATH before running task agent:setup"
