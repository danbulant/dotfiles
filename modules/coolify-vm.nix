{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.coolify-vm;
  inherit (lib)
    escapeShellArg
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  guestCloudConfig = import ./coolify-vm-guest.nix;
  cloudConfig = pkgs.writeText "coolify-vm-cloud-config.json" (
    builtins.toJSON (guestCloudConfig { inherit cfg lib; })
  );
  debianImage = pkgs.fetchurl {
    url = "https://cloud.debian.org/images/cloud/bookworm/20260923-2610/debian-12-genericcloud-amd64-20260923-2610.qcow2";
    hash = "sha512-PZTJ3WbYooP94GC4gQNzt64EA4uVbuANVT0a5WT2+96qL9bnQE6H5TNItalQkXDz6nwHMbpzdZDFxMuNVZpH+A==";
  };
  qemu = lib.getExe' pkgs.qemu "qemu-system-x86_64";
  qemuImg = lib.getExe' pkgs.qemu "qemu-img";
  socat = lib.getExe' pkgs.socat "socat";
  jq = lib.getExe' pkgs.jq "jq";
  sshKeygen = lib.getExe' pkgs.openssh "ssh-keygen";
  xorriso = lib.getExe' pkgs.xorriso "xorriso";
  cat = lib.getExe' pkgs.coreutils "cat";
  chmod = lib.getExe' pkgs.coreutils "chmod";
  cp = lib.getExe' pkgs.coreutils "cp";
  mkdir = lib.getExe' pkgs.coreutils "mkdir";
  mv = lib.getExe' pkgs.coreutils "mv";
  rm = lib.getExe' pkgs.coreutils "rm";
  sha256sum = lib.getExe' pkgs.coreutils "sha256sum";
  cmp = lib.getExe' pkgs.diffutils "cmp";
  sleep = lib.getExe' pkgs.coreutils "sleep";
  seq = lib.getExe' pkgs.coreutils "seq";
  hostForwarding = lib.concatStringsSep "," [
    "user"
    "model=virtio-net-pci"
    "hostfwd=tcp:127.0.0.1:${toString cfg.hostPorts.http}-:80"
    "hostfwd=tcp:127.0.0.1:${toString cfg.hostPorts.ssh}-:22"
    "hostfwd=tcp:127.0.0.1:${toString cfg.hostPorts.dashboard}-:8000"
    "hostfwd=tcp:127.0.0.1:${toString cfg.hostPorts.realtime}-:6001"
    "hostfwd=tcp:127.0.0.1:${toString cfg.hostPorts.terminal}-:6002"
  ];
in
{
  options.services.coolify-vm = {
    enable = mkEnableOption "the isolated Coolify Debian VM";

    dashboardDomain = mkOption {
      type = types.str;
      default = "coolify.eisen.danbulant.cloud";
      description = "Hostname for the private HTTP Coolify dashboard.";
    };

    adminEmail = mkOption {
      type = types.str;
      default = "dan@danbulant.cloud";
      description = "Initial Coolify administrator email address.";
    };

    adminName = mkOption {
      type = types.str;
      default = "dan";
      description = "Initial Coolify administrator name.";
    };

    memoryMiB = mkOption {
      type = types.ints.positive;
      default = 3072;
      description = "Guest memory in MiB.";
    };

    vcpus = mkOption {
      type = types.ints.positive;
      default = 2;
      description = "Number of virtual CPUs presented to the guest.";
    };

    cpuQuotaPercent = mkOption {
      type = types.ints.positive;
      default = 150;
      description = "Maximum host CPU percentage allowed for the VM service.";
    };

    diskSizeGiB = mkOption {
      type = types.ints.positive;
      default = 64;
      description = "Persistent guest root disk size in GiB.";
    };

    hostPorts = mkOption {
      type = types.submodule ({ ... }: {
        options = {
          http = mkOption {
            type = types.port;
            default = 18080;
            description = "Loopback host port forwarded to guest HTTP.";
          };
          ssh = mkOption {
            type = types.port;
            default = 2223;
            description = "Loopback host port forwarded to guest SSH.";
          };
          dashboard = mkOption {
            type = types.port;
            default = 18000;
            description = "Loopback host port forwarded to Coolify's dashboard.";
          };
          realtime = mkOption {
            type = types.port;
            default = 16001;
            description = "Loopback host port forwarded to Coolify realtime.";
          };
          terminal = mkOption {
            type = types.port;
            default = 16002;
            description = "Loopback host port forwarded to Coolify terminal.";
          };
        };
      });
      default = { };
      description = "Loopback-only host ports forwarded into the guest.";
    };

    domains = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Bare hostnames or wildcard hostname patterns routed to Coolify HTTP.";
    };
  };

  imports = [ ./coolify-vm-proxy.nix ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.match "^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$" cfg.dashboardDomain != null;
        message = "services.coolify-vm.dashboardDomain must be a bare hostname without a wildcard, scheme, port, or path";
      }
      {
        assertion = lib.all (
          domain:
          builtins.match "^(\\*\\.)?[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$" domain
          != null
        ) cfg.domains;
        message = "services.coolify-vm.domains must contain bare hostnames or *.hostname patterns";
      }
      {
        assertion = lib.length (lib.unique cfg.domains) == lib.length cfg.domains;
        message = "services.coolify-vm.domains must not contain duplicate hostnames";
      }
      {
        assertion =
          let
            ports = with cfg.hostPorts; [
              http
              ssh
              dashboard
              realtime
              terminal
            ];
          in
          lib.length (lib.unique ports) == lib.length ports;
        message = "services.coolify-vm.hostPorts must be unique";
      }
    ];
    users.groups."coolify-vm" = { };
    users.groups.kvm = { };
    users.users."coolify-vm" = {
      isSystemUser = true;
      group = "coolify-vm";
      extraGroups = [ "kvm" ];
      description = "Coolify VM runtime user";
    };

    systemd.services.coolify-vm = {
      description = "Isolated Coolify VM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/dev/kvm";
      path = [
        pkgs.coreutils
        pkgs.jq
        pkgs.openssh
        pkgs.qemu
        pkgs.socat
        pkgs.xorriso
      ];
      script = ''
        set -euo pipefail

        state=/var/lib/coolify-vm
        disk="$state/root.qcow2"
        seed="$state/seed.iso"
        private_key="$state/id_ed25519"
        public_key="$state/id_ed25519.pub"

        if [[ ! -e "$private_key" ]]; then
          umask 077
          # The installer removes authorized_keys entries containing "coolify".
          # Keep the independent VM management key outside its key namespace.
          ${sshKeygen} -q -t ed25519 -N "" -f "$private_key" -C vm-management
        fi

        # The base image and resize operation are only performed on first use.
        # Build a temporary file so an interrupted copy cannot become the disk.
        if [[ ! -e "$disk" ]]; then
          temporary_disk="$state/root.qcow2.tmp.$$"
          trap '${rm} -f -- "$temporary_disk"' EXIT
          ${cp} --reflink=auto -- ${escapeShellArg debianImage} "$temporary_disk"
          ${chmod} 0600 "$temporary_disk"
          ${qemuImg} resize "$temporary_disk" ${toString cfg.diskSizeGiB}G
          ${mv} -T -- "$temporary_disk" "$disk"
          trap - EXIT
        fi

        # Regenerate the seed when the declarative cloud config changes, but
        # leave the persistent root disk untouched.  The instance-id includes
        # the generated user-data hash so cloud-init sees a new first boot.
        key="$(${cat} "$public_key")"
        temporary_user_data="$state/user-data.tmp.$$"
        temporary_meta_data="$state/meta-data.tmp.$$"
        temporary_seed="$state/seed.iso.tmp.$$"
        temporary_seed_dir="$state/seed-dir.$$"
        trap '${rm} -rf -- "$temporary_user_data" "$temporary_meta_data" "$temporary_seed" "$temporary_seed_dir"' EXIT

        {
          printf '%s\n' '#cloud-config'
          ${jq} --arg key "$key" '
            .users = ((.users // [])
              | if any(.[]; .name == "root")
                then map(if .name == "root" then .ssh_authorized_keys = [$key] else . end)
                else . + [{name: "root", lock_passwd: true, ssh_authorized_keys: [$key]}]
                end)
          ' ${cloudConfig}
        } > "$temporary_user_data"
        ${chmod} 0600 "$temporary_user_data"

        if [[ ! -e "$seed" || ! -e "$state/user-data" || ! -e "$state/meta-data" ]] ||
          ! ${cmp} -s "$temporary_user_data" "$state/user-data"; then
          instance_hash="$(${sha256sum} "$temporary_user_data" | cut -d ' ' -f 1)"
          printf '%s\n' \
            "instance-id: coolify-vm-$instance_hash" \
            'local-hostname: coolify-vm' > "$temporary_meta_data"
          ${chmod} 0600 "$temporary_meta_data"

          ${mkdir} -m 0700 "$temporary_seed_dir"
          ${cp} "$temporary_user_data" "$temporary_seed_dir/user-data"
          ${cp} "$temporary_meta_data" "$temporary_seed_dir/meta-data"
          ${xorriso} -as mkisofs -quiet -output "$temporary_seed" -volid cidata \
            "$temporary_seed_dir/user-data" "$temporary_seed_dir/meta-data"
          ${chmod} 0600 "$temporary_seed"

          ${mv} -T -- "$temporary_user_data" "$state/user-data"
          ${mv} -T -- "$temporary_meta_data" "$state/meta-data"
          ${mv} -T -- "$temporary_seed" "$seed"
        else
          ${rm} -f -- "$temporary_user_data"
        fi
        ${rm} -rf -- "$temporary_seed_dir"
        trap - EXIT

        exec ${qemu} \
          -name coolify-vm \
          -machine q35,accel=kvm \
          -cpu host \
          -smp ${toString cfg.vcpus} \
          -m ${toString cfg.memoryMiB} \
          -drive "file=$disk,if=virtio,format=qcow2,cache=none,discard=unmap" \
          -drive "file=$seed,if=virtio,format=raw,readonly=on" \
          -nic ${escapeShellArg hostForwarding} \
          -device virtio-rng-pci \
          -display none \
          -serial stdio \
          -monitor unix:"$RUNTIME_DIRECTORY/monitor.sock",server=on,wait=off \
          -boot order=c \
          -rtc base=utc,clock=host
      '';
      preStop = ''
        if [[ -S "$RUNTIME_DIRECTORY/monitor.sock" ]]; then
          printf 'system_powerdown\n' | ${socat} - UNIX-CONNECT:"$RUNTIME_DIRECTORY/monitor.sock" || true
        fi

        for _ in $(${seq} 1 60); do
          kill -0 "$MAINPID" 2>/dev/null || exit 0
          ${sleep} 1
        done
      '';
      serviceConfig = {
        User = "coolify-vm";
        Group = "kvm";
        SupplementaryGroups = [ "coolify-vm" ];
        StateDirectory = "coolify-vm";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "coolify-vm";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        CPUQuota = "${toString cfg.cpuQuotaPercent}%";
        MemoryAccounting = true;
        MemoryMax = "${toString (cfg.memoryMiB + 512)}M";
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
        ReadWritePaths = [ "/var/lib/coolify-vm" ];
        DeviceAllow = [ "/dev/kvm rw" ];
        PrivateDevices = false;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
      };
    };
  };
}
