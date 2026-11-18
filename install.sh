#!/usr/bin/env bash
# install.sh — enlaza `isymem` a este clon. No toca configs de agentes: eso es `isymem setup`.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="${ISYMEM_BIN_DIR:-$HOME/.local/bin}/isymem"
force=0; [ "${1:-}" = "--force" ] && force=1

python3 "$here/test_agent_memory.py" >/dev/null 2>&1 || { echo "tests fallaron: python3 $here/test_agent_memory.py" >&2; exit 1; }
if [ -e "$bin" ] || [ -L "$bin" ]; then
  current="$(readlink -f "$bin" || true)"
  if [ "$current" = "$here/agent_memory.py" ]; then echo "isymem ya apunta a este clon: $bin"; exit 0; fi
  if [ "$force" -ne 1 ]; then
    echo "isymem ya existe y apunta a: $current" >&2
    echo "No lo piso. Si quieres usar este clon: ./install.sh --force" >&2
    exit 2
  fi
fi
mkdir -p "$(dirname "$bin")"
ln -sfn "$here/agent_memory.py" "$bin"
echo "OK: $bin -> $here/agent_memory.py"
echo "Siguiente: configura el proyecto (ver README, 'Configuración') y corre: isymem setup --dry-run"
