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
| `nix-secrets` | Text secrets repo — Phase 3 migrates its content | [x] |
| `nix-keytabs-matos-cc` | Binary keytabs repo — Phase 4 migrates its content | [x] |
| `nix-kerberos-ldap` | External module consumes `age.secrets.ldapAdminPassword` etc. directly — Phase 5 | [x] |
| `nix-home-alberth` | `alberth/common/packages.nix` installs the `ragenix` CLI; `alberth/common/cachix.nix` hardcodes `/run/agenix/cachix-authtoken`; `alberth/default.nix` symlinks the YubiKey identity stub for interactive `ragenix`/`age` use | [x] |

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
- [x] **Step 2**: create a matching `sops-nix-migration` branch (off a clean `main`) in each of
      the other four affected repos — `nix-secrets`, `nix-keytabs-matos-cc`, `nix-kerberos-ldap`,
      `nix-home-alberth` — even before there's any content to put on them. Keeps every repo
      individually revertible from Step 1 onward, rather than only nixie. Update the table
      above once done.
- [x] **Step 3**: add `sops-nix` (Mic92/sops-nix) as a flake input in `flake.nix`. Add
      `sops-nix.nixosModules.sops` to one low-stakes NixOS host's module list first (recommend
      `ephemeraltron` or `darwintron`, the CI build targets — no real secrets, pure eval/build
      smoke test) before touching any real host. **Validate**: `nix flake check` /
      `nix eval .#nixosConfigurations.<test-host>.config.system.build.toplevel.drvPath`
      succeeds with the module present but unused.
      - Used `darwintron` (per instruction) instead of `ephemeraltron`. Since darwintron is a
        nix-darwin host, not NixOS, wired `sops-nix.darwinModules.sops` — the checklist's
        `nixosModules.sops` wording assumed the NixOS option; darwin needs its own module name.
        Validated with `nix flake check` and
        `nix eval .#darwinConfigurations.darwintron.config.system.build.toplevel.drvPath`, both
        clean.
- [x] **Step 4**: add `sops`, `age`, `ssh-to-age` (and keep `age-plugin-yubikey`) to the
      devShell in `flake.nix`, alongside (not replacing) the existing `ragenix` package.
      **Validate**: `nix develop` succeeds, all four tools are on `PATH`.
      - `age-plugin-yubikey` already lives fleet-wide in `modules/common/packages.nix`, not the
        devShell — left untouched. Validated `nix develop --command which sops age ssh-to-age
        ragenix`, all four resolved.
- [x] **Step 5**: create a `.sops.yaml` at the repo root (or within whichever secrets repo ends
      up hosting it — see the Phase 1 decision point) with age recipients transcribed from the
      current `nix-secrets/secrets.nix` groups (`users`, `systems`, `ldapHosts`,
      `syncthingHosts`, `unifiBackupHosts`, `smtpSmartRelays`, `remoteBuildHosts`,
      `grafanaHosts`) as YAML anchors + `creation_rules` `path_regex` entries. No real secret
      encrypted yet. **Validate**: `sops --config .sops.yaml -e --input-type binary
      --output-type binary /dev/null` (or a throwaway test file matching one rule's path
      pattern) round-trips: encrypt then `sops -d` successfully, content matches.
      - Placed at nixie's repo root (Step 6/7 location decision still open). Encrypted a
        throwaway `ldap/scratch-test.txt` (deleted after) — the resulting file embedded exactly
        8 age recipients (alberth + 6 yubikeys + muninn), confirming the `ldapHosts`
        `path_regex` rule resolves independently of the fleet-wide catch-all (which would embed
        12). Actual decryption needs a physically-touched YubiKey (`age-plugin-yubikey`'s cached
        touch policy), unavailable non-interactively here, so full mechanics (encrypt → decrypt
        → content match) were verified separately with a throwaway self-generated age keypair
        outside the real recipient set — round-trip succeeded, content matched exactly.

## Phase 1 — Decisions before migrating real secrets

- [x] **Step 6**: decide **one repo or two**: does `nix-keytabs-matos-cc` stay separate (SOPS's
      binary mode removes the original technical reason for the split, but there may be
      access-control/workflow reasons to keep it), or fold into `nix-secrets`? Record the
      decision here before Step 9.
      - Decision: **one repo** — consolidate `nix-keytabs-matos-cc`'s content into `nix-secrets`.
        SOPS's binary mode (`--input-type binary --output-type binary`) removes the git-diff and
        plaintext-editing-workflow reasons the split existed for under agenix; no remaining
        reason to keep two repos once both are SOPS-encrypted. Phase 4 (Steps 19–21) migrates
        keytab content into `nix-secrets` rather than into a standalone
        `nix-keytabs-matos-cc`-on-SOPS repo; `nix-keytabs-matos-cc`'s own
        `sops-nix-migration` branch (created in Step 2) ends up unused and the repo itself is
        retired once Phase 4 completes and Phase 6 removes stale agenix wiring.
