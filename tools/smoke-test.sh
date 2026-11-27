#!/usr/bin/env bash
#
# Smoke test de los scripts del repo.
#
#   bash tools/smoke-test.sh
#
# Corre sin red y sin docker: prueba las DECISIONES de los scripts (el
# formato del manifiesto, la comparacion de versiones, el contenido del
# wrapper, lo que el lint detecta), no las herramientas que instalan.
#
# Sale con 1 si algo fallo.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/environment/dev-tooling"

FAILURES=0
TMP="$(mktemp -d "${TMPDIR:-/tmp}/my-skills-test.XXXXXX" 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok() { printf '  [ok] %s\n' "$1"; }
ko() {
  printf '  [FAIL] %s\n' "$1"
  FAILURES=$((FAILURES + 1))
  return 0
}

# --- lib.sh -------------------------------------------------------------------
# shellcheck source=scripts/lib.sh
. "$SKILL/scripts/lib.sh"

echo "lib.sh"

# la comparacion de versiones: una pre-release es menor que su release
if version_ge "3.0rc1" "3.0"; then
  ko "3.0rc1 deberia ser menor que 3.0"
else
  ok "3.0rc1 < 3.0"
fi
if version_ge "3.0" "3.0rc1"; then
  ok "3.0 > 3.0rc1"
else
  ko "3.0 deberia ser mayor que 3.0rc1"
fi
if version_ge "v22.20.0" "22.20.0"; then
  ok "el prefijo v no cuenta"
else
  ko "v22.20.0 deberia ser >= 22.20.0"
fi
if version_ge "2.9" "2.10"; then
  ko "2.9 no es mayor que 2.10"
else
  ok "2.9 < 2.10"
fi
if version_ge "1.7.1" "1.10.0"; then
  ko "1.7.1 no es mayor que 1.10.0"
else
  ok "1.7.1 < 1.10.0"
fi
if version_ge "2.39.2" "2.39"; then
  ok "2.39.2 >= 2.39"
else
  ko "2.39.2 deberia ser >= 2.39"
fi
if [ "$(printf 'herramienta 7\n' | extract_version)" = "7" ]; then
  ok "extract_version acepta una sola cifra"
else
  ko "extract_version deberia aceptar una sola cifra"
fi

# el formato del manifiesto: un "|" de mas trunca el ultimo campo
printf 'a|latest|user|apt|pkg|cmd --version|\n' > "$TMP/ok.conf"
if check_manifest_format "$TMP/ok.conf"; then
  ok "manifiesto de 7 campos"
else
  ko "manifiesto de 7 campos"
fi
printf 'a|latest|user|apt|pkg|cmd --version|echo x | echo y\n' > "$TMP/bad.conf"
if check_manifest_format "$TMP/bad.conf" 2>/dev/null; then
  ko "manifiesto con un | de mas deberia fallar"
else
  ok "manifiesto con un | de mas rechazado"
fi

# el wrapper: si install esta vacio, no se pasa comando (el entrypoint de la
# imagen ya es la herramienta)
wrapper_content "gitleaks" "zricethezav/gitleaks:latest" "" > "$TMP/w1"
if grep -q 'zricethezav/gitleaks:latest  "\$@"' "$TMP/w1"; then
  ok "install vacio: el wrapper no pasa comando"
else
  ko "install vacio: el wrapper no deberia pasar comando"
fi
wrapper_content "prettier" "node:lts-alpine" "npx --yes prettier@latest" > "$TMP/w2"
if grep -q 'node:lts-alpine npx --yes prettier@latest "\$@"' "$TMP/w2"; then
  ok "install con comando: el wrapper lo pasa"
else
  ko "install con comando: el wrapper deberia pasarlo"
fi
wrapper_content "prettier" "node:lts-alpine" "" > "$TMP/w3"
if grep -q 'cygpath -w' "$TMP/w3" && grep -qF '$mount:/work' "$TMP/w3"; then
  ok "el wrapper convierte el mount en Git Bash"
