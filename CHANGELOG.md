# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `modules/common/ghostty-theme-secrets.nix` — deploys the 8 commercial
  Ghostty theme files (`alucard`, `blade`, `buffy`, `dracula`, `lincoln`,
  `morbius`, `pro`, `van-helsing`) from `nix-secrets`'s new `ghostty-themes/`
  directory into `~/.config/ghostty/themes/`, replacing plaintext copies.
  Imported fleet-wide from `common-nixos.nix`/`common-darwin.nix`, matching
  the `github-secrets.nix`/`cachix-secrets.nix` pattern. `modules/nixos/
  ghostty-theme-tmpfiles.nix` pre-creates the themes directory with correct
  ownership on NixOS (systemd has no darwin equivalent, but the directory
  already exists there via home-manager's stylix ghostty integration) —
  same rationale as `github-secrets-tmpfiles.nix`.
- `direnv-instant` flake input (`github:Mic92/direnv-instant`), added to
  `modules/darwin/home-manager.nix` and `modules/nixos/home-manager.nix`
  `sharedModules` (matching the `nvf`/`qmd`/`stylix` pattern) — required for
  `nix-home-alberth`'s `alberth/common/tools.nix` to set
  `programs.direnv-instant.enable = true`. Without this module in
  `sharedModules`, evaluation fails with `The option
  'home-manager.users.alberth.programs.direnv-instant' does not exist`,
  hit on codex after `nix-home-alberth` picked up direnv-instant.
- `modules/common/development-packages.nix` — new module for development-only
  packages (`black`, `cmake`, `commitizen`, `commitlint`, `diff-so-fancy`,
  `doxygen`, `gnumake`, `imagemagick`, `inkscape`, `lazygit`, `nmap`,
  `pre-commit`, `prettier`, `pyenv`, `pylint`, `pyrefly`, `rbenv`,
  `shellcheck`, `yaml-language-server`, `yamllint`), wired only to
  `hosts/nixos/gammu/default.nix` and `hosts/darwin/codex/default.nix`.
- `hosts/nixos/gammu/default.nix` and `hosts/darwin/codex/default.nix` —
  added `pkgs.nixd` (Nix language server) to `environment.systemPackages`
  for editor tooling (Zed, nvf).
- `modules/nixos/syncthing-healthcheck.nix` — new watchdog timer, imported
  on gammu/huginn/porkchop, that polls Syncthing's GUI/REST API every 5
  minutes and restarts `syncthing.service` if it stops responding. Works
  around a failure mode where the GUI/API listener silently dies while the
  service stays `active` and sync itself keeps working, which broke
  `syncthing-init.service`/`syncthing-gui-password.service` activation on
  gammu and huginn during unrelated `nixos-rebuild switch` runs — see
  CLAUDE.md Syncthing conventions.
- `modules/nixos/certbot.nix` — new `nixie.certbot.xrdpDeploy` option,
  matching the existing `postfixDeploy`/`chronyDeploy`/`ldapDeploy`
  pattern: copies the renewed cert to `/var/lib/xrdp-tls/` (`root:xrdp
  640`) and restarts `xrdp.service` (not reload — xrdp has no cert-reload
  signal; `xrdp-sesman`, which owns live sessions, is a separate unit and
  is unaffected).
- `hosts/nixos/gammu/default.nix` — enabled `nixie.certbot.xrdpDeploy` and
  pointed `services.xrdp.sslCert`/`sslKey` at `/var/lib/xrdp-tls/`, so RDP
  now presents the real `gammu.ts.matos.cc` Let's Encrypt cert instead of
  xrdp's default self-signed one. The deploy hook only fires on an actual
  certbot renewal, so `/var/lib/xrdp-tls/` is empty (xrdp falls back to a
  self-signed cert there) until the next renewal or a manual `certbot
  certonly --cert-name gammu.home.matos.cc --force-renewal`.

### Changed

- `flake.nix` — renamed the `nixie-homes` flake input to `nix-home-alberth`
  (`github:amatos/nix-home-alberth`) and the `keytabs-matos-cc` input to
  `nix-keytabs-matos-cc` (`github:amatos/nix-keytabs-matos-cc`), following
  the same rename on GitHub. Threaded through `outputs`,
  `sharedSpecialArgs`, and every consuming host/module file (all
  `${keytabs-matos-cc}/...` interpolations, `nixie-homes.homeModules.*`
  references, and doc mentions in `CLAUDE.md`/`README.md`/`ARCHITECTURE.md`
  updated to match). `flake.lock` is intentionally untouched here — it
  still pins the old input names/URLs until `nix flake lock` is run after
  the GitHub-side rename actually happens; until then this repo's flake
  won't evaluate against the new names.
- `hosts/nixos/gammu/default.nix` and `README.md` — updated comments and
  the RDP/Remote Play docs to match `nix-home-alberth`'s rename of the
  `steamup` systemd user unit to `steam` (`alberth/gammu.nix`).
- `modules/common/packages.nix` — removed the 20 development-only packages
  listed above from `environment.systemPackages`; they now live in
  `modules/common/development-packages.nix` instead of being deployed
  fleet-wide.
- `hosts/darwin/template-darwin/default.nix` and
  `hosts/nixos/template-nixos/default.nix` — dropped unused function
  arguments (`pkgs`; `nix-home-alberth`, `userDefs`/`primaryUser`) flagged
  by `nixd`. `template-nixos`'s commented-out home overlay example still
  references `nix-home-alberth`/`primaryUser`; uncomment it and add the
  args back if that block is enabled.

---

## 26.07.13

### Added

- `users.nix` — added new ssh key to alberth

### Fixed

- `hosts/nixos/gammu/default.nix` — `services.xrdp.defaultWindowManager` now
  launches `startplasma-x11` under `dbus-run-session`, both referenced via
  their store paths. Plain `startplasma-x11` left RDP sessions at a black
  screen because xrdp's session doesn't start a D-Bus session bus itself,
  which Plasma's components need to come up.

---

## 26.07.12

### Added

- `flake.nix` — added `nixie-homes` (`github:amatos/nixie-homes`) as a real flake
  input (`inputs.nixpkgs`/`.home-manager`/`.nix-secrets`/`.nvf`/`.qmd`/`.stylix` all
  `.follows`-pinned to nixie's own), threaded through `outputs` and added to
  `sharedSpecialArgs`
- `flake.nix` — added `homebrew-cirruslabs-cli` (`github:cirruslabs/homebrew-cli`)
  and `homebrew-dracula-install` (`github:dracula/homebrew-install`) as
  `flake = false` inputs, threaded through `outputs` and `sharedSpecialArgs`
  (matching `homebrew-autoupdate`'s existing pattern); wired as new
  `nix-homebrew` taps on `codex` (`hosts/darwin/codex/default.nix`)
- `flake.nix` — devShell gained `pre-commit`, `commitlint`, `markdownlint-cli2`,
  and `direnv` packages (previously only available via the git hooks themselves,
  not on the devShell `$PATH` directly)
- `modules/common/packages.nix` — `environment.systemPackages` gained a large set
  of fleet-wide CLI tools: `bat`, `black`, `btop`, `chezmoi`, `cmake`,
  `commitizen`, `commitlint`, `cowsay`, `diff-so-fancy`, `direnv`, `dos2unix`,
  `doxygen`, `eza`, `fastfetch`, `fortune`, `fzf`, `gnumake`, `gnupg`, `htop`,
  `httpie`, `imagemagick`, `lazygit`, `lsd`, `nmap`, `prettier`, `pstree`,
  `pyenv`, `pylint`, `pyrefly`, `rbenv`, `ruby`, `sesh`, `shellcheck`,
  `starship`, `tealdeer`, `tmux`, `wget`, `yaml-language-server`, `yamllint`,
  `zoxide`; darwin gained `duti` and `mas` alongside the existing `dockutil`
  (see "Fixed" below — the first pass at this list had three package names
  that didn't evaluate; already corrected)
- `modules/darwin/home-manager.nix` — the `nixie-homes`-sourced home-manager
  base block, extracted out of `common-darwin.nix` (mirrors
  `modules/nixos/home-manager.nix`'s existing role on the NixOS side). Split
  out specifically so a darwin host can opt out of `nixie-homes` entirely by
  not importing it, without duplicating anything `common-darwin.nix`
  provides — see `hosts/darwin/nhcodex` below
- `hosts/darwin/nhcodex` — a lean test bed for future home-manager changes
  with zero `nixie-homes` involvement: imports `common-darwin.nix` directly
  (no duplication), skips `modules/darwin/home-manager.nix` and
  `codex/homebrew.nix` (the two places `nixie-homes` gets pulled in on
  darwin). `networking.hostName`/`computerName` stay `"codex"` — only the
  flake attribute name and host directory differ. `home-manager.darwinModules.
  home-manager` is in its module list, ready for `home-manager.users.alberth`
  to be set directly in this host's `default.nix` while experimenting

### Removed

- `home/` — deleted from this repo entirely; moved to the separate `nixie-homes`
  repo (`home/alberth` → `alberth/`), full git history carried over via
  `git filter-repo`; see "Changed" below

### Fixed

- `hosts/nixos/gammu/default.nix` — `services.xserver.enable = true` (needed
  for xrdp) silently defaults `services.xserver.displayManager.lightdm.enable`
  to `true` in nixpkgs' `xserver.nix` unless another display manager is
  enabled; only `sddm` was disabled, so lightdm became the actual display
  manager and started at boot via `graphical.target`, contradicting the
  comment claiming gammu boots to a text console. Confirmed via `nix eval
  .#nixosConfigurations.gammu.config.systemd.services.display-manager.script`
  (showed it exec'ing lightdm). Fixed by explicitly setting
  `services.xserver.displayManager.lightdm.enable = false;` alongside the
  existing `sddm.enable = false;`, which removes
  `systemd.services.display-manager` entirely rather than masking it.
  Confirmed via the same eval path (no `display-manager` key in
  `config.systemd.services` afterward) and a full `config.system.build.
  toplevel` evaluation
- `modules/common/packages.nix` — added `environment.shells = [ bashInteractive
  zsh fish nushell ]`. On NixOS, `programs.zsh`/`programs.fish` already added
  themselves to `environment.shells` automatically (and `programs.bash.enable`
  defaults to `true` fleet-wide), so nushell was the only real gap there. On
  darwin, none of `programs.zsh`/`fish`/`bash` add themselves to
  `environment.shells` — it's a separate, unset option — so `/etc/shells`
  wasn't managed at all and stayed at Apple's stock list; the nix-store fish
  that `users.users.${primaryUser}.shell` actually points to on darwin was
  missing from it entirely. Confirmed via `nix eval
  .#darwinConfigurations.codex.config.environment.shells` and
  `.#nixosConfigurations.gammu.config.environment.shells`
- `modules/common/packages.nix` — `environment.systemPackages` referenced three
  package attributes that don't exist in the pinned nixpkgs, breaking evaluation
  fleet-wide (this is a `modules/common/` file, imported by every host):
  `jenv` (removed — no such package, no obvious replacement), `make` → `gnumake`,
  `teeldear` → `tealdeer` (typo). Confirmed fixed via
  `nix eval .#darwinConfigurations.codex.config.environment.systemPackages`
  (now evaluates to 72 packages) and `nix build --dry-run` against every host
- `flake.nix` — `homebrew-cirruslabs-cli`/`homebrew-dracula-install` were declared
  as inputs but never threaded through `outputs` args or `sharedSpecialArgs`,
  breaking `codex` specifically (`error: attribute 'homebrew-cirruslabs-cli'
  missing`, since `hosts/darwin/codex/default.nix` takes it as a function
  argument). Found while re-verifying after the `packages.nix` fix above; fixed
  by adding both to the `outputs` function args and `sharedSpecialArgs`,
  matching every other input's existing pattern
- `modules/common/age-host-key.nix` — its activation script was registered
  as `system.activationScripts.generateAgeHostKey`, a custom-named script.
  Per the "darwin activation scripts" convention in `CLAUDE.md`,
  custom-named `system.activationScripts.<name>.text` blocks are silently
  never run on darwin (only the fixed, hardcoded stage list is). Confirmed
  via `nix eval
  .#darwinConfigurations.codex.config.system.activationScripts.script.text`
  — no trace of `generateAgeHostKey` or `/etc/age/host-key` generation in
  the assembled script. Net effect: darwin hosts (`codex`, `darwintron`)
  never actually got `/etc/age/host-key` generated by Nix, so ragenix's
  `age.identityPaths = [ "/etc/age/host-key" ]` (`modules/common/secrets.nix`)
  had nothing to decrypt with unless that file was created out-of-band.
  Fixed by branching on `pkgs.stdenv.isDarwin`: darwin now uses
  `system.activationScripts.extraActivation.text = lib.mkAfter "..."`
  (nix-darwin's real extension point, same fix already applied to the
  OrbStack/`ntp` scripts), while NixOS keeps the original
  `generateAgeHostKey`/`agenix.deps` mechanism unchanged. Verified darwin
  ordering is correct by tracing agenix's actual darwin implementation
  (`ryantm/agenix` `modules/age.nix`): darwin decryption has no
  `activationScripts` hook at all — it's a separate
  `launchd.daemons.activate-agenix` daemon, loaded during the `launchd`
  stage, which runs well after `extraActivation` (2nd stage overall) in
  nix-darwin's fixed sequence — confirmed directly in the assembled
  `codex` activation script (`launchctl load` for
  `org.nixos.activate-agenix.plist` appears ~1000 lines after the host-key
  generation).

### Changed

- `flake.nix` — edited input zapp to point to `zsa/zapp` repo
  (was `github:amatos/zapp/add-aarch64-darwin-support-for-nix-flake`), since
  the upstream PR was merged
- `modules/darwin/macos-defaults/dock/persistent-apps.nix` — removed `apps` from
  dock.
- `hosts/darwin/codex/homebrew.nix` — temporarily commented out `xcode` from
  `masApps` due to macOS 27 beta
- `hosts/darwin/common-darwin.nix` — no longer sets any `home-manager.*`
  option; that block moved to `modules/darwin/home-manager.nix` (see
  "Added"). `codex`, `darwintron`, and `template-darwin` each gained an
  explicit `../../../modules/darwin/home-manager.nix` import alongside
  `../common-darwin.nix` to keep their behavior unchanged — verified
  identical `home-manager.users.alberth` config before and after
- `hosts/darwin/codex/default.nix` — `nix-homebrew.enableRosetta` set to `false`
  (was `true`)
- `hosts/darwin/common-darwin.nix` — dropped `"@admin"` from
  `determinateNix.customSettings.trusted-users`, leaving just `"@staff"`
- `modules/common/packages.nix` — `nix.settings.trusted-users` changed `"@admin"`
  → `"@staff"`; the adjacent comment ("admin users are in 'admin', not 'wheel'")
  still describes the *old* value and now reads as stale — may be worth revisiting
- `modules/darwin/macos-defaults/dock/persistent-apps.nix` — pinned apps updated:
  added Orion, iPhone Mirroring, Siri; removed Google Chrome, Discord; dropped the
  section-header comments (Development & Tools / AI Assistants / notes on Ollama,
  RapidAPI, Postman, Bitwarden)
- `modules/darwin/macos-defaults/finder.nix` — `_FXShowPosixPathInTitle` enabled;
  `ColumnShowIcons` uncommented and enabled
- `modules/darwin/macos-defaults/system-ui.nix` — menu bar clock `ShowDate` set to
  "when space allows" (was "always"); screenshot save location moved to
  `~/Pictures/Screenshots/unsorted`; `BatteryShowPercentage` disabled
- `flake.nix` — dropped `x86_64-darwin` from `supportedSystems`. Only affects the
  dev-tooling matrix (`devShells`/`checks`/`formatter`/`preCommitCheck`, all driven
  by `forAllSystems`) — no darwin host declares `system = "x86_64-darwin"`, so no
  actual host configuration is affected
- Every `../../home/alberth`-style import replaced with
  `nixie-homes.homeModules.<name>`: `modules/nixos/home-manager.nix`,
  `hosts/darwin/common-darwin.nix`, `hosts/darwin/codex/default.nix`,
  `hosts/darwin/darwintron/default.nix`, `hosts/darwin/template-darwin/default.nix`,
  `hosts/darwin/codex/homebrew.nix` (script `readFile` path). Template/stub host
  comments (`template-nixos`, `picanha`, `sirloin`) updated to describe the new
  cross-repo workflow (add the overlay to `nixie-homes`, push it, then
  `nix flake lock --update-input nixie-homes`)
- `CLAUDE.md`/`README.md`/`ARCHITECTURE.md` — updated throughout for the home/
  removal above: removed all `home/alberth` references, documented the
  `nixie-homes` input and `homeModules` consumption pattern, reworked
  ARCHITECTURE.md's "three repos" framing (table, mermaid diagram, invariants,
  document map) to cover all four repos. Verified with `nix flake check` and
  `nix build --dry-run` against every `darwinConfigurations`/`nixosConfigurations`
  entry after the migration
- `LICENSE` — renamed to `LICENSE.md` for consistency across the `nixie`,
  `nix-secrets`, `keytabs-matos-cc`, and `nixie-homes` repos
- `ARCHITECTURE.md` — corrected a stale claim that `nix-secrets`/
  `keytabs-matos-cc` follow Conventional Commits "without automated
  enforcement"; both now have their own commitlint hook via their own
  `flake.nix`
- `README.md`/`CLAUDE.md`/`ARCHITECTURE.md` — corrected several stale/
  inaccurate references found during a documentation accuracy pass: a
  fictitious `secrets/secrets.nix` path in `README.md` (secrets recipients
  live in the external `nix-secrets`/`keytabs-matos-cc` repos, not a local
  `secrets/` directory — none exists), a `nixie.certbot.domains` example
  using the wrong (flat) list form, a stale devShell package list
  (`nixfmt-rfc-style` → `nixfmt`, missing `statix`), an incomplete
  `sharedSpecialArgs` example in `CLAUDE.md` (missing `homebrew-autoupdate`,
  `qmd`, `stylix`), and a missing `nixie-homes` row in `ARCHITECTURE.md`'s
  document map

---

## 26.07.11

### Added

- `home/alberth/gammu.nix` — added `systemd.user.services.steamup`, replacing
  the ad-hoc `hosts/nixos/gammu/scripts/steamup.sh` wrapper (removed):
  `gamescope` is now `ExecStart` directly (`Type = "exec"`) instead of a
  self-detaching script, so `systemctl --user start/stop/restart steamup`
  actually controls the session — `stop` tears down Steam and any running
  game via systemd's `control-group` `KillMode`, no manual `pkill` needed.
  Autostarts on boot inside alberth's real `systemd --user` session (not a
  NixOS `systemd.services` unit with `User=`) for a proper
  `XDG_RUNTIME_DIR`/D-Bus session, enabled at boot via
  `users.users.alberth.linger = true` in `hosts/nixos/gammu/default.nix`
- `home/alberth/gammu.nix` — added `iosevka` and `ioskeley-mono`
  (`normal`, `normal-NF`, `normal-term`, `normal-term-NF`) fonts; the
  `-term` variants fix arrow/box-drawing rendering in Ghostty
- `hosts/darwin/codex/homebrew.nix` — added `font-iosevka`,
  `font-iosevka-nerd-font`, and `font-ioskeley-mono` casks; nixpkgs'
  `iosevka` fails to build on aarch64-darwin (see Known issues), so
  codex gets these fonts via Homebrew's prebuilt binaries instead
- `ARCHITECTURE.md` — cross-repo architecture document for `nixie`,
  `nix-secrets`, and `keytabs-matos-cc`, targeting both humans and AI
  agents: repo responsibilities, the secrets lifecycle (with sequence
  diagram), module placement rules, host provisioning paths, and the
  invariants an agent must preserve across the three repos
- `modules/common/packages.nix` — added `pciutils` (`lspci`) for all NixOS
  hosts, gated by `stdenv.isLinux` alongside `ghostty.terminfo`
- `hosts/nixos/gammu/default.nix` — added `rocmPackages.rocm-smi` for
  querying/monitoring the AMD GPU; convention: any NixOS host with an AMD
  graphics card should carry this
- `hosts/nixos/gammu/default.nix` — `services.ollama.loadModels` pulls
  `qwen2.5-coder:14b` (~9GB Q4_K_M, fits the 12GB card with headroom);
  `environmentVariables.OLLAMA_CONTEXT_LENGTH = "32768"` pins context
  length for agentic tool-call loops (Zed Agent Panel, Claude Code)
- `home/alberth/gammu.nix` — added `claude-code` package and a
  `claude-local` fish function that points Claude Code at gammu's local
  Ollama model via `ANTHROPIC_BASE_URL` (Ollama's native Anthropic
  Messages API compatibility, no proxy needed)

### Changed

- `hosts/nixos/gammu/default.nix` — disabled `services.displayManager.sddm`;
  gammu now boots to a text console instead of a graphical login screen.
  Local Plasma sessions are started manually via `startplasma-wayland`;
  `xrdp` remote sessions are unaffected
- `CLAUDE.md`/`README.md` — added pointers to `ARCHITECTURE.md` so both
  humans and agents discover it before making cross-repo changes
- `flake.lock` — updated `nix-secrets` and `keytabs-matos-cc` inputs to
  pick up the backup-YubiKey rekey in both secrets repos
- `README.md` — added "Local LLM (Ollama + Open WebUI)" section: model
  choice/sizing rationale, Zed Agent Panel `settings.json` snippet, and
  `claude-local` usage; updated the `gammu/default.nix` layout comment
- `CLAUDE.md` — added a "Local LLM (Ollama)" convention: verify the GPU
  via `rocminfo`/sysfs before setting `rocmOverrideGfx`, `rocm-smi` on
  every AMD-GPU NixOS host, `loadModels`/`environmentVariables` usage,
  and the Zed/Claude Code tool-calling wiring; updated the same layout
  comment

### Known issues

- `home/alberth/codex.nix` — `iosevka`/`ioskeley-mono` are not built
  via nixpkgs here (unlike gammu): `iosevka` fails to build on
  aarch64-darwin due to an upstream bug (nixpkgs#532294), worked
  around via Homebrew casks instead (see Added). Switch back to
  nixpkgs once that's fixed upstream.

### Fixed

- `hosts/nixos/gammu/default.nix` — comments and `rocmOverrideGfx` wrongly
  assumed an RX 7900 GRE (Navi 31/gfx1100/16GB); `rocminfo` and sysfs
  confirm the card is actually a Radeon RX 7700 XT (Navi 32/gfx1101/12GB).
  `rocmOverrideGfx` corrected from `"11.0.0"` to `"11.0.1"`
- `home/alberth/default.nix` — the YubiKey identity symlink source had a
  typo (`age-yubikey-identity-43f4e92.txt`, missing the leading `d`)
  introduced while wiring up the post-rekey identity file; corrected to
  `age-yubikey-identity-d43f4e92.txt`, matching the actual file in
  `nix-secrets`

---

## 26.07.10

### Fixed

- `hosts/nixos/gammu/default.nix` — remove bogus
  `services.ollama.environment` block: the NixOS Ollama module uses
  `environmentVariables` (not `environment`), causing a hard
  evaluation error on rebuild; `OLLAMA_NUM_CTX` is not a valid
  Ollama server env var regardless — context window is per-model
  (Modelfile or Open WebUI settings), not a server-level env var

---

## 26.07.09

### Added

- `hosts/nixos/gammu/default.nix` — `services.ollama` with `ollama-rocm`
  package, `rocmOverrideGfx = "11.0.0"` (RX 7900 GRE / gfx1100 /
  RDNA3), listening on `0.0.0.0:11434`
- `hosts/nixos/gammu/default.nix` — `services.open-webui` on
  `0.0.0.0:8080`, pointing at Ollama via `OLLAMA_BASE_URL`
- `hosts/nixos/gammu/default.nix` — firewall rules allowing Ollama
  (11434) and Open WebUI (8080) from LAN (10.0.4.0/22); Tailscale
  access via existing `trustedInterfaces = ["tailscale0"]`
- `hosts/nixos/gammu/default.nix` — `services.ollama.environment`
  sets `OLLAMA_NUM_CTX = "32768"` to raise the default context window
  to 32 K tokens

### Changed

- `modules/darwin/macos-defaults/system-ui.nix` — set
  `loginwindow.SHOWFULLNAME = false` (show username field, not full
  name, at the login window)

---

## 26.07.08

### Added

- `hosts/darwin/common-darwin.nix` — postfix relay client for darwin hosts:
  `launchd.daemons."org.postfix.master"` registers an on-demand daemon
  (triggered by queue activity in `/private/var/spool/postfix/maildrop`,
  exits after 60 s idle). Five relay settings applied via `postconf -e`
  in `extraActivation` (same pattern as `kwriteconfig6` for KDE — writes
  specific keys into the existing `main.cf` without owning the whole
  file): `relayhost`, `inet_interfaces = loopback-only`, `inet_protocols`,
  `mydestination = ""`, `local_transport = error:local delivery disabled`,
  `smtp_tls_security_level = may`.

---

## 26.07.07

### Added

- `hosts/nixos/common-nixos.nix` — postfix relay client for all NixOS
  hosts except porkchop: loopback-only listener, relays through
  `porkchop.ts.matos.cc:25`, local delivery disabled, opportunistic TLS.
  Mirrors the chrony client block pattern already in that file.

### Changed

- `hosts/nixos/porkchop/default.nix` — added `100.64.0.0/10` (Tailscale
  CGNAT) to `nixie.smtpRelay.myNetworks` so fleet hosts connecting via
  `porkchop.ts.matos.cc` are accepted for relay without SASL credentials.

---

## 26.07.06

### Fixed

- `home/alberth/scripts/npbs-all.sh` — `fish -c npbs` failed on remote
  hosts because `npbs` is a shell alias (loaded only in interactive
  sessions). Replaced with the inline expansion
  `cd ~/Projects/nixie; and git pull; and nixbuild; and nixswitch`,
  which works in non-interactive fish because `nixbuild` and `nixswitch`
  are proper fish function files.
- `home/alberth/scripts/npbs-all.sh` — add `codex` (darwin) as a local
  host via `run_local()`, running the same fish command in-process
  instead of over SSH.

---

## 26.07.05

### Added

- `flake.nix` — `stylix` input (`github:danth/stylix`,
  `inputs.nixpkgs.follows`); threaded through `outputs` args and
  `sharedSpecialArgs`
- `home/alberth/common/stylix.nix` (new) — `stylix.enable = true` with
  base16 Dracula scheme (`base16-schemes`); JetBrainsMono Nerd Font set
  as monospace; starship, tmux, and vim targets disabled (custom/plugin
  theming retained for those); 1×1 bg image satisfies required option
- `hosts/darwin/common-darwin.nix`, `modules/nixos/home-manager.nix` —
  `stylix.homeModules.stylix` added to `home-manager.sharedModules`

### Changed

- `home/alberth/common/theming.nix` — removed manually embedded Dracula
  color blocks for fzf, btop, fish, and zsh-syntax-highlighting; now
  managed by stylix. eza YAML remains (no stylix target exists).
- `home/alberth/common/tools.nix` — removed explicit `bat.config.theme`
  (`"Dracula"`); stylix injects `base16-stylix` theme instead
- `home/alberth/darwin/ghostty.nix` — removed named `theme` setting;
  stylix generates terminal colors from base16 Dracula. Explicit
  `font-size = 14` kept to override stylix's scaled default.

---

## 26.07.04

### Changed

- `home/alberth/default.nix` — deploy `npbs-all` to `~/.local/bin/npbs-all`
  via `home.file` (executable symlink into the Nix store)
- `home/alberth/common/packages.nix` — add `$HOME/.local/bin` to
  `home.sessionPath`

---

## 26.07.03

### Added

- `home/alberth/scripts/npbs-all.sh` (new) — runs `npbs` on all physical
  hosts (gammu, porkchop, huginn) simultaneously via SSH; streams output
  live with `[hostname]` prefixes, reports which hosts failed, exits
  non-zero if any do
- `home/alberth/common/shells.nix` — `programs.fish` enabled fleet-wide:
  `interactiveShellInit` sets GPG_TTY, ARCHFLAGS, and sources 1Password
  plugins; fish `functions` define `nixbuild` and `nixswitch` (using fish
  command substitution `(hostname)` instead of `$(hostname)`) and the
  `ls` → eza wrapper (fish function syntax)
- `home/alberth/common/atuin.nix` — `enableFishIntegration = true`
- `home/alberth/common/theming.nix` — Dracula fish color palette via
  `set -U fish_color_*` universal variables (draculatheme.com/fish),
  ordered at 950 to match the zsh syntax-highlighting approach
- `hosts/darwin/codex/homebrew.nix` — added `cmux` and `supacode` casks;
  both are native macOS terminals for running AI coding agents in parallel,
  not available in nixpkgs
- `home/alberth/common/tools.nix` — `programs.tmux` enabled fleet-wide:
  mouse support, 0ms escape time (neovim-friendly), 50k line scrollback,
  `tmux-256color` terminal with true-color RGB passthrough, and the
  Dracula plugin (`tmuxPlugins.dracula`) for theming
- `modules/common/packages.nix` - explicitly added uv and python3
- `.github/workflows/ci.yml` — `concurrency` group keyed on workflow + ref
  with `cancel-in-progress: true`, so a new push cancels the previous
  run's CI instead of letting both finish
- `modules/nixos/unifi-backup.nix` (new) — `nixie.unifiBackup`: daily scp
  backup of UniFi OS's autobackup directory from unifi.home.matos.cc into a
  local directory, via SSH key auth. Deploys the script as `unifi_backup.sh`
  (also runnable manually) and wraps it in a systemd oneshot service + timer.
  Uses `IdentitiesOnly=yes` + `PreferredAuthentications=publickey` so the
  service only ever offers the ragenix-deployed key — without these, the
  primary user's `Host *` `~/.ssh/config` (IdentityFile is cumulative across
  matching blocks) adds a nonexistent default identity and tries GSSAPI
  first, producing misleading "no such identity" errors ahead of the real
  failure
- `modules/common/unifi-backup-secrets.nix` (new) — deploys the new
  `unifi-backup-ssh-key` secret (SSH private key for unifi.home.matos.cc)
  via ragenix from `nix-secrets`
- `hosts/nixos/porkchop/default.nix` — enabled `nixie.unifiBackup`,
  backing up into `/home/alberth/backups/unifi`
- `flake.nix` — added `qmd` flake input (`github:tobi/qmd`,
  `inputs.nixpkgs.follows = "nixpkgs"`); threaded through `outputs` args
  and `sharedSpecialArgs`
- `hosts/darwin/common-darwin.nix`, `modules/nixos/home-manager.nix` —
  added `qmd.homeModules.default` to `sharedModules` so `programs.qmd`
  is available on all hosts
- `home/alberth/codex.nix`, `home/alberth/gammu.nix` — `programs.qmd.enable
  = true`; installs qmd on codex (aarch64-darwin) and gammu (x86_64-linux)

### Changed

- `hosts/darwin/common-darwin.nix`, `hosts/nixos/common-nixos.nix` —
  default login shell changed from zsh to fish (`pkgs.fish`);
  `programs.fish.enable = true` added fleet-wide; zsh remains enabled
  and available
- `home/alberth/common/shells.nix` — removed `programs.fish` block and
  fish-specific nixbuild/nixswitch aliases
- `home/alberth/common/theming.nix` — removed fish Dracula theme config
  and `programs.fish.shellInit`
- `home/alberth/common/atuin.nix` — removed `enableFishIntegration`
- `home/alberth/nvf.nix` — removed `fish.enable` language support
- `home/alberth/darwin/ghostty.nix`, `home/alberth/template-darwin.nix`
  — updated stale fish references in comments
- `CLAUDE.md` — removed fish from Dracula theming tool list
- `CLAUDE.md` — added directive prohibiting AI/tool attribution tags
  (`Co-Authored-By` etc.) in commits without explicit user permission
- `hosts/nixos/common-nixos.nix` — `documentation.nixos.enable = false;`
  fleet-wide; stops the local NixOS manual/options-JSON build, which was
  the source of the upstream `builtins.toFile ... options.json` warning
  (nixpkgs#485682) on every `nix flake check`/`nix flake update`. Removes
  `nixos-help` and the local HTML manual on NixOS hosts
- `home/alberth/common/tools.nix` — bat now uses the Dracula theme (bundled
  with bat itself) instead of the Catppuccin auto light/dark setup. Dropped
  the now-unused `catppuccin-bat` flake input and its `themes` block, and
  removed the `catppuccin-bat` arg/wiring from `flake.nix`,
  `hosts/darwin/common-darwin.nix`, and `modules/nixos/home-manager.nix`
- `home/alberth/common/theming.nix` — btop, eza, fish, fzf, and
  zsh-syntax-highlighting switched from Catppuccin to Dracula. None of these
  have a nix-packaged Dracula module (unlike Catppuccin's catppuccin/nix), so
  their official colors/theme files are embedded directly instead of adding
  new flake inputs. `home/alberth/common/starship.nix` gained Dracula `style`
  overrides on the segments the official Dracula starship preset defines,
  without touching the existing p10k-derived formats/symbols. bat, neovim
  (nvf), and Ghostty were already Dracula. With nothing left using it, the
  `catppuccin` flake input and its `homeModules.catppuccin` sharedModule were
  removed from `flake.nix`, `hosts/darwin/common-darwin.nix`, and
  `modules/nixos/home-manager.nix` — nixie now carries no theming flake input
- `home/alberth/common/starship.nix` — replaced the two-line p10k-mirroring
  prompt with a powerline segmented layout using a named Dracula palette.
  Segments left-to-right: OS icon + username (purple block) → directory
  (cyan) → git branch + status (pink) → language tools + nix_shell (green:
  c, rust, go, node, php, java, kotlin, haskell, python, nix) → conda +
  time (comment grey) → cmd_duration. Prompt character changed from `❯` to
  `λ`; username is now always shown (was SSH-only)
- `home/alberth/common/starship.nix` — added `$hostname` to the purple
  segment immediately after `$username`; always shown (`ssh_only = false`),
  formatted as `@hostname`
- `home/alberth/common/ssh.nix` — added SSH host entry for
  `unifi.home.matos.cc` / `unifi` alias with `User = root`

### Fixed

- `hosts/nixos/template-nixos/hardware-configuration.nix` — the empty
  placeholder tripped NixOS's "fileSystems option does not specify your
  root file system" assertion, which only surfaces when `nix flake check`
  runs natively on x86_64-linux (not when cross-evaluated from codex,
  aarch64-darwin) — this was the original `ci.yml` breakage from Jun 29,
  masked ever since by evaluating `nix flake check` from the wrong arch.
  Added a placeholder `fileSystems."/"` entry, clearly marked as fake, to
  satisfy the assertion. Also applied to `hosts/nixos/{picanha,sirloin}`,
  which have the identical placeholder and will hit the same assertion
  once wired into `flake.nix`
- `flake.nix` — `nixosConfigurations.minixie` set `hardware.facter.reportPath`
  unconditionally to `hosts/nixos/minixie/facter.json`, a file that only
  exists after a real deploy generates it. A path literal to a file
  untracked by git fails flake evaluation outright (not just when the
  option is read), breaking `nix flake check` for every configuration,
  not just minixie. Now guarded with `lib.optionalAttrs (builtins.pathExists
  ...)` so the option is only set once the file exists and is committed.
  Inherited from the original standalone `minixie` repo, which had the
  same bug but no CI to catch it.

## 26.07.02

### Changed

- `hosts/nixos/common-nixos.nix`, `hosts/darwin/common-darwin.nix`,
  `hosts/nixos/ephemeraltron/default.nix` — default login shell for
  `alberth` switched from fish to zsh
- `CLAUDE.md`, `README.md` — host tables were missing `huginn`, `picanha`,
  and `sirloin`; added, with `picanha`/`sirloin` marked as stubs not yet
  in `flake.nix`

### Added

- `flake.nix` — `disko` input; merged the former standalone
  `amatos/minixie` repo in as `hosts/nixos/minixie` and a
  `nixosConfigurations.minixie` entry (generic nixos-anywhere bootstrap
  target, deliberately outside `sharedSpecialArgs`). Dropped the original
  repo's unused `nixos-facter-modules` input — that flake is deprecated
  and `hardware.facter.reportPath` is now a native nixpkgs option
- `README.md` — "Provisioning new hosts" section documenting the three
  bootstrap paths (`template-nixos`, `ephemeraltron`, `minixie`) and when
  to use each
- `users.nix` - added `ecdsa-sha2-nistp256` key for SSH access to `alberth`
- `modules/common/packages.nix` — `pre-commit`
- `modules/nixos/dyndns-luadns.nix` — `nixie.dyndnsLuadns`: polls a UDM's
  local API for the WAN IP and updates LuaDNS's dyndns2 endpoint (HTTPS)
  when it changes; reuses the existing `luadns-ini` certbot secret
- `modules/common/dyndns-luadns-secrets.nix` — deploys the new
  `unifi-api-key` secret (UniFi read-only API token) via ragenix
- `hosts/nixos/porkchop/default.nix` — enables `nixie.dyndnsLuadns` for
  `home.matos.cc`, checking every 5 minutes
- `modules/common/packages.nix` — `curl`, `jq` (fleet-wide; `curl` and `jq`
  were missing system-wide, breaking `dyndns-luadns.service`)

### Fixed

- `home/alberth/gammu.nix` — move the `nerdctl` alias from
  `programs.fish.shellAliases` to `home.shellAliases` so it's available in
  bash and zsh too, not just fish
- `home/alberth/darwin/default.nix` — remove the
  `programs.ghostty.settings.command` override that hardcoded a path to the
  fish binary; Ghostty now launches whatever the user's login shell is
  (zsh), and the now-unused `primaryUser` binding was dropped
- `home/alberth/common/shells.nix` — `unalias ls` before defining the zsh
  `ls` wrapper function; eza's `enableZshIntegration` alias earlier in the
  generated `.zshrc` otherwise broke zsh's parsing of `ls() { ... }`
  ("defining function based on alias `ls'"), surfaced after switching the
  default login shell to zsh
- `modules/nixos/dyndns-luadns.nix` — use `${pkgs.curl}/bin/curl` instead of
  bare `curl`, matching `syncthing-password.nix`'s pattern of not relying on
  `PATH` inside systemd units
- `modules/nixos/dyndns-luadns.nix` — match LuaDNS's response on its first
  word only; LuaDNS replies with a bare `good`/`nochg`, not `good <ip>`, so
  the old pattern reported every successful update as a failure

## 26.07.01

### Added

- `hosts/nixos/gammu/default.nix` — Steam gaming support: `programs.steam`
  (remote play + dedicated server firewall, proton-ge-bin, gamescope
  session), `hardware.graphics.enable32Bit`, `programs.gamemode`,
  `programs.gamescope`
- `hosts/nixos/gammu/scripts/steamup.sh` — headless gamescope + Steam
  Big Picture launcher at 4K for Steam Remote Play; wrapped via
  `writeShellApplication` and installed as `steamup.sh`
- `hosts/nixos/gammu/default.nix` — KDE Plasma 6 desktop via
  `services.desktopManager.plasma6` + `services.displayManager.sddm`
  (Wayland, login screen, no autologin)
- `hosts/nixos/gammu/default.nix` — `services.xrdp` for remote desktop
  access into Plasma (X11 session via `startplasma-x11`), chosen over
  KDE's native KRDP for declarative NixOS support
- `home/alberth/gammu.nix` — sets ghostty as the default terminal in KDE
  (`kdeglobals` `TerminalApplication`/`TerminalService`) via a `kwriteconfig6`
  `home.activation` hook, since nixie has no `plasma-manager` input
- `hosts/darwin/common-darwin.nix` — `determinateNix.customSettings` adds
  `trusted-users`: `root`, `alberth`, `@admin`, `@staff`
- `home/alberth/darwin/` — darwin home-manager overlay (ghostty settings
  only; moved from top-level `ghostty.nix`)
- `home/alberth/scripts/configure-brew-autoupdate.sh` — shell script to
  configure brew autoupdate LaunchAgent on each `darwin-rebuild switch`
- `modules/darwin/macos-defaults/` — declarative macOS system defaults
  (all darwin hosts via `common-darwin.nix`):
  - `finder.nix` — Finder preferences (extensions, search scope, Trash)
  - `keyboard.nix` — key repeat and keyboard navigation settings
  - `system-ui.nix` — NSGlobalDomain appearance, menu bar clock,
    screensaver, control center, screenshots config
  - `trackpad.nix` — trackpad click, scrolling, force-touch settings
  - `dock/default.nix` — Dock autohide, size, hot corners, gestures
  - `dock/persistent-apps.nix` — persistent Dock application list
- `hosts/darwin/codex/homebrew.nix` — Homebrew config (codex-specific);
  casks with `greedy = true`; masApps; `homebrew/autoupdate` tap;
  brew autoupdate LaunchAgent via `postActivation`

### Changed

- `CLAUDE.md`, `README.md` — documented the Steam gaming convention; fixed
  stale `gammu/default.nix — hostname only` layout comment
- `modules/darwin/macos-defaults/dock/persistent-apps.nix` - fixed path to Safari.app
- `modules/darwin/macos-defaults/dock/persistent-apps.nix` — fixed
  incorrect path to users.nix
- `home/alberth/common/` — renamed from `home/alberth/modules/`
- `home/alberth/codex.nix`, `darwintron.nix`, `template-darwin.nix` —
  import `./darwin`; stale `./ghostty.nix` import removed
- `hosts/darwin/common-darwin.nix` — imports `modules/darwin/macos-defaults`
- `hosts/darwin/codex/default.nix` — imports `./homebrew.nix`; old inline
  `homebrew` block removed
- `home/alberth/darwin/default.nix` — expanded from a one-line ghostty
  wrapper into the shared darwin home base: adds `services.gpg-agent`
  (pinentry-mac) and `programs.ghostty` (enable, `package = null`, fish
  command using `primaryUser`); removes duplicated blocks from
  `codex.nix`, `darwintron.nix`, and `template-darwin.nix`
- `home/alberth/darwintron.nix` — now trivial (just imports `./darwin`);
  removed redundant GPG agent and Ghostty blocks now in `darwin/default.nix`
- `home/alberth/template-darwin.nix` — same; now imports `./darwin` only
- `home/alberth/codex.nix` — removed GPG agent and Ghostty enable blocks
  now in `darwin/default.nix`; SSH and activation scripts unchanged
- `home/alberth/huginn.nix` — fixed doc comment (was "Gammu-specific")
- `home/alberth/picanha.nix` — fixed doc comment (was "Gammu-specific")
- `home/alberth/sirloin.nix` — fixed doc comment (was "Gammu-specific")
- `hosts/nixos/picanha/default.nix` — replaced boilerplate template
  comment with a host-specific stub description
- `hosts/nixos/sirloin/default.nix` — same
- `modules/nixos/default-password.nix` — use `primaryUser` from `users.nix`
  instead of hardcoded `"alberth"` for `users.users.<name>.hashedPasswordFile`
- `modules/common/packages.nix` — use `primaryUser` in `trusted-users`
  instead of hardcoded `"alberth"`
- `hosts/nixos/porkchop/default.nix` — use `primaryUser` in
  `saslAuthzRegexp` LDAP pattern instead of hardcoded `"alberth"`
- `home/alberth/default.nix` — imports reorganised; `atuin`, `chezmoi`,
  `devenv`, `starship` now imported from `common/` (moved; see Removed)
- `hosts/nixos/huginn/default.nix` — added missing
  `modules/common/certbot-secrets.nix` (LuaDNS credentials) and
  `modules/nixos/syncthing-password.nix` imports; huginn uses both
  certbot and Syncthing but was not importing either module
- `home/alberth/nixos.nix` — now auto-imports
  `home/alberth/<hostname>.nix` via `builtins.pathExists` +
  `osConfig.networking.hostName`; adds `pkgs.krb5` for all NixOS
  hosts except `porkchop` (which uses `krb5WithLdap` from system
  packages to avoid shadowing `kadmin.local`)
- `home/alberth/gammu.nix` — removed `pkgs.krb5`; now provided by
  `nixos.nix` for all NixOS hosts
- `hosts/nixos/huginn/default.nix` — removed explicit
  `home-manager.users` import; `nixos.nix` auto-discovers the overlay
- `hosts/nixos/gammu/default.nix` — same; removed `lib` arg (unused)
- `hosts/nixos/picanha/default.nix` — removed explicit
  `home-manager.users` import and unused `primaryUser` let binding
- `hosts/nixos/sirloin/default.nix` — same

### Fixed

- `hosts/nixos/huginn/default.nix` — restored the `primaryUser` let binding
  removed in the `home-manager.users` cleanup below; huginn's
  `services.syncthing.user`/`dataDir` still need it, unlike picanha/sirloin
  which only used it for the now-removed import. Surfaced as
  `undefined variable 'primaryUser'` during a `nixos-rebuild switch` on
  another host, since flake tooling can evaluate all `nixosConfigurations`
  entries eagerly.
- `hosts/nixos/{gammu,huginn,porkchop}/default.nix` — changed Syncthing
  `guiAddress`/`settings.gui.address` from the IPv6 wildcard `"[::]:8384"`
  to the IPv4 wildcard `"0.0.0.0:8384"`. NixOS's `syncthing-init` service
  curls `guiAddress` directly to reconcile config; connecting to a literal
  `::` destination always fails, breaking that service with
  `curl: (7) Failed to connect to :: port 8384` on every syncthing restart
  (observed in production on porkchop). Also dropped the now-nonfunctional
  `ip6 nexthdr tcp tcp dport 8384 accept` firewall rule on all three hosts —
  the GUI is IPv4-only now. See CLAUDE.md Syncthing conventions.
- (manual, not a flake change) gammu/huginn/porkchop each had a pre-existing
  `~/.config/syncthing/config.xml` with `<gui><address>[::]:8384</gui>`
  persisted from before the fix above; syncthing v2.0.15 prefers that
  persisted value over the `--gui-address` CLI flag on restart, so the
  address change above didn't take effect until manually PATCHed via the
  still-live old address and the service bounced. See CLAUDE.md Syncthing
  conventions for the recovery steps — needed again on any host migrating
  an existing `guiAddress` value.

### Removed

- `home/alberth/ghostty.nix` — moved to `home/alberth/darwin/ghostty.nix`
- `home/alberth/atuin.nix` — moved to `home/alberth/common/atuin.nix`
- `home/alberth/chezmoi.nix` — moved to `home/alberth/common/chezmoi.nix`
- `home/alberth/devenv.nix` — moved to `home/alberth/common/devenv.nix`
- `home/alberth/starship.nix` — moved to `home/alberth/common/starship.nix`
- `home/alberth/huginn.nix` — removed; `pkgs.krb5` absorbed into
  `nixos.nix` (shared across all NixOS hosts except porkchop)
- `home/alberth/picanha.nix` — same
- `home/alberth/sirloin.nix` — same

## 26.06.09

### Added

- `.gitignore` - added .claude to gitignore
- `hosts/nixos/huginn/default.nix` — Added `services.syncthing`, firewall, and kerberos configs for the huginn host
- `home/alberth/huginn.nix` — home-manager settings for alberth on the huginn host
- `home/alberth/picanha.nix` — home-manager settings for alberth on the picanha host
- `home/alberth/sirloin.nix` — home-manager settings for alberth on the sirloin host
- `hosts/darwin/codex/default.nix` - added claude-code cask
- `hosts/nixos/huginn/` — `home/alberth/huginn.nix` added
- `hosts/nixos/picanha/` — `home/alberth/picanha.nix` added
- `hosts/nixos/porkchop/` — `home/alberth/porkchop.nix` added
- `hosts/nixos/sirloin/` — `home/alberth/sirloin.nix` added
- `modules/common/packages.nix` — `alberth` added to `trusted-users`
- `flake.nix` — `keytabs-matos-cc` flake input added
  (`github:amatos/keytabs-matos-cc`, `flake = false`); threaded through
  `outputs` and `sharedSpecialArgs` alongside `nix-secrets`
- `CLAUDE.md` — "Wiring an external secrets repo into nixie" runbook
  documenting the add-input/thread-specialArgs/reference-file pattern, and
  an explicit text-vs-binary split rule for `nix-secrets` vs
  `keytabs-matos-cc`
- `hosts/darwin/common-darwin.nix` — `determinateNix.customSettings.trusted-users`
  added (`root`, `alberth`, `@admin`, `@staff`)
- `CLAUDE.md` — "Nix daemon settings (Determinate)" section documenting
  that `nix.settings` is NixOS-only under Determinate Nix and darwin hosts
  must use `determinateNix.customSettings` instead
- `hosts/darwin/codex/default.nix` — `system.activationScripts.extraActivation`
  creates the `ContainerData` APFS volume on `disk3` (idempotent via
  `diskutil info`) backing OrbStack's data directory
- `modules/nixos/github-secrets-tmpfiles.nix` — NixOS-only module holding the
  `systemd.tmpfiles.rules` entry that pre-creates `~/.ssh`, split out of
  `modules/common/github-secrets.nix`
- `CLAUDE.md` — "Module placement" gotcha documenting that darwin has no
  `systemd` option namespace at all, so `systemd.*` options can't live in
  `modules/common/` even when their value is platform-gated; and a Homebrew
  pattern note for casks with no nix-darwin module (install via cask,
  manage config/data via nix), referencing the OrbStack setup
- `CLAUDE.md` — "darwin activation scripts" section documenting that
  nix-darwin's `/activate` only runs a fixed, hardcoded list of named
  stages, so arbitrary `system.activationScripts.<name>` keys are silently
  never run; use `extraActivation`/`postActivation` instead, and how to
  verify a script actually made it into the built activation script
- `hosts/darwin/codex/default.nix` — added `claudebar` cask (menu bar app
  for monitoring AI coding assistant usage quotas); replaces the earlier
  `pkgs.claudebar` reference in `home/alberth/codex.nix`, which doesn't
  exist in nixpkgs and was blocking `codex` from evaluating at all

### Changed

- `hosts/darwin/codex/default.nix` — OrbStack: dropped the `programs.orbstack`
  block (that option doesn't exist in this nix-darwin pin, so it never
  actually evaluated); OrbStack is now installed solely via the existing
  Homebrew cask, with data/config managed declaratively (see Added above and
  the `home/alberth/codex.nix` entry below)
- `home/alberth/codex.nix` — reworked: `targets.darwin.copyApps` enabled
  (real app copies in `~/Applications/Home Manager Apps/` instead of
  `/nix/store` symlinks, so macOS TCC camera/mic/screen-recording grants
  persist across rebuilds); `manual.manpages.enable = false` workaround for
  a home-manager `options.json` warning; `programs.ssh.settings` and
  `programs.ghostty` merged under one `programs = { ... }` block;
  `home.activation.prependSSHInclude`/`syncthingConfig` moved under
  `home.activation`; added OrbStack Docker daemon config
  (`.orbstack/config/docker.json`: log rotation, build-cache GC) and a
  `Library/Group Containers/HUAQ24HBR6.dev.orbstack` out-of-store symlink
  pointing at the `ContainerData` volume; `CONTAINER_DATA` session variable
  added
- `hosts/darwin/common-darwin.nix` — removed `tailscale-secrets.nix` import;
  darwin hosts rely solely on the Homebrew `tailscale-app` cask, which
  manages its own auth key without agenix
- `modules/common/tailscale-secrets.nix` — updated comment to reflect the
  module is NixOS-only
- `hosts/darwin/codex/default.nix`, `hosts/nixos/gammu/default.nix`,
  `hosts/nixos/porkchop/default.nix` — Kerberos keytab references
  (`nixie.krb5.keytabFile`, `saslKeytabFile`) repointed from
  `${nix-secrets}` to `${keytabs-matos-cc}`, now that keytabs live in a
  dedicated repo; unused `nix-secrets` function args removed where the
  keytab was the only consumer in that file
- `modules/common/krb5-client.nix` — option doc/comments updated to
  reference `keytabs-matos-cc` instead of `nix-secrets`
- `hosts/nixos/{huginn,sirloin,picanha,template-nixos}/default.nix`,
  `hosts/darwin/template-darwin/default.nix` — "add a keytab" bootstrap
  comment updated to point at `keytabs-matos-cc`
- `flake.lock` — updated to pin the new `keytabs-matos-cc` input

### Fixed

- `modules/common/github-secrets.nix` — add `systemd.tmpfiles.rules` to
  pre-create `~/.ssh` as the primary user on NixOS; agenix (running as
  root) was creating the directory as root, blocking home-manager from
  writing `~/.ssh/config`
- `modules/common/github-secrets.nix` — the `systemd.tmpfiles.rules` fix
  above broke every darwin host (`error: The option 'systemd' does not
  exist`); nix-darwin declares no `systemd` option namespace, so gating the
  rule's *value* with `lib.optionals pkgs.stdenv.isLinux` wasn't enough —
  the option *key* still got merged into the darwin module tree. Moved the
  rule out to the new `modules/nixos/github-secrets-tmpfiles.nix` (imported
  only by NixOS hosts); `modules/common/github-secrets.nix` is back to
  pure cross-platform `age.secrets` deployment. (An intermediate fix using
  `lib.optionalAttrs pkgs.stdenv.isLinux { ... } // { ... }` at the module's
  top level was tried and discarded — it forces `pkgs` during module
  merging before `config` is settled and caused an infinite-recursion error
  on every host, darwin and NixOS alike.)
- `hosts/darwin/codex/default.nix`, `hosts/darwin/common-darwin.nix` — the
  `ContainerData`-volume script and the `ntp` activation script both
  silently never ran on darwin: nix-darwin's `/activate` is assembled from
  a fixed, hardcoded list of named stages (`groups`, `users`, `applications`,
  `homebrew`, `postActivation`, etc. — see upstream
  `modules/system/activation-scripts.nix`), unlike NixOS where
  `system.activationScripts.<name>` entries are collected generically.
  Custom names outside that list (`containerDataVolume`, `ntp`) are
  evaluated as options but never concatenated into the built script.
  Verified by diffing `nix eval .#darwinConfigurations.codex.config.system.activationScripts.script.text`
  against the actually-built `/activate` — neither script appeared in
  either, even though the system had genuinely rebuilt from current `HEAD`.
  Both moved onto `system.activationScripts.extraActivation.text` (via
  `lib.mkAfter`), nix-darwin's supported extension point, which runs early
  — before `homebrew` and home-manager activation
- `hosts/darwin/common-darwin.nix` — darwin's `nix.settings.trusted-users`
  (set in `modules/common/packages.nix`) never actually took effect; under
  Determinate Nix, `nix.enable` is forced `false` on darwin so nix-darwin
  never writes `/etc/nix/nix.conf`, silently dropping the setting (NixOS is
  unaffected — Determinate redirects its generated `nix.conf` into
  `nix.custom.conf`). `determinateNix.customSettings.trusted-users` is the
  correct mechanism on darwin and writes directly to `nix.custom.conf`;
  fixes "ignoring untrusted substituter" / "ignoring the client-specified
  setting 'trusted-public-keys'" warnings on codex
- `modules/common/packages.nix` — `@admin` added to `trusted-users`; on
  macOS admin users are in the `admin` group, not `wheel`, so `@wheel`
  alone does not trust them and flake `nixConfig` substituters are ignored
- `hosts/nixos/common-nixos.nix` — `services.openssh.package` set to
  `pkgs.openssh_gssapi`; `pkgs.openssh` no longer includes GSSAPI support
  (it is a separate Debian patch only in the `openssh_gssapi` derivation);
  without this `GSSAPIAuthentication`/`GSSAPICleanupCredentials` in sshd
  settings are unrecognised and Kerberos SSH login does not work
- `home/alberth/nixos.nix` — `pkgs.openssh_gssapi` added to `home.packages`
  on NixOS; shadows `pkgs.openssh` in the user PATH so the SSH client binary
  supports `GSSAPIAuthentication`/`GSSAPIDelegateCredentials` in
  `~/.ssh/config`; without this those options produce "Unsupported option"
  warnings on every SSH invocation
- `hosts/darwin/common-darwin.nix` — `pkgs.openssh_gssapi` added to darwin
  home packages for the same reason; macOS system SSH supports GSSAPI but
  `services.openssh` adds `pkgs.openssh` (no GSSAPI) to PATH, shadowing it
- `home/alberth/modules/ssh.nix` — GSSAPI options enabled on all platforms
  (was Linux-only); `lib`/`pkgs` args removed as no longer needed

## 26.06.08

### Added

- `modules/nixos/certbot.nix` — `ldapDeploy` option: deploy hook installs
  renewed cert+key to `/var/lib/openldap-tls/` (root:openldap 640) and
  restarts `openldap.service`; `tmpfiles` rule creates the directory
- `hosts/nixos/porkchop/default.nix` — LDAPS enabled: `ldaps:///` added
  to slapd `listenAddresses`; `tlsCertFile`/`tlsKeyFile` set to paths
  under `/var/lib/openldap-tls/`; `ldapDeploy = true` in certbot config
- `hosts/nixos/porkchop/default.nix` — OpenLDAP SASL/GSSAPI enabled via
  `nix-kerberos-ldap` ldap module options: `saslKeytabFile` deploys a
  dedicated age-encrypted `ldap/` service-principal keytab with openldap
  ownership; `saslHost = porkchop.ts.matos.cc` sets `olcSaslHost`;
  `saslAuthzRegexp` maps `alberth@MATOS.CC` to `cn=admin,dc=matos,dc=cc`
  so `ldapsearch`/`ldapmodify` work with a valid TGT instead of the
  LDAP admin password; `listenAddresses = [ "ldap://0.0.0.0:389/" ]`
  exposes slapd on all interfaces so GSSAPI clients can reach it via FQDN
- `hosts/nixos/porkchop/default.nix` — Samba Kerberos auth via
  `kerberos method = dedicated keytab`; clients with a valid TGT get
  transparent SMB access; keytab must contain both
  `host/porkchop.matos.cc` and `cifs/porkchop.matos.cc` principals
- `home/alberth/modules/ssh.nix` — `GSSAPIAuthentication` and
  `GSSAPIDelegateCredentials` enabled on all SSH client connections;
  attempts Kerberos auth before falling back to keys; requires a valid
  TGT (`kinit`) and a `host/` principal in the KDC

### Fixed

- `modules/common/krb5-client.nix` — `rdns = false` and
  `dns_canonicalize_hostname = false` added to `[libdefaults]`; without
  these libkrb5 resolves the Tailscale IP back to the short hostname
  and constructs the wrong service principal
- `hosts/nixos/common-nixos.nix` — `SASL_NOCANON on` in
  `/etc/openldap/ldap.conf`; Cyrus SASL's GSSAPI plugin does its own
  hostname canonicalization (independent of libkrb5 rdns settings) and
  reverse-resolves to the Tailscale-internal domain
  (`porkchop.tail<id>.ts.net`), triggering a cross-realm referral to a
  non-existent realm; `SASL_NOCANON` disables this and uses the URL
  hostname literally
- `hosts/darwin/common-darwin.nix` — same `SASL_NOCANON on` in
  `/etc/ldap.conf` (macOS ldap tools read this path)
- `modules/common/packages.nix` — `nix.settings.trusted-users` now
  includes `root` and `@wheel`; without this the Nix daemon ignores
  substituters and `trusted-public-keys` proposed by flake `nixConfig`
  blocks (nix-community, zed, garnix, amatos caches) with "not a
  trusted user" warnings
- `home/alberth/modules/ssh.nix` — `GSSAPIAuthentication` and
  `GSSAPIDelegateCredentials` now Linux-only via `lib.optionalAttrs`;
  Apple's OpenSSH has GSSAPI removed and emits "Unsupported option"
  warnings for these keys in `~/.ssh/config`

### Changed

- `modules/common/krb5-client.nix` — KDC and admin_server set to
  `porkchop.ts.matos.cc` (Tailscale); reachable from all hosts and
  external clients regardless of LAN adjacency
- `hosts/nixos/common-nixos.nix` — sshd: `GSSAPIAuthentication` and
  `GSSAPICleanupCredentials` enabled fleet-wide
- `hosts/darwin/common-darwin.nix` — sshd: same via `extraConfig`

## 26.06.07

### Added

- `modules/common/krb5-client.nix` — Kerberos client config for all hosts;
  sets `/etc/krb5.conf` pointing at `porkchop.matos.cc` as KDC and admin
  server; uses `lib.mkDefault` so porkchop's full KDC krb5.conf (written
  by `nix-kerberos-ldap` at normal priority) wins without conflict;
  `nixie.krb5.keytabFile` option deploys an age-encrypted host keytab to
  `/etc/krb5.keytab` on activation when set
- `hosts/nixos/common-nixos.nix` — import `krb5-client.nix`
- `hosts/darwin/common-darwin.nix` — import `krb5-client.nix`
- `hosts/darwin/codex/default.nix` — set `nixie.krb5.keytabFile`
- `hosts/nixos/gammu/default.nix` — set `nixie.krb5.keytabFile`
- `hosts/nixos/porkchop/default.nix` — set `nixie.krb5.keytabFile`
- `home/alberth/gammu.nix` — add `pkgs.krb5` for kinit/klist/kdestroy;
  kept out of shared home packages because porkchop has `krb5WithLdap` in
  system packages and home packages shadow system packages in user PATH,
  which causes `kadmin.local` to resolve to the non-LDAP build
- `hosts/darwin/template-darwin/` — new darwin host template based on
  codex; includes nix-homebrew, pinentry-mac GPG agent, ghostty home
  overlay, and inline provisioning instructions
- `hosts/nixos/template-nixos/` — new NixOS host template based on gammu;
  includes placeholder `hardware-configuration.nix` and inline
  provisioning instructions
- `home/alberth/template-darwin.nix` — darwin home overlay for the template
- `flake.nix` — `template-darwin` and `template-nixos` entries
- `flake.nix` — added `nix-kerberos-ldap` input (follows `nixpkgs` and
  `nix-secrets`)
- `hosts/nixos/porkchop/default.nix` — use
  `pkgs.stdenv.hostPlatform.system` in fresh pkgs import (fixes
  `'system' has been renamed` evaluation warning)
- `hosts/nixos/porkchop/default.nix` — build LDAP-enabled `krb5` via
  fresh `pkgs.path` instantiation (no system-wide overlay) to avoid
  the `krb5→openldap→cyrus-sasl→libkrb5→krb5` evaluation cycle;
  pass via new `krb5Package` option on `kerberosLdap.ldap` and
  `kerberosLdap.kerberos` (replaces prior `lib.mkForce` workarounds)
- `hosts/nixos/porkchop/default.nix` — Kerberos KDC + OpenLDAP backend via
  `services.kerberosLdap`; realm `MATOS.CC`, base DN `dc=matos,dc=cc`;
  firewall rules for KDC (88 TCP/UDP), kpasswd (464 TCP/UDP), kadmind
  (749 TCP), all LAN-restricted; `krb5` overridden with `withLdap = true`
  to provide `kdb5_ldap_util` and the `kldap` db_library

### Changed

- `home/alberth/modules/packages.nix` — removed `vlc` and
  `telegram-desktop` from shared packages; both are codex-only
- `home/alberth/codex.nix` — added `pkgs.telegram-desktop` (codex-only)
- `home/alberth/codex.nix` — removed `pkgs.vlc`; not available for
  aarch64-darwin; use `iina` homebrew cask instead
- `hosts/darwin/codex/default.nix` — removed stale vlc homebrew comment
- `hosts/nixos/porkchop/default.nix` — removed `krb5Package` from
  `kerberosLdap.ldap` block; option was removed upstream (schema now
  bundled in `nix-kerberos-ldap`)

- `hosts/nixos/porkchop/default.nix` — Samba + wsdd; per-user home shares,
  LAN/Tailscale only; SMB firewall rules
- `.zed/settings.json` — exclude `.git`, `.direnv`, and `result` from Zed's file scanner
- `home/alberth/gammu.nix` — new gammu-specific home overlay; adds `pkgs.act`
- `home/alberth/codex.nix` — added `pkgs.act` (codex- and gammu-only)
- `home/alberth/gammu.nix` — added `pkgs.nerdctl` (Docker-compatible CLI for containerd)
- `hosts/nixos/gammu/default.nix` — enabled `virtualisation.containerd`;
  `virtualisation.docker` (overlay2, containerd backend) for `act`;
  NOPASSWD sudoers rule for nerdctl
- `home/alberth/gammu.nix` — fish alias `nerdctl` → `sudo nerdctl`

### Fixed

- `home/alberth/nvf.nix` — renamed `vim.languages.ts` to `vim.languages.typescript` to match nvf's updated option name

## 2026-06-28

### Changed

- `hosts/darwin/codex/default.nix` — removed `orbstack` homebrew cask
- `home/alberth/codex.nix` — added `pkgs.orbstack` to `home.packages` (codex-only)

## 26.06.06

### Added

- `home/alberth/nvf.nix` - NVF settings update
- `home/alberth/default.nix` - Disable man.generateCaches
- `hosts/nixos/porkchop/default.nix` — NTP/NTS server via `services.chrony`; serves
  NTP (UDP 123) and NTS-KE (TCP 4460) to `10.0.4.0/22` and Tailscale CGNAT
  (`100.64.0.0/10`); upstreams to Cloudflare and Google via NTS for authenticated
  time; firewall rules added for both ports restricted to the LAN subnet (Tailscale
  covered by `trustedInterfaces`)
- `modules/nixos/certbot.nix` — `nixie.certbot.chronyDeploy` option; deploy hook
  installs renewed cert+key to `/var/lib/chrony-tls/` (root:chrony 640) and restarts
  `chronyd.service`; `tmpfiles` rule creates the directory; `ReadWritePaths` entry
  added so the certbot service can write into it under `ProtectSystem = "strict"`
- `hosts/nixos/common-nixos.nix` — all non-porkchop NixOS hosts now sync time from
  porkchop via NTS over Tailscale (`server porkchop.ts.matos.cc iburst nts`); chrony
  client enabled via `mkIf (hostName != "porkchop")` so porkchop's own server config
  is unaffected
- `hosts/darwin/common-darwin.nix` — darwin hosts sync time from porkchop via
  activation script (`systemsetup -setnetworktimeserver porkchop.ts.matos.cc`); plain
  NTP only (macOS timed does not support NTS or multiple servers)
- `modules/nixos/smtp-relay.nix` (new) — `nixie.smtpRelay` option module; configures
  Postfix as a smarthost relay with SASL auth and STARTTLS; accepts from configurable
  `myNetworks` (loopback by default); `nixie.smtpRelay.smtps.enable` adds a port-465
  implicit-TLS listener using the certbot-managed cert in `smtps.certDir`
- `modules/common/smtp-relay-secrets.nix` (new) — deploys `smtp-relay-sasl.age`
  from nix-secrets to `/run/agenix/smtp-relay-sasl` (Postfix SASL passwd map)
- `modules/nixos/certbot.nix` — add `nixie.certbot.postfixDeploy` option; deploy hook
  installs renewed cert+key into `/etc/postfix/ssl/` (`root:postfix 640`) and reloads
  `postfix.service`; multiple deploy hooks now composed via repeated `--deploy-hook` flags
- `hosts/nixos/porkchop/default.nix` — enable `nixie.smtpRelay` relaying through
  `smtp.fastmail.com:587`; SMTPS on port 465 with certbot cert; accept from localhost,
  `10.0.4.0/22`, and Tailscale; nftables rules opening ports 25 and 465 to the local subnet;
  add `mail.home.matos.cc` and `mail.ts.matos.cc` as SANs on the porkchop certificate
- `hosts/nixos/*/hardware-configuration.nix` - changed device paths to use
  `by-label` device names
- `modules/nixos/syncthing-password.nix` (new) — deploys `syncthing-gui-password.age`
  from nix-secrets; oneshot systemd service sets the Syncthing GUI password via
  `syncthing cli` at runtime, keeping the password out of the Nix store
- `modules/darwin/syncthing-password.nix` (new) — same secret, launchd user agent
  sets GUI user and password via `syncthing cli` on login (darwin cask has no

### Fixed

- `hosts/nixos/porkchop/default.nix` — corrected NTS server directives from
  `ntsServerCertFile`/`ntsServerKeyFile` to `ntsservercert`/`ntsserverkey` (chrony
  4.8 uses lowercase, no camelCase)
- `modules/nixos/syncthing-password.nix` — rewrote credential service to use the
  Syncthing REST API via `curl` instead of `syncthing cli`; `--home` is a flag for
  `syncthing serve` (not `syncthing cli`) so the CLI was silently ignoring it, failing
  to find the API key, and aborting before making any connection; the new approach
  reads the API key directly from `config.xml` with grep and PATCHes `/rest/config/gui`;
  switches from `requires`/`RemainAfterExit` to `partOf` (no `RemainAfterExit`) so
  credentials are re-applied on every syncthing restart; detects HTTP vs HTTPS from
  presence of `https-cert.pem` in the syncthing config dir

---

## 26.06.05 — 2026-06-26

### Added

- `home/alberth/modules/ssh.nix` - added single `IdentityFile` entry for `id_rsa`
- `.github/workflows/ci.yml` — added `build-ephemeraltron` job; builds
  `nixosConfigurations.ephemeraltron` on every push to main and on PRs

---

## 26.06.04 — 2026-06-26

### Added

- `hosts/nixos/porkchop/` (new) — NixOS host mirroring gammu: Syncthing with
  TLS and dual-stack GUI, nftables firewall, certbot for `porkchop.home.matos.cc`
  and `porkchop.ts.matos.cc`
- `hosts/nixos/porkchop/hardware-configuration.nix` — generated by
  `nixos-generate-config` on the physical machine
- `flake.nix` — `nixosConfigurations.porkchop`
- `CLAUDE.md` — added porkchop and ephemeraltron to hosts table
- `hosts/nixos/ephemeraltron/` (new) — minimal template NixOS host; provisions at
  `10.0.6.66/22` with static IP, SSH key access, passwordless sudo, and Nix flakes
  enabled so a real config can be applied immediately via `nixos-rebuild --flake`
- `hosts/nixos/ephemeraltron/hardware-configuration.nix` — x86_64 qemu-guest
  profile; by-label filesystem paths (`ESP`, `nixos`) so the config is disk-agnostic
- `installer/ephemeraltron.nix` — auto-installer ISO config; detects the first
  block device, partitions (GPT EFI + root), formats with matching labels, installs
  from a pre-built closure bundled in the ISO (no internet required), then reboots
- `flake.nix` — `nixosConfigurations.ephemeraltron`; `packages.x86_64-linux.ephemeraltron-iso`
  (build with `nix build .#ephemeraltron-iso`)

### Fixed

- `installer/ephemeraltron.nix` — replaced `${pkgs.path}` in `imports` with
  `modulesPath` to fix infinite recursion during ISO evaluation

---

## 26.06.03 — 2026-06-26

### Added

- `home/alberth/modules/` (new) — split `default.nix` into focused modules:
  `git.nix`, `gpg.nix`, `ssh.nix`, `shells.nix`, `tools.nix`, `theming.nix`,
  `packages.nix`; `default.nix` now contains only core identity and imports
- `home/alberth/default.nix` — `openssl` added to `home.packages` (all hosts)
- `CLAUDE.md` — added Commits section documenting Conventional Commits format,
  allowed types, and commitlint rules
- `hosts/nixos/gammu/default.nix` — `services.syncthing.guiAddress = "[::]:8384"`;
  Syncthing GUI binds to all interfaces on IPv4 and IPv6 via dual-stack wildcard
- `hosts/nixos/gammu/default.nix` — `overrideDevices = false` and `overrideFolders = false`
  so nixos-rebuild switch does not wipe Syncthing devices and folders
- `hosts/nixos/gammu/default.nix` — explicitly set Syncthing sync protocol to
  listen on all interfaces via TCP and QUIC on port 22000
- `hosts/darwin/codex/default.nix` — Syncthing configured with certbot-issued TLS
  cert for `codex.home.matos.cc`; GUI bound to all interfaces
- `home/alberth/codex.nix` — `home.activation.syncthingConfig` patches Syncthing's
  config.xml on each activation to enforce `tls="true"` and `[::]:8384` GUI address;
  syncthing-app remains homebrew-managed
- `hosts/nixos/gammu/default.nix` — firewall enabled; Syncthing GUI (port 8384)
  restricted to `10.0.4.0/22` on IPv4, open globally on IPv6; Syncthing sync
  protocol (port 22000 TCP/UDP) open globally on IPv4 and IPv6; SSH remains
  globally accessible
- `hosts/nixos/common-nixos.nix` — `networking.nftables.enable = true`; all NixOS
  hosts explicitly use nftables
- `hosts/nixos/common-nixos.nix`, `hosts/darwin/common-darwin.nix` — Tailscale
  enabled on all hosts; NixOS hosts auto-authenticate via ragenix secret;
  darwin hosts require one-time manual `sudo tailscale up --authkey <key>`
- `hosts/nixos/common-nixos.nix` — `networking.firewall.trustedInterfaces = [ "tailscale0" ]`;
  all traffic on the Tailscale interface is implicitly trusted on NixOS hosts
- `modules/common/tailscale-secrets.nix` (new) — deploys Tailscale auth key from
  `nix-secrets/tailscale-authkey.age` to `/run/agenix/tailscale-authkey`
- `nix-secrets/secrets.nix` — added `tailscale-authkey.age` recipient entry
- `README.md` — added Tailscale section documenting auto-auth on NixOS and
  manual auth on darwin
- `home/alberth/default.nix` — `nixflakeup` alias: update flake inputs, commit
  `flake.lock`, and push

### Fixed

- `nix-secrets/secrets.nix` — updated codex host age public key; previous key was
  never generated on disk so agenix activation failed silently on every switch
- `home/alberth/nixos.nix` — mask syncthing user unit via `home.activation` to
  prevent conflict with the system service managed by `services.syncthing`
- `hosts/nixos/gammu/default.nix` — corrected certbot domain from `home.matos.cc`
  to `gammu.home.matos.cc`; renewed certificate now matches the host FQDN
- `hosts/darwin/codex/default.nix` — corrected certbot domain from `home.matos.cc`
  to `codex.home.matos.cc`; renewed certificate now matches the host FQDN
- `modules/nixos/certbot.nix`, `modules/darwin/certbot.nix` — `domains` now accepts
  a list of lists; each inner list becomes a single cert with multiple SANs; bare
  strings still accepted (coerced to single-element list for backward compat);
  `--expand` added so certbot replaces existing certs when SANs change
- `hosts/nixos/gammu/default.nix` — issue single cert covering both
  `gammu.home.matos.cc` and `gammu.ts.matos.cc` as SANs
- `hosts/darwin/codex/default.nix` — issue single cert covering both
  `codex.home.matos.cc` and `codex.ts.matos.cc` as SANs

---

## 26.06.02 — 2026-06-26

### Added

- `modules/nixos/sudo.nix` — `/etc/sudoers.d/nix-rebuild-sudoers`; allows
  `wheel` group members to run `nixos-rebuild` without a password
- `modules/darwin/sudo.nix` — same file; allows `staff` group members to run
  `darwin-rebuild` without a password
- `hosts/nixos/common-nixos.nix`, `hosts/darwin/common-darwin.nix` — import
  the respective `sudo.nix` modules
- `.gitignore` — added `result` (nix build symlink) and `.pre-commit-config.yaml`
- `home/alberth/default.nix` — `User = "git"` added to `programs.ssh.settings."github.com"`
- `home/alberth/default.nix` — `nixpush` alias: `cd ~/Projects/nixie && git push`

### Fixed

- `modules/darwin/sudo.nix` — removed unsupported `mode` option; nix-darwin's
  `environment.etc` does not support `mode` (unlike NixOS)

---

## 26.06.01 — 2026-06-26

### Added

- `home/alberth/ghostty.nix` (new) — Ghostty settings shared across all darwin
  hosts, migrated from the live config: JetBrainsMono Nerd Font 14pt, `-calt`
  ligatures off, Dracula adaptive light/dark theme, 90% opacity with blur,
  macOS xray icon, secure input, extended shell integration features, clipboard
  improvements, `notify-on-command-finish = unfocused`
- `home/alberth/codex.nix`, `home/alberth/darwintron.nix` — import `ghostty.nix`
- `.github/workflows/flake-update.yml` — weekly scheduled workflow (Sunday
  02:00 UTC) using `DeterminateSystems/update-flake-lock`; opens a PR so CI
  runs before merge; also triggerable manually via `workflow_dispatch`
- `home/alberth/default.nix` — source `$HOME/.config/op/plugins.sh` in bash,
  zsh, and fish interactive init (guarded by a file-existence check)
- `home/alberth/default.nix` — `ripgrep` added to `home.packages` (all hosts)
- `home/alberth/default.nix` — `nixpull` alias: `cd ~/Projects/nixie && git pull`
- `home/alberth/default.nix` — `cat` aliased to `bat` across all shells
- `home/alberth/atuin.nix` — atuin shell history with bash/zsh/fish integrations;
  fuzzy search, auto-sync to api.atuin.sh every 5 minutes, compact style,
  global filter mode
- `home/alberth/default.nix` — new `home.packages` entries:
  tools (`htop`, `imagemagick`, `pandoc`, `ragenix`) and fonts
  (`font-awesome`, `hack-font`, `nerd-fonts.hack`)
- `statix` added to the devShell in `flake.nix`
- `pre-commit-hooks.nix` flake input; `preCommitCheck` in `flake.nix` with
  `nixfmt`, `markdownlint-cli2`, and `commitlint` hooks; `shellHook` wired into
  devShell so `nix develop` installs hooks automatically
- `home/alberth/chezmoi.nix` — installs chezmoi, sets `githubUsername = "amatos"`
- 1Password app and CLI added to Homebrew casks (`codex`) and `home.packages` (NixOS)
- `home/alberth/devenv.nix` — devenv package and config
- `amatos.cachix.org` added as a trusted binary cache in `modules/common/packages.nix`
- GitHub Actions CI (`.github/workflows/ci.yml`): `lint`, `flake-check`, `eval-darwin`
- `formatter` output in `flake.nix` wiring `nixfmt` for `nix fmt` support
- Starship prompt (`home/alberth/starship.nix`) — two-line rainbow prompt
- Fish set as default shell on all hosts
- `modules/nixos/agenix-fix.nix` (new) — workaround for ragenix/systemd-tmpfiles
  ordering race; removes stale `/run/agenix` directory before `agenixInstall`

### Changed

- `home/alberth/ghostty.nix` — replaced auto-generated defaults with actual
  migrated config; removed `catppuccin.ghostty.enable` (superseded by explicit
  Dracula theme)
- `home/alberth/default.nix` — `nixswitch` now uses `sudo darwin-rebuild switch
  --flake` on darwin and `sudo nixos-rebuild switch --flake` on NixOS
- `home/alberth/atuin.nix` — replaced `up_key_binding = false` with
  `flags = [ "--disable-up-arrow" ]`; correctly prevents atuin from binding ↑
- `flake.nix` — `markdownlint-cli2` hook lints all `.md` files on every commit
  (`pass_filenames = false`, `always_run = true`)
- `.github/workflows/ci.yml` — removed separate `build-gammu` / `build-nixostron`
  jobs; NixOS evaluation covered by `nix flake check`
- `devenv` moved from `environment.systemPackages` to `home.packages`
- Switched from Powerlevel10k (zsh) to Starship (all shells)
- `modules/common/secrets.nix` — removed YubiKey identity stub from
  `age.identityPaths`; host key alone is sufficient for automated activation
- `CLAUDE.md` — added Releases section (CalVer scheme, changelog grouping convention)
- `nix-secrets/secrets.nix` — updated gammu host age key

### Fixed

- `modules/common/certbot-secrets.nix` — removed `path = "/run/agenix/luadns.ini"`;
  setting a path inside `/run/agenix/` caused agenix to `mkdir -p /run/agenix`
  before the symlink step, making activation fail
- `modules/nixos/certbot.nix`, `modules/darwin/certbot.nix` — updated credential
  path to `/run/agenix/luadns-ini`
- `home/alberth/codex.nix`, `home/alberth/darwintron.nix` — set
  `programs.ghostty.settings.command` to nix-managed fish path so Ghostty
  launches fish instead of zsh
- `.markdownlint-cli2.yaml` — added `MD060: { style: "compact" }` and `ignores`
  for `.direnv/**` and `node_modules/**`
- `brew-nix.md`, `CLAUDE.md`, `README.md` — full markdownlint pass
- `home/alberth/chezmoi.nix` — replaced unavailable `programs.chezmoi` with
  `home.packages` + manual config file
- `pkgs/python/luadns.nix` — replaced comment-only file with `{ }` so `nix fmt` passes
- `hosts/nixos/common-nixos.nix` — import `agenix-fix.nix`

### Removed

- `catppuccin.ghostty.enable = true` from `codex.nix` and `darwintron.nix`
- `flake.nix` — disabled `markdown-link-check` hook (no network in Nix sandbox)
- `.pre-commit-config.yaml` — superseded by Nix-managed hooks
- `secrets/secrets.nix` — redundant duplicate; canonical copy lives in `nix-secrets`
- `.gitea/workflows/ci.yml` — replaced by GitHub Actions
- `neovim` from `home.packages` — provided by `nvf.nix`
