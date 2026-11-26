#!/usr/bin/env bash
#
# Instalador idempotente de las herramientas declaradas en un manifiesto.
#
#   install-tools.sh [--dry-run] [--only <nombre>] [--scope user|project]
#                    [--manifest <ruta>]...
#
# El manifiesto por defecto es assets/tools.conf (el universal de la skill).
# Se pueden pasar varios: el universal mas el del proyecto.
#
# Garantias:
#   - Idempotente: solo toca lo que no cumple la intencion declarada.
#   - Nunca desinstala ni degrada nada.
#   - Re-verifica despues de instalar y falla si el resultado no es el esperado.
#   - Portable: Linux, macOS y Git Bash de Windows.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

DRY_RUN=0
ONLY=""
SCOPE_FILTER=""
MANIFESTS=()
PREFIX="${TOOLS_PREFIX:-$PWD/.tools}"
case "$PREFIX" in /*) ;; *) PREFIX="$PWD/$PREFIX" ;; esac

# El PATH de esta corrida incluye el directorio del usuario: los wrappers se
# crean ahi y, sin esto, la verificacion posterior no los encuentra y el
# instalador y el checker se contradicen sobre la misma herramienta.
PATH="$(user_bin):$PATH"
export PATH

usage() {
  cat <<'EOF'
Uso: install-tools.sh [--dry-run] [--only <nombre>] [--scope user|project]
                       [--manifest <ruta>]...

  --dry-run          Muestra el plan sin ejecutar nada.
  --only <nombre>    Procesa solo la herramienta indicada.
  --scope <scope>    Filtra por scope (user | project).
  --manifest <ruta>  Manifiesto a procesar. Se puede repetir; por defecto se
                     usa el universal de la skill.
  -h, --help         Esta ayuda.

Variables de entorno:
  TOOLS_MANIFEST     Manifiesto adicional (equivale a --manifest).
  TOOLS_PREFIX       Prefijo de instalacion para scope=project (default: ./.tools)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --only) shift; ONLY="${1:-}" ;;
    --scope) shift; SCOPE_FILTER="${1:-}" ;;
    --manifest) shift; MANIFESTS+=("${1:-}") ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'opcion desconocida: %s\n' "$1" >&2; usage >&2; exit 2 ;;
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

setup_sudo

# --- metodos ------------------------------------------------------------------

method_available() {
  case "$1" in
    apt) command -v apt-get >/dev/null 2>&1 ;;
    dnf) command -v dnf >/dev/null 2>&1 ;;
    apk) command -v apk >/dev/null 2>&1 ;;
    pacman) command -v pacman >/dev/null 2>&1 ;;
    brew) command -v brew >/dev/null 2>&1 ;;
    choco) command -v choco >/dev/null 2>&1 ;;
    scoop) command -v scoop >/dev/null 2>&1 ;;
    winget) command -v winget >/dev/null 2>&1 ;;
    npm) command -v npm >/dev/null 2>&1 ;;
    pipx) command -v pipx >/dev/null 2>&1 ;;
    pip) command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1 ;;
    cargo) command -v cargo >/dev/null 2>&1 ;;
    go) command -v go >/dev/null 2>&1 ;;
    script) return 0 ;;
    docker) command -v docker >/dev/null 2>&1 ;;
    auto) command -v docker >/dev/null 2>&1 ;;
    none) return 0 ;;
    *) return 1 ;;
  esac
}

# el comando de instalacion para un metodo. Usa $SUDO solo si hace falta.
install_command() {
  local method="$1" pkg="$2"
  case "$method" in
    apt) printf '%s apt-get install -y %s' "$SUDO" "$pkg" ;;
    dnf) printf '%s dnf install -y %s' "$SUDO" "$pkg" ;;
    apk) printf '%s apk add --no-cache %s' "$SUDO" "$pkg" ;;
    pacman) printf '%s pacman -S --noconfirm %s' "$SUDO" "$pkg" ;;
    brew) printf 'brew install %s' "$pkg" ;;
    choco) printf 'choco install -y %s' "$pkg" ;;
    scoop) printf 'scoop install %s' "$pkg" ;;
    winget) printf 'winget install --silent --accept-source-agreements %s' "$pkg" ;;
    npm) printf 'npm install -g %s' "$pkg" ;;
    pipx) printf 'pipx install %s' "$pkg" ;;
    pip) printf 'pip install --user %s' "$pkg" ;;
    cargo) printf 'cargo install %s' "$pkg" ;;
    go) printf 'go install %s' "$pkg" ;;
    *) printf '' ;;
  esac
}

# el comando de actualizacion de listas del gestor de paquetes
refresh_command() {
  case "$1" in
    apt) printf '%s apt-get update -qq' "$SUDO" ;;
    dnf) printf '%s dnf makecache -q' "$SUDO" ;;
    apk) printf '%s apk update -q' "$SUDO" ;;
    pacman) printf '%s pacman -Sy --noconfirm' "$SUDO" ;;
    *) printf '' ;;
  esac
}

# --- variantes por plataforma -------------------------------------------------
# El campo install puede llevar variantes: "linux=<cmd> ;; windows=<cmd>".
# Si no lleva variantes, es un comando universal.

select_variant() {
  local spec="$1" os
  os="$(detect_os)"
  case "$spec" in
    *=*) ;;
    *) printf '%s' "$spec"; return 0 ;;
  esac
  local hit
  hit="$(printf '%s\n' "$spec" | sed 's/;;/\n/g' | grep -E "^[[:space:]]*${os}=" | head -1 | sed -E "s/^[[:space:]]*${os}=[[:space:]]*//")"
  if [ -n "$hit" ]; then
    printf '%s' "$hit"
    return 0
  fi
  # variante generica (sin prefijo de os)
  # OJO: el filtro tiene que excluir SOLO los prefijos de os conocidos. Con
  # "cualquier cosa con =" se descartaba una variante generica legitima
  # ("VERSION=1 instalar") y el instalador abortaba sin motivo.
  hit="$(printf '%s\n' "$spec" | sed 's/;;/\n/g' | grep -vE "^[[:space:]]*(${OS_VARIANTS})=" | head -1 | sed -E 's/^[[:space:]]*//')"
  if [ -n "$hit" ]; then
    printf '%s' "$hit"
    return 0
  fi
  return 1
}

