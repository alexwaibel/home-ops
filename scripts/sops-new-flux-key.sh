#!/usr/bin/env bash
# Generate a new in-cluster Flux age key: point the &flux recipient in
# .sops.yaml at it and store the private key in bootstrap/sops-age.sops.yaml.
# The plaintext key only exists in a private tmpfs dir. Re-encrypt all files
# and apply the secret to the cluster afterwards (task sops:rotate-flux-key).
set -Eeuo pipefail

root_dir="$(git rev-parse --show-toplevel)"
sops_config="${root_dir}/.sops.yaml"
secret_file="${root_dir}/bootstrap/sops-age.sops.yaml"

runtime_dir="${XDG_RUNTIME_DIR:-}"
[[ -n "${runtime_dir}" && -d "${runtime_dir}" && -O "${runtime_dir}" ]] || {
    echo "XDG_RUNTIME_DIR is not set to a directory you own; refusing to continue" >&2
    exit 1
}
grep -qE '^\s*- &flux age1[0-9a-z]+' "${sops_config}" || {
    echo "No '- &flux age1...' recipient found in ${sops_config}" >&2
    exit 1
}

umask 077
tmp_dir="$(mktemp -d "${runtime_dir}/sops-flux-key.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

age-keygen -o "${tmp_dir}/key" 2> /dev/null
recipient="$(age-keygen -y "${tmp_dir}/key")"

sed -i -E "s|^(\s*- &flux )age1[0-9a-z]+|\1${recipient}|" "${sops_config}"
jq -Rs . < "${tmp_dir}/key" | sops set --value-stdin "${secret_file}" '["stringData"]["age.agekey"]'

echo "New Flux recipient: ${recipient}" >&2
