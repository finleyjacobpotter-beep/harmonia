# Podman on the Nike guest, plus the podman-compose lab stacks the user asked
# for, each wired to a systemd service:
#
#   systemctl start ligolo-ng     the Ligolo-ng pivot proxy (nike/labs: ligolo)
#   systemctl start bloodhound    BloodHound CE (Postgres + Neo4j + the UI)
#   systemctl start cyberchef     CyberChef, the data-transformation web app
#   systemctl start zap           OWASP ZAP desktop UI in the browser (Burp
#                                 replacement: intercepting proxy + the GUI)
#   systemctl start mythic        Mythic C2 (via mythic-cli; first run clones
#                                 and builds, so it is slow)
#
# None start at boot: bring one up when you need it, and `systemctl stop` it
# after. The compose files live in /etc/nike/<stack>/. The web UIs all bind to
# localhost, so reach them over an SSH tunnel to Nike (see docs/nike.md).
{
  lib,
  pkgs,
  ...
}:
let
  compose = "${pkgs.podman-compose}/bin/podman-compose";

  # Ligolo-ng's proxy as a local image, built from the same binary that is on
  # PATH (nike/tools.nix), so nothing is pulled for it. It needs a TUN device
  # and the host network to create the ligolo interface and routes.
  ligoloImage = pkgs.dockerTools.buildImage {
    name = "nike-ligolo-proxy";
    tag = pkgs.ligolo-ng.version;
    copyToRoot = pkgs.buildEnv {
      name = "ligolo-root";
      paths = [
        pkgs.ligolo-ng
        pkgs.iproute2
        pkgs.cacert
      ];
    };
    config = {
      # -selfcert generates a certificate; agents connect on :11601.
      Entrypoint = [
        "ligolo-proxy"
        "-selfcert"
      ];
      Tty = true;
    };
  };

  ligoloCompose = pkgs.writeText "ligolo-compose.yml" ''
    services:
      ligolo:
        image: nike-ligolo-proxy:${pkgs.ligolo-ng.version}
        container_name: nike-ligolo-proxy
        # The proxy opens a "ligolo" TUN interface and adds routes, so it needs
        # the host network stack, the TUN device and NET_ADMIN.
        network_mode: host
        cap_add: [NET_ADMIN]
        devices: ["/dev/net/tun"]
        # Keep the proxy's interactive console alive; attach to it with
        #   podman attach nike-ligolo-proxy      (Ctrl-p Ctrl-q to detach)
        stdin_open: true
        tty: true
        restart: "no"
  '';

  # BloodHound Community Edition, modelled on SpecterOps' own compose file
  # (examples/docker-compose/docker-compose.yml). Images are pulled on the
  # first `up`. Everything binds to localhost; reach the UI over an SSH
  # tunnel to Nike (ssh -L 8080:127.0.0.1:8080 nike), then http://localhost:8080.
  bloodhoundCompose = pkgs.writeText "bloodhound-compose.yml" ''
    services:
      app-db:
        image: docker.io/library/postgres:18
        container_name: nike-bloodhound-postgres
        environment:
          PGUSER: bloodhound
          POSTGRES_USER: bloodhound
          POSTGRES_PASSWORD: bloodhoundcommunityedition
          POSTGRES_DB: bloodhound
        volumes: ["postgres-data:/var/lib/postgresql/data"]
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U bloodhound -d bloodhound -h 127.0.0.1"]
          interval: 10s
          timeout: 5s
          retries: 5
        restart: unless-stopped

      graph-db:
        image: docker.io/library/neo4j:4.4.42
        container_name: nike-bloodhound-neo4j
        environment:
          NEO4J_AUTH: neo4j/bloodhoundcommunityedition
          NEO4J_dbms_allow__upgrade: "true"
        ports:
          - "127.0.0.1:7687:7687"
          - "127.0.0.1:7474:7474"
        volumes: ["neo4j-data:/data"]
        healthcheck:
          test: ["CMD-SHELL", "wget -q --spider http://localhost:7474 || exit 1"]
          interval: 10s
          timeout: 5s
          retries: 5
        restart: unless-stopped

      bloodhound:
        image: docker.io/specterops/bloodhound:latest
        container_name: nike-bloodhound
        environment:
          bhe_database_connection: "user=bloodhound password=bloodhoundcommunityedition dbname=bloodhound host=app-db"
          bhe_neo4j_connection: "neo4j://neo4j:bloodhoundcommunityedition@graph-db:7687/"
          bhe_recreate_default_admin: "true"
        ports:
          - "127.0.0.1:8080:8080"
        depends_on:
          app-db: {condition: service_healthy}
          graph-db: {condition: service_healthy}
        restart: unless-stopped

    volumes:
      postgres-data:
      neo4j-data:
  '';

  # CyberChef — GCHQ's data-transformation web app ("the cyber swiss army
  # knife"), a static site in the official image. Bound to localhost; reach it
  # over an SSH tunnel (ssh -L 8001:127.0.0.1:8000 nike), then
  # http://localhost:8001. Replaces the encode/decode side of Burp.
  cyberchefCompose = pkgs.writeText "cyberchef-compose.yml" ''
    services:
      cyberchef:
        image: ghcr.io/gchq/cyberchef:latest
        container_name: nike-cyberchef
        ports:
          - "127.0.0.1:8000:8080"
        restart: unless-stopped
  '';

  # OWASP ZAP as a free Burp replacement: the full desktop UI served in the
  # browser via Webswing (no local Java needed), plus the intercepting proxy.
  #   GUI:   ssh -L 8081:127.0.0.1:8081 nike  ->  http://localhost:8081/zap
  #   proxy: ssh -L 8090:127.0.0.1:8090 nike  ->  point the browser at :8090
  # The session is ephemeral (no volume); save a session to ~/share from the
  # GUI if you need it to persist.
  zapCompose = pkgs.writeText "zap-compose.yml" ''
    services:
      zap:
        image: ghcr.io/zaproxy/zaproxy:stable
        container_name: nike-zap
        command: zap-webswing.sh
        user: zap
        ports:
          - "127.0.0.1:8081:8080"
          - "127.0.0.1:8090:8090"
        restart: unless-stopped
  '';

  # ── Mythic C2 ─────────────────────────────────────────────────────
  # Unlike the stacks above, Mythic has no static compose file to mirror: its
  # docker-compose.yml is generated by `mythic-cli`, and C2 profiles/agents are
  # installed separately (`mythic-cli install github <url>`), which regenerate
  # it. So the service drives mythic-cli rather than a fixed compose.
  #
  # Mythic is Docker-first; here it runs on podman via the docker-compat shim,
  # which is best-effort (upstream only supports Docker). If a container balks,
  # the fallback is a Docker daemon in Nike — see docs/nike.md.
  mythicRev = "v3.4.0.9";
  mythicDir = "/var/lib/nike/mythic";

  # Mythic's config. Every service is bound to localhost so nothing is exposed
  # off Nike; reach the UI over an SSH tunnel (docs/nike.md). Change the admin
  # password here, or in ${mythicDir}/.env on the guest, before first start.
  mythicEnv = pkgs.writeText "mythic.env" ''
    MYTHIC_ADMIN_USER=mythic_admin
    MYTHIC_ADMIN_PASSWORD=mythic_admin_password
    NGINX_BIND_LOCALHOST_ONLY=true
    MYTHIC_SERVER_BIND_LOCALHOST_ONLY=true
    HASURA_BIND_LOCALHOST_ONLY=true
    RABBITMQ_BIND_LOCALHOST_ONLY=true
    POSTGRES_BIND_LOCALHOST_ONLY=true
    DOCUMENTATION_BIND_LOCALHOST_ONLY=true
    JUPYTER_BIND_LOCALHOST_ONLY=true
    MYTHIC_REACT_BIND_LOCALHOST_ONLY=true
  '';

  # First start: clone Mythic (pinned), build mythic-cli, and drop the .env.
  # Idempotent — it no-ops once the checkout and binary exist.
  mythicSetup = pkgs.writeShellScript "nike-mythic-setup" ''
    set -eu
    if [ ! -d ${mythicDir}/.git ]; then
      ${pkgs.git}/bin/git clone --depth 1 --branch ${mythicRev} \
        https://github.com/its-a-feature/Mythic ${mythicDir}
    fi
    cd ${mythicDir}
    [ -x ${mythicDir}/mythic-cli ] || make
    [ -f ${mythicDir}/.env ] || cp ${mythicEnv} ${mythicDir}/.env
  '';

  # A compose stack as a service: bring it up detached, tear it down on stop.
  # `restartIfChanged = false` so a rebuild doesn't yank a running lab.
  composeService =
    {
      name,
      file,
      description,
      preStart ? [ ],
    }:
    {
      inherit description;
      path = with pkgs; [
        podman
        podman-compose
        gettext # podman-compose shells out to envsubst
      ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = preStart;
        ExecStart = "${compose} -f ${file} up -d";
        ExecStop = "${compose} -f ${file} down";
        TimeoutStartSec = "600"; # first run pulls images
      };
    };
