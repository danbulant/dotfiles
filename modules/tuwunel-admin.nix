{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.tuwunel-admin;
  tomlFormat = pkgs.formats.toml { };
  configFile = tomlFormat.generate "tuwunel-admin.toml" cfg.settings;
in
{
  options.services.tuwunel-admin = {
    enable = lib.mkEnableOption "tuwunel-admin web UI";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/tuwunel-admin/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../pkgs/tuwunel-admin/package.nix { }";
      description = "The tuwunel-admin package to use.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = {
        server.bind = "127.0.0.1:8009";
        matrix = {
          homeservers = [ "https://matrix.example.com" ];
          allow_any_server = false;
          admin_bot = "@tuwunel:matrix.example.com";
          admin_room_alias = "#admins:matrix.example.com";
          device_id = "tuwunel-admin";
          device_display_name = "tuwunel-admin";
        };
      };
      description = ''
        Configuration written to tuwunel-admin's TOML configuration file.
        See <https://github.com/knadh/tuwunel-admin/blob/master/config.sample.toml>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.tuwunel-admin = {
      description = "tuwunel Matrix administration UI";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} --config ${configFile}";
        Restart = "on-failure";
        RestartSec = "5s";

        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        UMask = "0077";
      };
    };
  };
}
