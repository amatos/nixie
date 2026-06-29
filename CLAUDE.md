# nixie — project directives

## What this is

nixie is a unified NixOS + nix-darwin system configuration managed as a single Nix flake.
It uses Determinate Nix and is driven exclusively by flakes — no `nix-env`, no imperative installs.

**Key inputs:** nix-darwin, home-manager (as a NixOS/darwin module, never standalone),
ragenix (age-encrypted secrets via YubiKey), nvf (declarative neovim),
catppuccin/nix (theming), nix-homebrew (declarative Homebrew on darwin).

**Secrets** live in a separate non-flake repo (`github:amatos/nix-secrets`, `flake = false`)
and are referenced as `nix-secrets` in specialArgs.

---

## Hosts

| Name | Platform | Arch | File | Notes |
| --- | --- | --- | --- | --- |
| `codex` | nix-darwin | aarch64-darwin | `hosts/darwin/codex/` | physical |
| `darwintron` | nix-darwin | aarch64-darwin | `hosts/darwin/darwintron/` | virtual |
| `nixostron` | NixOS | aarch64-linux | `hosts/nixos/nixostron/` | virtual |
| `gammu` | NixOS | x86_64-linux | `hosts/nixos/gammu/` | physical |
| `porkchop` | NixOS | x86_64-linux | `hosts/nixos/porkchop/` | physical |
| `ephemeraltron` | NixOS | x86_64-linux | `hosts/nixos/ephemeraltron/` | installer template |
| `template-darwin` | nix-darwin | aarch64-darwin | `hosts/darwin/template-darwin/` | new host template |
| `template-nixos` | NixOS | x86_64-linux | `hosts/nixos/template-nixos/` | new host template |

Hosts whose names end in `tron` are virtual machines.

**Adding a new NixOS host:** create `hosts/nixos/<name>/default.nix` importing
`../common-nixos.nix` and `./hardware-configuration.nix`, set `networking.hostName`,
add an entry to `nixosConfigurations` in `flake.nix` using `sharedSpecialArgs`.

**Adding a new darwin host:** create `hosts/darwin/<name>/default.nix` importing
`../common-darwin.nix`, set `networking.hostName` and `networking.computerName`,
merge a home overlay via
`home-manager.users.${primaryUser} = { imports = [ ../../../home/alberth/<name>.nix ]; }`,
and add an entry to `darwinConfigurations` in `flake.nix`. Create a matching
`home/alberth/<name>.nix` for darwin platform-specific settings (gpg-agent pinentry, etc.).

---

## Project layout

```text
flake.nix                        # inputs, sharedSpecialArgs, host wiring
users.nix                        # single source of truth for all users
secrets/secrets.nix              # ragenix recipient definitions

hosts/
  darwin/
    common-darwin.nix            # shared darwin config (nix-daemon, Touch ID, mkalias, home-manager base)
    codex/default.nix            # codex-specific: homebrew, certbot, dockutil
    darwintron/default.nix       # darwintron-specific: hostname only
  nixos/
    common-nixos.nix             # shared NixOS config (bootloader, locale, certbot, stateVersion)
    nixostron/default.nix        # hostname only
    gammu/default.nix            # hostname only

modules/
  common/                        # cross-platform modules (NixOS + darwin)
    packages.nix                 # shared system packages + nixpkgs.config.allowUnfree
    secrets.nix                  # ragenix identity paths
    age-host-key.nix             # generates /etc/age/host-key on first activation
    github-secrets.nix           # deploys GitHub SSH keys via ragenix
    certbot-secrets.nix          # deploys LuaDNS credentials via ragenix
  nixos/
    users.nix                    # NixOS user declarations
    home-manager.nix             # shared NixOS home-manager block
    certbot.nix                  # systemd timer, weekly + 1h random delay
    ghostty.nix                  # conditional on display server presence
  darwin/
    users.nix                    # darwin user declarations (strips NixOS-only fields)
    certbot.nix                  # launchd daemon, Sunday 03:00

home/alberth/
  default.nix                    # all shared home config (shells, git, gpg, tools, catppuccin)
  nvf.nix                        # neovim via nvf
  codex.nix                      # darwin/codex overlay (pinentry-mac, ghostty, 1Password SSH)
  darwintron.nix                 # darwin/darwintron overlay (pinentry-mac, ghostty)
  nixos.nix                      # NixOS overlay (pinentry-tty, open alias)
```

---

## Conventions

### users.nix is the single source of truth for user data

- `primaryUser` in `users.nix` drives all username references throughout the codebase.
- Never hardcode a username string in a module. Import `users.nix` and use `userDefs.primaryUser`.
- `email` and `gpgSigningKey` are custom fields on user entries; strip them before passing to
  `users.users` (handled in `modules/nixos/users.nix` and `modules/darwin/users.nix`).

### Module placement

