# bioserver2 — File #2 game server

Lobby and session server for File #2, packaged with its own MariaDB instance.

Part of the [PS2 online server infrastructure](../README.md). This container
handles game logic only — authentication and the login pages are served by the
[DNAS container](../dnas/README.md).

Structurally identical to [bioserver1](../bioserver1/README.md); the two run
side by side on different ports with separate databases, so a fault in one
title cannot affect the other.

## What runs inside

| Component | Purpose |
|---|---|
| Java lobby + session server | Room listing, matchmaking, live game sessions |
| MariaDB 10.5 | Accounts, sessions, nicknames, message of the day |
| Apache + PHP | Serves this title's pages on the internal port |

## Ports

| Port | Purpose |
|---|---|
| 8200 | Lobby server |
| 8590 | Game session |
| 8080 | Apache (internal) |

## Configuration

Before building, replace `changeme` in:

- `Dockerfile` → `DB_PASSWORD`
- `docker-compose.yml` → `DB_PASSWORD`
- `Bioserver2-master/bioserver/config.properties` → `db_password`
- `Bioserver2-master/www/db_cred.php` → `$pass`

All four must match. In `config.properties`, also set `gs_ip` to the address
the client should use to reach the session server.

Note that this container's database is named `bioserver2`, and its
`db_cred.php` must point at the `bioserver2` host — not `bioserver1`.

## Running

```bash
docker compose up -d
docker logs -f bioserver2        # expect "server started"
```

Then attach the DNAS container to this network:

```bash
docker network connect bioserver2-master_default my-dnas-server
```

## Startup sequence

Identical to bioserver1: MariaDB starts, the user and grants are created from
the environment, the schema is imported **only if the database is empty**,
MariaDB is rebound to all interfaces, then Apache and the server JAR start.

## Testing status

File #2 was validated at unit and integration level. The full remote acceptance
run was performed on File #1, so remote play for this title has not yet been
exercised end to end.

## Source

`Bioserver2-master/` is the upstream project by gh0stl1ne (AGPL-3.0),
unmodified except for the credential placeholders and the database provisioning
statements that moved into `docker-entrypoint.sh`.
