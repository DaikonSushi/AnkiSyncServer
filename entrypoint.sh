#!/usr/bin/env bash
set -euo pipefail

: "${ANKICONNECT_COLLECTION_PATH:=/data/collection.anki21}"
: "${ANKICONNECT_BIND:=0.0.0.0}"
: "${ANKICONNECT_PORT:=8765}"
: "${ANKI_CARDS_DIR:=/vault/AnkiCards}"
: "${YANKI_NAMESPACE:=MyObsidian}"
: "${YANKI_SYNC_INTERVAL_SECONDS:=900}"
: "${YANKI_SYNC_MEDIA:=local}"
: "${YANKI_ANKIWEB:=true}"
: "${YANKI_GIT_PULL:=true}"
: "${YANKI_ONCE:=false}"
: "${OBSIDIAN_GIT_REPO:=git@github.com:DaikonSushi/MyObsidian.git}"
: "${OBSIDIAN_GIT_BRANCH:=main}"
: "${OBSIDIAN_GIT_DIR:=/vault}"

export ANKICONNECT_COLLECTION_PATH
export ANKICONNECT_BIND
export ANKICONNECT_PORT

setup_git_ssh() {
  mkdir -p /tmp/ssh
  ssh-keyscan github.com > /tmp/ssh/known_hosts 2>/dev/null || true
  if [[ -f /root/.ssh/id_ed25519 ]]; then
    cp /root/.ssh/id_ed25519 /tmp/ssh/id_ed25519
    chmod 600 /tmp/ssh/id_ed25519
    export GIT_SSH_COMMAND="ssh -i /tmp/ssh/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=/tmp/ssh/known_hosts -o StrictHostKeyChecking=yes"
  else
    export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/tmp/ssh/known_hosts -o StrictHostKeyChecking=yes"
  fi
}

sync_obsidian_repo() {
  if [[ "$YANKI_GIT_PULL" != "true" ]]; then
    return
  fi

  setup_git_ssh

  if [[ -d "${OBSIDIAN_GIT_DIR}/.git" ]]; then
    echo "Updating Obsidian vault from ${OBSIDIAN_GIT_REPO}"
    git -C "$OBSIDIAN_GIT_DIR" fetch origin "$OBSIDIAN_GIT_BRANCH"
    git -C "$OBSIDIAN_GIT_DIR" checkout "$OBSIDIAN_GIT_BRANCH"
    git -C "$OBSIDIAN_GIT_DIR" pull --ff-only origin "$OBSIDIAN_GIT_BRANCH"
    return
  fi

  if [[ -n "$(find "$OBSIDIAN_GIT_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    echo "${OBSIDIAN_GIT_DIR} is not empty and is not a git checkout; cannot clone Obsidian vault." >&2
    exit 1
  fi

  echo "Cloning Obsidian vault from ${OBSIDIAN_GIT_REPO}"
  git clone --branch "$OBSIDIAN_GIT_BRANCH" --single-branch "$OBSIDIAN_GIT_REPO" "$OBSIDIAN_GIT_DIR"
}

if [[ ! -f "$ANKICONNECT_COLLECTION_PATH" ]]; then
  echo "Missing Anki collection: $ANKICONNECT_COLLECTION_PATH" >&2
  echo "Mount your collection.anki21 into /data/collection.anki21 first." >&2
  exit 1
fi

mkdir -p "$OBSIDIAN_GIT_DIR"
sync_obsidian_repo

if [[ ! -d "$ANKI_CARDS_DIR" ]]; then
  echo "Missing card directory: $ANKI_CARDS_DIR" >&2
  exit 1
fi

python -m uvicorn server:app \
  --host "$ANKICONNECT_BIND" \
  --port "$ANKICONNECT_PORT" &
server_pid="$!"

cleanup() {
  kill "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Waiting for AnkiConnect-compatible API..."
api_ready=false
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${ANKICONNECT_PORT}/api" \
    -H 'Content-Type: application/json' \
    -d '{"action":"version","version":6}' >/dev/null; then
    api_ready=true
    break
  fi
  sleep 1
done

if [[ "$api_ready" != "true" ]]; then
  echo "AnkiConnect-compatible API did not become ready." >&2
  exit 1
fi

run_sync() {
  sync_obsidian_repo

  echo "Running Yanki sync for $ANKI_CARDS_DIR"
  yanki sync "$ANKI_CARDS_DIR" \
    --namespace "$YANKI_NAMESPACE" \
    --anki-connect "http://127.0.0.1:${ANKICONNECT_PORT}/api" \
    --anki-web "$YANKI_ANKIWEB" \
    --sync-media "$YANKI_SYNC_MEDIA" \
    --json
}

run_sync

if [[ "$YANKI_ONCE" == "true" ]]; then
  exit 0
fi

while true; do
  sleep "$YANKI_SYNC_INTERVAL_SECONDS"
  run_sync || true
done
