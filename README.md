# PS2 Online Server Infrastructure — Containerized

A Docker-based deployment of the online server infrastructure for a 2003
PlayStation 2 survival-horror title whose official servers were retired years
ago. The stack was verified with a live cooperative session between two players
on geographically separate networks.

A personal project, later submitted as a graduation project for the Network
Technologies Diploma, Applied College, Imam Mohammad Ibn Saud Islamic
University, 2026.

> This project **deploys and modernizes** existing open-source server software.
> It does not reverse-engineer the game protocol. See [Credits](#credits).

---

## Background

Online play for this title depended on two independent layers, operated by two
different companies and retired years apart:

| Layer | Operator | Retired |
|---|---|---|
| Game and lobby servers | Capcom | Mar 2007 – Jun 2011 |
| DNAS authentication | Sony | Apr 2016 |

Because the layers were separate, restoration requires rebuilding both. That
separation is mirrored directly in the container layout below.

---

## Architecture

Three containers, each with a distinct role:

| Container | Responsibility | Ports |
|---|---|---|
| `my-dnas-server` | Legacy SSL authentication + PHP matchmaking pages for both titles | 443, 80 |
| `bioserver1` | Game logic for File #1, isolated MariaDB | 8300 (lobby), 8690 (session) |
| `bioserver2` | Game logic for File #2, isolated MariaDB | 8200 (lobby), 8590 (session) |

Connection sequence:

```
PS2 client
   │  ① DNAS authentication ............. my-dnas-server : 443
   │  ② matchmaking / login ............. my-dnas-server : 443
   │  ③ lobby ........................... bioserver1 : 8300  |  bioserver2 : 8200
   └─ ④ game session .................... bioserver1 : 8690  |  bioserver2 : 8590
```

**Only the DNAS container can talk to the console.** It runs Apache built from
source against OpenSSL 1.0.2u, the last branch that still offers the
`EDH-RSA-DES-CBC3-SHA` cipher the PS2 requires. The matchmaking pages for both
titles are served from there for the same reason — the game requests them over
HTTPS on port 443, which no modern Apache build can satisfy.

---

## Requirements

- Docker Desktop (or Docker Engine + Compose v2)
- PCSX2 emulator with a legitimate copy of the game
- Tailscale, or another WireGuard-based VPN, for remote play
- Roughly 3 GB of disk space for the built images

---

## Setup

### 1. Download the OpenSSL source

The DNAS image compiles OpenSSL 1.0.2u from source; the archive is not
committed to this repository.

```bash
cd dnas
wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz
```

The Dockerfile expects the file at `dnas/openssl-1.0.2u.tar.gz`.

### 2. Set your credentials

Every credential in this repository is the placeholder `changeme`. Replace it
with your own value in **all eight** locations:

| File | Key |
|---|---|
| `bioserver1/Dockerfile` | `DB_PASSWORD` |
| `bioserver1/docker-compose.yml` | `DB_PASSWORD` |
| `bioserver1/Bioserver1-master/bioserver/config.properties` | `db_password` |
| `bioserver1/Bioserver1-master/www/db_cred.php` | `$pass` |
| `bioserver2/…` | the same four |
| `dnas/DNASrep/www/dnas/00000002/db_cred.php` | `$pass` |
| `dnas/DNASrep/www/dnas/00000010/db_cred.php` | `$pass` |

> ⚠️ **The value must be identical everywhere.** The upstream project
> distributes the same placeholder across several files, and missing one is the
> single most common cause of `Access denied for user 'bioserver'@'localhost'`.
> > This bit me during development; see [Troubleshooting](#troubleshooting).

### 3. Set the advertised session-server address

In both `config.properties` files, replace `YOUR_SERVER_IP`:

```properties
gs_ip=100.x.x.x
```

This is the address the lobby server hands to the client when a session starts.
For LAN play use the host's local address; for remote play use the host's
Tailscale address.

> ⚠️ **Do not leave this as a loopback address.** The lobby does not carry game
> traffic — it only advertises where the session lives. A remote client given
> `127.0.0.1` will try to connect to its own machine and the session will never
> start.

### 4. Start the containers

```bash
cd dnas        && docker compose up -d
cd ../bioserver1 && docker compose up -d
cd ../bioserver2 && docker compose up -d
```

### 5. Connect the networks

Each Compose file creates its own network, so the DNAS container cannot resolve
the database hostnames until it is attached to both:

```bash
docker network connect bioserver1-master_default my-dnas-server
docker network connect bioserver2-master_default my-dnas-server
```

Verify with `docker network inspect bioserver1-master_default`.

> This manual step is a known limitation. Consolidating the three Compose files
> into one with a shared network would remove it.

### 6. Configure the client

In PCSX2: **Settings → Network & HDD → Ethernet**

- Enable Ethernet, device type **Sockets**
- Select your VPN adapter (e.g. Tailscale) as the Ethernet device
- Under **Internal DNS**, add:

| Hostname | Address |
|---|---|
| `gate1.jp.dnas.playstation.org` | your server address |
| `gate1.us.dnas.playstation.org` | your server address |
| `www01.kddi-mmbb.jp` | your server address |

Only the Japanese region has been tested — see [Limitations](#limitations).

---

## Verifying the deployment

```bash
# all three containers running
docker ps

# the Java servers are listening
docker exec -it bioserver1 ss -tulpn | grep -E '8300|8690'
docker exec -it bioserver2 ss -tulpn | grep -E '8200|8590'

# the database exists and holds the schema
docker exec -it bioserver1 mariadb -u root -e "SHOW TABLES FROM bioserver;"

# the DNAS endpoint rejects modern clients (expected)
wget https://127.0.0.1/          # should fail the TLS handshake
```

That last check is a feature, not a fault: the server is configured to offer
only the legacy cipher, so a modern client is supposed to be refused.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Access denied for user 'bioserver'@'localhost'` | The credential differs between `config.properties`, `db_cred.php` and the Docker environment | Make all of them identical (step 2) |
| `Access denied` persists after fixing the password | The database user exists only under the `%` host scope, while JDBC connects through `localhost` — MariaDB treats these as different accounts and matches the more specific host first | The entrypoint script creates both scopes; confirm with `SELECT user, host FROM mysql.user;` |
| Login page returns HTTP 500 | PHP configuration or a missing include | Check `docker logs my-dnas-server` and the Apache error log |
| DNAS container cannot query the database | The Compose networks are not connected | Run step 5 |
| Remote player reaches the lobby but the session never starts | `gs_ip` points at a loopback or LAN-only address | Set it to the VPN address (step 3) |
| Remote player cannot reach the server at all | Host firewall is blocking inbound traffic on the VPN interface | Allow the game ports on that interface |
| Player accounts disappear after a rebuild | The named volume was removed | Avoid `docker compose down -v`; `-v` deletes volumes |

---

## Repository layout

```
.
├── bioserver1/            File #1 game server
│   ├── Dockerfile             ← deployment work (this project)
│   ├── docker-compose.yml     ←
│   ├── docker-entrypoint.sh   ←
│   └── Bioserver1-master/     ← upstream source (gh0stl1ne, AGPL-3.0)
├── bioserver2/            File #2 game server, same layout
├── dnas/                  Authentication + matchmaking
│   ├── Dockerfile             ← deployment work (this project)
│   ├── docker-compose.yml     ←
│   └── DNASrep/               ← upstream source (gh0stl1ne, AGPL-3.0)
└── docs/                  Project report
```

Upstream source is kept in its original directory, unmodified except where
documented, so the boundary between the original work and this deployment stays
visible.

---

## What this project changed

The upstream code assumes a single machine. Three changes were needed to split
it across containers:

**Database provisioning moved out of the schema file.** Upstream
`bioserver.sql` created the database, the application user and its grants
inline, with the password written as a literal. A static SQL file cannot read
Docker environment variables, so those statements were reimplemented in
`docker-entrypoint.sh` using `${DB_USER}`, `${DB_PASSWORD}` and `${DB_NAME}`,
with `CREATE USER IF NOT EXISTS` so restarts stay idempotent. The file now holds
only the schema.

**Database host changed from loopback to container name.** Upstream
`db_cred.php` connected to `localhost`, correct when PHP and MariaDB share a
machine. Here PHP runs in the DNAS container and the databases in the game
containers, so the host is now `bioserver1` / `bioserver2` — which resolves only
because of the network step above. The same file was migrated from the `mysql_*`
functions, removed in PHP 7.0, to `mysqli_connect`.

**Per-title matchmaking directories published under the DNAS root.** The game
requests its pages by a fixed identifier compiled into the client — `/00000002/`
for File #1 and `/00000010/` for File #2. Since only the DNAS container can
serve the console over port 443, both directories live there, each with a
`db_cred.php` pointing at its own database.

---

## Limitations

1. Containers run several processes each; the upstream code assumes a local,
   always-available database.
2. The DNAS image is single-stage and still carries its build toolchain.
3. No unified orchestration — the shared network is connected manually.
4. Only the Japanese region certificate was tested.
5. Acceptance testing covered two players; the game supports four.
6. Credentials live in environment variables, not a secrets store.
7. The 3DES cipher and plaintext password storage are kept for client
   compatibility. **Do not expose this stack to the public internet.**
8. The advertised session address is fixed inside the image, so the deployment
   is bound to one VPN network.

---

## Credits

This project deploys and modernizes existing open-source work.

- **gh0stl1ne** ("ghostline") — the
  [Bioserver1](https://gitlab.com/gh0stl1ne/Bioserver1),
  [Bioserver2](https://gitlab.com/gh0stl1ne/Bioserver2) and
  [DNASrep](https://gitlab.com/gh0stl1ne/DNASrep) projects (AGPL-3.0), which
  provide the server codebase deployed here. The DNAS certificates in
  `dnas/DNASrep/etc/dnas/` also come from that repository.
- **the obsrv.org community** — protocol reconstruction documented since 2014,
  and the public client-side configuration guidance.
- **[Corbin](https://www.corbin.zip/outbreak-server/)** — a prior VM-based
deployment guide that was my first practical introduction to this subject.

No claim of original protocol reverse-engineering is made in this project.

---
> **Note:** The READMEs here were written by an AI. I broke the servers, fixed
> them, and told it what happened — it just made that sound organised.
---

## License

AGPL-3.0. The upstream projects are licensed under AGPL-3.0 and this work
inherits it. See `LICENSE`, and the per-directory `LICENSE.txt` files carried
over from upstream.
