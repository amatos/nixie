# Changelog

All notable changes to this project will be documented in this file.

---

## 2026-06-26 (2)

### Changed

- `home/alberth/default.nix` — `nixswitch` now uses `sudo darwin-rebuild switch --flake`
  on darwin and `sudo nixos-rebuild switch --flake` on NixOS; `nixbuild` still uses `nh`

---

## 2026-06-26

### Fixed

- `home/alberth/codex.nix`, `home/alberth/darwintron.nix` — set
  `programs.ghostty.settings.command` to `/etc/profiles/per-user/alberth/bin/fish`
  so Ghostty launches fish directly instead of defaulting to zsh

---

## 2026-06-25 (16)

### Added

- `home/alberth/default.nix` — `nixpull` alias: `cd ~/Projects/nixie && git pull`

---

## 2026-06-25 (15)

### Fixed

- `home/alberth/atuin.nix` — replaced `up_key_binding = false` (config-file
  option ignored by shell init scripts) with `flags = [ "--disable-up-arrow" ]`
  passed to `atuin init`; this correctly prevents atuin from binding ↑ in
  bash, zsh, and fish

---

## 2026-06-25 (14)

### Added

- `home/alberth/default.nix` — `cat` aliased to `bat` across all shells

---

## 2026-06-25 (13)

### Changed

- `home/alberth/atuin.nix` — set `up_key_binding = false`; up-arrow now uses
  shell native history, atuin search accessible via Ctrl-R only

---

## 2026-06-25 (12)

### Fixed

- `modules/common/certbot-secrets.nix` — removed `path = "/run/agenix/luadns.ini"`;
  setting a path inside `/run/agenix/` caused agenix to run `mkdir -p /run/agenix`
  before creating the generation symlink, making the symlink step fail with
  "cannot overwrite directory". Secret now uses its agenix default path
  (`/run/agenix/luadns-ini`).
- `modules/nixos/certbot.nix` — updated `--dns-luadns-credentials` to use
  `/run/agenix/luadns-ini`
- `modules/darwin/certbot.nix` — same credential path fix

---

## 2026-06-25 (11)

### Fixed

- `modules/nixos/agenix-fix.nix` (new) — workaround for ragenix/systemd-tmpfiles
  ordering issue: `systemd-tmpfiles` creates `/run/agenix` as a directory during
  activation; `agenixInstall` then fails because `ln -s` cannot overwrite a
  directory. The new script removes the directory (if not already a symlink)
  after `tmpfiles` but before `agenixInstall`.
- `hosts/nixos/common-nixos.nix` — import `agenix-fix.nix`

---

## 2026-06-25 (10)

### Fixed

- `.markdownlint-cli2.yaml` — added `MD060: { style: "compact" }` to resolve CI
  failure; table column style now explicitly set to compact
- `brew-nix.md` — updated all table separator rows from `|---|---|---|` to
  `| --- | --- | --- |` to satisfy compact table style

---

## 2026-06-25 (9)

### Added

- `home/alberth/default.nix` — new `home.packages` entries:
  - Tools: `htop`, `imagemagick`, `pandoc`, `ragenix`
  - Fonts: `font-awesome`, `hack-font`, `nerd-fonts.hack`

### Removed

- `neovim` from `home.packages` — already provided by `nvf.nix`

---

## 2026-06-25 (8)

### Added

- `statix` added to the devShell in `flake.nix` — Nix linter that catches
  antipatterns and suggests idiomatic fixes

---

## 2026-06-25 (7)

### Added

- `home/alberth/atuin.nix` — atuin shell history with bash/zsh/fish integrations;
  fuzzy search, auto-sync to api.atuin.sh every 5 minutes, compact style,
  global filter mode, session-scoped up-arrow binding

---

## 2026-06-25 (6)

### Fixed

- `home/alberth/chezmoi.nix` — replaced `programs.chezmoi` (not in home-manager 26.05)
  with `home.packages = [ pkgs.chezmoi ]` and a minimal `~/.config/chezmoi/chezmoi.toml`
  that sets `githubUsername = "amatos"`

