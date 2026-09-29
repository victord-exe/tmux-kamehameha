# mundito: el cerebro gira arriba mientras se escribe abajo (con las palabras del config de ejemplo)
Output assets/mundito.gif
Source demo/common.tape
Set Shell "zsh"
Set Height 1000   # mundito arranca desde 32 filas

Hide
Type "unset TMUX TMUX_PANE; export KH_REPO=$PWD MUNDITO_CONFIG=$PWD/extras/mundito/config.example.json ZDOTDIR=$PWD/demo/zdotdir; mkdir -p /tmp/mundito && cd /tmp/mundito && exec zsh -i" Enter
Sleep 1.5s
Type "source $KH_REPO/extras/mundito/mundito.zsh && mundito-on" Enter
Sleep 1s
Show

Sleep 4s
Screenshot assets/mundito.png
Type "echo sigue girando mientras escribo" Sleep 400ms Enter
Sleep 2s
Type "seq 1 12" Sleep 400ms Enter
Sleep 4s
Type "mundito-off" Sleep 400ms Enter
Sleep 1.5s
