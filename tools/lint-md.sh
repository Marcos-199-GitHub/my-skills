#!/usr/bin/env bash
#
# Lint de los .md del repo.
#
#   lint-md.sh [archivo...]
#
# Sin argumentos: revisa todos los .md versionados.
#
# Que corrige:
#   - Caracteres de alfabetos que no corresponden (CJK, cirilico, japones,
#     coreano). Esos son siempre un error de generacion.
#   - Palabras en ingles filtradas en la prosa (denylist curada con los casos
#     reales que aparecieron).
#   - Guion bajo dentro de una palabra: "querés_customizar". Los identificadores
#     en MAYUSCULAS (REPO_PATH, DO_NOT_TRACK) y el codigo en linea no cuentan.
#   - Heading sin linea en blanco despues: rompe el markdown.
#   - Code fences desbalanceados.
#   - Espacios al final de linea.
#
# Ignora: frontmatter, bloques de codigo, codigo en linea, y el indice
# generado del README (que esta en ingles por diseno).
#
# POR QUE ESTO ESTA EN AWK Y NO EN BASH: el lint corre en cada commit y en el
# CI. Con un proceso por linea (grep, sed, wc, tr) la validacion tardaba
# 28 segundos: 40.000 procesos para revisar 22 archivos. Ahora hay un awk por
# archivo y la validacion baja a menos de un segundo.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
WARNINGS=0

