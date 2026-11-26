#!/usr/bin/env bash
# Helpers compartidos por check-tools.sh e install-tools.sh.
# Todo lo que hay aca tiene que funcionar en Linux, macOS y Git Bash de Windows.

# --- sistema operativo y arquitectura -----------------------------------------

# Los prefijos de os que se aceptan en el campo 'install' del manifiesto.
# shellcheck disable=SC2034  # lo usa install-tools.sh (esta en el mismo scope)
OS_VARIANTS="linux|darwin|windows"

detect_os() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Linux) echo linux ;;
    Darwin) echo darwin ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT) echo windows ;;
    *) uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' ;;
  esac
}

detect_arch() {
  case "$(uname -m 2>/dev/null || echo unknown)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo aarch64 ;;
    armv7l | armv7) echo armv7 ;;
    *) uname -m 2>/dev/null || echo unknown ;;
  esac
}

# El directorio donde se instalan las herramientas del usuario (wrappers
# incluidos). Es el que tiene que estar en el PATH para poder llamarlas.
user_bin() {
  printf '%s' "${TOOLS_USER_BIN:-$HOME/.local/bin}"
}

# --- placeholders -------------------------------------------------------------
# {{OS}} linux | darwin | windows
# {{ARCH}} x86_64 | aarch64 | armv7
# {{GOARCH}} amd64 | arm64 (convención de Go: la usan muchas releases)
# {{EXT}} .exe en windows, vacio en el resto
# {{BINDIR}} /usr/local/bin en unix, $HOME/bin en windows

expand_placeholders() {
  local cmd="$1" os arch goarch ext bindir
  os="$(detect_os)"
  arch="$(detect_arch)"
  case "$arch" in
    x86_64) goarch="amd64" ;;
    aarch64) goarch="arm64" ;;
    armv7) goarch="armv7" ;;
    *) goarch="$arch" ;;
  esac
  case "$os" in
    windows) ext=".exe"; bindir="${TOOLS_USER_BIN:-$HOME/.local/bin}" ;;
    *) ext=""; bindir="${TOOLS_USER_BIN:-$HOME/.local/bin}" ;;
  esac
  cmd="${cmd//\{\{OS\}\}/$os}"
  cmd="${cmd//\{\{ARCH\}\}/$arch}"
  cmd="${cmd//\{\{GOARCH\}\}/$goarch}"
  cmd="${cmd//\{\{EXT\}\}/$ext}"
  cmd="${cmd//\{\{BINDIR\}\}/$bindir}"
  printf '%s' "$cmd"
}

# --- sudo ---------------------------------------------------------------------
# No existe en Windows, ni en contenedores donde ya sos root, ni siempre en
# macOS. Se usa solo cuando hace falta y esta disponible.

setup_sudo() {
# shellcheck disable=SC2034  # lo usa install-tools.sh (esta en el mismo scope)
  # 'SUDO' se define SIEMPRE. Con 'set -u', referenciar una variable sin
  # asignar aborta el script: en una maquina sin sudo (un contenedor sin
  # privilegios) el error era "SUDO: unbound variable" y el comando de
  # instalacion salia vacio, con un mensaje que no decía la causa real.
  SUDO=""
  if [ "$(id -u 2>/dev/null || echo 1000)" = "0" ]; then
    SUDO="" # ya es root
  elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi
}

# true si el metodo necesita privilegios de root
method_needs_sudo() {
  case "$1" in
    apt | dnf | apk | pacman) return 0 ;;
    *) return 1 ;;
  esac
}

# --- comparacion de versiones ------------------------------------------------
# 'sort -V' no existe en BSD/macOS. Esta comparacion si.

# separa un segmento de version en numero y sufijo.
#   "3"     -> numero "3",    sufijo ""
#   "3.0rc1" -> numero "3",    sufijo "rc1"
#   "v2"    -> numero "2",    sufijo ""
# El resultado queda en VN (numero) y VS (sufijo). Sin namerefs (bash 3.2).
split_version() {
  local v="$1"
  # prefijo no numerico: "v2" -> "2"
  while [ -n "$v" ]; do
    case "$v" in
      [0-9]*) break ;;
      *) v="${v#?}" ;;
    esac
  done
  # los digitos iniciales son el numero; el resto es el sufijo
  VN=""
  while [ -n "$v" ]; do
    case "$v" in
      [0-9]*) VN="$VN${v:0:1}"; v="${v:1}" ;;
      *) break ;;
    esac
  done
  VS="$v"
  [ -n "$VN" ] || VN="0"
}

