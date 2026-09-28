# Barra, mascota animada, avisos que llegan y reacciones de la mascota (prefix y zoom)
Output assets/hero.gif
Source demo/common.tape

Hide
Type "bash demo/setup.sh && clear && tmux -L kh-demo attach -t api" Enter
Sleep 2s
Show

Sleep 7s
Screenshot assets/hero.png
Ctrl+B
Sleep 2s
Type "z"
Sleep 3s
Ctrl+B
Type "z"
Sleep 2s

Hide
Type "tmux -L kh-demo kill-server" Enter
