{
  pkgs,
  lib,
  config,
  ...
}:

let
  llama-cpp = (
    (pkgs.llama-cpp.override {
      cudaSupport = true;
      rocmSupport = false;
      metalSupport = false;
      blasSupport = true;
    }).overrideAttrs
      (prevAttrs: rec {
        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
          ${prevAttrs.preConfigure or ""}
        '';
        version = "8999";
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b${version}";
          hash = "sha256-EgJ3Die/WpVm9dtQ2kwXoV4RAWNY9x7lT4wun79qqCI=";
          leaveDotGit = true;
          postFetch = ''
            git -C "$out" rev-parse --short HEAD > $out/COMMIT
            find "$out" -name .git -print0 | xargs -0 rm -rf
          '';
        };
        npmDepsHash = "sha256-k62LIbyY2DXvs7XXbX0lNPiYxuYzeJUyQtS4eA+68f8=";
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
          (cmakeBool "GGML_CLBLAST" true)
          (cmakeBool "GGML_CUDA" true)
          (cmakeBool "GGML_CUDA_GRAPHS" true)
          (cmakeBool "GGML_CUDA_F16" true)
          (cmakeBool "GGML_CUDA_FA_ALL_QUANTS" true)
          # (cmakeBool "GGML_HIP" false)
          # (cmakeBool "GGML_METAL" false)
          # (cmakeBool "GGML_RPC" false)
          # (cmakeBool "GGML_VULKAN" false)
          (cmakeFeature "LLAMA_BUILD_NUMBER" "8667")
          (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "120")
        ];
      })
  );
in
{
  services.hardware.openrgb.enable = true;
  boot = {
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

  services.paseo = {
    enable = true;
    relay.enable = false;
    user = "dan";
    group = "users";
    port = 5656;
    openFirewall = true;
  };

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
  environment.systemPackages = with pkgs; [
    nvitop
    # basalt-monado
    cudaPackages.cuda_nvcc
    llama-cpp
  ];
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
          --fit on --fit-ctx 131072 --fit-target 256 \
          --temp 1.0 --top-p 0.95 --top-k 64 \
          --repeat-penalty 1.0 \
          -ctk q8_0 -ctv q8_0 \
          --flash-attn on \
          --batch-size 1024 --ubatch-size 512 \
          --threads 12 --threads-batch 12 \
          --no-mmap --mlock \
          --parallel 1 --prio 2 --no-warmup --jinja
        '';
        models_dir = "\${env.HOME}/models";
      };
      models = {
        # qwen3-embedding-8b = {
        # };
        # "qwen3-embedding-0.6" = { };
        "qwen3.6-35B-A3B" = {
          cmd = "\${llama} -m /home/dan/.lmstudio/models/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
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
      ExecStart = lib.mkForce ''
        ${lib.getExe pkgs.llama-swap} --listen 0.0.0.0:${toString config.services.llama-swap.port} --config ${
          (pkgs.formats.yaml { }).generate "config.yaml" config.services.llama-swap.settings
        }
      '';
    };
  };
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    # powerManagement.enable = true;
    nvidiaSettings = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  # powerManagement.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;
}