else
  ko "el wrapper deberia convertir el mount en Git Bash"
fi

# el marcador del wrapper, para poder reconocer los nuestros
if grep -q 'Generado por dev-tooling' "$TMP/w1"; then
  ok "el wrapper se reconoce"
else
  ko "el marcador falta"
fi
if is_our_wrapper "$TMP/w1"; then
  ok "is_our_wrapper"
else
  ko "is_our_wrapper"
fi
if is_our_wrapper "$TMP/ok.conf" 2>/dev/null; then
  ko "is_our_wrapper: un archivo cualquiera no es wrapper"
else
  ok "is_our_wrapper: un archivo cualquiera no es wrapper"
fi

# --- lint-md.sh ---------------------------------------------------------------
echo "lint-md.sh"

printf 'Texto con cirilico: \320\237\321\200\320\270\320\262\320\265\320\202\n' > "$TMP/cyr.md"
if bash "$ROOT/tools/lint-md.sh" "$TMP/cyr.md" >/dev/null 2>&1; then
  ko "el lint deberia detectar el cirilico"
else
  ok "el lint detecta el cirilico"
fi

printf 'Texto con chino: \344\270\255\346\226\207\n' > "$TMP/cjk.md"
if bash "$ROOT/tools/lint-md.sh" "$TMP/cjk.md" >/dev/null 2>&1; then
  ko "el lint deberia detectar el CJK"
else
  ok "el lint detecta el CJK"
fi

printf '# Titulo\n\nTexto normal.\n' > "$TMP/ok.md"
if bash "$ROOT/tools/lint-md.sh" "$TMP/ok.md" >/dev/null 2>&1; then
  ok "un archivo limpio pasa"
else
  ko "un archivo limpio deberia pasar"
fi

# un archivo sin newline final no puede romper el lint
printf '# Sin newline' > "$TMP/nonl.md"
if bash "$ROOT/tools/lint-md.sh" "$TMP/nonl.md" >/dev/null 2>&1; then
  ok "un archivo sin newline final pasa"
else
  ko "un archivo sin newline final deberia pasar"
fi

# los warns no cambian el exit code: se comprueba el mensaje, no el estado
printf 'Texto con learned en la prosa.\n' > "$TMP/en.md"
out="$(bash "$ROOT/tools/lint-md.sh" "$TMP/en.md" 2>&1)"
if grep -q 'palabra en ingles filtrada' <<< "$out"; then
  ok "el lint detecta la palabra en ingles"
else
  ko "el lint deberia detectar la palabra en ingles"
fi

printf 'Texto con foo_bar en la prosa.\n' > "$TMP/us.md"
out="$(bash "$ROOT/tools/lint-md.sh" "$TMP/us.md" 2>&1)"
if grep -q 'guion bajo dentro de una palabra' <<< "$out"; then
  ok "el lint detecta el guion bajo"
else
  ko "el lint deberia detectar el guion bajo"
fi

printf 'Texto con CRLF\r\n' > "$TMP/crlf.md"
out="$(bash "$ROOT/tools/lint-md.sh" "$TMP/crlf.md" 2>&1)"
if grep -q 'CRLF' <<< "$out"; then
  ok "el lint detecta CRLF"
else
  ko "el lint deberia detectar CRLF"
fi

printf 'Texto con knowledge en la prosa.\n' > "$TMP/knowledge.md"
out="$(bash "$ROOT/tools/lint-md.sh" "$TMP/knowledge.md" 2>&1)"
if grep -q 'palabra en ingles filtrada' <<< "$out"; then
  ok "el denylist crece con los casos reales"
else
  ko "el denylist deberia cubrir knowledge"
fi

