#!/bin/bash
# Suena la bell en el pane de tmux donde corre Claude, para que tmux marque la ventana/sesión con 🔔
# Lo llaman los hooks Stop y Notification. Fuera de tmux no hace nada.
[ -n "$TMUX_PANE" ] || exit 0
tty=$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null) && printf '\a' > "$tty"
exit 0
