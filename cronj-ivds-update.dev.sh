#!/bin/bash

echo "[$(date)] Starting Invidious stack update..."

# Detect host IP for public_url
HOST_IP=$(hostname -I | awk '{print $1}')
echo "[$(date)] Detected host IP: $HOST_IP"

# Images
INVIDIOUS_IMAGE="quay.io/nthienquang199x/invidious:latest"
COMPANION_IMAGE="quay.io/nthienquang199x/invidious-companion:latest"
#INVIDIOUS_IMAGE="quay.io/invidious/invidious:2025.09.02-89c8b1b"
#COMPANION_IMAGE="quay.io/invidious/invidious-companion:master-30d9ac0"
DB_IMAGE="docker.io/library/postgres:14"

# Containers
INVIDIOUS_NAME="invidious"
COMPANION_NAME="invidious-companion"
DB_NAME="invidious-db"

# Local paths
BASE_DIR="/home/$USER/invidious"
DB_DIR="$BASE_DIR/postgresdata"
CACHE_DIR="$BASE_DIR/companioncache"

# Prepare folders
for dir in "$DB_DIR" "$CACHE_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "[$(date)] Creating folder $dir"
    mkdir -p "$dir"
    chown 999:999 "$dir"
  fi
done

# Pull latest images (only invidious and companion)
echo "[$(date)] Pulling latest Invidious & Companion images..."
docker pull $INVIDIOUS_IMAGE
docker pull $COMPANION_IMAGE

# Docker network (if not exists)
if ! docker network inspect invidious_default >/dev/null 2>&1; then
  echo "[$(date)] Creating network invidious_default"
  docker network create invidious_default
fi

# Start or create DB container
if ! docker inspect $DB_NAME >/dev/null 2>&1; then
  echo "[$(date)] Creating invidious-db..."
  docker run -d --name $DB_NAME     --restart unless-stopped     --network invidious_default     -v "$DB_DIR:/var/lib/postgresql/data"     -v "$(pwd)/config/sql:/config/sql"     -v "$(pwd)/docker/init-invidious-db.sh:/docker-entrypoint-initdb.d/init-invidious-db.sh"     -e POSTGRES_DB=invidious     -e POSTGRES_USER=kemal     -e POSTGRES_PASSWORD=kemal     --health-cmd='pg_isready -U kemal -d invidious'     --health-interval=30s     --health-timeout=5s     --health-retries=3     $DB_IMAGE
else
  echo "[$(date)] Starting existing invidious-db"
  docker start $DB_NAME >/dev/null
fi

# Recreate invidious-companion
if docker ps -a --format '{{.Names}}' | grep -wq "$COMPANION_NAME"; then
  echo "[$(date)] Removing old invidious-companion..."
  docker rm -f $COMPANION_NAME
fi

echo "[$(date)] Starting new invidious-companion..."
docker run -d --name $COMPANION_NAME   --restart unless-stopped   --network invidious_default   -p 0.0.0.0:8282:8282   -e SERVER_SECRET_KEY=ooP6eLai4quaiR8o   -e SERVER_BASE_PATH=/   --log-opt max-size=1G   --log-opt max-file=4   --cap-drop=ALL   --read-only   -v "$CACHE_DIR:/var/tmp/youtubei.js:rw"   --security-opt no-new-privileges:true   $COMPANION_IMAGE

# Recreate invidious
if docker ps -a --format '{{.Names}}' | grep -wq "$INVIDIOUS_NAME"; then
  echo "[$(date)] Removing old invidious..."
  docker rm -f $INVIDIOUS_NAME
fi

echo "[$(date)] Starting new invidious..."
docker run -d --name $INVIDIOUS_NAME   --restart unless-stopped   --network invidious_default   -p 0.0.0.0:3000:3000   --log-opt max-size=1G   --log-opt max-file=4     --env INVIDIOUS_CONFIG="$(cat <<EOF2
db:
  dbname: invidious
  user: kemal
  password: kemal
  host: invidious-db
  port: 5432
check_tables: true
invidious_companion:
  - private_url: "http://invidious-companion:8282"
    public_url: "http://$HOST_IP:8282"
invidious_companion_key: "ooP6eLai4quaiR8o"
hmac_key: "3brxHXsgCuzSmLTCNsTR"
EOF2
)"   $INVIDIOUS_IMAGE

echo "[$(date)] ✅ All containers are running with latest images."