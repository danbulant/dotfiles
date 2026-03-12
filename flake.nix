{
  inputs = {
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    colmena.url = "github:zhaofengli/colmena";
    affinity-nix.url = "github:mrshmllow/affinity-nix";

    copyparty.url = "github:9001/copyparty";

    nix-monitor = {
      url = "github:antonjah/nix-monitor";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      determinate,
      colmena,
      helium,
      zen-browser,
      dolphin-overlay,
      hyprland-plugins,
      home-manager,
      nixpkgs-unstable,
      nix-gaming,
      nix-index-database,
      dms,
      nix-monitor,
      ...
    }@attrs:
    {
      # Export sysbox package overlay for external use
      overlays.default = final: prev: {
        sysbox = final.callPackage ./pkgs/sysbox/package.nix { };
      };

      # Export sysbox NixOS module for external use
      nixosModules.sysbox = import ./modules/sysbox.nix;

      nixosConfigurations.aura = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          {
            nixpkgs.overlays = [
              # dolphin-overlay.overlays.default
              # Add sysbox overlay
              (final: prev: {
                sysbox = final.callPackage ./pkgs/sysbox/package.nix { };
                tailscale = prev.tailscale.overrideAttrs (old: {
                  checkFlags = builtins.map (
                    flag:
                    if prev.lib.hasPrefix "-skip=" flag then
                      flag + "|^TestGetList$|^TestIgnoreLocallyBoundPorts$|^TestPoller$"
                    else
                      flag
                  ) old.checkFlags;
                });
              })
            ];
          }
          determinate.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = attrs;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.dan = import ./home.nix;
            home-manager.backupFileExtension = "backup";
          }

          #          nix-monitor.nixosModules.default
          #        {
          #          programs.nix-monitor = {
          #            enable = true;

          # Required: customize for your setup
          #            rebuildCommand = [
          #              "bash" "-c"
          #              "cd /home/dan/projects/dotfiles; nh os switch . 2>&1"
          #            ];
          #          };
          #        }
          ./configuration.nix
          # Import sysbox module
          ./modules/sysbox.nix
          nix-index-database.nixosModules.nix-index
          { programs.nix-index-database.comma.enable = true; }
          #./powersave.nix
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
            overlays = [ ];
          };
          specialArgs = attrs;
        };

        eisen = import ./servers/eisen/configuration.nix;
      };
    };
}
