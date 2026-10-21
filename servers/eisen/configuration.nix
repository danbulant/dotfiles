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
    forgejo = 8300;
    matrix = 6167;
    sable = 6200;
    livekit = 7880;
    hedgedoc = 7900;
    vaultwarden = 8222; # default vw port
  };

  tailscaleAddress = "100.99.54.121";
  privateHttpPort = 80;
  internalPorts = {
    prometheus-node = 9000;
    prometheus-qb = 9200;
    prometheus-sonarr = 9101;
    prometheus-radarr = 9102;
    prometheus-prowlarr = 9103;
    prometheus-llama-swap = 9409;
    prometheus = 9090;
    livekit-jwt = 8080;
    tuwunel-admin = 8009;
    hindsight-api = 8888;
    hindsight-ui = 9999;
  };
  matrixServerName = "badapple.cz";
  matrixHost = "matrix.badapple.cz";
  livekitKeyFile = "/var/lib/livekit/keys";
  resticRepository = "sftp:restic-eisen@100.120.15.10:/eisen";
  # This is deliberately public: it avoids restic's rejection of an empty
  # password without creating a missing secret-file activation prerequisite.
  # Transport security comes from the pinned SSH host key and reused machine
  # identity.
  resticPasswordCommand = pkgs.writeShellScript "restic-eisen-password" ''
    printf '%s\n' 'restic-eisen-public'
  '';
  resticEnvironmentFile = pkgs.writeText "restic-eisen-environment" ''
    RESTIC_PASSWORD_COMMAND=${resticPasswordCommand}
  '';
  resticSftpCommand = "${lib.getExe pkgs.openssh} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts -o Port=2223 -i /etc/ssh/ssh_host_ed25519_key -s restic-eisen@100.120.15.10 sftp";
  resticExtraOptions = [
    "sftp.command='${resticSftpCommand}'"
  ];
  resticPruneOpts = [
    "--retry-lock=30m"
    "--keep-hourly=24"
    "--keep-daily=14"
    "--keep-weekly=8"
    "--keep-monthly=12"
    "--keep-yearly=5"
    "--group-by=tags"
  ];
  resticDefaults = {
    repository = resticRepository;
    environmentFile = toString resticEnvironmentFile;
    initialize = false;
    extraOptions = resticExtraOptions;
    pruneOpts = resticPruneOpts;
  };
  resticServiceConfig = {
    Restart = "on-failure";
    RestartSec = "30m";
    TimeoutStartSec = "12h";
  };
  resticBackupNames = [
    "forgejo"
    "matrix"
    "hedgedoc"
    "vaultwarden"
    "karakeep"
    "uptime-kuma"
    "grafana"
    "media-indexers"
    "hindsight"
  ];
  resticBackupServices = map (name: "restic-backups-${name}.service") resticBackupNames;
  resticRepositoryInit = pkgs.writeShellScript "restic-eisen-repository-init" ''
    set -eu
    error="$(${pkgs.coreutils}/bin/mktemp)"
    trap '${pkgs.coreutils}/bin/rm -f "$error"' EXIT

    restic() {
      ${lib.getExe pkgs.restic} --no-cache --option ${lib.escapeShellArg "sftp.command=${resticSftpCommand}"} "$@"
    }

    if restic cat config >/dev/null 2>"$error"; then
      exit 0
    fi

    if ${pkgs.gnugrep}/bin/grep -Eiq \
      '(no such file|does not exist|not found).*(config|repository)|(config|repository).*(no such file|does not exist|not found)' \
      "$error"; then
      restic init
      exit 0
    fi

    ${pkgs.coreutils}/bin/cat "$error" >&2
    exit 1
  '';
