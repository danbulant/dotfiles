{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.adctf;
  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    mapAttrs'
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optionalAttrs
    types
    ;

  compose = lib.getExe pkgs.docker-compose;
  qemuExe = lib.getExe' pkgs.qemu "qemu-system-x86_64";
  openvpn = lib.getExe pkgs.openvpn;

  portOverlays = {
    collector = pkgs.writeText "adctf-collector-ports.yml" ''
      services:
        collector:
          ports: [ "127.0.0.1:6256:6256" ]
    '';
    grafana = pkgs.writeText "adctf-grafana-ports.yml" ''
      services:
        grafana:
          ports: [ "127.0.0.1:6003:6003" ]
    '';
    loki = pkgs.writeText "adctf-loki-ports.yml" ''
      services:
        loki:
          ports: [ "127.0.0.1:6004:6004" ]
        alloy:
          ports: [ "127.0.0.1:6005:6005" ]
    '';
    prometheus = pkgs.writeText "adctf-prometheus-ports.yml" ''
      services:
        prometheus:
          ports: [ "127.0.0.1:9090:9090" ]
    '';
    cloudbeaver = pkgs.writeText "adctf-cloudbeaver-ports.yml" ''
      services:
        bober:
          ports: [ "127.0.0.1:8978:8978" ]
    '';
  };

  statekOverlay = pkgs.writeText "adctf-statek-overlay.yml" ''
    services:
      db:
        networks:
          statek:
          cct: { aliases: [ statek_db ] }
          cct6: { aliases: [ statek_db ] }
      scoreboard:
        networks:
          statek:
          cct: { aliases: [ statek_scoreboard ] }
          cct6: { aliases: [ statek_scoreboard ] }
      attackinfo:
        networks:
          statek:
          cct: { aliases: [ statek_attackinfo ] }
          cct6: { aliases: [ statek_attackinfo ] }
      submitter:
        networks:
          statek:
          cct: { aliases: [ statek_submitter ] }
          cct6: { aliases: [ statek_submitter ] }
      api:
        ports: !override [ "127.0.0.1:8081:8080" ]
        networks:
          statek:
            aliases: [ api ]
          cct: { aliases: [ statek_api ] }
          cct6: { aliases: [ statek_api ] }
      frontend:
        networks:
          statek:
          cct: { aliases: [ statek_frontend ] }
          cct6: { aliases: [ statek_frontend ] }
    networks:
      cct: { name: cct, external: true }
      cct6: { name: cct6, external: true }
  '';

  tulipOverlay = pkgs.writeText "adctf-tulip-overlay.yml" ''
    services:
      timescale:
        networks:
          internal:
          cct: { aliases: [ tulip_timescale ] }
          cct6: { aliases: [ tulip_timescale ] }
      frontend:
        ports: !override [ "127.0.0.1:3001:3000" ]
        networks:
          internal:
          cct: { aliases: [ tulip_frontend ] }
          cct6: { aliases: [ tulip_frontend ] }
      api:
        networks:
          internal:
          cct: { aliases: [ tulip_api ] }
          cct6: { aliases: [ tulip_api ] }
      flagids:
        networks:
          internal:
          cct: { aliases: [ tulip_flagids ] }
          cct6: { aliases: [ tulip_flagids ] }
      assembler:
        networks:
          internal:
          cct: { aliases: [ tulip_assembler ] }
          cct6: { aliases: [ tulip_assembler ] }
      enricher:
        networks:
          internal:
          cct: { aliases: [ tulip_enricher ] }
          cct6: { aliases: [ tulip_enricher ] }
    networks:
      cct: { name: cct, external: true }
      cct6: { name: cct6, external: true }
  '';

  infrastructureStacks = {
    collector = {
      directory = "${cfg.infrastructureRoot}/collector";
      files = [
        "${cfg.infrastructureRoot}/collector/compose.yml"
        portOverlays.collector
      ];
    };
    grafana = {
      directory = "${cfg.infrastructureRoot}/grafana";
      files = [
        "${cfg.infrastructureRoot}/grafana/compose.yml"
        portOverlays.grafana
      ];
    };
    loki = {
      directory = "${cfg.infrastructureRoot}/loki-budkyber";
      files = [
        "${cfg.infrastructureRoot}/loki-budkyber/compose.yml"
        portOverlays.loki
      ];
    };
    prometheus = {
      directory = "${cfg.infrastructureRoot}/prometheus";
      files = [
        "${cfg.infrastructureRoot}/prometheus/compose.yml"
        portOverlays.prometheus
      ];
    };
    suricata = {
      directory = "${cfg.infrastructureRoot}/suricata";
      files = [ "${cfg.infrastructureRoot}/suricata/compose.yml" ];
    };
  };

  applicationStacks = {
    statek = {
      directory = cfg.statekRoot;
      files = [
        "${cfg.statekRoot}/compose.yml"
        statekOverlay
      ];
    };
    tulip = {
      directory = cfg.tulipRoot;
      files = [
        "${cfg.tulipRoot}/compose.yml"
        tulipOverlay
      ];
      environment = {
        TRAFFIC_DIR_HOST = "${cfg.infrastructureRoot}/traffic";
        TRAFFIC_DIR_DOCKER = "/traffic";
      };
    };
  };

  cloudbeaverStack = {
    cloudbeaver = {
      directory = "${cfg.infrastructureRoot}/other/cloudbeaver";
      files = [
        "${cfg.infrastructureRoot}/other/cloudbeaver/compose.yml"
        portOverlays.cloudbeaver
      ];
    };
  };

  stacks =
    infrastructureStacks // applicationStacks // optionalAttrs cfg.cloudbeaver.enable cloudbeaverStack;

  proxyPorts = {
    collector = 6256;
    grafana = 6003;
    loki = 6004;
    alloy = 6005;
    prometheus = 9090;
    statek = 5173;
    statek-api = 8081;
    tulip = 3001;
  }
  // optionalAttrs cfg.cloudbeaver.enable { cloudbeaver = 8978; };

  proxyHosts = mapAttrs' (
    name: port:
    nameValuePair "${name}.${cfg.proxy.baseDomain}:80" {
      extraConfig = "reverse_proxy http://127.0.0.1:${toString port}";
    }
  ) proxyPorts;

  composeCommand =
    name: stack:
    "${compose} --project-name ${escapeShellArg "adctf-${name}"} "
    + concatMapStringsSep " " (file: "-f ${escapeShellArg file}") stack.files;

  mkComposeService =
    name: stack:
    nameValuePair "adctf-${name}" {
      description = "adctf ${name} containers";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "docker.service"
        "adctf-networks.service"
      ];
      after = [
        "docker.service"
        "adctf-networks.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      path = [ pkgs.coreutils ];
      environment = {
        DOCKER_BUILDKIT = "1";
        DOCKER_CLI_PLUGIN_DIRS = "${pkgs.docker-buildx}/libexec/docker/cli-plugins";
      }
      // (stack.environment or { });
      script = ''
        test -f ${escapeShellArg (builtins.head stack.files)}
        ${composeCommand name stack} up --detach --build --remove-orphans
      '';
      preStop = ''
        ${composeCommand name stack} down
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = stack.directory;
        TimeoutStartSec = "infinity";
        TimeoutStopSec = "5min";
      };
    };
