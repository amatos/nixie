# nixie — project directives

## Agent conventions

Any message prefixed with `question:` is a purely theoretical/discussion
request. Treat it as a request for information, reasoning, or discussion
only — **never** as an instruction to perform an action (no file edits,
commits, deployments, or other side effects), regardless of how the rest
of the phrasing reads.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for how nixie, nix-secrets,
keytabs-matos-cc, and nixie-homes fit together as a system — read it first
if you're new to this repo or making a change that spans more than one of
these repos.

## What this is

nixie is a unified NixOS + nix-darwin system configuration managed as a single Nix flake.
It uses Determinate Nix and is driven exclusively by flakes — no `nix-env`, no imperative installs.

**Key inputs:** nix-darwin, home-manager (as a NixOS/darwin module — nixie itself never
runs home-manager standalone), ragenix (age-encrypted secrets via YubiKey), nvf
(declarative neovim), nix-homebrew (declarative Homebrew on darwin).

**Home-manager configuration** lives in the separate `github:amatos/nixie-homes` repo
(input `nixie-homes`), a real flake (not `flake = false`) exposing `homeModules.<name>`
outputs that every host imports — see "home-manager host overlays" below. Unlike
`nix-secrets`/`keytabs-matos-cc`, `nixie-homes` is also independently usable via
`home-manager switch --flake` on any machine with Nix, with or without nixie — see its own
`CLAUDE.md`.

**Secrets** live in separate non-flake repos (`flake = false`) and are referenced via
specialArgs: text/token secrets in `github:amatos/nix-secrets` (input `nix-secrets`),
binary Kerberos keytabs in `github:amatos/keytabs-matos-cc` (input `keytabs-matos-cc`).

**`hosts/nixos/minixie`** is the one exception to the pattern above: a generic,
identity-less nixos-anywhere bootstrap target (`nixosConfigurations.minixie`) used to
get an unknown/fresh machine reachable over SSH before it gets a real host config. It
deliberately does **not** receive `sharedSpecialArgs` and never touches `nix-secrets` or
`keytabs-matos-cc` — see README "Provisioning new hosts" for the full workflow. Formerly
its own repo (`amatos/minixie`), merged into nixie to share one `flake.lock`.

---

## Hosts

| Name | Platform | Arch | File | Notes |
| --- | --- | --- | --- | --- |
| `codex` | nix-darwin | aarch64-darwin | `hosts/darwin/codex/` | physical |
| `nhcodex` | nix-darwin | aarch64-darwin | `hosts/darwin/nhcodex/` | test bed, no `nixie-homes`; `hostName` still `"codex"` |
| `darwintron` | nix-darwin | aarch64-darwin | `hosts/darwin/darwintron/` | virtual |
| `nixostron` | NixOS | aarch64-linux | `hosts/nixos/nixostron/` | virtual |
| `gammu` | NixOS | x86_64-linux | `hosts/nixos/gammu/` | physical |
| `porkchop` | NixOS | x86_64-linux | `hosts/nixos/porkchop/` | physical |
| `huginn` | NixOS | x86_64-linux | `hosts/nixos/huginn/` | physical |
| `picanha` | NixOS | x86_64-linux | `hosts/nixos/picanha/` | physical, stub — not in `flake.nix` yet |
| `sirloin` | NixOS | x86_64-linux | `hosts/nixos/sirloin/` | physical, stub — not in `flake.nix` yet |
| `ephemeraltron` | NixOS | x86_64-linux | `hosts/nixos/ephemeraltron/` | installer template |
| `minixie` | NixOS | x86_64-linux | `hosts/nixos/minixie/` | generic nixos-anywhere bootstrap target, not a real host — see README "Provisioning new hosts" |
| `template-darwin` | nix-darwin | aarch64-darwin | `hosts/darwin/template-darwin/` | new host template |
| `template-nixos` | NixOS | x86_64-linux | `hosts/nixos/template-nixos/` | new host template |

