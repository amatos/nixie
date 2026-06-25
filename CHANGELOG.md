# Changelog

All notable changes to this project will be documented in this file.

---

## 2026-06-25 (3)

### Added
- `home/alberth/chezmoi.nix` — installs chezmoi via `programs.chezmoi` and configures `sourceURL = "https://github.com/amatos/dotfiles"` so `chezmoi init --apply` works without arguments on a new machine
- Imported in `home/alberth/default.nix` (applies to all hosts)

---

## 2026-06-25 (2)

### Added
- 1Password app and CLI (`1password`, `1password-cli`) added to Homebrew casks in `hosts/darwin/codex/default.nix`
- `_1password-gui` and `_1password-cli` added to `home.packages` in `home/alberth/nixos.nix` for NixOS hosts

---

## 2026-06-25

### Added
- `home/alberth/devenv.nix` — home-manager module for devenv; installs the package and manages `~/.config/devenv/devenv.yaml`
- `amatos.cachix.org` added as a trusted binary cache in `modules/common/packages.nix`
- `home/alberth/default.nix` now imports `devenv.nix` and `starship.nix` via the `imports` list

### Changed
- `devenv` moved from `environment.systemPackages` (`modules/common/packages.nix`) to `home.packages` (via `devenv.nix`) — user-facing tools belong in home-manager per project conventions
- `pkgs/python/luadns.nix` fixed — was a comment-only file (invalid Nix); replaced with `{ }` so `nix fmt` passes

### Removed
- `secrets/secrets.nix` — redundant duplicate of `nix-secrets/secrets.nix`; the `.age` files and their recipient declarations live exclusively in the `nix-secrets` repo

---

## 2026-06-24

### Added
- GitHub Actions CI (`.github/workflows/ci.yml`) with five jobs: `lint`, `flake-check`, `build-gammu`, `build-nixostron` (native aarch64 on `ubuntu-24.04-arm`), `eval-darwin`
- `formatter` output in `flake.nix` wiring `nixfmt` for `nix fmt` support
- Starship prompt (`home/alberth/starship.nix`) matching the p10k rainbow layout — two-line prompt with fill, OS icon, git status, language/tool segments
- Fish set as default shell on all hosts (`programs.fish.enable` + `users.users.*.shell = pkgs.fish` in both `common-darwin.nix` and `common-nixos.nix`)

### Changed
- Switched from Powerlevel10k (zsh) to Starship (all shells) — removed p10k plugin, `.p10k.zsh` file reference, and `initContent` source line from `home/alberth/default.nix`
- `modules/common/secrets.nix` — removed YubiKey identity stub from `age.identityPaths`; age initialises all identity paths before decryption, and the missing plugin binary caused all secrets to fail during automated activation; host key alone is sufficient

### Removed
- `.gitea/workflows/ci.yml` — replaced by GitHub Actions
