#!/usr/bin/env bash
#
# Validador de la biblioteca de skills.
#
#   validate.sh            Valida todo.
#   validate.sh --write    Valida y regenera el indice del README.
#   validate.sh --check    Valida y falla si el indice del README esta viejo.
#   validate.sh --graph    Muestra el grafo de dependencias.
#
set -uo pipefail

# VALIDATE_ROOT permite correr el validador sobre una copia del repo: los
# checks nuevos se prueban con un caso negativo sin tocar los archivos reales.
ROOT="${VALIDATE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_DIR="$ROOT/skills"
README="$ROOT/README.md"

MODE="validate"
case "${1:-}" in
  --write) MODE="write" ;;
  --check) MODE="check" ;;
  --graph) MODE="graph" ;;
  "") MODE="validate" ;;
  -h|--help)
    printf 'Uso: validate.sh [--write|--check|--graph]\n'
    exit 0
    ;;
  *)
    printf 'opcion desconocida: %s\n' "$1" >&2
    exit 2
    ;;
esac

ERRORS=0
WARNINGS=0

err()  { printf '  [ERROR] %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }
warn() { printf '  [warn]  %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
note() { printf '  [nota]  %s\n' "$*"; }

# 'mktemp' sin argumentos pide un template en macOS
mktemp_file() {
  mktemp "${TMPDIR:-/tmp}/my-skills.XXXXXX" 2>/dev/null || mktemp
}

# --- parsers -----------------------------------------------------------------

# frontmatter de un archivo
fm() {
  awk 'NR==1 && $0 !~ /^---[[:space:]]*$/ {exit}
       NR>1 && $0 ~ /^---[[:space:]]*$/ {exit}
       NR>1 {print}' "$1"
}

# valor de una clave de primer nivel del frontmatter
fm_top() {
  fm "$1" | awk -v k="$2" '
    /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      key=$0; sub(/:.*/,"",key)
      if (key==k) { val=$0; sub(/^[^:]*:[[:space:]]*/,"",val); gsub(/^"|"$/,"",val); print val; exit }
    }'
}

# valor de una clave dentro de metadata:
fm_meta() {
  fm "$1" | awk -v k="$2" '
    /^metadata:[[:space:]]*$/ { inmeta=1; next }
    inmeta && /^[^[:space:]]/ { inmeta=0 }
    inmeta {
      line=$0; sub(/^[[:space:]]+/,"",line)
      if (index(line, k ":")==1) {
        sub("^"k":[[:space:]]*","",line); gsub(/^"|"$/,"",line); print line; exit
      }
    }'
}

# claves de metadata cuyo valor NO es un string (listas o mapas)
fm_meta_nonstring() {
  fm "$1" | awk '
    /^metadata:[[:space:]]*$/ { inmeta=1; next }
    inmeta && /^[^[:space:]]/ { inmeta=0 }
    inmeta {
      raw=$0
      match(raw, /[^[:space:]]/)
      ind=(RSTART ? RSTART - 1 : 0)
      line=raw; sub(/^[[:space:]]+/,"",line)
      if (line ~ /^[A-Za-z0-9_-]+:[[:space:]]*[\[{]/) { key=line; sub(/:.*/,"",key); print key; pending=""; next }
      if (pending != "") {
        if (line ~ /^-[[:space:]]/ || (ind > pind && line ~ /^[A-Za-z0-9_-]+:/)) {
          print pending; pending=""
        } else if (line ~ /^[A-Za-z0-9_-]+:/) pending=""
        next
      }
      if (line ~ /^[A-Za-z0-9_-]+:[[:space:]]*$/) { pending=line; sub(/:.*/,"",pending); pind=ind }
    }
    END { if (pending != "") print pending }'
}

# IDs de reglas con la forma ### [rule-id]
rule_ids() {
  grep -oE '^#{2,4}[[:space:]]+\[[a-z0-9][a-z0-9-]*\]' "$1" 2>/dev/null \
    | grep -oE '\[[a-z0-9][a-z0-9-]*\]' | tr -d '[]' | sort -u
}

# Reglas que nombra una copia derivada. El comodin [commit-*] se expande
# contra los IDs reales de work-protocol: sin eso, una copia que usa el
# comodin y otra que enumera las reglas parecerian distintas.
derived_rules() {
  local file="$1" refs rid pat id srcfile
  srcfile="$(skill_file_for work-protocol)" || srcfile=""
  refs="$(grep -oE '\[[a-z0-9][a-z0-9*-]*\]' "$file" 2>/dev/null | tr -d '[]' | sort -u)"
  while IFS= read -r rid; do
    [ -z "$rid" ] && continue
    case "$rid" in
      *'*'*)
        pat="${rid%\*}"
        [ -n "$srcfile" ] || continue
        while IFS= read -r id; do
          case "$id" in "$pat"*) printf '%s\n' "$id" ;; esac
        done <<< "$(rule_ids "$srcfile")"
        ;;
      *) printf '%s\n' "$rid" ;;
    esac
  done <<< "$refs" | sort -u | tr '\n' ' '
}