Hosts whose names end in `tron` are virtual machines. `picanha`/`sirloin` have host
directories committed (no home-manager overlay yet) but aren't wired into
`nixosConfigurations` in `flake.nix` yet — check `flake.nix` before assuming a host
listed here is actually deployable.

**Adding a new NixOS host:** create `hosts/nixos/<name>/default.nix` importing
`../common-nixos.nix` and `./hardware-configuration.nix`, set `networking.hostName`,
add an entry to `nixosConfigurations` in `flake.nix` using `sharedSpecialArgs`. If
host-specific home settings are needed, add `alberth/<name>.nix` to the `nixie-homes`
repo — `alberth/nixos.nix` auto-imports it when present, no wiring needed here beyond
`nix flake lock --update-input nixie-homes`.

**Adding a new darwin host:** create `hosts/darwin/<name>/default.nix` importing
`../common-darwin.nix`, set `networking.hostName` and `networking.computerName`,
merge a home overlay via
`home-manager.users.${primaryUser} = { imports = [ nixie-homes.homeModules.alberth-<name> ]; }`,
and add an entry to `darwinConfigurations` in `flake.nix`. Add a matching
`alberth/<name>.nix` and a `homeModules.alberth-<name>` output entry to the
`nixie-homes` repo (commit and push it there first) for darwin platform-specific
settings (gpg-agent pinentry, etc.).

---

## Project layout

```text
flake.nix                        # inputs, sharedSpecialArgs, host wiring
users.nix                        # single source of truth for all users

hosts/
  darwin/
    common-darwin.nix            # shared darwin config (nix-daemon, Touch ID, mkalias)
    codex/default.nix            # codex-specific: homebrew, certbot, dockutil
    nhcodex/default.nix          # test bed, no nixie-homes; hostName still "codex"
    darwintron/default.nix       # darwintron-specific: hostname only
  nixos/
    common-nixos.nix             # shared NixOS config (bootloader, locale, certbot, stateVersion)
    nixostron/default.nix        # hostname only
    gammu/default.nix            # docker/containerd, syncthing, certbot, Steam gaming,
                                  # Ollama/Open WebUI
    minixie/default.nix          # generic nixos-anywhere bootstrap target (no sharedSpecialArgs)

modules/
  common/                        # cross-platform modules (NixOS + darwin)
    packages.nix                 # shared system packages + nixpkgs.config.allowUnfree
    secrets.nix                  # ragenix identity paths
    age-host-key.nix             # generates /etc/age/host-key on first activation
    github-secrets.nix           # deploys GitHub SSH keys via ragenix (age.secrets only)
    certbot-secrets.nix          # deploys LuaDNS credentials via ragenix
  nixos/
    users.nix                    # NixOS user declarations
    home-manager.nix             # shared NixOS home-manager block
    certbot.nix                  # systemd timer, weekly + 1h random delay
    ghostty.nix                  # conditional on display server presence
    github-secrets-tmpfiles.nix  # pre-creates ~/.ssh via systemd-tmpfiles (NixOS-only; darwin has no systemd)
  darwin/
    users.nix                    # darwin user declarations (strips NixOS-only fields)
    home-manager.nix             # base home-manager block sourced from nixie-homes;
                                  # not part of common-darwin.nix, so hosts can opt out
    certbot.nix                  # launchd daemon, Sunday 03:00
```

Home-manager configuration is **not** in this repo — it lives in the separate
`nixie-homes` repo (`github:amatos/nixie-homes`, input `nixie-homes`), imported via
`nixie-homes.homeModules.<name>` (see "home-manager host overlays" below). Its own
`alberth/` layout (base config, per-host overlays) is documented in its `CLAUDE.md`.

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
- **User home config** → the separate `nixie-homes` repo, not this one (platform-specific
  divergences go in the host overlay file there) — see "home-manager host overlays" below
