{
  inputs = {
    paseo = {
      url = "github:getpaseo/paseo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    spacedrive-src = {
      url = "github:spacedriveapp/spacedrive";
      flake = false;
    };
    spacebot-src = {
      url = "github:spacedriveapp/spacebot";
      flake = false;
    };
    dmm = {
      url = "github:deadlock-mod-manager/deadlock-mod-manager/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hypr-kdeconnect-fix.url = "github:danbulant/hypr-kdeconnect-fix";
    codexbar = {
      url = "github:0xferrous/CodexBar-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rusic.url = "github:temidaradev/rusic";
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zed.url = "github:zed-industries/zed";
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
    reenv = {
      url = "github:levigross/NixRevAI";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      home-manager,
      nix-index-database,
      hypr-kdeconnect-fix,
      paseo,
      reenv,
      bun2nix,
      crane,
      spacedrive-src,
      spacebot-src,
      ...
    }@attrs:
    {
      # Export sysbox package overlay for external use
      overlays.default = final: prev: {
        sysbox = final.callPackage ./pkgs/sysbox/package.nix { };
        tuwunel-admin = final.callPackage ./pkgs/tuwunel-admin/package.nix { };
      };

      # Export sysbox NixOS module for external use
      nixosModules.sysbox = import ./modules/sysbox.nix;
      nixosModules.tuwunel-admin = import ./modules/tuwunel-admin.nix;

      packages.x86_64-linux = rec {
        tuwunel-admin = nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/tuwunel-admin/package.nix { };
        default = tuwunel-admin;
      };

      nixosConfigurations.fern = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          hypr-kdeconnect-fix.nixosModules.default
          paseo.nixosModules.paseo
          determinate.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            services.hypr-kdeconnect-fix.enable = true;
            home-manager.extraSpecialArgs = attrs;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.dan = import ./servers/ui-mode/home.nix;
            home-manager.backupFileExtension = "backup";
            nixpkgs.overlays = [
              bun2nix.overlays.default
              (_: prev: {
                # Hyprland 0.56.1 requires glaze >= 7 and < 8, while this
                # nixpkgs revision provides glaze 8.0.0.
                hyprland = prev.hyprland.override {
                  glaze = prev.glaze.overrideAttrs (_: {
                    version = "7.8.3";
                    src = prev.fetchFromGitHub {
                      owner = "stephenberry";
                      repo = "glaze";
                      tag = "v7.8.3";
                      hash = "sha256-WqtaZ3AVDs1oIfAVQuU63eg+0753LoYfv/pRyG9OMnM=";
                    };
                  });
                };

                # ethnum 1.5.2 assumes TryFromIntError is zero-sized, which is
                # no longer true with Rust 1.97. Apply its upstream safe fix to
                # SpacetimeDB's writable Cargo vendor tree.
                spacetimedb = prev.spacetimedb.overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    substituteInPlace "$cargoDepsCopy/source-registry-0/ethnum-1.5.2/src/error.rs" \
                      --replace-fail 'pub const fn tfie() -> TryFromIntError {' 'pub fn tfie() -> TryFromIntError {' \
                      --replace-fail 'unsafe { mem::transmute(()) }' 'u8::try_from(-1i8).unwrap_err()'
                  '';
                });

                # pyfilesystem2 still uses pkg_resources at runtime, which was
                # removed from setuptools 82. Keep setuptools 80 build-only for
                # the upstream tests, but migrate the installed package to the
                # standard-library entry-point API so Python environments don't
                # contain two conflicting setuptools versions.
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (_: pythonPrev: {
                    fs = pythonPrev.fs.overridePythonAttrs (old: {
                      nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [
                        pythonPrev.setuptools_80
                      ];
                      postInstall = (old.postInstall or "") + ''
                        fsPath="$out/${pythonPrev.python.sitePackages}/fs"
                        substituteInPlace "$fsPath/__init__.py" "$fsPath/opener/__init__.py" \
                          --replace-fail '__import__("pkg_resources").declare_namespace(__name__)  # type: ignore' ""
                        substituteInPlace "$fsPath/opener/registry.py" \
                          --replace-fail 'import pkg_resources' 'from importlib import metadata' \
                          --replace-fail 'pkg_resources.iter_entry_points("fs.opener")' 'metadata.entry_points(group="fs.opener")' \
                          --replace-fail 'pkg_resources.iter_entry_points("fs.opener", protocol)' 'iter(metadata.entry_points(group="fs.opener", name=protocol))'
                      '';
                      meta = old.meta // {
                        broken = false;
                      };
                    });
                  })
                ];
              })
              (final: _: {
                spacedrive-master =
                  let
                    sources = import ./pkgs/spacedrive/nix/sources.nix {
                      inherit (final) lib;
                      root = spacedrive-src;
                    };
                    packages = import ./pkgs/spacedrive/nix {
                      pkgs = final;
                      craneLib = crane.mkLib final;
                      upstreamRoot = spacedrive-src;
                      spacebotRoot = spacebot-src;
                      inherit (sources)
                        frontendSrc
                        daemonRustSrc
                        desktopRustSrc
                        cliRustSrc
                        ;
                    };
                  in
                  packages.spacedrive;
              })
            ];
            networking.hostName = "fern";
            imports = [ ./servers/fern/hardware-configuration.nix ];
          }
          ./servers/fern/configuration.nix
          ./servers/ui-mode/configuration.nix
          nix-index-database.nixosModules.nix-index
          { programs.nix-index-database.comma.enable = true; }
        ];
      };

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
            home-manager.users.dan = import ./servers/ui-mode/home.nix;
            home-manager.backupFileExtension = "backup";
            networking.hostName = "aura";
            imports = [ ./servers/aura/hardware-configuration.nix ];
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
          ./servers/ui-mode/configuration.nix
          ./servers/aura/configuration.nix
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
