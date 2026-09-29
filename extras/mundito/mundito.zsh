# mundito: un cerebro en Braille con tus palabras en órbita, arriba de la terminal mientras escribes.
# zle pinta cada frame entre teclas (zle -F), así nunca pisa lo que escribes; con un comando corriendo se pausa solo.
# Las filas de arriba quedan fuera del scroll region: la salida de los comandos no las toca. `mundito-off` lo apaga.
typeset -g _MUNDO_TOP=24 _MUNDO_FD _MUNDO_BIN=${0:A:h}/mundito   # 23 filas (ROWS en mundito) + 1 de aire

_mundo_region() { print -n "\e7\e[${_MUNDO_TOP};${LINES}r\e8" > /dev/tty }

_mundo_frame() {
  local f
  if read -r -u $1 f; then print -rn -- $'\e7'"$f"$'\e8' > /dev/tty; else mundito-off; fi
}

_mundo_precmd() {
  local pos
  print -n '\e[6n' > /dev/tty; read -rs -t 0.3 -d R pos < /dev/tty   # fila del cursor
  pos=${${pos#*\[}%%;*}
  # tras `clear` o un TUI que resetea el scroll region, el cursor puede quedar arriba: bajarlo
  (( ${pos:-99} < _MUNDO_TOP )) && print -n "\e[${_MUNDO_TOP};1H" > /dev/tty
  _mundo_region
}

# claude, ssh y compañía dibujan su propia UI: les devolvemos la pantalla completa
_mundo_preexec() { case ${${(z)1}[1]} in claude|codex|opencode|ssh|tmux) mundito-off ;; esac }

_mundo_clear() { print -n "\e[2J\e[${_MUNDO_TOP};1H" > /dev/tty; zle -I }   # Ctrl+L sin borrar el cerebro... por un frame

mundito-on() {
  [[ -n $_MUNDO_FD ]] && return 0
  (( LINES >= _MUNDO_TOP + 8 && COLUMNS >= 60 )) || return 0
  print -n "\e[2J\e[${_MUNDO_TOP};1H" > /dev/tty
  exec {_MUNDO_FD}< <(exec $_MUNDO_BIN --stream)
  zle -F $_MUNDO_FD _mundo_frame
  _mundo_region
  autoload -Uz add-zsh-hook; add-zsh-hook precmd _mundo_precmd; add-zsh-hook preexec _mundo_preexec
  TRAPWINCH() { _mundo_region }
  zle -N clear-screen _mundo_clear
}

mundito-off() {
  [[ -n $_MUNDO_FD ]] || return 0
  zle -F $_MUNDO_FD 2>/dev/null; exec {_MUNDO_FD}<&-; _MUNDO_FD=
  add-zsh-hook -d precmd _mundo_precmd; add-zsh-hook -d preexec _mundo_preexec; unfunction TRAPWINCH 2>/dev/null
  zle -A .clear-screen clear-screen
  print -n "\e7\e[r\e8" > /dev/tty
}
