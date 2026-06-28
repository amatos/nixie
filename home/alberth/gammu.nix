# Gammu-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  # Gammu-only packages
  home.packages = [
    pkgs.act # Run GitHub Actions locally
    pkgs.nerdctl # Docker-compatible CLI for containerd
  ];

  # nerdctl — point at the system containerd socket; use systemd cgroup driver
  xdg.configFile."nerdctl/nerdctl.toml".text = ''
    address        = "unix:///run/containerd/containerd.sock"
    namespace      = "default"
    cgroup_manager = "systemd"
  '';
}