# true si $1 (instalada) es >= $2 (requerida)
#
# Un sufijo no numerico marca una pre-release, que es MENOR que su release:
# "3.0rc1" < "3.0". Antes, el codigo borraba los no-digitos de cada
# segmento: "3.0rc1" quedaba "3.01" y se comparaba como mayor que "3.0".
version_ge() {
  local have="$1" want="$2"
  [ -n "$have" ] || return 1
  local -a h w
  local i n hv wv hs ws hn wn
  IFS='.' read -r -a h <<< "$have"
  IFS='.' read -r -a w <<< "$want"
  n=${#w[@]}
  [ ${#h[@]} -gt "$n" ] && n=${#h[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    hv="${h[$i]:-0}"
    wv="${w[$i]:-0}"
    split_version "$hv"; hn="$VN"; hs="$VS"
    split_version "$wv"; wn="$VN"; ws="$VS"
    if [ "$hn" -gt "$wn" ]; then return 0; fi
    if [ "$hn" -lt "$wn" ]; then return 1; fi
    # numeros iguales: decide el sufijo
    if [ -n "$hs" ] && [ -z "$ws" ]; then return 1; fi   # pre-release vs release
    if [ -z "$hs" ] && [ -n "$ws" ]; then return 0; fi   # release vs pre-release
    if [ -n "$hs" ] && [ -n "$ws" ] && [ "$hs" != "$ws" ]; then
      if LC_ALL=C awk -v a="$hs" -v b="$ws" 'BEGIN { exit !(("" a) > ("" b)) }'; then return 0; fi
      return 1
    fi
    i=$((i + 1))
  done
  return 0
}

# --- temporales ---------------------------------------------------------------
# 'mktemp' sin argumentos no funciona en macOS: pide un template.

mktemp_file() {
  mktemp "${TMPDIR:-/tmp}/my-skills.XXXXXX" 2>/dev/null || mktemp
}

# --- wrapper de docker --------------------------------------------------------
#(method=docker) En vez de instalar el binario, se crea un wrapper que corre
# la imagen. Ventajas: no se instala nada en la maquina, la version queda
# reproducible por el tag de la imagen, y es trivial de revertir.
#
# El wrapper corre la imagen con el directorio actual montado en /work, como el
# usuario actual (para que los archivos que escribe la herramienta no queden
# propiedad de root) y con HOME en /tmp (muchas imagenes usan HOME=/root, que
# el usuario mapeado no puede escribir).

# El contenido del wrapper. Va separado de la escritura para poder comparar
# con el que ya esta en disco: un wrapper que no cambio no se toca.
wrapper_content() {
  local name="$1" image="$2" in_cmd="$3"
  # el cache se monta desde el home: sin esto, npx y go run re-descargan
  # el paquete en cada invocacion
  local img_cache
  img_cache="$(printf '%s' "$image" | tr -c 'A-Za-z0-9._-' '_')"
  # 'in_cmd' es el comando DENTRO de la imagen. Si esta vacio, el wrapper no
  # pasa comando: el entrypoint de la imagen ya es la herramienta. Pasarle
  # el nombre igual lo rompia ("yamllint yamllint --version").
  cat <<EOF
#!/bin/sh
# Generado por dev-tooling. Corre $image en vez de instalar el binario.
CACHE="\${XDG_CACHE_HOME:-\$HOME/.cache}/my-skills/$img_cache"
mkdir -p "\$CACHE/npm" 2>/dev/null || true
# En Git Bash, \$PWD es /c/... y Docker Desktop no lo monta: convertir.
mount="\$PWD"
case "\$(uname -s 2>/dev/null || echo unknown)" in
  MINGW* | MSYS* | CYGWIN*)
    command -v cygpath >/dev/null 2>&1 && mount="\$(cygpath -w "\$PWD")"
    ;;
esac
exec docker run --rm -v "\$mount:/work" -w /work -u "\$(id -u):\$(id -g)" \\
  -e HOME=/tmp -e XDG_CACHE_HOME=/cache -e npm_config_cache=/cache/npm \\
  -v "\$CACHE:/cache" \\
  $image $in_cmd "\$@"
EOF
}

install_docker_wrapper() {
  local name="$1" image="$2" in_cmd="$3" target_dir="$4"
  mkdir -p "$target_dir" || return 1
  wrapper_content "$name" "$image" "$in_cmd" > "$target_dir/$name" || return 1
  chmod +x "$target_dir/$name" 2>/dev/null || return 1
  return 0
}

# --- formato del manifiesto ----------------------------------------------------
# Cada linea tiene que tener exactamente 7 campos. Un "|" de mas trunca el
# ultimo campo en silencio: el comando de instalacion queda malformado y el
# error aparece lejos de la causa ("no se pudo determinar el comando").
check_manifest_format() {
  local file="$1" bad
  bad="$(awk -F'|' '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    NF != 7 { printf "%s:%d: %d campos (deberian ser 7): %s\n", FILENAME, NR, NF, $0 }
  ' "$file")"
  if [ -n "$bad" ]; then
    printf '%s\n' "$bad" >&2
    return 1
  fi
  return 0
}

# true si el archivo es un wrapper generado por dev-tooling
is_our_wrapper() {
  local f="$1"
  [ -f "$f" ] || return 1
  grep -q 'Generado por dev-tooling' "$f" 2>/dev/null
}

# --- misc ---------------------------------------------------------------------

extract_version() {
  grep -oE '[0-9]+(\.[0-9]+)*' | head -1
}

detect_version() {
  local vcmd="$1" out="" cmd v
  [ -n "$vcmd" ] || return 1
  # el comando puede traer alternativas separadas por ';': se prueba la
  # primera que imprima una version. Sirve cuando el binario tiene nombres
  # distintos segun la plataforma ("fdfind" en Debian, "fd" en brew).
  local oldifs="$IFS"
  IFS=';'
  # shellcheck disable=SC2086  # se divide a proposito por ';'
  set -- $vcmd
  IFS="$oldifs"
  for cmd in "$@"; do
    cmd="$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$cmd" ] || continue
    out="$(bash -c "$cmd" 2>/dev/null)" || out=""
    if [ -z "$out" ]; then
      out="$(bash -lc "$cmd" 2>/dev/null)" || out=""
    fi
    [ -n "$out" ] || continue
    v="$(printf '%s\n' "$out" | extract_version)"
    [ -n "$v" ] || continue
    printf '%s\n' "$v"
    return 0
  done
  return 1
}
