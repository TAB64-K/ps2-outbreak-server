# bioserver1 — File #1 game server

Lobby and session server for File #1, packaged with its own MariaDB instance.

Part of the [PS2 online server infrastructure](../README.md). This container
handles game logic only — authentication and the login pages are served by the
[DNAS container](../dnas/README.md).

## What runs inside

| Component | Purpose |
|---|---|
| Java lobby + session server | Room listing, matchmaking, live game sessions |
| MariaDB 10.5 | Accounts, sessions, nicknames, message of the day |
| Apache + PHP | Serves this title's pages on the internal port |

Built in two stages: the first compiles the Java sources into a JAR, the second
copies only the artifact into a slim runtime image.

## Ports

| Port | Purpose |
|---|---|
| 8300 | Lobby server |
| 8690 | Game session |
| 8081 | Apache (internal) |

## Configuration

Before building, replace `changeme` in:

- `Dockerfile` → `DB_PASSWORD`
- `docker-compose.yml` → `DB_PASSWORD`
- `Bioserver1-master/bioserver/config.properties` → `db_password`
- `Bioserver1-master/www/db_cred.php` → `$pass`

All four must match. In `config.properties`, also set `gs_ip` to the address
the client should use to reach the session server — the VPN address for remote
play, not a loopback address.

## Running

```bash
docker compose up -d
docker logs -f bioserver1        # expect "server started"
```

Then attach the DNAS container to this network so it can reach the database:

```bash
docker network connect bioserver1-master_default my-dnas-server
```

## Startup sequence

`docker-entrypoint.sh` runs on every start:

1. Start MariaDB and wait until it accepts connections
2. Create the database, user and grants from the environment variables
3. **Check whether the schema already has tables** — import `bioserver.sql`
   only if empty
4. Bind MariaDB to all interfaces and restart it
5. Start Apache
6. Launch the server JAR

Step 3 is what makes restarts safe. Combined with the named volume in
`docker-compose.yml`, rebuilding the container never erases player accounts.

## Database schema

| Table | Contents |
|---|---|
| `users` | Account IDs and passwords |
| `sessions` | Who is online, in which room and area |
| `hnpairs` | In-game nicknames |
| `motd` | Message of the day |

Inspect it live:

```bash
docker exec -it bioserver1 mariadb -u root -e "SHOW TABLES FROM bioserver;"
```

## Source

`Bioserver1-master/` is the upstream project by gh0stl1ne (AGPL-3.0),
unmodified except for the credential placeholders and the database provisioning
statements that moved into `docker-entrypoint.sh`. See the root README for
details.
