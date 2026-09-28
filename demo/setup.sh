#!/usr/bin/env bash
# Arma el servidor de demo (tmux -L kh-demo) con sesiones y contenido genérico para grabar los GIFs.
# Uso: bash demo/setup.sh   (luego: tmux -L kh-demo attach -t api)
set -e
export KH_REPO; KH_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="${TMPDIR:-/tmp}/kh-demo"
T="tmux -L kh-demo"

$T kill-server 2>/dev/null || true
rm -rf "$D" && mkdir -p "$D"

# Repos de juguete para que la barra y el prompt muestren ramas
repo() { mkdir -p "$D/$1" && git -C "$D/$1" init -q -b main && shift_msgs "$@"; }
shift_msgs() { local r="$D/$1"; shift; for m in "$@"; do echo "$m" >> "$r/CHANGELOG"; git -C "$r" add -A; git -C "$r" -c user.name=demo -c user.email=demo@example.com commit -qm "$m"; done; }
repo api "feat: login con email" "fix: expira la sesión a las 24h" "refactor: servicio de tokens" "feat: refresh token rotativo"
git -C "$D/api" checkout -qb feat/refresh-tokens
repo web "feat: pantalla de login" "style: tokens de color"
git -C "$D/web" checkout -qb feat/dark-mode
repo infra "chore: módulo de red" "feat: bucket de assets"

# Contenido de cada pane: se imprime y queda un shell vivo debajo
cat > "$D/auth.ts" <<'EOF'
import { signJwt, verifyJwt } from "./jwt";
import { tokens } from "./token.repository";

export async function rotateRefreshToken(userId: string, old: string) {
  const current = await tokens.findActive(userId);
  if (!current || current.value !== old) {
    await tokens.revokeAll(userId); // reuse detectado
    throw new Error("refresh token reutilizado");
  }
  await tokens.revoke(current.id);
  return tokens.issue(userId, { ttl: "30d" });
}
EOF
cat > "$D/server.log" <<'EOF'
[12:01:03] INFO  api escuchando en :3000
[12:01:04] INFO  conectado a postgres (pool=10)
[12:02:17] INFO  POST /auth/login 200 38ms
[12:02:21] INFO  POST /auth/refresh 200 12ms
[12:03:45] WARN  POST /auth/refresh 401 refresh token vencido
[12:04:02] ERROR POST /auth/refresh 500 refresh token reutilizado (user=4812)
[12:04:10] INFO  GET /me 200 6ms
[12:05:33] ERROR conexión a redis perdida, reintentando en 2s
[12:05:35] INFO  redis reconectado
EOF
cat > "$D/tests.txt" <<'EOF'
 ✓ src/auth/login.test.ts (12 tests) 84ms
 ✓ src/auth/refresh.test.ts (9 tests) 51ms
 ✓ src/ui/theme.test.ts (6 tests) 12ms

 Test Files  3 passed (3)
      Tests  27 passed (27)
   Duration  1.02s
EOF
cat > "$D/plan.txt" <<'EOF'
Terraform will perform the following actions:

  # aws_s3_bucket.assets will be created
  + resource "aws_s3_bucket" "assets" {
      + bucket = "demo-assets"
    }

Plan: 1 to add, 0 to change, 0 to destroy.
EOF
cat > "$D/todo.md" <<'EOF'
# Pendientes

- [x] rotar refresh tokens
- [ ] modo oscuro en web
- [ ] alertas de redis
EOF
cat > "$D/claude.txt" <<'EOF'
> rota el refresh token en cada uso y detecta si lo reutilizan

⏺ Listo. rotateRefreshToken ahora revoca el token anterior en cada uso
  y, si llega uno ya revocado, cierra todas las sesiones del usuario.

  Tests: 9 passed en src/auth/refresh.test.ts
EOF
# Uso falso para el status line de Claude (el script lee este cache y no sale a la red)
mkdir -p "$D/tmp"
echo '{"five_hour":{"utilization":23,"resets_at":"2099-01-01T00:00:00Z"},"seven_day":{"utilization":61,"resets_at":"2099-01-03T00:00:00Z"}}' > "$D/tmp/claude_usage_cache_demo.json"

show() { printf 'clear; %s; exec zsh' "$1"; }
# Log con niveles en color (truecolor), pintado una vez aquí
c() { printf '\033[38;2;%sm' "$1"; }; R=$'\033[0m'
sed -e "s/INFO/$(c '122;162;247')INFO$R/" -e "s/WARN/$(c '224;175;104')WARN$R/" -e "s/ERROR/$(c '247;118;142')ERROR$R/" "$D/server.log" > "$D/server.ansi"
logcmd="cat $D/server.ansi"
claudecmd="cat $D/claude.txt; echo; echo '{\"model\":{\"display_name\":\"Opus\"},\"cost\":{\"total_cost_usd\":1.42},\"context_window\":{\"used_percentage\":34},\"workspace\":{\"current_dir\":\"$D/api\"},\"session_id\":\"demo\"}' | TMPDIR=$D/tmp node $KH_REPO/extras/claude-code/statusline.js"

# ZDOTDIR se hereda del entorno con el que arranca el servidor
export ZDOTDIR="$KH_REPO/demo/zdotdir"
$T -f "$KH_REPO/demo/tmux.conf" new -d -s api -n editor -x 160 -y 40 -c "$D/api" "$(show "cat $D/auth.ts")"
$T run-shell "$KH_REPO/kamehameha.tmux"
$T split-window -h -t api:editor -c "$D/api" "$(show 'git log --oneline --graph --color=always')"
$T select-pane -t api:editor.0 -T "src/auth.ts"
$T select-pane -t api:editor.1 -T "git log"
$T new-window -d -t api: -n server -c "$D/api" "$(show "$logcmd")";  $T select-pane -t api:server -T "pnpm dev"
$T new-window -d -t api: -n claude -c "$D/api" "$(show "$claudecmd")"; $T select-pane -t api:claude -T "✳ Rotar refresh tokens"
$T new-session -d -s web -n dev -c "$D/web" "$(show 'git log --oneline --color=always')"; $T select-pane -t web:dev -T "vite"
$T new-window -d -t web: -n tests -c "$D/web" "$(show "cat $D/tests.txt")"; $T select-pane -t web:tests -T "vitest"
$T new-session -d -s infra -n terraform -c "$D/infra" "$(show "cat $D/plan.txt")"; $T select-pane -t infra:terraform -T "terraform plan"
$T new-session -d -s notas -n todo -c "$D" "$(show "cat $D/todo.md")"; $T select-pane -t notas:todo -T "todo.md"
$T select-window -t api:editor; $T select-pane -t api:editor.0

# Bells programadas: una ventana de la sesión actual y otra sesión, para que se vean los avisos en la grabación
bell() { ( sleep "$2"; printf '\a' > "$($T display -p -t "$1" '#{pane_tty}')" ) & }
bell api:server "${KH_BELL_DELAY:-4}"
bell web:tests "$(( ${KH_BELL_DELAY:-4} + 1 ))"