in
{
  # Rootless-capable podman with a docker alias, so compose and the usual
  # `docker` muscle memory both work. The docker-compatible socket at
  # /run/docker.sock is for Mythic's mythic-cli, which talks to the daemon
  # through the Docker Go SDK (not just the `docker` CLI).
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  environment.systemPackages = [ pkgs.podman-compose ];

  environment.etc = {
    "nike/ligolo-ng/compose.yml".source = ligoloCompose;
    "nike/bloodhound/compose.yml".source = bloodhoundCompose;
    "nike/cyberchef/compose.yml".source = cyberchefCompose;
    "nike/zap/compose.yml".source = zapCompose;
  };

  # Defined but not wanted-by anything: start them on demand.
  systemd.services.ligolo-ng = composeService {
    name = "ligolo-ng";
    file = "/etc/nike/ligolo-ng/compose.yml";
    description = "Ligolo-ng pivot proxy (podman-compose)";
    # Load the locally built proxy image before composing it up.
    preStart = [ "${pkgs.podman}/bin/podman load -i ${ligoloImage}" ];
  };

  systemd.services.bloodhound = composeService {
    name = "bloodhound";
    file = "/etc/nike/bloodhound/compose.yml";
    description = "BloodHound CE: Postgres, Neo4j and the UI (podman-compose)";
  };

  systemd.services.cyberchef = composeService {
    name = "cyberchef";
    file = "/etc/nike/cyberchef/compose.yml";
    description = "CyberChef data-transformation web app (podman-compose)";
  };

  systemd.services.zap = composeService {
    name = "zap";
    file = "/etc/nike/zap/compose.yml";
    description = "OWASP ZAP desktop UI via Webswing + proxy (podman-compose)";
  };

  # Mythic C2, driven by mythic-cli (not a static compose). Manual start like
  # the rest; the first start clones and builds Mythic, so it takes a while.
  systemd.tmpfiles.rules = [ "d ${mythicDir} 0750 root root -" ];
  systemd.services.mythic = {
    description = "Mythic C2 via mythic-cli (podman, best-effort)";
    path = with pkgs; [
      podman
      podman-compose
      # mythic-cli may call `docker-compose` (v1 spelling); route it to
      # podman-compose so the shim is complete.
      (writeShellScriptBin "docker-compose" ''exec ${podman-compose}/bin/podman-compose "$@"'')
      gettext # podman-compose shells out to envsubst
      git
      go # mythic-cli is built with `make` on first start
      gnumake
      gcc
    ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = mythicDir;
      # mythic-cli talks to the Docker-compatible socket podman exposes.
      Environment = "DOCKER_HOST=unix:///run/docker.sock";
      ExecStartPre = "${mythicSetup}";
      ExecStart = "${mythicDir}/mythic-cli start";
      ExecStop = "${mythicDir}/mythic-cli stop";
      TimeoutStartSec = "1800"; # first run clones, builds mythic-cli, pulls images
    };
  };
}
