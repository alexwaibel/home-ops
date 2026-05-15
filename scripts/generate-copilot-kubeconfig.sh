#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Install a scoped kubeconfig for the copilot-readonly ServiceAccount.

Usage:
  generate-copilot-kubeconfig.sh [-n namespace] [-s service-account] [-d duration] [-o output-path]

Options:
  -n namespace         ServiceAccount namespace (default: flux-system)
  -s service-account   ServiceAccount name (default: copilot-readonly)
  -d duration          Token duration passed to kubectl create token (default: 24h)
  -o output-path       Output kubeconfig path (default: ${COPILOT_KUBECONFIG:-$HOME/.kube/copilot-config})
  -h                   Show this help message
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

yaml_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

NAMESPACE="flux-system"
SERVICE_ACCOUNT="copilot-readonly"
DURATION="24h"
OUTPUT_PATH="${COPILOT_KUBECONFIG:-$HOME/.kube/copilot-config}"
SOURCE_KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

while getopts ":n:s:d:o:h" opt; do
    case "${opt}" in
        n) NAMESPACE="${OPTARG}" ;;
        s) SERVICE_ACCOUNT="${OPTARG}" ;;
        d) DURATION="${OPTARG}" ;;
        o) OUTPUT_PATH="${OPTARG}" ;;
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

require_cmd kubectl
require_cmd base64

CURRENT_CONTEXT="$(
    KUBECONFIG="${SOURCE_KUBECONFIG}" kubectl config current-context
)"
if [[ -z "${CURRENT_CONTEXT}" ]]; then
    echo "No current kubectl context is set." >&2
    exit 1
fi

CURRENT_USER="$(
    KUBECONFIG="${SOURCE_KUBECONFIG}" kubectl config view --raw -o "jsonpath={.contexts[?(@.name==\"${CURRENT_CONTEXT}\")].context.user}"
)"
if [[ "${CURRENT_USER}" == "${SERVICE_ACCOUNT}" ]]; then
    echo "Current context already uses ${SERVICE_ACCOUNT}; run this script from the source kubeconfig that can mint tokens." >&2
    exit 1
fi

CLUSTER_NAME="$(
    KUBECONFIG="${SOURCE_KUBECONFIG}" kubectl config view --raw -o "jsonpath={.contexts[?(@.name==\"${CURRENT_CONTEXT}\")].context.cluster}"
)"
if [[ -z "${CLUSTER_NAME}" ]]; then
    echo "Unable to resolve cluster name for context: ${CURRENT_CONTEXT}" >&2
    exit 1
fi

CLUSTER_SERVER="$(
    KUBECONFIG="${SOURCE_KUBECONFIG}" kubectl config view --raw -o "jsonpath={.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.server}"
)"
if [[ -z "${CLUSTER_SERVER}" ]]; then
    echo "Unable to resolve cluster server for cluster: ${CLUSTER_NAME}" >&2
    exit 1
fi

CLUSTER_CA_DATA="$(
    KUBECONFIG="${SOURCE_KUBECONFIG}" kubectl config view --raw -o "jsonpath={.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.certificate-authority-data}"
)"
if [[ -z "${CLUSTER_CA_DATA}" ]]; then
    CLUSTER_CA_FILE="$(
        KUBECONFIG="${SOURCE_KUBECONFIG}" kubectl config view --raw -o "jsonpath={.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.certificate-authority}"
    )"
    if [[ -z "${CLUSTER_CA_FILE}" || ! -f "${CLUSTER_CA_FILE}" ]]; then
        echo "Unable to resolve cluster CA data for cluster: ${CLUSTER_NAME}" >&2
        exit 1
    fi
    CLUSTER_CA_DATA="$(base64 <"${CLUSTER_CA_FILE}" | tr -d '\n')"
fi

KUBECONFIG_SEPARATOR=':'
case "${OSTYPE:-}" in
    msys* | cygwin* | win32*)
    KUBECONFIG_SEPARATOR=';'
    ;;
esac
IFS="${KUBECONFIG_SEPARATOR}" read -r -a SOURCE_KUBECONFIG_PATHS <<<"${SOURCE_KUBECONFIG}"
for SOURCE_PATH in "${SOURCE_KUBECONFIG_PATHS[@]}"; do
    if [[ "${SOURCE_PATH}" == "${OUTPUT_PATH}" ]]; then
        echo "Output path must not overwrite the source kubeconfig used to mint tokens: ${OUTPUT_PATH}" >&2
        exit 1
    fi
done

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
CREDENTIAL_HELPER="${SCRIPT_DIR}/copilot-kube-credential.sh"
if [[ ! -f "${CREDENTIAL_HELPER}" ]]; then
    echo "Credential helper is missing: ${CREDENTIAL_HELPER}" >&2
    exit 1
fi
if [[ ! -x "${CREDENTIAL_HELPER}" ]]; then
    echo "Credential helper is not executable: ${CREDENTIAL_HELPER} (run: chmod +x ${CREDENTIAL_HELPER})" >&2
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"

cat >"${OUTPUT_PATH}" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: ${CLUSTER_NAME}
    cluster:
      server: ${CLUSTER_SERVER}
      certificate-authority-data: ${CLUSTER_CA_DATA}
contexts:
  - name: copilot-readonly@${CLUSTER_NAME}
    context:
      cluster: ${CLUSTER_NAME}
      namespace: ${NAMESPACE}
      user: ${SERVICE_ACCOUNT}
current-context: copilot-readonly@${CLUSTER_NAME}
users:
  - name: ${SERVICE_ACCOUNT}
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1
        command: $(yaml_quote "${CREDENTIAL_HELPER}")
        args:
          - -n
          - $(yaml_quote "${NAMESPACE}")
          - -s
          - $(yaml_quote "${SERVICE_ACCOUNT}")
          - -d
          - $(yaml_quote "${DURATION}")
          - -c
          - $(yaml_quote "${CURRENT_CONTEXT}")
        env:
          - name: KUBECONFIG
            value: $(yaml_quote "${SOURCE_KUBECONFIG}")
        interactiveMode: Never
EOF

chmod 600 "${OUTPUT_PATH}"

echo "Wrote scoped kubeconfig with automatic token refresh: ${OUTPUT_PATH}"
echo "Source kubeconfig: ${SOURCE_KUBECONFIG}"
echo "Source context: ${CURRENT_CONTEXT}"
echo "Run: export KUBECONFIG='${OUTPUT_PATH}'"
