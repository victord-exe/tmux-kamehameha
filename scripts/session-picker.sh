#!/bin/bash
# Selector de sesiones estilo Telescope (prefix f).
# ←/→ o Tab/Shift-Tab recorren las ventanas de la sesión elegida dentro del preview; Enter entra a esa ventana.
# El script se llama a sí mismo con --preview, --move y --go. La ventana elegida vive en $PICKER_STATE ("sesion<TAB>indice").

sel() { # ventana elegida para la sesión $1: la guardada si es de esa sesión, si no la activa
  local st; st=$(cat "$PICKER_STATE" 2>/dev/null)
  if [ -n "$st" ] && [ "${st%%$'\t'*}" = "$1" ]; then echo "${st#*$'\t'}"
  else tmux display -p -t "=$1:" '#{window_index}'; fi
}

case "$1" in
  --preview)
    w=$(sel "$2")
    # Lista de ventanas con scroll: máximo MAX filas, centrada en la elegida, con "↑/↓ N más" para lo que queda fuera
    MAX=6
    head=$(tmux list-windows -t "=$2" -F "#{window_index}	#{window_name}	#{window_bell_flag}" |
      awk -F'\t' -v w="$w" -v max="$MAX" '
        {i[NR] = $1; nm[NR] = $2; b[NR] = $3; if ($1 == w) c = NR}
        END {
          s = c - int(max / 2); if (s > NR - max + 1) s = NR - max + 1; if (s < 1) s = 1
          e = s + max - 1; if (e > NR) e = NR
          D = "\033[38;2;169;177;214m"
          if (s > 1) printf "%s  ↑ %d más\033[0m\n", D, s - 1
          for (k = s; k <= e; k++)
            printf "%s%s %s%s\033[0m\n", (k == c ? "\033[38;2;255;158;100m\033[1m▶ " : "  "), i[k], nm[k], (b[k] == 1 ? " 🔔" : "")
          if (e < NR) printf "%s  ↓ %d más\033[0m\n", D, NR - e
        }')
    printf '%s\n' "$head"
    printf '\e[38;2;84;92;126m%*s\e[0m\n' "${FZF_PREVIEW_COLUMNS:-80}" '' | tr ' ' '─'
    n=$(( ${FZF_PREVIEW_LINES:-30} - $(printf '%s\n' "$head" | wc -l) - 1 )); [ "$n" -lt 1 ] && n=1
    # ponytail: solo la pantalla visible del pane; con -S -N saldría scrollback si hiciera falta
    tmux capture-pane -ep -t "=$2:$w" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | tail -n "$n"
    exit 0 ;;
  --move)
    w=$(sel "$2")
    next=$(tmux list-windows -t "=$2" -F '#{window_index}' |
      awk -v w="$w" -v d="$3" '{a[NR] = $1; if ($1 == w) c = NR} END {c += d; if (c < 1) c = NR; if (c > NR) c = 1; print a[c]}')
    printf '%s\t%s' "$2" "$next" > "$PICKER_STATE"
    exit 0 ;;
  --go)
    tmux switch-client -t "=$2:$(sel "$2")"
    exit 0 ;;
esac

export PICKER_STATE; PICKER_STATE=$(mktemp); trap 'rm -f "$PICKER_STATE"' EXIT

# Campo 1 = nombre crudo, campo 2 = lo que se ve: nombre alineado a 24 + conteo
tmux ls -F "#{session_name}	#{session_windows}w#{?session_attached, ●,}#{?session_alerts, 🔔,}" |
  awk -F'\t' '{n[NR]=$1; r[NR]=$2; if (length($1)>m) m=length($1)} END {if (m>24) m=24; for (i=1;i<=NR;i++) printf "%s\t%-*s  %s\n", n[i], m, n[i], r[i]}' |
  fzf --with-shell 'bash -c' --delimiter '\t' --with-nth 2 \
    --reverse --style full --no-scrollbar --prompt '  ' --pointer '▶' \
    --input-label ' Buscar ' --list-label ' Sesiones ' --preview-label ' Preview · ←/→ ventanas · Enter entra ' \
    --preview "$0 --preview {1}" --preview-window 'right,65%' \
    --bind "right:execute-silent($0 --move {1} 1)+refresh-preview,tab:execute-silent($0 --move {1} 1)+refresh-preview" \
    --bind "left:execute-silent($0 --move {1} -1)+refresh-preview,shift-tab:execute-silent($0 --move {1} -1)+refresh-preview" \
    --bind "enter:become($0 --go {1})" \
    --color 'fg:#c0caf5,bg:-1,hl:#ff9e64,fg+:#c0caf5,bg+:#292e42,hl+:#ff9e64,pointer:#ff9e64,prompt:#7aa2f7,info:#a9b1d6,border:#545c7e,label:#ff9e64'
exit 0
