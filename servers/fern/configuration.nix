{
  pkgs,
  lib,
  config,
  reenv,
  waydroid-script,
  waydroid-nvidia-nix,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  waydroidNvidia =
    (waydroid-nvidia-nix.packages.${system}.waydroid-nvidia-full).overrideAttrs
      (_: {
        postFixup = ''
          wrapProgram $out/bin/waydroid \
            --prefix PATH : ${lib.makeBinPath [ pkgs.lxc pkgs.kmod pkgs.util-linux ]}
          wrapProgram $out/lib/waydroid/data/scripts/waydroid-net.sh \
            --prefix PATH : ${
              lib.makeBinPath [
                pkgs.lxc
                pkgs.kmod
                pkgs.iptables
                pkgs.nftables
                pkgs.iproute2
                pkgs.dnsmasq
                pkgs.gawk
                pkgs.getent
              ]
            }
        '';
      });

  ninfs = pkgs.python3Packages.buildPythonApplication {
    pname = "ninfs";
    version = "1.7b2";
    format = "setuptools";

    src = pkgs.fetchFromGitHub {
      owner = "ihaveamac";
      repo = "ninfs";
      rev = "v1.7b2";
      hash = "sha256-x1BxY3YGfCPdqp44xLnbKimRoMPNqel/bP1mGdvx+98=";
    };

    postPatch = ''
      sed -i '/#include <dlfcn.h>/a #include <string>' ninfs/hac/_crypto.cpp
    '';

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      pycryptodomex
    ];

    doCheck = false;
  };

  llama-cpp = (
    (pkgs.llama-cpp.override {
      cudaSupport = true;
      rocmSupport = false;
      metalSupport = false;
      blasSupport = true;
    }).overrideAttrs
      (_: rec {
        version = "10434";
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b${version}";
          hash = "sha256-Sz0kW1q91YzdrKbZUqMbFJ0DLZrzARSGheUrtCKcoQo=";
        };
        npmRoot = "tools/ui";
        npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
          prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=7e4c0a96"
          pushd ${npmRoot}
          LLAMA_BUILD_NUMBER=${version} npm run build
          popd
        '';
        cmakeFlags = with pkgs.lib; [
          # -march=native is non-deterministic; override with platform-specific flags if needed
          (cmakeBool "GGML_NATIVE" true)
          (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
          (cmakeBool "LLAMA_BUILD_SERVER" true)
          (cmakeBool "LLAMA_BUILD_TESTS" false)
          (cmakeBool "LLAMA_OPENSSL" true)
          (cmakeBool "BUILD_SHARED_LIBS" true)
          # (cmakeBool "GGML_BLAS" false)
          (cmakeBool "GGML_LTO" true)
          (cmakeBool "GGML_CUDA" true)
          (cmakeBool "GGML_CUDA_GRAPHS" true)
          (cmakeBool "GGML_CUDA_F16" true)
          (cmakeBool "GGML_CUDA_FA_ALL_QUANTS" true)
          # (cmakeBool "GGML_HIP" false)
          # (cmakeBool "GGML_METAL" false)
          # (cmakeBool "GGML_RPC" false)
          # (cmakeBool "GGML_VULKAN" false)
          (cmakeFeature "LLAMA_BUILD_NUMBER" version)
          (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "120")
        ];
      })
  );
