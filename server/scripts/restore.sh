#!/usr/bin/env bash
# Restore drill (blueprint §8.4):  FILE=backups/kalla-XXXX.dump ./scripts/restore.sh
# Restores into the running compose stack's database. Destructive: --clean
# drops existing objects first. Practice on a copy, never on production first.
set -euo pipefail
cd "$(dirname "$0")/.."

FILE=${FILE:?Set FILE to the dump path (decrypted .dump)}
test -s "$FILE"

set -a; source .env; set +a

case "$FILE" in
  *.age)
    command -v age >/dev/null || { echo "age is required for .age files"; exit 1; }
    PLAIN=$(mktemp)
    trap 'rm -f "$PLAIN"' EXIT
    age -d -o "$PLAIN" "$FILE"
    FILE="$PLAIN"
    ;;
esac

read -r -p "This replaces the current database. Type RESTORE to continue: " CONFIRM
[[ "$CONFIRM" == "RESTORE" ]] || { echo "Aborted."; exit 1; }

docker compose exec -T postgres pg_restore -U kalla -d kalla --clean --if-exists < "$FILE"
docker compose exec -T postgres psql -U kalla -d kalla -c 'SELECT count(*) FROM users;'
echo "Restore OK"