{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.backupMetrics;

  jobType = types.submodule ({ name, ... }:
    {
      options.service = mkOption {
        type = types.str;
        default = "restic-backups-${name}";
        description = "Systemd service name (without the .service suffix) for this backup.";
      };
    });

  serviceName = name: removeSuffix ".service" cfg.jobs.${name}.service;
  jobNames = attrNames cfg.jobs;
  serviceNames = map serviceName jobNames;
  stateFile = name: "${cfg.stateDirectory}/${name}";
  statusFile = name: "${stateFile name}.status";
  runningFile = name: "${stateFile name}.running";
  lastSuccessFile = name: "${stateFile name}.last-success";
  lastAttemptFile = name: "${stateFile name}.last-attempt";

  writeAttempt = name: pkgs.writeShellScript "backup-metrics-${name}-attempt" ''
    set -eu
    running=${escapeShellArg (runningFile name)}
    attempt=${escapeShellArg (lastAttemptFile name)}
    now="$(${pkgs.coreutils}/bin/date +%s)"

    temporary="$attempt.tmp.$$"
    printf '%s\n' "$now" > "$temporary"
    ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$attempt"

    temporary="$running.tmp.$$"
    : > "$temporary"
    ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$running"
  '';

  writeSuccess = name: pkgs.writeShellScript "backup-metrics-${name}-success" ''
    set -eu
    state=${escapeShellArg (statusFile name)}
    running=${escapeShellArg (runningFile name)}
    success=${escapeShellArg (lastSuccessFile name)}
    now="$(${pkgs.coreutils}/bin/date +%s)"

    temporary="$success.tmp.$$"
    printf '%s\n' "$now" > "$temporary"
    ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$success"

    temporary="$state.tmp.$$"
    printf '%s\n' success > "$temporary"
    ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$state"
    ${pkgs.coreutils}/bin/rm -f "$running"
  '';

  markFailure = name: pkgs.writeShellScript "backup-metrics-${name}-failure" ''
    set -eu
    state=${escapeShellArg (statusFile name)}
    running=${escapeShellArg (runningFile name)}

    if [ "''${SERVICE_RESULT:-}" != success ]; then
      temporary="$state.tmp.$$"
      printf '%s\n' failed > "$temporary"
      ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
      ${pkgs.coreutils}/bin/mv -f "$temporary" "$state"
      ${pkgs.coreutils}/bin/rm -f "$running"
    fi
  '';

  metricBlocks = concatStringsSep "\n" (map
    (name:
      let
        unit = "${serviceName name}.service";
      in
      ''
        backup=${escapeShellArg name}
        unit=${escapeShellArg unit}
        state_file=${escapeShellArg (statusFile name)}
        running_file=${escapeShellArg (runningFile name)}
        success_file=${escapeShellArg (lastSuccessFile name)}
        attempt_file=${escapeShellArg (lastAttemptFile name)}

        active_state="$(${pkgs.systemd}/bin/systemctl show "$unit" --property=ActiveState --value 2>/dev/null || true)"
        sub_state="$(${pkgs.systemd}/bin/systemctl show "$unit" --property=SubState --value 2>/dev/null || true)"
        status=""
        if [ -r "$state_file" ]; then
          status="$(${pkgs.coreutils}/bin/cat "$state_file" 2>/dev/null || true)"
        fi

        running=0
        case "$active_state" in
          activating)
            if [ "$sub_state" != auto-restart ]; then
              running=1
            fi
            ;;
          deactivating|reloading)
            running=1
            ;;
          active)
            if [ "$sub_state" != exited ] && [ "$sub_state" != dead ]; then
              running=1
            fi
            ;;
        esac

        attempt_in_progress=0
        if [ -e "$running_file" ]; then
          attempt_in_progress=1
        fi

        success=NaN
        case "$status" in
          success)
            success=1
            ;;
          failed)
            success=0
            ;;
        esac
        if [ "$active_state" = failed ]; then
          success=0
        elif [ "$attempt_in_progress" -eq 1 ] && [ "$running" -eq 0 ]; then
          success=0
        fi

        last_success=NaN
        if [ -r "$success_file" ]; then
          candidate="$(${pkgs.coreutils}/bin/cat "$success_file" 2>/dev/null || true)"
          case "$candidate" in
            ""|*[!0-9]*) ;;
            *) last_success="$candidate" ;;
          esac
        fi

        last_attempt=NaN
        if [ -r "$attempt_file" ]; then
          candidate="$(${pkgs.coreutils}/bin/cat "$attempt_file" 2>/dev/null || true)"
          case "$candidate" in
            ""|*[!0-9]*) ;;
            *) last_attempt="$candidate" ;;
          esac
        fi

        printf 'backup_job_success{host="%s",backup="%s"} %s\n' "$host" "$backup" "$success"
        printf 'backup_job_last_success_timestamp_seconds{host="%s",backup="%s"} %s\n' "$host" "$backup" "$last_success"
        printf 'backup_job_running{host="%s",backup="%s"} %s\n' "$host" "$backup" "$running"
        printf 'backup_job_last_attempt_timestamp_seconds{host="%s",backup="%s"} %s\n' "$host" "$backup" "$last_attempt"
      '') jobNames);

  collector = pkgs.writeShellScript "systemd-backup-metrics-collector" ''
    set -eu
    output=${escapeShellArg "${cfg.textfileDirectory}/backup_jobs.prom"}
    temporary="$output.tmp.$$"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
    exec > "$temporary"
    host=${escapeShellArg cfg.host}

    ${metricBlocks}

    ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$output"
    trap - EXIT
  '';

  serviceOverrides = listToAttrs (map
    (name: {
      name = serviceName name;
      value.serviceConfig = {
        ExecStartPre = mkBefore [ "+${writeAttempt name}" ];
        ExecStartPost = mkAfter [ "+${writeSuccess name}" ];
        ExecStopPost = mkAfter [ "+${markFailure name}" ];
        ReadWritePaths = mkAfter [ cfg.stateDirectory ];
      };
    }) jobNames);
