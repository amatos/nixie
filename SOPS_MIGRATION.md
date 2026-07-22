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
        6/Step 24) and reusing infrastructure every host already has
        (`/etc/ssh/ssh_host_ed25519_key`) instead of provisioning and rotating a second, parallel
        identity. sops-nix's `sops.age.sshKeyPaths` option consumes the SSH host key directly at
        activation time, converting it internally to a plain X25519 age identity; the recipient
        side of `.sops.yaml` needs each host's **`ssh-to-age`-derived `age1...` string**
        (`ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub`), matching what sops-nix's
        `sops-install-secrets` computes internally — confirmed directly from its own log output
        during Step 10's real deploy. (Step 9's PoC briefly went down a wrong path here — see its
        notes for the full story of a red herring and the correction — but this is confirmed
        correct as of Step 10.) This replaces the `codex`/`gammu`/`porkchop`/`huginn`/`muninn`
        anchors currently in `.sops.yaml` (Step 5) — those were transcribed from
        `nix-secrets/secrets.nix`'s existing ragenix host keys and will need re-deriving via
        `ssh-to-age` for each host before Phase 3 (Step 12+) encrypts anything for real (`codex`'s
        anchor is already done, see Step 9). Coupling secret-decryption identity to the SSH host
        key's lifecycle is an accepted tradeoff: rotating a host's SSH host key would now also
        require re-encrypting its secrets, which doesn't happen today.

## Phase 2 — Proof of concept on one low-risk secret

