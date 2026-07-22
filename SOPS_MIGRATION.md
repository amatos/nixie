# Experiment: migrate secrets from ragenix/age to sops-nix

Tracked on the `sops-nix-migration` branch only — deliberately not merged into `main` until a
final decision is made (last phase below). If this experiment is abandoned, discard the branch
and none of this ever touches `main`.

See the proposal discussed in chat for full background/rationale and the areas-of-concern list.
This file is the actionable checklist version of that proposal.

**How to use this checklist**: each step is a single atomic unit of work — implement it,
validate it against its own criteria, then check it off before starting the next one. Steps may
be executed days apart, possibly in a session with no memory of this discussion — every entry
is written to stand on its own.

---

## Phase 0 — Branch setup

- [x] **Step 1**: create the `sops-nix-migration` branch off `main`, clean working tree.
- [ ] **Step 2**: add `sops-nix` (Mic92/sops-nix) as a flake input in `flake.nix`. Add
      `sops-nix.nixosModules.sops` to one low-stakes NixOS host's module list first (recommend
      `ephemeraltron` or `darwintron`, the CI build targets — no real secrets, pure eval/build
      smoke test) before touching any real host. **Validate**: `nix flake check` /
      `nix eval .#nixosConfigurations.<test-host>.config.system.build.toplevel.drvPath`
      succeeds with the module present but unused.
- [ ] **Step 3**: add `sops`, `age`, `ssh-to-age` (and keep `age-plugin-yubikey`) to the
      devShell in `flake.nix`, alongside (not replacing) the existing `ragenix` package.
      **Validate**: `nix develop` succeeds, all four tools are on `PATH`.
- [ ] **Step 4**: create a `.sops.yaml` at the repo root (or within whichever secrets repo ends
      up hosting it — see the Phase 1 decision point) with age recipients transcribed from the
      current `nix-secrets/secrets.nix` groups (`users`, `systems`, `ldapHosts`,
      `syncthingHosts`, `unifiBackupHosts`, `smtpSmartRelays`, `remoteBuildHosts`,
      `grafanaHosts`) as YAML anchors + `creation_rules` `path_regex` entries. No real secret
      encrypted yet. **Validate**: `sops --config .sops.yaml -e --input-type binary
      --output-type binary /dev/null` (or a throwaway test file matching one rule's path
      pattern) round-trips: encrypt then `sops -d` successfully, content matches.

## Phase 1 — Decisions before migrating real secrets

- [ ] **Step 5**: decide **one repo or two**: does `nix-keytabs-matos-cc` stay separate (SOPS's
      binary mode removes the original technical reason for the split, but there may be
      access-control/workflow reasons to keep it), or fold into `nix-secrets`? Record the
      decision here before Step 8.
      - Decision: `_______________`