in
{
  options.services.adctf = {
    enable = mkEnableOption "the adctf attack-defense infrastructure";

    user = mkOption {
      type = types.str;
      default = "dan";
      description = "Local user allowed to manage the container and VM runtimes.";
    };

    containerStacks.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the Docker-based attack-defense infrastructure stacks.";
    };

    infrastructureRoot = mkOption {
      type = types.str;
      default = "/home/dan/projects/ad-infrastructure-private";
      description = "Absolute path to the ad-infrastructure-private checkout.";
    };

    statekRoot = mkOption {
      type = types.str;
      default = "/home/dan/projects/statek";
      description = "Absolute path to the Statek checkout.";
    };

    tulipRoot = mkOption {
      type = types.str;
      default = "/home/dan/projects/tulip-private";
      description = "Absolute path to the Tulip checkout.";
    };

    cloudbeaver.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Start the optional CloudBeaver database UI.";
    };

    proxy = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Publish adctf HTTP services through Caddy.";
      };

      baseDomain = mkOption {
        type = types.str;
        default = "fern.danbulant.cloud";
        description = "Base domain below which each service gets its own subdomain.";
      };
    };

    cgroup = {
      reserveCpuPercent = mkOption {
        type = types.ints.between 0 99;
        default = 50;
        description = "Percentage of one logical CPU reserved outside docker.slice.";
      };

      reserveMemoryMiB = mkOption {
        type = types.ints.positive;
        default = 1024;
        description = "Physical memory reserved outside docker.slice.";
      };

      reserveSwapMiB = mkOption {
        type = types.ints.unsigned;
        default = 1024;
        description = "Swap reserved outside docker.slice when swap is available.";
      };
    };

    virtualMachines = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable libvirt/QEMU management for a qcow vulnbox image.";
      };

      faust = {
        enable = mkEnableOption "FAUST CTF Vulnbox";

        imagePath = mkOption {
          type = types.str;
          description = "Absolute path to the mutable Vulnbox qcow2 image.";
        };

        memoryMiB = mkOption {
          type = types.ints.positive;
          default = 8192;
          description = "Guest RAM in MiB.";
        };

        vcpus = mkOption {
          type = types.ints.positive;
          default = 4;
          description = "Guest virtual CPU count and host CPU quota.";
        };

        hostSshPort = mkOption {
          type = types.port;
          default = 2222;
          description = "Loopback TCP port forwarded to the guest SSH service.";
        };

        vncDisplay = mkOption {
          type = types.ints.between 0 99;
          default = 0;
          description = "Loopback VNC display number used for the guest console.";
        };

        autoStart = mkOption {
          type = types.bool;
          default = false;
          description = "Start the Vulnbox at boot.";
        };

        playerVpn = {
          enable = mkEnableOption "the host-side FAUST CTF player VPN";

          configPath = mkOption {
            type = types.str;
            default = "/var/lib/faustctf/player-faustctf.conf";
            description = "Runtime OpenVPN configuration path; its contents never enter the Nix store.";
          };

          autoStart = mkOption {
            type = types.bool;
            default = true;
            description = "Start the player VPN at boot when its configuration exists.";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.containerStacks.enable {
      assertions = [
        {
          assertion = lib.hasPrefix "/" cfg.infrastructureRoot;
          message = "services.adctf.infrastructureRoot must be an absolute path";
        }
        {
          assertion = lib.hasPrefix "/" cfg.statekRoot;
          message = "services.adctf.statekRoot must be an absolute path";
        }
        {
          assertion = lib.hasPrefix "/" cfg.tulipRoot;
          message = "services.adctf.tulipRoot must be an absolute path";
        }
      ];

      virtualisation.docker = {
        enable = true;
        daemon.settings = {
          "cgroup-parent" = "docker.slice";
          features.buildkit = true;
        };
      };

      environment.systemPackages = [
        pkgs.docker-buildx
        pkgs.docker-compose
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.infrastructureRoot}/traffic 0775 ${cfg.user} users -"
        "d ${cfg.infrastructureRoot}/traffic/pcaps 0775 ${cfg.user} users -"
      ];

      users.users.${cfg.user}.extraGroups = [ "docker" ];

      systemd.slices.docker = {
        description = "Docker container resource budget";
        sliceConfig = {
          CPUAccounting = true;
          MemoryAccounting = true;
        };
      };

      systemd.services = {
        docker = {
          requires = [ "adctf-cgroup-limits.service" ];
          after = [ "adctf-cgroup-limits.service" ];
          wantedBy = [ "multi-user.target" ];
        };

        adctf-cgroup-limits = {
          description = "Reserve host resources outside docker.slice";
          before = [ "docker.service" ];
          path = [
            pkgs.coreutils
            pkgs.systemd
          ];
          script = ''
            logical_cpus="$(nproc --all)"
            cpu_quota="$((logical_cpus * 100 - ${toString cfg.cgroup.reserveCpuPercent}))"
            memory_total_kib=0
            swap_total_kib=0

            while read -r key value _; do
              case "$key" in
                MemTotal:) memory_total_kib="$value" ;;
                SwapTotal:) swap_total_kib="$value" ;;
              esac
            done < /proc/meminfo

            reserve_memory_kib=$((${toString cfg.cgroup.reserveMemoryMiB} * 1024))
            if ((memory_total_kib <= reserve_memory_kib)); then
              echo "Cannot reserve ${toString cfg.cgroup.reserveMemoryMiB} MiB from $((memory_total_kib / 1024)) MiB of physical memory" >&2
              exit 1
            fi
            memory_max_kib="$((memory_total_kib - reserve_memory_kib))"

            reserve_swap_kib=$((${toString cfg.cgroup.reserveSwapMiB} * 1024))
            if ((swap_total_kib > reserve_swap_kib)); then
              swap_max_kib="$((swap_total_kib - reserve_swap_kib))"
            else
              swap_max_kib=0
            fi

            systemctl set-property --runtime docker.slice \
              CPUQuota="''${cpu_quota}%" \
              MemoryMax="''${memory_max_kib}K" \
              MemorySwapMax="''${swap_max_kib}K"
          '';
          preStop = ''
            systemctl set-property --runtime docker.slice \
              CPUQuota=infinity MemoryMax=infinity MemorySwapMax=infinity
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };

        adctf-networks = {
          description = "Create adctf container networks";
          requires = [ "docker.service" ];
          after = [ "docker.service" ];
          path = [ config.virtualisation.docker.package ];
          script = ''
            docker network inspect cct >/dev/null 2>&1 || \
              docker network create \
                --gateway 10.66.0.1 \
                --ip-range 10.66.0.0/16 \
                --subnet 10.66.0.0/16 \
                cct

            docker network inspect cct6 >/dev/null 2>&1 || \
              docker network create \
                --ipv6 \
                --subnet 2001:db8:1::/64 \
                cct6
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      }
      // mapAttrs' mkComposeService stacks;

      services.caddy = mkIf cfg.proxy.enable {
        enable = true;
        virtualHosts = proxyHosts;
      };
    })

    (mkIf cfg.virtualMachines.enable {
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;
      users.users.${cfg.user}.extraGroups = [
        "kvm"
        "libvirtd"
      ];
      environment.systemPackages = with pkgs; [
        qemu
        quickemu
        virt-viewer
      ];
    })

    (mkIf cfg.virtualMachines.faust.enable {
      assertions = [
        {
          assertion = lib.hasPrefix "/" cfg.virtualMachines.faust.imagePath;
          message = "services.adctf.virtualMachines.faust.imagePath must be an absolute path";
        }
        {
          assertion = lib.hasPrefix "/" cfg.virtualMachines.faust.playerVpn.configPath;
          message = "services.adctf.virtualMachines.faust.playerVpn.configPath must be an absolute path";
        }
      ];

      environment.systemPackages = [
        pkgs.openvpn
        pkgs.qemu
        pkgs.socat
        pkgs.virt-viewer
      ];
      users.users.${cfg.user}.extraGroups = [ "kvm" ];

      systemd.tmpfiles.rules = [
        "d /var/lib/faustctf 0700 root root -"
      ];

      systemd.services.faust-vulnbox = {
        description = "FAUST CTF Vulnbox";
        wantedBy = lib.optional cfg.virtualMachines.faust.autoStart "multi-user.target";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.ConditionPathExists = cfg.virtualMachines.faust.imagePath;
        path = [
          pkgs.coreutils
          pkgs.socat
        ];
        script = ''
          exec ${qemuExe} \
            -name faust-vulnbox \
            -machine q35,accel=kvm \
            -cpu host \
            -smp ${toString cfg.virtualMachines.faust.vcpus} \
            -m ${toString cfg.virtualMachines.faust.memoryMiB} \
            -drive ${escapeShellArg "file=${cfg.virtualMachines.faust.imagePath},if=virtio,format=qcow2,cache=none,discard=unmap"} \
            -nic ${escapeShellArg "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${toString cfg.virtualMachines.faust.hostSshPort}-:22"} \
            -device virtio-rng-pci \
            -display ${escapeShellArg "vnc=127.0.0.1:${toString cfg.virtualMachines.faust.vncDisplay}"} \
            -monitor unix:"$RUNTIME_DIRECTORY/monitor.sock",server=on,wait=off \
            -boot order=c \
            -rtc base=utc,clock=host
        '';
        preStop = ''
          if [[ -S "$RUNTIME_DIRECTORY/monitor.sock" ]]; then
            printf 'system_powerdown\n' | socat - UNIX-CONNECT:"$RUNTIME_DIRECTORY/monitor.sock" || true
          fi

          for _ in $(seq 1 60); do
            kill -0 "$MAINPID" 2>/dev/null || exit 0
            sleep 1
          done
        '';
        serviceConfig = {
          User = cfg.user;
          Group = "users";
          RuntimeDirectory = "faust-vulnbox";
          UMask = "0077";
          CPUQuota = "${toString (cfg.virtualMachines.faust.vcpus * 100)}%";
          MemoryAccounting = true;
          MemoryMax = "${toString (cfg.virtualMachines.faust.memoryMiB + 1024)}M";
          TasksMax = 512;
          LimitNOFILE = 4096;
          Nice = 5;
          OOMPolicy = "stop";
          Restart = "on-failure";
          RestartSec = "5s";
          TimeoutStopSec = "75s";
          KillSignal = "SIGTERM";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [ cfg.virtualMachines.faust.imagePath ];
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
        };
      };
    })

    (mkIf (cfg.virtualMachines.faust.enable && cfg.virtualMachines.faust.playerVpn.enable) {
      networking.nftables = {
        enable = true;
        tables."faust-player" = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority -10; policy accept;
              iifname "tun-faustctf" ct state established,related accept
              iifname "tun-faustctf" drop
            }
          '';
        };
      };

      systemd.services.faust-player-vpn = {
        description = "FAUST CTF player VPN";
        wantedBy = lib.optional cfg.virtualMachines.faust.playerVpn.autoStart "multi-user.target";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.ConditionPathExists = cfg.virtualMachines.faust.playerVpn.configPath;
        serviceConfig = {
          Type = "simple";
          ExecStart = "${openvpn} --config ${escapeShellArg cfg.virtualMachines.faust.playerVpn.configPath} --data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC";
          WorkingDirectory = builtins.dirOf cfg.virtualMachines.faust.playerVpn.configPath;
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadOnlyPaths = [ cfg.virtualMachines.faust.playerVpn.configPath ];
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
        };
      };
    })
  ]);
}