# un heading sin linea en blanco si cambia el exit code
printf '# Titulo\nTexto pegado.\n' > "$TMP/head.md"
if bash "$ROOT/tools/lint-md.sh" "$TMP/head.md" >/dev/null 2>&1; then
  ko "el lint deberia detectar el heading sin blanco"
else
  ok "el lint detecta el heading sin blanco"
fi

printf '```bash\necho hola\n' > "$TMP/fence.md"
if bash "$ROOT/tools/lint-md.sh" "$TMP/fence.md" >/dev/null 2>&1; then
  ko "el lint deberia detectar el fence sin cerrar"
else
  ok "el lint detecta el fence sin cerrar"
fi

printf 'Texto con espacio final.  \n' > "$TMP/trail.md"
out="$(bash "$ROOT/tools/lint-md.sh" "$TMP/trail.md" 2>&1)"
if grep -q 'espacios al final de linea' <<< "$out"; then
  ok "el lint detecta los espacios al final"
else
  ko "el lint deberia detectar los espacios al final"
fi

# la limpieza del inbox: el check falla si el ID conciliado sigue presente
echo "learning-reconcile (limpieza del inbox)"
checkinbox="$ROOT/skills/maintenance/learning-reconcile/scripts/check-inbox.sh"
printf '## L-2030-01-01-vm1\n\n- **tipo**: caso\n' > "$TMP/inbox.md"
if INBOX="$TMP/inbox.md" bash "$checkinbox" L-2030-01-01-vm1 >/dev/null 2>&1; then
  ko "un ID conciliado presente en el inbox deberia fallar"
else
  ok "un ID conciliado presente en el inbox se detecta"
fi
if INBOX="$TMP/inbox.md" bash "$checkinbox" L-2030-01-02-vm1 >/dev/null 2>&1; then
  ok "un ID ya limpio pasa"
else
  ko "un ID ya limpio deberia pasar"
fi

# --- validate.sh --------------------------------------------------------------
echo "validate.sh"

if bash "$ROOT/tools/validate.sh" >/dev/null 2>&1; then
  ok "el validador pasa"
else
  ko "el validador fallo"
fi

# el indice dice CUANDO se activa: ninguna fila puede quedarse sin la clausula
if awk '/<!-- skills:start -->/{f=1;next} /<!-- skills:end -->/{exit} f && /^\| `/ && $0 !~ /Use when/ {bad=1} END {exit (bad ? 0 : 1)}' "$ROOT/README.md"; then
  ko "el indice tiene filas sin la clausula de activacion"
else
  ok "todas las filas del indice dicen cuando se activa"
fi

# timeout portable: timeout(1) no existe en macOS. El vigilante NO se espera:
# esperarlo costaria los segundos completos aunque el comando terminara antes.
run_limited() {
  local secs="$1" outfile="$2"; shift 2
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" > "$outfile" 2>&1
    return $?
  fi
  "$@" > "$outfile" 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null ) &
  wait "$pid"
}

# cada caso negativo arranca de una copia limpia (VALIDATE_ROOT). Sin .git:
# copiarlo cuesta ~0,8 s en cinco casos y el validador solo lo usa para una
# check de documentacion que estos fixtures no ejercitan.
fresh_repo() {
  rm -rf "$TMP/repo"
  mkdir -p "$TMP/repo"
  (cd "$ROOT" && cp -R README.md AGENTS.md .gitignore .gitattributes \
    assets agents skills templates tools .github "$TMP/repo/") 2>/dev/null
}

