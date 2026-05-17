FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

ARG NODE_MAJOR=22
ARG YANKI_VERSION=2.0.9
ARG ANKI_CONNECT_SERVER_VERSION=0.2.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg git tini \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g "yanki@${YANKI_VERSION}" \
    && uv pip install --system "anki-connect-server==${ANKI_CONNECT_SERVER_VERSION}" uvicorn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY server.py /app/server.py
RUN chmod +x /app/entrypoint.sh

EXPOSE 8765

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
