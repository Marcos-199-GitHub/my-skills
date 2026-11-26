#!/usr/bin/env bash
#
# Reporta el estado de las herramientas declaradas en un manifiesto.
# No instala nada. Salida: 0 si todo cumple, 1 si hay faltantes.
#
#   check-tools.sh [--scope user|project] [--manifest <ruta>]...
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

SCOPE_FILTER=""
MANIFESTS=()
PREFIX="${TOOLS_PREFIX:-$PWD/.tools}"
case "$PREFIX" in /*) ;; *) PREFIX="$PWD/$PREFIX" ;; esac

# el directorio del usuario va en el PATH: ahi se crean los wrappers, y sin
# esto el checker dice "FALTA" de una herramienta que el instalador dijo
# haber instalado
PATH="$(user_bin):$PATH"
export PATH

while [ $# -gt 0 ]; do
  case "$1" in
    --scope) shift; SCOPE_FILTER="${1:-}" ;;
    --manifest) shift; MANIFESTS+=("${1:-}") ;;
    -h|--help) printf 'Uso: check-tools.sh [--scope <scope>] [--manifest <ruta>]...\n'; exit 0 ;;
    *) printf 'opcion desconocida: %s\n' "$1" >&2; exit 2 ;;
    esac
  shift
done

[ ${#MANIFESTS[@]} -eq 0 ] && MANIFESTS=("$SKILL_DIR/assets/tools.conf")
[ -n "${TOOLS_MANIFEST:-}" ] && MANIFESTS+=("$TOOLS_MANIFEST")

for m in "${MANIFESTS[@]}"; do
  [ -f "$m" ] || { printf 'manifiesto no encontrado: %s\n' "$m" >&2; exit 1; }
  check_manifest_format "$m" || {
    printf 'el manifiesto %s tiene lineas mal formadas. Un "|" de mas trunca el comando en silencio\n' "$m" >&2
    exit 1
  }
done

PROBLEMS=0

for manifest in "${MANIFESTS[@]}"; do
  printf '\n=== %s\n' "$manifest"
  printf '%-14s %-14s %-12s %-10s %s\n' "HERRAMIENTA" "INSTALADA" "INTENCION" "METODO" "ESTADO"
  printf '%s\n' "-------------------------------------------------------------------------"

  while IFS='|' read -r name version scope method pkg vcmd _install; do
    case "$name" in
      '' | \#*) continue ;;
    esac
    [ -n "$version" ] || version="latest"
    [ -n "$scope" ] || scope="user"
    [ -n "$method" ] || method="none"
    [ -n "$vcmd" ] || vcmd="$pkg --version"

    [ -n "$SCOPE_FILTER" ] && [ "$SCOPE_FILTER" != "$scope" ] && continue

    if [ "$scope" = "project" ]; then
      have="$(PATH="$PREFIX/bin:$PATH" detect_version "$vcmd")" || have=""
    else
      have="$(detect_version "$vcmd")" || have=""
    fi

    if [ -z "$have" ]; then
      state="FALTA"
      PROBLEMS=$((PROBLEMS+1))
    elif [ "$version" = "latest" ] || [ "$version" = "lts" ]; then
      # canal flotante: sin pin no hay forma de saber si es la ultima sin
      # consultarle al gestor. Se informa, no se juzga.
      state="al dia*"
    elif version_ge "$have" "$version"; then
      state="ok"
    else
      state="DESACTUALIZADA"
      PROBLEMS=$((PROBLEMS+1))
    fi

    printf '%-14s %-14s %-12s %-10s %s\n' "$name" "${have:--}" "$version" "$method" "$state"
  done < "$manifest"
done

printf '\n'
if [ "$PROBLEMS" -eq 0 ]; then
  printf 'Todo en orden.\n'
  printf '* canal flotante: se actualiza cuando corres el instalador.\n'
  exit 0
fi
printf '%d herramienta(s) requieren atencion.\n' "$PROBLEMS"
printf 'Para instalar o actualizar: bash scripts/install-tools.sh\n'
exit 1
