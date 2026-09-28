#!/bin/bash
# Buscador de texto estilo Telescope live grep (prefix g): fuzzy search sobre el contenido de TODOS los panes,
# con scrollback. Preview centrado en la línea; Enter salta al pane en copy-mode parado en esa línea.
# Cada línea lleva ocultos el pane_id y el número de línea dentro de su captura.

# ponytail: últimas HIST líneas por pane; súbelo si buscas cosas más viejas (fzf aguanta cientos de miles)
HIST=5000
cap() { tmux capture-pane -p -J -S "-$HIST" -t "$@"; }

case "$1" in
  --preview)
    cap "$2" -e | awk -v l="$3" 'NR == l {print "\033[38;2;255;158;100m\033[1m▶\033[0m " $0; next} {print "  " $0}'
    exit 0 ;;
  --go)
    text=$(cap "$2" | sed -n "${3}p" | sed 's/[[:space:]]*$//')
    tmux switch-client -t "$2"; tmux select-window -t "$2"; tmux select-pane -t "$2"
    tmux copy-mode -t "$2"
    [ -n "$text" ] && tmux send-keys -t "$2" -X search-backward-text "$text"
    exit 0 ;;
esac

# Campos: 1 pane_id, 2 línea (ocultos) · 3 ubicación (se ve, no se busca) · 4 texto (se ve y se busca)
# Líneas más recientes primero (--tac); se saltan las vacías y se aprietan los tramos de espacios (prompt a la derecha)
tmux list-panes -a -F "#{pane_id}	#{session_name}:#{window_index}.#{pane_index}" |
  while IFS=$'\t' read -r id where; do
    cap "$id" | awk -v id="$id" -v w="$where" 'NF {gsub(/\t/, " "); gsub(/   +/, "  "); printf "%s\t%d\t\033[38;2;169;177;214m%-18s\033[0m\t%s\n", id, NR, w, $0}'
  done |
  fzf --ansi --tac --with-shell 'bash -c' --delimiter '\t' --with-nth 3,4 --nth 2 \
    --reverse --style full --no-scrollbar --no-hscroll --prompt '  ' --pointer '▶' \
    --input-label ' Buscar texto ' --list-label ' Coincidencias ' --preview-label ' Preview · Enter salta a la línea ' \
    --preview "$0 --preview {1} {2}" --preview-window 'right,55%,+{2}-/2' \
    --bind "enter:become($0 --go {1} {2})" \
    --color 'fg:#c0caf5,bg:-1,hl:#ff9e64,fg+:#c0caf5,bg+:#292e42,hl+:#ff9e64,pointer:#ff9e64,prompt:#7aa2f7,info:#a9b1d6,border:#545c7e,label:#ff9e64'
exit 0
