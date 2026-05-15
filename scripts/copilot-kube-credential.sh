#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Emit an ExecCredential for the copilot-readonly ServiceAccount.

Usage:
  copilot-kube-credential.sh [-n namespace] [-s service-account] [-d duration] [-c context]

Options:
  -n namespace         ServiceAccount namespace (default: flux-system)
  -s service-account   ServiceAccount name (default: copilot-readonly)
  -d duration          Token duration passed to kubectl create token (default: 24h)
  -c context           Source kubeconfig context to use
  -h                   Show this help message
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

json_escape() {
    "${PYTHON_BIN}" -c 'import json, sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"
}

NAMESPACE="flux-system"
SERVICE_ACCOUNT="copilot-readonly"
DURATION="24h"
CONTEXT=""

while getopts ":n:s:d:c:h" opt; do
    case "${opt}" in
        n) NAMESPACE="${OPTARG}" ;;
        s) SERVICE_ACCOUNT="${OPTARG}" ;;
        d) DURATION="${OPTARG}" ;;
        c) CONTEXT="${OPTARG}" ;;
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
PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [[ -z "${PYTHON_BIN}" ]]; then
    echo "Missing required command: python3 (or python)" >&2
    exit 1
fi

SOURCE_KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

KUBECTL_CMD=(kubectl)
if [[ -n "${CONTEXT}" ]]; then
    KUBECTL_CMD+=(--context)
    KUBECTL_CMD+=("${CONTEXT}")
fi

TOKEN="$(
    KUBECONFIG="${SOURCE_KUBECONFIG}" "${KUBECTL_CMD[@]}" --namespace "${NAMESPACE}" create token "${SERVICE_ACCOUNT}" --duration "${DURATION}"
)"
if [[ -z "${TOKEN}" ]]; then
    echo "Failed to create token for ${NAMESPACE}/${SERVICE_ACCOUNT}" >&2
    exit 1
fi

cat <<EOF
{
  "apiVersion": "client.authentication.k8s.io/v1",
  "kind": "ExecCredential",
  "status": {
    "token": "$(json_escape "${TOKEN}")"
  }
}
EOF
