{
  description = "snowflakes — NixOS on sway, themed Miami Wind";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative flatpak (used for the sandboxed Zen browser)
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-flatpak,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # Change these two to match your machine / login.
      hostname = "snowflake";
      username = "finley";

      palette = import ./theme/miami-wind.nix;
      keys = import ./keys.nix;
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
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          {
            nixpkgs.hostPlatform = system;
            nixpkgs.overlays = [
              (final: _: { tulasi-icon-theme = final.callPackage ./pkgs/tulasi-icon-theme.nix { }; })
            ];
          }
          ./hosts/snowflake
          nix-flatpak.nixosModules.nix-flatpak
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

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