in
{
  deployment = {
    targetHost = "eisen";
  };
  nixpkgs.config.permittedInsecurePackages = [
    "pnpm-9.15.9"
  ];
  programs.nix-index-database.comma.enable = true;

  # Pin Fern's ordinary sshd host key because the backup client uses port 2223
  # on Fern's Tailscale address (port 22 is intercepted by Tailscale SSH).
  programs.ssh.knownHosts."fern-restic" = {
    hostNames = [ "[100.120.15.10]:2223" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2UDk/HQF7+2spmQ0b/BFmw8tHAFwku4iUkooPuQXfm";
  };

  imports = [
    nix-index-database.nixosModules.nix-index
    ../../modules/sops.nix
    ./hardware-configuration.nix
    ../../modules/llama-swap-exporter.nix
    ../../modules/systemd-backup-metrics.nix
    ../../modules/tuwunel-admin.nix
    ../../modules/coolify-vm.nix
  ];

  services.backupMetrics = {
    enable = true;
    host = "eisen";
    jobs = {
      forgejo.service = "restic-backups-forgejo";
      matrix.service = "restic-backups-matrix";
      hedgedoc.service = "restic-backups-hedgedoc";
      vaultwarden.service = "restic-backups-vaultwarden";
      karakeep.service = "restic-backups-karakeep";
      uptime-kuma.service = "restic-backups-uptime-kuma";
      grafana.service = "restic-backups-grafana";
      media-indexers.service = "restic-backups-media-indexers";
      hindsight.service = "restic-backups-hindsight";
    };
  };

  services.coolify-vm = {
    enable = true;
    memoryMiB = 3072;
    vcpus = 2;
    cpuQuotaPercent = 150;
    dashboardDomain = "coolify.eisen.danbulant.cloud";
    dashboardListenAddress = tailscaleAddress;
    dashboardPort = privateHttpPort;
    githubWebhookDomain = "coolify-hooks.apps.danbulant.cloud";
    # Eisen terminates public TLS; the VM receives HTTP only.
    domains = [ "*.apps.eisen.danbulant.cloud" "*.apps.danbulant.cloud" "bv.badapple.cz" "www.bv.badapple.cz" ];
    tlsAtUpstream = false;
  };

  # The private Caddy sites bind the Tailscale address instead of a wildcard;
  # order Caddy after the daemon before attempting the listener.
  systemd.services.caddy = {
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
  };

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

    matrix-tuwunel = {
      enable = true;
      settings.global = {
        server_name = matrixServerName;
        port = [ ports.matrix ];
        allow_registration = true;
        oidc_native_auth = true;
        ip_source = "rightmost_x_forwarded_for";
        registration_token_file = "/etc/secrets/matrix-registration-token";
        database_backup_path = "/var/lib/tuwunel/database-backups";
        database_backups_to_keep = 2;
        admin_signal_execute = [ "server backup-database" ];

        well_known = {
          client = "https://${matrixHost}";
          livekit_url = "https://${matrixHost}/livekit/jwt";
        };
      };
    };

    tuwunel-admin = {
      enable = true;
      settings = {
        server.bind = "127.0.0.1:${toString internalPorts.tuwunel-admin}";
        matrix = {
          homeservers = [ "https://${matrixHost}" ];
          allow_any_server = false;
          admin_bot = "@tuwunel:${matrixServerName}";
          admin_room_alias = "#admins:${matrixServerName}";
          device_id = "tuwunel-admin";
          device_display_name = "tuwunel-admin";
        };
      };
    };

    livekit = {
      enable = true;
      keyFile = livekitKeyFile;
      openFirewall = true;
      settings = {
        port = ports.livekit;
        room.auto_create = false;
        rtc = {
          tcp_port = 7881;
          use_external_ip = true;
          port_range_start = 50100;
          port_range_end = 50105;
        };
      };
    };

    lk-jwt-service = {
      enable = true;
      keyFile = livekitKeyFile;
      livekitUrl = "wss://${matrixHost}/livekit/sfu";
      port = internalPorts.livekit-jwt;
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
        DISABLE_NEW_RELEASE_CHECK = "true";
      };
      environmentFile = "/etc/secrets/karakeep.env";
    };


    forgejo = {
      enable = true;
      settings = {
        # Preserve rpi1's instance preferences while using Eisen's storage paths.
        DEFAULT.APP_NAME = "BGit";
        server = {
          DOMAIN = "git.badapple.cz";
          ROOT_URL = "https://git.badapple.cz";
          HTTP_PORT = ports.forgejo;
          OFFLINE_MODE = true;
        };
        service.DISABLE_REGISTRATION = true;
        security.PASSWORD_HASH_ALGO = "pbkdf2_hi";
        federation.ENABLED = true;
        session = {
          PROVIDER = "file";
          PROVIDER_CONFIG = "/var/lib/forgejo/data/sessions";
        };
      };
      lfs.enable = true;
      # Forgejo's ZIP dump rewrites large archives, forcing restic to read
      # them again instead of reusing unchanged files. The backup job below
      # stages a database export, Git mirrors, and persistent files.
      dump.enable = false;
    };

    forgejo-runner.instances.eisen = {
      enable = true;
      settings = {
        runner.labels = [ "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-24.04" ];
        server.connections.default = {
          url = "https://git.badapple.cz";
          # Offline registration token prefix: ffa19dc0216ce2d1.
          uuid = "66666131-3964-6330-3231-366365326431";
        };
      };
      secrets.server.connections.default.token_url = "/etc/secrets/forgejo-runner-token";
    };

    dnsmasq = {
      enable = true;
    };

    hedgedoc = {
      enable = true;
      settings = {
        domain = "doc.danbulant.cloud";
        port = ports.hedgedoc;
        protocolUseSSL = true;
      };
    };

    vaultwarden = {
      enable = true;
      domain = "pw.danbulant.cloud";

      config = {
        ROCKET_ADDRESS = "::1";
        ROCKET_PORT = 8222;
      };
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
      provision = {
        enable = true;
        dashboards.settings.providers = [
          {
            name = "backups";
            options.path = pkgs.writeTextDir "backup-chain-dashboard.json" (
              builtins.readFile ./backup-chain-dashboard.json
            );
          }
        ];
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
          extraFlags = [ "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector" ];
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
          job_name = "node-fern";
          static_configs = [
            {
              targets = [ "100.120.15.10:9000" ];
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
        {
          job_name = "llama-swap";
          static_configs = [
            {
              targets = [ "localhost:${toString internalPorts.prometheus-llama-swap}" ];
            }
          ];
        }
        {
          job_name = "uptime-kuma";
          static_configs = [
            {
              targets = [ "localhost:${toString ports.status}" ];
              # generated, only accessible through tailscale, not really sensitive
            }
          ];
          basic_auth = {
            username = "";
            password = "uk1_SAAatRz9luyFXItVnbXyOdVuU2fkMhZITrnPY27z";
          };
        }
      ];
    };


    glance = {
      enable = true;
      settings = {
        server = {
          port = ports.glance;
        };
        pages = import ./glance-pages.nix;
      };
      environmentFile = "/etc/secrets/glance.env";
    };

    caddy = {
      enable = true;
      # Explicitly include the tailnet socket for ordinary sites too. Caddy
      # otherwise gives the more-specific private bind only the private routes.
      # Private virtualHosts override this default with only tailscaleAddress.
      globalConfig = ''
        default_bind 0.0.0.0 [::] ${tailscaleAddress}
      '';

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

      virtualHosts =
        builtins.listToAttrs (
          map (k: {
            name = "${k}.eisen.danbulant.cloud:80, ${k}.eisen:80";
            value = {
              # import auth
              extraConfig = ''
                reverse_proxy http://localhost:${toString ports.${k}}
              '';
            };
          }) (builtins.attrNames ports)
        )
        // {
          "http://hindsight.eisen.danbulant.cloud:${toString privateHttpPort}" = {
            extraConfig = ''
              bind ${tailscaleAddress}
              reverse_proxy http://localhost:${toString internalPorts.hindsight-ui}
            '';
          };
          "http://hindsight-api.eisen.danbulant.cloud:${toString privateHttpPort}" = {
            extraConfig = ''
              bind ${tailscaleAddress}
              reverse_proxy http://localhost:${toString internalPorts.hindsight-api}
            '';
          };
          "${matrixHost}" = {
            extraConfig = ''
              @matrixClientWellKnown path /.well-known/matrix/client
              handle @matrixClientWellKnown {
                header Access-Control-Allow-Origin "*"
                header Content-Type application/json
                respond `{"m.homeserver":{"base_url":"https://${matrixHost}"},"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://${matrixHost}/livekit/jwt"}]}` 200
              }

              @matrixServerWellKnown path /.well-known/matrix/server
              handle @matrixServerWellKnown {
                header Access-Control-Allow-Origin "*"
                header Content-Type application/json
                respond `{"m.server":"${matrixHost}:443"}` 200
              }

              @jwtService path /livekit/jwt/sfu/get* /livekit/jwt/healthz* /livekit/jwt/get_token*
              handle @jwtService {
                uri strip_prefix /livekit/jwt
                reverse_proxy http://localhost:${toString internalPorts.livekit-jwt}
              }

              @livekit path /livekit/sfu*
              handle @livekit {
                uri strip_prefix /livekit/sfu
                reverse_proxy http://localhost:${toString ports.livekit}
              }

              handle {
                reverse_proxy http://localhost:${toString ports.matrix}
              }
            '';
          };
          "admin.${matrixHost}" = {
            extraConfig = ''
              reverse_proxy http://localhost:${toString internalPorts.tuwunel-admin}
            '';
          };
          "sable.badapple.cz" = {
            extraConfig = ''
              reverse_proxy http://localhost:${toString ports.sable}
            '';
          };
          "doc.danbulant.cloud" = {
            extraConfig = ''
              reverse_proxy http://localhost:${toString ports.hedgedoc} {
                # TLS terminates at the upstream Cloudflare/Traefik proxies;
                # HedgeDoc still needs the public scheme for secure cookies.
                header_up X-Forwarded-Proto https
              }
            '';
          };
          "photos.badapple.cz" = {
            extraConfig = ''reverse_proxy http://fern'';
          };
          "git.badapple.cz" = {
            extraConfig = ''reverse_proxy http://localhost:${toString ports.forgejo}'';
          };
          "pw.danbulant.cloud" = {
            extraConfig = ''
              reverse_proxy http://localhost:${toString ports.vaultwarden}
            '';
          };
        };
    };
    tailscale.permitCertUid = "caddy";
    tailscaleAuth = {
      # this is what's used above in forward_auth
      enable = true;
      group = "caddy";
    };
  };
  systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = matrixServerName;

  systemd.services.livekit-keys = {
    description = "Generate the shared LiveKit API key";
    before = [
      "livekit.service"
      "lk-jwt-service.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "livekit";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
    script = ''
      if [[ ! -s "$STATE_DIRECTORY/keys" ]]; then
        key="$(${lib.getExe pkgs.openssl} rand -base64 48)"
        printf 'lk-jwt-service: %s\n' "$key" > "$STATE_DIRECTORY/keys"
      fi
    '';
  };
  systemd.services.livekit = {
    requires = [ "livekit-keys.service" ];
    after = [ "livekit-keys.service" ];
  };
  systemd.services.lk-jwt-service = {
    requires = [ "livekit-keys.service" ];
    after = [ "livekit-keys.service" ];
  };

  # Keep any previously generated Forgejo dump timer disabled.
  systemd.timers.forgejo-dump.enable = false;

  # Stop creating large, repeatedly rewritten Forgejo ZIP dumps.
  # Existing archives remain untouched for historical restore use.
  # This is a live, incremental backup. SQLite gets an online-consistent
  # snapshot and repositories use Git transport; files are not one global
  # point-in-time image, so a concurrent push/upload can cross the snapshots.
  # Restic jobs back up the staged tree and retain each tag independently.
  services.restic.backups =
    {
      forgejo = resticDefaults // {
        # The stage persists between runs so Git mirrors and restic deduplicate
        # unchanged repository objects.
        paths = [ "/var/lib/forgejo-backup" ];
        extraBackupArgs = [
          "--tag=forgejo"
          "--retry-lock=30m"
        ];
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077

          git=${lib.getExe pkgs.git}
          rsync=${lib.getExe pkgs.rsync}
          sqlite=${lib.getExe pkgs.sqlite}
          source=/var/lib/forgejo
          staging=/var/lib/forgejo-backup
          db_tmp="$staging/data/forgejo.db.tmp"
          repo_list=/run/restic-backups-forgejo/repositories

          # Keep credentials private. The staging directory is owned by this
          # job and is never used as a source for the live Forgejo service.
          ${pkgs.coreutils}/bin/install -d -o root -g root -m 0700 "$staging"
          ${pkgs.coreutils}/bin/install -d -m 0700 \
            "$staging/data" "$staging/custom" "$staging/repositories"
          cleanup() {
            ${pkgs.coreutils}/bin/rm -f "$db_tmp"
          }
          trap cleanup EXIT
          trap 'exit 143' HUP INT TERM
          ${pkgs.coreutils}/bin/rm -f "$db_tmp"

          # SQLite's online backup API produces a consistent live snapshot;
          # rename it only after the backup completes.
          "$sqlite" -readonly "$source/data/forgejo.db" ".backup $db_tmp"
          ${pkgs.coreutils}/bin/chmod 0600 "$db_tmp"
          ${pkgs.coreutils}/bin/mv -f "$db_tmp" "$staging/data/forgejo.db"

          # Forgejo's bare repositories are mirrored through Git's transport,
          # not copied with hardlinks or a live recursive filesystem copy.
          ${pkgs.findutils}/bin/find "$source/repositories" \
            -type d -name '*.git' -prune -print0 > "$repo_list"
          while IFS= read -r -d "" repo; do
            relative="''${repo#"$source/repositories/"}"
            destination="$staging/repositories/$relative"
            ${pkgs.coreutils}/bin/install -d -m 0700 "''${destination%/*}"
            # Forgejo can leave hook-only directories without a Git
            # repository. Preserve their files instead of trying to clone.
            if [ ! -e "$repo/HEAD" ] && [ ! -d "$repo/objects" ]; then
              "$rsync" --archive --no-owner --no-group --delete "$repo/" "$destination/"
              continue
            fi
            if [ -d "$destination/objects" ]; then
              "$git" -C "$destination" \
                -c core.hooksPath=/dev/null \
                -c "safe.directory=$repo" \
                -c protocol.file.allow=always \
                -c gc.autoDetach=false \
                fetch --no-auto-maintenance --prune origin
            else
              clone_tmp="$destination.tmp"
              ${pkgs.coreutils}/bin/rm -rf "$clone_tmp"
              "$git" \
                -c core.hooksPath=/dev/null \
                -c "safe.directory=$repo" \
                -c protocol.file.allow=always \
                clone --mirror --no-local "$repo" "$clone_tmp"
              ${pkgs.coreutils}/bin/rm -rf "$destination"
              ${pkgs.coreutils}/bin/mv -f "$clone_tmp" "$destination"
            fi
            "$git" -C "$destination" \
              -c core.hooksPath=/dev/null \
              -c "safe.directory=$repo" \
              -c gc.autoDetach=false \
              gc --auto
            if [ -f "$repo/HEAD" ]; then
              "$rsync" --archive "$repo/HEAD" "$destination/HEAD"
            fi
            # Preserve repository-local hooks and other non-object files.
            # Keep the source config separately: replacing the mirror config
            # would destroy its fetch settings.
            # On restore, copy these saved configs onto the restored mirrors.
            "$rsync" --archive --no-owner --no-group --delete \
              --exclude='/objects/' --exclude='/refs/' --exclude='/logs/' \
              --exclude='/HEAD' --exclude='/packed-refs' --exclude='/config' \
              --exclude='/FETCH_HEAD' --exclude='/ORIG_HEAD' \
              "$repo/" "$destination/"
            config_dir="$staging/repository-configs/$relative"
            ${pkgs.coreutils}/bin/install -d -m 0700 "$config_dir"
            if [ -f "$repo/config" ]; then
              "$rsync" --archive "$repo/config" "$config_dir/config"
            else
              ${pkgs.coreutils}/bin/rm -f "$config_dir/config"
            fi
          done < "$repo_list"

          # Remove only mirrors and interrupted clone directories owned by the
          # staging job when their source repository no longer exists.
          ${pkgs.findutils}/bin/find "$staging/repositories" \
            -type d -name '*.git' -prune -print0 > "$repo_list"
          while IFS= read -r -d "" mirror; do
            relative="''${mirror#"$staging/repositories/"}"
            if [ ! -d "$source/repositories/$relative" ]; then
              ${pkgs.coreutils}/bin/rm -rf "$mirror"
              ${pkgs.coreutils}/bin/rm -rf "$staging/repository-configs/$relative"
            fi
          done < "$repo_list"
          ${pkgs.findutils}/bin/find "$staging/repositories" \
            -type d -name '*.git.tmp' -prune \
            -exec ${pkgs.coreutils}/bin/rm -rf -- {} +

          # Keep persistent storage, queues, and action data. Issue/repository
          # indexers and temporary files are regenerable and are omitted.
          ${pkgs.coreutils}/bin/rm -rf \
            "$staging/data/indexers" "$staging/data/tmp"
          "$rsync" --archive --delete \
            --exclude='forgejo.db*' \
            --exclude='indexers/' \
            --exclude='tmp/' \
            "$source/data/" "$staging/data/"
          "$rsync" --archive --delete \
            "$source/custom/" "$staging/custom/"
        '';
        timerConfig = {
          OnCalendar = "*-*-* 09,12,15,18,21:00:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
      };

      matrix = resticDefaults // {
        paths = [
          "/var/lib/tuwunel/database-backups"
          "/var/lib/tuwunel/media"
          "/var/lib/livekit/keys"
          "/etc/secrets/matrix-registration-token"
        ];
        extraBackupArgs = [ "--tag=matrix" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 09,12,15,18,21:00:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu

          backup_meta=/var/lib/tuwunel/database-backups/meta
          before="$(${pkgs.findutils}/bin/find "$backup_meta" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | ${pkgs.coreutils}/bin/sort || true)"

          ${lib.getExe' pkgs.systemd "systemctl"} kill --kill-whom=main --signal=SIGUSR2 tuwunel.service

          # RocksDB writes the metadata file only after an online backup is complete.
          for ((attempt = 0; attempt < 120; attempt++)); do
            after="$(${pkgs.findutils}/bin/find "$backup_meta" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | ${pkgs.coreutils}/bin/sort || true)"
            if [[ -n "$after" && "$after" != "$before" ]]; then
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 5
          done

          echo "Timed out waiting for Tuwunel's online database backup" >&2
          exit 1
        '';
      };

      hedgedoc = resticDefaults // {
        # HedgeDoc currently uses SQLite. .dump is a transactional logical
        # export; uploads are immutable files and are copied separately.
        dynamicFilesFrom = ''
          printf '%s\n' /run/restic-backups-hedgedoc/hedgedoc.sql /var/lib/hedgedoc/uploads
        '';
        extraBackupArgs = [ "--tag=hedgedoc" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 05:30:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-hedgedoc
          ${lib.getExe pkgs.sqlite} -readonly -bail /var/lib/hedgedoc/db.sqlite .dump \
            > /run/restic-backups-hedgedoc/hedgedoc.sql
        '';
        backupCleanupCommand = ''
          ${pkgs.coreutils}/bin/rm -f /run/restic-backups-hedgedoc/hedgedoc.sql
        '';
      };

      vaultwarden = resticDefaults // {
        # Keep the database logical and include user attachments. The
        # attachments directory is optional on this installation.
        dynamicFilesFrom = ''
          printf '%s\n' \
            /run/restic-backups-vaultwarden/vaultwarden.sql \
            /var/lib/vaultwarden/rsa_key.pem
          if [ -d /var/lib/vaultwarden/attachments ]; then
            printf '%s\n' /var/lib/vaultwarden/attachments
          fi
        '';
        extraBackupArgs = [ "--tag=vaultwarden" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 06:00:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-vaultwarden
          ${lib.getExe pkgs.sqlite} -readonly -bail /var/lib/vaultwarden/db.sqlite3 .dump \
            > /run/restic-backups-vaultwarden/vaultwarden.sql
        '';
        backupCleanupCommand = ''
          ${pkgs.coreutils}/bin/rm -f /run/restic-backups-vaultwarden/vaultwarden.sql
        '';
      };

      karakeep = resticDefaults // {
        dynamicFilesFrom = ''
          printf '%s\n' \
            /run/restic-backups-karakeep \
            /var/lib/karakeep/assets \
            /var/lib/karakeep/settings.env
        '';
        extraBackupArgs = [ "--tag=karakeep" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 06:30:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-karakeep
          ${lib.getExe pkgs.sqlite} -readonly -bail /var/lib/karakeep/db.db .dump \
            > /run/restic-backups-karakeep/db.sql
          ${lib.getExe pkgs.sqlite} -readonly -bail /var/lib/karakeep/queue.db .dump \
            > /run/restic-backups-karakeep/queue.sql
        '';
      };

      uptime-kuma = resticDefaults // {
        dynamicFilesFrom = ''
          printf '%s\n' \
            /run/restic-backups-uptime-kuma \
            /var/lib/private/uptime-kuma/upload \
            /var/lib/private/uptime-kuma/screenshots \
            /var/lib/private/uptime-kuma/db-config.json
        '';
        extraBackupArgs = [ "--tag=uptime-kuma" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 07:00:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-uptime-kuma
          ${lib.getExe pkgs.sqlite} -readonly -bail /var/lib/private/uptime-kuma/kuma.db .dump \
            > /run/restic-backups-uptime-kuma/kuma.sql
        '';
      };

      grafana = resticDefaults // {
        dynamicFilesFrom = ''
          printf '%s\n' \
            /run/restic-backups-grafana \
            /etc/secrets/gf_secret_key
        '';
        extraBackupArgs = [ "--tag=grafana" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 07:30:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-grafana
          ${lib.getExe pkgs.sqlite} -readonly -bail /var/lib/grafana/data/grafana.db .dump \
            > /run/restic-backups-grafana/grafana.sql
        '';
      };

      # Sonarr, Radarr and Prowlarr store their indexes in SQLite. Keep the
      # small XML settings (including API keys), but never copy live databases.
      media-indexers = resticDefaults // {
        dynamicFilesFrom = ''
          printf '%s\n' /run/restic-backups-media-indexers
          for path in \
            /var/lib/sonarr/.config/NzbDrone/config.xml \
            /var/lib/radarr/.config/Radarr/config.xml \
            /var/lib/private/prowlarr/config.xml; do
            if [ -e "$path" ]; then
              printf '%s\n' "$path"
            fi
          done
        '';
        extraBackupArgs = [ "--tag=media-indexers" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 08:00:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-media-indexers
          for spec in \
            "/var/lib/sonarr/.config/NzbDrone/sonarr.db:sonarr.sql" \
            "/var/lib/sonarr/.config/NzbDrone/logs.db:sonarr-logs.sql" \
            "/var/lib/radarr/.config/Radarr/radarr.db:radarr.sql" \
            "/var/lib/radarr/.config/Radarr/logs.db:radarr-logs.sql" \
            "/var/lib/private/prowlarr/prowlarr.db:prowlarr.sql" \
            "/var/lib/private/prowlarr/logs.db:prowlarr-logs.sql"; do
            source="''${spec%%:*}"
            destination="''${spec##*:}"
            if [ -f "$source" ]; then
              ${lib.getExe pkgs.sqlite} -readonly -bail "$source" .dump \
                > "/run/restic-backups-media-indexers/$destination"
            fi
          done
        '';
      };

      hindsight = resticDefaults // {
        # Hindsight ships an embedded PostgreSQL server in its container.
        # Dump it through pg_dump rather than copying the Docker volume.
        dynamicFilesFrom = ''
          printf '%s\n' /run/restic-backups-hindsight/hindsight.sql
        '';
        extraBackupArgs = [ "--tag=hindsight" "--retry-lock=30m" ];
        timerConfig = {
          OnCalendar = "*-*-* 08:30:00";
          Persistent = true;
          RandomizedDelaySec = "20m";
        };
        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -eu
          umask 077
          ${pkgs.coreutils}/bin/install -d -m 0700 /run/restic-backups-hindsight
          ${lib.getExe pkgs.docker} exec -e PGPASSWORD=hindsight hindsight \
            /home/hindsight/.pg0/installation/18.1.0/bin/pg_dump \
            -h 127.0.0.1 -p 5432 -U hindsight -d hindsight \
            > /run/restic-backups-hindsight/hindsight.sql
        '';
      };
    };
  systemd.services.restic-repository-init = {
    description = "Initialize the shared Eisen restic repository";
    wantedBy = [ "multi-user.target" ];
    before = resticBackupServices;
    environment.RESTIC_REPOSITORY = resticRepository;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = toString resticEnvironmentFile;
      ExecStart = resticRepositoryInit;
    };
  };



  # A sleeping Fern is normal. Retry failed jobs without overlapping timer
  # runs, and abandon dead SSH connections after twelve hours.
  systemd.services.restic-backups-forgejo.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-matrix.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-hedgedoc.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-vaultwarden.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-karakeep.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-uptime-kuma.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-grafana.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-media-indexers.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-hindsight.serviceConfig = resticServiceConfig;
  systemd.services.restic-backups-forgejo.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-forgejo.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-matrix.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-matrix.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-hedgedoc.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-hedgedoc.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-vaultwarden.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-vaultwarden.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-karakeep.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-karakeep.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-uptime-kuma.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-uptime-kuma.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-grafana.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-grafana.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-media-indexers.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-media-indexers.after = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-hindsight.requires = [ "restic-repository-init.service" ];
  systemd.services.restic-backups-hindsight.after = [ "restic-repository-init.service" ];

  systemd.services.docker-hindsight = {
    serviceConfig = {
      LoadCredential = "openrouter-key:/etc/secrets/hindsight-or";
      RuntimeDirectory = "hindsight";
      RuntimeDirectoryMode = "0700";
    };
    # The source is a raw key, not an environment file. Convert it only at
    # startup, outside the Nix store, and never include its value in tracing.
    preStart = lib.mkBefore ''
      set +x
      umask 077
      printf 'HINDSIGHT_API_LLM_API_KEY=%s\n' "$(< "$CREDENTIALS_DIRECTORY/openrouter-key")" \
        > /run/hindsight/environment
    '';
  };


  # LiveKit's TCP ICE fallback is separate from its HTTP/WebSocket port.
  networking.firewall.allowedTCPPorts = [ 7881 80 443 ];

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
    };

    oci-containers = {
      backend = "docker";
      containers = {
        hindsight = {
          image = "ghcr.io/vectorize-io/hindsight:0.10.2";
          autoStart = true;
          # Docker stays loopback-only; Caddy publishes these only on Tailscale.
          # No authentication is configured, so do not add a public listener.
          ports = [
            "127.0.0.1:${toString internalPorts.hindsight-api}:8888"
            "127.0.0.1:${toString internalPorts.hindsight-ui}:9999"
          ];
          environmentFiles = [ "/run/hindsight/environment" ];
          environment = {
            HINDSIGHT_API_LLM_PROVIDER = "openrouter";
            HINDSIGHT_API_LLM_MODEL = "openai/gpt-6-luna";
            # Normalize facts, observations, and reflect output, even for multilingual input.
            HINDSIGHT_API_LLM_OUTPUT_LANGUAGE = "English";
            HINDSIGHT_API_RETAIN_EXTRACTION_MODE = "concise";
            HINDSIGHT_API_ENABLE_OBSERVATIONS = "true";
            HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION = "true";
            # Bound background traffic and reflect work; spending is capped
            # separately on the dedicated OpenRouter key.
            HINDSIGHT_API_LLM_MAX_CONCURRENT = "4";
            HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT = "2";
            HINDSIGHT_API_CONSOLIDATION_LLM_MAX_CONCURRENT = "1";
            HINDSIGHT_API_LLM_MAX_RETRIES = "2";
            HINDSIGHT_API_REFLECT_MAX_ITERATIONS = "6";
            HINDSIGHT_API_REFLECT_MAX_CONTEXT_TOKENS = "24000";
            HINDSIGHT_API_EMBEDDINGS_PROVIDER = "local";
            HINDSIGHT_API_EMBEDDINGS_LOCAL_MODEL = "BAAI/bge-small-en-v1.5";
            HINDSIGHT_API_EMBEDDINGS_LOCAL_FORCE_CPU = "true";
            HINDSIGHT_API_RERANKER_PROVIDER = "local";
            HINDSIGHT_API_RERANKER_LOCAL_FORCE_CPU = "true";
            HINDSIGHT_API_WORKER_ID = "eisen-hindsight";
          };
          # The all-in-one image runs embedded PostgreSQL as UID 1000.
          # Named volumes preserve its ownership and data across container replacement.
          volumes = [
            "hindsight-data:/home/hindsight/.pg0"
          ];
          extraOptions = [ "--shm-size=1g" ];
        };

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
          environment = {
            VPN_PORT_FORWARDING = "on";
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
        };

        sable = {
          image = "ghcr.io/sableclient/sable:latest";
          ports = [
            "127.0.0.1:${toString ports.sable}:8080"
          ];
        };
      };
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "kvm-intel" ];
    # Shortcuts for fixing things
    # alt+sysrq (prtsc) + key
    # h: Print help to the system log.
    # f: Trigger the kernel oom killer.
    # s: Sync data to disk before triggering the reset options below.
    # e: SIGTERM all processes except PID 0.
    # i: SIGKILL all processes except PID 0.
    # b: Reboot the system.
    kernel.sysctl."kernel.sysrq" = 1;

    swraid.enable = false;

    initrd.systemd.enable = true;

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
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

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      intel-ocl
      libva-vdpau-driver
      # This Gen8-capable release predates GCC 16's incomplete-SFINAE checks.
      (intel-compute-runtime-legacy1.override { stdenv = gcc15Stdenv; })
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  environment.systemPackages = with pkgs; [
    forgejo
    bun
    jellyfin-ffmpeg
    intel-gpu-tools
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
