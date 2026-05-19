#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'USAGE'
Setup local GitOps AI tooling for Copilot sessions.

Usage:
  setup-copilot-agent.sh [--install-tools] [--skip-kubeconfig] [--kubeconfig-output PATH] [--duration DURATION] [--skills-ref REF] [--agent NAME]

Options:
  --install-tools          Install flux-operator and flux-operator-mcp first
  --skip-kubeconfig        Skip generating the read-only kubeconfig
  --kubeconfig-output PATH Output path for generated read-only kubeconfig (default: ~/.kube/copilot-config)
  --duration DURATION      Token duration for read-only kubeconfig generation (default: 24h)
  --skills-ref REF         Skills OCI reference (default: ghcr.io/fluxcd/agent-skills)
  --agent NAME             Agent target for skills install (default: github-copilot)
  -h, --help               Show this help message
USAGE
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_opt_value() {
    local opt="$1"
    local value="${2:-}"
    if [[ -z "${value}" ]]; then
        echo "Option ${opt} requires a value." >&2
        usage >&2
        exit 1
    fi
}

SCRIPT_DIR="$({ cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd; })"
INSTALL_TOOLS=false
SKIP_KUBECONFIG=false
KUBECONFIG_OUTPUT="${COPILOT_KUBECONFIG:-${HOME}/.kube/copilot-config}"
DURATION="24h"
SKILLS_REF="ghcr.io/fluxcd/agent-skills"
AGENT="github-copilot"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-tools)
            INSTALL_TOOLS=true
            shift
            ;;
        --skip-kubeconfig)
            SKIP_KUBECONFIG=true
            shift
            ;;
        --kubeconfig-output)
            require_opt_value "--kubeconfig-output" "${2:-}"
            KUBECONFIG_OUTPUT="$2"
            shift 2
            ;;
        --duration)
            require_opt_value "--duration" "${2:-}"
            DURATION="$2"
            shift 2
            ;;
        --skills-ref)
            require_opt_value "--skills-ref" "${2:-}"
            SKILLS_REF="$2"
            shift 2
            ;;
        --agent)
            require_opt_value "--agent" "${2:-}"
            AGENT="$2"
            shift 2
            ;;
        -h | --help)
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

if [[ "${INSTALL_TOOLS}" == true ]]; then
    bash "${SCRIPT_DIR}/install-flux-ai-tooling.sh"
fi

require_cmd flux-operator
require_cmd flux-operator-mcp

if [[ "${SKIP_KUBECONFIG}" == false ]]; then
    require_cmd kubectl
    bash "${SCRIPT_DIR}/generate-copilot-kubeconfig.sh" -d "${DURATION}" -o "${KUBECONFIG_OUTPUT}"
fi

echo "Installing Flux agent skills for ${AGENT} from ${SKILLS_REF}..."
flux-operator skills install "${SKILLS_REF}" --agent "${AGENT}"

echo
echo "Setup complete."
if [[ "${SKIP_KUBECONFIG}" == false ]]; then
    echo "Export read-only kubeconfig: export KUBECONFIG='${KUBECONFIG_OUTPUT}'"
fi
cat <<'USAGE_INFO'

Start read-only MCP server with:
  task agent:mcp-serve

MCP server command (for agent configs):
  flux-operator-mcp serve --read-only
USAGE_INFO
