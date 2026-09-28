# tmux-kamehameha

Tema para tmux en Tokyo Night con acento naranja, una mascota que carga un kamehameha en la barra, pickers estilo Telescope para sesiones y texto, y avisos cuando Claude Code termina en otra ventana.

```
 main   0 editor   1 server   2 zsh       feat/login   13:35 28 sept.  (ﾉ>ω<)ﾉ━━━━━━●
```

## Qué trae

| Pieza | Qué hace |
|-------|----------|
| **Barra** | Fondo transparente. Pill naranja con la sesión, que se pone azul mientras el prefix está activo. Ventana actual en una pill oscura. A la derecha: sesiones con aviso pendiente, rama git del pane, título del pane, hora y la mascota. |
| **Mascota** | Carga y dispara un kamehameha, un frame por segundo. Reacciona: en guardia `(ง°Д°)ง` con el prefix, Super Saiyajin con un pane en zoom, cansado `(ﾉ-ω-)ﾉ zzz` con batería <20% desenchufada (macOS). |
| **`prefix f`** | Selector de sesiones estilo Telescope: buscador, lista y preview. `←/→` o `Tab/Shift-Tab` recorren las ventanas de la sesión dentro del preview (con scroll), `Enter` entra a esa ventana. |
| **`prefix g`** | Fuzzy search de texto en todos los panes de todas las sesiones, con scrollback. Preview centrado en la línea; `Enter` salta al pane en copy-mode parado sobre ella. |
| **`prefix s` / `w`** | `choose-tree` con la misma paleta y 🔔 en sesiones y ventanas con aviso. |
| **Avisos** | Una bell en otra ventana la marca en naranja con 🔔; si viene de otra sesión, aparece a la derecha de la barra. Con el extra de Claude Code, cada Claude avisa al terminar o al pedir permiso. |
| **Panes** | Los inactivos se atenúan. Con 2+ panes, cada borde muestra número, comando y título. |
| **Splits** | `prefix \|` y `prefix -` abren en la carpeta del pane actual. |
| **Ventanas** | `renumber-windows on`: al cerrar una no quedan huecos en la numeración. |

## Requisitos

- tmux 3.4 o superior (probado en 3.6a)
- [fzf](https://github.com/junegunn/fzf) 0.58 o superior, para los pickers
- Una [Nerd Font](https://www.nerdfonts.com/) en la terminal
- Truecolor: `set -ag terminal-overrides ",xterm-256color:RGB"`
- La mascota cansada usa `pmset`, solo macOS. En otros sistemas simplemente no se cansa.

## Instalación

Con [TPM](https://github.com/tmux-plugins/tpm), en `~/.tmux.conf`:

```tmux
set -g @plugin 'victord-exe/tmux-kamehameha'
```

Luego `prefix I` para instalar.

## Opciones

Van antes de la línea `run '~/.tmux/plugins/tpm/tpm'`.

| Opción | Default | Qué hace |
|--------|---------|----------|
| `@kamehameha-pet` | `on` | `off` quita la mascota |
| `@kamehameha-sessions-key` | `f` | Tecla del selector de sesiones |
| `@kamehameha-search-key` | `g` | Tecla del buscador de texto |

La lista de ventanas del preview muestra 6 como máximo (`MAX` en `scripts/session-picker.sh`) y el buscador de texto lee las últimas 5000 líneas de cada pane (`HIST` en `scripts/text-search.sh`).

## Extras

No los carga TPM; son para que el resto de la terminal combine con el tema.

### Claude Code: avisos y status line

`extras/claude-code/tmux-bell.sh` suena la bell en el pane donde corre Claude, y tmux marca esa ventana. Cópialo y regístralo como hook en `~/.claude/settings.json`:

```json
"hooks": {
  "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash ~/.claude/scripts/tmux-bell.sh", "timeout": 3 }] }],
  "Notification": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash ~/.claude/scripts/tmux-bell.sh", "timeout": 3 }] }]
}
```

Claude Code carga los hooks al arrancar: las sesiones abiertas antes de agregarlos no avisan hasta reiniciarlas.

`extras/claude-code/statusline.js` pinta el status line de Claude con la misma paleta: pill del modelo, carpeta, rama y costo a la izquierda, y barras de contexto, sesión y semana a la derecha. Dentro de tmux usa el ancho del pane para ir en una línea; si no cabe, achica las barras y, si tampoco, parte en dos.

```json
"statusLine": { "type": "command", "command": "node ~/.claude/statusline.js", "padding": 2 }
```

### oh-my-posh

`extras/oh-my-posh/kamehameha.omp.json`: pill naranja con la carpeta, rama git, duración si el comando pasó de 3 s, `✘ código` si falló, AWS solo si el perfil no es `default`, `❯` en su propia línea y transient prompt.

```sh
eval "$(oh-my-posh init zsh --config /ruta/a/kamehameha.omp.json)"
```

## Licencia

MIT
