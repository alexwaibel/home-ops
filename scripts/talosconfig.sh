#!/usr/bin/env bash
# Mint a short-lived, role-scoped talosconfig. The long-lived admin config
# derived from the secrets bundle only ever exists in a private temp dir.
#
#   talosconfig.sh mint <role> <ttl> <output-path>
#   talosconfig.sh run  <role> <ttl> -- <command...>   # TALOSCONFIG set for command only
set -Eeuo pipefail

usage() {
    sed -n '5,6s/^#   //p' "${0}" >&2
    exit 1
}

[[ $# -ge 4 ]] || usage
mode="${1}" role="${2}" ttl="${3}"
shift 3

case "${mode}" in
    mint) [[ $# -eq 1 && -n "${1}" ]] || usage ;;
    run) [[ $# -ge 2 && "${1}" == "--" ]] || usage ;;
    *) usage ;;
esac
IFS=, read -ra roles <<< "${role}"
for r in "${roles[@]}"; do
    [[ "${r}" =~ ^os:(admin|operator|reader|etcd:backup)$ ]] || { echo "Invalid role: ${r}" >&2; exit 1; }
done
[[ "${ttl}" =~ ^([0-9]+(\.[0-9]+)?(h|m|s))+$ ]] || { echo "Invalid TTL: ${ttl} (e.g. 1h, 30m)" >&2; exit 1; }

# Only use a per-user tmpfs so key material never touches a persistent disk
runtime_dir="${XDG_RUNTIME_DIR:-}"
[[ -n "${runtime_dir}" && -d "${runtime_dir}" && -O "${runtime_dir}" ]] || {
    echo "XDG_RUNTIME_DIR is not set to a directory you own; refusing to continue" >&2
    exit 1
}

# Remove dirs left behind by runs that died before their EXIT trap fired
for dir in "${runtime_dir}"/talosconfig.*; do
    [[ -d "${dir}" ]] || continue
    pid="$(cat "${dir}/pid" 2>/dev/null || true)"
    if [[ -n "${pid}" ]]; then
        kill -0 "${pid}" 2>/dev/null && continue
    elif [[ -n "$(find "${dir}" -maxdepth 0 -mmin -1)" ]]; then
        continue # just created by a concurrent run that hasn't written its pid yet
    fi
    rm -rf "${dir}"
done

talos_dir="$(cd "$(dirname "${0}")/../talos" && pwd)"
umask 077
tmp_dir="$(mktemp -d "${runtime_dir}/talosconfig.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT
echo "$$" > "${tmp_dir}/pid"

(cd "${talos_dir}" && topf talosconfig) > "${tmp_dir}/root"
node="$(yq -e '[.nodes[] | select(.role == "control-plane")][0].ip' "${talos_dir}/topf.yaml")"
talosctl --talosconfig "${tmp_dir}/root" --nodes "${node}" \
    config new --roles "${role}" --crt-ttl "${ttl}" "${tmp_dir}/minted" > /dev/null
rm -f "${tmp_dir}/root"
mapfile -t nodes < <(yq '.nodes[].ip' "${talos_dir}/topf.yaml")
talosctl --talosconfig "${tmp_dir}/minted" config node "${nodes[@]}"

if [[ "${mode}" == "mint" ]]; then
    mkdir -p "$(dirname "${1}")"
    install -m 600 "${tmp_dir}/minted" "${1}"
    echo "Wrote ${role} talosconfig (TTL ${ttl}) to ${1}" >&2
else
    shift
    TALOSCONFIG="${tmp_dir}/minted" "$@"
fi
