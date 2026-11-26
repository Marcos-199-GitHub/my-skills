#!/usr/bin/env bash
#
# Corre un comando dentro de una imagen, con el proyecto montado.
#
#   docker-run.sh <imagen> [comando...]
#   docker-run.sh node:lts-alpine node --version
#   docker-run.sh python:3.13-slim python script.py
#
# Es el primitivo para usar un toolchain sin instalarlo en la maquina: nada
# se instala, la version la define el tag de la imagen, y es trivial de
# revertir.
#
# Monta el directorio actual en /work, corre como el usuario actual (para que
# los archivos que escribe no queden propiedad de root) y con HOME en /tmp
# (muchas imagenes usan HOME=/root, que el usuario mapeado no puede escribir).
#
set -uo pipefail

if [ $# -lt 1 ]; then
  printf 'uso: %s <imagen> [comando...]\n' "$(basename "$0")" >&2
  exit 2
fi

image="$1"
shift

if ! command -v docker >/dev/null 2>&1; then
  printf 'docker no esta instalado en esta maquina\n' >&2
  exit 1
fi

# En Git Bash de Windows, $PWD es /c/Users/marco y Docker Desktop no monta
# esa forma: hay que pasarla como ruta de Windows.
mount="$PWD"
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW* | MSYS* | CYGWIN*)
    if command -v cygpath >/dev/null 2>&1; then
      mount="$(cygpath -w "$PWD")"
    fi
    ;;
esac

exec docker run --rm \
  -v "$mount:/work" \
  -w /work \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  "$image" "$@"