- darwin declares no `systemd` option namespace at all (no systemd on macOS). Gating a
  `systemd.*` option's *value* with `lib.mkIf`/`lib.optionals pkgs.stdenv.isLinux` inside a
  `modules/common/` file is not enough — the option *key* itself doesn't exist on darwin and
  evaluation fails regardless of the value. Any `systemd.*` setting must live in
  `modules/nixos/`, imported only from NixOS hosts (see `github-secrets-tmpfiles.nix`, split
  out of `modules/common/github-secrets.nix` for this reason).

### darwin activation scripts

- Unlike NixOS, nix-darwin's `/activate` script is assembled from a **fixed, hardcoded list**
  of named stages (`preActivation`, `groups`, `users`, `applications`, ..., `homebrew`,
  `postActivation` — see upstream `modules/system/activation-scripts.nix`). Defining
  `system.activationScripts.<your-own-name>.text` is accepted by the module system and
  evaluates fine, but is **silently never run** — it isn't one of the names the fixed script
  concatenates. This bit the OrbStack `ContainerData` volume script, the long-standing `ntp`
  script in `hosts/darwin/common-darwin.nix`, and `modules/common/age-host-key.nix`'s
  `/etc/age/host-key` generation (fixed by branching on `pkgs.stdenv.isDarwin`; see CHANGELOG).
- Use `system.activationScripts.extraActivation.text = lib.mkAfter "..."` instead — it's
  nix-darwin's supported extension point and runs early (before `homebrew` and home-manager
  activation). `postActivation` (runs last, after `homebrew`) is the other valid hook if
  ordering after Homebrew/home-manager matters.
- To verify a darwin activation script actually ran, don't trust that `darwin-rebuild switch`
  succeeded — check the *content*:
  `nix eval --raw .#darwinConfigurations.<host>.config.system.activationScripts.script.text | grep <marker>`
  must find it, and so must `grep <marker> /run/current-system/activate` after switching.

### flake.nix

- All hosts share
  `sharedSpecialArgs = { inherit self nix-secrets keytabs-matos-cc nvf homebrew-autoupdate qmd stylix nixie-homes; }`.
- Do not add per-host specialArgs unless there is no other way.

### Nix daemon settings (Determinate)

- Every host uses Determinate Nix (`determinate.darwinModules.default` /
  `determinate.nixosModules.default`), which manages `/etc/nix/nix.conf`
  itself and expects custom settings in `/etc/nix/nix.custom.conf` instead.
- **NixOS**: the standard `nix.settings` (e.g. in `modules/common/packages.nix`)
  works as expected — Determinate's NixOS module redirects the normal
  generated `nix.conf` straight into `nix.custom.conf`.
- **darwin**: Determinate forces `nix.enable = false`, so nix-darwin never
  writes `/etc/nix/nix.conf` at all — anything set via `nix.settings` is
  silently dropped (this is why a plain `nix.settings.trusted-users` entry
  doesn't take effect on codex). Use `determinateNix.customSettings` instead
  (see `hosts/darwin/common-darwin.nix`); it maps directly onto
  `/etc/nix/nix.custom.conf`. Verify with:
  `nix eval .#darwinConfigurations.<host>.config.determinateNix.customSettings.trusted-users`
  or by building the system and inspecting `<closure>/etc/nix/nix.custom.conf`.

### Packages

- User-facing apps and fonts → `home.packages` in `nixie-homes`' `alberth/default.nix` (a
  separate repo — see "home-manager host overlays" below)
- System daemons and tools needed before home-manager → `environment.systemPackages`
- darwin-specific system tools (e.g. `dockutil`) → inline in the host's `default.nix`
- `nixpkgs.config.allowUnfree = true` is set in `modules/common/packages.nix`

### Homebrew (darwin only)

- Managed declaratively via nix-homebrew; `cleanup = "uninstall"` on codex.
- When migrating a cask to a nix package, leave the cask entry as a comment with a note of
  where it moved (`— moved to pkgs.X in path/to/file.nix`).
