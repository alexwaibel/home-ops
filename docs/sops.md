# SOPS keys

Secrets in this repo are encrypted with [SOPS](https://github.com/getsops/sops)
and [age](https://age-encryption.org). Recipients are defined once as YAML
anchors at the top of [`.sops.yaml`](../.sops.yaml) and referenced by each
creation rule.

| Recipient | Where the private key lives | Can decrypt |
| --- | --- | --- |
| `yubikey_*` | PIV slot 2 (`home-ops`) on each YubiKey, never exportable | everything |
| `offline_backup` | Bitwarden item "home-ops SOPS backup age key" only | everything |
| `flux` | `flux-system/sops-age` in the cluster, plus `bootstrap/sops-age.sops.yaml` | `kubernetes/` only |

Flux deliberately can't decrypt `talos/` or `bootstrap/`, so a cluster
compromise doesn't expose the Talos root PKI.

`age-yubikey-identities.txt` holds the YubiKey identity stubs `sops` uses to
find the right key. They only reference keys on the devices (serial, slot,
recipient) and aren't secret.

## Daily use

Plug in any enrolled YubiKey. `sops` (and `topf`, `task talos:config`, …) asks
for the PIV PIN once per session and a touch, which is cached for 15 seconds.

### New machine

1. Install `age-plugin-yubikey` (home-manager in nix-config) and make sure
   `pcscd` is running.
2. Clone the repo; `mise` points `SOPS_AGE_KEY_FILE` at the identities file.
3. Check with `sops decrypt talos/talsecret.sops.yaml > /dev/null`.

## Adding a YubiKey

FIPS YubiKeys don't work: age-plugin-yubikey needs a TDES management key
([str4d/age-plugin-yubikey#92](https://github.com/str4d/age-plugin-yubikey/issues/92)),
which FIPS mode forbids.

1. Generate the key on the new YubiKey:

   ```sh
   age-plugin-yubikey --generate --slot 2 --name home-ops --pin-policy once --touch-policy cached
   ```

2. Append its stub to the identities file:

   ```sh
   age-plugin-yubikey --identity --slot 2 >> age-yubikey-identities.txt
   ```

3. Add a `&yubikey_<name>` anchor in `.sops.yaml` (comment with the serial)
   and reference it in **every** creation rule.
4. With an already-enrolled YubiKey plugged in, run `task sops:reencrypt`.
5. Commit and push.

## Revoking a YubiKey (lost, broken or retired)

1. Remove its anchor and references from `.sops.yaml` and its stub from
   `age-yubikey-identities.txt`.
2. Run `task sops:reencrypt`. This also rotates every file's data key, so the
   removed key can't read future versions.
3. Commit and push.

A removed key can still decrypt every version in **git history**. If the key
was lost or stolen, not just retired, the PIN (3 tries before it locks) is
what protects you. If you suspect the PIN was also compromised, rotate the
secret values themselves, starting with the provider credentials in
`kubernetes/`. Rotating the Talos PKI is a larger, separate operation.

## Rotating the Flux key

```sh
task sops:rotate-flux-key
git commit -am "Rotate Flux SOPS key" && git push
```

This generates a new key in `$XDG_RUNTIME_DIR/home-ops`, updates the `&flux` recipient
and `bootstrap/sops-age.sops.yaml`, re-encrypts everything and applies the
secret to the cluster (needs a working `kubeconfig`). Push straight away: Flux
can't decrypt `kubernetes/` until the re-encrypted files land. Check with
`flux get kustomizations`. If the apply step failed, rerun
`task sops:apply-flux-key`.

## Rotating the offline backup key

1. Generate a new key straight to tmpfs and upload the file to Bitwarden:

   ```sh
   f="$XDG_RUNTIME_DIR/home-ops/backup.agekey"
   (umask 077 && mkdir -p "${f%/*}" && age-keygen -o "$f")
   ```

2. Replace the `&offline_backup` recipient with the printed public key and run
   `task sops:reencrypt`.
3. `rm "$f"`, commit and push, then delete the old Bitwarden item.

## Recovering when every YubiKey is lost

You need the Bitwarden item, so keep your Bitwarden recovery code offline in
case your YubiKeys were also your Bitwarden 2FA.

1. Download the backup key from Bitwarden to `$XDG_RUNTIME_DIR/home-ops/`
   (tmpfs).
2. Enroll replacement YubiKeys as in [Adding a YubiKey](#adding-a-yubikey),
   and remove the lost ones as in
   [Revoking a YubiKey](#revoking-a-yubikey-lost-broken-or-retired).
3. Re-encrypt using the backup key for decryption:

   ```sh
   SOPS_AGE_KEY_CMD="cat $XDG_RUNTIME_DIR/home-ops/<file>" task sops:reencrypt
   ```

4. Delete the downloaded key, then
   [rotate the backup key](#rotating-the-offline-backup-key), since it has now
   been on a machine.
5. Commit and push.

If the backup key is also gone, the encrypted secrets are unrecoverable:
re-create them from their providers and rebuild the cluster's Talos PKI with
`topf secrets`.
