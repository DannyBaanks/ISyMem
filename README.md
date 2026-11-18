# ISyMem

Memoria compartida para **todos** los agentes de código de una máquina: Claude Code, Codex, AGY/Gemini,
Qwen, OpenCode, Grok, Crush… Un solo banco de notas que cada agente lee al arrancar y escribe mientras trabaja,
con el mismo formato que la auto-memoria de Claude Code. Claude la lee nativo y los demás la reciben por su config global.

Un solo archivo de Python 3 (sin dependencias). Linux/macOS (`fcntl`). Usa [`ziggrep`](https://github.com/DannyBaanks/ZiGrep)
si está instalado para buscar anclas; si no, cae a Python.

## La idea: un grafo que se descubre por niveles

Cargar todas las notas en cada sesión gasta tokens. Pero no cargarlas hace que el agente repita errores que ya
se corrigieron. ISyMem resuelve eso con niveles: cada agente lee solo el nivel que su tarea necesita.

| Nivel | Comando | Qué da |
|---|---|---|
| L0 | `MEMORY.md` (se carga solo al arrancar) | reglas generales + **una línea por proyecto** |
| L1 | `isymem <proyecto>` · `isymem projects` | tarjeta: memorias del proyecto, fallos/pendientes abiertos, proyectos vecinos |
| L2 | `isymem <proyecto> --fails --pending` | **una línea por hecho** (anclas, buscadas con ziggrep) |
| L3 | `isymem show <slug>` · `isymem graph <slug\|proyecto>` | la memoria completa · sus enlaces |

- **Nodo:** un archivo `<slug>.md` con frontmatter (`name`, `description`, `metadata.type`, `metadata.project`).
- **Hub:** `hub-<proyecto>.md`, la única línea del proyecto en el índice. Lleva un `## Ledger` y la lista automática de sus memorias.
- **Aristas:** `[[otro-slug]]` en el cuerpo. Los enlaces que cruzan proyectos dan los "vecinos".
- **Ancla:** un hecho por línea, buscable sin la herramienta:

  ```
  - @todo#7997 #game-port 2026-11-17: achievement/stat round trip with live Steam [[steam-bridge-state]]
  ```
  Tipos: `fail todo rule state idea`. Cerrados: `done fixed`.
  A mano: `ziggrep -rn '@(todo|fail)#[0-9a-f]+ #game-port ' <dir-de-memoria>/`

## Salida real

Banco de demo creado con los comandos de abajo (2026-11-17). La ruta del banco se abrevió como `~/demo/mem`.

```
$ isymem game-port
PROYECTO game-port — Windows game running natively on Linux: loader, audio, Steam bridge
  hub: ~/demo/mem/hub-game-port.md
  abiertos: 1 todo · 1 fail  → isymem game-port --open   (reglas: --rules · estado: --state)
  memorias (lee solo la que aplique: isymem show <slug>):
    steam-bridge-state                   [project, 0d] Steam API relay works; achievements/cloud/overlay not seen yet
  vecinos (grafo por [[links]]): general(1)

$ isymem game-port --fails --pending
[game-port]
  @fail#c06d 2026-11-17: overlay crashes on first frame  (hub-game-port.md:18)
  @todo#7997 2026-11-17: achievement/stat round trip with live Steam [[steam-bridge-state]]  (hub-game-port.md:17)
cerrar: isymem close <id> [--note "..."] · nueva: isymem add <proyecto> --todo|--fail "..."

$ isymem recall "voy a matar el proceso del bridge"
RECALL 'voy a matar el proceso del bridge' — lee las que apliquen ANTES de actuar (`isymem show <slug>`):
    2.63  steam-bridge-state                   [project, game-port, 0d]  Steam API relay works; achievements/cloud/overlay not seen yet
    2.54  hub-game-port                        [project, game-port, 0d]  Windows game running natively on Linux: loader, audio, Steam bridge
    1.97  no-kill-derived-pids                 [feedback, general, 0d]  print and check comm before any kill; a ppid kill once logged the user out
```

Comandos con los que se armó:

```bash
isymem save no-kill-derived-pids --name "Never kill derived PIDs" --type feedback \
  --desc "print and check comm before any kill; a ppid kill once logged the user out" \
  --why "killed systemd --user via a ppid" --how "ps -o comm= -p PID before kill"
isymem hub game-port --name "Game port" --desc "Windows game running natively on Linux: loader, audio, Steam bridge"
isymem save steam-bridge-state --project game-port --name "Steam bridge" \
  --desc "Steam API relay works; achievements/cloud/overlay not seen yet" \
  --body "Bridge relays to the native steamclient. See [[no-kill-derived-pids]] before restarting it."
isymem add game-port --todo "achievement/stat round trip with live Steam" --link steam-bridge-state
isymem add game-port --fail "overlay crashes on first frame"
isymem add game-port --rule "the .exe is the artifact: native shims, no Wine"
```

## Comandos

| Quieres… | Comando |
|---|---|
| ver el índice | `isymem` / `isymem list [--type feedback]` |
| proyectos con conteos | `isymem projects` |
| tarjeta de un proyecto | `isymem <proyecto>` |
| fallos / pendientes / reglas… | `isymem <proyecto> --fails --todo` (`--pending --pendientes --rules --state --ideas --done --open --all`); sin proyecto = todos |
| anotar una línea | `isymem add <proyecto> --fail\|--todo\|--rule\|--state\|--idea "..." [--link slug]` |
| cerrar | `isymem close <id> --note "commit/evidencia"` (todo→done, fail→fixed) |
| memoria larga | `isymem save <slug> --name ... --desc ... --type feedback\|user\|project\|reference [--project P] --body/--why/--how ...` |
| buscar por tarea (ranking, glosa español→inglés) | `isymem recall "<lo que vas a hacer>" [--show]` |
| buscar texto literal | `isymem search "<texto>"` |
| leer / enlaces | `isymem show <slug>` · `isymem graph <slug\|proyecto>` |
| retirar (nunca borra) | `isymem archive <slug>` → `~/.local/state/isymem/archive/` |
| versiones anteriores | `isymem history [<slug>]` |
| reordenar el índice (reglas + hubs) | `isymem compact [--dry-run]` |
| revisar todo | `isymem doctor [--stale-days N]` |
| instalar la regla en los agentes | `isymem setup [--dry-run] [--undo]` · refrescar copias: `isymem sync` |

Garantías: `save` sobre un slug existente **agrega** (`--replace` reescribe, con snapshot previo). Las escrituras usan
lock (varios agentes a la vez no pierden líneas del índice). `save`/`add` rechazan texto con pinta de secreto
(tokens, `sk-`, `ghp_`, `hf_`, claves privadas…). `archive` mueve, no borra.

## Instalación y configuración

```bash
git clone https://github.com/DannyBaanks/ISyMem && cd ISyMem
./install.sh            # corre los tests y enlaza ~/.local/bin/isymem (no pisa uno existente sin --force)
```

Dile qué proyecto comparten tus agentes (es personal: no va en el repo):

```bash
mkdir -p ~/.config/isyco-memory
cat > ~/.config/isyco-memory/config.json <<'JSON'
{ "project_root": "/ruta/a/tu/proyecto", "user": "TuNombre" }
JSON
isymem setup --dry-run   # muestra qué configs tocaría
isymem setup             # instala la regla (+ copia del índice) en cada agente
isymem doctor
```

- El banco vive donde Claude Code guarda la memoria de ese proyecto: `~/.claude/projects/<ruta con '-'>/memory/`.
  `<proyecto>/docs/agent/memory` es un symlink a ese directorio.
- `setup` escribe entre marcadores `<!-- isymem:setup begin/end -->` y no toca el resto del archivo. Configs:
  `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/.qwen/QWEN.md`, `~/.config/opencode/AGENTS.md` (regla + copia
  del índice, porque Codex no resuelve `@imports`) y `~/.claude/CLAUDE.md` (solo un `@import`; Claude ya carga
  `MEMORY.md`). Instala solo en los agentes cuyo directorio existe. `--undo` quita los bloques.
- Cada `save`/`add`/`archive` refresca esas copias del índice. Si otro proceso escribe `MEMORY.md` directo,
  corre `isymem sync` (o llámalo desde tu hook de inicio de sesión).
- Variables: `ISYMEM_PROJECT_ROOT`, `ISYMEM_USER`, `ISYMEM_CONFIG_DIR`, `ISYMEM_DIR` (banco suelto, sin symlink),
  `ISYMEM_STATE_DIR`, `ISYMEM_AUTHOR`.

## Límites (honestos)

- `recall` busca por palabras (TF-IDF simple + glosa ES→EN), no entiende el significado. Lo "semántico" de las anclas
  lo pone quien las escribe al elegir el tipo y el proyecto.
- Una memoria refleja lo que era cierto cuando se escribió. Verifica en disco antes de citar un conteo o un SHA.
- No sincroniza entre máquinas: es un directorio local.

## Pruebas

```bash
python3 test_agent_memory.py     # banco desechable: nunca toca el real
```

## Origen

Nació en el monorepo ISyCo (`tools/agent_memory.py`), que sigue siendo la copia que ejecutan los agentes de esa
máquina. Las dos copias se mantienen idénticas: si cambias una, cópiala a la otra y corre las pruebas en ambas.
