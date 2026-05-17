#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

podman rm -f anki-yanki-sync >/dev/null 2>&1 || true
podman run -d --name anki-yanki-sync \
  --restart=unless-stopped \
  --env-file .env \
  -e ANKICONNECT_COLLECTION_PATH=/data/collection.anki21 \
  -e ANKICONNECT_BIND=0.0.0.0 \
  -e ANKICONNECT_PORT=8765 \
  -e ANKI_CARDS_DIR=/vault/AnkiCards \
  -e YANKI_NAMESPACE=MyObsidian \
  -e YANKI_GIT_PULL=true \
  -e OBSIDIAN_GIT_REPO=git@github.com:DaikonSushi/MyObsidian.git \
  -e OBSIDIAN_GIT_BRANCH=main \
  -e OBSIDIAN_GIT_DIR=/vault \
  -p 8765:8765 \
  -v obsidian-vault:/vault \
  -v "$PWD/data:/data:Z" \
  -v /root/.ssh:/root/.ssh:ro,z \
  anki-yanki-sync