# agregar un requires al frontmatter del fixture
add_requires() {
  local file="$1" req="$2" tmp="$3"
  awk -v r="$req" '{print} /^metadata:[[:space:]]*$/ && !done {print "  requires: \"" r "\""; done=1}' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# el check de fuentes derivadas se prueba sobre copias del repo: un marcador
# roto, una copia sin marcador, otra con reglas distintas y el formato del
# README divergente tienen que fallar. VALIDATE_ROOT no toca los reales.
echo "validate.sh (fuentes derivadas)"

fresh_repo
printf '\n<!-- source: work-protocol#regla-inexistente -->\n' >> "$TMP/repo/assets/global-agents-md.md"
out="$(VALIDATE_ROOT="$TMP/repo" bash "$ROOT/tools/validate.sh" 2>&1)"
if grep -q 'no matchea ninguna regla' <<< "$out"; then
  ok "un source con un rule-id inexistente se detecta"
else
  ko "un source con un rule-id inexistente deberia fallar"
fi

for derived in assets/global-agents-md.md agents/main-agent.md; do
  fresh_repo
  grep -v '<!-- source:' "$TMP/repo/$derived" > "$TMP/sin-marcador"
  mv "$TMP/sin-marcador" "$TMP/repo/$derived"
  out="$(VALIDATE_ROOT="$TMP/repo" bash "$ROOT/tools/validate.sh" 2>&1)"
  if grep -q 'falta el marcador de fuente derivada' <<< "$out"; then
    ok "$derived sin marcador se detecta"
  else
    ko "$derived sin marcador deberia fallar"
  fi
done

fresh_repo
grep -v 'check-the-blind-spots' "$TMP/repo/agents/main-agent.md" > "$TMP/agente"
mv "$TMP/agente" "$TMP/repo/agents/main-agent.md"
out="$(VALIDATE_ROOT="$TMP/repo" bash "$ROOT/tools/validate.sh" 2>&1)"
if grep -q 'nombran reglas distintas' <<< "$out"; then
  ok "una copia con menos reglas se detecta"
else
  ko "una copia con menos reglas deberia fallar"
fi

fresh_repo
grep -v '^- \*\*tipo\*\*:' "$TMP/repo/README.md" > "$TMP/readme"
mv "$TMP/readme" "$TMP/repo/README.md"
out="$(VALIDATE_ROOT="$TMP/repo" bash "$ROOT/tools/validate.sh" 2>&1)"
if grep -q 'el formato de entrada de learning divergio' <<< "$out"; then
  ok "el ejemplo del README sin 'tipo' se detecta"
else
  ko "el ejemplo del README sin 'tipo' deberia fallar"
fi

# un ciclo que no incluye a la skill validada colgaba al validador: la
# recursion se reemplazo por DFS con visitados. Sin timeout(1) en macOS.
echo "validate.sh (ciclos de dependencias)"
fresh_repo
add_requires "$TMP/repo/skills/behavior/subagent-delegation/SKILL.md" dev-tooling "$TMP/req1"
add_requires "$TMP/repo/skills/environment/dev-tooling/SKILL.md" environment-setup "$TMP/req2"
VALIDATE_ROOT="$TMP/repo" run_limited 5 "$TMP/ciclo.out" bash "$ROOT/tools/validate.sh"
rc=$?
out="$(cat "$TMP/ciclo.out")"
if [ "$rc" -ne 0 ] && grep -q 'ciclo de dependencias' <<< "$out"; then
  ok "un ciclo desconectado se detecta sin colgar"
else
  ko "un ciclo desconectado deberia detectarse sin colgar (rc=$rc)"
fi

# frontmatter e infra: una sola copia con varias mutaciones. Cada corrida del
# validador cuesta ~0,4 s y los errores se acumulan, asi que se agrupan.
echo "validate.sh (frontmatter e infra)"
fresh_repo
sd="$TMP/repo/skills/behavior/subagent-delegation/SKILL.md"
awk '/^description:/ && !done {sub(/ Use when /, " Se activa cuando "); done=1} {print}' "$sd" > "$TMP/sd" && mv "$TMP/sd" "$sd"
awk '/^metadata:[[:space:]]*$/ && !done {print; print "  tags:"; print "    - uno"; done=1; next} {print}' "$sd" > "$TMP/sd" && mv "$TMP/sd" "$sd"
add_requires "$TMP/repo/skills/environment/dev-tooling/SKILL.md" subagent-delegation "$TMP/r1"
add_requires "$sd" skill-import "$TMP/r2"
esfile="$TMP/repo/skills/environment/environment-setup/SKILL.md"
sed 's/`dev-tooling`/dev-tooling/g' "$esfile" > "$TMP/es" && mv "$TMP/es" "$esfile"
out="$(VALIDATE_ROOT="$TMP/repo" bash "$ROOT/tools/validate.sh" 2>&1)"
for msg in "no incluye 'Use when ...'" "no es un string" \
  "no aparece entre backticks" "mas de dos niveles"; do
  if grep -qF "$msg" <<< "$out"; then
    ok "$msg se detecta"
  else
    ko "$msg deberia fallar"
  fi
done

fresh_repo
grep -v '^\*\.sh text eol=lf' "$TMP/repo/.gitattributes" > "$TMP/ga" && mv "$TMP/ga" "$TMP/repo/.gitattributes"
sed 's/validate.sh --check/validate.sh/' "$TMP/repo/.github/workflows/validate.yml" > "$TMP/wf" && mv "$TMP/wf" "$TMP/repo/.github/workflows/validate.yml"
out="$(VALIDATE_ROOT="$TMP/repo" bash "$ROOT/tools/validate.sh" 2>&1)"
if grep -q 'no fuerza LF' <<< "$out"; then
  ok ".gitattributes sin eol=lf se detecta"
else
  ko ".gitattributes sin eol=lf deberia fallar"
fi
if grep -q 'no corre validate.sh --check' <<< "$out"; then
  ok "workflow sin --check se detecta"
else
  ko "workflow sin --check deberia fallar"
fi

# --- decisiones de versiones y de los scripts ---------------------------------
echo "check-tools.sh e install-tools.sh"

# detect_version prueba alternativas sin depender de lo que haya instalado
out="$(detect_version 'printf "herramienta 1.2.3\n"')"
if [ "$out" = "1.2.3" ]; then
  ok "detect_version extrae la version"
else
  ko "detect_version no extrajo la version: $out"
fi
out="$(detect_version 'false; printf "otra 2.4.0\n"')"
if [ "$out" = "2.4.0" ]; then
  ok "detect_version prueba alternativas"
else
  ko "detect_version no probo la alternativa: $out"
fi

# un manifiesto con comandos falsos: las decisiones se prueban sin tocar el
# entorno. Correr los scripts reales costaba 18 s en detectar versiones de
# wrappers de docker y npm; aca todo es un printf.
printf 'herramienta-falsa|latest|user|apt|paquete-falso|printf "1.0.0\\n"|\n' > "$TMP/tools.conf"
if bash "$SKILL/scripts/install-tools.sh" --dry-run --manifest "$TMP/tools.conf" >/dev/null 2>&1; then
  ok "el instalador en dry-run planea con un manifiesto falso"
else
  ko "el instalador en dry-run fallo con el manifiesto falso"
fi
if bash "$SKILL/scripts/check-tools.sh" --manifest "$TMP/tools.conf" >/dev/null 2>&1; then
  ok "el checker acepta una herramienta con canal flotante"
else
  ko "el checker rechazo una herramienta falsa que cumple"
fi

printf 'herramienta-falsa|9.9.9|user|apt|paquete-falso|printf "1.0.0\\n"|\n' > "$TMP/tools-old.conf"
if bash "$SKILL/scripts/check-tools.sh" --manifest "$TMP/tools-old.conf" >/dev/null 2>&1; then
  ko "el checker deberia reportar una version desactualizada"
else
  ok "el checker detecta la version desactualizada"
fi

# --- resultado ----------------------------------------------------------------
echo
if [ "$FAILURES" -eq 0 ]; then
  echo "Todo OK."
  exit 0
fi
printf '%d fallo(s).\n' "$FAILURES"
exit 1