- Fonts and apps with a nixpkgs equivalent should be in `home.packages`, not homebrew.
- Some casks (e.g. `orbstack`) have no nix-darwin module to manage their config/data, but the
  app's own data files can still be nix-managed: install via the cask in the host's
  `default.nix`, then manage the app's config/data location declaratively in `nixie-homes`'
  `alberth/<host>.nix` overlay (e.g. `home.file` for config files, an out-of-store
  symlink for relocating data to another volume). See `hosts/darwin/codex/default.nix`
  (OrbStack cask + `ContainerData` APFS volume activation script) and `nixie-homes`'
  `alberth/codex.nix` (Docker daemon config + Group Container symlink) for the pattern.

### home-manager host overlays

Home-manager configuration lives in the separate `nixie-homes` repo
(`github:amatos/nixie-homes`, input `nixie-homes`), a real flake exposing
`homeModules.<name>` outputs — not `flake = false` like `nix-secrets`/`keytabs-matos-cc`,
since `nixie-homes` must also work standalone. See its own `CLAUDE.md` for that repo's
layout and conventions; here, only the consumption side:

- `modules/darwin/home-manager.nix` sets the base home-manager block with
  `nixie-homes.homeModules.alberth` and `.alberth-nvf`. It is **not** part of
  `common-darwin.nix` — each darwin host that wants `nixie-homes` imports both
  explicitly (`../common-darwin.nix` and `../../../modules/darwin/home-manager.nix`),
  so a host can opt out of `nixie-homes` entirely by only importing the former. See
  `hosts/darwin/nhcodex` — a lean test bed with zero `nixie-homes` involvement,
  reusing `common-darwin.nix` without duplicating anything.
- Each darwin host merges its own overlay by adding
  `home-manager.users.${primaryUser} = { imports = [ nixie-homes.homeModules.alberth-<host> ]; };`
  — the module system merges the imports lists automatically. (Note: `imports` inside a
  submodule value is the raw module-import mechanism, resolved before option merging —
  `lib.mkForce`/`lib.mkOverride` do **not** work on it the way they do on a normal
  list-typed option; there is no way to "cancel" one module's `imports` contribution
  from another module merged into the same submodule. This is why opting out means not
  importing `modules/darwin/home-manager.nix` in the first place, not overriding it.)
- NixOS hosts use `modules/nixos/home-manager.nix`, which already includes
  `nixie-homes.homeModules.alberth-nixos` (the NixOS-integration overlay).
- To add a new host overlay: add `alberth/<host>.nix` and a
  `homeModules.alberth-<host>` output entry to `nixie-homes`' `flake.nix`, commit and push
  it there, then run `nix flake lock --update-input nixie-homes` here before referencing it.

### Secrets

- All secrets are age-encrypted via ragenix. Recipient lists live in the external secrets
  repos' own `secrets.nix` (`nix-secrets` or `keytabs-matos-cc`), not in nixie itself.
- Secrets are deployed to known paths by modules in `modules/common/` or platform modules.
- The YubiKey identity stub and host key paths are configured in `modules/common/secrets.nix`.
- **Text secrets** (SSH keys, tokens, passwords, `.ini` credentials) go in `nix-secrets`.
- **Binary secrets** (e.g. Kerberos keytabs) go in their own dedicated repo
  (`keytabs-matos-cc`) — git diffs binary files poorly and they don't share the
  plaintext-editing workflow of the secrets above. Never add a binary secret to
  `nix-secrets`; if a new binary secret type is needed, create a new repo for it
  following the `keytabs-matos-cc` pattern rather than mixing it into an existing repo.

#### Wiring an external secrets repo into nixie

When a secrets repo (`nix-secrets`, `keytabs-matos-cc`, or a new one) gains a file that a
host needs to consume:

1. If the repo is not yet a flake input, add it in `flake.nix`:
   `<name> = { url = "github:amatos/<repo>"; flake = false; };` (plain git repo, not a flake).