- **Cross-platform logic** → `modules/common/`
- **NixOS-only** → `modules/nixos/`
- **darwin-only** → `modules/darwin/`
- **User home config** → `home/alberth/` (platform-specific divergences go in the host overlay file)

### flake.nix

- All hosts share `sharedSpecialArgs = { inherit self nix-secrets nvf catppuccin-bat catppuccin; }`.
- Do not add per-host specialArgs unless there is no other way.

### Packages

- User-facing apps and fonts → `home.packages` in `home/alberth/default.nix`
- System daemons and tools needed before home-manager → `environment.systemPackages`
- darwin-specific system tools (e.g. `dockutil`) → inline in the host's `default.nix`
- `nixpkgs.config.allowUnfree = true` is set in `modules/common/packages.nix`

### Homebrew (darwin only)

- Managed declaratively via nix-homebrew; `cleanup = "uninstall"` on codex.
- When migrating a cask to a nix package, leave the cask entry as a comment with a note of
  where it moved (`— moved to pkgs.X in path/to/file.nix`).
- Fonts and apps with a nixpkgs equivalent should be in `home.packages`, not homebrew.

### home-manager host overlays

- `common-darwin.nix` sets the base home-manager block with `home/alberth` and `nvf.nix`.
- Each darwin host merges its own overlay by adding
  `home-manager.users.${primaryUser} = { imports = [ .../home/alberth/<host>.nix ]; };` —
  the module system merges the imports lists automatically.
- NixOS hosts use `modules/nixos/home-manager.nix` which includes the nixos overlay already.

### Secrets

- All secrets are age-encrypted via ragenix. Recipient lists are in `secrets/secrets.nix`.
- Secrets are deployed to known paths by modules in `modules/common/` or platform modules.
- The YubiKey identity stub and host key paths are configured in `modules/common/secrets.nix`.

### Theming

- catppuccin flavor: `macchiato`, accent: `blue` — set globally in `home/alberth/default.nix`.
- bat uses a custom auto light/dark config (macchiato dark / latte light); do not enable `catppuccin.bat`.
- nvf manages its own catppuccin-mocha internally; do not enable `catppuccin.nvim`.

### Certbot

- Certificates are issued per-host via `nixie.certbot.enable = true` and `nixie.certbot.domains`.
- Darwin: launchd daemon, runs Sunday 03:00.
- NixOS: systemd timer, weekly cadence with 1h randomized delay and `Persistent = true`.
- Both use `--keep-until-expiring` — safe to run frequently.

---

## Formatting

`.nix` files are formatted automatically by a git pre-commit hook — do not run
`nix fmt` manually before committing. Never include `nix fmt` in commit instructions.

---

## Commits

All commits must be GPG-signed (`git commit -S`) and follow the
[Conventional Commits](https://www.conventionalcommits.org/) format enforced
by commitlint (`.commitlintrc.yaml`):

```text
<type>[optional scope]: <subject>

[optional body]

[optional footer]
```

Allowed types (breaking change markers `!` are not used — use `breaking` instead):

| Type | Use for |
| --- | --- |
| `feat` | New functionality |
| `fix` | Bug or breakage fix |
| `docs` | Documentation only |
| `chore` | Maintenance, deps, tooling |
| `ci` | CI / GitHub Actions changes |
| `test` | Adding or updating tests |
| `refactor` | Code restructuring without behaviour change |
| `perf` | Performance improvements |
| `breaking` | Backwards-incompatible changes |

Rules enforced by commitlint:

- Body and footer must be preceded by a blank line.
- Body lines should be ≤ 100 characters (warning, not error; URLs are exempt).
- Scope is optional; use it to identify the affected file or subsystem
  (e.g. `feat(atuin): …`).

---

## Releases

Releases use CalVer: `yy.mm.release` (e.g. `26.06.01`).

- The release counter resets to `01` at the start of each new month.
- Each subsequent release within the same month increments by 1: `26.06.01`, `26.06.02`, etc.
- Tags are GPG-signed: `git tag -s yy.mm.release -m "Release yy.mm.release"`.
- Before tagging, check the highest existing tag for the month:
  `git tag --list 'yy.mm.*' | sort`
- When creating a release, combine all changes since the last release into a
  single entry in `CHANGELOG.md` and note the tagged version.
- Unreleased changes must be grouped under an `## Unreleased` section at the
  top of `CHANGELOG.md` until they are included in a release.
- `CHANGELOG.md` lines must be ≤ 80 characters; never exceed 100.

---

## Before making changes

1. Check `users.nix` before adding any user-related config — the field you need may already exist.
2. Check `modules/common/` before creating a platform-specific module — if it works on both
   platforms, it belongs there.
3. Check `home/alberth/default.nix` before adding to a host overlay — if it applies to all hosts,
   put it in the shared home config.
4. Propose structural/architectural changes before implementing — describe the approach and wait
   for confirmation.
