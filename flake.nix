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

    # Declarative flatpak (used for the sandboxed Zen browser). Tag v0.7.0.
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
      system = "x86_64-linux";

      # Change this to your login. Host names are the attribute names below.
      username = "u";

      palette = import ./theme/miami-wind.nix;
      keys = import ./keys.nix;

      # Every host gets the same desktop, home-manager config and microVMs;
      # hosts/<name>/default.nix adds its hardware and what only it needs.
      mkHost =
        hostname:
        let
          specialArgs = {
            inherit
              inputs
              hostname
              username
              palette
              keys
              ;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            {
              nixpkgs.hostPlatform = system;
              nixpkgs.overlays = [
                (final: _: { tulasi-icon-theme = final.callPackage ./pkgs/tulasi-icon-theme.nix { }; })
              ];
            }
            ./hosts/${hostname}
            nix-flatpak.nixosModules.nix-flatpak
            microvm.nixosModules.host
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = specialArgs;
                users.${username} = import ./home;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        # The desktop.
        harmonia = mkHost "harmonia";
        # The laptop (ThinkPad E14 Gen 2): the same, plus Wi-Fi, lid/power
        # handling and ThinkPad fan control.
        cadmus = mkHost "cadmus";
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
