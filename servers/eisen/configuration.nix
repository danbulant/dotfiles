
{ config, pkgs, lib, name ? "eisen", copyparty, ... }:
let
  # these are used both in service configuration but also to
  # create mappings {name}.eisen.danbulant.cloud to port in caddy
  ports = {
    "status" = 3001;
    "glance" = 5678;
    "copyparty" = 3210;
    "syncthing" = 8384;
    "gitea" = 3000;
    "immich" = 2283;
    "grafana" = 3002;
    "ntfy" = 3003;
  };
in
{
  deployment = {
    buildOnTarget = true;
  };

  nixpkgs.overlays = [ copyparty.overlays.default ];

  imports = [
    copyparty.nixosModules.default
    ./hardware-configuration.nix
  ];

  nix = {
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };

  networking = {
    hostName = name;
    nameservers = ["1.1.1.1"];
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

    syncthing = {
      enable = true;
      openDefaultPorts = true;
      settings = {
        gui = {
          insecureSkipHostCheck = true;
        };
      };
    };
    
    copyparty = {
      enable = true;

      settings = {
        p = ports.copyparty;
        idp-hm-usr = "^X-Webauth-Login^danbulant@github^dan";
        rproxy = 1;
        xff-hdr = "X-Forwarded-For";
        ipu = [ "100.103.148.81/32=dan" /*"100.79.186.114/32=dan" "100.76.144.133/32=dan" "100.114.62.113/32=dan" */ ];
      };

      accounts = {
        dan = {
          passwordFile = "/dev/null";
        };
      };

      volumes = {
        "/" = {
          path = "/media/large";
          access = {
            rwa = [ "dan" ];
            r = [ "*" ];
          };
        };
      };

      openFilesLimit = 8192;
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
      settings.server.http_port = ports.grafana;
    };

    gitea = {
      enable = true;
      lfs = {
        enable = true;
        contentDir = "/media/large/gitea-lfs";
      };
      appName = "Eisen git";
      settings.server.DOMAIN = "gitea.eisen";
      settings.server.HTTP_PORT = ports.gitea;
      settings.server.ROOT_URL = "http://gitea.eisen/";
    };

    immich = {
      enable = true;
    };
    
    ntfy-sh = {
      enable = true;
      settings = {
        listen-http = ":${toString ports.ntfy}";
        base-url = "http://ntfy.eisen";
      };
    };

    grafana-to-ntfy = {
      enable = true;
      settings = {
        ntfyUrl = "http://ntfy.eisen/grafana";
      };
    };

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
    tailscaleAuth = {
       # this is what's used above in forward_auth
      enable = true;
      group = "caddy";
    };
  };
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
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
    extraGroups = [ "networkmanager" "wheel" "docker" "fuse" "video" "wireshark" "gamemode" "scanner" "lp" "kvm" "adbusers"];
    shell = pkgs.nushell;
    packages = with pkgs; [
      
    ];
  };
  nix.settings.trusted-users = [ "root" "@wheel" "dan" ];

  environment.systemPackages = with pkgs; [
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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # /etc/hosts :)
  networking.extraHosts = ''
  '';
}