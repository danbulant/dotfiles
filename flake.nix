{
  inputs = {
    waydroid-script = {
      url = "github:casualsnek/waydroid_script";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    waydroid-nvidia-nix = {
      url = "github:yigexuanmu/waydroid-nvidia-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omp = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.bun2nix.follows = "bun2nix";
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
    dank-greeter = {
      url = "git+https://github.com/AvengeMedia/dank-greeter.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    delta = {
      url = "github:zed-industries/delta-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    reenv = {
      url = "github:levigross/NixRevAI";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    colmena.url = "github:zhaofengli/colmena";
    nix-monitor = {
      url = "github:antonjah/nix-monitor";
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
      reenv,
      bun2nix,
      ...
    }@attrs:
    let
      photoprismOverlay = final: prev: {
        photoprism = final.callPackage ./pkgs/photoprism/package.nix {
          photoprism = prev.photoprism;
        };
      };
      # Preserve NVIDIA ELF header order; sorting corrupts cicc at dynamic-loader startup.
      singlePassCudaRunpath = pkgs: old: {
        appendRunpaths = (old.appendRunpaths or [ ]) ++ [ "${pkgs.addDriverRunpath.driverLink}/lib" ];
        patchelfFlags = (old.patchelfFlags or [ ]) ++ [ "--no-sort" ];
        # Only autoPatchelf honors patchelfFlags; fold driver lookup into that pass.
        dontPatchELF = true;
        dontUseAutoAddDriverRunpath = true;
      };

      desktopCompatibilityOverlay = _: prev: {
        # Apply during scope construction so CUDA's nested pkgs inherit the fix too.
        _cuda = prev._cuda.extend (_: cudaPrev: {
          extensions = cudaPrev.extensions ++ [
            (_: cudaPrev:
              prev.lib.optionalAttrs (cudaPrev.cudaMajorMinorVersion == "13.3") {
                libnvvm = cudaPrev.libnvvm.overrideAttrs (singlePassCudaRunpath prev);
                cuda_nvcc = cudaPrev.cuda_nvcc.overrideAttrs (singlePassCudaRunpath prev);
                libcufile = cudaPrev.libcufile.overrideAttrs (singlePassCudaRunpath prev);
              }
              // prev.lib.optionalAttrs (cudaPrev.cudaMajorMinorVersion == "13.4") {
                cuda_gdb = cudaPrev.cuda_gdb.overrideAttrs (singlePassCudaRunpath prev);
                cuda_sanitizer_api = cudaPrev.cuda_sanitizer_api.overrideAttrs (singlePassCudaRunpath prev);
              })
          ];
        });

        # Structured wrapper arguments must be separate tokens, not one shell string.
        aw-qt = prev.aw-qt.overrideAttrs (_: {
          makeWrapperArgs = [ "--suffix" "PATH" ":" (prev.lib.makeBinPath [ prev.xdg-utils ]) ];
        });

        # Godot 4.7 also requires HarfBuzz's optional vector library.
        godot_4 = prev.godot_4.override {
          harfbuzz = prev.harfbuzz.override { withVector = true; };
        };

        # sphinxHook reads a scalar; structured attrs otherwise expose only "html".
        khal = prev.khal.overrideAttrs (_: {
          sphinxBuilders = "html man";
        });

        # ActivityWatch's aw-core requires Peewee 3, not the default Peewee 4.
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (finalPython: prevPython: {
            aw-core = prevPython.aw-core.override {
              peewee = finalPython.peewee_3;
            };
          })
        ];

        # DwarFS 0.14.0 bundles Folly and fbthrift snapshots that relied on
        # transitive C string declarations and fmt's pre-12 core header.
        dwarfs = prev.dwarfs.overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + prev.lib.optionalString (old.version == "0.14.0") ''
              sed -i '/#include <exception>/i#include <cstring>' folly/folly/lang/Exception.h
              sed -i '/#include <array>/i#include <cstring>' \
                fbthrift/thrift/compiler/ast/t_type.cc
              sed -i '/#include <cinttypes>/i#include <cstring>' \
                fbthrift/thrift/compiler/generate/t_concat_generator.cc
              find fbthrift -type f \( -name '*.h' -o -name '*.cc' \) \
                -exec sed -i 's|<fmt/core\.h>|<fmt/format.h>|g' {} +
            '';
        });

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
      };
    in
    {
      # Export sysbox package overlay for external use
      overlays.default = final: prev: {
        sysbox = final.callPackage ./pkgs/sysbox/package.nix { };
        tuwunel-admin = final.callPackage ./pkgs/tuwunel-admin/package.nix { };
      };

      # Export sysbox NixOS module for external use
      nixosModules.sysbox = import ./modules/sysbox.nix;
      nixosModules.tuwunel-admin = import ./modules/tuwunel-admin.nix;
      nixosModules.adctf = import ./modules/adctf.nix;

      packages.x86_64-linux = rec {
        tuwunel-admin =
          nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/tuwunel-admin/package.nix
            { };
        default = tuwunel-admin;
      };

      devShells.x86_64-linux.secrets = nixpkgs.legacyPackages.x86_64-linux.mkShellNoCC {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          sops
          age
          ssh-to-age
        ];
      };

      nixosConfigurations.fern = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          hypr-kdeconnect-fix.nixosModules.default
          determinate.nixosModules.default
          home-manager.nixosModules.home-manager
          ./modules/adctf.nix
          {
            services.hypr-kdeconnect-fix.enable = true;
            home-manager.extraSpecialArgs = attrs;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.dan = import ./servers/ui-mode/home.nix;
            home-manager.backupFileExtension = "backup";
            nixpkgs.overlays = [
              bun2nix.overlays.default
              desktopCompatibilityOverlay
              photoprismOverlay
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
              bun2nix.overlays.default
              desktopCompatibilityOverlay
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

          ./servers/ui-mode/configuration.nix
          ./servers/aura/configuration.nix
          # Import sysbox module
          ./modules/sysbox.nix
          nix-index-database.nixosModules.nix-index
          { programs.nix-index-database.comma.enable = true; }
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
