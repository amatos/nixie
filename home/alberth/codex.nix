# Codex-specific home-manager settings for alberth.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Codex-only packages
  home.packages = [
    pkgs.orbstack # Fast, light Docker and Linux VM manager
    pkgs.act # Run GitHub Actions locally
    pkgs.telegram-desktop # Messaging
  ];

  # GPG agent — use pinentry-mac for native macOS Keychain / Touch ID prompts.
  # pinentry-mac is also in homebrew.brews so it's available system-wide;
  # we point gpg-agent at the nixpkgs derivation for a deterministic path.
  services.gpg-agent = {
    enable = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
    '';
  };

  imports = [
    ./ghostty.nix
  ];

  # Ghostty — installed via homebrew cask; enable programs.ghostty so
  # home-manager can manage the config and catppuccin can inject the theme.
  # package = null prevents home-manager from installing the nixpkgs build,
  # which has no aarch64-darwin support.
  # ghostty.nix provides shared settings; command overrides the default shell lookup.
  programs.ghostty = {
    enable = true;
    package = null;
    settings.command = "/etc/profiles/per-user/alberth/bin/fish";
  };

  programs.ssh.settings = {
    "*" = {
      ServerAliveInterval = 120;
      IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      ForwardAgent = true;
    };
    "muninn.home.matos.cc muninn.local muninn" = {
      User = "pi";
    };
  };

  # Syncthing — patch GUI settings in config.xml on each activation.
  # syncthing-app is managed by homebrew; we only touch the settings we care about.
  home.activation.syncthingConfig =
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
  home.activation.prependSSHInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sshConfig="${config.home.homeDirectory}/.ssh/config"
    tmpfile=$(mktemp)
    { printf 'Include 1Password/config\n\n'; cat "$sshConfig"; } > "$tmpfile"
    chmod 600 "$tmpfile"
    mv "$tmpfile" "$sshConfig"
  '';
}