in
{
  imports = [
    waydroid-nvidia-nix.nixosModules.waydroid-nvidia
  ];

  services.hardware.openrgb.enable = true;
  # The split RemoteDesktop/ScreenCast portal session emits malformed D-Bus
  # traffic with XDPH 1.4.1. Override capture without replacing Sunshine's
  # mutable web-UI configuration.
  systemd.user.services.sunshine.serviceConfig.ExecStart =
    lib.mkForce ''"/run/wrappers/bin/sunshine" "capture=wlr"'';

  # Hyprland's FALLBACK output has no capturable framebuffer. Keep a real
  # headless output available so Sunshine can stream when no monitor is attached.
  # systemd.user.services.sunshine-headless-output = {
  #   description = "Create a headless Hyprland output for Sunshine";
  #   before = [ "sunshine.service" ];
  #   partOf = [ "graphical-session.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     ExecStart = pkgs.writeShellScript "sunshine-headless-output" ''
  #       ${lib.getExe' pkgs.hyprland "hyprctl"} output create headless sunshine
  #       ${lib.getExe' pkgs.hyprland "hyprctl"} keyword monitor sunshine,1920x1080@60,0x0,1
  #     '';
  #     ExecStop = pkgs.writeShellScript "remove-sunshine-headless-output" ''
  #       ${lib.getExe' pkgs.hyprland "hyprctl"} output remove sunshine
  #     '';
  #   };
  # };
  # systemd.user.services.sunshine = {
  #   requires = [ "sunshine-headless-output.service" ];
  #   after = [ "sunshine-headless-output.service" ];
  # };
  # ssh -R (remote port forward) to this server should listen publicly
  services.openssh.settings.GatewayPorts = "yes";
  boot = {
    # Steam client bug #13186: xpad conflicts with Steam Controller emulation
    # and crashes Steam while a game is starting.
    blacklistedKernelModules = [ "xpad" ];
    kernelParams = [
      # attempt to fix nvidia perf
      "nvidia_drm.fbdev=1"
      "nvidia_drm.modeset=1"
      "module_blacklist=i915"
      "delayacct"
      "initcall_blacklist=sysfb_init"
      #"quiet"
      #"splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };

  # vr
  # services.monado = {
  #   enable = false;
  #   defaultRuntime = true; # Register as default OpenXR runtime
  # };
  # systemd.user.services.monado.environment = {
  #   STEAMVR_LH_ENABLE = "1";
  #   XRT_COMPOSITOR_COMPUTE = "1";
  #   WMR_HANDTRACKING = "0";
  #   VIT_SYSTEM_LIBRARY_PATH = "${pkgs.basalt-monado}/lib/libbasalt.so";
  # };
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraProfile = ''
        # Fixes timezones on VRChat
        unset TZ
        # Allows Monado/WiVRn to be used
        export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
      '';
    };
  };

  #services.paseo = {
  #  enable = true;
  #  relay.enable = false;
  #  user = "dan";
  #  group = "users";
  #  port = 5656;
  #  openFirewall = true;
  #};

  programs.kdeconnect.enable = true;

  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    # package = unstable-pkgs.mesa.drivers;
    # Steam support
    enable32Bit = true;
    # package32 = unstable-pkgs.pkgsi686Linux.mesa.drivers;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];
  };
  environment.systemPackages =
    (with pkgs; [
      wl-clipboard
      mtkclient
      blender
      android-studio-full
      nvitop
      # basalt-monado
      cudaPackages.cuda_nvcc
      llama-cpp
      imgbrd-grabber
      protonplus

      # Reverse engineering tooling
      bintools
      binwalk
      ctrtool
      fuse
      fuse3
      mtools
      openssl
      p7zip
      sleuthkit
      aircrack-ng
      hostapd
      iw
      ninfs
      tcpdump
      wireshark-cli
      avalonia-ilspy
    ])
    ++ [ waydroid-script.packages.${system}.default ]
    ++ (with reenv.packages.${system}; [
      bindiff
      ghidra-with-extensions
      retdec
    ]);

  environment.sessionVariables = {
    GHIDRA_MCP_BRIDGE = "${
      reenv.packages.${system}.ghidra-with-extensions
    }/libexec/ghidra-mcp/bridge_mcp_ghidra.py";
  };

  environment.extraInit = ''
    export LD_LIBRARY_PATH="${
      pkgs.lib.makeLibraryPath [
        pkgs.fuse
        pkgs.fuse3
      ]
    }:''${LD_LIBRARY_PATH:-}"
  '';
  services.llama-swap = {
    enable = true;
    openFirewall = true;
    settings = {
      #      listen = "0.0.0.0:8080";
      macros = {
        llama = ''
          ${pkgs.lib.getExe' llama-cpp "llama-server"} \
          --port ${"\${PORT}"} \
          --alias "unsloth/qwen" \
          --no-webui \
          --ctx-size 131072 \
          --gpu-layers auto \
          --fit on --fit-ctx 131072 --fit-target 256 \
          --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 \
          --repeat-penalty 1.0 \
          -ctk q8_0 -ctv q8_0 \
          --flash-attn on \
          --batch-size 1024 --ubatch-size 512 \
          --threads 12 --threads-batch 12 \
          --load-mode mlock \
          --parallel 1 --no-warmup --jinja
        '';
        models_dir = "\${env.HOME}/models";
      };
      globalTTL = 3600;
      models = {
        # qwen3-embedding-8b = {
        # };
        # "qwen3-embedding-0.6" = { };
        "qwen3.6-35B-A3B" = {
          cmd = "\${llama} -m /home/dan/.lmstudio/models/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
        };
        "qwen3.8-27B-Q2" = {
          cmd = "\${llama} -m /home/dan/models/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q2_K_XL.gguf --ctx-size 100000 --fit-ctx 100000";
        };
        "qwen3.8-27B-Q4" = {
          cmd = "\${llama} -m /home/dan/models/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-Q4_0.gguf --ctx-size 100000 --fit-ctx 100000 -ctk q4_0 -ctv q4_0 --ubatch-size 128 --spec-type draft-mtp --spec-draft-n-max 3";
        };
        "gemma-4-26B-A4B" = {
          cmd = "\${llama} -m /home/dan/.lmstudio/models/lmstudio-community/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-Q4_K_M.gguf";
        };
        "qwen3.5-9B" = {
          cmd = "\${llama} -m /home/dan/.lmstudio/models/lmstudio-community/Qwen3.5-9B-GGUF/Qwen3.5-9B-Q4_K_M.gguf";
        };
        "qwen3.5-9B-sushi" = {
          cmd = "\${llama} -m /home/dan/.lmstudio/models/bigatuna/Qwen3.5-9b-Sushi-Coder-RL-GGUF/Qwen3.5-9b-Sushi-Coder-RL.Q4_K_M.gguf";
        };
      };
    };
  };
  systemd.services.llama-swap = {
    environment = {
      HOME = "/home/dan";
    };
    serviceConfig = {
      ProtectHome = pkgs.lib.mkForce false;
      DynamicUser = pkgs.lib.mkForce false;
      User = pkgs.lib.mkForce "dan";
      Group = pkgs.lib.mkForce "users"; # or dan's primary group
      LimitMEMLOCK = "infinity";
      ExecStart = lib.mkForce ''
        ${lib.getExe pkgs.llama-swap} --listen 0.0.0.0:${toString config.services.llama-swap.port} --config ${
          (pkgs.formats.yaml { }).generate "config.yaml" config.services.llama-swap.settings
        }
      '';
    };
  };

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/var/secrets/cache-private-key.pem";
  };

  services.caddy = {
    enable = true;

    virtualHosts = {
      "llama.fern.danbulant.cloud:80" = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.llama-swap.port}
        '';
      };
      "nix.fern.danbulant.cloud:80" = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.nix-serve.port}
        '';
      };
    };
  };

  nix.optimise = {
    automatic = true;
    persistent = true;
  };
  nix.gc = {
    automatic = true;
    persistent = true;
  };

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    # powerManagement.enable = true;
    nvidiaSettings = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  # Stable device names for Hyprland's AMD-primary multi-GPU renderer.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:11:00.0", SYMLINK+="dri/amd-igpu"
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:01:00.0", SYMLINK+="dri/nvidia-dgpu"
  '';
  # powerManagement.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;
  
  # Keep the host resolver off Waydroid's 192.168.240.1:53 listener.
  services.dnsmasq.settings = {
    listen-address = "127.0.0.1";
    bind-interfaces = true;
  };

  services.waydroid-nvidia = {
    enable = true;
    package = waydroidNvidia;
    refreshRate = 200;
  };

  virtualisation.waydroid = {
    enable = true;
    package = waydroidNvidia;
  };

  # Native-bridge installers reuse these global binfmt names. Container
  # restarts do not clear them, so switching libndk/libhoudini otherwise leaves
  # stale interpreters pointing at files removed from the Android overlay.
  systemd.services.waydroid-container.preStart = ''
    for handler in arm_exe arm_dyn arm64_exe arm64_dyn; do
      handlerPath="/proc/sys/fs/binfmt_misc/$handler"
      if [[ -e "$handlerPath" ]]; then
        echo -1 > "$handlerPath"
      fi
    done
  '';
}
