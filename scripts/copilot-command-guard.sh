#!/usr/bin/env bash

set -euo pipefail

deny() {
    echo "copilot-command-guard: denied: $*" >&2
    exit 126
}

usage() {
    cat <<'EOF'
Usage: copilot-command-guard.sh <command> [args...]

Runs only read-only commands approved for this repo.
EOF
}

has_arg() {
    local needle="$1"
    shift
    for arg in "$@"; do
        [[ "${arg}" == "${needle}" ]] && return 0
    done
    return 1
}

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 2
fi

cmd="$1"
shift

case "${cmd}" in
    kubectl)
        sub="${1:-}"
        case "${sub}" in
            get|describe|logs|top|explain|api-resources|api-versions|version) ;;
            config)
                has_arg "view" "$@" && has_arg "--minify" "$@" || deny "kubectl $*"
                ;;
            apply|delete|edit|patch|replace|create|scale|rollout|drain|cordon|uncordon|label|annotate|cp|exec|port-forward|proxy|debug|attach)
                deny "kubectl $*"
                ;;
            *)
                deny "kubectl $*"
                ;;
        esac
        ;;
    flux)
        sub="${1:-}"
        case "${sub}" in
            get|tree|stats|check|diff|trace) ;;
            reconcile|suspend|resume|create|delete)
                deny "flux $*"
                ;;
            *)
                deny "flux $*"
                ;;
        esac
        ;;
    flux-local)
        sub="${1:-}"
        case "${sub}" in
            test|diff|build) ;;
            *) deny "flux-local $*" ;;
        esac
        ;;
    helm)
        sub="${1:-}"
        case "${sub}" in
            template|show) ;;
            install|upgrade|uninstall|rollback)
                deny "helm $*"
                ;;
            *)
                deny "helm $*"
                ;;
        esac
        ;;
    kustomize)
        sub="${1:-}"
        case "${sub}" in
            build) ;;
            *) deny "kustomize $*" ;;
        esac
        ;;
    kubeconform) ;;
    yq|jq|rg|grep|find)
        deny "${cmd} $*"
        ;;
    git)
        sub="${1:-}"
        case "${sub}" in
            status|diff|show|log) ;;
            *) deny "git $*" ;;
        esac
        ;;
    curl|wget|nc|ssh|scp)
        deny "${cmd} $*"
        ;;
    *)
        deny "${cmd} $*"
        ;;
esac

exec "${cmd}" "$@"