- [x] **Step 7**: decide **file granularity for text secrets**: keep one file per secret
      (mirroring today's structure, simplest mechanical migration) or consolidate into fewer
      multi-key YAML files per recipient-group (the option SOPS's structured-value model
      actually enables)? Record the decision here before Step 9.
      - Decision: **consolidate into one multi-key YAML file per recipient-group, where
        possible** — group secrets by the same recipient set they already share in
        `nix-secrets/secrets.nix` (`ldapHosts`, `unifiBackupHosts`, `smtpSmartRelays`,
        `remoteBuildHosts`, `grafanaHosts`, and the big `users ++ systems` bucket) into one
        `.yaml` per group, keyed by secret name. "Where possible" carves out an exception for
        secrets that can't cleanly share a file — e.g. `nix-keytabs-matos-cc`'s binary keytabs
        (Step 6: folding into `nix-secrets`) still need their own file each, since SOPS's
        structured multi-key model doesn't apply to opaque binary blobs the same way it does to
        text values. This maps directly onto the `.sops.yaml` `creation_rules` already drafted
        in Step 5 — each rule's recipient group becomes one consolidated file's `path_regex`
        target instead of matching many individual per-secret files.
- [x] **Step 8**: decide **host identity source**: keep generating a dedicated per-host age key
      via `modules/common/age-host-key.nix` (as today), or switch to deriving it from the
      existing SSH host key via `ssh-to-age` (removes a custom module, couples secret-decryption
      identity to the SSH host key's lifecycle instead)? Record the decision here before Step 10.
      - Decision: **derive from the existing SSH host key via `ssh-to-age`** — simplifies future
        work by removing a bespoke module (`modules/common/age-host-key.nix`, retired in Phase
        6/Step 24) and reusing infrastructure every host already has (`/etc/ssh/ssh_host_ed25519_key`)
        instead of provisioning and rotating a second, parallel identity. sops-nix's
        `sops.age.sshKeyPaths` option consumes the SSH host key directly (no manual `ssh-to-age`
        conversion step needed at activation time — sops-nix does it internally); the recipient
        side of `.sops.yaml` still needs each host's derived age public key, computed once via
        `ssh-to-age -i /etc/ssh/ssh_host_ed25519_key` (or `ssh-keyscan` + `ssh-to-age` remotely)
        per host, to replace the `codex`/`gammu`/`porkchop`/`huginn`/`muninn` anchors currently
        in `.sops.yaml` (Step 5) — those were transcribed from `nix-secrets/secrets.nix`'s
        existing ragenix host keys and will need re-deriving from each host's SSH key before
        Phase 3 (Step 12+) encrypts anything for real. Coupling secret-decryption identity to
        the SSH host key's lifecycle is an accepted tradeoff: rotating a host's SSH host key
        would now also require re-encrypting its secrets, which doesn't happen today.

## Phase 2 — Proof of concept on one low-risk secret

- [ ] **Step 9**: migrate exactly one low-stakes secret end-to-end — recommend a
      `ghostty-themes/*.age` file (cosmetic, no boot-time dependency, nothing breaks if this
      goes wrong). Encrypt it under SOPS per the Phase 1 decisions, wire
      `sops.secrets.<name>` on one real host **alongside** (not replacing) the existing
      `age.secrets.<name>` for the same content.
      - **IN PROGRESS, BLOCKED — see below.** Used `codex` as the one real host (this repo
        happens to run on codex itself, so its real SSH host key was available locally without
        needing remote access to another fleet host). Encryption half done: `nix-secrets`'
        `.sops.yaml` (moved there from nixie per Step 6) has a PoC `creation_rule` for
        `ghostty-themes.yaml` scoped to `users` + `*codex_ssh`
        (`age1dq4gttszvhkf5j6kcvquggnc7a4vxrwgyk6k4ldxmmpekc7pzupqegqrdm`, derived via
        `ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub`), and `ghostty-themes.yaml` itself
        has the real `dracula` theme content (from the plaintext at
        `nix-secrets/ghostty-themes/dracula` — untracked, **not committed**, still sitting on
        disk; decide whether to delete it) encrypted under that rule. Verified the encrypted
        file's embedded recipient list is exactly the intended 8 keys (`users` + codex), not
        the broader fleet-wide 12.
      - **Still not done**: wiring `sops.secrets.<name>` into codex's actual nix host config
        (`hosts/darwin/codex/`) — blocked on the finding below, no point wiring a secret that
        can't be proven to decrypt yet.
      - **Blocker — resolve before continuing**: decrypting `ghostty-themes.yaml`'s `dracula`
        key against codex's real SSH host private key fails, via *two independent paths*:
        `sops -d` with `SOPS_AGE_SSH_PRIVATE_KEY_FILE=/etc/ssh/ssh_host_ed25519_key`, and plain
        `age -d -i /etc/ssh/ssh_host_ed25519_key` against a fresh test message encrypted
        straight to the same recipient. Both fail with "no identity matched any of the
        recipients" — even though `ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key |
        age-keygen -y` (private key piped directly, never printed) reproduces the *exact same*
        public key computed from the `.pub` file. That's a contradiction: the same key, through
        two derivation paths, produces a recipient neither `sops` nor `age`'s own SSH-decrypt
        logic can open. Likely cause: an ed25519→X25519 conversion mismatch between the
        standalone `ssh-to-age` tool and `age`/`sops`'s built-in SSH support (there are
        historically two incompatible conversion conventions in this ecosystem for ed25519
        keys specifically). **Not yet tested**: sops-nix doesn't use plain `sops`/`age` for
        this at all — it ships its own `sops-install-secrets` Go binary
        (`sops-nix.packages.<system>.sops-install-secrets`, confirmed buildable) driven by a
        generated manifest, which is the actual code path used at real deploy time and may not
        share the same bug. Testing it needs a standalone manifest built outside the full
        module system — more involved, and touches private-key material further, which is
        worth doing carefully (ideally by a human with direct shell access) rather than by an
        agent working around sandboxing. **This must be resolved before Step 10** — if
        sops-nix's own decrypt path has the same mismatch, Step 8's decision (host identity via
        `ssh-to-age`) needs revisiting (e.g. recipients may need computing via sops-nix's own
        tooling instead of the standalone `ssh-to-age` binary, or a specific version pinning
        issue needs chasing down).
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
