{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    # hyprland.url = "github:hyprwm/Hyprland/v0.48.1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      # inputs.hyprland.follows = "hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dolphin-overlay = {
      url = "github:rumboon/dolphin-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { zen-browser, nixpkgs, dolphin-overlay, hyprland-plugins, /*hyprland,*/ home-manager, nixpkgs-unstable, nix-gaming,nix-index-database, ... }@attrs: {
    nixosConfigurations.lenovo-nix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        {
          nixpkgs.overlays = [ dolphin-overlay.overlays.default ];
        }
        # ./obs.nix # doesn't work. Use nix-shell -p obs-studio instead
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dan = (import ./home.nix) { inherit zen-browser nixpkgs-unstable nix-gaming /*suyu hyprland*/ hyprland-plugins; };
          home-manager.backupFileExtension = "backup";
        }
        ./configuration.nix
        nix-index-database.nixosModules.nix-index
        { programs.nix-index-database.comma.enable = true; }
      ];
    };
  };
}
