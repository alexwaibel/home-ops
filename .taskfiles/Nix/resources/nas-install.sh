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

install -d -m700 "$temp/root"

export BW_SESSION=$(bw unlock --raw)
bw get item "nix-nas" | jq -r '.fields[] | select(.name=="Encryption Password") | .value' > "$temp/root/secret.key"

nix run github:nix-community/nixos-anywhere -- --disk-encryption-keys /tmp/secret.key "$temp/root/secret.key" --extra-files "$temp" --flake '.#nix-nas' --generate-hardware-config nixos-facter facter.json --target-host root@"$IP"
