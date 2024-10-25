{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland/v0.44.1-b";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    home-manager.url = "github:nix-community/home-manager/release-24.05"; # /release-24.11
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nixvim = {
        url = "github:nix-community/nixvim";
        # If using a stable channel you can use `url = "github:nix-community/nixvim/nixos-<version>"`
        inputs.nixpkgs.follows = "nixpkgs";
    };
    # kwin-effects-forceblur.url = "https://gist.githubusercontent.com/taj-ny/c1abdde710f33e34dc39dc53a5dc2c09/raw/7078265012c37b6f6bc397e9a7893bc6004e7b6c/kwin-effects-forceblur.nix";
  };

  outputs = { nixpkgs, nixvim, home-manager, ... }@attrs: {
    nixosConfigurations.lenovo-nix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        # ./obs.nix # doesn't work. Use nix-shell -p obs-studio instead
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.users.dan = (import ./home.nix) { nix-gaming = attrs.nix-gaming; };
          home-manager.backupFileExtension = "backup";
        }
        # nixvim.nixosModules.nixvim
        ./configuration.nix
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
