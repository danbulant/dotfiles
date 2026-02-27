{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.virtualisation.sysbox;
in

{
  options.virtualisation.sysbox = {
    enable = lib.mkEnableOption "Sysbox, a next-generation runc for running system containers";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The sysbox package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.sysbox.package = lib.mkDefault pkgs.sysbox;

    # Configure Docker to use sysbox-runc runtime
    virtualisation.docker.daemon.settings = lib.mkIf config.virtualisation.docker.enable {
      runtimes.sysbox-runc = {
        path = "${cfg.package}/bin/sysbox-runc";
      };
    };

    # Configure Podman to use sysbox-runc runtime
    virtualisation.containers.containersConf.settings = lib.mkIf config.virtualisation.podman.enable {
      engine.runtimes.sysbox-runc = [
        "${cfg.package}/bin/sysbox-runc"
      ];
    };

    systemd.services.sysbox-mgr = {
      description = "Sysbox Manager Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      path = with pkgs; [
        rsync
        kmod
        iptables
      ];

      serviceConfig = {
        Type = "notify";
        ExecStart = "${cfg.package}/bin/sysbox-mgr";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "root";
        Group = "root";
      };

      preStart = ''
        # Ensure iptables is available in /sbin for sysbox compatibility
        mkdir -p /sbin
        for cmd in ${pkgs.iptables}/bin/iptables*; do
          ln -sf "$cmd" "/sbin/$(basename $cmd)" || true
        done
      '';
    };

    systemd.services.sysbox-fs = {
      description = "Sysbox FileSystem Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "sysbox-mgr.service" ];
      requires = [ "sysbox-mgr.service" ];

      path = with pkgs; [
        rsync
        kmod
        fuse
        iptables
      ];

      serviceConfig = {
        Type = "notify";
        ExecStart = "${cfg.package}/bin/sysbox-fs";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "root";
        Group = "root";
      };
    };

    # Enable unprivileged user namespace cloning (required for sysbox)
    security.unprivilegedUsernsClone = true;

    # Apply sysctl configuration (sysbox requires higher values than system defaults)
    boot.kernel.sysctl = {
      "fs.inotify.max_queued_events" = lib.mkOverride 999 1048576;
      "fs.inotify.max_user_watches" = lib.mkOverride 999 1048576;
      "fs.inotify.max_user_instances" = lib.mkOverride 999 1048576;
      "kernel.keys.maxkeys" = lib.mkOverride 999 20000;
      "kernel.keys.maxbytes" = lib.mkOverride 999 400000;
    };

    # Make sysbox-runc available in PATH for container runtimes
    environment.systemPackages = [ cfg.package ];
  };
}
