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
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # ── Nix formatting ──────────────────────────────────────────────
            nixfmt = {
              enable = true;
              package = pkgs.nixfmt;
            };

            # ── Standard file hygiene ───────────────────────────────────────
            # Hooks from pre-commit/pre-commit-hooks (check-yaml, end-of-file-fixer,
            # trailing-whitespace, check-merge-conflict, check-added-large-files,
            # check-case-conflict, mixed-line-ending) all require a Python backing
            # package that is absent in nixpkgs 26.05 with this version of
            # pre-commit-hooks.nix; they are omitted until a fix is found.

            # ── Markdown linting (config: .markdownlint-cli2.yaml) ──────────
            # pass_filenames = false + always_run = true: lints ALL .md files
            # in the repo on every commit, not just staged ones.  markdownlint-cli2
            # handles the **/*.md glob natively (no shell expansion needed).
            markdownlint-cli2 = {
              enable = true;
              name = "markdownlint-cli2";
              entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2 **/*.md";
              language = "system";
              pass_filenames = false;
              always_run = true;
            };

            # ── Markdown link checking ───────────────────────────────────────
            # Disabled: the Nix build sandbox has no network access, so every
            # external URL returns Status: 0 (connection refused) and the hook
            # always fails in `nix flake check` / CI.  Run manually with:
            #   markdown-link-check --config .markdown-link-check.json <file>
            markdown-link-check = {
              enable = false;
              name = "markdown-link-check";
              entry = "${pkgs.markdown-link-check}/bin/markdown-link-check --config .markdown-link-check.json";
              language = "system";
              types = [ "markdown" ];
              pass_filenames = true;
            };

            # ── Commit message validation (config: .commitlintrc.yaml) ──────
            commitlint = {
              enable = true;
              name = "commitlint";
              entry = "${pkgs.commitlint}/bin/commitlint --edit";
              language = "system";
              stages = [ "commit-msg" ];
              pass_filenames = false;
            };

            # ── Branch naming (check-branch / commit-check) ─────────────────
            # Not available in nixpkgs; dropped from Nix config.
            # Install manually if needed: pip install commit-check
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

        porkchop = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            zapp.nixosModules.default
            ./hosts/nixos/porkchop
          ];
        };

        # Minimal template host — provisions at 10.0.6.66/22 so a real config
        # can be applied immediately after booting.  Built and installed via
        # the ephemeraltron-iso package below.
        ephemeraltron = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            ./hosts/nixos/ephemeraltron
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

      # Installer ISOs
      # Build: nix build .#ephemeraltron-iso
      packages.x86_64-linux.ephemeraltron-iso =
        (lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs // {
            # Pre-build the target system and bundle it in the ISO store so
            # installation requires no internet access.
            ephemeraltronSystem = self.nixosConfigurations.ephemeraltron.config.system.build.toplevel;
          };
          modules = [ ./installer/ephemeraltron.nix ];
        }).config.system.build.isoImage;

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
              statix # Nix linter — catches antipatterns and suggests fixes
            ];
            # Installs git hooks into .git/hooks when entering the devShell
            inherit (preCommitCheck.${system}) shellHook;
          };
        }
      );
    };
}
