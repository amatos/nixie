# Codex-specific home-manager settings for alberth.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ==========================================================================
  # macOS Application Management (copyApps for TCC stability)
  # ==========================================================================
  # Use copyApps instead of linkApps to create REAL copies of apps at stable
  # paths in ~/Applications/Home Manager Apps/. This allows macOS TCC
  # (Transparency, Consent, Control) permissions to persist across rebuilds.
  #
  # With linkApps (default), apps symlink to /nix/store paths which change on
  # every rebuild, invalidating TCC permissions (camera, mic, screen recording).
  #
  # Trade-off: Uses more disk space (~100MB per app) but TCC permissions persist.
  #
  # See: https://github.com/nix-community/home-manager/issues/8336
  targets.darwin = {
    copyApps.enable = true;
    linkApps.enable = false;
  };

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;

  imports = [
    ./darwin
  ];

  # darwin/default.nix provides: GPG agent (pinentry-mac), Ghostty (enable,
  # package = null, command = fish). Only add settings that differ on codex.

  programs = {
    qmd.enable = true;
    ssh.settings = {
      "*" = {
        ServerAliveInterval = 120;
        IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
        ForwardAgent = true;
      };
      "muninn.home.matos.cc muninn.local muninn" = {
        User = "pi";
      };
    };
  };

  home = {
    # ========================================================================
    # TCC-Sensitive GUI Applications (using copyApps for stable paths)
    # ========================================================================
    # These apps need macOS TCC (Transparency Consent Control) permissions
    # for camera, microphone, screen recording, etc.
    #
    # With targets.darwin.copyApps enabled (see above), apps in home.packages
    # are COPIED to ~/Applications/Home Manager Apps/ with STABLE paths that
    # persist TCC permissions across darwin-rebuild.
    #
    # This is better than mac-app-util trampolines because:
    # - Binary paths are stable (not /nix/store which changes on rebuild)
    # - TCC permissions granted to the app persist
    # - No wrapper scripts - actual app copies
    #
    # Trade-off: Uses more disk space (~100MB per app) but TCC works correctly.
    #
    # NOTE: OrbStack itself is installed via the Homebrew cask in
    # hosts/darwin/codex/default.nix, which also creates the ContainerData
    # APFS volume mounted below. This file only manages OrbStack's data
    # location and Docker daemon settings.
    #
    # Codex-only packages
    # NOTE: iosevka and ioskeley-mono are intentionally omitted here — iosevka
    # fails to build on aarch64-darwin due to a known upstream bug:
    # https://github.com/NixOS/nixpkgs/issues/532294. They're installed via
    # Homebrew instead (hosts/darwin/codex/homebrew.nix: font-iosevka,
    # font-iosevka-nerd-font, font-ioskeley-mono). gammu (x86_64-linux) is
    # unaffected and uses pkgs.iosevka/pkgs.ioskeley-mono directly.
    packages = with pkgs; [
      act # Run GitHub Actions locally
      telegram-desktop # Messaging
    ];

    activation = {
      # Syncthing — patch GUI settings in config.xml on each activation.
      # syncthing-app is managed by homebrew; we only touch the settings we care about.
      syncthingConfig =
        let
          script = pkgs.writeText "syncthing-patch.py" ''
            import sys, xml.etree.ElementTree as ET
            path = sys.argv[1]
            tree = ET.parse(path)
            root = tree.getroot()
            gui = root.find('gui')
            if gui is not None:
                gui.set('tls', 'true')
                addr = gui.find('address')
                if addr is not None:
                    addr.text = '[::]:8384'
            tree.write(path, encoding='unicode', xml_declaration=True)
          '';
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          config_xml="${config.home.homeDirectory}/Library/Application Support/Syncthing/config.xml"
          if [ -f "$config_xml" ]; then
            ${pkgs.python3}/bin/python3 ${script} "$config_xml"
          fi
        '';

      # Prepend `Include 1Password/config` to the top of ~/.ssh/config after
      # home-manager writes it. extraConfig appends to the end, so we use an
      # activation script instead to ensure SSH processes the include first.
      prependSSHInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        sshConfig="${config.home.homeDirectory}/.ssh/config"
        tmpfile=$(mktemp)
        { printf 'Include 1Password/config\n\n'; cat "$sshConfig"; } > "$tmpfile"
        chmod 600 "$tmpfile"
        mv "$tmpfile" "$sshConfig"
      '';
    };

    file = {
      # OrbStack data on dedicated APFS volume
      # Symlinks entire Group Container so ALL OrbStack data lives on volume
      # Volume created by system.activationScripts.containerDataVolume in
      # hosts/darwin/codex/default.nix
      # Contains: Docker images, containers, volumes, Linux VMs, logs
      # MIGRATION: Stop OrbStack and move existing data before enabling
      # NOTE: `ln` reports a permission error when OrbStack is running because the
      # Group Container directory is locked. This is expected — the symlink persists
      # correctly and does not need to be recreated on every rebuild.
      "Library/Group Containers/HUAQ24HBR6.dev.orbstack".source =
        config.lib.file.mkOutOfStoreSymlink "/Volumes/ContainerData";

      # Docker daemon configuration for OrbStack
      # Log rotation + build cache GC to prevent unbounded disk growth
      # force = true: OrbStack pre-creates this file; home-manager must overwrite it
      ".orbstack/config/docker.json" = {
        force = true;
        text = builtins.toJSON (
          let
            logMaxFileSize = "25m";
            logMaxFiles = "25";
            keepDuration = "2160h"; # 90 days
            defaultKeepStorage = "10GB";
            sourceLocalMaxUsedSpace = "10GB";
            generalMaxUsedSpace = "20GB";
          in
          {
            log-driver = "json-file";
            log-opts = {
              max-size = logMaxFileSize;
              max-file = logMaxFiles;
            };
            builder.gc = {
              enabled = true;
              inherit defaultKeepStorage;
              policy = [
                {
                  inherit keepDuration;
                  filter = [ "type==source.local" ];
                  maxUsedSpace = sourceLocalMaxUsedSpace;
                }
                {
                  inherit keepDuration;
                  maxUsedSpace = generalMaxUsedSpace;
                }
              ];
            };
          }
        );
      };
    };
    # ========================================================================
    # Environment variables for external data locations
    # ========================================================================
    sessionVariables = {
      # Container data on dedicated volume
      # NOTE: This volume is separate from Ollama
      CONTAINER_DATA = "/Volumes/ContainerData";
    };
  };
}
