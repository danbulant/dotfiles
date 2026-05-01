let
  jellyfinConfig =
    {
      title,
      library-name ? null,
      mode,
    }:
    {
      inherit title;
      type = "custom-api";
      # url = "http://jellyfin.eisen.danbulant.cloud";
      frameless = true;
      cache = "5m";
      options = {
        inherit library-name mode;
        base-url = "http://jellyfin.eisen.danbulant.cloud";
        api-key = "\${JELLYFIN_KEY}";
        user-name = "dan";
        item-count = "10";
        small-column = false;
        show-thumbnail = true;
        thumbnail-aspect-ratio = "default";
      };
      template = builtins.readFile ./glance/jellyfin-latest;
    };
in
[
  {
    name = "Home";
    columns = [
      {
        size = "small";
        widgets = [
          {
            type = "calendar";
            "first-day-of-week" = "monday";
          }
          {
            type = "server-stats";
            servers = [
              {
                type = "local";
              }
            ];
          }
          {

            # - type: custom-api
            #   title: "Jellyfin/Emby Stats"
            #   base-url: ${JELLYFIN_URL}
            #   options:
            #     url: ${JELLYFIN_URL}
            #     key: ${JELLYFIN_API_KEY}
            #
            type = "custom-api";
            title = "Jellyfin Stats";
            # url = "http://jellyfin.eisen.danbulant.cloud";
            options = {
              url = "http://jellyfin.eisen.danbulant.cloud";
              key = "\${JELLYFIN_KEY}";
            };
            template = builtins.readFile ./glance/jellyfin-stats;
          }
          {
            type = "custom-api";
            title = "Uptime Kuma";
            title-url = "http://status.eisen.danbulant.cloud";
            url = "http://status.eisen.danbulant.cloud/api/status-page/base";
            subrequests = {
              heartbeats = {
                url = "http://status.eisen.danbulant.cloud/api/status-page/heartbeat/base";
              };
            };
            cache = "10m";
            template = builtins.readFile ./glance/uptime-kuma;
          }
          {
            type = "custom-api";
            title = "Tailscale";
            title-url = "https://login.tailscale.com/admin/machines";
            url = "https://api.tailscale.com/api/v2/tailnet/-/devices";
            headers = {
              Authorization = "Bearer \${TAILSCALE_API_KEY}";
            };
            cache = "10m";
            options = {
              # collapseAfter: 4
              # disableOfflineIndicator: true
              # disableUpdateIndicator: true
              # prioritiseTags: true
            };
            template = builtins.readFile ./glance/tailscale;
          }
        ];
      }
      {
        size = "full";
        widgets = [
          {
            type = "group";
            widgets = [
              { type = "hacker-news"; }
              { type = "lobsters"; }
            ];
          }
          {
            type = "monitor";
            cache = "1m";
            title = "Services";

            sites = [
              {
                title = "Jellyfin";
                url = "http://jellyfin.eisen.danbulant.cloud";
                icon = "si:jellyfin";
              }
              {
                title = "qBittorrent";
                url = "http://qb.eisen.danbulant.cloud";
                icon = "si:qbittorrent";
              }
              {
                title = "Radarr";
                url = "http://radarr.eisen.danbulant.cloud";
                icon = "si:radarr";
              }
              {
                title = "Sonarr";
                url = "http://sonarr.eisen.danbulant.cloud";
                icon = "si:sonarr";
              }
              {
                title = "Prowlarr";
                url = "http://prowlarr.eisen.danbulant.cloud";
                icon = "si:prowlarr";
              }
              {
                title = "Vaultwarden";
                url = "https://vaultwarden.danbulant.cloud";
                icon = "si:vaultwarden";
              }
              {
                title = "Nextcloud";
                url = "https://direct.danbulant.cloud";
                icon = "si:nextcloud";
              }
              {
                title = "Grafana";
                url = "http://grafana.eisen.danbulant.cloud";
                icon = "si:grafana";
              }
              {
                title = "Karakeep";
                url = "http://keep.eisen.danbulant.cloud";
                icon = "si:karakeep";
              }
            ];
          }
          (jellyfinConfig {
            title = "Movies";
            mode = "nextup";
          })
          {
            type = "group";
            widgets = [
              (jellyfinConfig {
                title = "Shows";
                library-name = "Shows";
                mode = "latest";
              })
              (jellyfinConfig {
                title = "Movies";
                library-name = "Movies";
                mode = "latest";
              })
            ];
          }
          # {
          #   type = "docker-containers";
          # }
        ];
      }
      {
        size = "small";
        widgets = [
          {
            type = "weather";
            location = "Aarhus, Denmark";
            units = "metric";
            "hour-format" = "24h";
          }
          # {
          #   type = "releases";
          #   cache = "1d";
          #   repositories = [
          #     "glanceapp/glance"
          #     "go-gitea/gitea"
          #     "immich-app/immich"
          #     "syncthing/syncthing"
          #     "9001/copyparty"
          #     "caddyserver/caddy"
          #   ];
          # }
          {
            type = "custom-api";
            title = "xkcd";
            cache = "10m";
            url = "https://xkcd.com/info.0.json";
            template = ''
              <body> {{ .JSON.String "title" }}</body>
              <img src="{{ .JSON.String "img" }}"></img>
            '';
          }
          {
            type = "custom-api";
            title = "Steam specials";
            cache = "12h";
            url = "https://store.steampowered.com/api/featuredcategories?cc=us";
            template = ''
              <ul class="list list-gap-10 collapsible-container" data-collapse-after="5">
              {{ range .JSON.Array "specials.items" }}
                <li>
                  <a class="size-h4 color-highlight block text-truncate" href="https://store.steampowered.com/app/{{ .Int "id" }}/">{{ .String "name" }}</a>
                  <ul class="list-horizontal-text">
                    <li>{{ div (.Int "final_price" | toFloat) 100 | printf "$%.2f" }}</li>
                    {{ $discount := .Int "discount_percent" }}
                    <li{{ if ge $discount 40 }} class="color-positive"{{ end }}>{{ $discount }}% off</li>
                  </ul>
                </li>
              {{ end }}
              </ul>
            '';
          }
        ];
      }
    ];
  }
]
