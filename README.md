# nixie

Combined NixOS and nix-darwin configuration using Determinate Nix, nix-darwin, and home-manager. All configuration is driven by Nix flakes.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for how this repo fits together with
its companion secrets repos (`nix-secrets`, `nix-keytabs-matos-cc`).

[![CI](https://github.com/amatos/nixie/actions/workflows/ci.yml/badge.svg)](https://github.com/amatos/nixie/actions/workflows/ci.yml)

## Hosts

| Hostname | OS | Architecture | Physical / Virtual | Function |
| --- | --- | --- | --- | --- |
| `codex` | nix-darwin | aarch64-darwin | Physical | MacBook Pro, main desktop |
| `nhcodex` | nix-darwin | aarch64-darwin | Physical (same as `codex`) | Test bed for home-manager changes, no `nix-home-alberth` |
| `darwintron` | nix-darwin | aarch64-darwin | Virtual | CI build target |
| `gammu` | NixOS | x86_64-linux | Physical | Video games, LLMs, and other tasks best suited for a Linux host |
| `porkchop` | NixOS | x86_64-linux | Physical | SMTP smart relay, ldap server, Kerberos KDC |
| `huginn` | NixOS | x86_64-linux | Physical | misc |
| `muninn` | NixOS | x86_64-linux | Physical | misc |
| `ephemeraltron` | NixOS | x86_64-linux | Virtual | CI build target |
| `minixie` | NixOS | x86_64-linux | N/A | generic nixos-anywhere bootstrap target, not a real host |

Hosts whose names end in `tron` are virtual machines.

## Repository layout

Not exhaustive — see `modules/` for the complete module set:

```text
flake.nix                        # inputs, sharedSpecialArgs, host wiring
users.nix                        # single source of truth for users (primaryUser, email, GPG key)

hosts/
  darwin/
    common-darwin.nix            # shared darwin config (nix-daemon, Touch ID, mkalias)
    codex/default.nix            # codex-specific: homebrew, certbot, dockutil
    nhcodex/default.nix          # test bed, no nix-home-alberth; hostName still "codex"
    darwintron/default.nix       # darwintron-specific: hostname only
  nixos/
    common-nixos.nix             # shared NixOS config (bootloader, locale, certbot, stateVersion)
    gammu/default.nix            # docker/containerd, syncthing, certbot, Steam gaming,
                                  # Ollama/Open WebUI
    minixie/default.nix          # generic nixos-anywhere bootstrap target (no sharedSpecialArgs)

modules/
  common/                        # cross-platform modules (NixOS + darwin)
    packages.nix                 # shared system packages, allowUnfree, environment.shells
    development-packages.nix     # dev-tool packages, wired only to gammu and codex
    secrets.nix                  # ragenix identity paths
    age-host-key.nix             # generates /etc/age/host-key on first activation
    github-secrets.nix           # deploys GitHub SSH keys via ragenix
    certbot-secrets.nix          # deploys LuaDNS credentials via ragenix
    tailscale-secrets.nix        # deploys Tailscale auth key via ragenix (NixOS only)
  nixos/
    users.nix                    # NixOS user declarations
    home-manager.nix             # shared NixOS home-manager block
    certbot.nix                  # systemd timer, weekly + 1h random delay
    ghostty.nix                  # conditional on display server presence
    github-secrets-tmpfiles.nix  # pre-creates ~/.ssh via systemd-tmpfiles (NixOS-only)
  darwin/
    users.nix                    # darwin user declarations (strips NixOS-only fields)
    home-manager.nix             # base home-manager block sourced from nix-home-alberth;
                                  # not part of common-darwin.nix, so hosts can opt out
    certbot.nix                  # launchd daemon, Sunday 03:00
```

Home-manager configuration lives in the separate
[nix-home-alberth](https://github.com/amatos/nix-home-alberth) repo (input `nix-home-alberth`), imported
via `nix-home-alberth.homeModules.<name>` — see that repo's own `README.md`/`CLAUDE.md`.

## Development shell

A devShell is provided for working on the configuration itself:

```bash
# Enter the dev shell (automatically via direnv, or manually)
nix develop

# Or, if direnv is installed and .envrc is allowed:
cd nixie   # shell loads automatically
```

The devShell provides: `nil` (Nix LSP), `nixfmt`, `ragenix`, `nixos-anywhere`, `nix-tree`, `nvd`,
`statix`.

To activate direnv:

```bash
direnv allow
```

## Switching / rebuilding

```bash
# macOS
darwin-rebuild switch --flake .#<hostname>

# NixOS
nixos-rebuild switch --flake .#<hostname>
```

## Provisioning new hosts

nixie has two ways to get a fresh machine running, depending on what you're starting from:

| Path | Starting point | How |
| --- | --- | --- |
| `template-nixos` | Console access, booted into a NixOS installer | Copy `hosts/nixos/template-nixos`, add to `flake.nix`, install manually |
| `minixie` | SSH-only, no console (VPS/cloud host, or a booted installer) | `nixos-anywhere --flake .#minixie root@<ip>` — disko + identity-less install |

`minixie` is intentionally disconnected from `nix-secrets`/`nix-keytabs-matos-cc` and
`sharedSpecialArgs` — it exists only to get a box from "freshly booted/rescued" to
"reachable over SSH with disks partitioned". Once it's up, replace
`hosts/nixos/minixie` with a real host directory (following the `template-nixos`
pattern) rather than extending the minixie config in place.

```bash
nixos-anywhere --flake .#minixie root@<target-ip>

# Or via nix run if nixos-anywhere isn't installed locally:
nix run github:nix-community/nixos-anywhere -- --flake .#minixie root@<target-ip>

# With nixos-facter hardware detection:
nixos-anywhere --flake .#minixie \
  --generate-hardware-config nixos-facter hosts/nixos/minixie/facter.json \
  root@<target-ip>
```

Before deploying, replace the placeholder SSH key in `hosts/nixos/minixie/default.nix` under
`users.users.root.openssh.authorizedKeys.keys` with your own.

## Secrets (ragenix + YubiKey)

Secrets are encrypted with [ragenix](https://github.com/yaxitech/ragenix) using an age identity backed
by a YubiKey via `age-plugin-yubikey`. Encrypted `.age` files live in the
[nix-secrets](https://github.com/amatos/nix-secrets) repository, pulled in as a non-flake flake input
(`flake = false`).

### Prerequisites

- YubiKey plugged in
- `age-plugin-yubikey` available (`nix shell nixpkgs#age-plugin-yubikey`)

### Generating a new secret

1. **Add the secret's entry to `nix-secrets`'s own `secrets.nix`** (a separate repo, not a
   subdirectory of this one — see [nix-secrets](https://github.com/amatos/nix-secrets)), listing
   the recipients that should be able to decrypt it:

   ```nix
   "my-new-secret.age".publicKeys = allKeys;
   ```

2. **Encrypt the secret** using ragenix, from inside the `nix-secrets` checkout:

   ```bash
   cd /path/to/nix-secrets
   ragenix -e my-new-secret.age
   ```

3. **Commit the `.age` file** to the appropriate repository.

4. **Declare the secret on the hosts** that need it:

   ```nix
   age.secrets.my-new-secret = {
     file  = "${nix-secrets}/my-new-secret.age";
     path  = "/path/on/host/my-new-secret";
     owner = "alberth";
     mode  = "0600";
   };
   ```

5. **Rebuild the host.**

### Adding a new host

Each host auto-generates its own age key at `/etc/age/host-key` on first activation.

1. Deploy with the YubiKey plugged in — the activation script prints the new host's public key:

   ```text
   Host age public key (add this to nix-secrets/secrets.nix and rekey):
   age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

2. Add that key to `nix-secrets/secrets.nix` as a new recipient.

3. Rekey all secrets:

   ```bash
   nix run github:yaxitech/ragenix -- --rekey
   ```

4. Commit, push, and redeploy. All subsequent boots are fully automatic.

### Re-keying secrets

```bash
nix run github:yaxitech/ragenix -- --rekey
```

## Tailscale

Tailscale is enabled on all hosts. NixOS hosts authenticate automatically at activation using the
auth key decrypted from `nix-secrets/tailscale-authkey.age`. Darwin hosts do not support
`authKeyFile` via nix-darwin and must be authenticated once manually after the first deploy:

```bash
sudo tailscale up --authkey <key>
```

The auth key is stored in 1Password and in `nix-secrets`. Use a **reusable, non-ephemeral** key so
nodes persist across reboots and re-deploys.

## Certbot (LuaDNS DNS-01)

Certificates renew automatically — weekly via a systemd timer (NixOS, with 1h
randomized delay) or launchd job (darwin, Sunday 03:00). Both use `--keep-until-expiring`.

The LuaDNS API credentials are decrypted from `nix-secrets/luadns.ini.age` at boot and placed at
`/run/agenix/luadns-ini`.

### Configuring domains

```nix
nixie.certbot = {
  enable = true;
  domains = [
    [ "example.com" "www.example.com" ] # one cert, two SANs — the common case
  ];
  # domains = [ "example.com" ];        # single-domain shorthand: one cert, no SANs
};
```

### Manual renewal

```bash
# NixOS
sudo systemctl start certbot.service

# macOS
sudo launchctl start org.nixie.certbot
```

### Certificate location

`/etc/letsencrypt/live/<domain>/` on all hosts.

## Gaming (Steam)

Currently configured on `gammu` only (AMD GPU) — declared inline in its `default.nix`, not
a shared module:

```nix
hardware.graphics = {
  enable = true;
  enable32Bit = true; # required or Steam fails to start
};

programs.steam = {
  enable = true;
  remotePlay.openFirewall = true;
  dedicatedServer.openFirewall = true;
  extraCompatPackages = with pkgs; [ proton-ge-bin ];
  gamescopeSession.enable = true;
};

programs.gamemode.enable = true;
programs.gamescope = {
  enable = true;
  capSysNice = true;
};
```

`gammu` also runs GNOME, but `services.displayManager.gdm.enable = false` — there is no
display manager, so the host boots to a text console (`multi-user.target`) instead of a graphical
login screen. For desktop access, connect via xrdp (see Remote Desktop below). To start a local
GNOME X11 session from the physical console, log in on the tty and run:

```console
startx $(which gnome-session)
```

The gamescope Big Picture session (`programs.steam.gamescopeSession` above) is accessible
independently of the desktop environment — see the headless Steam unit below.

For SSH-only access with nothing plugged in, there's a headless (no display, physical or
virtual) gamescope + Steam Big Picture session at 4K (3840x2160) for Steam Remote Play, managed
as a home-manager user unit — `systemd.user.services.steam` (`nix-home-alberth`'s `alberth/gammu.nix`):

```console
systemctl --user start   steam   # launch the headless session
systemctl --user stop    steam   # stop gamescope, Steam, and any running game
systemctl --user restart steam
journalctl --user -u steam -f    # follow its logs
```

`gamescope` is the unit's `ExecStart` directly (`Type = "exec"`), not a detaching wrapper script,
so systemd tracks its real PID — `start`/`stop`/`restart` actually control the session, and
`stop` tears down Steam and any running game underneath it too via systemd's default `KillMode`
(`control-group`), no manual `pkill` needed.

The unit also runs automatically on boot: it runs inside alberth's own `systemd --user`
session — not a NixOS `systemd.services` unit with `User=` — so it has the real
`XDG_RUNTIME_DIR`/D-Bus session Steam's `-pipewire-dmabuf` flag needs. That user session is
started at boot (not just on interactive login) via `users.users.alberth.linger = true` in
`hosts/nixos/gammu/default.nix`.

## Remote Desktop (xrdp)

`gammu` runs `services.xrdp` for full desktop access from codex, separate from the Steam
streaming setup above:

```nix
services.xserver.enable = true; # required: xrdp's session is X11, not Wayland

services.xrdp = {
  enable = true;
  defaultWindowManager =
    "${pkgs.dbus}/bin/dbus-run-session ${pkgs.gnome-session}/bin/gnome-session";
  openFirewall = true;
};
```

This spins up its own X11 GNOME session per RDP connection, independent of any local session
on the physical console — connecting over RDP doesn't disturb whatever's running there (or vice
versa). The `dbus-run-session` wrapper is required because xrdp doesn't start a D-Bus session
bus itself, and GNOME's components need one to come up. Connect from codex with any RDP client
(e.g. Microsoft Remote Desktop, FreeRDP) to `gammu.ts.matos.cc:3389`.

## Local LLM (Ollama + Open WebUI)

`gammu` runs local LLM inference on its AMD GPU — a Radeon RX 7700 XT (Navi 32, `gfx1101`,
12GB VRAM; confirmed via `rocminfo` and sysfs after an earlier, incorrect "RX 7900 GRE"
assumption — see CHANGELOG):

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-rocm;
  rocmOverrideGfx = "11.0.1"; # reports gfx1101 to ROCm
  host = "0.0.0.0";
  port = 11434;
  loadModels = [ "qwen2.5-coder:14b" ]; # ~9GB Q4_K_M, fits the 12GB card with headroom
  environmentVariables.OLLAMA_CONTEXT_LENGTH = "32768";
};

services.open-webui = {
  enable = true;
  host = "0.0.0.0";
  port = 8080;
  environment.OLLAMA_BASE_URL = "http://127.0.0.1:11434";
};
```

Both are reachable from the LAN (`10.0.4.0/22`) and over Tailscale
(`trustedInterfaces = ["tailscale0"]`); see `hosts/nixos/gammu/default.nix` for the exact
firewall rules. `rocm-smi` (`pkgs.rocmPackages.rocm-smi`) is installed on `gammu` for
monitoring the GPU; `lspci` (`pciutils`) is available on all NixOS hosts.

`qwen2.5-coder:14b` was chosen for reliable tool-calling support (needed for agentic coding
workflows) at a size that fits `gammu`'s 12GB of VRAM with headroom left for context.

### Zed Agent Panel

Zed does not auto-enable tool calling for Ollama models — declare the model explicitly in
`~/.config/zed/settings.json`:

```json
{
  "language_models": {
    "ollama": {
      "api_url": "http://localhost:11434",
      "available_models": [
        {
          "name": "qwen2.5-coder:14b",
          "display_name": "Qwen 2.5 Coder 14B",
          "max_tokens": 32768,
          "supports_tools": true
        }
      ]
    }
  }
}
```

### Claude Code

Ollama exposes an Anthropic Messages-API-compatible endpoint natively, so Claude Code can
talk to it directly — no translation proxy needed. On `gammu`, run `claude-local` (a fish
function defined in `nix-home-alberth`'s `alberth/gammu.nix`) instead of plain `claude` to point
Claude Code at the local model:

```fish
claude-local  # sets ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN / ANTHROPIC_MODEL, then runs claude
```

`claude-local` only exists on `gammu`. On `codex`, plain `claude` (installed via Homebrew)
talks to Anthropic's cloud API as usual.
