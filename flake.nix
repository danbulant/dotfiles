{
  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      #url = "github:nix-community/home-manager/release-25.05";
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    colmena.url = "github:zhaofengli/colmena";

    copyparty.url = "github:9001/copyparty";
  };

  outputs = { nixpkgs, colmena, zen-browser, dolphin-overlay, hyprland-plugins, home-manager, nixpkgs-unstable, nix-gaming, nix-index-database, ... }@attrs: {
    nixosConfigurations.lenovo-nix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        {
          nixpkgs.overlays = [
            # dolphin-overlay.overlays.default
            (_: prev: {
              tailscale = prev.tailscale.overrideAttrs (old: {
                checkFlags =
                  builtins.map (
                    flag:
                      if prev.lib.hasPrefix "-skip=" flag
                      then flag + "|^TestGetList$|^TestIgnoreLocallyBoundPorts$|^TestPoller$"
                      else flag
                  )
                  old.checkFlags;
              });
            })
          ];
        }
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dan = (import ./home.nix) { inherit colmena zen-browser nixpkgs-unstable nix-gaming hyprland-plugins; };
          home-manager.backupFileExtension = "backup";
        }
        ./configuration.nix
        nix-index-database.nixosModules.nix-index
        { programs.nix-index-database.comma.enable = true; }
        ./powersave.nix
      ];
    };

    nixosConfigurations.eisen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        ./servers/eisen/configuration.nix
      ];
    };

    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };
        specialArgs = attrs;
      };

      eisen = import ./servers/eisen/configuration.nix;
    };
  };
}
