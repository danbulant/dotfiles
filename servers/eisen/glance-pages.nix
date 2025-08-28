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
            type = "rss";
            limit = 10;
            "collapse-after" = 3;
            cache = "12h";
            feeds = [
              {
                url = "https://selfh.st/rss/";
                title = "selfh.st";
                limit = 4;
              }
              {
                url = "https://ciechanow.ski/atom.xml";
              }
              {
                url = "https://www.joshwcomeau.com/rss.xml";
                title = "Josh Comeau";
              }
              {
                url = "https://samwho.dev/rss.xml";
              }
              {
                url = "https://ishadeed.com/feed.xml";
                title = "Ahmad Shadeed";
              }
            ];
          }
          {
            type = "custom-api";
            title = "Uptime Kuma";
            title-url = "http://status.eisen";
            url = "http://status.eisen/api/status-page/base";
            subrequests = {
              heartbeats = {
                url = "http://status.eisen/api/status-page/heartbeat/base";
              };
            };
            cache = "10m";
            template = ''
              {{ $hb := .Subrequest "heartbeats" }}

              {{ if not (.JSON.Exists "publicGroupList") }}
              <p class="color-negative">Error reading response</p>
              {{ else if eq (len (.JSON.Array "publicGroupList")) 0 }}
              <p>No monitors found</p>
              {{ else }}

              <ul class="dynamic-columns list-gap-8">
                {{ range .JSON.Array "publicGroupList" }}
                {{ range .Array "monitorList" }}
                {{ $id := .String "id" }}
                {{ $hbArray := $hb.JSON.Array (print "heartbeatList." $id) }}
                <div class="flex items-center gap-12">
                  <a class="size-title-dynamic color-highlight text-truncate block grow" href="http://status.eisen/dashboard/{{ $id }}"
                    target="_blank" rel="noreferrer">
                    {{ .String "name" }} </a>
              
                  {{ if gt (len $hbArray) 0 }}
                    {{ $latest := index $hbArray (sub (len $hbArray) 1) }}
                    {{ if eq ($latest.Int "status") 1 }}
                    <div>{{ $latest.Int "ping" }}ms</div>
                    <div class="monitor-site-status-icon-compact" title="OK">
                      <svg fill="var(--color-positive)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                        <path fill-rule="evenodd"
                          d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm3.857-9.809a.75.75 0 0 0-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 1 0-1.06 1.061l2.5 2.5a.75.75 0 0 0 1.137-.089l4-5.5Z"
                          clip-rule="evenodd"></path>
                      </svg>
                    </div>
                    {{ else }}
                    <div><span class="color-negative">DOWN</span></div>
                    <div class="monitor-site-status-icon-compact" title="{{ if $latest.Exists "msg" }}{{ $latest.String "msg" }}{{ else
                      }}Error{{ end }}">
                      <svg fill="var(--color-negative)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                        <path fill-rule="evenodd"
                          d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495ZM10 5a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 10 5Zm0 9a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"
                          clip-rule="evenodd"></path>
                      </svg>
                    </div>
                    {{ end }}
                  {{ else }}
                    <div><span class="color-negative">No data</span></div>
                    <div class="monitor-site-status-icon-compact" title="No data available">
                      <svg fill="var(--color-negative)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                        <path d="M10 18a8 8 0 1 1 0-16 8 8 0 0 1 0 16zm0-2a6 6 0 1 0 0-12 6 6 0 0 0 0 12zm-.75-8a.75.75 0 0 1 1.5 0v3a.75.75 0 0 1-1.5 0V8zm.75 5a1 1 0 1 1 0 2 1 1 0 0 1 0-2z"/>
                      </svg>
                    </div>
                  {{ end }}
                </div>
                {{ end }}
                {{ end }}
              </ul>
              {{ end }}
            '';
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
            type = "videos";
            channels = [
              "UCXuqSBlHAE6Xw-yeJA0Tunw" # Linus Tech Tips
              "UCR-DXc1voovS8nhAvccRZhg" # Jeff Geerling
              "UCsBjURrPoezykLs9EqgamOA" # Fireship
              "UCBJycsmduvYEL83R_U4JriQ" # Marques Brownlee
              "UCHnyfMqiRRG1u-2MsSQLbXA" # Veritasium
            ];
          }
          {
            type = "group";
            widgets = [
              {
                type = "reddit";
                subreddit = "technology";
                "show-thumbnails" = true;
              }
              {
                type = "reddit";
                subreddit = "selfhosted";
                "show-thumbnails" = true;
              }
            ];
          }
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
          {
            type = "releases";
            cache = "1d";
            repositories = [
              "glanceapp/glance"
              "go-gitea/gitea"
              "immich-app/immich"
              "syncthing/syncthing"
              "9001/copyparty"
              "caddyserver/caddy"
            ];
          }
          {
            type = "custom-api";
            title = "Epic Games";
            cache = "1h";
            url = "https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en&country=US&allowCountries=US";
            template = ''
              <div>
                {{ if eq .Response.StatusCode 200 }}
                  <div class="horizontal-cards-2">
                    {{ range .JSON.Array "data.Catalog.searchStore.elements" }}
                      {{ $price := .String "price.totalPrice.discountPrice" }}
                      {{ $hasPromo := gt (len (.Array "promotions.promotionalOffers")) 0 }}
                      {{ if and $hasPromo (eq $price "0") }}
                        {{ $gamePage := .String "productSlug" }}
                        {{ if gt (len (.Array "offerMappings")) 0 }}
                          {{ $gamePage = .String "offerMappings.0.pageSlug" }}
                        {{end }}
                        <a href="https://store.epicgames.com/en-US/p/{{ $gamePage }}" target="_blank" class="card">
                          {{ $title := .String "title" }}
                          {{ range .Array "keyImages" }}
                            {{ if eq (.String "type") "OfferImageWide" }}
                              <img src="{{ .String "url" }}" alt="{{ $title }}" style="width: 100%; max-width: 300px; height: 150px; object-fit: cover; border-radius: var(--border-radius);">
                            {{ end }}
                          {{ end }}
                          <div class="card-content">
                            <span class="size-base color-primary">{{ $title }}</span><br>
                            <span class="size-h5 color-subdue">
                              {{ if $hasPromo }}
                                {{ $promotions := .Array "promotions.promotionalOffers" }}
                                {{ if gt (len $promotions) 0 }}
                                  {{ $firstPromo := index $promotions 0 }}
                                  {{ $offers := $firstPromo.Array "promotionalOffers" }}
                                  {{ if gt (len $offers) 0 }}
                                    {{ $firstOffer := index $offers 0 }}
                                    Free until {{ slice ($firstOffer.String "endDate") 0 10 }}
                                  {{ else }}
                                    Free this week!
                                  {{ end }}
                                {{ else }}
                                  Free this week!
                                {{ end }}
                              {{ end }}
                            </span>
                          </div>
                        </a>
                      {{ end }}
                    {{ end }}
                  </div>
                {{ else }}
                  <p class="color-negative">Error fetching Epic Games data.</p>
                {{ end }}
              </div>
              '';
          }
        ];
      }
    ];
  }
]