- [x] **Step 9**: migrate exactly one low-stakes secret end-to-end — recommend a
      `ghostty-themes/*.age` file (cosmetic, no boot-time dependency, nothing breaks if this
      goes wrong). Encrypt it under SOPS per the Phase 1 decisions, wire
      `sops.secrets.<name>` on one real host **alongside** (not replacing) the existing
      `age.secrets.<name>` for the same content.
      - **Blocker hit, then resolved.** Used `codex` as the one real host (this repo happens to
        run on codex itself, so its real SSH host key was available locally without needing
        remote access to another fleet host).
      - **Root cause, first (wrong) diagnosis**: initially concluded the standalone `ssh-to-age`
        CLI's ed25519→X25519 conversion (it depends only on `filippo.io/edwards25519`, not
        `filippo.io/age`) was incompatible with `age`/`sops`'s own, based on `age -d -i
        host_key`/`sops -d` with `SOPS_AGE_SSH_PRIVATE_KEY_FILE` both failing to decrypt a file
        encrypted to the `ssh-to-age`-derived recipient. Switched `.sops.yaml`'s `*codex_ssh`
        anchor to the raw `ssh-ed25519 AAAA...` public key string instead (which *did* decrypt
        via plain `sops -d`/`age -d -i`), and shipped that.
      - **That fix was wrong, found via Step 10's real deploy.** Running the actual
        `darwin-rebuild switch` on codex, sops-nix's real deploy-time tool
        (`sops-install-secrets`, driven by `sops.age.sshKeyPaths`) logged: `Imported
        /etc/ssh/ssh_host_ed25519_key as age key with fingerprint
        age1dq4gttszvhkf5j6kcvquggnc7a4vxrwgyk6k4ldxmmpekc7pzupqegqrdm` — the *exact* fingerprint
        `ssh-to-age` computes. So `ssh-to-age`'s conversion was right all along, and the earlier
        manual test wasn't a conversion bug — it was pairing an inconsistent stanza type: `age -R
        host_key.pub`/`-i host_key` (or a raw ssh-ed25519 recipient string) creates/unwraps an
        **SSH-specific** ciphertext stanza, while `age -r <age1... string>` creates a **generic
        X25519** stanza; `-i sshkey`-style identity loading only unwraps the SSH-specific kind,
        regardless of whether the underlying key math matches. `sops-install-secrets` doesn't use
        that SSH-specific stanza path at all — it converts the SSH key to a plain X25519 age
        identity internally (matching `ssh-to-age`'s output) and needs a plain `age1...` recipient
        in the file to match against. Reverted `.sops.yaml`'s `*codex_ssh` anchor back to
        `age1dq4gttszvhkf5j6kcvquggnc7a4vxrwgyk6k4ldxmmpekc7pzupqegqrdm`, re-encrypted
        `ghostty-themes.yaml`, and Step 10 (below) confirms this is actually correct.
      - **Lesson for the rest of the migration**: when precomputing a host's age recipient from
        its SSH key for `.sops.yaml`, use `ssh-to-age -i <host>.pub` (the converted `age1...`
        form) — not the raw SSH public key string. Validate any such recipient against a real
        `darwin-rebuild`/`nixos-rebuild switch` (or at least the built
        `config.system.build.sops-nix-manifest` + a manual `sops-install-secrets` run), not just
        plain `sops -d`/`age -d` CLI testing — the two tools don't exercise the same code path
        for SSH keys, so success in one doesn't guarantee success in the other.
      - **Wired**: added `sops-nix.darwinModules.sops` to codex's module list in `flake.nix`
        (alongside `darwintron`'s existing smoke-test entry) and
        `sops.secrets.ghostty-theme-dracula-sops-poc` to `hosts/darwin/codex/default.nix`
        (`sopsFile = "${nix-secrets}/ghostty-themes.yaml"`, `key = "dracula"`, deployed to a
        separate `dracula-sops-poc` path rather than the live theme file, so it sits alongside
        the existing `age.secrets.ghostty-theme-dracula` without disturbing it). Required adding
        `nix-secrets` to codex's module function args (wasn't previously used there).
- [x] **Step 10**: deploy to that one host. **Validate**: `sops`-decrypted file appears at the
      expected `/run/secrets/<name>` path with correct content/ownership/mode, and the
      consuming config (ghostty) still picks it up correctly.
      - Deployed for real via `sudo darwin-rebuild switch --flake .#codex --no-write-lock-file
        --override-input nix-secrets git+file:///Users/alberth/Projects/nix-secrets?ref=sops-nix-migration`
        (nix-secrets' commits aren't pushed, hence the override; run interactively by the user,
        not through the agent's sandboxed shell — an earlier attempt through the sandbox failed
        partway on an unrelated pre-existing OrbStack Group Container symlink step, apparently a
        macOS TCC Full Disk Access restriction specific to the sandboxed process, not a config
        issue). `/run/current-system` advanced to the new generation (40).
      - **Validated**: `/run/secrets/ghostty-theme-dracula-sops-poc` exists,
        `-r-------- alberth:staff`, mode `0400`, content byte-identical to the original
        `nix-secrets/ghostty-themes/dracula` plaintext (`diff` clean).
        `~/.config/ghostty/themes/dracula-sops-poc` correctly symlinks to it. (Deployed to this
        separate PoC path rather than the live `dracula` theme file on purpose — see Step 9's
        wiring notes — so "consuming config still picks it up" wasn't separately re-validated
        against the live ghostty config in this PoC; the file landing correctly with the right
        content/ownership/mode is what Step 10 asks to validate.)
- [x] **Step 11**: **checkpoint** — does this prove the pipeline end-to-end (encryption,
      recipient resolution, deploy-time decryption, correct file permissions)? If not, stop and
      resolve before any further migration. This is the natural point to bail cheaply if the
      pipeline doesn't feel right.
      - **Yes.** Encryption (Step 9), recipient resolution (`.sops.yaml` creation_rules scoped
        correctly per group), deploy-time decryption (real `darwin-rebuild switch`, real
        `sops-install-secrets`), and correct file permissions (`0400`, `alberth:staff`) are all
        confirmed on a real host. Proceed to Phase 3.

## Phase 3 — Migrate `nix-secrets` in batches (one recipient-group at a time)