in
{
  options.services.backupMetrics = {
    enable = mkEnableOption "systemd backup metrics";

    host = mkOption {
      type = types.str;
      description = "Host label emitted for every backup metric.";
    };

    jobs = mkOption {
      type = types.attrsOf jobType;
      default = { };
      description = "Backup label to systemd service mapping.";
    };

    stateDirectory = mkOption {
      type = types.str;
      default = "/var/lib/systemd-backup-metrics";
      description = "Persistent directory for backup attempt, result, and success timestamps.";
    };

    textfileDirectory = mkOption {
      type = types.str;
      default = "/var/lib/node_exporter/textfile_collector";
      description = "Node exporter textfile collector directory.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host != "";
        message = "services.backupMetrics.host must not be empty.";
      }
      {
        assertion = jobNames != [ ];
        message = "services.backupMetrics.jobs must contain at least one backup.";
      }
      {
        assertion = length (unique serviceNames) == length serviceNames;
        message = "services.backupMetrics.jobs must not map multiple backups to one systemd service.";
      }
      {
        assertion = all (label: match "[A-Za-z0-9_.:-]+" label != null) ([ cfg.host ] ++ jobNames);
        message = "services.backupMetrics.host and backup labels must contain only Prometheus-safe characters.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDirectory} 0750 root root -"
      "d ${cfg.textfileDirectory} 0755 root root -"
    ];

    systemd.services = serviceOverrides // {
      systemd-backup-metrics = {
        description = "Export systemd backup metrics";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = collector;
        };
      };
    };

    systemd.timers.systemd-backup-metrics = {
      description = "Refresh systemd backup metrics";
      wantedBy = [ "timers.target" ];
      after = [ "local-fs.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
        AccuracySec = "1s";
      };
    };
  };
}