# --- preparacion: listas del gestor, una sola vez -----------------------------
# Con canales flotantes el comando de instalacion corre en cada pasada, asi
# que un update por herramienta seria lento. Va una vez, antes.
NEEDS_REFRESH=0
REFRESH_METHOD=""
for m in "${MANIFESTS[@]}"; do
  meth="$(grep -oE '\|(apt|dnf|apk|pacman)\|' "$m" | head -1 | tr -d '|')"
  if [ -n "$meth" ]; then
    NEEDS_REFRESH=1
    REFRESH_METHOD="$meth"
    break
  fi
done
if [ "$NEEDS_REFRESH" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  rc="$(refresh_command "$REFRESH_METHOD")"
  if [ -n "$rc" ]; then
    printf 'Actualizando listas de %s...\n' "$REFRESH_METHOD"
    bash -lc "$rc" >/dev/null 2>&1 || printf '  (la actualizacion fallo o no hace falta)\n'
  fi
fi

# --- loop ---------------------------------------------------------------------

CHANGED=0
SKIPPED=0
OMITTED=0
FAILED=0
PLANNED=0

for manifest in "${MANIFESTS[@]}"; do
  printf '\n=== manifiesto: %s\n' "$manifest"
  while IFS='|' read -r name version scope method pkg vcmd install; do
    case "$name" in
      '' | \#*) continue ;;
    esac
    [ -n "$version" ] || version="latest"
    [ -n "$scope" ] || scope="user"
    [ -n "$method" ] || method="none"
    [ -n "$vcmd" ] || vcmd="$pkg --version"

    [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
    [ -n "$SCOPE_FILTER" ] && [ "$SCOPE_FILTER" != "$scope" ] && continue

    printf '\n-- %s (%s, scope: %s, metodo: %s)\n' "$name" "$version" "$scope" "$method"

    if [ "$scope" = "project" ]; then
      mkdir -p "$PREFIX/bin" || { printf '   ERROR: no se pudo crear %s\n' "$PREFIX" >&2; FAILED=$((FAILED+1)); continue; }
      export PATH="$PREFIX/bin:$PATH"
      export TOOLS_PREFIX="$PREFIX"
    fi

    have="$(detect_version "$vcmd")" || have=""

    floating=0
    if [ "$version" = "latest" ] || [ "$version" = "lts" ]; then
      floating=1
      if [ -z "$have" ]; then state="MISSING"; else state="FLOATING"; fi
    elif [ -z "$have" ]; then
      state="MISSING"
    elif version_ge "$have" "$version"; then
      state="OK"
    else
      state="OUTDATED"
    fi

    case "$state" in
      OK)
        printf '   ya cumple (instalada: %s)\n' "$have"
        SKIPPED=$((SKIPPED+1))
        continue
        ;;
      FLOATING)
        printf '   instalada: %s (canal flotante: se verifica con el gestor)\n' "$have"
        ;;
      MISSING)
        printf '   no esta instalada\n'
        ;;
      OUTDATED)
        printf '   instalada %s, se requiere %s\n' "$have" "$version"
        ;;
    esac

    # --- metodo ---------------------------------------------------------------
    # method=docker/auto: se crea un wrapper (rama de abajo).
    # method=script: el comando sale del campo install.
    # Los demas: el metodo genera el comando. Si el metodo no existe en la
    # maquina pero el campo install trae una variante para este SO, se usa
    # esa: sin esto, una herramienta declarada con method=apt se omitia en
    # macOS (no hay apt-get) y se quedaba sin alternativa.
    if [ "$method" = "script" ] || ! method_available "$method"; then
      variant=""
      if [ -n "$install" ]; then
        variant="$(select_variant "$install")" || variant=""
      fi
      if [ -z "$variant" ]; then
        if [ "$method" = "script" ]; then
          printf '   ERROR: el campo install no tiene variante para %s\n' "$(detect_os)" >&2
          FAILED=$((FAILED+1))
          continue
        fi
        printf '   omitida: el metodo "%s" no existe en esta maquina y el campo install no tiene variante para %s\n' "$method" "$(detect_os)"
        OMITTED=$((OMITTED+1))
        continue
      fi
      if [ "$method" != "script" ]; then
        printf '   el metodo "%s" no existe aca: se usa la variante de install para %s\n' "$method" "$(detect_os)"
      fi
      cmd="$variant"
    else
      # el metodo existe en la maquina: se usa, con sudo si hace falta
      if method_needs_sudo "$method" && [ -z "$SUDO" ] \
        && [ "$(id -u 2>/dev/null || echo 1000)" != "0" ]; then
        printf '   omitida: "%s" necesita privilegios de root y esta maquina no tiene sudo. Instalala a mano o usa otro metodo\n' "$method"
        OMITTED=$((OMITTED+1))
        continue
      fi
      cmd="$(install_command "$method" "$pkg")"
    fi

    # method=docker o auto: en vez de instalar, se crea un wrapper que corre
    # la imagen. La diferencia:
    #   docker  siempre contenedor (toolchains: la reproducibilidad es el punto)
    #   auto    usa lo nativo si ya esta; el contenedor es el fallback
    #            (analizadores: un contenedor para algo que ya tenes es gasto)
    if [ "$method" = "docker" ] || [ "$method" = "auto" ]; then
      target_dir="$PREFIX/bin"
      [ "$scope" = "user" ] && target_dir="$(user_bin)"
      # si lo que se detecto es NUESTRO wrapper, se regenera: puede haber
      # quedado con la regla vieja (o con una imagen que cambio). Si lo que
      # se detecto es una instalacion nativa, se usa esa y no se crea nada.
      if [ "$method" = "auto" ] && [ -n "$have" ] \
        && ! is_our_wrapper "$target_dir/$name"; then
        printf '   ya esta instalada de forma nativa (%s): se usa esa, no el contenedor\n' "$have"
        SKIPPED=$((SKIPPED+1))
        continue
      fi
      # 'install' es el comando DENTRO de la imagen. Vacio = el entrypoint de
      # la imagen ya es la herramienta y no hay que pasar nada.
      in_cmd="$install"
      if [ "$DRY_RUN" -eq 1 ]; then
        if [ -n "$in_cmd" ]; then
          printf '   [dry-run] crearia wrapper %s -> docker run %s %s "$@"\n' "$target_dir/$name" "$pkg" "$in_cmd"
        else
          printf '   [dry-run] crearia wrapper %s -> docker run %s "$@"\n' "$target_dir/$name" "$pkg"
        fi
        PLANNED=$((PLANNED+1))
        continue
      fi
      # un wrapper que ya esta y es el mismo no se toca
      if [ -f "$target_dir/$name" ] && is_our_wrapper "$target_dir/$name" \
        && [ "$(cat "$target_dir/$name")" = "$(wrapper_content "$name" "$pkg" "$in_cmd")" ]; then
        printf '   ya esta al dia: wrapper en %s\n' "$target_dir/$name"
        SKIPPED=$((SKIPPED+1))
        continue
      fi
      if install_docker_wrapper "$name" "$pkg" "$in_cmd" "$target_dir"; then
        printf '   ok: wrapper en %s (imagen %s)\n' "$target_dir/$name" "$pkg"
        case ":$PATH:" in
          *":$target_dir:"*) ;;
          *) printf '   aviso: %s no esta en el PATH. Agregalo para poder llamar la herramienta\n' "$target_dir" ;;
        esac
        CHANGED=$((CHANGED+1))
      else
        printf '   ERROR: no se pudo crear el wrapper en %s\n' "$target_dir" >&2
        FAILED=$((FAILED+1))
      fi
      continue
    fi

    if [ -z "$cmd" ]; then
      printf '   ERROR: no se pudo determinar el comando de instalacion para "%s"\n' "$name" >&2
      FAILED=$((FAILED+1))
      continue
    fi
    cmd="$(expand_placeholders "$cmd")"

    # el destino tiene que ser escribible: /usr/local/bin no lo es para un
    # usuario normal, y el comando falla con un error de curl confuso
    dest_dir=
    dest_dir="$(printf '%s' "$cmd" | grep -oE '\{\{BINDIR\}\}|/usr/local/bin|\$HOME[^ ]*' | head -1)"
    case "$dest_dir" in
      *BINDIR* | /usr/local/bin | '$HOME'*)
        real_dir=
        real_dir="$(printf '%s' "$cmd" | sed "s@{{BINDIR}}@${TOOLS_USER_BIN:-$HOME/.local/bin}@g" | grep -F -o -- "${TOOLS_USER_BIN:-$HOME/.local/bin}" | head -1)"
        if [ -n "$real_dir" ] && [ ! -w "$(dirname "$real_dir")" ] && [ ! -w "$real_dir" ]; then
          printf '   ERROR: el destino %s no es escribible por este usuario. Ajusta TOOLS_USER_BIN o instalalo a mano\n' "$real_dir" >&2
          FAILED=$((FAILED+1))
          continue
        fi
        ;;
    esac

    if [ "$DRY_RUN" -eq 1 ]; then
      printf '   [dry-run] ejecutaria: %s\n' "$cmd"
      PLANNED=$((PLANNED+1))
      continue
    fi

    printf '   ejecutando: %s\n' "$cmd"
    if ! bash -lc "$cmd"; then
      printf '   ERROR: la instalacion fallo para %s\n' "$name" >&2
      FAILED=$((FAILED+1))
      continue
    fi

    newver="$(detect_version "$vcmd")" || newver=""
    if [ -z "$newver" ]; then
      printf '   ERROR: %s sigue sin detectarse despues de instalar\n' "$name" >&2
      FAILED=$((FAILED+1))
      continue
    fi
    if [ "$floating" -eq 0 ] && ! version_ge "$newver" "$version"; then
      printf '   ERROR: %s quedo en %s y se requiere %s\n' "$name" "$newver" "$version" >&2
      FAILED=$((FAILED+1))
      continue
    fi

    printf '   ok: %s\n' "$newver"
    CHANGED=$((CHANGED+1))
  done < "$manifest"
done

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n%d por instalar · %d sin cambios · %d omitidas · %d fallidas\n' \
    "$PLANNED" "$SKIPPED" "$OMITTED" "$FAILED"
else
  printf '\n%d actualizadas · %d sin cambios · %d omitidas · %d fallidas\n' \
    "$CHANGED" "$SKIPPED" "$OMITTED" "$FAILED"
fi
[ "$FAILED" -eq 0 ] || exit 1
