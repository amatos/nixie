# nixie

Combined NixOS and nix-darwin configuration using Determinate Nix, nix-darwin, and home-manager. All configuration is driven by Nix flakes.

## Hosts

| Hostname | OS | Architecture | Physical / Virtual | Function |
| --- | --- | --- | --- | --- |
| `codex` | nix-darwin | aarch64-darwin | Physical | MacBook Pro, main desktop |
| `darwintron` | nix-darwin | aarch64-darwin | Virtual | Development & Testing VM |
| `nixostron` | NixOS | aarch64-linux | Virtual | Development & Testing VM |
| `gammu` | NixOS | x86_64-linux | Physical | Video games, LLMs, and other tasks best suited for a Linux host |
| `porkchop` | NixOS | x86_64-linux | Physical | SMTP smart relay, ldap server, Kerberos KDC |
| `huginn` | NixOS | x86_64-linux | Physical | misc |

Hosts whose names end in `tron` are virtual machines.

## Repository layout

```text
flake.nix                        # inputs, sharedSpecialArgs, host wiring
users.nix                        # single source of truth for users (primaryUser, email, GPG key)
secrets/
  secrets.nix                    # ragenix recipient definitions

hosts/
  darwin/
    common-darwin.nix            # shared darwin config (nix-daemon, Touch ID, mkalias, home-manager base)
    codex/default.nix            # codex-specific: homebrew, certbot, dockutil
    darwintron/default.nix       # darwintron-specific: hostname only
  nixos/
    common-nixos.nix             # shared NixOS config (bootloader, locale, certbot, stateVersion)
    nixostron/default.nix        # hostname only
    gammu/default.nix            # docker/containerd, syncthing, certbot, Steam gaming

modules/
  common/                        # cross-platform modules (NixOS + darwin)
    packages.nix                 # shared system packages + nixpkgs.config.allowUnfree
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

## Development shell

A devShell is provided for working on the configuration itself:

```bash
# Enter the dev shell (automatically via direnv, or manually)
nix develop

# Or, if direnv is installed and .envrc is allowed:
cd nixie   # shell loads automatically
```

The devShell provides: `nil` (Nix LSP), `nixfmt-rfc-style`, `ragenix`, `nix-tree`, `nvd`.

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

## Secrets (ragenix + YubiKey)

Secrets are encrypted with [ragenix](https://github.com/yaxitech/ragenix) using an age identity backed
by a YubiKey via `age-plugin-yubikey`. Encrypted `.age` files live in the
[nix-secrets](https://github.com/amatos/nix-secrets) repository, pulled in as a non-flake flake input
(`flake = false`).

### Prerequisites

- YubiKey plugged in
- `age-plugin-yubikey` available (`nix shell nixpkgs#age-plugin-yubikey`)

### Generating a new secret

1. **Add the secret's entry to `secrets/secrets.nix`**, listing the recipients that should be able to decrypt it:

   ```nix
   "my-new-secret.age".publicKeys = allKeys;
   ```

2. **Encrypt the secret** using ragenix:

   ```bash
   nix run github:yaxitech/ragenix -- -e secrets/my-new-secret.age
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

Certificates renew automatically — weekly via a systemd timer (NixOS, with 1h randomized delay) or launchd job (darwin, Sunday 03:00). Both use `--keep-until-expiring`.

The LuaDNS API credentials are decrypted from `nix-secrets/luadns.ini.age` at boot and placed at
`/run/agenix/luadns-ini`.

### Configuring domains

```nix
nixie.certbot = {
  enable  = true;
  domains = [ "example.com" "*.example.com" ];
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

Note: `gammu` has no display manager configured, so the gamescope session isn't reachable from
a login screen — launch it manually from a TTY with `gamescope -- steam -gamepadui`.
