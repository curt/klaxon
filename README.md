# Klaxon

<https://github.com/curt/klaxon>

Klaxon aims to be a lightweight, single-author, blog-centric 
[ActivityPub](https://www.w3.org/TR/activitypub/) server. It is being developed 
using the excellent [Phoenix Framework](https://www.phoenixframework.org/) and 
is written mostly in [Elixir](https://elixir-lang.org/).

## Status

At the moment, Klaxon is, at best, pre-alpha code.
There is no meaningful documentation and no support.
Use it at your own risk.

## Architecture

- Core: Phoenix application (Elixir) with Ecto/PostgreSQL and binary UUIDs.
- Domains/contexts:
  - Auth: users, sessions, email confirmations, password resets.
  - Profiles: local profile (the single author), public remote profiles, RSA keys.
  - Contents: posts, labels/tags, attachments; RSS feed rendering.
  - Media: local/remote media handling via Waffle; default S3 storage.
  - Activities: ActivityPub verbs (Create, Follow/Undo, Like/Undo, Ping/Pong).
  - Federation: enqueue/send outbound activities; resolve followers.
  - Inbox/Outbox: controllers and workers to process AP traffic (Oban jobs).
  - Syndication: periodic jobs (Oban Cron) for email subscriptions.
  - Traces: GPX traces, waypoints, and views (PostGIS compatible schema).
  - Blocks: follower blocks.
- HTTP endpoints (selected):
  - Web: profile index (`/`), posts, places, traces, media, RSS (`/rss`).
  - ActivityPub: `/.well-known/webfinger`, `/inbox` (POST), `/outbox` (GET),
    `/followers`, `/following`, `/nodeinfo/*`.
  - API: authenticated owner-only JSON API under `/api` for posts, traces, places.
- Background jobs: Oban workers for inbox processing and outbound federation; Oban Cron
  for periodic syndication.
- Caching: Cachex for profile/post lookups.
- Storage/integration: PostgreSQL (with PostGIS features), Waffle + S3, Tesla/Hackney HTTP,
  HTTP Signatures, ImageMagick via `mogrify` for image processing.

## Quickstart (local dev)

Minimal steps to run locally with a Dockerized Postgres and Phoenix dev server.

Tip: run `mix klaxon` to list Klaxon-specific Mix tasks.

1) Prerequisites

- Erlang/OTP 26 and Elixir 1.15 (see `.tool-versions`).
- Docker (for running Postgres/PostGIS) or a local PostgreSQL with compatible settings.

2) Start Postgres (PostGIS) in Docker

```
docker run --name klaxon-db \
  -e POSTGRES_DB=klaxon_dev \
  -e POSTGRES_PASSWORD=my_password \
  -p 54320:5432 -d postgis/postgis:17-3.5-alpine
```

This matches `config/dev.exs` (host `localhost`, port `54320`, user `postgres`,
password `my_password`, database `klaxon_dev`). If you use a different setup,
adjust `config/dev.exs` accordingly.

3) Install dependencies and set up the database

```
mix deps.get
mix setup
```

4) Run the dev server

```
mix phx.server
```

Visit http://localhost:4000 — you should see a notice that no profile is configured yet.

5) Create a user (via UI)

- Open http://localhost:4000/users/register and create an account. In dev, emails
  are viewable at http://localhost:4000/dev/mailbox (adapter is local).

6) Create the local profile (first-run only)

Option A: use the Mix task:

```
mix klaxon.setup_profile --email you@example.com --name you --uri http://localhost:4000/
```

Option B: open IEx and create manually:

```
iex -S mix

u = Klaxon.Auth.get_user_by_email("you@example.com")
{:ok, _profile} = Klaxon.Profiles.create_local_profile(%{
  name: "you",
  uri:  "http://localhost:4000/"
}, u.id)
```

Reload http://localhost:4000 — you should now see your profile and can start posting.

Notes

- Media uploads use S3 by default via Waffle. Without AWS credentials in dev,
  avoid uploading media or switch storage in config as needed.
- For ActivityPub federation, run with a public URL and set `PHX_HOST` (and reverse proxy)
  in production; see `config/runtime.exs` for required env vars.

## Docker Compose Quickstart

Run the app as a release with Docker Compose.

1) Create `.env` in the repo root

Use real values in production. For a local test run, placeholders are fine for AWS/S3.

```
# Ports on your host
KLAXON_PORT=4000
POSTGRES_PORT=54320

# Database
POSTGRES_PASSWORD=change_me

# Phoenix + app
PHX_HOST=localhost
SECRET_KEY_BASE=$(openssl rand -base64 48)
MAIL_FROM=you@example.com

# S3 (required by Makefile; placeholders OK if not uploading)
AWS_ACCESS_KEY_ID=dummy
AWS_SECRET_ACCESS_KEY=dummy
AWS_REGION=us-east-1
AWS_S3_BUCKET=klaxon-dev-bucket
AWS_S3_DUMP_BUCKET=klaxon-dev-dumps
```

2) Start the database

The Makefile picks the correct PostGIS image for your CPU and exports it to Compose.

```
make up-db
```

3) Build the Klaxon image

This writes a version and tags both `klaxon:<computed>` and `klaxon:latest`.

```
make build
```

4) Start the app

```
make up
```

Open http://localhost:$KLAXON_PORT

5) Register a user and create the local profile

- Go to `/users/register` and create an account (login occurs immediately).
- Create the local profile via the release console:

```
docker compose exec app bin/klaxon remote

u = Klaxon.Auth.get_user_by_email("you@example.com")
{:ok, _profile} = Klaxon.Profiles.create_local_profile(%{
  name: "you",
  uri:  "http://localhost:#{System.get_env("KLAXON_PORT") || "4000"}/"
}, u.id)
:init.stop()
```

Refresh the homepage and you should see your profile.

Notes

- For proper URLs when accessed remotely, set `PHX_HOST` to your domain and front the app with HTTPS.
- Media uploads use S3 via Waffle. Without valid AWS creds/bucket, avoid uploads or switch storage in config.
- Useful targets: `make logs-app`, `make down`, `make clean`. See `Makefile` for more.

## Author

Klaxon is written and maintained by [Curt Gilman](https://github.com/curt).

## License

Copyright &copy; 2023-2025 Curt Gilman

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
