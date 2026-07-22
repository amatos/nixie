# Experiment: migrate secrets from ragenix/age to sops-nix

Tracked on the `sops-nix-migration` branch — in **five** repos, not just this one (see Phase 0
Step 2). Deliberately not merged into any of their `main` branches until a final decision is
made (last phase below). If this experiment is abandoned, discard all five branches and none of
this ever touches any repo's `main`.

**Affected repos** (every repo that references `age.secrets`, `ragenix`, or a `/run/agenix/*`
path, checked directly rather than assumed):

| Repo | Why it's affected | `sops-nix-migration` branch created? |
| --- | --- | --- |
| `nixie` | Consumes `age.secrets.*` throughout; owns the `ragenix` flake input | [x] (this repo) |
| `nix-secrets` | Text secrets repo — Phase 3 migrates its content | [ ] |
| `nix-keytabs-matos-cc` | Binary keytabs repo — Phase 4 migrates its content | [ ] |
| `nix-kerberos-ldap` | External module consumes `age.secrets.ldapAdminPassword` etc. directly — Phase 5 | [ ] |
| `nix-home-alberth` | `alberth/common/packages.nix` installs the `ragenix` CLI; `alberth/common/cachix.nix` hardcodes `/run/agenix/cachix-authtoken`; `alberth/default.nix` symlinks the YubiKey identity stub for interactive `ragenix`/`age` use | [ ] |

See the proposal discussed in chat for full background/rationale and the areas-of-concern list.
This file is the actionable checklist version of that proposal.

**How to use this checklist**: each step is a single atomic unit of work — implement it,
validate it against its own criteria, then check it off before starting the next one. Steps may
be executed days apart, possibly in a session with no memory of this discussion — every entry
is written to stand on its own.

---

## Phase 0 — Branch setup

- [x] **Step 1**: create the `sops-nix-migration` branch off `main` in `nixie`, clean working
      tree.
- [ ] **Step 2**: create a matching `sops-nix-migration` branch (off a clean `main`) in each of
      the other four affected repos — `nix-secrets`, `nix-keytabs-matos-cc`, `nix-kerberos-ldap`,
      `nix-home-alberth` — even before there's any content to put on them. Keeps every repo
      individually revertible from Step 1 onward, rather than only nixie. Update the table
      above once done.
- [ ] **Step 3**: add `sops-nix` (Mic92/sops-nix) as a flake input in `flake.nix`. Add
      `sops-nix.nixosModules.sops` to one low-stakes NixOS host's module list first (recommend
      `ephemeraltron` or `darwintron`, the CI build targets — no real secrets, pure eval/build
      smoke test) before touching any real host. **Validate**: `nix flake check` /
      `nix eval .#nixosConfigurations.<test-host>.config.system.build.toplevel.drvPath`
      succeeds with the module present but unused.
- [ ] **Step 4**: add `sops`, `age`, `ssh-to-age` (and keep `age-plugin-yubikey`) to the
      devShell in `flake.nix`, alongside (not replacing) the existing `ragenix` package.
      **Validate**: `nix develop` succeeds, all four tools are on `PATH`.
- [ ] **Step 5**: create a `.sops.yaml` at the repo root (or within whichever secrets repo ends
      up hosting it — see the Phase 1 decision point) with age recipients transcribed from the
      current `nix-secrets/secrets.nix` groups (`users`, `systems`, `ldapHosts`,
      `syncthingHosts`, `unifiBackupHosts`, `smtpSmartRelays`, `remoteBuildHosts`,
      `grafanaHosts`) as YAML anchors + `creation_rules` `path_regex` entries. No real secret
      encrypted yet. **Validate**: `sops --config .sops.yaml -e --input-type binary
      --output-type binary /dev/null` (or a throwaway test file matching one rule's path
      pattern) round-trips: encrypt then `sops -d` successfully, content matches.

## Phase 1 — Decisions before migrating real secrets

- [ ] **Step 6**: decide **one repo or two**: does `nix-keytabs-matos-cc` stay separate (SOPS's
      binary mode removes the original technical reason for the split, but there may be
      access-control/workflow reasons to keep it), or fold into `nix-secrets`? Record the
      decision here before Step 9.
      - Decision: `_______________`
