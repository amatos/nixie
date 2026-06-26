# Shared configuration for all nix-darwin hosts.
# Each host imports this file and adds its hostname, host-specific overlay
# (home/alberth/<host>.nix), and any host-only services on top.
{
  config,
  pkgs,
  lib,
  nvf,
  catppuccin,
  catppuccin-bat,
  ...
}:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  imports = [
    ../../modules/darwin/users.nix
    ../../modules/darwin/sudo.nix
    ../../modules/common/packages.nix
    ../../modules/common/age-host-key.nix
    ../../modules/common/secrets.nix
    ../../modules/common/github-secrets.nix
  ];

  # Primary user — required by options that run under the user context (e.g. homebrew)
  system.primaryUser = primaryUser;

  # Allow Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Fish — enable system-wide so it appears in /etc/shells and can be set as login shell
  programs.fish.enable = true;
  users.users.${primaryUser}.shell = pkgs.fish;

  # Zapp — CLI tool for flashing ZSA keyboards
  programs.zapp.enable = true;

  services.tailscale.enable = true;

  # SSH daemon — password auth disabled; key-only access
  # macOS manages its own firewall separately; no networking.firewall equivalent in nix-darwin
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      PermitRootLogin no
    '';
  };

  # Install Nix-managed apps as macOS aliases in /Applications/Nix Apps/.
  # Native aliases are indexed by Spotlight and Launchpad unlike Unix symlinks.
  system.activationScripts.applications.text =
    let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = [ "/Applications" ];
      };
    in
    lib.mkForce ''
      echo "setting up /Applications/Nix Apps..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l | while read -r app; do
        src=$(readlink "$app")
        name=$(basename "$app")
        echo "  aliasing $name" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$name"
      done
    '';

  # home-manager — base config shared by all darwin hosts.
  # Each host merges in its own overlay via:
  #   home-manager.users.${primaryUser} = { imports = [ ./home/alberth/<host>.nix ]; };
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = "${pkgs.trash-cli}/bin/trash";
    sharedModules = [
      nvf.homeManagerModules.default
      catppuccin.homeModules.catppuccin
    ];
    extraSpecialArgs = { inherit catppuccin-bat; };
    users.${primaryUser} = {
      imports = [
        ../../home/alberth
        ../../home/alberth/nvf.nix
      ];
    };
  };

  # Set when the host was first provisioned — do not change after initial deploy.
  system.stateVersion = 5;
}