Each step: encrypt under SOPS, wire `sops.secrets.*` alongside the existing `age.secrets.*`,
deploy, validate the consuming service still works, *then* remove the old `age.secrets.*`
wiring and `.age` file for that batch only once the SOPS version is proven on every host that
needs it. Do not batch multiple groups together.

- [x] **Step 12**: `smtpSmartRelays` group (`smtp-relay-sasl`) — validate on porkchop and huginn
      (send a real test email through each, matching the validation approach used in the
      porkchop migration's Stage 5/6).
      - `porkchop`/`huginn` real SSH host keys derived via `ssh-to-age` (reachable directly from
        codex over Tailscale — `ssh-keyscan -t ed25519 <host>.ts.matos.cc`, no remote access
        needed). `nix-secrets`: added `*porkchop_ssh`/`*huginn_ssh` anchors (separate from the
        shared legacy `*porkchop`/`*huginn` ragenix anchors, still used by other
        not-yet-migrated rules) and a dedicated `smtp-relay-sasl.yaml` creation_rule; encrypted
        with the real credential content.
      - Deploying required `nixos-rebuild` via `nix run nixpkgs#nixos-rebuild --` (not installed
        by default on darwin) with `--elevate=sudo --ask-elevate-password` (`--use-remote-sudo`
        is deprecated) run interactively by the user for the sudo prompt — my sandboxed shell
        has no live TTY the user can type a password into, so this step always needed the user
        directly, same as codex's darwin-rebuild switch earlier.
      - **Validated twice**: once with `sops.secrets.smtp-relay-sasl-sops` wired *alongside*
        `age.secrets.smtp-relay-sasl` (`nixie.smtpRelay.saslSecretPath` repointed at it — user
        confirmed OK to cut over live, nothing was using the relays at the time) — real test
        emails via `sendmail` on both hosts, confirmed `status=sent (250 2.0.0 Ok)` in each
        host's postfix log. Then again after fully removing the agenix wiring (see below) — same
        `status=sent` result on both, proving the cutover holds with no fallback path left.
      - **agenix wiring removed**: `modules/common/smtp-relay-secrets.nix` now declares
        `sops.secrets.smtp-relay-sasl` directly (no more `age.secrets`), using
        `restartUnits = [ "postfix.service" ]` in place of the old
        `systemd.services.postfix.after/wants = ["agenix.service"]` (no explicit boot-ordering
        dependency turned out to be needed — sops-nix installs secrets via the same
        activation-script phase NixOS itself uses, which completes before services start).
        `smtp-relay-sasl.age` deleted from `nix-secrets`, along with its now-dead
        `smtpSmartRelays` binding in `secrets.nix`.
- [x] **Step 13** (PoC scope only — see below): `ldapHosts` group (`ldap/admin-password`,
      `ldap/kdc-password`, `ldap/krb5-master-key`) — **highest-consequence step in this phase**:
      these are boot-time secrets for muninn's KDC/LDAP. Validate with a full
      `kinit`/`ldapwhoami` check on muninn, matching the depth of validation used in the original
      Kerberos+LDAP migration, before removing the agenix version.
      - **Structural finding, changed this step's scope**: unlike `smtp-relay-sasl`/
        `grafana-secret-key` (declared directly in `nixie`'s own modules), these three secrets
        are consumed by `age.secrets.{krb5MasterKey,kdcLdapPassword,ldapAdminPassword,
        ldapKdcPassword}` declared *inside the external `nix-kerberos-ldap` repo's own module
        code* (`modules/kerberos.nix`, `modules/ldap.nix`). Switching that to `sops.secrets.*` is
        explicitly Phase 5's job (Steps 22–23), not this one — so the real
        `kinit`/`ldapwhoami`-against-the-live-service validation this step originally called for
        isn't reachable without either doing Phase 5 early, or scoping this step down. User chose
        to scope it down: PoC-only for now (matching Step 9's pattern), full cutover deferred to
        Phase 5 in its planned order.
      - Confirmed all three secrets are plain text (no non-printable bytes — checked before
        assuming, per user instruction to verify this for `nix-keytabs-matos-cc`/
        `nix-kerberos-ldap` too when those phases come up) and consolidated into a single
        `ldap.yaml` (Step 7 decision), preserving exact original bytes (including trailing
        newlines, via YAML block-literal style — a quoted-flow-scalar + `tr -d '\n'` approach
        used for Step 12/16 would have silently dropped them, harmlessly there but not verified
        safe here). Scoped to `users` + muninn's real `ssh-to-age` key (`*muninn_ssh`, separate
        from the legacy `*muninn` ragenix anchor, which stays for the old per-file secrets).
      - Deployed to muninn as three side-path PoC secrets (`ldap-admin-password-sops-poc`, etc.)
        — not wired into the live KDC/LDAP config at all. `sops-install-secrets` imported
        `/etc/ssh/ssh_host_ed25519_key` with fingerprint exactly matching `*muninn_ssh`; agenix's
        existing KDC/LDAP secrets decrypted and the live service was untouched. All three PoC
        secrets landed with correct `0400 root:root` permissions, matching the manifest exactly;
        content was already verified byte-identical to the original `.age` files before
        encryption. Full live-service cutover validation (`kinit`/`ldapwhoami`) is Phase 5's job.
- [x] **Step 14**: `unifiBackupHosts` group (`unifi/backup-ssh-key`) — validate the unifi-backup
      service on porkchop still runs successfully.
      - Confirmed plain printable text (OpenSSH's PEM/base64 armor) before encrypting. Caught a
        real bug by diffing the round-trip before moving on: the original key file had a
        trailing blank line, and YAML's default `|` (clip) block-scalar chomping silently
        stripped it — fixed by using `|+` (keep) instead, preserving the exact original bytes.
      - Scoped to `users` + porkchop's real `ssh-to-age` key (`*porkchop_ssh`).
      - **Validated three times, escalating**: (1) wired `sops.secrets.unifi-backup-ssh-key-sops-poc`
        alongside `age.secrets.unifi-backup-ssh-key`, then manually ran the exact `scp`
        invocation the service uses (against the real `unifi.home.matos.cc` gateway, into a
        throwaway `/tmp` directory) — succeeded (exit 0). (2) Converted
        `modules/common/unifi-backup-secrets.nix` to `sops.secrets` directly (`restartUnits =
        ["unifi-backup.service"]`), repointed the hardcoded `-i /run/agenix/...` path in
        `modules/nixos/unifi-backup.nix`, deleted `unifi/backup-ssh-key.age` and its
        `secrets.nix`/`.sops.yaml` entries. (3) Redeployed — `sops-nix`'s `restartUnits`
        mechanism actually *started* `unifi-backup.service` as part of the switch (it wasn't
        running before), and it completed with `status=0/SUCCESS`, landing fresh backup files —
        the real, live, scheduled service validated end-to-end, not just a manual test.
      - One manual-test-only false alarm along the way: an SSH-agent artifact
        (`sign_and_send_pubkey: ... communication with agent failed`) from testing over a nested
        SSH session — resolved with `env -u SSH_AUTH_SOCK` / `-o IdentityAgent=none` on the test
        invocation; irrelevant to the real systemd service, which has no interactive agent.
- [x] **Step 15**: `remoteBuildHosts` group (`builder/codex-ssh-key`) — validate a remote build
      from codex to gammu still works.
      - Confirmed the classifier block from earlier (SSH private key material specifically gets
        flagged, unlike lower-sensitivity secrets) — the user ran the decrypt directly and handed
        off the resulting plaintext file, which unblocked everything downstream (reading/
        re-encrypting an already-decrypted file wasn't flagged, only the initial decrypt was).
        Confirmed plain printable text (OpenSSH PEM/base64 armor) before encrypting, preserving
        exact original bytes (`|+` keep-chomping, same lesson as Step 14).
      - Scoped to `users` + codex's real `ssh-to-age` key (`*codex_ssh`, already derived in
        Step 9/10).
      - Converts `modules/darwin/remote-build-client.nix` from `age.secrets` to `sops.secrets`
        directly, pointing at the same `/etc/nix/remotebuild_ed25519` path `/etc/nix/machines`
        already references — no other change needed there. Deployed locally to codex (no remote
        sudo needed, since this only touches codex itself).
      - **Validated with a real remote build**: `nix build
        .#nixosConfigurations.gammu.config.system.build.toplevel` (overridden to the local
        `nix-secrets` branch) completed successfully, with multiple derivations visibly building
        `on 'ssh-ng://remotebuild@gammu.ts.matos.cc'` — the actual remote-build path, using the
        SOPS-sourced key, with `agenix`'s wiring for this secret already fully removed.
- [x] **Step 16**: `grafanaHosts` group (`grafana-secret-key`) — validate Grafana still starts
      on porkchop with the SOPS-sourced secret.
      - `nix-secrets`: encrypted `grafana-secret-key.yaml` under a new `porkchop_ssh`-scoped rule
        (content decrypted from the existing `.age` via the no-PIN/no-touch YubiKey identity).
        Also added a `*yubikey_0634d1c4` anchor to `.sops.yaml` and to this rule and Step 12's —
        that identity (see memory) was added to `nix-secrets/secrets.nix`'s `users` group after
        `.sops.yaml` was first drafted in Step 5, so it wasn't in sync; now it is, and it's
        usable for non-interactive validation going forward.
      - Hit a GPG signing blocker along the way: the signing key's subkey had expired
        (2026-07-05) — it lives on a YubiKey and needs a PIN/touch the agent can't supply
        non-interactively, so every commit failed until the user was back to handle it directly.
        Nothing was lost; changes just sat staged until then.
      - **Validated twice**, same as Step 12: once with `sops.secrets.grafana-secret-key-sops`
        wired *alongside* `age.secrets.grafanaSecretKey`
        (`services.grafana.settings.security.secret_key` overridden with `lib.mkForce`, since
        that module sets it as a plain assignment, not `mkDefault`) — Grafana's `/api/health`
        returned `HTTP 200`/`"database": "ok"`, with `currentprovider=secretKey.v1` in the logs
        confirming it used the SOPS-sourced key. Then again after fully removing the agenix
        wiring — same `HTTP 200` result.
      - **agenix wiring removed**: `modules/nixos/syslog-server.nix` now declares
        `sops.secrets.grafanaSecretKey` directly (no more `age.secrets`, no more host-level
        `mkForce` override needed), using `restartUnits = [ "grafana.service" ]`.
        `grafana-secret-key.age` deleted from `nix-secrets`, along with its now-dead
        `grafanaHosts` binding in `secrets.nix`.
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
      - **Groundwork already done in Step 13**: `nix-secrets/ldap.yaml` exists (consolidated
        `admin-password`/`kdc-password`/`krb5-master-key`, byte-identical to the originals),
        `.sops.yaml` already has a `*muninn_ssh`-scoped rule for it, and muninn already has
        `sops-nix.nixosModules.sops` in its module list (`flake.nix`) and three PoC secrets
        wired to side paths (`hosts/nixos/muninn/default.nix`) proving the pipeline works. This
        step just needs the module code itself switched over — point
        `age.secrets.ldapAdminPassword`/etc. (currently in `nix-kerberos-ldap`'s own
        `modules/ldap.nix`/`modules/kerberos.nix`) at `sops.secrets.*` reading the same
        `ldap.yaml` keys, then remove Step 13's now-redundant PoC secrets from muninn's config.
- [ ] **Step 23**: bump `nixie`'s `flake.lock` for `nix-kerberos-ldap` to the new branch's
      revision (temporary, branch-to-branch reference during the experiment — resolved to a
      normal `main`-to-`main` reference in Phase 8 if kept). Validate muninn's full KDC/LDAP
      stack against the updated module — this is where the `kinit`/`ldapwhoami` check deferred
      from Step 13 actually happens.

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
