#!/usr/bin/env bash
# Nightly PostgreSQL backup (blueprint §11.5). Cron: 15 2 * * *
# Run from the server/ directory of the deployed stack.
#
# Required in .env: POSTGRES_PASSWORD
# Optional: AGE_PUBLIC_KEY (encrypt), RCLONE_REMOTE (copy off-server),
#           HEALTHCHECK_PING_URL (dead-man's-switch monitor)
set -euo pipefail
cd "$(dirname "$0")/.."

set -a; source .env; set +a

STAMP=$(date -u +%Y%m%d-%H%M)
DIR=./backups
FILE="$DIR/kalla-$STAMP.dump"
mkdir -p "$DIR"

docker compose exec -T postgres pg_dump -U kalla -Fc kalla > "$FILE"
test -s "$FILE" # fail loudly on an empty dump

# Encrypt before the file leaves this machine (recommended).
if [[ -n "${AGE_PUBLIC_KEY:-}" ]] && command -v age >/dev/null; then
  age -r "$AGE_PUBLIC_KEY" -o "$FILE.age" "$FILE"
  rm "$FILE"
  FILE="$FILE.age"
fi

# Copy OFF the server — a backup on the same machine is not a backup.
if [[ -n "${RCLONE_REMOTE:-}" ]] && command -v rclone >/dev/null; then
  rclone copy "$FILE" "$RCLONE_REMOTE/kalla-backups/daily/"
fi

# Keep 7 days locally; the off-server copy keeps the longer history.
find "$DIR" -name 'kalla-*' -mtime +7 -delete

if [[ -n "${HEALTHCHECK_PING_URL:-}" ]]; then
  curl -fsS -m 10 "$HEALTHCHECK_PING_URL" > /dev/null
fi

echo "Backup OK: $FILE"