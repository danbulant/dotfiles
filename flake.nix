{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland/v0.44.1-b";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, nixpkgs-unstable, nix-gaming, nix-index-database, ... }@attrs: {
    nixosConfigurations.lenovo-nix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        # ./obs.nix # doesn't work. Use nix-shell -p obs-studio instead
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.users.dan = (import ./home.nix) { inherit nixpkgs-unstable nix-gaming; };
          home-manager.backupFileExtension = "backup";
        }
        ./configuration.nix
        nix-index-database.nixosModules.nix-index
        { programs.nix-index-database.comma.enable = true; }
      ];
    };

    # homeConfigurations.lenovo-nix = home-manager.lib.homeManagerConfiguration {
    #   pkgs = import nixpkgs {
    #     system = "x86_64-linux";
    #     config.allowUnfree = true;
    #   };

    #   extraSpecialArgs = {inherit attrs;};

    #   modules = [
    #     ./home.nix
    #   ];
    # };
  };
}
