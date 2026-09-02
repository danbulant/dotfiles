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
        ports: !override [ "127.0.0.1:3000:3000" ]
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
        "${cfg.infrastructureRoot}/collector/docker-compose.yml"
        portOverlays.collector
      ];
    };
    grafana = {
      directory = "${cfg.infrastructureRoot}/grafana";
      files = [
        "${cfg.infrastructureRoot}/grafana/docker-compose.yml"
        portOverlays.grafana
      ];
    };
    loki = {
      directory = "${cfg.infrastructureRoot}/loki-adctf";
      files = [
        "${cfg.infrastructureRoot}/loki-adctf/docker-compose.yml"
        portOverlays.loki
      ];
    };
    prometheus = {
      directory = "${cfg.infrastructureRoot}/prometheus";
      files = [
        "${cfg.infrastructureRoot}/prometheus/docker-compose.yml"
        portOverlays.prometheus
      ];
    };
    suricata = {
      directory = "${cfg.infrastructureRoot}/suricata";
      files = [ "${cfg.infrastructureRoot}/suricata/docker-compose.yml" ];
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
        "${cfg.infrastructureRoot}/other/cloudbeaver/docker-compose.yml"
        portOverlays.cloudbeaver
      ];
    };
  };

  stacks =
    infrastructureStacks
    // applicationStacks
    // optionalAttrs cfg.cloudbeaver.enable cloudbeaverStack;

  proxyPorts = {
    collector = 6256;
    grafana = 6003;
    loki = 6004;
    alloy = 6005;
    prometheus = 9090;
    statek = 5173;
    statek-api = 8080;
    tulip = 3000;
  }
  // optionalAttrs cfg.cloudbeaver.enable { cloudbeaver = 8978; };

  proxyHosts = mapAttrs' (
    name: port:
    nameValuePair "${name}.${cfg.proxy.baseDomain}:80" {
      extraConfig = "reverse_proxy http://127.0.0.1:${toString port}";
    }
  ) proxyPorts;

  composeCommand = name: stack:
    "${compose} --project-name ${escapeShellArg "adctf-${name}"} "
    + concatMapStringsSep " " (file: "-f ${escapeShellArg file}") stack.files;

  mkComposeService = name: stack:
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
      environment = stack.environment or { };
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

      virtualbox.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable VirtualBox as a fallback for VirtualBox-formatted vulnbox images.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
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
        daemon.settings."cgroup-parent" = "docker.slice";
      };

      environment.systemPackages = [
        pkgs.docker-compose
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.infrastructureRoot}/traffic 0775 ${cfg.user} users -"
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
    }

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

    (mkIf cfg.virtualMachines.virtualbox.enable {
      virtualisation.virtualbox.host = {
        enable = true;
        enableKvm = true;
        addNetworkInterface = false;
      };
      users.users.${cfg.user}.extraGroups = [ "vboxusers" ];
    })
  ]);
}
