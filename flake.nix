{
  description = "nixie — combined NixOS and nix-darwin configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0"; # Stable Nixpkgs (use 0.1 for unstable)

    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0"; # Stable nix-darwin (use 0.1 for unstable)
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3"; # Determinate 3.*
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05"; # pin to same release as nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-secrets = {
      url = "github:amatos/nix-secrets";
      flake = false; # plain git repo, not a flake
    };

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-bat = {
      url = "github:catppuccin/bat";
      flake = false;
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    zapp = {
      url = "github:amatos/zapp/add-aarch64-darwin-support-for-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      determinate,
      home-manager,
      ragenix,
      nix-secrets,
      nvf,
      catppuccin-bat,
      catppuccin,
      nix-homebrew,
      zapp,
      pre-commit-hooks,
      ...
    }:
    let
      # Helper to build a lib from nixpkgs for a given system
      lib = nixpkgs.lib;

      # Supported systems
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      # Shared specialArgs passed to every host configuration
      sharedSpecialArgs = {
        inherit
          self
          nix-secrets
          nvf
          catppuccin-bat
          catppuccin
          ;
      };

      # Pre-commit hooks — shared between checks output and devShell shellHook.
      # Running `nix develop` installs the hooks into .git/hooks automatically.
      preCommitCheck = forAllSystems (
        system:
        pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixfmt = {
              enable = true;
              package = nixpkgs.legacyPackages.${system}.nixfmt;
            };
          };
        }
      );
    in
    {
      # nix-darwin configurations (macOS)
      # Usage: nix run nix-darwin -- switch --flake .#<hostname>
      darwinConfigurations = {
        codex = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            ragenix.nixosModules.default
            nix-homebrew.darwinModules.nix-homebrew
            zapp.darwinModules.default
            ./hosts/darwin/codex
          ];
        };

        darwintron = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            ragenix.nixosModules.default
            zapp.darwinModules.default
            ./hosts/darwin/darwintron
          ];
        };
      };

      # NixOS configurations (Linux)
      # Usage: nixos-rebuild switch --flake .#<hostname>
      nixosConfigurations = {
        nixostron = lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            zapp.nixosModules.default
            ./hosts/nixos/nixostron
          ];
        };

        gammu = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            zapp.nixosModules.default
            ./hosts/nixos/gammu
          ];
        };
      };

      # Standalone home-manager configurations
      # Usage: home-manager switch --flake .#<username>@<hostname>
      homeConfigurations = {
        # example = home-manager.lib.homeManagerConfiguration {
        #   pkgs = nixpkgs.legacyPackages."aarch64-darwin";
        #   extraSpecialArgs = { inherit self; };
        #   modules = [
        #     ./home/<username>
        #   ];
        # };
      };

      # Canonical formatter — enables `nix fmt` and `nix run .#formatter -- --check`
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Expose pre-commit check so `nix flake check` verifies formatting too
      checks = forAllSystems (system: {
        pre-commit = preCommitCheck.${system};
      });

      # Dev shells and packages (optional)
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "nixie";
            packages = with pkgs; [
              nil # Nix LSP
              nixfmt # canonical Nix formatter
              ragenix.packages.${system}.default # rekey secrets, add recipients
              nix-tree # visualize derivation dependency graph
              nvd # diff two NixOS/darwin closures before switching
            ];
            # Installs git hooks into .git/hooks when entering the devShell
            inherit (preCommitCheck.${system}) shellHook;
          };
        }
      );
    };
}