- [ ] **Step 6**: decide **file granularity for text secrets**: keep one file per secret
      (mirroring today's structure, simplest mechanical migration) or consolidate into fewer
      multi-key YAML files per recipient-group (the option SOPS's structured-value model
      actually enables)? Record the decision here before Step 8.
      - Decision: `_______________`
- [ ] **Step 7**: decide **host identity source**: keep generating a dedicated per-host age key
      via `modules/common/age-host-key.nix` (as today), or switch to deriving it from the
      existing SSH host key via `ssh-to-age` (removes a custom module, couples secret-decryption
      identity to the SSH host key's lifecycle instead)? Record the decision here before Step 9.
      - Decision: `_______________`

## Phase 2 — Proof of concept on one low-risk secret

- [ ] **Step 8**: migrate exactly one low-stakes secret end-to-end — recommend a
      `ghostty-themes/*.age` file (cosmetic, no boot-time dependency, nothing breaks if this
      goes wrong). Encrypt it under SOPS per the Phase 1 decisions, wire
      `sops.secrets.<name>` on one real host **alongside** (not replacing) the existing
      `age.secrets.<name>` for the same content.
- [ ] **Step 9**: deploy to that one host. **Validate**: `sops`-decrypted file appears at the
      expected `/run/secrets/<name>` path with correct content/ownership/mode, and the
      consuming config (ghostty) still picks it up correctly.
- [ ] **Step 10**: **checkpoint** — does this prove the pipeline end-to-end (encryption,
      recipient resolution, deploy-time decryption, correct file permissions)? If not, stop and
      resolve before any further migration. This is the natural point to bail cheaply if the
      pipeline doesn't feel right.

## Phase 3 — Migrate `nix-secrets` in batches (one recipient-group at a time)

Each step: encrypt under SOPS, wire `sops.secrets.*` alongside the existing `age.secrets.*`,
deploy, validate the consuming service still works, *then* remove the old `age.secrets.*`
wiring and `.age` file for that batch only once the SOPS version is proven on every host that
needs it. Do not batch multiple groups together.

- [ ] **Step 11**: `smtpSmartRelays` group (`smtp-relay-sasl`) — validate on porkchop and huginn
      (send a real test email through each, matching the validation approach used in the
      porkchop migration's Stage 5/6).
- [ ] **Step 12**: `ldapHosts` group (`ldap/admin-password`, `ldap/kdc-password`,
      `ldap/krb5-master-key`) — **highest-consequence step in this phase**: these are boot-time
      secrets for muninn's KDC/LDAP. Validate with a full `kinit`/`ldapwhoami` check on muninn,
      matching the depth of validation used in the original Kerberos+LDAP migration, before
      removing the agenix version.
- [ ] **Step 13**: `unifiBackupHosts` group (`unifi/backup-ssh-key`) — validate the unifi-backup
      service on porkchop still runs successfully.
- [ ] **Step 14**: `remoteBuildHosts` group (`builder/codex-ssh-key`) — validate a remote build
      from codex to gammu still works.
- [ ] **Step 15**: `grafanaHosts` group (`grafana-secret-key`) — validate Grafana still starts
      on porkchop with the SOPS-sourced secret.
- [ ] **Step 16**: remaining `users ++ systems`-scoped fleet-wide secrets (`github/ssh-key`,
      `github/ratelimit`, `luadns.ini`, `tailscale-authkey`, `cachix-authtoken`,
      `default-nixos-user-password`, `unifi/api-key`, `users/alberth`, `users/nixos`,
      `syncthing-gui-password`, all `ghostty-themes/*` not already done in Step 8) — can likely
      go in one or two batches given they share the same recipient set, but still validate on
      at least two representative hosts (one NixOS, one darwin) before removing the agenix
      versions.

## Phase 4 — Migrate `nix-keytabs-matos-cc`

- [ ] **Step 17**: migrate one host's keytab as proof — recommend `keytab-codex.age` (lowest
      consequence: codex losing its keytab briefly just means a Kerberos client hiccup, not a
      KDC/LDAP outage). Use SOPS's binary mode (`--input-type binary --output-type binary`).
      Validate `kinit -k -t /etc/krb5.keytab host/codex.matos.cc` still works.
- [ ] **Step 18**: migrate the remaining host keytabs (`keytab-gammu`, `keytab-porkchop`,
      `keytab-huginn`, `keytab-muninn`) one at a time, validating `kinit -k` on each.
- [ ] **Step 19**: migrate the LDAP SASL keytabs (`keytab-ldap-porkchop`, `keytab-ldap-muninn`)
      — validate the full GSSAPI LDAP bind chain (`ldapwhoami -Y GSSAPI`) still works on both,
      given how much debugging that exact path took to get right originally.

## Phase 5 — External module coordination

- [ ] **Step 20**: update `nix-kerberos-ldap`'s `ldap.nix`/`kerberos.nix` to consume
      `sops.secrets.*` instead of `age.secrets.*`. This is a change to a repo outside this
      experiment's branch — commit and push it there (on its own branch first, matching this
      same experimental posture) before referencing it from here.
- [ ] **Step 21**: bump `nixie`'s `flake.lock` for `nix-kerberos-ldap` to the new revision.
      Validate muninn's full KDC/LDAP stack against the updated module.

## Phase 6 — Fleet-wide agenix removal

- [ ] **Step 22**: once every secret has a validated SOPS counterpart on every host that needs
      it, remove all remaining `age.secrets.*` wiring, the `ragenix.nixosModules.default` /
      `ragenix.nixosModules.default` darwin equivalent imports, and `modules/common/secrets.nix`
      (ragenix identity paths) — replaced by whatever Phase 1 Step 7 decided for host identity.
- [ ] **Step 23**: remove the `ragenix` flake input and devShell package entirely.
- [ ] **Step 24**: delete the old `.age` files from both secrets repos (only once confirmed
      unreferenced anywhere).

## Phase 7 — Documentation rewrite

- [ ] **Step 25**: rewrite `ARCHITECTURE.md` §4 (Secrets architecture — model, lifecycle
      diagram, invariants) to describe the SOPS-based model instead of agenix.
- [ ] **Step 26**: rewrite `CLAUDE.md`'s secrets sections (the "Secrets" section and "Wiring an
      external secrets repo into nixie" subsection) to match.
- [ ] **Step 27**: update each secrets repo's own `CLAUDE.md`/`README.md` similarly.

## Phase 8 — Final decision

- [ ] **Step 28**: full review of the branch's diff against `main`, confirm every phase above
      validated cleanly with no known-broken hosts.
- [ ] **Step 29**: **decision point** — keep or revert?
      - **If keeping**: merge `sops-nix-migration` into `main` (squash or merge commit, your
        call), push, and update `ARCHITECTURE.md`'s "Latest releases" table / cut a release
        per the usual convention.
      - **If not keeping**: discard the branch (`git branch -D sops-nix-migration` after
        checking out `main`); `main` was never touched, so no cleanup needed there.
