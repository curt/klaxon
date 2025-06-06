ARG MIX_ENV="prod"

### Build stage ###

FROM elixir:1.18.4-otp-26-alpine AS build

RUN apk add --no-cache git gcc g++ musl-dev make cmake postgresql-client

WORKDIR /opt/klaxon

RUN mix local.hex --force && \
    mix local.rebar --force

ARG MIX_ENV
ENV MIX_ENV="${MIX_ENV}"

COPY VERSION.default VERSION.full
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

RUN mkdir config
COPY config/config.exs config/$MIX_ENV.exs config/
RUN mix deps.compile

COPY priv priv
COPY assets assets
COPY lib lib
COPY .git .git
COPY Makefile VERSION ./
RUN make write-version
RUN mix assets.deploy && \
    mix compile

COPY config/runtime.exs config/
RUN mix phx.gen.release && \
    mix release

### Distribute stage ###

FROM alpine AS dist

ARG MIX_ENV

RUN apk --no-cache add postgresql-client libstdc++ openssl ncurses-libs imagemagick imagemagick-jpeg imagemagick-heic

RUN addgroup -g 1000 klaxon && \
    adduser -u 1000 -G klaxon -D -h /opt/klaxon klaxon

COPY --from=build --chown=klaxon:klaxon /opt/klaxon/_build/prod/rel/klaxon /opt/klaxon
COPY --chown=klaxon:klaxon ./docker-entrypoint.sh /opt/klaxon/docker-entrypoint.sh

USER klaxon

WORKDIR /opt/klaxon

ENTRYPOINT ./docker-entrypoint.sh
