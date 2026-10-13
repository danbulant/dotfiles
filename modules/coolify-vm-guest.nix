{ cfg, lib }:
let
  dashboardDomain = cfg.dashboardDomain;
  dashboardPort = cfg.dashboardPort;
  dashboardUrl = "http://${dashboardDomain}${lib.optionalString (dashboardPort != 80) ":${toString dashboardPort}"}";
  adminEmail = if cfg ? adminEmail then cfg.adminEmail else "/@danbulant.eu";
  adminName = if cfg ? adminName then cfg.adminName else "dan";
  shellQuote = lib.escapeShellArg;
  proxyCompose = ''
    name: coolify-proxy
    networks:
      coolify:
        external: true
    services:
      traefik:
        container_name: coolify-proxy
        image: traefik:v3.6
        restart: always
        extra_hosts:
          - host.docker.internal:host-gateway
        networks:
          - coolify
        # The host ingress is the only public TLS terminator.  Do not publish
        # 443 (or the dashboard/API port); QEMU publishes only guest port 80.
        ports:
          - "80:80"
        healthcheck:
          test: wget -qO- http://localhost:80/ping || exit 1
          interval: 4s
          timeout: 2s
          retries: 5
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock:ro
          - /data/coolify/proxy:/traefik
        command:
          - --ping=true
          - --ping.entrypoint=http
          - --api.dashboard=true
          - --api.insecure=false
          - --entrypoints.http.address=:80
          # Kept as an unbound entrypoint so Coolify's generated HTTPS labels
          # remain valid.  It is intentionally not published by this compose.
          # This HTTPS listener is intentionally unpublished.  No ACME resolver
          # is configured; generated TLS routers may log a missing letsencrypt
          # resolver warning, which is expected behind host-side TLS.
          - --entrypoints.https.address=:443
          - --entrypoints.http.http.encodequerysemicolons=true
          - --entryPoints.http.http2.maxConcurrentStreams=250
          - --entrypoints.https.http.encodequerysemicolons=true
          - --entryPoints.https.http2.maxConcurrentStreams=250
          # QEMU slirp presents the host-side ingress as 10.0.2.2.  Trust only
          # that hop, so X-Forwarded-Proto=https reaches generated HTTP routers.
          - --entrypoints.http.forwardedheaders.trustedips=10.0.2.2/32
          - --entrypoints.https.forwardedheaders.trustedips=10.0.2.2/32
          - --providers.file.directory=/traefik/dynamic/
          - --providers.file.watch=true
          - --providers.docker=true
          - --providers.docker.exposedbydefault=false
        labels:
          coolify.managed: "true"
          coolify.proxy: "true"
  '';
  bootstrap = ''
    #!/bin/bash
    set -euo pipefail

    export PATH=/usr/sbin:/usr/bin:/sbin:/bin
    export USER=root
    ENV_FILE=/data/coolify/source/.env
    PASSWORD_FILE=/root/coolify-admin-password
    PROXY_FILE=/data/coolify/proxy/docker-compose.yml
    INSTALLER_URL=https://cdn.coollabs.io/coolify/install.sh
    DASHBOARD_URL=${shellQuote dashboardUrl}
    ADMIN_NAME=${shellQuote adminName}
    ADMIN_EMAIL=${shellQuote adminEmail}

    mkdir -p /usr/local/lib/coolify-vm /data/coolify/proxy
    if ! command -v curl >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl openssl python3 python3-yaml
    fi

    # The password is generated inside the guest and never enters Nix or the
    # cloud-init user-data.  Keep one value forever so reboots are idempotent.
    if [ ! -s "$PASSWORD_FILE" ]; then
      umask 077
      password_tmp=$(mktemp)
      openssl rand -base64 48 | tr -d '\n' >"$password_tmp"
      install -o root -g root -m 0600 "$password_tmp" "$PASSWORD_FILE"
      rm -f "$password_tmp"
    fi
    chown root:root "$PASSWORD_FILE"
    chmod 0600 "$PASSWORD_FILE"

    # The official CDN installer is the supported Debian path.  It installs
    # Docker and all prerequisites, then seeds the root account from these envs.
    # It is run only when the persistent installation has not been initialized.
    if [ ! -s "$ENV_FILE" ]; then
      DOCKER_ADDRESS_POOL_BASE=172.20.0.0/16 \
      DOCKER_ADDRESS_POOL_SIZE=24 \
      ROOT_USERNAME="$ADMIN_NAME" \
      ROOT_USER_EMAIL="$ADMIN_EMAIL" \
      ROOT_USER_PASSWORD="$(cat "$PASSWORD_FILE")" \
      bash -c "$(curl -fsSL "$INSTALLER_URL")"
    fi

    set_env_var() {
      key=$1
      value=$2
      if grep -q "^$key=" "$ENV_FILE"; then
        awk -v k="$key" -v v="$value" 'BEGIN { FS=OFS="=" } $1 == k { $0 = k "=" v } { print }' "$ENV_FILE" >"$ENV_FILE.tmp"
        chmod 0600 "$ENV_FILE.tmp"
        mv "$ENV_FILE.tmp" "$ENV_FILE"
      else
        printf '%s=%s\n' "$key" "$value" >>"$ENV_FILE"
      fi
    }

    # APP_URL is the supported canonical instance URL; Coolify reads it from
    # .env (there is no supported artisan "set instance URL" command).
    set_env_var APP_URL "$DASHBOARD_URL"
    # Laravel's session config uses SESSION_SECURE_COOKIE directly.  Explicitly
    # clear it for the private HTTP dashboard instead of inheriting an old HTTPS
    # installation value.
    set_env_var SESSION_SECURE_COOKIE false

    # Keep the installer-managed app on its normal integrated Docker network and
    # make Laravel reload the URL and session policy after reconfiguration/reboot.
    if ! command -v docker >/dev/null 2>&1; then
      echo "Coolify bootstrap: installer did not provide docker" >&2
      exit 1
    fi
    if [ ! -f /data/coolify/source/docker-compose.yml ] || [ ! -f /data/coolify/source/docker-compose.prod.yml ]; then
      echo "Coolify bootstrap: installer compose files are missing" >&2
      exit 1
    fi
    # Cold-start seeders can perform two 60-second IP-detection requests.
    # Allow them to finish before applying the saved instance/proxy settings.
    docker compose --env-file "$ENV_FILE" \
      -f /data/coolify/source/docker-compose.yml \
      -f /data/coolify/source/docker-compose.prod.yml up -d --remove-orphans --wait --wait-timeout 300
    docker exec coolify php artisan config:clear >/dev/null

    # Merge our route/entrypoint policy into the existing Coolify proxy YAML.
    # Preserve application networks, custom services, volumes, and labels.
    proxy_networks=""
    if docker inspect coolify-proxy >/dev/null 2>&1; then
      proxy_networks=$(docker inspect --format '{{range $network, $_ := .NetworkSettings.Networks}}{{println $network}}{{end}}' coolify-proxy)
    fi
    if [ -f "$PROXY_FILE" ]; then
      python3 - "$PROXY_FILE" /usr/local/lib/coolify-vm/proxy-compose.yml <<'PY'
  '' + ''
