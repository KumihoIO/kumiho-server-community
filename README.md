# Kumiho Server — Community Edition

**Kumiho Server CE** is a free, **single-user**, self-hosted edition of the Kumiho graph server. It runs entirely on your own machine, talks only to a local Neo4j (and an optional local Redis), and needs no account, token, or cloud connection.

> Use is governed by the [Community Edition EULA](./EULA.md). CE is licensed for **single-user, local** use — personal, development, internal, or commercial. Running it as a hosted, shared, multi-user, team, or production-backend service requires a separate commercial agreement.

## Install

**macOS / Linux**

```sh
curl -fsSL https://github.com/KumihoIO/kumiho-server-community/releases/latest/download/install.sh | sh
```

**Windows (PowerShell)**

```powershell
irm https://github.com/KumihoIO/kumiho-server-community/releases/latest/download/install.ps1 | iex
```

The installer downloads the latest release binary, **verifies its SHA-256 checksum (fail-closed)**, installs it to `~/.kumiho/bin`, and then launches the setup wizard.

## Setup — `onboard`

The installer hands off to the built-in onboarding wizard (run it again any time with `kumiho_server onboard`). It walks you through:

- your local username / email (used to attribute created data; defaults to your OS user),
- the Neo4j connection (port, database, credentials),
- an optional local Redis port (enables event streams),
- the server port (defaults to `127.0.0.1:9190`),
- optional OpenAI embeddings for vector / semantic search, and
- **EULA acceptance**.

It writes a permission-restricted config to `~/.kumiho/server.toml` plus a launch script, and can start the server right away.

> The server will not start until onboarding is complete and the EULA is accepted. A cold launch without it halts and points you back to `onboard`.

## Requirements

| Component | Needed? | Notes |
| --- | --- | --- |
| **Neo4j 5.x** | Required | Local instance; not bundled. |
| **Redis 7.x** | Optional | Enables event streams. |
| **OpenAI API key** | Optional | Enables embeddings / semantic search. |

Docker is a convenient way to run the databases locally:

```sh
docker run -d --name kumiho-neo4j -p 7687:7687 -p 7474:7474 \
  -e NEO4J_AUTH=neo4j/your-local-password neo4j:5
docker run -d --name kumiho-redis -p 6379:6379 redis:7
```

Point onboarding at the published host ports (`7687`, `6379`). Kumiho itself runs on the host, not inside the database containers.

## What CE is — and isn't

CE is a **single-user, loopback-only** build:

- The edition is locked at **compile time** — it cannot be reconfigured into a cloud or multi-tenant server.
- It binds only to `127.0.0.1` and refuses non-loopback peers.
- A built-in concurrency cap keeps one user smooth while refusing a second simultaneous user, so it is **not** a shared backend.
- It is **tokenless and unauthenticated**. The loopback / peer checks are *isolation*, not a security boundary — **never expose CE to a network or place it behind a proxy.**

There are **no data caps** — your single-user graph is unlimited.

## Verify a download manually

Every release ships `checksums.txt`:

```sh
sha256sum -c checksums.txt        # Linux
shasum -a 256 -c checksums.txt    # macOS
```

## Health check

With the server running:

```sh
curl http://127.0.0.1:9190/api/_live
# {"status":"ok","version":"x.y.z","deployment_mode":"self_hosted_ce"}
```

`GET /api/_health` additionally reports Neo4j, Redis, and embedding readiness.

## Documentation

The full runbook (`self-hosted-ce.md`) is included in every release archive and covers configuration, Docker, the Python SDK, and the security model.

## License

Community Edition is distributed in binary form under the [Community Edition EULA](./EULA.md). Team, hosted, multi-user, or production-backend use — and higher concurrency — require a separate commercial agreement: <https://kumiho.io/contact>.
