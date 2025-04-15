#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <IP_ADDRESS>"
  exit 1
fi

IP="$1"

temp=$(mktemp -d)

cleanup() {
    rm -rf "$temp"
}
trap cleanup EXIT

install -d -m700 "$temp/etc/secrets/initrd"

export BW_SESSION=$(bw unlock --raw)
bw get notes "Media Center Mini PC" > "$temp/etc/secrets/initrd/ssh_host_ed25519_key"

nix run github:nix-community/nixos-anywhere -- \
  --disk-encryption-keys /tmp/secret.key <(bw get item "Media Center Mini PC" | jq -r '.fields[] | select(.name=="Encryption Password") | .value') \
  --extra-files "$temp" \
  --flake '.#media-center' \
  --generate-hardware-config nixos-facter ./machines/media-center/facter.json \
  --target-host root@"$IP"
