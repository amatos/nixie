# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `hosts/nixos/porkchop/` (new) — NixOS host mirroring gammu: Syncthing with
  TLS and dual-stack GUI, nftables firewall, certbot for `porkchop.home.matos.cc`
  and `porkchop.ts.matos.cc`; `hardware-configuration.nix` is a stub pending
  `nixos-generate-config` on the actual machine
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

---

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
