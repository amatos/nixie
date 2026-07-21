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

    nix-keytabs-matos-cc = {
      url = "github:amatos/nix-keytabs-matos-cc";
      flake = false; # plain git repo, not a flake
    };

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    homebrew-autoupdate = {
      url = "github:Homebrew/homebrew-autoupdate";
      flake = false; # plain git repo, not a flake
    };

    homebrew-cirruslabs-cli = {
      url = "github:cirruslabs/homebrew-cli";
      flake = false; # plain git repo, not a flake
    };

    homebrew-dracula-install = {
      url = "github:dracula/homebrew-install";
      flake = false; # plain git repo, not a flake
    };

    zapp = {
      url = "github:zsa/zapp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-kerberos-ldap = {
      url = "github:amatos/nix-kerberos-ldap";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-secrets.follows = "nix-secrets";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qmd = {
      url = "github:tobi/qmd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    direnv-instant = {
      url = "github:Mic92/direnv-instant";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-home-alberth = {
      url = "github:amatos/nix-home-alberth";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        nix-secrets.follows = "nix-secrets";
        nvf.follows = "nvf";
        qmd.follows = "qmd";
        stylix.follows = "stylix";
        direnv-instant.follows = "direnv-instant";
        pre-commit-hooks.follows = "pre-commit-hooks";
      };
    };

    orion-browser = {
      url = "github:amatos/nix-orion-browser";
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
      nix-keytabs-matos-cc,
      nvf,
      nix-homebrew,
      homebrew-autoupdate,
      homebrew-cirruslabs-cli,
      homebrew-dracula-install,
      zapp,
      pre-commit-hooks,
      nix-kerberos-ldap,
      disko,
      qmd,
      stylix,
      direnv-instant,
      nix-home-alberth,
      orion-browser,
      ...
    }:
    let
      # Helper to build a lib from nixpkgs for a given system
      inherit (nixpkgs) lib;

      # Supported systems
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      # Shared specialArgs passed to every host configuration
      sharedSpecialArgs = {
        inherit
          self
          nix-secrets
          nix-keytabs-matos-cc
          nvf
          homebrew-autoupdate
          homebrew-cirruslabs-cli
          homebrew-dracula-install
          qmd
          stylix
          direnv-instant
          nix-home-alberth
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

        # nhcodex — a lean test bed for future home-manager changes, with no
        # nix-home-alberth involvement; see hosts/darwin/nhcodex/default.nix.
        # networking.hostName stays "codex".
        nhcodex = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            ragenix.nixosModules.default
            ./hosts/darwin/nhcodex
          ];
        };

        # CI build target — mirrors ephemeraltron's role on the darwin side.
        # Not provisioned or switched to interactively.
        darwintron = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            ragenix.nixosModules.default
            ./hosts/darwin/darwintron
          ];
        };

        template-darwin = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            ragenix.nixosModules.default
            nix-homebrew.darwinModules.nix-homebrew
            ./hosts/darwin/template-darwin
          ];
        };
      };

      # NixOS configurations (Linux)
      # Usage: nixos-rebuild switch --flake .#<hostname>
      nixosConfigurations = {
        gammu = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            zapp.nixosModules.default
            orion-browser.nixosModules.default
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
            ./hosts/nixos/porkchop
          ];
        };

        template-nixos = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            ./hosts/nixos/template-nixos
          ];
        };

        huginn = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            ./hosts/nixos/huginn
          ];
        };

        muninn = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.default
            nix-kerberos-ldap.nixosModules.default
            ./hosts/nixos/muninn
          ];
        };

        # CI build target — exists so ci.yml's build-ephemeraltron job has a
        # real x86_64-linux nixosConfiguration to build (not just evaluate)
        # on every push/PR. Not provisioned or switched to interactively.
        ephemeraltron = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = [
            ./hosts/nixos/ephemeraltron
          ];
        };

        # Generic nixos-anywhere bootstrap target — no nixie identity baked
        # in. Deploy with: nixos-anywhere --flake .#minixie root@<target-ip>
        # Replace with a real host config once reachable; not part of
        # sharedSpecialArgs on purpose (it never consumes nix-secrets or
        # nix-keytabs-matos-cc).
        minixie = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ragenix.nixosModules.default
            ./hosts/nixos/minixie
            # hardware.facter.reportPath is a native nixpkgs option (the
            # standalone nixos-facter-modules flake is deprecated/upstreamed).
            # facter.json only exists after a real deploy generates it
            # (nixos-anywhere --generate-hardware-config nixos-facter ...);
            # a plain path literal to a file untracked by git fails flake
            # evaluation outright, so only set the option once the file is
            # actually present and committed.
            (lib.optionalAttrs (builtins.pathExists ./hosts/nixos/minixie/facter.json) {
              hardware.facter.reportPath = ./hosts/nixos/minixie/facter.json;
            })
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
              nixos-anywhere # provision new hosts via nixos-anywhere
              nix-tree # visualize derivation dependency graph
              nvd # diff two NixOS/darwin closures before switching
              statix # Nix linter — catches antipatterns and suggests fixes
              pre-commit # run pre-commit hooks when building
              commitlint # lint commit messages
              markdownlint-cli2 # lint markdown files
              direnv # load environment variables from .env files
            ];
            # Installs git hooks into .git/hooks when entering the devShell
            inherit (preCommitCheck.${system}) shellHook;
          };
        }
      );
    };
}