import os
import sys
import tempfile
import yaml

path, desired_path = sys.argv[1:3]
with open(path, encoding="utf-8") as stream:
    current = yaml.safe_load(stream) or {}
with open(desired_path, encoding="utf-8") as stream:
    desired = yaml.safe_load(stream) or {}

services = current.setdefault("services", {})
desired_proxy = desired["services"]["traefik"]
proxy = services.get("traefik")
if not isinstance(proxy, dict):
    proxy = dict(desired_proxy)
    services["traefik"] = proxy
for key in ("container_name", "restart", "extra_hosts", "volumes", "networks", "image", "ports", "command", "healthcheck"):
    proxy.setdefault(key, desired_proxy[key])
for key in ("image", "ports", "command", "healthcheck"):
    proxy[key] = desired_proxy[key]

networks = proxy.setdefault("networks", [])
if isinstance(networks, list):
    if "coolify" not in networks:
        networks.append("coolify")
elif isinstance(networks, dict):
    networks.setdefault("coolify", None)
else:
    proxy["networks"] = ["coolify"]
top_networks = current.setdefault("networks", {})
if isinstance(top_networks, dict):
    top_networks.setdefault("coolify", {"external": True})

labels = proxy.get("labels", {})
if isinstance(labels, dict):
    labels = {
        key: value
        for key, value in labels.items()
        if key != "traefik.enable"
        and not key.startswith("traefik.http.routers.traefik")
        and not key.startswith("traefik.http.services.traefik")
    }
    labels.update(desired_proxy["labels"])
elif isinstance(labels, list):
    labels = [
        value
        for value in labels
        if value != "traefik.enable=true"
        and not value.startswith("traefik.http.routers.traefik")
        and not value.startswith("traefik.http.services.traefik")
    ]
    labels.extend(f"{key}={value}" for key, value in desired_proxy["labels"].items())
else:
    labels = desired_proxy["labels"]
proxy["labels"] = labels

volumes = proxy.setdefault("volumes", [])
def volume_target(item):
    if isinstance(item, dict):
        return item.get("target")
    parts = item.split(":")
    if len(parts) >= 3 and parts[-1] in ("ro", "rw", "z", "Z"):
        return parts[-2]
    return parts[-1]
for required in desired_proxy["volumes"]:
    target = volume_target(required)
    if not any(volume_target(item) == target for item in volumes):
        volumes.append(required)

fd, temporary = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".proxy-", text=True)
with os.fdopen(fd, "w", encoding="utf-8") as stream:
    yaml.safe_dump(current, stream, sort_keys=False)
