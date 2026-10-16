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
  waydroidNvidia = (waydroid-nvidia-nix.packages.${system}.waydroid-nvidia-full).overrideAttrs (_: {
    postFixup = ''
      wrapProgram $out/bin/waydroid \
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs.lxc
            pkgs.kmod
            pkgs.util-linux
          ]
        }
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
          (cmakeBool "GGML_LTO" true)
          (cmakeBool "GGML_CUDA" true)
          (cmakeBool "GGML_CUDA_GRAPHS" true)
          (cmakeBool "GGML_CUDA_F16" true)
          (cmakeBool "GGML_CUDA_FA_ALL_QUANTS" true)
          (cmakeFeature "LLAMA_BUILD_NUMBER" version)
          (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "120")
        ];
      })
  );

  clefPython = (pkgs.python3.override {
    packageOverrides = final: prev: {
      cuda-bindings = prev.cuda-bindings.override { cudaPackages = pkgs.cudaPackages_13_3; };
      triton-bin = prev.triton-bin.overrideAttrs (old: {
        # Fix nixpkgs' binary patch: libcuda_dirs must return directories, not a string.
        postFixup = (old.postFixup or "") + ''
          substituteInPlace "$out/${pkgs.python3.sitePackages}/triton/backends/nvidia/driver.py" \
            --replace-fail \
              "return '${pkgs.addDriverRunpath.driverLink}/lib/libcuda.so'" \
              "return ['${pkgs.addDriverRunpath.driverLink}/lib']"
        '';
      });
      torch-bin = (prev.torch-bin.override { cudaPackages = pkgs.cudaPackages_13_3; }).overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          cudaSupport = true;
          rocmSupport = false;
          cudaPackages = pkgs.cudaPackages_13_3;
        };
      });
      torch = final.torch-bin;
      torchvision = prev.torchvision-bin.override { cudaPackages = pkgs.cudaPackages_13_3; };
    };
  }).withPackages (ps: with ps; [
    torch
    torchvision
    transformers
    accelerate
    bitsandbytes
    safetensors
    pillow
  ]);
  clefServer = pkgs.writeShellScript "clef-flash-server" ''
    # Triton compiles its CUDA driver helper during the first inference.
    export CC=${lib.getExe' pkgs.stdenv.cc "cc"}
    export HF_HUB_OFFLINE=1
    export HF_HUB_DISABLE_TELEMETRY=1
    exec ${clefPython}/bin/python ${../../pkgs/clef/server.py} \
      --model-dir /home/dan/models/Cloudflare/clef-flash "$@"
  '';
  # Restic always encrypts; this intentionally public password needs no secret
  # provisioning and matches Eisen's local repository.
  eisenResticPassword = pkgs.writeText "eisen-restic-public-password" "restic-eisen-public\n";
in
{
  imports = [
    waydroid-nvidia-nix.nixosModules.waydroid-nvidia
  ];

  services.hardware.openrgb.enable = true;

  # Match the GUI's "Lights Off" action: Direct mode writes black to every
  # addressable LED, while Static only changes the controller's built-in effect.
  # Run this as the SDK server's stop command so it cannot race the server being
  # torn down during shutdown.
  systemd.services.openrgb.serviceConfig.ExecStop =
    "${lib.getExe config.services.hardware.openrgb.package} --device B850 --mode direct --color 000000 --device Wooting --mode direct --color 000000";
  # The split RemoteDesktop/ScreenCast portal session emits malformed D-Bus
  # traffic with XDPH 1.4.1. Override capture without replacing Sunshine's
  # mutable web-UI configuration.
  systemd.user.services.sunshine.serviceConfig.ExecStart =
    lib.mkForce ''"/run/wrappers/bin/sunshine" "capture=wlr"'';

  # The backup client uses ordinary SSH on a Tailscale-only port 2223.
  # Tailscale SSH intercepts port 22 and cannot consume sshd's ForceCommand.
  services.openssh.extraConfig = ''
    Match User restic-eisen
      ChrootDirectory /var/lib/restic-receiver
      ForceCommand internal-sftp -d /eisen
      DisableForwarding yes
      PermitTTY no
      AuthenticationMethods publickey
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PubkeyAuthentication yes
  '';
  services.openssh.openFirewall = false;
  services.openssh.ports = [ 22 2223 ];
  services.openssh.listenAddresses = [
    {
      addr = "0.0.0.0";
      port = 22;
    }
    {
      # NixOS appends :port verbatim, so IPv6 addresses need brackets.
      addr = "[::]";
      port = 22;
    }
    {
      addr = "100.120.15.10";
      port = 2223;
    }
  ];
  systemd.services.sshd = {
    wants = [ "network-online.target" "tailscaled.service" ];
    after = [ "network-online.target" "tailscaled.service" ];
  };
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2223 ];
  # ssh -R (remote port forward) to this server should listen publicly
  services.openssh.settings.GatewayPorts = "yes";
  services.tailscale.extraUpFlags = lib.mkAfter [ "--ssh" ];

  # `tailscale ssh` remains available for administrators; restic deliberately
  # uses the ordinary port above so this account is constrained by sshd.


  services.adctf = {
    enable = false;
    containerStacks.enable = true;
    proxy = {
      baseDomain = "fern.badapple.cz";
    };
    virtualMachines = {
      enable = true;
      faust = {
        enable = true;
        imagePath = "/home/dan/Downloads/vulnbox.qcow2";
        memoryMiB = 8192;
        vcpus = 8;
        hostSshPort = 2222;
        vncDisplay = 0;
        autoStart = false;
        playerVpn = {
          enable = true;
          configPath = "/home/dan/Downloads/player-faustctf.conf";
        };
      };
    };
  };

  users.groups.restic-eisen = { };
  users.users.restic-eisen = {
    isSystemUser = true;
    group = "restic-eisen";
    home = "/media/large/restic/eisen";
    shell = "${pkgs.shadow}/bin/nologin";
    # Reuse Eisen's existing machine SSH host key as this account's client
    # identity; the ForceCommand above prevents shell access.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuCpbQyWhXv+lDpLnf4tB+AfAsAbCaEtHflnX1QLnlG root@eisen"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /media/large/restic 0755 root root -"
    "d /media/large/restic/eisen 0700 restic-eisen restic-eisen -"
    "d /var/lib/restic-receiver 0755 root root -"
  ];
  # /media/large is owned by dan, so it cannot be an SSH chroot ancestor.
  # Expose only the repository beneath a separate root-owned chroot, on demand.
  fileSystems."/var/lib/restic-receiver/eisen" = {
    device = "/media/large/restic/eisen";
    fsType = "none";
    options = [
      "bind"
      "nofail"
      "x-systemd.automount"
      "x-systemd.requires-mounts-for=/media/large"
    ];
  };
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
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };

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


  programs.kdeconnect.enable = true;

  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    # Steam support
    enable32Bit = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];
  };
  environment.systemPackages =
    (with pkgs; [
      photoprism
      wl-clipboard
      mtkclient
      blender
      (android-studio.withSdk (
        androidenv.composeAndroidPackages {
          platformVersions = [ "35" ];
          includeEmulator = true;
          includeSystemImages = true;
          systemImageTypes = [ "google_apis" ];
          abiVersions = [ "x86_64" ];
          includeNDK = "if-supported";
        }
      ).androidsdk)
      nvitop
      cudaPackages.cuda_nvcc
      llama-cpp
      imgbrd-grabber
      protonplus

      eden

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
        "clef-flash" = {
          cmd = "${clefServer} --port \${PORT}";
          checkEndpoint = "/health";
          ttl = 300;
          # A decision model, not a chat/completions model.
          unlisted = true;
        };
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
  services.forgejo-runner.instances.fern = {
    enable = true;
    settings = {
      runner.labels = [ "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-24.04" ];
      server.connections.default = {
        url = "https://git.badapple.cz";
        # Offline registration token prefix: d647656e3d16534c.
        uuid = "64363437-3635-3665-3364-313635333463";
      };
    };
    secrets.server.connections.default.token_url = "/etc/secrets/forgejo-runner-token";
  };
  systemd.services.forgejo-runner-fern.requires = [ "docker.service" ];

  services.photoprism = {
    enable = true;
    originalsPath = "/media/large/photos";
    importPath = "/var/lib/photoprism/import";
    passwordFile = "/etc/secrets/photoprism";
    settings = {
      PHOTOPRISM_DETECT_NSFW = "true";
      PHOTOPRISM_SITE_URL = "https://photos.badapple.cz";
      PHOTOPRISM_SITE_TITLE = "BA Photos";
    };
  };

  programs.ssh.knownHosts.storagebox = {
    hostNames = [ "[u669849.your-storagebox.de]:23" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };

  systemd.services.photos-storagebox-sync = {
    description = "Sync photos to Hetzner Storage Box";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathIsDirectory = "/media/large/photos";
    serviceConfig = {
      Type = "oneshot";
      User = "dan";
      Group = "users";
      Nice = 10;
      IOSchedulingClass = "idle";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      PrivateTmp = true;
    };
    script = ''
      exec ${lib.getExe pkgs.rsync} \
        --archive \
        --human-readable \
        --partial \
        --rsh="${lib.getExe pkgs.openssh} -p 23 -i /home/dan/.ssh/id_ed25519 -o BatchMode=yes" \
        /media/large/photos/ \
        u669849@u669849.your-storagebox.de:photos/
    '';
  };

  systemd.timers.photos-storagebox-sync = {
    description = "Sync photos to Hetzner Storage Box every four hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00/4:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  # Copy snapshots, not the live repository files: restic coordinates locks
  # with Eisen's writers and keeps the offsite repository independently usable.
  systemd.services.eisen-restic-storagebox = {
    description = "Copy Eisen restic snapshots from Fern to Hetzner";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/media/large/restic/eisen/config";
    environment = {
      RESTIC_REPOSITORY = "sftp:u669849@u669849.your-storagebox.de:restic/eisen";
      RESTIC_PASSWORD_FILE = eisenResticPassword;
    };
    serviceConfig = {
      Type = "oneshot";
      User = "root"; # Read the restricted receiver and existing Storage Box key.
      Nice = 10;
      IOSchedulingClass = "idle";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ "/media/large/restic/eisen" ]; # Source repository locks.
      PrivateTmp = true;
      CacheDirectory = "restic-eisen-storagebox";
      Restart = "on-failure";
      RestartSec = "30m";
      TimeoutStartSec = "12h";
    };
    script = ''
      set -eu
      export RESTIC_CACHE_DIR="$CACHE_DIRECTORY"
      restic() {
        ${lib.getExe pkgs.restic} \
          -o "sftp.command=${lib.getExe pkgs.openssh} -p 23 -i /home/dan/.ssh/id_ed25519 -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -s u669849@u669849.your-storagebox.de sftp" \
          "$@"
      }
      restic cat config >/dev/null || restic init
      restic copy --from-repo /media/large/restic/eisen \
        --from-password-file ${eisenResticPassword}
      restic forget --prune --group-by tags \
        --keep-hourly 24 --keep-daily 14 --keep-weekly 8 \
        --keep-monthly 12 --keep-yearly 5
    '';
  };
  systemd.timers.eisen-restic-storagebox = {
    description = "Copy Eisen backups to Hetzner every four hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00/4:00:00";
      Persistent = true;
      RandomizedDelaySec = "20m";
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
      "photos.badapple.cz:80" = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.photoprism.port}
        '';
      };
    };
  };

  services.tailscale.extraSetFlags = lib.mkForce [
    "--advertise-exit-node"
    "--ssh"
  ];

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
    nvidiaSettings = false;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  # Stable device names for Hyprland's AMD-primary multi-GPU renderer.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:11:00.0", SYMLINK+="dri/amd-igpu"
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:01:00.0", SYMLINK+="dri/nvidia-dgpu"
  '';
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

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