2. Thread `<name>` through the `outputs` function arguments and add it to `sharedSpecialArgs`.
3. Reference the file from the consuming host/module as `"${<name>}/<file>"` — e.g.
   `nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-codex.age";`.
4. Only declare `<name>` in a file's function args if that file actually uses it — remove
   unused specialArgs args rather than leaving dead ones around.
5. Update the `hosts/*/template-*` skeleton comments if the new pattern applies to future hosts.
6. Run `nix flake lock --update-input <name>` to pick up the input, then verify with
   `nix eval .#<darwinConfigurations|nixosConfigurations>.<host>.config.<option>` before
   committing — confirms the path resolves into the new input's store path.
7. Update the secrets repo's own `README.md` (recipients table, secrets table) — see that
   repo's `CLAUDE.md` for its conventions.

### Theming

- Dracula (<https://draculatheme.com>) fleet-wide, across every themed tool. There is no
  catppuccin/nix-style nix flake input for Dracula, so nixie carries no theming flake input at
  all: bat, neovim (nvf), and Ghostty theme via their own bundled `"dracula"`/`"Dracula"`
  option (no extra config needed beyond selecting it). Tools with no bundled Dracula variant
  (btop, eza, fzf, starship, zsh-syntax-highlighting) have the official Dracula
  colors/theme files embedded directly in `nixie-homes`' `alberth/common/theming.nix` (or, for
  starship, as `style` overrides layered onto the existing segment formats in
  `nixie-homes`' `alberth/common/starship.nix`) — see that project's own README/`draculatheme.com/<tool>`
  page as the source of truth if a value ever needs updating.
- When adding a newly-themed tool, check `draculatheme.com/<tool>` first; if it's not listed
  there, the tool has no available Dracula theme and should be left unstyled rather than
  approximated.

### Certbot

- Certificates are issued per-host via `nixie.certbot.enable = true` and `nixie.certbot.domains`.
- Darwin: launchd daemon, runs Sunday 03:00.
- NixOS: systemd timer, weekly cadence with 1h randomized delay and `Persistent = true`.
- Both use `--keep-until-expiring` — safe to run frequently.

### Gaming (Steam)

- Steam config is host-specific, not a shared module — declared inline in the host's
  `default.nix` (see `hosts/nixos/gammu/default.nix`), since only one host currently needs it.
- Minimum required: `hardware.graphics.enable = true;` and `enable32Bit = true;` — without
  32-bit graphics support Steam fails to start. `nixpkgs.config.allowUnfree` is already set
  fleet-wide in `modules/common/packages.nix`, so no per-host unfree predicate is needed.
- `programs.steam.enable = true` also implicitly enables `hardware.steam-hardware.enable`
  (Steam Controller/Valve Index udev rules).
- AMD GPUs need no extra driver packages — the default `radv` Vulkan driver (via
  `hardware.graphics`) is used; do not add `amdvlk` unless a specific game requires it.
- `programs.gamemode.enable` and `programs.gamescope.enable` are separate top-level options,
  not sub-options of `programs.steam`.

### Remote Desktop

- `gammu` uses `services.xrdp` (not KDE's native KRDP) for RDP access into Plasma, chosen
  specifically to stay flakes-only: KRDP has no declarative NixOS module — its on/off toggle
  and password live in Plasma's System Settings GUI, not the Nix store — and has had
  NixOS-specific reliability issues. `xrdp` is a proper declarative service.
- `services.xserver.enable = true;` is required alongside `services.xrdp` — xrdp's session is
  X11 (`defaultWindowManager = "startplasma-x11"`), separate and independent from SDDM's local
  Wayland session; both can run concurrently on the same host.

### Local LLM (Ollama)

- **Never assume a GPU model from specs sheets or prior comments** — verify with `rocminfo`
  (reports `Marketing Name` and the `gfxNNNN` string directly) or sysfs
  (`/sys/class/drm/card*/device/{device,mem_info_vram_total}`) before setting
  `rocmOverrideGfx` or sizing models to VRAM. `gammu`'s GPU was misidentified as an RX 7900
  GRE (Navi 31/gfx1100/16GB) for several releases; it's actually an RX 7700 XT (Navi
  32/gfx1101/12GB) — see CHANGELOG for the correction.
- `rocmOverrideGfx` must match the card's real gfx target (`HSA_OVERRIDE_GFX_VERSION`,
  `major.minor.step` — e.g. gfx1101 → `"11.0.1"`), not a copy-pasted value from a tutorial
  for a different card.
