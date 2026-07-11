# Centralized user definitions.
# Each entry is passed to users.users.<name> on every host.
# Add or remove users here; hosts import this via the shared module.
{
  # The primary interactive user — referenced by modules that need a username.
  primaryUser = "alberth";

  # Local admin account — NixOS hosts only; used for initial setup and emergency access.
  nixos = {
    isNormalUser = true;
    description = "NixOS Admin";
    extraGroups = [ "wheel" ];
  };

  alberth = {
    isNormalUser = true;
    description = "Alberth Matos";
    extraGroups = [ "wheel" ]; # wheel grants sudo
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDhrDAbSH8T5NcQhkXJ57O0wRUoCugudzE67R1Ulop+EmaXyXeLDBkLEqU47MZj7IZN/IJrwH9IPmjwBgfiZeSHtOkbEacnjV+0m8GUH7tsxwtu2k7IzQvdNgyvilHDzRlv7N52DMINCfdeUGGSsyGpmg4B2LSjww7sbXelWX7PcIH4OZTF0UJV9MF2mHieDxo6vChtz69Ud0B8Pw/H80kAKOew6Diyp3gQwKdwBJIvife2ISzJB3OWC0p8cqLedbZBK8v5/CC3jICbI4jgozaV+c0Q801elc13vaMRa51l6xaAMAjl/Kbk766hODdNf5gTn/ZCmMeDi9sWi9x17Ybmv4ucaNAV3BuKZkA1LDk1bQ1MIfvcy2hoPIlPIDlaShQSjFlv/2X0iDO3EhOBOLdSxUeQJEFLbvTKmdpV/E0IFV14XtUufMM5txOJr/fhWyiEBKJwKC7KBAZzRouH0FZZh7sYRfviZBtxdGj6Pv8WuOixcd+Vn15GDKYC2dtCAnM= alberth@codex"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAif6Mv0L/8n9hrhwM9KJdU4zzWmAcUz/Y/NgfRwOFOZDBl+YJjRcg8BH71PP8D559HSq73x259+Txps66bli5M="
    ];
    email = "alberth@matos.cc";
  };
}