err()  { printf '  [ERROR] %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }
warn() { printf '  [warn]  %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }

# Palabras inglesas que se filtraron en la prosa. Curadas con incidentes
# reales: si aparece una nueva, se agrega.
ENGLISH_LEAKS='learned|proposed|reflecting|instead of|the way|should be|will be|can be|you can|need to|want to|it is|there is|of the|makes|halfway|walls of text|truly|frequently|enforce|knowledge|hot path'

# Un solo awk por archivo. Los bytes se leen en locale C (LC_ALL=C), asi que
# los alfabetos ajenos se detectan por byte: cirilico D0-DF, kana/CJK/hangul
# E3-ED. No es "todo lo no-ASCII": el espanol usa acentos (C2/C3) y el repo
# usa flechas y simbolos (E2).
lint_file() {
  local f="$1" base
  base="$(basename "$f")"

  if [ ! -r "$f" ]; then
    err "$f: no se puede leer"
    return
  fi

  local out line ne nw
  out="$(LC_ALL=C awk \
    -v base="$base" \
    -v file="$f" \
    -v leaks="$ENGLISH_LEAKS" '
    BEGIN {
      fence = 0; infm = 0; inidx = 0
      prev_head = 0; prev_n = 0; prev_ok = 0
      nleak = split(leaks, leakarr, "|")
      # la comilla simple va en una variable: el programa awk vive dentro de
      # comillas simples de bash, y una comilla simple lo cortaria
      SQ = sprintf("%c", 39)
      # los bytes de los alfabetos ajenos, en octal
      foreign = "\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337"
      foreign = foreign "\343\344\345\346\347\350\351\352\353\354\355"
      # un caracter de palabra para los limites: como el \b de grep, los
      # digitos tambien son caracteres de palabra
      wordish = "^[A-Za-z0-9_]$"
      # una letra (para arrancar una palabra): no incluye el guion bajo
      letterish = "^[A-Za-z]$"
      # una letra acentuada cuenta como letra (2 bytes UTF-8 >= 0x80)
      highish = "^[\200-\377]$"
    }

    # caracter de palabra (para los limites de las palabras filtradas)
    function isword(c) {
      return (c ~ wordish) || (c ~ highish)
    }
    # letra: arranca una palabra. El guion bajo no.
    function isletter(c) {
      return (c ~ letterish) || (c ~ highish)
    }
    # caracter que puede seguir a una letra dentro de la palabra
    function isinner(c) {
      return (c ~ wordish) || (c ~ highish)
    }
    # una palabra es "mayuscula" si no tiene minusculas. Las acentuadas se
    # distinguen por el segundo byte: C3 81-9A es A-Z acentuada, C3 A1-BA es
    # a-z acentuada.
    function iscaps(s, i, c, nx) {
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c ~ /^[a-z]$/) return 0
        if (c == "\303") {
          nx = substr(s, i + 1, 1)
          if (nx >= "\241" && nx <= "\272") return 0
        }
      }
      return 1
    }
    # el guion bajo dentro de una palabra, que no sea un identificador en
    # MAYUSCULAS. Devuelve la palabra encontrada, o "".
    function underscored(s, n, i, j, c, run) {
      i = 1
      while (i <= n) {
        c = substr(s, i, 1)
        if (isletter(c)) {
          j = i
          while (j <= n && isinner(substr(s, j, 1))) j++
          run = substr(s, i, j - i)
          if (index(run, "_") > 0 && !iscaps(run)) return run
          i = j
        } else {
          i++
        }
      }
      return ""
    }
    # una palabra filtrada en ingles, con los limites de \b
    function leaked(s, n, li, p, lp, pos, before, after) {
      for (li = 1; li <= nleak; li++) {
        p = leakarr[li]
        lp = length(p)
        pos = index(s, p)
        while (pos > 0) {
          before = (pos == 1) ? "" : substr(s, pos - 1, 1)
          after = substr(s, pos + lp, 1)
          if (!isword(before) && !isword(after)) return p
          rest = substr(s, pos + 1)
          pos = index(rest, p)
          if (pos > 0) pos = pos + 1
        }
      }
      return ""
    }

    {
      line = $0
      n = NR

      # un heading necesita linea en blanco despues: se verifica cuando se
      # lee la linea siguiente
      if (prev_ok && prev_head && length(line) > 0) {
        printf "  [ERROR] %s:%d: heading sin linea en blanco despues\n", file, prev_n
      }

      # el indice generado del README esta en ingles por diseno: se excluye
      # por bloque, siguiendo los marcadores linea a linea
      if (base == "README.md") {
        if (line == "<!-- skills:start -->") { inidx = 1; prev_ok = 0; next }
        if (line == "<!-- skills:end -->") { inidx = 0; prev_ok = 0; next }
        if (inidx) { prev_ok = 0; next }
      }

      # frontmatter: solo al principio
      if (n == 1 && line == "---") { infm = 1; prev_ok = 0; next }
      if (infm == 1) {
        if (line == "---") infm = 0
        prev_ok = 0
        next
      }

      # bloques de codigo: fences y contenido
      if (line ~ /^```/) { fence = 1 - fence; prev_ok = 0; next }
      if (fence == 1) { prev_ok = 0; next }

      # de aca en adelante los checks corren
      prev_ok = 1
      prev_n = n
      prev_head = (line ~ /^#{1,6} /)

      # para los checks de prosa, se saca el codigo en linea
      clean = line
      gsub(/`[^`]*`/, "", clean)

      # 1. alfabetos que no corresponden
      for (i = 1; i <= length(clean); i++) {
        c = substr(clean, i, 1)
        if (index(foreign, c) > 0) {
          printf "  [ERROR] %s:%d: caracteres de otro alfabeto. Casi siempre es texto corrupto: %s\n", file, n, line
          break
        }
      }

      # 2. palabras en ingles filtradas
      p = leaked(clean, length(clean))
      if (p != "") {
        printf "  [warn]  %s:%d: posible palabra en ingles filtrada en la prosa: %s\n", file, n, line
      }

      # 3. guion bajo dentro de una palabra (los identificadores en MAYUSCULAS
      #    y el codigo en linea no cuentan)
      bad = underscored(clean, length(clean))
      if (bad != "") {
        printf "  [warn]  %s:%d: guion bajo dentro de una palabra (%s%s%s): %s\n", file, n, SQ, bad, SQ, line
      }

      # 4. heading sin linea en blanco despues (verificado arriba, con la
      #    linea siguiente)

      # 5. espacios al final y CRLF
      if (line ~ /[ \t]+$/) {
        printf "  [warn]  %s:%d: espacios al final de linea\n", file, n
      }
      if (line ~ /\r$/) {
        printf "  [warn]  %s:%d: CRLF: la linea termina en \\r\n", file, n
      }
    }

    END {
      # 6. fences desbalanceados
      if (fence != 0) {
        printf "  [ERROR] %s: code fences desbalanceados (falta cerrar un bloque)\n", file
      }
    }
  ' "$f")" || { err "$f: no se pudo leer"; return; }

  [ -n "$out" ] || return

  # los mensajes van a stderr (como los imprimia el script) y los contadores
  # se cuentan aca, sin procesos externos
  ne=0
  nw=0
  while IFS= read -r line; do
    case "$line" in
      '  [ERROR]'*) ne=$((ne + 1)) ;;
      '  [warn]'*) nw=$((nw + 1)) ;;
    esac
    printf '%s\n' "$line" >&2
  done <<< "$out"

  ERRORS=$((ERRORS + ne))
  WARNINGS=$((WARNINGS + nw))
}

# --- archivos a revisar --------------------------------------------------------

if [ $# -gt 0 ]; then
  files=("$@")
else
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(cd "$ROOT" && git ls-files '*.md' 2>/dev/null)
fi

printf 'Lint de markdown: %d archivo(s)\n\n' "${#files[@]}"

for f in "${files[@]}"; do
  if [ -f "$f" ]; then
    lint_file "$f"
  elif [ -f "$ROOT/$f" ]; then
    lint_file "$ROOT/$f"
  fi
done

printf '\n%d errores · %d warnings\n' "$ERRORS" "$WARNINGS" >&2
[ "$ERRORS" -eq 0 ] || exit 1