- Any NixOS host with an AMD GPU should carry `pkgs.rocmPackages.rocm-smi` for
  monitoring/querying it (see `hosts/nixos/gammu/default.nix`). `pciutils` (`lspci`) ships on
  all NixOS hosts already, via the `stdenv.isLinux` gate in `modules/common/packages.nix`.
- Use `services.ollama.loadModels` to declare models pulled at activation, not a manual
  `ollama pull` — keeps the model set reproducible across rebuilds. Leave `syncModels` at its
  default (`false`) unless you want undeclared models removed on every switch.
- The env var is `environmentVariables.OLLAMA_CONTEXT_LENGTH`, not `environment` and not
  `OLLAMA_NUM_CTX` — see the `26.07.10` CHANGELOG entry for the earlier evaluation-breaking
  mistake. Context length is what agentic tool-call loops need headroom for (system prompt +
  tool schemas alone can run several thousand tokens); size it, and the model, to fit the
  card's VRAM with headroom to spare.
- Both Zed's Agent Panel and Claude Code can drive a local Ollama model as a tool-calling
  agent: Zed requires the model explicitly declared with `supports_tools: true` in
  `~/.config/zed/settings.json` (autodiscovery alone does not enable tool calls); Claude Code
  talks to Ollama directly via its native Anthropic Messages API compatibility
  (`ANTHROPIC_BASE_URL`), no translation proxy needed. See README "Local LLM (Ollama + Open
  WebUI)" and `nixie-homes`' `alberth/gammu.nix`'s `claude-local` fish function.

### Syncthing

- Hosts running `services.syncthing` (gammu, huginn, porkchop) bind the GUI to the IPv4
  wildcard `guiAddress = "0.0.0.0:8384"` (and matching `settings.gui.address`) — **never**
  the IPv6 wildcard `"[::]:8384"`. NixOS's `syncthing-init` service (`merge-syncthing-config`)
  reconciles any declared `services.syncthing.settings` by curling `guiAddress` itself; curl
  can connect to `0.0.0.0` (the Linux kernel routes it over loopback) but cannot connect to a
  literal `::` destination at all, so `[::]` breaks `syncthing-init` with
  `curl: (7) Failed to connect to :: port 8384`. This was hit in production on porkchop (and
  latent on gammu/huginn) — see CHANGELOG. The GUI firewall rule is IPv4-only
  (`ip saddr 10.0.4.0/22 tcp dport 8384 accept`) to match; there is no IPv6 rule for 8384.
- The GUI password is set via the custom `modules/nixos/syncthing-password.nix` service, which
  correctly targets loopback (`http://[::1]:8384`) directly rather than reusing `guiAddress` —
  that pattern is safe regardless of what `guiAddress` is bound to and should be the model for
  any future custom syncthing REST API calls.
