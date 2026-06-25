# Homebrew Casks with Nixpkgs Equivalents

Casks that have a corresponding package in nixpkgs. Candidates for migration to
`home.packages` or `environment.systemPackages` once the darwin breakage or
platform limitation is resolved.

> **Note on darwin availability:** some packages (e.g. `steam`) are in nixpkgs
> but only build/run on Linux. These are flagged below.

---

## Development Tools

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `visual-studio-code` | `pkgs.vscode` | Unfree |
| `zed` | `pkgs.zed-editor` | Keeping as cask — [#59250](https://github.com/zed-industries/zed/issues/59250) |
| `jetbrains-toolbox` | `pkgs.jetbrains-toolbox` | |
| `ghostty` | `pkgs.ghostty` | Keeping as cask for the native macOS `.app` bundle |
| `obs` | `pkgs.obs-studio` | |
| `texstudio` | `pkgs.texstudio` | |
| `mactex` | `pkgs.texlive.combined.scheme-full` | Different structure; nixpkgs ships upstream TeX Live, not the macOS-specific wrapper |
| `inkscape` | `pkgs.inkscape` | |

## Communication Tools

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `discord` | `pkgs.discord` | Unfree |
| `slack` | `pkgs.slack` | Unfree |
| `telegram` | `pkgs.telegram-desktop` | |
| `zoom` | `pkgs.zoom-us` | Unfree |

## Utility Tools

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `syncthing-app` | `pkgs.syncthing` | Nixpkgs ships the daemon; the macOS GUI wrapper (`syncthing-macos`) is not packaged — use `services.syncthing` on NixOS |

## Entertainment Tools

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `vlc` | `pkgs.vlc` | |
| `spotify` | `pkgs.spotify` | Unfree |
| `steam` | `pkgs.steam` | Linux only in nixpkgs; darwin is not supported |

## Productivity Tools

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `obsidian` | `pkgs.obsidian` | Unfree |

## Security

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `tailscale-app` | `pkgs.tailscale` | Nixpkgs ships the CLI/daemon; the macOS menubar app is not the same binary — on NixOS use `services.tailscale` |

## Browsers

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `google-chrome` | `pkgs.google-chrome` | Unfree; Linux only — darwin not supported in nixpkgs |

## Fonts

Nerd Fonts in nixpkgs are available as a package set: `pkgs.nerd-fonts.<name>`.

| Homebrew cask | Nix attribute | Notes |
|---|---|---|
| `font-anonymous-pro` | `pkgs.anonymousPro` | |
| `font-dejavu-sans-mono-nerd-font` | `pkgs.nerd-fonts.dejavu-sans-mono` | |
| `font-inconsolata` | `pkgs.inconsolata` | |
| `font-inconsolata-go-nerd-font` | `pkgs.nerd-fonts.inconsolata-go` | |
| `font-iosevka` | `pkgs.iosevka` | |
| `font-jetbrains-mono` | `pkgs.jetbrains-mono` | |
| `font-jetbrains-mono-nerd-font` | `pkgs.nerd-fonts.jetbrains-mono` | |
| `font-liberation` | `pkgs.liberation_ttf` | |

---

## Not in nixpkgs (macOS-only or proprietary without a package)

For reference — these have no nixpkgs equivalent and must stay as casks.

`claude`, `tower`, `kaleidoscope`, `lm-studio`, `hex-fiend`, `orbstack`,
`plistedit-pro`, `vmlx`, `airfoil`, `arq`, `audio-hijack`,
`automounterhelper`, `betterdiscord-installer`, `betterdisplay`,
`bettermouse`, `bettertouchtool`, `cleanshot`, `coherence-x`, `crossover`,
`elgato-capture-device-utility`, `elgato-stream-deck`, `elgato-studio`,
`elgato-wave-link`, `farrago`, `fission`, `focusrite-control-2`, `hazel`,
`keyboard-maestro`, `latest`, `lingon-x`, `loopback`, `obs` (macOS app),
`piezo`, `raycast`, `setapp`, `skim`, `soundsource`, `superwhisper`,
`textsniper`, `winbox`, `iina`, `pixelsnap`, `powerphotos`,
`gpg-suite@nightly`, `little-snitch`, `spamsieve`, `helium-browser`,
`font-sf-mono-nerd-font-ligaturized`, `font-tengwar-telcontar`,
`font-zed-mono`, `font-zed-mono-nerd-font`, `font-zed-sans`
