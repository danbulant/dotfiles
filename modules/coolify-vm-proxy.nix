{ config, lib, ... }:
let
  cfg = config.services.coolify-vm;
  # Upstream TLS is optional; host-side TLS is the default.
  siteAddress = domain: if cfg.tlsAtUpstream then "http://${domain}" else domain;
  certificateDomains = cfg.domains ++ lib.optional (cfg.githubWebhookDomain != null) cfg.githubWebhookDomain;
  onDemandTls = !cfg.tlsAtUpstream && certificateDomains != [ ];
  siteTls = lib.optionalString onDemandTls ''
    tls {
      on_demand
    }
  '';
  allowedDomainRegex = "^(" + lib.concatMapStringsSep "|" (domain:
    if lib.hasPrefix "*." domain then
      "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?[.]${lib.escapeRegex (lib.removePrefix "*." domain)}"
    else lib.escapeRegex domain
  ) certificateDomains + ")$";
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
    default = false;
    description = ''
      Whether public TLS terminates before the host Caddy. In this mode origin
      sites explicitly use HTTP and advertise HTTPS to the guest. Otherwise
      Caddy manages public TLS and redirects itself, obtaining individual
      hostname certificates on demand for configured application domains.
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

  options.services.coolify-vm.githubWebhookDomain = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Public hostname exposing only POST /webhooks/source/github/events.
      Use its HTTPS base URL as the GitHub App custom webhook endpoint.
      DNS and upstream ingress must forward this hostname to the host Caddy.
    '';
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      globalConfig = lib.optionalString onDemandTls ''
        on_demand_tls {
          ask http://127.0.0.1:18081/
        }
      '';
      virtualHosts = lib.listToAttrs (
        map (domain: lib.nameValuePair (siteAddress domain) {
          extraConfig = siteTls + publicProxy cfg.hostPorts.http;
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
      } // lib.optionalAttrs onDemandTls {
        "http://127.0.0.1:18081" = {
          extraConfig = ''
            bind 127.0.0.1
            @allowed expression `{query.domain}.matches(${builtins.toJSON allowedDomainRegex}) && {query.domain} != ${builtins.toJSON cfg.dashboardDomain}`
            respond @allowed 200
            respond 403
          '';
        };
      } // lib.optionalAttrs (cfg.githubWebhookDomain != null) {
        ${siteAddress cfg.githubWebhookDomain} = {
          extraConfig = siteTls + ''
            @githubEvents {
              method POST
              path /webhooks/source/github/events
            }
            handle @githubEvents {
              reverse_proxy 127.0.0.1:${toString cfg.hostPorts.dashboard} {
                ${lib.optionalString cfg.tlsAtUpstream ''
                  header_up X-Forwarded-Proto https
                  header_up X-Forwarded-Port 443
                ''}
              }
            }
            handle {
              respond 404
            }
          '';
        };
      };
    };
  };
}