- **Changing `guiAddress` on a host with a pre-existing `~/.config/syncthing/config.xml` does
  not take effect on its own.** Once `config.xml` has a persisted `<gui><address>`, it wins over
  the `--gui-address` CLI flag on restart (observed on syncthing v2.0.15) — so
  `nixos-rebuild switch` alone leaves the daemon listening on the *old* address while
  `syncthing-init` tries to reach the *new* one declared in Nix, a chicken-and-egg loop that
  can't self-heal (reaching the API to fix the address requires already being connected to the
  address being changed). Break it once manually via the still-live old address, then bounce
  the service:

  ```bash
  APIKEY=$(xmllint --xpath 'string(configuration/gui/apikey)' ~/.config/syncthing/config.xml)
  curl -sk -H "X-API-Key: $APIKEY" -X PATCH -d '{"address":"<new-guiAddress>"}' http://[::1]:8384/rest/config/gui
  sudo systemctl restart syncthing.service
  sudo systemctl restart syncthing-init.service
  ```

  Hit when migrating gammu/huginn/porkchop from `[::]:8384` to `0.0.0.0:8384`. Not needed on a
  brand-new host with no existing `config.xml`.
- **The GUI/REST API listener can silently die while `syncthing.service` stays `active` and sync
  itself (the `:22000` listener) keeps working** — no crash, no error logged, no unit restart;
  observed on both gammu and huginn after hours of normal uptime, unrelated to any config change.
  Because the unit never fails, `Restart=on-failure` never fires, and there's nothing to gate with
  unit ordering: `syncthing-init.service` and `syncthing-gui-password.nix` already declare correct
  `After=`/`Requires=`/`PartOf=` on `syncthing.service`, but that only proves the unit was active
  when they started, not that its API is still responding *now* — this is what broke both of their
  activation runs (`curl: (7) Failed to connect` / `start operation timed out`) during an otherwise
  unrelated `nixos-rebuild switch`. `modules/nixos/syncthing-healthcheck.nix` (imported on
  gammu/huginn/porkchop) works around it with a 5-minute systemd timer that polls
  `http://[::1]:8384/rest/noauth/health` and force-restarts `syncthing.service` if it doesn't
  respond — a watchdog, not a fix, since the underlying cause of the listener dying is unknown.
  Not applied on darwin (codex/nhcodex): syncthing there runs as a self-supervised Homebrew-cask
  GUI app with no stable launchd job to target a clean restart at (`launchctl list` shows it as an
  ephemeral `application.*`-labeled process, not a fixed `Label`), so an equivalent watchdog would
  mean killing a foreground app rather than restarting a headless daemon — a different risk profile
  that hasn't been justified by an observed failure on darwin.

### KDE Configuration

- nixie has no `plasma-manager` input — KDE settings that need to be declarative (e.g. gammu's
  default terminal) are set via a `home.activation` hook calling `kwriteconfig6`
  (`pkgs.kdePackages.kconfig`), not by having home-manager own the whole config file.
- Files like `kdeglobals` hold many settings Plasma itself writes at runtime (theme, fonts,
  click behavior, etc.) alongside the one or two keys nixie cares about. Managing the file
  wholesale via `xdg.configFile`/`home.file` would symlink it read-only into the Nix store,
  breaking every other System Settings change on next write. `kwriteconfig6 --file <name>
  --group <group> --key <key> <value>` merges a single key in place instead — the same
  mechanism KDE's own System Settings uses under the hood.
- Example: gammu's default terminal is set in `nixie-homes`' `alberth/gammu.nix` via
  `TerminalApplication=ghostty` / `TerminalService=com.mitchellh.ghostty.desktop` in
  `kdeglobals` — this is the only mechanism Dolphin's "Open Terminal Here" (and similar
  actions) respects; there is no MIME-type-based way to set a default terminal.
- If adding much more KDE-specific declarative config becomes common, reconsider adding
  `plasma-manager` as a flake input rather than growing ad-hoc `kwriteconfig6` activation
  scripts — propose that as a structural change first per the project conventions above.

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

**Never add a `Co-Authored-By` trailer** (or any other AI/tool attribution
tag) to a commit without explicitly asking the user first and receiving
permission. This repository is not an advertising space.

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
3. Check `nixie-homes`' `alberth/default.nix` (separate repo) before adding to a host overlay —
   if it applies to all hosts, put it in the shared home config there, not a per-host overlay.
4. Propose structural/architectural changes before implementing — describe the approach and wait
   for confirmation.