---

## 2026-06-25 (5)

### Added

- `pre-commit-hooks.nix` flake input (`github:cachix/pre-commit-hooks.nix`)
- `preCommitCheck` in `flake.nix` with working hooks:
  - `nixfmt` — Nix formatting
  - `markdownlint-cli2` (`pkgs.markdownlint-cli2`) — markdown linting
  - `markdown-link-check` (`pkgs.markdown-link-check`) — link validation
  - `commitlint` (`pkgs.commitlint`, commit-msg stage) — conventional commit enforcement
- `checks` output exposing the pre-commit check so `nix flake check` also validates formatting
- `shellHook` wired into the devShell — `nix develop` installs hooks into `.git/hooks` automatically

### Removed

- `.pre-commit-config.yaml` — superseded by the Nix-managed hooks above
- Hooks from `pre-commit/pre-commit-hooks` (`check-yaml`, `trailing-whitespace`, etc.) —
  no default entry in pre-commit-hooks.nix with nixpkgs 26.05; omitted
- `check-branch` hook — not available in nixpkgs

---

## 2026-06-25 (4)

### Changed

- `.github/workflows/ci.yml` — removed `build-gammu` and `build-nixostron` jobs;
  NixOS evaluation still covered by `nix flake check` in the `flake-check` job

---

## 2026-06-25 (3)

### Added

- `home/alberth/chezmoi.nix` — installs chezmoi and configures `githubUsername = "amatos"`
  so `chezmoi init` can infer the source repo
- Imported in `home/alberth/default.nix` (applies to all hosts)

---

## 2026-06-25 (2)

### Added

- 1Password app and CLI (`1password`, `1password-cli`) added to Homebrew casks
  in `hosts/darwin/codex/default.nix`
- `_1password-gui` and `_1password-cli` added to `home.packages`
  in `home/alberth/nixos.nix` for NixOS hosts

---

## 2026-06-25

### Added

- `home/alberth/devenv.nix` — home-manager module for devenv; installs the package
  and manages `~/.config/devenv/devenv.yaml`
- `amatos.cachix.org` added as a trusted binary cache in `modules/common/packages.nix`
- `home/alberth/default.nix` now imports `devenv.nix` and `starship.nix`

### Changed

- `devenv` moved from `environment.systemPackages` to `home.packages` (via `devenv.nix`) —
  user-facing tools belong in home-manager per project conventions
- `pkgs/python/luadns.nix` fixed — was a comment-only file (invalid Nix);
  replaced with `{ }` so `nix fmt` passes

### Removed

- `secrets/secrets.nix` — redundant duplicate of `nix-secrets/secrets.nix`;
  the `.age` files and recipient declarations live exclusively in the `nix-secrets` repo

---

## 2026-06-24

### Added

- GitHub Actions CI (`.github/workflows/ci.yml`) with jobs:
  `lint`, `flake-check`, `build-gammu`, `build-nixostron`, `eval-darwin`
- `formatter` output in `flake.nix` wiring `nixfmt` for `nix fmt` support
- Starship prompt (`home/alberth/starship.nix`) matching the p10k rainbow layout —
  two-line prompt with fill, OS icon, git status, language/tool segments
- Fish set as default shell on all hosts (`programs.fish.enable` +
  `users.users.*.shell = pkgs.fish` in `common-darwin.nix` and `common-nixos.nix`)

### Changed

- Switched from Powerlevel10k (zsh) to Starship (all shells) — removed p10k plugin,
  `.p10k.zsh` file reference, and `initContent` source line from `home/alberth/default.nix`
- `modules/common/secrets.nix` — removed YubiKey identity stub from `age.identityPaths`;
  age initialises all identity paths before decryption, and the missing plugin binary
  caused all secrets to fail during automated activation; host key alone is sufficient

### Removed

- `.gitea/workflows/ci.yml` — replaced by GitHub Actions
