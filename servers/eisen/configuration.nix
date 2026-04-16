{
  nix-index-database,
  pkgs,
  lib,
  name ? "eisen",
  ...
}:
let
  # these are used both in service configuration but also to
  # create mappings {name}.eisen.danbulant.cloud to port in caddy
  ports = {
    status = 3001;
    glance = 5678;
    jellyfin = 8096;
    qb = 8081;
    sonarr = 8989;
    radarr = 7878;
    jackett = 9117;
    prowlarr = 9696;
    keep = 8100;
    grafana = 3002;
    # ntfy = 3003;
  };
  internalPorts = {
    prometheus-node = 9000;
    prometheus-qb = 9200;
    prometheus-sonarr = 9101;
    prometheus-radarr = 9102;
    prometheus-prowlarr = 9103;
    prometheus = 9090;
  };
in
{
  deployment = {
    buildOnTarget = true;
    targetHost = "192.168.1.114";
  };

  programs.nix-index-database.comma.enable = true;

  imports = [
    nix-index-database.nixosModules.nix-index
    ./hardware-configuration.nix
  ];

  nix = {
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };

  networking = {
    hostName = name;
    nameservers = [ "1.1.1.1" ];
    networkmanager.enable = true;
  };

  time.timeZone = lib.mkForce "Europe/Prague";
  i18n.defaultLocale = "en_US.UTF-8";

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };

  services = {
    logind.lidSwitchExternalPower = "ignore";

    geoclue2.enable = true;
    localtimed.enable = true;
    openssh.enable = true;
    tailscale = {
      enable = true;
      useRoutingFeatures = "both";
      openFirewall = true;
      extraUpFlags = [ "--advertise-exit-node" ];
    };
    avahi.enable = true;
    lldpd.enable = true;

    jellyfin = {
      enable = true;
    };

    sonarr = {
      enable = true;
      settings.server.port = ports.sonarr;
    };

    radarr = {
      enable = true;
      settings.server.port = ports.radarr;
    };
    prowlarr = {
      enable = true;
      settings.server.port = ports.prowlarr;
    };
    karakeep = {
      enable = true;
      extraEnvironment = {
        PORT = toString ports.keep;
        # DISABLE_SIGNUPS = "true";
        DISABLE_NEW_RELEASE_CHECK = "true";
      };
      environmentFile = "/etc/secrets/karakeep.env";
    };

    dnsmasq = {
      enable = true;
    };

    uptime-kuma = {
      enable = true;
      settings = {
        PORT = toString ports.status;
      };
    };

    grafana = {
      enable = true;
      settings = {
        server.http_port = ports.grafana;
        security = {
          secret_key = "$__file{/etc/secrets/gf_secret_key}";
        };
      };
    };
    prometheus = {
      enable = true;
      exporters = {
        exportarr-radarr = {
          enable = true;
          url = "http://127.0.0.1:${toString ports.radarr}";
          port = internalPorts.prometheus-radarr;
          apiKeyFile = "/etc/secrets/radarr_api_key";
        };
        exportarr-sonarr = {
          enable = true;
          url = "http://127.0.0.1:${toString ports.sonarr}";
          port = internalPorts.prometheus-sonarr;
          apiKeyFile = "/etc/secrets/sonarr_api_key";
        };
        exportarr-prowlarr = {
          enable = true;
          url = "http://127.0.0.1:${toString ports.prowlarr}";
          port = internalPorts.prometheus-prowlarr;
          apiKeyFile = "/etc/secrets/prowlarr_api_key";
        };
        node = {
          enable = true;
          port = internalPorts.prometheus-node;
        };
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "localhost:${toString internalPorts.prometheus-node}" ];
            }
          ];
        }
        {
          job_name = "qb";
          static_configs = [
            {
              targets = [ "localhost:${toString internalPorts.prometheus-qb}" ];
            }
          ];
        }
        {
          job_name = "sonarr";
          static_configs = [
            {
              targets = [ "localhost:${toString internalPorts.prometheus-sonarr}" ];
            }
          ];
        }
        {
          job_name = "radarr";
          static_configs = [
            {
              targets = [ "localhost:${toString internalPorts.prometheus-radarr}" ];
            }
          ];
        }
      ];
    };

    # ntfy-sh = {
    #   enable = true;
    #   settings = {
    #     listen-http = ":${toString ports.ntfy}";
    #     base-url = "http://ntfy.eisen";
    #   };
    # };

    # grafana-to-ntfy = {
    #   enable = true;
    #   settings = {
    #     ntfyUrl = "http://ntfy.eisen/grafana";
    #   };
    # };

    glance = {
      enable = true;
      settings = {
        server = {
          port = ports.glance;
        };
        pages = import ./glance-pages.nix;
      };
    };

    caddy = {
      enable = true;

      extraConfig = ''
        (auth) {
          forward_auth unix//run/tailscale-nginx-auth/tailscale-nginx-auth.sock {
            uri /auth
            header_up Remote-Addr {remote_host}
            header_up Remote-Port {remote_port}
            header_up Original-URI {uri}
            copy_headers {
              Tailscale-User>X-Webauth-User
              Tailscale-Name>X-Webauth-Name
              Tailscale-Login>X-Webauth-Login
              Tailscale-Tailnet>X-Webauth-Tailnet
              Tailscale-Profile-Picture>X-Webauth-Profile-Picture
            }
          }
        }
      '';

      virtualHosts = builtins.listToAttrs (
        map (k: {
          name = "${k}.eisen.danbulant.cloud:80, ${k}.eisen:80";
          value = {
            # import auth
            extraConfig = ''
              reverse_proxy http://localhost:${toString ports.${k}}
            '';
          };
        }) (builtins.attrNames ports)
      );
    };
    tailscale.permitCertUid = "caddy";
    tailscaleAuth = {
      # this is what's used above in forward_auth
      enable = true;
      group = "caddy";
    };
  };
  # systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
    };

    oci-containers = {
      backend = "docker";
      containers = {
        gluetun = {
          image = "qmcgaw/gluetun";
          capabilities = {
            NET_ADMIN = true;
          };
          devices = [ "/dev/net/tun" ];
          environmentFiles = [ "/etc/secrets/gluetun.env" ];
          ports = [
            "${toString ports.qb}:${toString ports.qb}"
            "${toString ports.jackett}:${toString ports.jackett}"
          ];
          # VPN_SERVICE_PROVIDER=protonvpn
          # VPN_TYPE=wireguard
          # WIREGUARD_PRIVATE_KEY=wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU
          # SERVER_COUNTRIES=Denmark
          environment = {
            VPN_PORT_FORWARDING = "on";
            # TOR_ONLY = "on";
            PORT_FORWARD_ONLY = "on";
            FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24,100.64.0.0/10";
            FIREWALL_INPUT_PORTS = "41641,22,80,443,53";

            VPN_PORT_FORWARDING_UP_COMMAND = ''
              /bin/sh -c 'wget -O- -nv --retry-connrefused --post-data "json={\"listen_port\":{{PORT}},\"current_network_interface\":\"{{VPN_INTERFACE}}\",\"random_port\":false,\"upnp\":false}" http://127.0.0.1:${toString ports.qb}/api/v2/app/setPreferences'
            '';
            VPN_PORT_FORWARDING_DOWN_COMMAND = ''
              /bin/sh -c 'wget -O- -nv --retry-connrefused --post-data "json={\"listen_port\":0,\"current_network_interface\":\"lo\"}" http://127.0.0.1:${toString ports.qb}/api/v2/app/setPreferences'
            '';
          };
          # extraOptions = [ "--network=host" ];
        };
        qbittorrent = {
          image = "lscr.io/linuxserver/qbittorrent";

          environment = {
            WEBUI_PORT = toString ports.qb;
          };

          volumes = [
            "/media/large/downloads:/downloads"
            "qbittorrent-config:/config"
          ];

          extraOptions = [ "--network=container:gluetun" ];
        };
        jackett = {
          image = "lscr.io/linuxserver/jackett";

          volumes = [
            "jackett-config:/config"
          ];

          extraOptions = [ "--network=container:gluetun" ];
        };
        prometheus-qb = {
          image = "ghcr.io/esanchezm/prometheus-qbittorrent-exporter";
          environment = {
            QBITTORRENT_PORT = toString ports.qb;
            QBITTORRENT_HOST = "localhost";
            EXPORTER_PORT = toString internalPorts.prometheus-qb;
          };
          extraOptions = [ "--network=host" ];
          # ports = [ "8000:${toString internalPorts.prometheus-qb}" ];
        };
      };
    };
  };
  # hardware.nvidia-container-toolkit.enable = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    # Shortcuts for fixing things
    # alt+sysrq (prtsc) + key
    # h: Print help to the system log.
    # f: Trigger the kernel oom killer.
    # s: Sync data to disk before triggering the reset options below.
    # e: SIGTERM all processes except PID 0.
    # i: SIGKILL all processes except PID 0.
    # b: Reboot the system.
    kernel.sysctl."kernel.sysrq" = 1;

    # zfs.enabled = false;
    swraid.enable = false;

    initrd.systemd.enable = true;

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # timeout = 0;
      # grub.enable = true;
      # grub.device = "/dev/disk/by-id/ata-Apacer_AS350_512GB_2021012802000028";
      # grub.efiSupport = true;
    };
  };

  users.users.dan = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "fuse"
      "video"
      "wireshark"
      "gamemode"
      "scanner"
      "lp"
      "kvm"
      "adbusers"
    ];
    shell = pkgs.nushell;
  };
  nix.settings.trusted-users = [
    "root"
    "@wheel"
    "dan"
  ];

  environment.systemPackages = with pkgs; [
    lsof
    rsync
    git
    nvtopPackages.full
    btop
    lshw
    bat
    lsd
    fastfetch
    fish
    nix-output-monitor
    nh
    duf
    dust
    cachix
    qemu
    ffmpeg
    httpie
    socat
    websocat
    oh-my-posh
  ];

  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.cudaSupport = true;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # /etc/hosts :)
  networking.extraHosts = "";
}
