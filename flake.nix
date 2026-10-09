{
  description = "harmonia — NixOS on sway, themed Miami Wind";

  # Every input is pinned to an exact commit. To update one, replace its rev
  # with a newer commit from the branch or tag named in the comment above it
  # (`git ls-remote <repo> <ref>`), then rebuild.
  inputs = {
    # nixos-unstable, 2026-09-27
    nixpkgs.url = "github:nixos/nixpkgs/e158d9ed9b51c98974c5e66e1ba1c9e0255fecaa";

    home-manager = {
      # master, 2026-09-27
      url = "github:nix-community/home-manager/7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative flatpak (the sandboxed Firefox, Element and friends). Tag v0.7.0.
    nix-flatpak.url = "github:gmodena/nix-flatpak/440818969ac2cbd77bfe025e884d0aa528991374";

    # Hardware profiles; cadmus uses the ThinkPad E14 Gen 2 one. master, 2026-10-04
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/31cc5f4d9b9ba601071e8b8504601b9b176e2756";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The Nike microVM (nike/, modules/nixos/nike.nix). main, 2026-10-01
    microvm = {
      url = "github:microvm-nix/microvm.nix/3f1540f254fe73ac907281b7de7d396bb3d54850";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-flatpak,
      microvm,
      ...
    }@inputs:
    let
      # Change this to your login (Dionysus's is "d", below). Host names are
      # the attribute names below.
      defaultUsername = "u";

      palette = import ./theme/miami-wind.nix;
      keys = import ./keys.nix;

      # The tulasi-icon-theme overlay, used by every host.
      iconOverlay = (
        final: _: {
          tulasi-icon-theme = final.callPackage ./pkgs/tulasi-icon-theme.nix { };
        }
      );

      # Builds one host from hosts/<hostname>/default.nix and its home
      # config. harmonia and cadmus share the desktop, the home config and the
      # microVMs; Dionysus has its own user and home (home/dionysus) and no
      # microVMs, and is built for whichever architecture is passed.
      mkHost =
        {
          hostname,
          system ? "x86_64-linux",
          username ? defaultUsername,
          home ? ./home,
          vms ? true,
        }:
        let
          # `system` lets a home config decide, statically, whether to pull
          # in x86_64-only pieces (home/dionysus/default.nix).
          specialArgs = {
            inherit
              inputs
              hostname
              username
              palette
              keys
              system
              ;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            {
              nixpkgs.hostPlatform = system;
              nixpkgs.overlays = [ iconOverlay ];
            }
            ./hosts/${hostname}
            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = specialArgs;
                users.${username} = import home;
              };
            }
          ]
          ++ nixpkgs.lib.optional vms microvm.nixosModules.host;
        };

      # Per-architecture outputs (the formatter, the docs) for both systems.
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );

      # Dionysus: harmonia's Sway desktop with the coding toolset built in
      # natively (opencode, Claude Code and the Rust tools) and no microVMs,
      # so the same config works on aarch64-linux and x86_64-linux.
      mkDionysus =
        system:
        mkHost {
          hostname = "dionysus";
          inherit system;
          username = "d";
          home = ./home/dionysus;
          vms = false;
        };
    in
    {
      nixosConfigurations = {
        # The desktop.
        harmonia = mkHost { hostname = "harmonia"; };
        # The laptop (ThinkPad E14 Gen 2): the same, plus Wi-Fi, lid/power
        # handling and ThinkPad fan control.
        cadmus = mkHost { hostname = "cadmus"; };

        # Dionysus: the dev/creative desktop with everything native and no
        # microVMs. Same two outputs so `nixos-rebuild --flake .#dionysus`
        # works on an x86_64 host and `.#dionysus-aarch64` on an aarch64 one.
        dionysus = mkDionysus "x86_64-linux";
        dionysus-aarch64 = mkDionysus "aarch64-linux";
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      # The documentation site (mkdocs.yml, docs/): `nix build .#docs` builds
      # it into ./result, `nix develop .#docs` gives a shell for `mkdocs serve`.
      packages = forAllSystems (pkgs: {
        docs = pkgs.runCommand "harmonia-docs" {
          nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
          src = nixpkgs.lib.fileset.toSource {
            root = ./.;
            fileset = nixpkgs.lib.fileset.unions [
              ./mkdocs.yml
              ./docs
              ./scripts/mkdocs-hooks.py
            ];
          };
        } "cd $src && mkdocs build --strict --site-dir $out";
      });

      devShells = forAllSystems (pkgs: {
        docs = pkgs.mkShell { packages = [ pkgs.python3Packages.mkdocs-material ]; };
      });
    };
}