- [ ] **Step 7**: decide **file granularity for text secrets**: keep one file per secret
      (mirroring today's structure, simplest mechanical migration) or consolidate into fewer
      multi-key YAML files per recipient-group (the option SOPS's structured-value model
      actually enables)? Record the decision here before Step 9.
      - Decision: `_______________`
- [ ] **Step 8**: decide **host identity source**: keep generating a dedicated per-host age key
      via `modules/common/age-host-key.nix` (as today), or switch to deriving it from the
      existing SSH host key via `ssh-to-age` (removes a custom module, couples secret-decryption
      identity to the SSH host key's lifecycle instead)? Record the decision here before Step 10.
      - Decision: `_______________`

## Phase 2 — Proof of concept on one low-risk secret

- [ ] **Step 9**: migrate exactly one low-stakes secret end-to-end — recommend a
      `ghostty-themes/*.age` file (cosmetic, no boot-time dependency, nothing breaks if this
      goes wrong). Encrypt it under SOPS per the Phase 1 decisions, wire
      `sops.secrets.<name>` on one real host **alongside** (not replacing) the existing
      `age.secrets.<name>` for the same content.
- [ ] **Step 10**: deploy to that one host. **Validate**: `sops`-decrypted file appears at the
      expected `/run/secrets/<name>` path with correct content/ownership/mode, and the
      consuming config (ghostty) still picks it up correctly.
- [ ] **Step 11**: **checkpoint** — does this prove the pipeline end-to-end (encryption,
      recipient resolution, deploy-time decryption, correct file permissions)? If not, stop and
      resolve before any further migration. This is the natural point to bail cheaply if the
      pipeline doesn't feel right.

## Phase 3 — Migrate `nix-secrets` in batches (one recipient-group at a time)

Each step: encrypt under SOPS, wire `sops.secrets.*` alongside the existing `age.secrets.*`,
deploy, validate the consuming service still works, *then* remove the old `age.secrets.*`
wiring and `.age` file for that batch only once the SOPS version is proven on every host that
needs it. Do not batch multiple groups together.

- [ ] **Step 12**: `smtpSmartRelays` group (`smtp-relay-sasl`) — validate on porkchop and huginn
      (send a real test email through each, matching the validation approach used in the
      porkchop migration's Stage 5/6).
- [ ] **Step 13**: `ldapHosts` group (`ldap/admin-password`, `ldap/kdc-password`,
      `ldap/krb5-master-key`) — **highest-consequence step in this phase**: these are boot-time
      secrets for muninn's KDC/LDAP. Validate with a full `kinit`/`ldapwhoami` check on muninn,
      matching the depth of validation used in the original Kerberos+LDAP migration, before
      removing the agenix version.
- [ ] **Step 14**: `unifiBackupHosts` group (`unifi/backup-ssh-key`) — validate the unifi-backup
      service on porkchop still runs successfully.
- [ ] **Step 15**: `remoteBuildHosts` group (`builder/codex-ssh-key`) — validate a remote build
      from codex to gammu still works.
- [ ] **Step 16**: `grafanaHosts` group (`grafana-secret-key`) — validate Grafana still starts
      on porkchop with the SOPS-sourced secret.
- [ ] **Step 17**: remaining `users ++ systems`-scoped fleet-wide secrets (`github/ssh-key`,
      `github/ratelimit`, `luadns.ini`, `tailscale-authkey`, `cachix-authtoken`,
      `default-nixos-user-password`, `unifi/api-key`, `users/alberth`, `users/nixos`,
      `syncthing-gui-password`, all `ghostty-themes/*` not already done in Step 9) — can likely
      go in one or two batches given they share the same recipient set, but still validate on
      at least two representative hosts (one NixOS, one darwin) before removing the agenix
      versions.
- [ ] **Step 18**: **`nix-home-alberth` update, in lockstep with `cachix-authtoken` in Step
      17**: `alberth/common/cachix.nix` hardcodes `secret="/run/agenix/cachix-authtoken"` —
      change to sops-nix's runtime path (`/run/secrets/cachix-authtoken` by default, or whatever
      Step 8's identity-source decision implies). Commit on `nix-home-alberth`'s own
      `sops-nix-migration` branch. **Validate**: `~/.config/cachix/cachix.dhall` still gets
      written correctly with the right token after a home-manager activation.

## Phase 4 — Migrate `nix-keytabs-matos-cc`

- [ ] **Step 19**: migrate one host's keytab as proof — recommend `keytab-codex.age` (lowest
      consequence: codex losing its keytab briefly just means a Kerberos client hiccup, not a
      KDC/LDAP outage). Use SOPS's binary mode (`--input-type binary --output-type binary`).
      Validate `kinit -k -t /etc/krb5.keytab host/codex.matos.cc` still works.
- [ ] **Step 20**: migrate the remaining host keytabs (`keytab-gammu`, `keytab-porkchop`,
      `keytab-huginn`, `keytab-muninn`) one at a time, validating `kinit -k` on each.
- [ ] **Step 21**: migrate the LDAP SASL keytabs (`keytab-ldap-porkchop`, `keytab-ldap-muninn`)
      — validate the full GSSAPI LDAP bind chain (`ldapwhoami -Y GSSAPI`) still works on both,
      given how much debugging that exact path took to get right originally.

## Phase 5 — External module coordination

- [ ] **Step 22**: update `nix-kerberos-ldap`'s `ldap.nix`/`kerberos.nix` to consume
      `sops.secrets.*` instead of `age.secrets.*`, on its own `sops-nix-migration` branch
      (created in Step 2).
- [ ] **Step 23**: bump `nixie`'s `flake.lock` for `nix-kerberos-ldap` to the new branch's
      revision (temporary, branch-to-branch reference during the experiment — resolved to a
      normal `main`-to-`main` reference in Phase 8 if kept). Validate muninn's full KDC/LDAP
      stack against the updated module.

## Phase 6 — Fleet-wide agenix removal

- [ ] **Step 24**: once every secret has a validated SOPS counterpart on every host that needs
      it, remove all remaining `age.secrets.*` wiring, the `ragenix.nixosModules.default` /
      darwin equivalent imports, and `modules/common/secrets.nix` (ragenix identity paths) —
      replaced by whatever Phase 1 Step 8 decided for host identity.
- [ ] **Step 25**: remove the `ragenix` flake input and devShell package entirely from `nixie`.
- [ ] **Step 26**: **`nix-home-alberth` cleanup**: remove the `ragenix` package from
      `alberth/common/packages.nix`, add `sops` in its place if useful for interactive use.
      Re-check `alberth/default.nix`'s YubiKey identity-stub symlink comment ("so ragenix and
      age tools find it") — the symlink itself likely still applies unchanged (sops with age
      recipients uses the same `age-plugin-yubikey` identity files), but the comment referencing
      ragenix specifically should be updated for accuracy.
- [ ] **Step 27**: delete the old `.age` files from both secrets repos (only once confirmed
      unreferenced anywhere).

## Phase 7 — Documentation rewrite

- [ ] **Step 28**: rewrite `ARCHITECTURE.md` §4 (Secrets architecture — model, lifecycle
      diagram, invariants) to describe the SOPS-based model instead of agenix.
- [ ] **Step 29**: rewrite `CLAUDE.md`'s secrets sections (the "Secrets" section and "Wiring an
      external secrets repo into nixie" subsection) to match.
- [ ] **Step 30**: update each of the other four repos' own `CLAUDE.md`/`README.md` similarly
      (`nix-secrets`, `nix-keytabs-matos-cc`, `nix-kerberos-ldap`, `nix-home-alberth`).

## Phase 8 — Final decision

- [ ] **Step 31**: full review of all five branches' diffs against their respective `main`
      branches, confirm every phase above validated cleanly with no known-broken hosts.
- [ ] **Step 32**: **decision point** — keep or revert? This is a single decision covering all
      five repos together (they're not independently useful mid-migration — e.g. nixie's
      `sops-nix-migration` branch depends on the others' branches while the experiment is live).
      - **If keeping**: merge each repo's `sops-nix-migration` branch into its own `main`
        (squash or merge commit, your call) in dependency order — secrets repos and
        `nix-kerberos-ldap` first, then `nixie` (re-pointing its `flake.lock` references from
        the other repos' branches back to their `main`s), then `nix-home-alberth`. Push each,
        then update `ARCHITECTURE.md`'s "Latest releases" table / cut a release in each per the
        usual convention.
      - **If not keeping**: discard all five branches (`git branch -D sops-nix-migration` after
        checking out `main` in each repo); no repo's `main` was ever touched, so no cleanup
        needed anywhere.
