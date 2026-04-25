{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-swap-exporter;
  exporter = pkgs.callPackage ../servers/eisen/llama-swap-exporter/default.nix { };
in

{
  options.services.llama-swap-exporter = {
    enable = lib.mkEnableOption "llama-swap Prometheus exporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9409;
      description = "Port for the Prometheus metrics endpoint.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8080/api/metrics";
      description = "llama-swap metrics endpoint URL.";
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Scrape interval in seconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.llama-swap-exporter = {
      description = "llama-swap Prometheus exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${exporter}/bin/exporter.py";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "root";
        Group = "root";
        Environment = [
          "PROMETHEUS_PORT=${toString cfg.port}"
          "LLAMA_SWAP_URL=${cfg.url}"
          "SCRAPE_INTERVAL=${toString cfg.interval}"
        ];
        ReadWritePaths = [ "/tmp" ];
      };
    };
  };
}