# contenido de una seccion "## Heading"
section() {
  awk -v h="$2" '
    index($0, "## " h) == 1 { infmt=1; next }
    infmt && /^## / { exit }
    infmt { print }' "$1"
}

# paths del tipo `references/x.md` citados en el body.
# Se ignoran los bloques de codigo: ahi los paths son ejemplos, no referencias.
referenced_paths() {
  awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    { print }
  ' "$1" | grep -oE '`(references|scripts|assets)/[A-Za-z0-9._/-]+`' \
    | tr -d '`' | sort -u
}

# paths de nivel repo citados en README.md o AGENTS.md
referenced_repo_paths() {
  awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    { print }
  ' "$1" | grep -oE '`(skills|tools|agents|assets|templates)/[A-Za-z0-9._/-]+`' \
    | tr -d '`' | sort -u
}

# Verifica los paths citados en un archivo.
#   $1  archivo donde se cita
#   $2  directorio base para resolver los paths relativos
#   $3  etiqueta para los mensajes
# Devuelve 1 si encontro algun path roto.
check_cited_paths() {
  local file="$1" dir="$2" label="$3" p rc=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ -e "$dir/$p" ]; then
      continue
    elif [ "$dir" != "$ROOT" ] && [ -e "$ROOT/$p" ]; then
      note "$label: '$p' se resuelve contra la raiz del repo, no contra la skill"
    elif path_in_repo "$p"; then
      note "$label: '$p' es una referencia cruzada (existe en otra skill). Aclarar a que skill pertenece"
    else
      err "$label: cita '$p' pero no existe"
      rc=1
    fi
  done < <(referenced_paths "$file")
  return $rc
}

# true si el path existe en alguna skill del repo (referencia cruzada)
path_in_repo() {
  local p i
  for i in "${!SKILL_DIRS[@]}"; do
    [ -e "${SKILL_DIRS[$i]}/$1" ] && return 0
  done
  return 1
}

# skill IDs referenciados en un bloque de permissions (action: skill)
fm_skill_permissions() {
  fm "$1" | awk '
    /^[[:space:]]*-[[:space:]]*action:[[:space:]]*skill/ { want=1; next }
    want && /^[[:space:]]*resource:[[:space:]]*/ {
      sub(/^[[:space:]]*resource:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; want=0; next
    }
    want && /^[[:space:]]*-[[:space:]]*action:/ { want=0 }
  '
}

# campos del formato de entrada de learning, en el bloque que sigue a un
# encabezado "## L-". Hace falta acotar al bloque: el documento puede tener
# otros "- **campo**:" que no son del formato de la entrada.
inbox_block_fields() {
  awk '
    /^[[:space:]]*#+[[:space:]]+L-/ { inblock=1; next }
    inblock {
      if ($0 ~ /^[[:space:]]*-[[:space:]]*\*\*[a-z_-]+\*\*[[:space:]]*:/) {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]*\*\*/, "", line)
        sub(/\*\*.*$/, "", line)
        print line
        next
      }
      if ($0 !~ /^[[:space:]]*$/) inblock=0
    }
  ' "$1" 2>/dev/null | sort -u
}

csv() { tr ',' '\n' <<< "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'; }

# --- carga de skills ---------------------------------------------------------

SKILL_NAMES=()
SKILL_CATS=()
SKILL_DIRS=()
SKILL_FILES=()

load_skills() {
  [ -d "$SKILLS_DIR" ] || { err "no existe el directorio de skills: $SKILLS_DIR"; return 1; }
  local dir cat name file
  while IFS= read -r dir; do
    cat="$(basename "$(dirname "$dir")")"
    name="$(basename "$dir")"
    file="$dir/SKILL.md"
    SKILL_CATS+=("$cat"); SKILL_NAMES+=("$name")
    SKILL_DIRS+=("$dir");  SKILL_FILES+=("$file")
  done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -type d | sort)
  return 0
}