os.replace(temporary, path)
  '' + ''
    PY
    else
      install -o root -g root -m 0644 /usr/local/lib/coolify-vm/proxy-compose.yml "$PROXY_FILE"
    fi
    if ! docker network inspect coolify >/dev/null 2>&1; then
      docker network create --attachable coolify >/dev/null
    fi
    docker compose -f "$PROXY_FILE" up -d --remove-orphans --wait --wait-timeout 60
    for network in $proxy_networks; do
      case "$network" in bridge|host|none|default|coolify|"") continue ;; esac
      if docker network inspect "$network" >/dev/null 2>&1; then
        if ! docker network inspect --format '{{range .Containers}}{{println .Name}}{{end}}' "$network" | grep -qx coolify-proxy; then
          docker network connect "$network" coolify-proxy
        fi
      fi
    done

    # Coolify v4.3 stores the active proxy YAML in Server.proxy's
    # last_saved_proxy_configuration schemaless field.  Persist our trusted-IP
    # configuration after app:init creates the local server row, otherwise a
    # later restart could regenerate the default (public 443 + ACME) compose.
    proxy_configured=false
    if docker ps --format '{{.Names}}' | grep -qx coolify; then
      for attempt in $(seq 1 60); do
        if docker exec coolify php artisan tinker --execute='if (!\App\Models\Server::find(0)) { throw new \RuntimeException("Local server is not initialized"); }' >/dev/null 2>&1; then
          proxy_b64=$(base64 -w0 "$PROXY_FILE")
          # The fqdn mutator strips ports. Preserve the private canonical URL;
          # Coolify generates proxy Host rules from its hostname separately.
          if docker exec -e COOLIFY_PROXY_CONFIGURATION="$proxy_b64" -e COOLIFY_APP_URL="$DASHBOARD_URL" coolify php artisan tinker --execute='
            $instance = \App\Models\InstanceSettings::find(0);
            $s = \App\Models\Server::find(0);
            if (!$instance || !$s) {
                throw new \RuntimeException("Coolify instance or local server is not initialized");
            }
            $instance->setRawAttributes(
                array_replace($instance->getAttributes(), [
                    "fqdn" => getenv("COOLIFY_APP_URL"),
                ]),
                false
            );
            $instance->is_dashboard_force_https_enabled = false;
            $instance->is_registration_enabled = !\App\Models\User::query()->exists();
            $instance->save();
            $configuration = base64_decode(getenv("COOLIFY_PROXY_CONFIGURATION"));
            $s->proxy->set("type", "TRAEFIK");
            $s->proxy->set("status", "running");
            $s->proxy->set("last_saved_proxy_configuration", $configuration);
            $s->proxy->set("last_saved_settings", md5(base64_encode($configuration)));
            $s->save();
          ' >/dev/null; then
            proxy_configured=true
            break
          fi
        fi
        sleep 2
      done
    fi
    if [ "$proxy_configured" != true ]; then
      echo "Coolify bootstrap: timed out waiting for initialized Coolify server row" >&2
      exit 1
    fi

    cat <<EOF
    Coolify VM bootstrap complete.
    Dashboard: $DASHBOARD_URL (private HTTP listener on the host)
    Traefik: guest :80 only; X-Forwarded-* trusted from 10.0.2.2/32
    Traefik :443 is an unused, unpublished listener; ACME is disabled.
    WARNING: generated public-application TLS routers may log missing letsencrypt resolver; host ingress owns public TLS.
    Verify dashboard: curl -I -H 'Host: ${dashboardDomain}' http://127.0.0.1:8000/api/health
    Verify proxy: docker compose -f $PROXY_FILE ps; curl -I -H 'Host: <service-domain>' -H 'X-Forwarded-Proto: https' http://127.0.0.1/
    Admin password: $PASSWORD_FILE (mode 0600, root only)
    EOF
  '';
  systemdUnit = ''
    [Unit]
    Description=Provision and configure Coolify inside the VM
    Wants=network-online.target docker.service
    After=network-online.target docker.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/lib/coolify-vm/bootstrap.sh
    RemainAfterExit=no
    TimeoutStartSec=0

    [Install]
    WantedBy=multi-user.target
  '';
in
{
  disable_root = false;
  ssh_pwauth = false;
  ssh_deletekeys = false;
  hostname = "coolify-vm";
  manage_etc_hosts = true;
  users = [
    {
      name = "root";
      lock_passwd = true;
      ssh_authorized_keys = [ "__COOLIFY_VM_ROOT_SSH_KEY__" ];
    }
  ];
  write_files = [
    {
      path = "/usr/local/lib/coolify-vm/proxy-compose.yml";
      permissions = "0644";
      owner = "root:root";
      content = proxyCompose;
    }
    {
      path = "/usr/local/lib/coolify-vm/bootstrap.sh";
      permissions = "0755";
      owner = "root:root";
      content = bootstrap;
    }
    {
      path = "/etc/systemd/system/coolify-vm-bootstrap.service";
      permissions = "0644";
      owner = "root:root";
      content = systemdUnit;
    }
  ];
  runcmd = [
    [ "systemctl" "daemon-reload" ]
    [ "systemctl" "enable" "--now" "coolify-vm-bootstrap.service" ]
  ];
}
