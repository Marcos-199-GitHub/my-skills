#!/usr/bin/env bash
#
# Verifica que las entradas conciliadas ya no esten en el inbox local.
#
#   check-inbox.sh <id> [<id> ...]
#   INBOX=/ruta/al/inbox.md check-inbox.sh <id>
#
# Se llama al final de una conciliacion, con los IDs que se aplicaron o se
# descartaron. Sin IDs no puede verificar nada: es un error de uso.
#
set -uo pipefail

if [ $# -lt 1 ]; then
  printf 'uso: %s <id> [<id> ...]\n' "$(basename "$0")" >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
inbox="${INBOX:-$root/.learning/inbox.md}"

if [ ! -f "$inbox" ]; then
  printf 'no existe el inbox: %s\n' "$inbox" >&2
  exit 1
fi

status=0
for id in "$@"; do
  if grep -qF -- "## $id" "$inbox"; then
    printf '[ERROR] %s sigue en el inbox\n' "$id" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  printf 'inbox limpio: %s entrada(s) conciliada(s) ausentes\n' "$#"
fi
exit "$status"