skill_exists() {
  local n
  for n in "${SKILL_NAMES[@]}"; do [ "$n" = "$1" ] && return 0; done
  return 1
}

skill_file_for() {
  local i
  for i in "${!SKILL_NAMES[@]}"; do [ "${SKILL_NAMES[$i]}" = "$1" ] && { printf '%s\n' "${SKILL_FILES[$i]}"; return 0; }; done
  return 1
}

# --- validacion --------------------------------------------------------------

validate() {
  local i cat name file dir
  local fmname desc meta_cat req ovr

  printf 'Validando %d skills...\n\n' "${#SKILL_NAMES[@]}"

  for i in "${!SKILL_NAMES[@]}"; do
    cat="${SKILL_CATS[$i]}"; name="${SKILL_NAMES[$i]}"
    file="${SKILL_FILES[$i]}"; dir="${SKILL_DIRS[$i]}"

    if [ ! -f "$file" ]; then
      err "$cat/$name: falta SKILL.md"
      continue
    fi

    local problems=0

    # 1. frontmatter presente
    if [ -z "$(fm "$file")" ]; then
      err "$cat/$name: sin frontmatter o frontmatter vacio"
      problems=1
    fi

    # 2. name
    fmname="$(fm_top "$file" name)"
    if [ -z "$fmname" ]; then
      err "$cat/$name: falta 'name' en el frontmatter"
      problems=1
    elif [ "$fmname" != "$name" ]; then
      err "$cat/$name: 'name' ($fmname) no coincide con la carpeta ($name)"
      problems=1
    elif ! grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' <<< "$fmname"; then
      err "$cat/$name: 'name' no es kebab-case valido: $fmname"
      problems=1
    elif [ "${#fmname}" -gt 64 ]; then
      err "$cat/$name: 'name' supera los 64 caracteres"
      problems=1
    elif ! grep -q -- '-' <<< "$fmname"; then
      warn "$cat/$name: 'name' tiene una sola palabra. Conviene que se entienda solo"
    fi

    # 3. description
    desc="$(fm_top "$file" description)"
    if [ -z "$desc" ]; then
      err "$cat/$name: falta 'description'. Sin ella la skill no se anuncia al modelo"
      problems=1
    elif [ "${#desc}" -gt 1024 ]; then
      err "$cat/$name: 'description' supera los 1024 caracteres"
      problems=1
    elif [ "${#desc}" -lt 30 ]; then
      warn "$cat/$name: 'description' muy corta. Decí QUE hace y CUANDO usarla"
    elif ! grep -q 'Use when' <<< "$desc"; then
      err "$cat/$name: 'description' no incluye 'Use when ...'. Es la clausula que dispara la carga de la skill"
      problems=1
    elif grep -qE '(^|[^a-z])(cuando|usar|para|antes|despues|después)([^a-z]|$)' <<< "$desc"; then
      err "$cat/$name: 'description' tiene palabras en español: va en ingles"
      problems=1
    fi
    # un '|' en la description rompe la tabla markdown del indice del README
    case "$desc" in
      *'|'*)
        err "$cat/$name: la description tiene un '|'. Rompe la tabla del indice del README"
        problems=1
        ;;
    esac
    # una description multilinea (YAML '>' o '|') se pierde: el parser solo
    # lee la primera linea y el valor queda siendo '>' o '|'
    case "$desc" in
      ">"* | "|"*)
        err "$cat/$name: la description es multilinea (YAML con '>' o '|'). El parser solo lee la primera linea"
        problems=1
        ;;
    esac

    # 3b. compatibility: campo opcional de la spec (max 500 caracteres)
    compat="$(fm_top "$file" compatibility)"
    if [ -n "$compat" ]; then
      if [ "${#compat}" -gt 500 ]; then
        err "$cat/$name: 'compatibility' supera los 500 caracteres"
        problems=1
      fi
      case "$compat" in
        ">"* | "|"*)
          err "$cat/$name: 'compatibility' es multilinea. Va en una sola linea"
          problems=1
          ;;
      esac
    fi

    # 4. metadata: todos los valores string
    local nonstring
    nonstring="$(fm_meta_nonstring "$file")"
    if [ -n "$nonstring" ]; then
      while IFS= read -r k; do
        err "$cat/$name: metadata.$k no es un string. La spec solo admite string -> string"
        problems=1
      done <<< "$nonstring"
    fi

    # 5. metadata.category == carpeta
    meta_cat="$(fm_meta "$file" category)"
    if [ -z "$meta_cat" ]; then
      err "$cat/$name: falta metadata.category"
      problems=1
    elif [ "$meta_cat" != "$cat" ]; then
      err "$cat/$name: metadata.category ($meta_cat) no coincide con la carpeta ($cat)"
      problems=1
    fi

    # 6. IDs duplicados
    local dup
    dup=0
    local j
    for j in "${!SKILL_NAMES[@]}"; do
      [ "$j" -le "$i" ] && continue
      [ "${SKILL_NAMES[$j]}" = "$name" ] && dup=1
    done
    if [ "$dup" -eq 1 ]; then
      err "$cat/$name: ID duplicado en el repo. El instalador se queda con el primero y descarta el otro"
      problems=1
    fi

    # 7. requires: existen, sin ciclos, y estan en ## Prerequisites
    req="$(fm_meta "$file" requires)"
    if [ -n "$req" ]; then
      local prereq_body
      prereq_body="$(section "$file" "Prerequisites")"
      local r
      while IFS= read -r r; do
        [ -z "$r" ] && continue
        if ! skill_exists "$r"; then
          err "$cat/$name: requires '$r' no existe en el repo"
          problems=1
        elif ! grep -qF -- "\`$r\`" <<< "$prereq_body"; then
          err "$cat/$name: requires '$r' no aparece entre backticks en '## Prerequisites'. Una mencion suelta no basta: el agente nunca ve el frontmatter"
          problems=1
        fi
        # ciclo: r no puede depender (directa ni indirectamente) de name
        if depends_on "$r" "$name"; then
          err "$cat/$name: ciclo de dependencias con '$r'"
          problems=1
        fi
      done <<< "$(csv "$req")"
    fi

    # 8. overrides: la base existe y la regla [id] existe en la base
    ovr="$(fm_meta "$file" overrides)"
    if [ -n "$ovr" ]; then
      local o base rule
      while IFS= read -r o; do
        [ -z "$o" ] && continue
        base="${o%%#*}"
        rule="${o#*#}"
        if [ "$base" = "$o" ]; then
          err "$cat/$name: override '$o' mal formado. Se espera base#rule-id"
          problems=1
          continue
        fi
        if ! skill_exists "$base"; then
          err "$cat/$name: override '$o' apunta a la skill inexistente '$base'"
          problems=1
          continue
        fi
        local basefile
        basefile="$(skill_file_for "$base")"
        if ! grep -qx -- "$rule" <<< "$(rule_ids "$basefile")"; then
          err "$cat/$name: override '$o' no matchea ninguna regla [rule-id] de '$base'"
          problems=1
        fi
      done <<< "$(csv "$ovr")"
    fi

    # 9. paths citados existen
    #    Se resuelven primero dentro de la skill; si no estan, en la raiz del
    #    repo (assets/ del repo es un nivel compartido, no de una skill).
    #    Se miran tambien los references/ de la skill: un path roto ahi no
    #    lo encuentra nadie hasta que el agente lo intenta.
    local p
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      if [ -e "$dir/$p" ]; then
        continue
      elif [ -e "$ROOT/$p" ]; then
        note "$cat/$name: '$p' se resuelve contra la raiz del repo, no contra la skill"
      elif path_in_repo "$p"; then
        note "$cat/$name: '$p' es una referencia cruzada (existe en otra skill). Aclarar a que skill pertenece"
      else
        err "$cat/$name: el body cita '$p' pero no existe"
        problems=1
      fi
    done < <(referenced_paths "$file")

    local rfile
    for rfile in "$dir"/references/*.md; do
      [ -f "$rfile" ] || continue
      check_cited_paths "$rfile" "$dir" "$cat/$name ($(basename "$rfile"))" || problems=1
    done

    # 10. tamaño
    local lines
    lines=$(wc -l < "$file" | tr -d ' ')
    if [ "$lines" -gt 500 ]; then
      err "$cat/$name: SKILL.md tiene $lines lineas (max 500). Movi el detalle a references/"
      problems=1
    fi

    if [ "$problems" -eq 0 ]; then
      printf '  [ok] %s/%s\n' "$cat" "$name"
    else
      printf '  [FAIL] %s/%s\n' "$cat" "$name"
    fi
  done

  # checks a nivel repo
  printf '\nChecks del repo:\n'

  # una skill va en skills/<categoria>/<nombre>/. Un directorio suelto en
  # skills/ es invisible para el validador (no entra al indice ni a las
  # revisiones) y el instalador lo toma como skill de primer nivel: la
  # biblioteca y lo que se instala dejan de coincidir.
  local stray n
  for stray in "$SKILLS_DIR"/*/; do
    [ -d "$stray" ] || continue
    if [ -f "$stray/SKILL.md" ]; then
      err "$(basename "${stray%/}"): esta en skills/ sin categoria. Va en skills/<categoria>/<nombre>/"
      continue
    fi
    n=0
    for d in "$stray"*/; do
      [ -d "$d" ] && n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then
      warn "$(basename "${stray%/}"): categoria sin skills"
    fi
  done

  # los paths citados en README.md y AGENTS.md tienen que existir: son la
  # puerta de entrada de la biblioteca y no hay otro que los revise
  local doc dp
  for doc in README.md AGENTS.md; do
    [ -f "$ROOT/$doc" ] || continue
    while IFS= read -r dp; do
      [ -z "$dp" ] && continue
      if [ ! -e "$ROOT/$dp" ]; then
        err "$doc: cita '$dp' pero no existe"
      fi
    done < <(referenced_repo_paths "$ROOT/$doc")
  done

  local gm="assets/global-agents-md.md"
  if [ ! -f "$ROOT/$gm" ]; then
    err "$gm no existe"
  else
    # los marcadores tienen que estar exactamente una vez cada uno: si el
    # payload se reimprime sobre si mismo, el de cierre queda duplicado
    local nb ne
    nb=$(grep -c '<!-- my-skills:begin -->' "$ROOT/$gm")
    ne=$(grep -c '<!-- my-skills:end -->' "$ROOT/$gm")
    if [ "$nb" -ne 1 ] || [ "$ne" -ne 1 ]; then
      err "$gm: debe tener 1 marcador begin y 1 marcador end (tiene $nb y $ne)"
    else
      printf '  [ok] %s\n' "$gm"
    fi
    # es una plantilla: la ruta del repo la sustituye el bootstrap
    if ! grep -q '{{REPO_PATH}}' "$ROOT/$gm"; then
      err "$gm no tiene {{REPO_PATH}}. Es una plantilla: si la ruta queda fija, el bootstrap de otra maquina instala una ruta rota"
    fi
  fi

  local li="assets/learning-inbox.md"
  if [ ! -f "$ROOT/$li" ]; then
    err "$li no existe"
  else
    printf '  [ok] %s\n' "$li"
  fi

  # el formato de entrada esta en varios archivos: si divergen, el agente
  # registra con un formato y la conciliacion espera otro. El campo 'tipo'
  # se habia perdido en dos de ellos sin que nada lo notara.
  local fmt_files=(
    "assets/global-agents-md.md"
    "assets/learning-inbox.md"
    "skills/behavior/work-protocol/assets/lessons-template.md"
    "skills/behavior/work-protocol/SKILL.md"
    "README.md"
  )
  local ff ref="" reff="" fcur
  for ff in "${fmt_files[@]}"; do
    [ -f "$ROOT/$ff" ] || continue
    fcur="$(inbox_block_fields "$ROOT/$ff" | tr '\n' ' ')"
    if [ -z "$fcur" ]; then
      err "$ff: no tiene el bloque de formato de la entrada (## L-... con los campos)"
      continue
    fi
    if [ -z "$ref" ]; then
      ref="$ff"
      reff="$fcur"
      continue
    fi
    if [ "$fcur" != "$reff" ]; then
      err "el formato de entrada de learning divergio entre $ref y $ff"
      err "  $ref: $reff"
      err "  $ff: $fcur"
    fi
  done

  # el manifiesto de herramientas: cada linea tiene que tener exactamente 7
  # campos. Un "|" de mas (un pipe en un comando) trunca la linea en
  # silencio y el comando queda mal formado.
  local tman="skills/environment/dev-tooling/assets/tools.conf"
  if [ -f "$ROOT/$tman" ]; then
    local nfields tname seen
    while IFS= read -r tline; do
      case "$tline" in
        '' | \#*) continue ;;
      esac
      nfields="$(printf '%s' "$tline" | awk -F'|' '{print NF}')"
      if [ "$nfields" -ne 7 ]; then
        err "$tman: una linea tiene $nfields campos y deberia tener 7. Un '|' de mas trunca el comando: $tline"
      fi
    done < "$ROOT/$tman"

    # los nombres no se repiten
    while IFS= read -r tname; do
      [ -z "$tname" ] && continue
      seen="$(grep -c "^$tname|" "$ROOT/$tman")"
      if [ "$seen" -gt 1 ]; then
        err "$tman: la herramienta '$tname' aparece $seen veces"
      fi
    done < <(grep -vE '^\s*(#|$)' "$ROOT/$tman" | cut -d'|' -f1 | sort -u)
    printf '  [ok] %s\n' "$tman"
  fi

  local ag="agents/main-agent.md"
  if [ ! -f "$ROOT/$ag" ]; then
    err "$ag no existe"
  elif ! grep -q 'primary' <<< "$(fm_top "$ROOT/$ag" mode)"; then
    err "$ag: falta 'mode: primary' en el frontmatter"
  else
    printf '  [ok] %s\n' "$ag"
  fi

  # las skills que el agente principal tiene permiso de cargar tienen que
  # existir: si se renombran, el permission se vuelve no-op y el system
  # prompt queda apuntando a algo inexistente
  if [ -f "$ROOT/$ag" ]; then
    local sid
    while IFS= read -r sid; do
      [ -z "$sid" ] && continue
      [ "$sid" = "*" ] && continue
      if ! skill_exists "$sid"; then
        err "$ag: el permission de la skill '$sid' no existe en la biblioteca"
      fi
    done < <(fm_skill_permissions "$ROOT/$ag")
  fi

  # Las copias derivadas declaran su fuente y nombran las mismas reglas. El
  # conjunto se recorre: un archivo nuevo en assets/ o agents/ que cite reglas
  # sin marcador, o una copia con reglas distintas, divergia sin ser vista.
  local derived src base rule srcfile dset dref="" dfile=""
  while IFS= read -r derived; do
    [ -f "$ROOT/$derived" ] || continue
    grep -qE '\[[a-z0-9][a-z0-9*-]*\]' "$ROOT/$derived" || continue
    if ! grep -qE 'source:[[:space:]]*[a-z0-9-]+#[a-z0-9-]+' "$ROOT/$derived"; then
      err "$derived: falta el marcador de fuente derivada (source: skill#rule-id) — cita reglas sin declarar su fuente"
    fi
    while IFS= read -r src; do
      [ -z "$src" ] && continue
      base="${src%%#*}"
      rule="${src#*#}"
      if [ "$base" = "$src" ]; then
        err "$derived: source '$src' mal formado. Se espera skill#rule-id"
        continue
      fi
      if ! skill_exists "$base"; then
        err "$derived: source '$src' apunta a la skill inexistente '$base'"
        continue
      fi
      srcfile="$(skill_file_for "$base")"
      if ! grep -qx -- "$rule" <<< "$(rule_ids "$srcfile")"; then
        err "$derived: source '$src' no matchea ninguna regla [rule-id] de '$base'"
      fi
    done < <(grep -oE 'source:[[:space:]]*[a-z0-9-]+#[a-z0-9-]+' "$ROOT/$derived" | sed -E 's/source:[[:space:]]*//')

    dset="$(derived_rules "$ROOT/$derived")"
    [ -n "$dset" ] || continue
    if [ -z "$dref" ]; then
      dref="$dset"; dfile="$derived"
    elif [ "$dset" != "$dref" ]; then
      err "las copias derivadas nombran reglas distintas: $dfile ($dref) vs $derived ($dset)"
    fi
  done < <(cd "$ROOT" && find assets agents -type f -name '*.md' | sort)

  if [ -f "$ROOT/$gm" ] && ! grep -q 'learning/inbox.md' "$ROOT/$gm"; then
    err "$gm no menciona el inbox de aprendizaje. Sin esa linea el agente no sabe donde registrar lo que aprende"
  fi

  if [ -f "$ROOT/.gitignore" ] && ! grep -q '^\.learning/' "$ROOT/.gitignore"; then
    err ".gitignore no ignora .learning/. El inbox es local de cada maquina y no debe commitearse"
  fi

  if [ -f "$ROOT/templates/skill/SKILL.md" ]; then
    printf '  [ok] templates/skill/SKILL.md\n'
  else
    err "templates/skill/SKILL.md no existe"
  fi

  check_chain_depth

  # el lint de markdown va aparte: usa su propio exit code
  if [ -f "$ROOT/tools/lint-md.sh" ]; then
    printf '\n'
    if bash "$ROOT/tools/lint-md.sh" >/dev/null 2>&1; then
      printf '  [ok] markdown\n'
    else
      bash "$ROOT/tools/lint-md.sh" 2>&1 | grep -E '^\s+\[(ERROR|warn)\]' | sed 's/^/  /' >&2
      err "el lint de markdown fallo. Corregi lo que reporta y volve a correr"
    fi
  fi

  # la infraestructura del repo tiene que estar documentada: un archivo nuevo
  # que nadie menciona es drift esperando a pasar
  local f base
  while IFS= read -r f; do
    base="$(basename "$f")"
    if ! grep -rqF "$base" "$ROOT/README.md" "$ROOT/AGENTS.md" 2>/dev/null; then
      err "$f no esta mencionado en README.md ni en AGENTS.md. Documentalo o no va a ser descubrible"
    fi
  done < <(cd "$ROOT" && git ls-files 'tools/*' 'agents/*' 'assets/*' '.gitattributes' 2>/dev/null)

  # Dos piezas que se dan por existentes tienen que estar: sin eol=lf los
  # .sh dejan de ejecutarse en Windows, y sin workflow nadie corre --check.
  if [ -f "$ROOT/.gitattributes" ] && ! grep -q '^\*\.sh text eol=lf' "$ROOT/.gitattributes"; then
    err ".gitattributes no fuerza LF en los .sh. En Windows bash deja de ejecutarlos"
  fi
  local wf=".github/workflows/validate.yml"
  if [ ! -f "$ROOT/$wf" ]; then
    err "$wf no existe. Sin workflow, --check no corre en CI"
  elif ! grep -q 'validate.sh --check' "$ROOT/$wf" || ! grep -q 'smoke-test.sh' "$ROOT/$wf"; then
    err "$wf no corre validate.sh --check y smoke-test.sh. El gate de CI no cubre la biblioteca"
  else
    printf '  [ok] %s\n' "$wf"
  fi
}

