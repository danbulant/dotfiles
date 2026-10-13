{ config, lib, ... }:
let
  cfg = config.services.coolify-vm;
  # Eisen's public TLS terminates upstream. Explicit HTTP site addresses keep
  # Caddy from redirecting the origin hop or trying to obtain certificates.
  siteAddress = domain: if cfg.tlsAtUpstream then "http://${domain}" else domain;
  publicProxy = port: ''
    # A wildcard/application site must never become an alias for Coolify's
    # control plane when its hostname is configured broadly enough to overlap.
    @coolifyDashboard host ${cfg.dashboardDomain}
    handle @coolifyDashboard {
      respond 404
    }
    handle {
      reverse_proxy 127.0.0.1:${toString port} {
        ${lib.optionalString cfg.tlsAtUpstream ''
          header_up X-Forwarded-Proto https
          header_up X-Forwarded-Port 443
        ''}
      }
    }
  '';
  dashboardProxy = port: ''
    reverse_proxy 127.0.0.1:${toString port} {
      header_up X-Forwarded-Proto http
      header_up X-Forwarded-Port ${toString cfg.dashboardPort}
    }
  '';
in
{
  options.services.coolify-vm.tlsAtUpstream = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether public TLS terminates before the host Caddy. In this mode origin
      sites explicitly use HTTP and advertise HTTPS to the guest. Otherwise
      Caddy manages public TLS and redirects itself; wildcard sites then require
      DNS-challenge configuration in the host Caddy.
    '';
  };

  options.services.coolify-vm.dashboardListenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
    description = "Address on which the private Coolify dashboard listener binds.";
  };

  options.services.coolify-vm.dashboardPort = lib.mkOption {
    type = lib.types.port;
    default = 8088;
    description = "Private HTTP port for the Coolify dashboard and control-plane routes.";
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      virtualHosts = lib.listToAttrs (
        map (domain: lib.nameValuePair (siteAddress domain) {
          extraConfig = publicProxy cfg.hostPorts.http;
        }) cfg.domains
      ) // {
        "http://${cfg.dashboardDomain}:${toString cfg.dashboardPort}" = {
          extraConfig = ''
            bind ${cfg.dashboardListenAddress}
            handle /app/* {
              ${dashboardProxy cfg.hostPorts.realtime}
            }
            handle /terminal/ws* {
              ${dashboardProxy cfg.hostPorts.terminal}
            }
            handle {
              ${dashboardProxy cfg.hostPorts.dashboard}
            }
          '';
        };
      };
    };
  };
}