# true si la skill $1 depende (directa o indirectamente) de $2.
# Iterativo y con visitados: un ciclo que no incluye al objetivo no puede
# recursar hasta agotar el stack. Sin namerefs (bash 3.2).
depends_on() {
  local start="$1" target="$2" current f req r last
  local -a stack=("$start")
  local visited=""
  while [ ${#stack[@]} -gt 0 ]; do
    last=$((${#stack[@]} - 1))
    current="${stack[$last]}"
    unset "stack[$last]"
    [ "$current" = "$target" ] && return 0
    case "$visited" in
      *"|$current|"*) continue ;;
    esac
    visited="$visited|$current|"
    f="$(skill_file_for "$current")" || continue
    req="$(fm_meta "$f" requires)"
    [ -z "$req" ] && continue
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      stack+=("$r")
    done <<< "$(csv "$req")"
  done
  return 1
}

# Ninguna cadena de requires puede pasar de dos niveles: tres skills cargadas
# por tarea es el limite de contexto. BFS con visitados, sin namerefs (bash 3.2).
check_chain_depth() {
  local i name cur node depth head req r nfile
  for i in "${!SKILL_NAMES[@]}"; do
    name="${SKILL_NAMES[$i]}"
    local -a q=("$name|0")
    local seen="|$name|"
    head=0
    while [ "$head" -lt "${#q[@]}" ]; do
      cur="${q[$head]}"; head=$((head + 1))
      node="${cur%|*}"; depth="${cur##*|}"
      if [ "$depth" -gt 2 ]; then
        err "cadena de requires de mas de dos niveles desde '$name' hasta '$node'. Tres skills por tarea es el limite"
        return 1
      fi
      nfile="$(skill_file_for "$node")" || continue
      req="$(fm_meta "$nfile" requires)"
      [ -z "$req" ] && continue
      while IFS= read -r r; do
        [ -z "$r" ] && continue
        case "$seen" in
          *"|$r|"*) continue ;;
        esac
        seen="$seen|$r|"
        q+=("$r|$((depth + 1))")
      done <<< "$(csv "$req")"
    done
  done
  return 0
}

# --- indice del README -------------------------------------------------------

index_block() {
  local i cat name desc clause
  printf '<!-- Generado por tools/validate.sh --write. No editar a mano. -->\n\n'
  printf '| Skill | Categoria | Cuando se activa |\n'
  printf '| --- | --- | --- |\n'
  for i in "${!SKILL_NAMES[@]}"; do
    cat="${SKILL_CATS[$i]}"; name="${SKILL_NAMES[$i]}"
    desc="$(fm_top "${SKILL_FILES[$i]}" description)"
    if [ "${#desc}" -gt 140 ]; then
      # La columna dice CUANDO se activa: cortar desde el principio se come
      # justo la clausula "Use when" en las descripciones largas.
      clause="${desc##*. Use when }"
      if [ "$clause" != "$desc" ]; then desc="Use when $clause"; fi
      if [ "${#desc}" -gt 140 ]; then desc="${desc:0:137}..."; fi
    fi
    printf '| `%s` | %s | %s |\n' "$name" "$cat" "$desc"
  done
}

readme_block() {
  awk '/<!-- skills:start -->/{f=1;next} f&&/<!-- skills:end -->/{exit} f{print}' "$README"
}

sync_readme() {
  local tmp
  tmp="$(mktemp_file)"
  if [ -z "$tmp" ] || [ ! -f "$tmp" ]; then
    err "no se pudo crear el archivo temporal. No se toco el README"
    return 1
  fi
  index_block > "$tmp"
  if [ ! -s "$tmp" ]; then
    err "el indice generado quedo vacio. No se toco el README"
    rm -f "$tmp"
    return 1
  fi
  if [ ! -f "$README" ]; then
    err "no existe $README"
    rm -f "$tmp"
    return 1
  fi
  awk -v blockfile="$tmp" '
    /<!-- skills:start -->/ {
      print "<!-- skills:start -->"
      while ((getline line < blockfile) > 0) print line
      close(blockfile); skip=1; next
    }
    skip && /<!-- skills:end -->/ { print "<!-- skills:end -->"; skip=0; next }
    skip { next }
    { print }
  ' "$README" > "$README.tmp" && mv "$README.tmp" "$README"
  rm -f "$tmp"
  printf 'Indice del README actualizado.\n'
  return 0
}

check_readme() {
  local tmp cur
  tmp="$(mktemp_file)"
  index_block > "$tmp"
  cur="$(mktemp_file)"
  readme_block > "$cur"
  if ! diff -q "$cur" "$tmp" >/dev/null 2>&1; then
    err "el indice del README esta desactualizado. Corré: tools/validate.sh --write"
    diff -u "$cur" "$tmp" | head -30 >&2
    rm -f "$tmp" "$cur"
    return 1
  fi
  rm -f "$tmp" "$cur"
  printf '  [ok] indice del README al dia\n'
  return 0
}

# --- graph -------------------------------------------------------------------

print_graph() {
  local i name req ovr
  printf 'Grafo de dependencias\n\n'
  for i in "${!SKILL_NAMES[@]}"; do
    name="${SKILL_NAMES[$i]}"
    req="$(fm_meta "${SKILL_FILES[$i]}" requires)"
    ovr="$(fm_meta "${SKILL_FILES[$i]}" overrides)"
    printf '%s\n' "$name"
    [ -n "$req" ] && printf '  requires:  %s\n' "$req"
    [ -n "$ovr" ] && printf '  overrides: %s\n' "$ovr"
    [ -z "$req" ] && [ -z "$ovr" ] && printf '  (sin dependencias)\n'
    printf '\n'
  done
}

# --- main --------------------------------------------------------------------

load_skills

case "$MODE" in
  graph)
    print_graph
    ;;
  write)
    validate
    printf '\n'
    if [ "$ERRORS" -eq 0 ]; then
      if sync_readme; then
        # el indice se vuelve a verificar: si el write rompio algo, falla acá
        if ! check_readme >/dev/null 2>&1; then
          err "el indice del README quedo inconsistente despues de regenerarlo"
        fi
      fi
    else
      printf 'Hay errores. No se regenero el indice.\n' >&2
      exit 1
    fi
    ;;
  check)
    validate
    printf '\n'
    check_readme
    ;;
  *)
    validate
    ;;
esac

printf '\n%d skills · %d errores · %d warnings\n' "${#SKILL_NAMES[@]}" "$ERRORS" "$WARNINGS"
[ "$ERRORS" -eq 0 ] || exit 1
